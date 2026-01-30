const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const logger = functions.logger;

async function isAdminCaller(context) {
  try {
    if (!context?.auth) return false;
    if (context.auth.token?.admin === true) return true;

    const userDoc = await db.collection('users').doc(context.auth.uid).get();
    const role = userDoc.exists ? userDoc.data()?.userRole : null;
    return role === 2 || role === 3 || role === '2' || role === '3';
  } catch (e) {
    logger.warn('isAdminCaller check failed', { error: e?.message });
    return false;
  }
}

function requireAuth(context) {
  if (!context?.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }
}

async function requireAdmin(context) {
  requireAuth(context);
  if (!(await isAdminCaller(context))) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'User must have admin role'
    );
  }
}

exports.getPetNamesAdmin = functions.https.onCall(async (data, context) => {
  await requireAdmin(context);

  const petIds = Array.isArray(data?.petIds) ? data.petIds : [];
  const uniqueIds = Array.from(
    new Set(
      petIds
        .map((v) => (typeof v === 'string' ? v.trim() : ''))
        .filter((v) => v)
    )
  );

  if (uniqueIds.length === 0) {
    return { names: {} };
  }

  if (uniqueIds.length > 200) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Too many petIds (max 200)'
    );
  }

  const refs = uniqueIds.map((id) => db.collection('pets').doc(id));
  const docs = await db.getAll(...refs);
  const names = {};

  docs.forEach((docSnap, idx) => {
    const id = uniqueIds[idx];
    const name = docSnap.exists ? (docSnap.data()?.name ?? 'Unknown Pet') : 'Unknown Pet';
    names[id] = String(name);
  });

  return { names };
});

exports.getPolicyAndPetAdmin = functions.https.onCall(async (data, context) => {
  await requireAdmin(context);

  const policyId = typeof data?.policyId === 'string' ? data.policyId.trim() : '';
  const petId = typeof data?.petId === 'string' ? data.petId.trim() : '';

  if (!policyId || !petId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'policyId and petId are required'
    );
  }

  const [policySnap, petSnap] = await Promise.all([
    db.collection('policies').doc(policyId).get(),
    db.collection('pets').doc(petId).get(),
  ]);

  return {
    policy: policySnap.exists ? policySnap.data() : null,
    pet: petSnap.exists ? petSnap.data() : null,
  };
});

exports.getClaimsAnalyticsFilterOptionsAdmin = functions.https.onCall(
  async (data, context) => {
    await requireAdmin(context);

    const startDate = typeof data?.startDate === 'string' ? data.startDate : null;
    const endDate = typeof data?.endDate === 'string' ? data.endDate : null;

    if (!startDate || !endDate) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'startDate and endDate are required'
      );
    }

    const start = admin.firestore.Timestamp.fromDate(new Date(startDate));
    const end = admin.firestore.Timestamp.fromDate(new Date(endDate));

    // Pull claims in range, then derive options from related pets/users referenced.
    const claimsSnap = await db
      .collection('claims')
      .where('createdAt', '>=', start)
      .where('createdAt', '<=', end)
      .get();

    const petIdsSet = new Set();
    const ownerIdsSet = new Set();
    const vetProvidersSet = new Set();

    for (const doc of claimsSnap.docs) {
      const claim = doc.data() || {};
      if (typeof claim.petId === 'string' && claim.petId.trim()) {
        petIdsSet.add(claim.petId.trim());
      }
      if (typeof claim.ownerId === 'string' && claim.ownerId.trim()) {
        ownerIdsSet.add(claim.ownerId.trim());
      }

      const documents = Array.isArray(claim.documents) ? claim.documents : [];
      for (const d of documents) {
        const providerName = d?.metadata?.providerName;
        if (typeof providerName === 'string' && providerName.trim()) {
          vetProvidersSet.add(providerName.trim());
        }
      }
    }

    const petIds = Array.from(petIdsSet).slice(0, 1000);
    const ownerIds = Array.from(ownerIdsSet).slice(0, 1000);

    const breedsSet = new Set();
    const regionsSet = new Set();

    // Batch fetch pets
    for (let i = 0; i < petIds.length; i += 200) {
      const chunk = petIds.slice(i, i + 200);
      const refs = chunk.map((id) => db.collection('pets').doc(id));
      const docs = await db.getAll(...refs);
      docs.forEach((snap) => {
        const breed = snap.exists ? snap.data()?.breed : null;
        if (typeof breed === 'string' && breed.trim()) breedsSet.add(breed.trim());
      });
    }

    // Batch fetch users
    for (let i = 0; i < ownerIds.length; i += 200) {
      const chunk = ownerIds.slice(i, i + 200);
      const refs = chunk.map((id) => db.collection('users').doc(id));
      const docs = await db.getAll(...refs);
      docs.forEach((snap) => {
        const state = snap.exists ? snap.data()?.address?.state : null;
        if (typeof state === 'string' && state.trim()) regionsSet.add(state.trim());
      });
    }

    const breeds = Array.from(breedsSet).sort();
    const regions = Array.from(regionsSet).sort();
    const vetProviders = Array.from(vetProvidersSet).sort();

    logger.info('Claims analytics filter options generated', {
      breeds: breeds.length,
      regions: regions.length,
      vetProviders: vetProviders.length,
      claims: claimsSnap.size,
    });

    return { breeds, regions, vetProviders };
  }
);
