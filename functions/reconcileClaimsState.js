/**
 * Cloud Function: reconcileClaimsState
 * 
 * Scheduled function that runs every 15 minutes to:
 * 1. Clear expired review locks (>10 minutes old)
 * 2. Detect and correct orphaned payouts (settling status >30 minutes)
 * 3. Fix claims stuck in inconsistent states
 * 4. Log reconciliation actions for audit trail
 * 
 * Deploy with:
 *   firebase deploy --only functions:reconcileClaimsState
 * 
 * Test with:
 *   firebase functions:shell
 *   > reconcileClaimsState()
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

/**
 * Reconcile claims state - runs every 15 minutes
 * Fixes orphaned payouts, stale locks, and inconsistent states
 */
exports.reconcileClaimsState = functions.pubsub
  .schedule('every 15 minutes')
  .onRun(async (context) => {
    console.log('🔧 Starting claims reconciliation...');
    
    const results = {
      timestamp: new Date().toISOString(),
      expiredLocksCleared: 0,
      orphanedPayoutsFixed: 0,
      staleSettlingFixed: 0,
      errors: [],
    };

    try {
      // Task 1: Clear expired review locks (>10 minutes old)
      results.expiredLocksCleared = await clearExpiredReviewLocks();
      
      // Task 2: Fix orphaned payouts (settling status >30 minutes)
      results.orphanedPayoutsFixed = await fixOrphanedPayouts();
      
      // Task 3: Fix stale settling status (>30 minutes without payout)
      results.staleSettlingFixed = await fixStaleSettlingStatus();
      
      // Log results
      await logReconciliationResults(results);
      
      console.log('✅ Reconciliation completed:', results);
      return results;
      
    } catch (error) {
      console.error('❌ Reconciliation error:', error);
      results.errors.push(error.message);
      await logReconciliationResults(results);
      throw error;
    }
  });

/**
 * Clear expired review locks (>10 minutes old)
 */
async function clearExpiredReviewLocks() {
  const tenMinutesAgo = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() - 10 * 60 * 1000)
  );
  
  const expiredLocksQuery = await db.collection('claims')
    .where('reviewLockedAt', '<', tenMinutesAgo)
    .get();
  
  let clearedCount = 0;
  const batch = db.batch();
  
  expiredLocksQuery.forEach((doc) => {
    batch.update(doc.ref, {
      reviewLockedBy: FieldValue.delete(),
      reviewLockedAt: FieldValue.delete(),
    });
    clearedCount++;
  });
  
  if (clearedCount > 0) {
    await batch.commit();
    console.log(`🔓 Cleared ${clearedCount} expired review locks`);
  }
  
  return clearedCount;
}

/**
 * Fix orphaned payouts - claims in 'settling' status for >30 minutes
 * These may indicate failed payout transactions
 */
async function fixOrphanedPayouts() {
  const thirtyMinutesAgo = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() - 30 * 60 * 1000)
  );
  
  const orphanedQuery = await db.collection('claims')
    .where('status', '==', 'settling')
    .where('updatedAt', '<', thirtyMinutesAgo)
    .get();
  
  let fixedCount = 0;
  
  for (const doc of orphanedQuery.docs) {
    const claimId = doc.id;
    const data = doc.data();
    
    try {
      // Check if payout was actually completed
      const payoutSnapshot = await doc.ref.collection('payouts')
        .where('status', '==', 'completed')
        .limit(1)
        .get();
      
      if (!payoutSnapshot.empty) {
        // Payout exists - mark claim as settled
        await doc.ref.update({
          status: 'settled',
          settledAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          reconciledAt: FieldValue.serverTimestamp(),
          reconciledReason: 'Orphaned settling status with completed payout',
        });
        
        console.log(`✅ Fixed orphaned payout for claim ${claimId} - marked as settled`);
        fixedCount++;
      } else {
        // No payout found - revert to processing
        await doc.ref.update({
          status: 'processing',
          updatedAt: FieldValue.serverTimestamp(),
          reconciledAt: FieldValue.serverTimestamp(),
          reconciledReason: 'Orphaned settling status without payout - reverted',
        });
        
        console.log(`⚠️ Fixed orphaned settling for claim ${claimId} - reverted to processing`);
        fixedCount++;
      }
    } catch (error) {
      console.error(`❌ Error fixing claim ${claimId}:`, error);
    }
  }
  
  return fixedCount;
}

/**
 * Fix stale settling status - should transition to settled or revert
 */
async function fixStaleSettlingStatus() {
  const fifteenMinutesAgo = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() - 15 * 60 * 1000)
  );
  
  const staleQuery = await db.collection('claims')
    .where('status', '==', 'settling')
    .where('updatedAt', '<', fifteenMinutesAgo)
    .get();
  
  let fixedCount = 0;
  
  for (const doc of staleQuery.docs) {
    const claimId = doc.id;
    
    try {
      // Check for any payout records
      const payoutSnapshot = await doc.ref.collection('payouts')
        .orderBy('createdAt', 'desc')
        .limit(1)
        .get();
      
      if (!payoutSnapshot.empty) {
        const payout = payoutSnapshot.docs[0].data();
        
        if (payout.status === 'completed') {
          // Complete the settlement
          await doc.ref.update({
            status: 'settled',
            settledAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
            reconciledAt: FieldValue.serverTimestamp(),
            reconciledReason: 'Stale settling status with completed payout',
          });
          fixedCount++;
        } else if (payout.status === 'failed') {
          // Revert to processing
          await doc.ref.update({
            status: 'processing',
            updatedAt: FieldValue.serverTimestamp(),
            reconciledAt: FieldValue.serverTimestamp(),
            reconciledReason: 'Stale settling status with failed payout',
          });
          fixedCount++;
        }
      }
    } catch (error) {
      console.error(`❌ Error fixing stale settling for claim ${claimId}:`, error);
    }
  }
  
  return fixedCount;
}

/**
 * Log reconciliation results for audit trail
 */
async function logReconciliationResults(results) {
  try {
    await db.collection('system_logs').add({
      type: 'claims_reconciliation',
      timestamp: FieldValue.serverTimestamp(),
      results: results,
    });
  } catch (error) {
    console.error('Failed to log reconciliation results:', error);
  }
}

/**
 * Manual trigger function for testing
 * Call with: firebase functions:shell
 * > manualReconciliation()
 */
exports.manualReconciliation = functions.https.onCall(async (data, context) => {
  // Verify admin authentication
  if (!context.auth || !context.auth.token.admin) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can trigger manual reconciliation'
    );
  }
  
  console.log('🔧 Manual reconciliation triggered by:', context.auth.uid);
  
  const results = {
    timestamp: new Date().toISOString(),
    triggeredBy: context.auth.uid,
    expiredLocksCleared: 0,
    orphanedPayoutsFixed: 0,
    staleSettlingFixed: 0,
    errors: [],
  };

  try {
    results.expiredLocksCleared = await clearExpiredReviewLocks();
    results.orphanedPayoutsFixed = await fixOrphanedPayouts();
    results.staleSettlingFixed = await fixStaleSettlingStatus();
    
    await logReconciliationResults(results);
    
    console.log('✅ Manual reconciliation completed:', results);
    return { success: true, results };
    
  } catch (error) {
    console.error('❌ Manual reconciliation error:', error);
    results.errors.push(error.message);
    await logReconciliationResults(results);
    return { success: false, error: error.message, results };
  }
});
