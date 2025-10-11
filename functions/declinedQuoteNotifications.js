/**
 * Declined Quote Notifications
 * 
 * Sends notifications when a quote is declined by the eligibility system
 * Supports Slack webhook and SendGrid email notifications
 */

const logger = require("firebase-functions/logger");
const axios = require("axios");

/**
 * Send notification to Slack via webhook
 * 
 * @param {Object} quoteData - The quote document data
 * @param {string} quoteId - The quote document ID
 * @param {Object} eligibility - The eligibility object with decline details
 * @return {Promise<boolean>} Success status
 */
async function sendSlackNotification(quoteData, quoteId, eligibility) {
  const slackWebhookUrl = process.env.SLACK_WEBHOOK_URL;

  if (!slackWebhookUrl) {
    logger.warn("SLACK_WEBHOOK_URL not configured, skipping Slack notification");
    return false;
  }

  try {
    const pet = quoteData.pet || {};
    const owner = quoteData.owner || {};
    const riskScore = quoteData.riskScore || {};

    // Format the Slack message
    const message = {
      text: `🚫 New Declined Quote`,
      blocks: [
        {
          type: "header",
          text: {
            type: "plain_text",
            text: "🚫 Quote Declined - Eligibility Check Failed",
            emoji: true,
          },
        },
        {
          type: "section",
          fields: [
            {
              type: "mrkdwn",
              text: `*Pet:*\n${pet.name || "Unknown"} (${pet.breed || "Unknown"}, ${pet.age || "N/A"} years)`,
            },
            {
              type: "mrkdwn",
              text: `*Owner:*\n${owner.firstName || ""} ${owner.lastName || ""}\n${owner.email || "No email"}`,
            },
            {
              type: "mrkdwn",
              text: `*Risk Score:*\n${riskScore.totalScore || "N/A"}/100 (${riskScore.riskLevel || "Unknown"})`,
            },
            {
              type: "mrkdwn",
              text: `*Quote ID:*\n\`${quoteId.substring(0, 12)}...\``,
            },
          ],
        },
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: `*❌ Rule Violated:* \`${eligibility.ruleViolated || "Unknown"}\``,
          },
        },
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: `*Decline Reason:*\n${eligibility.reason || "No reason provided"}`,
          },
        },
        {
          type: "context",
          elements: [
            {
              type: "mrkdwn",
              text: `Declined at: ${new Date(eligibility.checkedAt || Date.now()).toLocaleString()}`,
            },
          ],
        },
        {
          type: "divider",
        },
        {
          type: "actions",
          elements: [
            {
              type: "button",
              text: {
                type: "plain_text",
                text: "View in Admin Dashboard",
                emoji: true,
              },
              url: `https://petuwrite.com/admin/quotes/${quoteId}`,
              style: "primary",
            },
            {
              type: "button",
              text: {
                type: "plain_text",
                text: "Request Review",
                emoji: true,
              },
              url: `https://petuwrite.com/admin/quotes/${quoteId}?action=review`,
              style: "danger",
            },
          ],
        },
      ],
    };

    // Send to Slack
    const response = await axios.post(slackWebhookUrl, message, {
      headers: {"Content-Type": "application/json"},
    });

    if (response.status === 200) {
      logger.info("Slack notification sent successfully", {quoteId});
      return true;
    } else {
      logger.error("Slack notification failed", {
        status: response.status,
        quoteId,
      });
      return false;
    }
  } catch (error) {
    logger.error("Error sending Slack notification", {
      error: error.message,
      quoteId,
    });
    return false;
  }
}

/**
 * Send notification email via SendGrid
 * 
 * @param {Object} quoteData - The quote document data
 * @param {string} quoteId - The quote document ID
 * @param {Object} eligibility - The eligibility object with decline details
 * @return {Promise<boolean>} Success status
 */
