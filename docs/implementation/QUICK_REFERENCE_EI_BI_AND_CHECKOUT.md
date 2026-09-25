> **Two documents in one file.** Its first line is the run-together heading of
> two separate quick references — "Emotional Intelligence + BI Panel Integration"
> and "Checkout Flow" — which were concatenated at some point before
> 2025-10-10. Both halves are still readable and neither is maintained; the
> systems themselves are documented in
> [`EMOTIONAL_INTELLIGENCE_SYSTEM.md`](EMOTIONAL_INTELLIGENCE_SYSTEM.md) and
> [`BI_PANEL_SYSTEM.md`](BI_PANEL_SYSTEM.md). Renamed and moved here from the
> repository root on 2026-09-25.

# Quick Reference: Emotional Intelligence + BI Panel Integration# Quick Reference - Checkout Flow



## Quick Start: Using the Widgets## 🚀 Common Operations



### 1. Add Pawla to Any Screen### Navigate to Checkout

```dart

```dartNavigator.pushNamed(

import 'package:pet_underwriter_ai/widgets/pawla_avatar.dart';  context,

import 'package:pet_underwriter_ai/services/claim_tracker_service.dart';  '/checkout',

  arguments: {

// Get dynamic message    'pet': selectedPet,

final message = ClaimTrackerService.getCurrentMessage(claim);    'selectedPlan': chosenPlan,

  },

// Display);

PawlaAvatar(```

  expression: message.expression,

  size: 120,### Send Policy Email

  message: message.message,```dart

  animated: true,await PolicyService.sendPolicyEmail(

)  recipientEmail: 'owner@example.com',

```  policyData: policy.toJson(),

);

### 2. Add Claim Timeline```



```dart### Generate PDF

import 'package:pet_underwriter_ai/widgets/claim_timeline_widget.dart';```dart

final result = await PolicyService.generatePolicyPDF(

ClaimTimelineWidget(claim: claim)  policyId: 'policy_123',

```  policyNumber: 'PU2024XXXX',

  policyData: policy.toJson(),

### 3. Add AI Explainability);

final pdfUrl = result['pdfUrl'];

```dart```

import 'package:pet_underwriter_ai/widgets/ai_explainability_widget.dart';

### Create Policy

if (claim.aiDecision != null) {```dart

  AIExplainabilityWidget(claim: claim)final policy = await PolicyService.createPolicy(

}  ownerId: user.uid,

```  petId: pet.id,

  pet: pet,

### 4. Add Sentiment Feedback  owner: ownerDetails,

  plan: selectedPlan,

```dart  paymentInfo: paymentInfo,

import 'package:pet_underwriter_ai/widgets/sentiment_feedback_widget.dart';);

```

if (claim.status == ClaimStatus.settled || claim.status == ClaimStatus.denied) {

  SentimentFeedbackWidget(claim: claim)### Get User's Policies

}```dart

```final policies = await PolicyService.getUserPolicies(user.uid);

```

### 5. Export Analytics CSV

---

```dart

import 'package:pet_underwriter_ai/services/csv_export_service.dart';## 🔧 Configuration Commands



final csvContent = await CSVExportService.exportClaimsAnalytics(### Set SendGrid Key

  analyticsData,```bash

  startDate: startDate,firebase functions:config:set sendgrid.key="YOUR_KEY"

  endDate: endDate,```

);

// Then save to file...### Deploy Functions

``````bash

firebase deploy --only functions

### 6. Email Analytics Report```



```dart### View Logs

import 'package:pet_underwriter_ai/services/analytics_email_service.dart';```bash

firebase functions:log

await AnalyticsEmailService.shareAnalyticsReport(```

  recipientEmail: 'manager@company.com',

  analyticsData: analyticsData,### Start Emulator

  startDate: startDate,```bash

  endDate: endDate,firebase emulators:start

);```

```

---

---

## 🧪 Stripe Test Cards

## File Locations Cheat Sheet

| Purpose | Card Number | Result |

### Emotional Intelligence|---------|-------------|--------|

- `lib/widgets/pawla_avatar.dart` - Animated avatar (6 expressions)| Success | 4242 4242 4242 4242 | ✅ Approved |

- `lib/widgets/claim_timeline_widget.dart` - 5-stage timeline| Decline | 4000 0000 0000 0002 | ❌ Declined |

- `lib/widgets/ai_explainability_widget.dart` - Factor analysis| Insufficient | 4000 0000 0000 9995 | ⚠️ Insufficient Funds |

- `lib/widgets/sentiment_feedback_widget.dart` - "Was this fair?"

- `lib/services/claim_tracker_service.dart` - Message generator**Details**: Any future expiry, any CVC



### BI Panel---

- `functions/claimsAnalytics.js` - Analytics aggregation

- `functions/analyticsEmail.js` - Email sending## 📂 Key File Locations

- `lib/services/csv_export_service.dart` - CSV generation

- `lib/services/analytics_email_service.dart` - Email client```

lib/

### Documentation├── models/

- `docs/implementation/EMOTIONAL_INTELLIGENCE_SYSTEM.md` - Full EI guide│   └── checkout_state.dart          # State models

- `docs/implementation/BI_PANEL_SYSTEM.md` - Full BI guide├── screens/

│   ├── checkout_screen.dart         # Main container

---│   ├── review_screen.dart           # Step 1

│   ├── owner_details_screen.dart    # Step 2

## Pawla Expression Quick Pick│   ├── payment_screen.dart          # Step 3

│   └── confirmation_screen.dart     # Step 4

| Situation | Expression | Example Message |└── services/

|-----------|-----------|-----------------|    └── policy_service.dart          # Firestore ops

| Welcome user | `happy` | "Hi! I'm Pawla, let's get started!" |

| Analyzing documents | `working` | "I'm analyzing your 3 documents..." |functions/

| AI processing | `thinking` | "Let me carefully review this..." |├── policyEmails.js                  # Email/PDF functions

| Claim approved | `celebrating` | "🎉 Great news! Claim approved!" |└── index.js                         # Exports

| Claim denied | `empathetic` | "I know this isn't what you hoped for..." |```

| Missing info | `concerned` | "I notice some documents are missing..." |

---

---

## 🔥 Firestore Structure

## Timeline Stage Status

```

| Stage | Complete When | Icon | Color |/policies/{policyId}

|-------|--------------|------|-------|  - policyNumber: "PU2024XXXX"

| Claim Filed | Always | file_upload | Blue |  - ownerId: "user123"

| Documents Review | attachments.length > 0 | description | Purple |  - pet: {...}

| AI Analysis | aiDecision != null | psychology | Teal |  - owner: {...}

| Human Review | override exists OR confidence < 80% | person | Orange |  - plan: {...}

| Final Decision | status == settled/denied | check/cancel | Green/Red |  - effectiveDate: "2024-01-15"

  - expirationDate: "2025-01-15"

---  - status: "active"

  - pdfUrl: "https://..."

## Analytics Metrics At-a-Glance  - createdAt: timestamp



| Metric | What It Means | Ideal Value |/users/{userId}/policies/{policyId}

|--------|--------------|-------------|  - Reference to main policy

| Auto-Approval Rate | % claims approved without human | 80-85% |

| AI Confidence (avg) | How sure AI is on average | > 80% |/email_logs/{logId}

| Fraud Detection Accuracy | % AI denials confirmed by humans | > 85% |  - policyId: "policy_123"

| Time-to-Settlement (mean) | Average hours to settle | < 48h |  - recipientEmail: "owner@example.com"

| Time-to-Settlement (P90) | 90% settle within | < 72h |  - sentAt: timestamp

  - status: "sent"

---```



## Common Integration Patterns---



### Pattern 1: Full Claims Status Screen## ⚠️ Error Handling



```dart```dart

Column(try {

  children: [  await PolicyService.sendPolicyEmail(...);

    PawlaAvatar(...),           // Top: Emotional support} on FirebaseFunctionsException catch (e) {

    ProgressIndicator(...),     // Progress bar  switch (e.code) {

    ClaimTimelineWidget(...),   // Middle: Journey visualization    case 'unauthenticated':

    AIExplainabilityWidget(...),// Bottom: Transparency      // Redirect to login

    SentimentFeedbackWidget(...),// Very bottom: Feedback      break;

  ],    case 'invalid-argument':

)      // Show validation error

```      break;

    default:

### Pattern 2: Real-Time Updates      // Show generic error

  }

```dart}

StreamBuilder<DocumentSnapshot>(```

  stream: FirebaseFirestore.instance.collection('claims').doc(claimId).snapshots(),

  builder: (context, snapshot) {---

    final claim = Claim.fromFirestore(snapshot.data!);

    final message = ClaimTrackerService.getCurrentMessage(claim);## 📊 Cloud Functions

    return PawlaAvatar(expression: message.expression, message: message.message);

  },| Function | Type | Purpose |

)|----------|------|---------|

```| `sendPolicyEmail` | Callable | Send confirmation email |

| `generatePolicyPDF` | Callable | Create PDF document |

### Pattern 3: Analytics Dashboard with Export| `checkExpiringPolicies` | Scheduled | Daily renewal check |



```dart---

Column(

  children: [## 📧 Email Templates

    Row(

      children: [### Policy Confirmation

        ElevatedButton.icon(icon: Icons.download, label: 'Export CSV', onPressed: _exportCsv),- Sent after policy creation

        ElevatedButton.icon(icon: Icons.email, label: 'Email Report', onPressed: _emailReport),- Includes PDF attachment

      ],- Contains "What's Next" steps

    ),- Has dashboard CTA button

    // Charts...

    BarChart(data: avgPayoutByBreed),### Renewal Reminder

    LineChart(data: autoApprovalTrend),- Sent 30 days before expiry

    PieChart(data: fraudDetection),- Yellow warning banner

  ],- "Renew Now" button

)- Automated daily check

```

---

---

## 🎯 Deployment Checklist

## Firestore Collections Used

- [ ] Install dependencies (`flutter pub get`, `npm install`)

| Collection | Purpose | Created By |- [ ] Configure SendGrid key

|-----------|---------|----------|- [ ] Deploy Cloud Functions

| `claims` | Core claim data | User/Admin |- [ ] Deploy Firestore rules

| `claim_feedback` | Sentiment feedback | SentimentFeedbackWidget |- [ ] Deploy Storage rules

| `analytics` | Event logging | Various services |- [ ] Test checkout flow

| `analytics_shares` | Email share audit | sendAnalyticsEmail function |- [ ] Verify email delivery

- [ ] Test PDF download

---- [ ] Monitor logs

- [ ] Go live!

## Environment Setup Checklist

---

### For Emotional Intelligence

- ✅ All widgets in `lib/widgets/` directory## 📞 Quick Links

- ✅ Service in `lib/services/` directory

- ✅ Claim model has required fields (aiDecision, aiConfidenceScore, status, etc.)- **Setup Guide**: POLICY_FUNCTIONS_SETUP.md

- ✅ Firestore rules allow reads/writes to `claim_feedback`- **Integration Guide**: FLUTTER_INTEGRATION_GUIDE.md

- **Deployment**: DEPLOYMENT_CHECKLIST.md

### For BI Panel- **Full Summary**: CHECKOUT_FLOW_SUMMARY.md

- ✅ Cloud Functions deployed (`firebase deploy --only functions`)

- ✅ SendGrid API key configured---

- ✅ Firestore indexes created (see `firestore.indexes.json`)

- ✅ Admin users have `userRole: 'admin'` in Firestore## 💡 Pro Tips

- ✅ Dependencies added to `pubspec.yaml` (csv, path_provider)

1. **Use Emulator for Testing**: Avoid production costs

---2. **Cache PDF URLs**: Don't regenerate unnecessarily

3. **Retry Failed Emails**: Network issues are common

## Testing Checklist4. **Log Everything**: Track email delivery and downloads

5. **Monitor Functions**: Check logs regularly

### Emotional Intelligence

- [ ] Pawla animates smoothly (float + pulse)---

- [ ] Expression changes based on claim status

- [ ] Timeline shows correct stages (all 5)## 🔒 Security Notes

- [ ] Timeline updates in real-time when claim changes

- [ ] Explainability expands/collapses- Always verify user ownership before policy access

- [ ] Factor bars show correct percentages- Use signed URLs with expiration for PDFs

- [ ] Sentiment buttons work (positive/neutral/negative)- Validate email addresses before sending

- [ ] Comment field expands after sentiment selection- Keep API keys in environment variables

- [ ] Feedback saves to Firestore- Never commit secrets to Git

- [ ] Thank-you message shows after submission

- [ ] Duplicate submissions prevented---



### BI Panel**Need more details?** Check the full documentation files!

- [ ] Analytics load within 3 seconds
- [ ] All charts render correctly
- [ ] CSV export downloads file
- [ ] CSV contains all 8 sections
- [ ] Email dialog accepts valid emails
- [ ] Email sends successfully
- [ ] Email contains HTML template
- [ ] CSV attachment included in email
- [ ] Admin-only access enforced
- [ ] Date range filter works
- [ ] Real-time metrics update

---

## Troubleshooting Quick Fixes

### Pawla not showing
- Check `expression` parameter is valid enum value
- Verify `size` > 0
- Ensure parent widget has non-zero constraints

### Timeline not updating
- Verify using StreamBuilder or manual refresh
- Check claim model has updated fields
- Ensure Firestore snapshot listener is active

### CSV export fails
- **Web**: Check popup blocker
- **Mobile**: Grant storage permissions
- **Desktop**: Select writable directory

### Email not sending
- Verify SendGrid API key: `firebase functions:config:get`
- Check sender email verified in SendGrid dashboard
- Review Firebase Functions logs
- Test with curl: `curl -H "Authorization: Bearer YOUR_KEY" https://api.sendgrid.com/v3/scopes`

### Charts showing errors
- Ensure data is not null/NaN
- Verify fl_chart version compatibility
- Check data structure matches chart type

---

## Performance Tips

1. **Cache Analytics**: Store last result, refresh every 5-15 minutes
2. **Lazy Load Charts**: Only render visible sections
3. **Debounce Filters**: Wait 500ms after user stops typing
4. **Use Firestore Snapshots**: Real-time updates without polling
5. **Paginate Large Reports**: Split CSVs over 10MB

---

## Next Steps

### Priority 1: Complete User Experience
1. Find/create `ClaimStatusScreen`
2. Integrate all 5 widgets (Pawla, Timeline, Explainability, Feedback, Progress)
3. Add real-time Firestore snapshot listener
4. Test with sample claims (draft, processing, settled, denied)

### Priority 2: Complete BI Panel
1. Find `ClaimsAnalyticsTab` (1019 lines)
2. Add export CSV button calling `CSVExportService`
3. Add email share button with dialog
4. Update charts to use new 10% confidence buckets
5. Add time-to-settlement chart
6. Add fraud detection pie chart

### Priority 3: Polish
1. Add loading states (skeleton screens)
2. Add error boundaries
3. Add accessibility labels
4. Test on different screen sizes
5. Add unit tests for services

---

## Support Resources

- **Emotional Intelligence**: See `docs/implementation/EMOTIONAL_INTELLIGENCE_SYSTEM.md`
- **BI Panel**: See `docs/implementation/BI_PANEL_SYSTEM.md`
- **Firebase Docs**: https://firebase.google.com/docs
- **fl_chart Docs**: https://pub.dev/packages/fl_chart
- **SendGrid Docs**: https://docs.sendgrid.com

---

## Quick Commands

```bash
# Deploy Cloud Functions
firebase deploy --only functions

# Set SendGrid config
firebase functions:config:set sendgrid.api_key="SG.xxxx"

# View logs
firebase functions:log

# Test analytics locally
firebase emulators:start --only functions,firestore

# Run Flutter app
flutter run

# Generate Firestore indexes
firebase deploy --only firestore:indexes

# Check dependencies
flutter pub get
```

---

## Data Flow Diagram

```
User Submits Claim
        ↓
    [Firestore: claims]
        ↓
    ← Snapshot Listener →
        ↓
 ClaimTrackerService.getCurrentMessage()
        ↓
    PawlaAvatar renders with expression
        ↓
    AI processes claim → aiDecision created
        ↓
    ← Snapshot triggers update →
        ↓
    Timeline shows AI Analysis ✓
    Explainability widget appears
        ↓
    Claim settled/denied
        ↓
    ← Snapshot triggers update →
        ↓
    Pawla: celebrating or empathetic
    SentimentFeedbackWidget appears
        ↓
    User rates fairness → Saves to claim_feedback
        ↓
    Thank-you message shown
```

---

## Code Snippets Library

### Get claim by ID
```dart
final claim = await FirebaseFirestore.instance
  .collection('claims')
  .doc(claimId)
  .get()
  .then((doc) => Claim.fromFirestore(doc));
```

### Listen to claim updates
```dart
FirebaseFirestore.instance
  .collection('claims')
  .doc(claimId)
  .snapshots()
  .listen((snapshot) {
    final claim = Claim.fromFirestore(snapshot);
    setState(() => _claim = claim);
  });
```

### Fetch analytics data
```dart
final callable = FirebaseFunctions.instance.httpsCallable('aggregateClaimsData');
final result = await callable.call({
  'startDate': startDate.toIso8601String(),
  'endDate': endDate.toIso8601String(),
});
final analyticsData = result.data;
```

### Show snackbar
```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('Success!'),
    backgroundColor: Colors.green,
  ),
);
```

### Format currency
```dart
import 'package:intl/intl.dart';

final formatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
final formatted = formatter.format(1250.50); // "$1,250.50"
```

---

## Version History

- **v1.0** (2025-01-15): Initial emotional intelligence system
  - Pawla avatar with 6 expressions
  - Claim timeline with 5 stages
  - AI explainability with factor analysis
  - Sentiment feedback system
  - Real-time message generation

- **v1.1** (2025-01-15): BI panel infrastructure
  - Enhanced analytics aggregation (15+ metrics)
  - CSV export service (8 sections)
  - Email sharing with SendGrid
  - HTML email templates

---

## Success Criteria

### User Experience
- ✅ Users understand where they are in the claims process
- ✅ Users feel supported throughout the journey (Pawla)
- ✅ Users understand why AI made its decision
- ✅ Users can provide feedback on decisions

### Admin Experience
- ✅ Admins can see comprehensive analytics
- ✅ Admins can export reports for external analysis
- ✅ Admins can share reports with stakeholders via email
- ✅ Admins can monitor AI performance and fraud detection

### Technical
- ✅ All widgets compile without errors
- ✅ Real-time updates work correctly
- ✅ Cloud Functions execute within timeout
- ✅ Email delivery rate > 98%
- ✅ CSV exports successfully on all platforms

---

**Ready to integrate!** Start with `ClaimStatusScreen` and add all 5 widgets. 🚀
