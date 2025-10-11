# Quick Reference - Checkout Flow

## 🚀 Common Operations

### Navigate to Checkout
```dart
Navigator.pushNamed(
  context,
  '/checkout',
  arguments: {
    'pet': selectedPet,
    'selectedPlan': chosenPlan,
  },
);
```

### Send Policy Email
```dart
await PolicyService.sendPolicyEmail(
  recipientEmail: 'owner@example.com',
  policyData: policy.toJson(),
);
```

### Generate PDF
```dart
final result = await PolicyService.generatePolicyPDF(
  policyId: 'policy_123',
  policyNumber: 'PU2024XXXX',
  policyData: policy.toJson(),
);
final pdfUrl = result['pdfUrl'];
```

### Create Policy
```dart
final policy = await PolicyService.createPolicy(
  ownerId: user.uid,
  petId: pet.id,
  pet: pet,
  owner: ownerDetails,
  plan: selectedPlan,
  paymentInfo: paymentInfo,
);
```

### Get User's Policies
```dart
final policies = await PolicyService.getUserPolicies(user.uid);
```

---

## 🔧 Configuration Commands

### Set SendGrid Key
```bash
firebase functions:config:set sendgrid.key="YOUR_KEY"
```

### Deploy Functions
```bash
firebase deploy --only functions
```

### View Logs
```bash
firebase functions:log
```

### Start Emulator
```bash
firebase emulators:start
```

---

## 🧪 Stripe Test Cards

| Purpose | Card Number | Result |
|---------|-------------|--------|
| Success | 4242 4242 4242 4242 | ✅ Approved |
| Decline | 4000 0000 0000 0002 | ❌ Declined |
| Insufficient | 4000 0000 0000 9995 | ⚠️ Insufficient Funds |

**Details**: Any future expiry, any CVC

---

## 📂 Key File Locations

```
lib/
├── models/
│   └── checkout_state.dart          # State models
├── screens/
│   ├── checkout_screen.dart         # Main container
│   ├── review_screen.dart           # Step 1
│   ├── owner_details_screen.dart    # Step 2
│   ├── payment_screen.dart          # Step 3
│   └── confirmation_screen.dart     # Step 4
└── services/
    └── policy_service.dart          # Firestore ops

functions/
├── policyEmails.js                  # Email/PDF functions
└── index.js                         # Exports
```

---

## 🔥 Firestore Structure

```
/policies/{policyId}
  - policyNumber: "PU2024XXXX"
  - ownerId: "user123"
  - pet: {...}
  - owner: {...}
  - plan: {...}
  - effectiveDate: "2024-01-15"
  - expirationDate: "2025-01-15"
  - status: "active"
  - pdfUrl: "https://..."
  - createdAt: timestamp

/users/{userId}/policies/{policyId}
  - Reference to main policy

/email_logs/{logId}
  - policyId: "policy_123"
  - recipientEmail: "owner@example.com"
  - sentAt: timestamp
  - status: "sent"
```

---

## ⚠️ Error Handling

```dart
try {
  await PolicyService.sendPolicyEmail(...);
} on FirebaseFunctionsException catch (e) {
  switch (e.code) {
    case 'unauthenticated':
      // Redirect to login
      break;
    case 'invalid-argument':
      // Show validation error
      break;
    default:
      // Show generic error
  }
}
```

---

## 📊 Cloud Functions

| Function | Type | Purpose |
|----------|------|---------|
| `sendPolicyEmail` | Callable | Send confirmation email |
| `generatePolicyPDF` | Callable | Create PDF document |
| `checkExpiringPolicies` | Scheduled | Daily renewal check |

---

## 📧 Email Templates

### Policy Confirmation
- Sent after policy creation
- Includes PDF attachment
- Contains "What's Next" steps
- Has dashboard CTA button

### Renewal Reminder
- Sent 30 days before expiry
- Yellow warning banner
- "Renew Now" button
- Automated daily check

---

## 🎯 Deployment Checklist

- [ ] Install dependencies (`flutter pub get`, `npm install`)
- [ ] Configure SendGrid key
- [ ] Deploy Cloud Functions
- [ ] Deploy Firestore rules
- [ ] Deploy Storage rules
- [ ] Test checkout flow
- [ ] Verify email delivery
- [ ] Test PDF download
- [ ] Monitor logs
- [ ] Go live!

---

## 📞 Quick Links

- **Setup Guide**: POLICY_FUNCTIONS_SETUP.md
- **Integration Guide**: FLUTTER_INTEGRATION_GUIDE.md
- **Deployment**: DEPLOYMENT_CHECKLIST.md
- **Full Summary**: CHECKOUT_FLOW_SUMMARY.md

---

## 💡 Pro Tips

1. **Use Emulator for Testing**: Avoid production costs
2. **Cache PDF URLs**: Don't regenerate unnecessarily
3. **Retry Failed Emails**: Network issues are common
4. **Log Everything**: Track email delivery and downloads
5. **Monitor Functions**: Check logs regularly

---

## 🔒 Security Notes

- Always verify user ownership before policy access
- Use signed URLs with expiration for PDFs
- Validate email addresses before sending
- Keep API keys in environment variables
- Never commit secrets to Git

---

**Need more details?** Check the full documentation files!
