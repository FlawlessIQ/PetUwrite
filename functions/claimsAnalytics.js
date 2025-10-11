const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const logger = functions.logger;

/**
 * Cloud Function to aggregate claims analytics data
 * 
 * This function provides optimized data aggregation for the admin dashboard
 * avoiding heavy client-side queries and calculations
 * 
 * @callable
 * @param {Object} data - Request parameters
 * @param {string} data.startDate - Start date (ISO string)
 * @param {string} data.endDate - End date (ISO string)
 * @param {string} data.breed - Optional breed filter
 * @param {string} data.ageRange - Optional age range filter
 * @param {string} data.region - Optional region filter
 * @param {string} data.vetProvider - Optional vet provider filter
 * @return {Promise<Object>} Aggregated analytics data
 */
exports.getClaimsAnalytics = functions.https.onCall(async (data, context) => {
  try {
    // Verify authentication (admin only)
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated'
      );
    }

    // Verify admin role
    const userDoc = await db.collection('users').doc(context.auth.uid).get();
    const userRole = userDoc.data()?.userRole;
    
    if (userRole !== 2) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'User must have admin role'
      );
    }

    const {
      startDate,
      endDate,
      breed,
      ageRange,
      region,
      vetProvider,
    } = data;

    // Validate dates
    if (!startDate || !endDate) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Start and end dates are required'
      );
    }

    const start = admin.firestore.Timestamp.fromDate(new Date(startDate));
    const end = admin.firestore.Timestamp.fromDate(new Date(endDate));

    logger.info('Fetching claims analytics', {
      startDate,
      endDate,
      filters: { breed, ageRange, region, vetProvider },
    });

    // Build base query
    let query = db.collection('claims')
      .where('createdAt', '>=', start)
      .where('createdAt', '<=', end);

    // Fetch claims
    const claimsSnapshot = await query.get();
    
    // Apply filters and aggregate
    const analytics = await aggregateClaimsData(
      claimsSnapshot.docs,
      { breed, ageRange, region, vetProvider }
    );

    logger.info('Claims analytics generated', {
      totalClaims: analytics.totalClaims,
      dateRange: `${startDate} to ${endDate}`,
    });

    return analytics;
  } catch (error) {
    logger.error('Error generating claims analytics', {
      error: error.message,
      stack: error.stack,
    });
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      'internal',
      'Failed to generate analytics: ' + error.message
    );
  }
});

/**
 * Aggregate claims data with filters
 * 
 * @param {Array} claimsDocs - Firestore document snapshots
 * @param {Object} filters - Filter criteria
 * @return {Promise<Object>} Aggregated data
 */
