# Policy Cloud Functions Setup Guide

This document explains the Cloud Functions for policy email notifications and PDF generation.

## 📋 Overview

The policy functions handle:
1. **Policy Email Notifications** - Send welcome emails with policy details
2. **PDF Generation** - Create and store policy documents
3. **Expiration Reminders** - Automated daily checks for expiring policies

## 🔧 Setup Instructions

### 1. Install Dependencies

Navigate to the functions directory and install required packages:

```bash
cd functions
npm install nodemailer pdfkit @google-cloud/storage
```

### 2. Configure SendGrid (Email Service)

You need a SendGrid API key for sending emails:

1. Sign up at [SendGrid.com](https://sendgrid.com)
2. Create an API key in Settings → API Keys
3. Configure Firebase Functions environment:

```bash
firebase functions:config:set sendgrid.key="YOUR_SENDGRID_API_KEY"
```

Or set as environment variable:

```bash
export SENDGRID_API_KEY="YOUR_SENDGRID_API_KEY"
```

### 3. Configure Firebase Storage

Ensure Firebase Storage is enabled in your Firebase project:

```bash
firebase use pet-underwriter-ai
```

The storage bucket is automatically configured from your Firebase project.

### 4. Deploy Functions

Deploy all functions to Firebase:

```bash
firebase deploy --only functions
```

Or deploy specific functions:

```bash
firebase deploy --only functions:sendPolicyEmail,functions:generatePolicyPDF,functions:checkExpiringPolicies
```

## 📚 Function Reference

### `sendPolicyEmail`

Sends a policy confirmation email with PDF attachment.

**Type:** HTTPS Callable Function  
**Auth:** Required

**Parameters:**
```javascript
{
  policyId: string,          // Firestore document ID
  policyNumber: string,      // Policy number (e.g., PU2024XXXX)
  recipientEmail: string,    // Owner's email address
  recipientName: string,     // Owner's full name
  policyData: {              // Complete policy object
    policyNumber: string,
    pet: {...},
    owner: {...},
    plan: {...},
    effectiveDate: string,
    expirationDate: string
  }
}
```

**Returns:**
```javascript
{
  success: boolean,
  message: string
}
```

**Example (from Flutter):**
```dart
final result = await FirebaseFunctions.instance
    .httpsCallable('sendPolicyEmail')
    .call({
      'policyId': policy.policyId,
      'policyNumber': policy.policyNumber,
      'recipientEmail': policy.owner.email,
      'recipientName': '${policy.owner.firstName} ${policy.owner.lastName}',
      'policyData': policy.toJson(),
    });
```

**Email Logs:**  
All sent emails are logged in Firestore collection `email_logs` with:
- `policyId`
- `recipientEmail`
- `subject`
- `sentAt` (timestamp)
- `status` ('sent' or 'failed')

---

### `generatePolicyPDF`

Generates a PDF document and uploads to Firebase Storage.

**Type:** HTTPS Callable Function  
**Auth:** Required

**Parameters:**
```javascript
{
  policyId: string,          // Firestore document ID
  policyNumber: string,      // Policy number
  policyData: {              // Complete policy object
    policyNumber: string,
    pet: {...},
    owner: {...},
    plan: {...},
    effectiveDate: string,
    expirationDate: string
  }
}
```

**Returns:**
```javascript
{
  success: boolean,
  pdfUrl: string            // Signed URL (valid for 7 days)
}
```

**Storage Location:**  
PDFs are stored at: `policies/{policyId}/{policyNumber}.pdf`

**Firestore Update:**  
After generation, the policy document is updated with:
- `pdfUrl`: Signed URL for downloading
- `pdfGeneratedAt`: Timestamp

**Example (from Flutter):**
```dart
final result = await FirebaseFunctions.instance
    .httpsCallable('generatePolicyPDF')
    .call({
      'policyId': policyId,
      'policyNumber': policyNumber,
      'policyData': policy.toJson(),
    });

final pdfUrl = result.data['pdfUrl'];
// Open URL in browser or WebView
```

---

### `checkExpiringPolicies`

Scheduled function that runs daily to check for expiring policies and send renewal reminders.

**Type:** Scheduled Function (PubSub)  
**Schedule:** Daily at midnight (00:00 UTC)  
**Auth:** Not applicable (automated)

**Logic:**
1. Queries all active policies expiring within 30 days
2. Sends renewal reminder email to each policy owner
3. Logs results

**Renewal Email:**  
Contains:
- Days remaining until expiration
- Policy number and pet name
- "Renew Now" button linking to renewal page

**Logs:**  
Check Cloud Functions logs:
```bash
firebase functions:log --only checkExpiringPolicies
```

## 📄 PDF Contents

The generated policy PDF includes:

### Header
- Policy title
- Policy number

### Policy Holder Information
- Name, email, phone
- Full address

### Insured Pet Information
- Name, species, breed
- Age, gender, weight

### Coverage Details
- Plan name and tier
- Monthly/annual premium
- Deductible, reimbursement rate
- Annual maximum coverage

### Coverage Period
- Effective date
- Expiration date

### Covered Benefits
- List of all plan features

### Policy Exclusions
- List of all plan exclusions

### Footer
- Terms and conditions notice
- Support contact information
- Generation timestamp

## 📧 Email Template

The policy confirmation email includes:

### Header
- Welcome message with celebration emoji
- Company branding

### Content
- Personalized greeting
- Policy confirmation message
- Policy details box (number, pet, plan, premium, start date)
- "What's Next?" section with 4 steps
- Dashboard CTA button
- Support information (email, phone, live chat)

### Footer
- Company tagline
- Recipient email
- Privacy policy and terms links

### Attachment
- Policy PDF document

## 🧪 Testing

### Test Email Function Locally

```bash
cd functions
npm run serve
```

Then call from your Flutter app in debug mode (it will use the local emulator).

### Test with Firebase Emulator Suite

```bash
firebase emulators:start
```

Configure Flutter to use emulator:
```dart
FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
```

### Test SendGrid Integration

Use SendGrid's test mode to avoid sending real emails during development:

```javascript
// In policyEmails.js, add for development:
if (process.env.NODE_ENV === 'development') {
  mailOptions.to = 'test@example.com'; // Override recipient
}
```

## 🔐 Security Considerations

1. **Authentication Required**  
   Both callable functions verify user authentication using `context.auth`.

2. **Signed URLs**  
   PDF URLs are signed and expire after 7 days for security.

3. **Email Validation**  
   Recipient emails should be validated before calling functions.

4. **API Key Security**  
   Never commit SendGrid API keys to version control.  
   Use Firebase Functions config or environment variables.

5. **Rate Limiting**  
   Consider implementing rate limiting for email sending to prevent abuse.

## 🚨 Error Handling

All functions throw `HttpsError` with appropriate codes:

- `unauthenticated`: User not logged in
- `invalid-argument`: Missing or invalid parameters
- `internal`: Server error (check logs)

Handle in Flutter:
```dart
try {
  final result = await callable.call(params);
} on FirebaseFunctionsException catch (e) {
  if (e.code == 'unauthenticated') {
    // Redirect to login
  } else if (e.code == 'invalid-argument') {
    // Show validation error
  } else {
    // Show generic error
  }
}
```

## 📊 Monitoring

### View Function Logs
```bash
firebase functions:log
```

### Monitor Email Delivery

Check `email_logs` collection in Firestore:
```dart
final logs = await FirebaseFirestore.instance
    .collection('email_logs')
    .where('policyId', isEqualTo: policyId)
    .orderBy('sentAt', descending: true)
    .get();
```

### Track PDF Generation

Check policy documents for `pdfGeneratedAt` field:
```dart
final policy = await FirebaseFirestore.instance
    .collection('policies')
    .doc(policyId)
    .get();

if (policy.data()?['pdfUrl'] != null) {
  print('PDF available: ${policy.data()?['pdfGeneratedAt']}');
}
```

## 🔄 Renewal Flow

When a policy is nearing expiration:

1. `checkExpiringPolicies` detects it (30 days before)
2. Renewal reminder email is sent
3. Email contains "Renew Now" button
4. Button links to: `https://petunderwriter.ai/renew/{policyId}`
5. User completes renewal form
6. New policy is created with 'R' suffix
7. Old policy status updated to 'renewed'

## 💡 Customization

### Change Email Sender

Edit in `policyEmails.js`:
```javascript
from: 'Your Company <noreply@yourdomain.com>'
```

### Modify PDF Layout

Edit `generatePolicyPDFBuffer()` function to customize:
- Colors and fonts
- Section ordering
- Additional information
- Company logo (add image to PDF)

### Change Renewal Window

Edit scheduled function to check different timeframe:
```javascript
// Check 45 days instead of 30
thirtyDaysFromNow.setDate(thirtyDaysFromNow.getDate() + 45);
```

### Add More Email Types

Add new functions for:
- Claim status updates
- Payment reminders
- Policy changes confirmation

## 📝 Next Steps

1. ✅ Deploy functions to Firebase
2. ⚙️ Configure SendGrid API key
3. 🧪 Test with emulator locally
4. 📧 Send test email to yourself
5. 📄 Generate test PDF
6. 🚀 Deploy to production
7. 📊 Monitor logs and email delivery
8. 🎨 Customize email template branding

## 🆘 Troubleshooting

### "SendGrid API key not configured"
```bash
firebase functions:config:set sendgrid.key="YOUR_KEY"
firebase deploy --only functions
```

### "Storage bucket not found"
Check Firebase Storage is enabled in console.

### "PDF generation failed"
Check Cloud Functions logs:
```bash
firebase functions:log --only generatePolicyPDF
```

### "Email not received"
1. Check spam folder
2. Verify email logs in Firestore
3. Check SendGrid dashboard for delivery status
4. Verify recipient email is correct

## 📚 Resources

- [Firebase Cloud Functions Documentation](https://firebase.google.com/docs/functions)
- [SendGrid Node.js Library](https://github.com/sendgrid/sendgrid-nodejs)
- [PDFKit Documentation](https://pdfkit.org/)
- [Nodemailer Documentation](https://nodemailer.com/)
- [Firebase Storage Documentation](https://firebase.google.com/docs/storage)

---

**Questions?** Contact the development team or check the main project README.