async function sendEmailNotification(quoteData, quoteId, eligibility) {
  const sendGridApiKey = process.env.SENDGRID_API_KEY;
  const notificationEmail = process.env.NOTIFICATION_EMAIL || "admin@petuwrite.com";

  if (!sendGridApiKey) {
    logger.warn("SENDGRID_API_KEY not configured, skipping email notification");
    return false;
  }

  try {
    const pet = quoteData.pet || {};
    const owner = quoteData.owner || {};
    const riskScore = quoteData.riskScore || {};

    // Format the email
    const emailData = {
      personalizations: [
        {
          to: [
            {
              email: notificationEmail,
              name: "Admin Team",
            },
          ],
          subject: `🚫 Quote Declined: ${pet.name || "Unknown Pet"} - ${eligibility.ruleViolated || "Unknown Rule"}`,
        },
      ],
      from: {
        email: "notifications@petuwrite.com",
        name: "PetUwrite Alerts",
      },
      content: [
        {
          type: "text/html",
          value: generateEmailHtml(quoteData, quoteId, eligibility, pet, owner, riskScore),
        },
      ],
    };

    // Send via SendGrid
    const response = await axios.post(
        "https://api.sendgrid.com/v3/mail/send",
        emailData,
        {
          headers: {
            "Authorization": `Bearer ${sendGridApiKey}`,
            "Content-Type": "application/json",
          },
        },
    );

    if (response.status === 202) {
      logger.info("SendGrid email sent successfully", {quoteId});
      return true;
    } else {
      logger.error("SendGrid email failed", {
        status: response.status,
        quoteId,
      });
      return false;
    }
  } catch (error) {
    logger.error("Error sending SendGrid email", {
      error: error.message,
      response: error.response?.data,
      quoteId,
    });
    return false;
  }
}

/**
 * Generate HTML email content
 * 
 * @param {Object} quoteData - Full quote data
 * @param {string} quoteId - Quote ID
 * @param {Object} eligibility - Eligibility details
 * @param {Object} pet - Pet data
 * @param {Object} owner - Owner data
 * @param {Object} riskScore - Risk score data
 * @return {string} HTML email content
 */
function generateEmailHtml(quoteData, quoteId, eligibility, pet, owner, riskScore) {
  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif;
      line-height: 1.6;
      color: #333;
      max-width: 600px;
      margin: 0 auto;
      padding: 20px;
    }
    .header {
      background: linear-gradient(135deg, #0A2647 0%, #00C2CB 100%);
      color: white;
      padding: 20px;
      border-radius: 8px 8px 0 0;
      text-align: center;
    }
    .content {
      background: #f8f9fa;
      padding: 20px;
      border: 1px solid #dee2e6;
      border-top: none;
    }
    .alert-box {
      background: #fff3cd;
      border: 2px solid #ffc107;
      border-radius: 8px;
      padding: 15px;
      margin: 20px 0;
    }
    .decline-box {
      background: #f8d7da;
      border: 2px solid #dc3545;
      border-radius: 8px;
      padding: 15px;
      margin: 20px 0;
    }
    .info-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 15px;
      margin: 20px 0;
    }
    .info-item {
      background: white;
      padding: 15px;
      border-radius: 6px;
      border: 1px solid #dee2e6;
    }
    .info-label {
      font-size: 12px;
      color: #6c757d;
      text-transform: uppercase;
      margin-bottom: 5px;
    }
    .info-value {
      font-size: 16px;
      font-weight: 600;
      color: #212529;
    }
    .button {
      display: inline-block;
      padding: 12px 24px;
      margin: 10px 5px;
      background: #0A2647;
      color: white;
      text-decoration: none;
      border-radius: 6px;
      font-weight: 600;
    }
    .button-danger {
      background: #dc3545;
    }
    .footer {
      text-align: center;
      color: #6c757d;
      font-size: 12px;
      margin-top: 20px;
      padding-top: 20px;
      border-top: 1px solid #dee2e6;
    }
  </style>
