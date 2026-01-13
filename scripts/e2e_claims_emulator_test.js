/*
  End-to-end Claims Emulator Smoke Test

  Runs inside `firebase emulators:exec`.
  Validates:
   - Customer can call processClaimDecision and claim updates server-side
   - Admin can call processClaimPayout and claim reaches settled (emulator stub)

  Usage:
    firebase emulators:exec --only auth,firestore,functions,storage \
      "node scripts/e2e_claims_emulator_test.js"
*/

const admin = require('../functions/node_modules/firebase-admin');

function requireEnv(name) {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required env var: ${name}`);
  return value;
}

function projectIdFromEnv() {
  if (process.env.GCLOUD_PROJECT) return process.env.GCLOUD_PROJECT;
  if (process.env.FIREBASE_CONFIG) {
    try {
      const cfg = JSON.parse(process.env.FIREBASE_CONFIG);
      if (cfg.projectId) return cfg.projectId;
    } catch (_) {}
  }
  return 'pet-underwriter-ai';
}

async function exchangeCustomTokenForIdToken({ authEmulatorHost, customToken }) {
  // Auth emulator supports Identity Toolkit endpoints; API key is not validated.
  const url = `http://${authEmulatorHost}/identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=fake-api-key`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ token: customToken, returnSecureToken: true }),
  });

  const body = await res.json();
  if (!res.ok) {
    throw new Error(`Failed to exchange custom token: ${res.status} ${JSON.stringify(body)}`);
  }

  if (!body.idToken) {
    throw new Error(`No idToken in exchange response: ${JSON.stringify(body)}`);
  }

  return body.idToken;
}

