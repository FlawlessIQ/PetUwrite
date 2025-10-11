# Declined Quote Notifications - Quick Setup

## 🚀 5-Minute Setup Guide

**Status:** ✅ Code Ready - Configuration Needed

---

## 📋 Prerequisites

- Firebase project configured
- Firebase CLI installed (`npm install -g firebase-tools`)
- Slack workspace (optional)
- SendGrid account (optional)

---

## ⚡ Quick Start

### **Step 1: Get Webhook URLs**

#### **Slack Webhook** (Optional)

1. Go to: https://api.slack.com/messaging/webhooks
2. Click **"Create New Webhook"**
3. Select channel (e.g., `#alerts` or `#underwriting`)
4. Copy webhook URL (looks like: `https://hooks.slack.com/services/T00/B00/XXX`)

#### **SendGrid API Key** (Optional)

1. Go to: https://app.sendgrid.com/settings/api_keys
2. Click **"Create API Key"**
3. Name: "PetUwrite Notifications"
4. Permissions: **Mail Send** (Full Access)
5. Copy API key (starts with `SG.`)

---

### **Step 2: Configure Environment**

```bash
# Navigate to functions directory
cd functions

# Set Slack webhook (optional)
firebase functions:config:set slack.webhook_url="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

# Set SendGrid API key (optional)
firebase functions:config:set sendgrid.api_key="SG.YOUR_SENDGRID_API_KEY"

# Set notification email
firebase functions:config:set sendgrid.notification_email="admin@petuwrite.com"

# View current config
firebase functions:config:get
```

**Alternative: Use .env file (local development)**

```bash
# Create .env file in functions directory
echo 'SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"' > .env
echo 'SENDGRID_API_KEY="SG.YOUR_SENDGRID_API_KEY"' >> .env
echo 'NOTIFICATION_EMAIL="admin@petuwrite.com"' >> .env
```

---

### **Step 3: Deploy Function**

```bash
# Install dependencies (if not already done)
npm install

# Deploy only this function
firebase deploy --only functions:onQuoteDeclined

# Or deploy all functions
firebase deploy --only functions
```

**Expected Output:**

```
✔  functions[onQuoteDeclined(us-central1)] Successful create operation. 
Function URL: https://us-central1-YOUR-PROJECT.cloudfunctions.net/onQuoteDeclined

✔  Deploy complete!
```

---

### **Step 4: Test It**

#### **Option A: Test in Firestore Console**

1. Go to Firebase Console → Firestore
2. Navigate to `quotes` collection
3. Create or update a document:

```json
{
  "pet": {
    "name": "Test Dog",
    "breed": "Golden Retriever",
    "age": 9
  },
  "owner": {
    "firstName": "Test",
    "lastName": "User",
    "email": "test@example.com"
  },
  "riskScore": {
    "totalScore": 92,
    "riskLevel": "very_high"
  },
  "eligibility": {
    "eligible": false,
    "status": "declined",
    "reason": "Risk score of 92 exceeds maximum allowed score of 85",
    "ruleViolated": "maxRiskScore",
    "violatedValue": 92,
    "checkedAt": "2025-10-10T14:30:00Z"
  }
}
```

4. **Save** - Function should trigger automatically

#### **Option B: Test from Flutter App**

Run the eligibility check in your app - it will automatically trigger when a quote is declined.

---

### **Step 5: Verify**

#### **Check Slack** (if configured)
- Go to your Slack channel
- Look for message: "🚫 Quote Declined - Eligibility Check Failed"

#### **Check Email** (if configured)
- Check inbox for: admin@petuwrite.com
- Subject: "🚫 Quote Declined: Test Dog - maxRiskScore"

#### **Check Firebase Logs**

```bash
# View real-time logs
firebase functions:log --only onQuoteDeclined --follow

# View recent logs
firebase functions:log --only onQuoteDeclined
```

**Expected Log Output:**

```
onQuoteDeclined: Quote declined - triggering notification
onQuoteDeclined: Processing declined quote notification
onQuoteDeclined: Slack notification sent successfully
onQuoteDeclined: SendGrid email sent successfully
onQuoteDeclined: Quote decline processed successfully
```

---

## 🎯 Configuration Options

### **Required (At Least One)**

You must configure **at least one** notification channel:

- ✅ Slack webhook **OR**
- ✅ SendGrid API key

If neither is configured, the function will still run but skip notifications.

### **Optional Settings**

```bash
# Change notification email recipient
firebase functions:config:set sendgrid.notification_email="other@example.com"

# Add multiple recipients (comma-separated)
firebase functions:config:set sendgrid.notification_email="admin@petuwrite.com,manager@petuwrite.com"
```

---

## 🔍 Troubleshooting

### **Problem: Function Not Triggering**

**Check:**
1. Function deployed successfully?
   ```bash
   firebase functions:list | grep onQuoteDeclined
   ```

2. Document structure correct?
   - Must have `eligibility.status == "declined"`
   - Must have `eligibility.eligible == false`

3. Check logs:
   ```bash
   firebase functions:log --only onQuoteDeclined
   ```

---

### **Problem: Slack Message Not Received**

**Check:**
1. Webhook URL correct?
   ```bash
   firebase functions:config:get slack
   ```

2. Test webhook manually:
   ```bash
   curl -X POST -H 'Content-type: application/json' \
     --data '{"text":"Test message"}' \
     YOUR_SLACK_WEBHOOK_URL
   ```

