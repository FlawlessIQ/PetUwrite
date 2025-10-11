/**
 * Send Analytics Email Cloud Function
 * 
 * Sends claims analytics reports via SendGrid with CSV attachment
 */

const functions = require('firebase-functions/v2');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

const db = admin.firestore();

// SendGrid configuration
const SENDGRID_API_KEY = process.env.SENDGRID_API_KEY || '';
const FROM_EMAIL = process.env.FROM_EMAIL || 'noreply@petuwrite.com';
const FROM_NAME = 'PetUwrite Analytics';

/**
 * Send analytics report via email
 * 
 * @callable
 * @param {Object} data - Request data
 * @param {string} data.recipientEmail - Email address to send to
 * @param {string} data.dateRange - Date range description
 * @param {Object} data.analytics - Analytics data object
 * @param {string} data.csvData - CSV file content
 * @param {string} data.timestamp - Report generation timestamp
 * @return {Promise<Object>} Result with success status
 */
exports.sendAnalyticsEmail = functions.https.onCall(async (data, context) => {
  try {
    // Verify authentication
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
        'Only administrators can share analytics reports'
      );
    }

    const {
      recipientEmail,
      dateRange,
      analytics,
      csvData,
      timestamp,
    } = data;

    if (!recipientEmail || !analytics || !csvData) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required fields'
      );
    }

    console.log('Sending analytics email', {
      recipient: recipientEmail,
      dateRange,
      sentBy: context.auth.uid,
    });

    // Format email content
    const emailBody = formatEmailBody(analytics, dateRange, timestamp);
    const emailHtml = formatEmailHtml(analytics, dateRange, timestamp);

    // Send email with SendGrid
    await sendEmailWithSendGrid({
      to: recipientEmail,
      subject: `Claims Analytics Report - ${dateRange}`,
      text: emailBody,
      html: emailHtml,
      csvData,
      csvFilename: `claims_analytics_${Date.now()}.csv`,
    });

    // Log the share event
    await db.collection('analytics_shares').add({
      recipientEmail,
      dateRange,
      sharedBy: context.auth.uid,
      sharedAt: admin.firestore.FieldValue.serverTimestamp(),
      reportType: 'claims_analytics',
    });

    console.log('Analytics email sent successfully');

    return {
      success: true,
      message: 'Analytics report sent successfully',
    };

  } catch (error) {
    console.error('Error sending analytics email', {
      error: error.message,
      stack: error.stack,
    });

    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw new functions.https.HttpsError(
      'internal',
      `Failed to send email: ${error.message}`
    );
  }
});

/**
 * Format plain text email body
 */
function formatEmailBody(analytics, dateRange, timestamp) {
  const totalClaims = analytics.totalClaims || 0;
  const settledCount = analytics.settledCount || 0;
  const totalPaidOut = analytics.totalPaidOut || 0;
  const avgAmount = analytics.averageAmount || 0;
  const autoApprovalRate = (analytics.autoApprovalRate || 0) * 100;

  const fraudData = analytics.fraudDetection || {};
  const fraudAccuracy = (fraudData.accuracy || 0) * 100;

  const settlementData = analytics.settlementMetrics || {};
  const meanSettlement = settlementData.mean || 0;
  const p90Settlement = settlementData.p90 || 0;

  return `
Claims Analytics Report
Date Range: ${dateRange}
Generated: ${new Date(timestamp).toLocaleString()}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SUMMARY METRICS

Total Claims: ${totalClaims}
Settled Claims: ${settledCount}
Auto-Approval Rate: ${autoApprovalRate.toFixed(1)}%

FINANCIAL METRICS

Total Paid Out: $${totalPaidOut.toLocaleString('en-US', {minimumFractionDigits: 2})}
Average Payout: $${avgAmount.toLocaleString('en-US', {minimumFractionDigits: 2})}

AI PERFORMANCE

Fraud Detection Accuracy: ${fraudAccuracy.toFixed(1)}%
Mean Settlement Time: ${formatHours(meanSettlement)}
90th Percentile Settlement: ${formatHours(p90Settlement)}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

A detailed CSV report is attached with complete breakdowns by:
• Breed, Region, and Claim Type
• Time Series Data
• AI Confidence Distribution
• Fraud Detection Details
• Settlement Time Metrics

--
PetUwrite Analytics System
  `.trim();
}

/**
 * Format HTML email body
 */