async function aggregateClaimsData(claimsDocs, filters) {
  // Initialize aggregation buckets
  const claimsByMonth = {};
  const amountsByMonth = {};
  const autoApprovalByMonth = {};
  const manualReviewByMonth = {};
  
  // AI confidence histogram (10% buckets)
  const confidenceBuckets = {
    '0-10%': 0,
    '10-20%': 0,
    '20-30%': 0,
    '30-40%': 0,
    '40-50%': 0,
    '50-60%': 0,
    '60-70%': 0,
    '70-80%': 0,
    '80-90%': 0,
    '90-100%': 0,
  };
  
  // Payout breakdowns
  const payoutByBreed = {};
  const payoutByRegion = {};
  const payoutByClaimType = {};
  const countByBreed = {};
  const countByRegion = {};
  const countByClaimType = {};
  
  // Time-to-settlement tracking
  const settlementTimes = [];
  
  // Fraud detection tracking
  let aiDenialsCorrect = 0;
  let aiDenialsOverridden = 0;
  
  let autoApproved = 0;
  let manualApproved = 0;
  let denied = 0;
  let pending = 0;
  let totalAmount = 0;
  let settledCount = 0;

  // Apply filters and aggregate
  for (const doc of claimsDocs) {
    const claimData = doc.data();
    
    // Fetch related data for all claims
    const petDoc = await db.collection('pets').doc(claimData.petId).get();
    const petData = petDoc.data();
    const breed = petData?.breed || 'Unknown';
    
    const ownerDoc = await db.collection('users').doc(claimData.ownerId).get();
    const ownerData = ownerDoc.data();
    const region = ownerData?.address?.state || 'Unknown';
    
    // Apply filters
    if (filters.breed && breed !== filters.breed) {
      continue;
    }
    
    if (filters.region && region !== filters.region) {
      continue;
    }
    
    if (filters.vetProvider) {
      const documents = claimData.documents || [];
      const hasProvider = documents.some(d => 
        d.metadata?.providerName === filters.vetProvider
      );
      if (!hasProvider) {
        continue;
      }
    }

    // Aggregate by month
    const createdAt = claimData.createdAt.toDate();
    const monthKey = createdAt.toLocaleDateString('en-US', { 
      year: 'numeric', 
      month: 'short' 
    });
    
    claimsByMonth[monthKey] = (claimsByMonth[monthKey] || 0) + 1;
    
    const amount = claimData.claimAmount || 0;
    const claimType = claimData.claimType || 'Unknown';
    amountsByMonth[monthKey] = (amountsByMonth[monthKey] || 0) + amount;

    // Decision distribution
    const status = claimData.status;
    const aiDecision = claimData.aiDecision;
    const humanOverride = claimData.humanOverride;
    
    if (status === 'settled') {
      const isAutoApproved = !humanOverride && aiDecision === 'approve';
      
      if (isAutoApproved) {
        autoApproved++;
        autoApprovalByMonth[monthKey] = (autoApprovalByMonth[monthKey] || 0) + 1;
      } else {
        manualApproved++;
        manualReviewByMonth[monthKey] = (manualReviewByMonth[monthKey] || 0) + 1;
      }
      
      totalAmount += amount;
      settledCount++;
      
      // Payout breakdowns
      payoutByBreed[breed] = (payoutByBreed[breed] || 0) + amount;
      countByBreed[breed] = (countByBreed[breed] || 0) + 1;
      
      payoutByRegion[region] = (payoutByRegion[region] || 0) + amount;
      countByRegion[region] = (countByRegion[region] || 0) + 1;
      
      payoutByClaimType[claimType] = (payoutByClaimType[claimType] || 0) + amount;
      countByClaimType[claimType] = (countByClaimType[claimType] || 0) + 1;
      
      // Time-to-settlement calculation
      if (claimData.settledAt) {
        const createdTime = claimData.createdAt.toMillis();
        const settledTime = claimData.settledAt.toMillis();
        const timeToSettle = (settledTime - createdTime) / (1000 * 60 * 60); // hours
        settlementTimes.push(timeToSettle);
      }
    } else if (status === 'denied') {
      denied++;
      
      // Fraud detection: AI denied, was it correct?
      if (aiDecision === 'deny') {
        if (!humanOverride || humanOverride.decision === 'deny') {
          aiDenialsCorrect++;
        } else {
          aiDenialsOverridden++;
        }
      }
    } else {
      pending++;
    }

    // AI confidence histogram (10% buckets)
    const aiConfidence = claimData.aiConfidenceScore;
    if (aiConfidence !== null && aiConfidence !== undefined) {
      const bucketIndex = Math.min(Math.floor(aiConfidence * 10), 9);
      const buckets = Object.keys(confidenceBuckets);
      confidenceBuckets[buckets[bucketIndex]]++;
    }
  }

  // Calculate average payouts
  const avgPayoutByBreed = {};
  for (const breed in payoutByBreed) {
    avgPayoutByBreed[breed] = payoutByBreed[breed] / countByBreed[breed];
  }
  
  const avgPayoutByRegion = {};
  for (const region in payoutByRegion) {
    avgPayoutByRegion[region] = payoutByRegion[region] / countByRegion[region];
  }
  
  const avgPayoutByClaimType = {};
  for (const claimType in payoutByClaimType) {
    avgPayoutByClaimType[claimType] = payoutByClaimType[claimType] / countByClaimType[claimType];
  }
  
  // Calculate time-to-settlement percentiles
  let meanSettlementTime = 0;
  let p90SettlementTime = 0;
  let p99SettlementTime = 0;
  
  if (settlementTimes.length > 0) {
    settlementTimes.sort((a, b) => a - b);
    
    meanSettlementTime = settlementTimes.reduce((a, b) => a + b, 0) / settlementTimes.length;
    
    const p90Index = Math.floor(settlementTimes.length * 0.9);
    p90SettlementTime = settlementTimes[p90Index];
    
    const p99Index = Math.floor(settlementTimes.length * 0.99);
    p99SettlementTime = settlementTimes[p99Index];
  }
  
  // Calculate fraud detection ratio
  const totalAIDenials = aiDenialsCorrect + aiDenialsOverridden;
  const fraudDetectionAccuracy = totalAIDenials > 0 
    ? aiDenialsCorrect / totalAIDenials 
    : 0;

  return {
    // Time series data
    claimsByMonth,
    amountsByMonth,
    autoApprovalByMonth,
    manualReviewByMonth,
    
    // Summary counts
    autoApproved,
    manualApproved,
    denied,
    pending,
    totalClaims: autoApproved + manualApproved + denied + pending,
    settledCount,
    
    // Financial metrics
    totalPaidOut: totalAmount,
    averageAmount: settledCount > 0 ? totalAmount / settledCount : 0,
    
    // Payout breakdowns
    avgPayoutByBreed,
    avgPayoutByRegion,
    avgPayoutByClaimType,
    payoutByBreed,
    payoutByRegion,
    payoutByClaimType,
    
    // AI metrics
    confidenceBuckets,
    autoApprovalRate: (autoApproved + manualApproved) > 0 
      ? autoApproved / (autoApproved + manualApproved) 
      : 0,
    
    // Fraud detection
    fraudDetection: {
      aiDenialsCorrect,
      aiDenialsOverridden,
      totalAIDenials,
      accuracy: fraudDetectionAccuracy,
    },
    
    // Time-to-settlement
    settlementMetrics: {
      mean: meanSettlementTime,
      p90: p90SettlementTime,
      p99: p99SettlementTime,
      count: settlementTimes.length,
    },
  };
}