3. Check Slack channel settings (bot permissions)

---

### **Problem: Email Not Received**

**Check:**
1. SendGrid API key valid?
   ```bash
   firebase functions:config:get sendgrid
   ```

2. Check SendGrid dashboard for bounce/errors

3. Verify sender domain (notifications@petuwrite.com)

4. Check spam folder

5. Test SendGrid API:
   ```bash
   curl -X POST https://api.sendgrid.com/v3/mail/send \
     -H "Authorization: Bearer YOUR_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"personalizations":[{"to":[{"email":"test@example.com"}]}],"from":{"email":"test@example.com"},"subject":"Test","content":[{"type":"text/plain","value":"Test"}]}'
   ```

---

### **Problem: Function Times Out**

**Check:**
1. Network connectivity in Cloud Function
2. Webhook URLs accessible from Google Cloud
3. Increase timeout (default: 60s):
   ```javascript
   // In index.js
   exports.onQuoteDeclined = onDocumentUpdated(
     {
       document: "quotes/{quoteId}",
       timeoutSeconds: 120,  // Increase to 120 seconds
     },
     async (event) => { ... }
   );
   ```

---

## 📊 Monitoring

### **View Function Metrics**

1. Firebase Console → Functions
2. Click **onQuoteDeclined**
3. View:
   - Invocations per day
   - Execution time
   - Error rate
   - Memory usage

### **Set Up Alerts**

1. Firebase Console → Functions → **onQuoteDeclined**
2. Click **"Set up alert"**
3. Configure:
   - Error rate > 10%
   - Execution time > 10s
   - Send to: your email

---

## 🔄 Updates & Maintenance

### **Update Notification Template**

1. Edit `functions/declinedQuoteNotifications.js`
2. Modify Slack blocks or email HTML
3. Deploy:
   ```bash
   firebase deploy --only functions:onQuoteDeclined
   ```

### **Change Webhook URL**

```bash
# Update Slack webhook
firebase functions:config:set slack.webhook_url="NEW_URL"

# Redeploy
firebase deploy --only functions:onQuoteDeclined
```

### **Rotate API Keys**

```bash
# Update SendGrid key
firebase functions:config:set sendgrid.api_key="NEW_KEY"

# Redeploy
firebase deploy --only functions:onQuoteDeclined
```

---

## 📝 Environment Variables Summary

| Variable | Required | Default | Example |
|----------|----------|---------|---------|
| `SLACK_WEBHOOK_URL` | No | - | `https://hooks.slack.com/...` |
| `SENDGRID_API_KEY` | No | - | `SG.abc123...` |
| `NOTIFICATION_EMAIL` | No | `admin@petuwrite.com` | `admin@petuwrite.com` |

**Note:** At least one notification channel (Slack OR SendGrid) should be configured.

---

## 🎨 Customization

### **Change Slack Channel**

Create a new webhook for a different channel in Slack settings.

### **Add More Recipients**

Modify `declinedQuoteNotifications.js`:

```javascript
const recipients = [
  { email: "admin@petuwrite.com", name: "Admin" },
  { email: "underwriter@petuwrite.com", name: "Underwriter" },
];

// In sendEmailNotification function
personalizations: [
  {
    to: recipients,
    subject: "...",
  },
],
```

### **Filter by Rule**

Only notify for certain rules:

```javascript
// In index.js, onQuoteDeclined function
const criticalRules = ['maxRiskScore', 'criticalConditions'];

if (!criticalRules.includes(afterEligibility.ruleViolated)) {
  logger.info("Not a critical rule, skipping notification");
  return null;
}
```

---

## ✅ Checklist

### **Before Deployment**
- [ ] Firebase CLI installed
- [ ] Functions directory has package.json
- [ ] `npm install` completed
- [ ] Slack webhook obtained (optional)
- [ ] SendGrid API key obtained (optional)
- [ ] Environment variables configured

### **After Deployment**
- [ ] Function deployed successfully
- [ ] Test quote created in Firestore
- [ ] Slack notification received (if configured)
- [ ] Email notification received (if configured)
- [ ] Logs show successful execution
- [ ] Analytics event logged
- [ ] No errors in Firebase Console

---

## 🆘 Support

### **Common Commands**

```bash
# View logs
firebase functions:log --only onQuoteDeclined

# View config
firebase functions:config:get

# Delete function
firebase functions:delete onQuoteDeclined

# Redeploy function
firebase deploy --only functions:onQuoteDeclined
```

### **Debug Mode**

Add more logging:

```javascript
// In declinedQuoteNotifications.js
logger.info("Debug info", {
  quoteId,
  eligibility,
  slackConfigured: !!slackWebhookUrl,
  emailConfigured: !!sendGridApiKey,
});
```

---

## 🎉 Success!

If you received notifications on both Slack and email, you're all set! 

**Your admin team will now receive instant alerts when quotes are declined.**

---

## 📚 More Resources

- Full Documentation: `DECLINED_QUOTE_NOTIFICATIONS_GUIDE.md`
- Firebase Functions Docs: https://firebase.google.com/docs/functions
- Slack Webhooks: https://api.slack.com/messaging/webhooks
- SendGrid API: https://docs.sendgrid.com/api-reference

---

**Questions?** Check the full guide or Firebase Functions logs for detailed information.

Happy monitoring! 🚀📬