async function callCallable({ projectId, region, name, idToken, data }) {
  const url = `http://127.0.0.1:5001/${projectId}/${region}/${name}`;
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${idToken}`,
    },
    body: JSON.stringify({ data }),
  });

  const bodyText = await res.text();
  let body;
  try {
    body = JSON.parse(bodyText);
  } catch (_) {
    body = { raw: bodyText };
  }

  if (!res.ok) {
    throw new Error(`Callable ${name} failed: ${res.status} ${JSON.stringify(body)}`);
  }

  // Callable responses use either { result } or direct payload depending on emulator/runtime.
  return body.result ?? body;
}

async function main() {
  const projectId = projectIdFromEnv();
  const region = 'us-central1';

  const authHost = requireEnv('FIREBASE_AUTH_EMULATOR_HOST');
  requireEnv('FIRESTORE_EMULATOR_HOST');

  if (!admin.apps.length) {
    admin.initializeApp({ projectId });
  }

  const db = admin.firestore();

  const customerUid = 'e2e_customer_1';
  const adminUid = 'e2e_admin_1';

  const customerEmail = 'e2e_customer_1@example.com';
  const adminEmail = 'e2e_admin_1@example.com';

  // Create auth users in emulator
  await admin.auth().createUser({ uid: customerUid, email: customerEmail, password: 'Passw0rd!123' }).catch(() => {});
  await admin.auth().createUser({ uid: adminUid, email: adminEmail, password: 'Passw0rd!123' }).catch(() => {});

  // Create Firestore user docs
  await db.collection('users').doc(customerUid).set({
    userRole: 1,
    email: customerEmail,
    stripeCustomerId: 'cus_emulator_123',
    firstName: 'E2E',
    lastName: 'Customer',
  }, { merge: true });

  await db.collection('users').doc(adminUid).set({
    userRole: 2,
    email: adminEmail,
    firstName: 'E2E',
    lastName: 'Admin',
  }, { merge: true });

  // Minimal pet/policy for claim decision prompt
  const petId = 'e2e_pet_1';
  await db.collection('pets').doc(petId).set({ ownerId: customerUid, name: 'Rex' }, { merge: true });

  const policyId = 'e2e_policy_1';
  await db.collection('policies').doc(policyId).set({
    ownerId: customerUid,
    petId,
    effectiveDate: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 40 * 24 * 60 * 60 * 1000)),
    plan: {
      name: 'E2E Plan',
      annualDeductible: 250,
      reimbursementPercent: 80,
      isUnlimitedAnnualCoverage: false,
      maxAnnualCoverage: 5000,
      waitingPeriodsDays: { illness: 14, accident: 0, wellness: 0 },
    },
  }, { merge: true });

  // Create claim
  const claimId = 'e2e_claim_1';
  await db.collection('claims').doc(claimId).set({
    policyId,
    ownerId: customerUid,
    petId,
    incidentDate: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 2 * 24 * 60 * 60 * 1000)),
    claimType: 'illness',
    claimAmount: 123.45,
    currency: 'USD',
    description: 'E2E test claim',
    attachments: [],
    status: 'submitted',
    createdAt: admin.firestore.Timestamp.fromDate(new Date()),
    updatedAt: admin.firestore.Timestamp.fromDate(new Date()),
    aiDecision: null,
    aiConfidenceScore: null,
    aiReasoningExplanation: null,
    humanOverride: null,
    settledAt: null,
    reviewLockedBy: null,
    reviewLockedAt: null,
  });

  // Obtain ID tokens (via custom token exchange)
  const customerCustomToken = await admin.auth().createCustomToken(customerUid);
  const adminCustomToken = await admin.auth().createCustomToken(adminUid);

  const customerIdToken = await exchangeCustomTokenForIdToken({ authEmulatorHost: authHost, customToken: customerCustomToken });
  const adminIdToken = await exchangeCustomTokenForIdToken({ authEmulatorHost: authHost, customToken: adminCustomToken });

  // Call decision
  const decisionResult = await callCallable({
    projectId,
    region,
    name: 'processClaimDecision',
    idToken: customerIdToken,
    data: { claimId },
  });

  const claimAfterDecision = await db.collection('claims').doc(claimId).get();
  const claimData1 = claimAfterDecision.data() || {};
  if (claimData1.status !== 'processing' && claimData1.status !== 'denied') {
    throw new Error(`Unexpected claim status after decision: ${claimData1.status}`);
  }

  // Simulate admin approval (minimal): set processing and humanOverride
  await db.collection('claims').doc(claimId).set({
    status: 'processing',
    humanOverride: {
      decision: 'approved',
      overriddenBy: adminUid,
      overrideReason: 'E2E test approval',
      overrideTimestamp: admin.firestore.Timestamp.fromDate(new Date()),
    },
    updatedAt: admin.firestore.Timestamp.fromDate(new Date()),
  }, { merge: true });

  // Call payout
  const payoutResult = await callCallable({
    projectId,
    region,
    name: 'processClaimPayout',
    idToken: adminIdToken,
    data: { claimId },
  });

  // Verify settled + payout exists
  const claimAfterPayout = await db.collection('claims').doc(claimId).get();
  const claimData2 = claimAfterPayout.data() || {};

  const payoutsSnap = await db.collection('payouts').where('claimId', '==', claimId).limit(5).get();
  if (payoutsSnap.empty) {
    throw new Error('Expected a payout record but found none');
  }

  const payoutDoc = payoutsSnap.docs[0];
  const payoutData = payoutDoc.data() || {};

  if (claimData2.status !== 'settled') {
    throw new Error(`Expected claim to be settled, got: ${claimData2.status}`);
  }
  if (payoutData.status !== 'completed') {
    throw new Error(`Expected payout to be completed, got: ${payoutData.status}`);
  }

  console.log('✅ E2E CLAIMS EMULATOR TEST PASSED');
  console.log(JSON.stringify({
    projectId,
    claimId,
    decisionResult,
    payoutResult,
    claimStatus: claimData2.status,
    payoutId: payoutDoc.id,
    payoutStatus: payoutData.status,
  }, null, 2));
}

main().catch((err) => {
  console.error('❌ E2E CLAIMS EMULATOR TEST FAILED');
  console.error(err);
  process.exit(1);
});