function formatEmailHtml(analytics, dateRange, timestamp) {
  const totalClaims = analytics.totalClaims || 0;
  const settledCount = analytics.settledCount || 0;
  const totalPaidOut = analytics.totalPaidOut || 0;
  const avgAmount = analytics.averageAmount || 0;
  const autoApprovalRate = (analytics.autoApprovalRate || 0) * 100;

  const fraudData = analytics.fraudDetection || {};
  const fraudAccuracy = (fraudData.accuracy || 0) * 100;

  const settlementData = analytics.settlementMetrics || {};
  const meanSettlement = settlementData.mean || 0;
  const p90Settlement = settlementData.p90 || 0;

  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body {
      font-family: 'Helvetica Neue', Arial, sans-serif;
      line-height: 1.6;
      color: #333;
      max-width: 600px;
      margin: 0 auto;
      padding: 20px;
    }
    .header {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      padding: 30px;
      border-radius: 10px 10px 0 0;
      text-align: center;
    }
    .header h1 {
      margin: 0;
      font-size: 24px;
    }
    .header p {
      margin: 5px 0 0 0;
      opacity: 0.9;
      font-size: 14px;
    }
    .content {
      background: #f8f9fa;
      padding: 30px;
      border-radius: 0 0 10px 10px;
    }
    .section {
      background: white;
      padding: 20px;
      margin-bottom: 20px;
      border-radius: 8px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    .section h2 {
      margin: 0 0 15px 0;
      font-size: 18px;
      color: #667eea;
      border-bottom: 2px solid #667eea;
      padding-bottom: 10px;
    }
    .metric {
      display: flex;
      justify-content: space-between;
      padding: 8px 0;
      border-bottom: 1px solid #eee;
    }
    .metric:last-child {
      border-bottom: none;
    }
    .metric-label {
      font-weight: 500;
      color: #666;
    }
    .metric-value {
      font-weight: bold;
      color: #333;
    }
    .highlight {
      background: #e3f2fd;
      padding: 15px;
      border-radius: 8px;
      border-left: 4px solid #2196f3;
      margin: 15px 0;
    }
    .footer {
      text-align: center;
      margin-top: 30px;
      padding-top: 20px;
      border-top: 1px solid #ddd;
      color: #999;
      font-size: 12px;
    }
    .attachment-note {
      background: #fff3cd;
      border: 1px solid #ffc107;
      border-radius: 8px;
      padding: 15px;
      margin-top: 20px;
    }
  </style>
</head>
<body>
  <div class="header">
    <h1>📊 Claims Analytics Report</h1>
    <p>${dateRange}</p>
    <p>Generated: ${new Date(timestamp).toLocaleString()}</p>
  </div>
  
  <div class="content">
    <div class="section">
      <h2>Summary Metrics</h2>
      <div class="metric">
        <span class="metric-label">Total Claims</span>
        <span class="metric-value">${totalClaims.toLocaleString()}</span>
      </div>
      <div class="metric">
        <span class="metric-label">Settled Claims</span>
        <span class="metric-value">${settledCount.toLocaleString()}</span>
      </div>
      <div class="metric">
        <span class="metric-label">Auto-Approval Rate</span>
        <span class="metric-value">${autoApprovalRate.toFixed(1)}%</span>
      </div>
    </div>

    <div class="section">
      <h2>Financial Metrics</h2>
      <div class="metric">
        <span class="metric-label">Total Paid Out</span>
        <span class="metric-value">$${totalPaidOut.toLocaleString('en-US', {minimumFractionDigits: 2})}</span>
      </div>
      <div class="metric">
        <span class="metric-label">Average Payout</span>
        <span class="metric-value">$${avgAmount.toLocaleString('en-US', {minimumFractionDigits: 2})}</span>
      </div>
    </div>

    <div class="section">
      <h2>AI Performance</h2>
      <div class="metric">
        <span class="metric-label">Fraud Detection Accuracy</span>
        <span class="metric-value">${fraudAccuracy.toFixed(1)}%</span>
      </div>
      <div class="metric">
        <span class="metric-label">Mean Settlement Time</span>
        <span class="metric-value">${formatHours(meanSettlement)}</span>
      </div>
      <div class="metric">
        <span class="metric-label">90th Percentile Settlement</span>
        <span class="metric-value">${formatHours(p90Settlement)}</span>
      </div>
    </div>

    <div class="attachment-note">
      <strong>📎 CSV Report Attached</strong><br>
      A detailed CSV file is attached with complete breakdowns including:
      <ul style="margin: 10px 0 0 0;">
        <li>Payout analysis by breed, region, and claim type</li>
        <li>Time series trends</li>
        <li>AI confidence distribution</li>
        <li>Fraud detection details</li>
        <li>Settlement time percentiles</li>
      </ul>
    </div>
  </div>

  <div class="footer">
    <p>PetUwrite Analytics System</p>
    <p>This report was automatically generated and sent securely.</p>
  </div>
</body>
</html>
  `.trim();
}

/**
 * Send email via SendGrid
 */
async function sendEmailWithSendGrid({
  to,
  subject,
  text,
  html,
  csvData,
  csvFilename,
}) {
  // Create transporter with SendGrid
  const transporter = nodemailer.createTransporter({
    host: 'smtp.sendgrid.net',
    port: 587,
    secure: false,
    auth: {
      user: 'apikey',
      pass: SENDGRID_API_KEY,
    },
  });

  // Prepare email
  const mailOptions = {
    from: `${FROM_NAME} <${FROM_EMAIL}>`,
    to,
    subject,
    text,
    html,
    attachments: [
      {
        filename: csvFilename,
        content: csvData,
        contentType: 'text/csv',
      },
    ],
  };

  // Send email
  const info = await transporter.sendMail(mailOptions);
  console.log('Email sent:', info.messageId);
  
  return info;
}

/**
 * Format hours to human-readable string
 */
function formatHours(hours) {
  if (hours < 1) {
    return `${Math.round(hours * 60)} minutes`;
  } else if (hours < 24) {
    return `${hours.toFixed(1)} hours`;
  } else {
    const days = hours / 24;
    return `${days.toFixed(1)} days`;
  }
}

module.exports = {
  sendAnalyticsEmail: exports.sendAnalyticsEmail,
};
