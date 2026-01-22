const path = require('path');
const fs = require('fs');
const crypto = require('crypto');

const admin = require('firebase-admin');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { setGlobalOptions } = require('firebase-functions/v2');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

setGlobalOptions({ region: 'us-central1' });

function sha256(input) {
  return crypto.createHash('sha256').update(input).digest('hex');
}

async function isAdminRequest(request) {
  if (!request.auth) return false;

  const tokenAdmin = request.auth.token?.admin === true;
  if (tokenAdmin) return true;

  const uid = request.auth.uid;
  const userDoc = await db.collection('users').doc(uid).get();
  const role = userDoc.data()?.userRole;
  return role === 2 || role === 3 || role === '2' || role === '3';
}

async function requireAdmin(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }

  const ok = await isAdminRequest(request);
  if (!ok) {
    throw new HttpsError('permission-denied', 'Admin access required');
  }
}

function readSeedReference() {
  const filePath = path.join(__dirname, 'benchmark_reference_seed.json');
  const raw = fs.readFileSync(filePath, 'utf8');
  const parsed = JSON.parse(raw);
  return { parsed, raw };
}

function normalizeReference(reference) {
  if (!reference || typeof reference !== 'object') {
    throw new HttpsError('invalid-argument', 'reference must be an object');
  }

  const bands = Array.isArray(reference.bands) ? reference.bands : [];
  const normalizedBands = bands
    .filter((b) => b && typeof b === 'object')
    .map((b) => ({
      metric: String(b.metric || '').trim(),
      low: Number(b.low ?? 0),
      median: Number(b.median ?? 0),
      high: Number(b.high ?? 0),
      unit: b.unit != null ? String(b.unit) : null,
    }))
    .filter((b) => b.metric.length > 0);

  return {
    schemaVersion: Number(reference.schemaVersion ?? 1) || 1,
    asOf: reference.asOf != null ? String(reference.asOf) : null,
    notes: reference.notes != null ? String(reference.notes) : null,
    bands: normalizedBands,
  };
}