</head>
<body>
  <div class="header">
    <h1 style="margin: 0;">🚫 Quote Declined</h1>
    <p style="margin: 10px 0 0 0;">Eligibility Check Failed</p>
  </div>
  
  <div class="content">
    <div class="alert-box">
      <strong>⚠️ Action Required:</strong> A quote has been automatically declined by the eligibility system. 
      Review the details below and consider requesting a manual review if appropriate.
    </div>

    <div class="info-grid">
      <div class="info-item">
        <div class="info-label">Pet</div>
        <div class="info-value">${pet.name || "Unknown"}</div>
        <div style="font-size: 14px; color: #6c757d; margin-top: 5px;">
          ${pet.breed || "Unknown"} • ${pet.age || "N/A"} years
        </div>
      </div>
      
      <div class="info-item">
        <div class="info-label">Owner</div>
        <div class="info-value">${owner.firstName || ""} ${owner.lastName || ""}</div>
        <div style="font-size: 14px; color: #6c757d; margin-top: 5px;">
          ${owner.email || "No email"}
        </div>
      </div>
      
      <div class="info-item">
        <div class="info-label">Risk Score</div>
        <div class="info-value">${riskScore.totalScore || "N/A"}/100</div>
        <div style="font-size: 14px; color: #6c757d; margin-top: 5px;">
          ${riskScore.riskLevel || "Unknown"}
        </div>
      </div>
      
      <div class="info-item">
        <div class="info-label">Quote ID</div>
        <div class="info-value" style="font-size: 12px; font-family: monospace;">
          ${quoteId.substring(0, 16)}...
        </div>
      </div>
    </div>

    <div class="decline-box">
      <div style="font-weight: 600; margin-bottom: 10px;">
        ❌ Rule Violated: <code>${eligibility.ruleViolated || "Unknown"}</code>
      </div>
      ${eligibility.violatedValue ? `
        <div style="margin-bottom: 10px;">
          <strong>Violating Value:</strong> ${eligibility.violatedValue}
        </div>
      ` : ""}
      <div style="margin-top: 10px;">
        <strong>Decline Reason:</strong><br/>
        ${eligibility.reason || "No reason provided"}
      </div>
      <div style="margin-top: 10px; font-size: 12px; color: #6c757d;">
        Declined at: ${new Date(eligibility.checkedAt || Date.now()).toLocaleString()}
      </div>
    </div>

    <div style="text-align: center; margin-top: 30px;">
      <a href="https://petuwrite.com/admin/quotes/${quoteId}" class="button">
        📊 View in Admin Dashboard
      </a>
      <a href="https://petuwrite.com/admin/quotes/${quoteId}?action=review" class="button button-danger">
        📝 Request Manual Review
      </a>
    </div>
  </div>

  <div class="footer">
    <p>
      This is an automated notification from PetUwrite.<br/>
      You're receiving this because a quote was declined by the eligibility system.
    </p>
  </div>
</body>
</html>
  `;
}

/**
 * Main handler for declined quote notifications
 * Called by the Cloud Function trigger
 * 
 * @param {Object} quoteData - The quote document data
 * @param {string} quoteId - The quote document ID
 * @return {Promise<Object>} Results of notification attempts
 */
async function handleDeclinedQuoteNotification(quoteData, quoteId) {
  const eligibility = quoteData.eligibility;

  if (!eligibility || eligibility.eligible !== false) {
    logger.warn("Quote is not declined, skipping notification", {quoteId});
    return {success: false, reason: "Quote not declined"};
  }

  if (eligibility.status !== "declined") {
    logger.info("Quote status is not 'declined', skipping notification", {
      quoteId,
      status: eligibility.status,
    });
    return {success: false, reason: "Status not declined"};
  }

  logger.info("Processing declined quote notification", {
    quoteId,
    ruleViolated: eligibility.ruleViolated,
    petName: quoteData.pet?.name,
  });

  // Send notifications in parallel
  const [slackResult, emailResult] = await Promise.all([
    sendSlackNotification(quoteData, quoteId, eligibility),
    sendEmailNotification(quoteData, quoteId, eligibility),
  ]);

  const result = {
    success: slackResult || emailResult,
    slack: slackResult,
    email: emailResult,
    quoteId,
  };

  logger.info("Declined quote notification processing complete", result);

  return result;
}

module.exports = {
  handleDeclinedQuoteNotification,
  sendSlackNotification,
  sendEmailNotification,
};