/**
 * Scheduled function to update cached analytics daily
 * Runs every day at midnight PST
 */
exports.updateClaimsAnalyticsCache = functions.pubsub
  .schedule('0 0 * * *')
  .timeZone('America/Los_Angeles')
  .onRun(async (context) => {
    try {
      logger.info('Starting scheduled claims analytics cache update');

      const now = new Date();
      const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
      const ninetyDaysAgo = new Date(now.getTime() - 90 * 24 * 60 * 60 * 1000);

      // Generate analytics for last 30 days
      const thirtyDayAnalytics = await generateAnalyticsForRange(thirtyDaysAgo, now);
      
      // Generate analytics for last 90 days
      const ninetyDayAnalytics = await generateAnalyticsForRange(ninetyDaysAgo, now);

      // Store in cache collection
      await db.collection('analytics_cache').doc('claims_30_days').set({
        ...thirtyDayAnalytics,
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
        range: '30_days',
      });

      await db.collection('analytics_cache').doc('claims_90_days').set({
        ...ninetyDayAnalytics,
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
        range: '90_days',
      });

      logger.info('Claims analytics cache updated successfully');
    } catch (error) {
      logger.error('Error updating claims analytics cache', {
        error: error.message,
        stack: error.stack,
      });
    }
  });

/**
 * Helper function to generate analytics for a date range
 * 
 * @param {Date} startDate - Start date
 * @param {Date} endDate - End date
 * @return {Promise<Object>} Analytics data
 */
async function generateAnalyticsForRange(startDate, endDate) {
  const start = admin.firestore.Timestamp.fromDate(startDate);
  const end = admin.firestore.Timestamp.fromDate(endDate);

  const claimsSnapshot = await db.collection('claims')
    .where('createdAt', '>=', start)
    .where('createdAt', '<=', end)
    .get();

  return await aggregateClaimsData(claimsSnapshot.docs, {});
}

module.exports = {
  getClaimsAnalytics: exports.getClaimsAnalytics,
  updateClaimsAnalyticsCache: exports.updateClaimsAnalyticsCache,
};
