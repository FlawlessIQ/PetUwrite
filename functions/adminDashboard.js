/**
 * Cloud Functions for Admin Dashboard
 * 
 * Automatic flagging and notifications for high-risk quotes
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

/**
 * Triggered when a new quote is created
 * Automatically flags high-risk quotes (score > 80) for underwriter review
 */
exports.flagHighRiskQuote = functions.firestore
  .document('quotes/{quoteId}')
  .onCreate(async (snap, context) => {
    const quoteData = snap.data();
    const quoteId = context.params.quoteId;
    const riskScore = quoteData.riskScore?.totalScore || 0;

    // Only process high-risk quotes
    if (riskScore <= 80) {
      console.log(`Quote ${quoteId} has acceptable risk score: ${riskScore}`);
      return null;
    }

    console.log(`Flagging high-risk quote ${quoteId} with score ${riskScore}`);

    try {
      // Update quote with flag
      await snap.ref.update({
        flaggedForReview: true,
        flaggedAt: admin.firestore.FieldValue.serverTimestamp(),
        requiresUnderwriterApproval: true,
      });

      // Create notification for underwriters
      await admin.firestore().collection('notifications').add({
        type: 'high_risk_quote',
        quoteId: quoteId,
        riskScore: riskScore,
        petName: quoteData.pet?.name || 'Unknown',
        ownerName: `${quoteData.owner?.firstName || ''} ${quoteData.owner?.lastName || ''}`.trim(),
        aiDecision: quoteData.riskScore?.aiAnalysis?.decision || 'Unknown',
        targetRole: 2, // Underwriter role
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Get all underwriters
      const underwriters = await admin
        .firestore()
        .collection('users')
        .where('userRole', '==', 2)
        .get();

      console.log(`Found ${underwriters.size} underwriters to notify`);

      // Send notifications to each underwriter (optional - requires FCM tokens)
      const notificationPromises = underwriters.docs.map(async (underwriterDoc) => {
        const underwriterData = underwriterDoc.data();
        
        // If user has FCM token, send push notification
        if (underwriterData.fcmToken) {
          return admin.messaging().send({
            token: underwriterData.fcmToken,
            notification: {
              title: '⚠️ High-Risk Quote Pending',
              body: `${quoteData.pet?.name} (Risk: ${riskScore}) requires review`,
            },
            data: {
              type: 'high_risk_quote',
              quoteId: quoteId,
              riskScore: riskScore.toString(),
            },
          });
        }
      });

      await Promise.allSettled(notificationPromises);

      console.log(`Successfully flagged quote ${quoteId} and notified underwriters`);
      return { success: true };
    } catch (error) {
      console.error(`Error flagging quote ${quoteId}:`, error);
      throw error;
    }
  });

/**
 * Triggered when a quote is updated with humanOverride
 * Logs the override and updates statistics
 */
exports.onQuoteOverride = functions.firestore
  .document('quotes/{quoteId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const quoteId = context.params.quoteId;

    // Check if humanOverride was added
    if (!beforeData.humanOverride && afterData.humanOverride) {
      console.log(`Quote ${quoteId} was overridden by underwriter`);

      try {
        // Get current month/year for statistics
        const now = new Date();
        const monthKey = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;

        // Update monthly statistics
        const statsRef = admin.firestore()
          .collection('admin_stats')
          .doc(`overrides_${monthKey}`);

        const statsDoc = await statsRef.get();
        const currentStats = statsDoc.exists ? statsDoc.data() : {
          totalOverrides: 0,
          approved: 0,
          denied: 0,
          moreInfo: 0,
          byUnderwriter: {},
        };

        // Increment counters
        currentStats.totalOverrides++;
        
        const decision = afterData.humanOverride.decision;
        if (decision === 'Approve') {
          currentStats.approved++;
        } else if (decision === 'Deny') {
          currentStats.denied++;
        } else if (decision === 'Request More Info') {
          currentStats.moreInfo++;
        }

        // Track by underwriter
        const underwriterId = afterData.humanOverride.underwriterId;
        if (!currentStats.byUnderwriter[underwriterId]) {
          currentStats.byUnderwriter[underwriterId] = {
            name: afterData.humanOverride.underwriterName,
            count: 0,
            approved: 0,
            denied: 0,
            moreInfo: 0,
          };
        }
        currentStats.byUnderwriter[underwriterId].count++;
        if (decision === 'Approve') {
          currentStats.byUnderwriter[underwriterId].approved++;
        } else if (decision === 'Deny') {
          currentStats.byUnderwriter[underwriterId].denied++;
        } else if (decision === 'Request More Info') {
          currentStats.byUnderwriter[underwriterId].moreInfo++;
        }

        // Update statistics
        await statsRef.set({
          ...currentStats,
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Mark notification as resolved
        const notifications = await admin
          .firestore()
          .collection('notifications')
          .where('quoteId', '==', quoteId)
          .where('type', '==', 'high_risk_quote')
          .get();

        const updatePromises = notifications.docs.map((doc) =>
          doc.ref.update({
            resolved: true,
            resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
            resolvedBy: underwriterId,
          })
        );

        await Promise.all(updatePromises);

        console.log(`Updated statistics for override of quote ${quoteId}`);
        return { success: true };
      } catch (error) {
        console.error(`Error updating override statistics:`, error);
        throw error;
      }
    }

    return null;
  });

/**
 * Scheduled function to generate daily override reports
 * Runs at 9 AM every day
 */
exports.generateDailyOverrideReport = functions.pubsub
  .schedule('0 9 * * *')
  .timeZone('America/New_York')
  .onRun(async (context) => {
    console.log('Generating daily override report');

    try {
      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);
      yesterday.setHours(0, 0, 0, 0);

      const today = new Date();
      today.setHours(0, 0, 0, 0);

      // Get all overrides from yesterday
      const overrides = await admin
        .firestore()
        .collection('audit_logs')
        .where('type', '==', 'quote_override')
        .where('timestamp', '>=', admin.firestore.Timestamp.fromDate(yesterday))
        .where('timestamp', '<', admin.firestore.Timestamp.fromDate(today))
        .get();

      const report = {
        date: yesterday.toISOString().split('T')[0],
        totalOverrides: overrides.size,
        approved: 0,
        denied: 0,
        moreInfo: 0,
        byUnderwriter: {},
        averageResponseTime: 0,
      };

      let totalResponseTime = 0;

      // Process each override
      for (const doc of overrides.docs) {
        const data = doc.data();

        // Count by decision
        if (data.decision === 'Approve') report.approved++;
        else if (data.decision === 'Deny') report.denied++;
        else if (data.decision === 'Request More Info') report.moreInfo++;

        // Count by underwriter
        const underwriterId = data.underwriterId;
        if (!report.byUnderwriter[underwriterId]) {
          report.byUnderwriter[underwriterId] = {
            name: data.underwriterName,
            count: 0,
          };
        }
        report.byUnderwriter[underwriterId].count++;

        // Calculate response time (if quote has createdAt)
        if (data.quoteId) {
          const quoteDoc = await admin
            .firestore()
            .collection('quotes')
            .doc(data.quoteId)
            .get();
          
          if (quoteDoc.exists) {
            const quoteData = quoteDoc.data();
            const quoteCreatedAt = quoteData.createdAt?.toDate();
            const overrideTimestamp = data.timestamp?.toDate();
            
            if (quoteCreatedAt && overrideTimestamp) {
              const responseTimeHours = (overrideTimestamp - quoteCreatedAt) / (1000 * 60 * 60);
              totalResponseTime += responseTimeHours;
            }
          }
        }
      }

      // Calculate average response time
      if (overrides.size > 0) {
        report.averageResponseTime = totalResponseTime / overrides.size;
      }

      // Store report
      await admin
        .firestore()
        .collection('daily_reports')
        .doc(report.date)
        .set({
          ...report,
          generatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

      console.log(`Daily report generated for ${report.date}:`, report);

      // Send email to administrators (optional)
      // Could integrate with SendGrid or similar service here

      return { success: true, report };
    } catch (error) {
      console.error('Error generating daily report:', error);
      throw error;
    }
  });

/**
 * Scheduled function to alert on pending high-risk quotes
 * Runs every 2 hours during business hours
 */
exports.alertPendingQuotes = functions.pubsub
  .schedule('0 */2 * * *')
  .timeZone('America/New_York')
  .onRun(async (context) => {
    console.log('Checking for pending high-risk quotes');

    try {
      // Get quotes pending for more than 4 hours
      const fourHoursAgo = new Date();
      fourHoursAgo.setHours(fourHoursAgo.getHours() - 4);

      const pendingQuotes = await admin
        .firestore()
        .collection('quotes')
        .where('riskScore.totalScore', '>', 80)
        .where('flaggedForReview', '==', true)
        .where('createdAt', '<', admin.firestore.Timestamp.fromDate(fourHoursAgo))
        .get();

      const quotesWithoutOverride = pendingQuotes.docs.filter(
        (doc) => !doc.data().humanOverride
      );

      console.log(`Found ${quotesWithoutOverride.length} pending quotes > 4 hours old`);

      if (quotesWithoutOverride.length === 0) {
        return { message: 'No pending quotes to alert' };
      }

      // Get all underwriters
      const underwriters = await admin
        .firestore()
        .collection('users')
        .where('userRole', '==', 2)
        .get();

      // Send urgent notifications
      const notificationPromises = underwriters.docs.map(async (underwriterDoc) => {
        const underwriterData = underwriterDoc.data();
        
        if (underwriterData.fcmToken) {
          return admin.messaging().send({
            token: underwriterData.fcmToken,
            notification: {
              title: '🚨 Urgent: Pending High-Risk Quotes',
              body: `${quotesWithoutOverride.length} quotes require immediate review`,
            },
            data: {
              type: 'pending_quotes_alert',
              count: quotesWithoutOverride.length.toString(),
            },
          });
        }
      });

      await Promise.allSettled(notificationPromises);

      return {
        success: true,
        pendingCount: quotesWithoutOverride.length,
      };
    } catch (error) {
      console.error('Error checking pending quotes:', error);
      throw error;
    }
  });

/**
 * HTTP function to get override analytics
 * Callable by admins and underwriters
 */
exports.getOverrideAnalytics = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  // Verify user role (underwriter or admin)
  const userDoc = await admin
    .firestore()
    .collection('users')
    .doc(context.auth.uid)
    .get();

  const userRole = userDoc.data()?.userRole || 0;
  if (userRole < 2) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Insufficient permissions'
    );
  }

  try {
    const { startDate, endDate } = data;

    // Get overrides in date range
    let query = admin
      .firestore()
      .collection('audit_logs')
      .where('type', '==', 'quote_override');

    if (startDate) {
      query = query.where(
        'timestamp',
        '>=',
        admin.firestore.Timestamp.fromDate(new Date(startDate))
      );
    }

    if (endDate) {
      query = query.where(
        'timestamp',
        '<=',
        admin.firestore.Timestamp.fromDate(new Date(endDate))
      );
    }

    const overrides = await query.get();

    // Calculate analytics
    const analytics = {
      totalOverrides: overrides.size,
      approved: 0,
      denied: 0,
      moreInfo: 0,
      byUnderwriter: {},
      byDecision: {},
      averageRiskScore: 0,
      overrideRate: 0, // percentage of AI decisions overridden
    };

    let totalRiskScore = 0;
    let aiApprovalCount = 0;
    let humanApprovalCount = 0;

    overrides.forEach((doc) => {
      const data = doc.data();

      // Count by decision
      if (data.decision === 'Approve') {
        analytics.approved++;
        humanApprovalCount++;
      } else if (data.decision === 'Deny') {
        analytics.denied++;
      } else if (data.decision === 'Request More Info') {
        analytics.moreInfo++;
      }

      // Count by underwriter
      const underwriterId = data.underwriterId;
      if (!analytics.byUnderwriter[underwriterId]) {
        analytics.byUnderwriter[underwriterId] = {
          name: data.underwriterName,
          count: 0,
        };
      }
      analytics.byUnderwriter[underwriterId].count++;

      // Track AI vs human decisions
      const aiDecision = data.aiDecision || '';
      if (aiDecision.includes('Approve')) {
        aiApprovalCount++;
      }

      // Sum risk scores
      if (data.riskScore) {
        totalRiskScore += data.riskScore;
      }
    });

    // Calculate averages
    if (overrides.size > 0) {
      analytics.averageRiskScore = totalRiskScore / overrides.size;
      analytics.overrideRate =
        ((humanApprovalCount - aiApprovalCount) / overrides.size) * 100;
    }

    return analytics;
  } catch (error) {
    console.error('Error getting override analytics:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});