async function writeAuditLog({
  action,
  request,
  requestData,
  result,
}) {
  const actorUid = request.auth?.uid || null;
  const actorEmail = request.auth?.token?.email || null;
  const actorAdminClaim = request.auth?.token?.admin === true;

  await db.collection('admin_audit_log').add({
    action,
    actorUid,
    actorEmail,
    actorAdminClaim,
    requestData: requestData ?? null,
    result: result ?? null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/**
 * Admin callable: refresh benchmark reference.
 * - If `reference` is provided, uses it (curated/admin-supplied payload).
 * - Otherwise loads bundled seed JSON.
 * Writes:
 * - /benchmark_reference_versions/{versionId}
 * - /benchmark_reference_current/current
 * Logs:
 * - /admin_audit_log
 */
exports.refreshBenchmarkReference = onCall({ cors: true }, async (request) => {
  await requireAdmin(request);

  const source = request.data?.source != null
    ? String(request.data.source)
    : 'Curated internal reference (seed)';
  const notes = request.data?.notes != null ? String(request.data.notes) : null;

  let reference;
  let canonicalRaw;

  if (request.data?.reference) {
    reference = normalizeReference(request.data.reference);
    canonicalRaw = JSON.stringify(reference);
  } else {
    const seed = readSeedReference();
    reference = normalizeReference(seed.parsed);
    canonicalRaw = JSON.stringify(reference);
  }

  const checksum = sha256(canonicalRaw);
  const versionId = `ref_${new Date().toISOString().replace(/[:.]/g, '-')}_${checksum.slice(0, 8)}`;

  const versionRef = db.collection('benchmark_reference_versions').doc(versionId);
  const currentRef = db.collection('benchmark_reference_current').doc('current');

  await db.runTransaction(async (tx) => {
    tx.set(versionRef, {
      source,
      notes,
      checksum,
      reference,
      bands: reference.bands,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdByUid: request.auth.uid,
    });

    tx.set(
      currentRef,
      {
        activeVersionId: versionId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedByUid: request.auth.uid,
      },
      { merge: true },
    );
  });

  await writeAuditLog({
    action: 'benchmark_reference_refresh',
    request,
    requestData: {
      usedSeed: !request.data?.reference,
      source,
      notes,
    },
    result: {
      versionId,
      checksum,
      bandCount: reference.bands.length,
    },
  });

  return {
    versionId,
    checksum,
    bandCount: reference.bands.length,
  };
});

function safeNumber(n) {
  const v = Number(n);
  if (!Number.isFinite(v)) return 0;
  return v;
}

function daysBetween(start, end) {
  const ms = end.getTime() - start.getTime();
  return Math.max(0, ms / (1000 * 60 * 60 * 24));
}

async function paginateQuery(query, { maxDocs = 20000 }) {
  const docs = [];
  let last = null;

  // Use conservative batching to avoid memory spikes.
  const pageSize = 500;

  while (true) {
    let q = query.limit(pageSize);
    if (last) q = q.startAfter(last);

    const snap = await q.get();
    if (snap.empty) break;

    docs.push(...snap.docs);
    if (docs.length > maxDocs) {
      throw new HttpsError(
        'resource-exhausted',
        `Query exceeded maxDocs=${maxDocs}. Narrow the date range or cohort.`
      );
    }

    last = snap.docs[snap.docs.length - 1];
    if (snap.docs.length < pageSize) break;
  }

  return docs;
}

/**
 * Admin callable: compute a portfolio metrics snapshot for a time window.
 * Reads:
 * - /claims
 * - /policies
 * Writes:
 * - /portfolio_metrics_snapshots/{snapshotId}
 * Logs:
 * - /admin_audit_log
 */
exports.computePortfolioMetricsSnapshot = onCall({ cors: true }, async (request) => {
  await requireAdmin(request);

  const startDate = request.data?.startDate;
  const endDate = request.data?.endDate;
  const cohort = request.data?.cohort != null ? String(request.data.cohort) : null;

  if (!startDate || !endDate) {
    throw new HttpsError('invalid-argument', 'startDate and endDate are required');
  }

  const start = new Date(startDate);
  const end = new Date(endDate);
  if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
    throw new HttpsError('invalid-argument', 'Invalid startDate/endDate');
  }
  if (end.getTime() < start.getTime()) {
    throw new HttpsError('invalid-argument', 'endDate must be >= startDate');
  }

  const startTs = admin.firestore.Timestamp.fromDate(start);
  const endTs = admin.firestore.Timestamp.fromDate(end);

  // Claims in range
  const claimsQuery = db
    .collection('claims')
    .where('createdAt', '>=', startTs)
    .where('createdAt', '<=', endTs)
    .orderBy('createdAt', 'asc');

  const claimDocs = await paginateQuery(claimsQuery, { maxDocs: 20000 });

  let claimsCount = 0;
  let claimsSettledCount = 0;
  let claimsPaidTotal = 0;
  let settlementHoursSum = 0;
  let settlementHoursCount = 0;

  for (const doc of claimDocs) {
    const c = doc.data() || {};

    // Optional cohort filtering: extremely lightweight (string matching)
    if (cohort && cohort.trim().length) {
      const haystack = [
        c.claimType,
        c.status,
        c.policyId,
      ]
        .filter(Boolean)
        .map((x) => String(x).toLowerCase())
        .join(' ');
      if (!haystack.includes(cohort.toLowerCase())) {
        continue;
      }
    }

    claimsCount += 1;

    if (String(c.status || '').toLowerCase() === 'settled') {
      claimsSettledCount += 1;
      claimsPaidTotal += safeNumber(c.claimAmount);

      if (c.createdAt?.toMillis && c.settledAt?.toMillis) {
        const hours = (c.settledAt.toMillis() - c.createdAt.toMillis()) / (1000 * 60 * 60);
        if (Number.isFinite(hours) && hours >= 0) {
          settlementHoursSum += hours;
          settlementHoursCount += 1;
        }
      }
    }
  }

  // Policies (best-effort):
  // - newPolicies in range: createdAt between start/end
  // - activePolicyCount: status == 'active' (no range, to avoid composite index requirements)
  // - totalMonthlyPremium: sum plan.monthlyPremium over those active policies
  const newPoliciesQuery = db
    .collection('policies')
    .where('createdAt', '>=', startTs)
    .where('createdAt', '<=', endTs)
    .orderBy('createdAt', 'asc');

  const newPolicyDocs = await paginateQuery(newPoliciesQuery, { maxDocs: 20000 });

  let newPolicies = 0;
  for (const doc of newPolicyDocs) {
    const p = doc.data() || {};
    if (cohort && cohort.trim().length) {
      const pet = p.pet || {};
      const owner = p.owner || {};
      const plan = p.plan || {};
      const haystack = [
        p.status,
        pet.species,
        pet.breed,
        owner.address?.state,
        plan.name,
        plan.tier,
      ]
        .filter(Boolean)
        .map((x) => String(x).toLowerCase())
        .join(' ');
      if (!haystack.includes(cohort.toLowerCase())) {
        continue;
      }
    }
    newPolicies += 1;
  }

  const activePoliciesQuery = db.collection('policies').where('status', '==', 'active');
  const activePolicyDocs = await paginateQuery(activePoliciesQuery, { maxDocs: 20000 });

  let activePolicyCount = 0;
  let totalMonthlyPremium = 0;
  for (const doc of activePolicyDocs) {
    const p = doc.data() || {};

    if (cohort && cohort.trim().length) {
      const pet = p.pet || {};
      const owner = p.owner || {};
      const plan = p.plan || {};
      const haystack = [
        p.status,
        pet.species,
        pet.breed,
        owner.address?.state,
        plan.name,
        plan.tier,
      ]
        .filter(Boolean)
        .map((x) => String(x).toLowerCase())
        .join(' ');
      if (!haystack.includes(cohort.toLowerCase())) {
        continue;
      }
    }

    activePolicyCount += 1;
    totalMonthlyPremium += safeNumber(p.plan?.monthlyPremium);
  }

  const avgSettlementHours = settlementHoursCount > 0
    ? settlementHoursSum / settlementHoursCount
    : null;

  const periodDays = daysBetween(start, end);
  const periodMonthsApprox = Math.max(1 / 30, periodDays / 30);
  const premiumEarnedApprox = totalMonthlyPremium * periodMonthsApprox;

  const claimFrequency = activePolicyCount > 0 ? claimsCount / activePolicyCount : null;
  const claimSeverity = claimsSettledCount > 0 ? claimsPaidTotal / claimsSettledCount : null;
  const lossRatioApprox = premiumEarnedApprox > 0 ? claimsPaidTotal / premiumEarnedApprox : null;

  // Attach current benchmark version id if present
  const currentSnap = await db.collection('benchmark_reference_current').doc('current').get();
  const benchmarkVersionId = currentSnap.exists ? currentSnap.data()?.activeVersionId : null;

  const snapshotRef = db.collection('portfolio_metrics_snapshots').doc();
  const snapshotId = snapshotRef.id;

  const metrics = {
    activePolicyCount,
    newPolicies,
    totalMonthlyPremium,
    claimsCount,
    claimsSettledCount,
    claimsPaidTotal,
    avgSettlementHours,
    claimFrequency,
    claimSeverity,
    lossRatioApprox,
    premiumEarnedApprox,
    periodDays,
  };

  const filters = {
    startDate: start.toISOString(),
    endDate: end.toISOString(),
    cohort: cohort || null,
  };

  await snapshotRef.set({
    computedAt: admin.firestore.FieldValue.serverTimestamp(),
    computedByUid: request.auth.uid,
    benchmarkVersionId: benchmarkVersionId || null,
    filters,
    metrics,
  });

  await writeAuditLog({
    action: 'portfolio_metrics_snapshot_compute',
    request,
    requestData: filters,
    result: {
      snapshotId,
      benchmarkVersionId: benchmarkVersionId || null,
      metrics: {
        activePolicyCount,
        newPolicies,
        claimsCount,
        claimsSettledCount,
      },
    },
  });

  return {
    snapshotId,
    benchmarkVersionId: benchmarkVersionId || null,
    metrics,
  };
});
