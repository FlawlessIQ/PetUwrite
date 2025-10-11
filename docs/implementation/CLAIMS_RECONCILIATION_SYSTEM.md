# Claims Reconciliation System - Implementation Guide

## Overview

A comprehensive automated system for maintaining data integrity in the claims pipeline through hourly reconciliation checks, automatic retry logic, and admin escalation workflows.

**Created:** October 10, 2025  
**Status:** ✅ Production Ready

---

## 🎯 Features Implemented

### 1. Hourly Cloud Function: `reconcileClaimsState`

**Location:** `functions/claimsReconciliation.js`

**Schedule:** Runs every hour at :00 (via Cloud Scheduler)

**Core Functions:**
- ✅ Detects mismatched states between claims and payouts
- ✅ Auto-updates claims to 'settled' when payouts are completed
- ✅ Retries failed Stripe/SendGrid operations (max 3 attempts)
- ✅ Escalates unresolvable issues to admin via Slack/Email
- ✅ Logs all operations to `payout_audit_trail` collection

**Key Metrics Tracked:**
- Mismatched states fixed
- Failed operations retried
- Successful retry count
- Escalations to admin
- Execution duration

---

## 📊 System Architecture

### Cloud Function Flow

```
┌─────────────────────────────────────────────────────┐
│         Hourly Trigger (Cloud Scheduler)            │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│    Step 1: Find Mismatched States                   │
│    ─────────────────────────────────                │
│    • Query claims in 'processing' or 'settling'     │
│    • Check for completed payouts                    │
│    • Auto-update claim to 'settled'                 │
│    • Log to audit trail                             │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│    Step 2: Retry Failed Operations                  │
│    ──────────────────────────────                   │
│    • Find payouts with 'failed' status              │
│    • Check retry count (max 3)                      │
│    • Retry Stripe payout with idempotency key       │
│    • Retry SendGrid notifications                   │
│    • Update retry count and status                  │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│    Step 3: Escalate After Max Retries               │
│    ─────────────────────────────────                │
│    • Mark payout as 'escalated'                     │
│    • Send Slack notification                        │
│    • Send email to admin                            │
│    • Log escalation to audit trail                  │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│    Step 4: Log Results & Notify                     │
│    ───────────────────────────                      │
│    • Store run stats in reconciliation_runs         │
│    • Send summary to Slack if significant issues    │
│    • Update system health metrics                   │
└─────────────────────────────────────────────────────┘
```

### Data Flow

```
Firestore Collections:
├── claims/                    (existing)
│   └── {claimId}/
│       ├── status: 'processing' | 'settling' | 'settled'
│       └── reconciledAt: timestamp
│
├── payouts/                   (new - top-level)
│   └── {payoutId}/
│       ├── claimId: string
│       ├── status: 'pending' | 'completed' | 'failed' | 'escalated'
│       ├── retryCount: number (0-3)
│       ├── failureType: 'stripe_payout' | 'sendgrid_notification'
│       ├── idempotencyKey: string
│       └── lastError: string
│
├── payout_audit_trail/        (new)
│   └── {auditId}/
│       ├── type: 'state_reconciliation' | 'retry_attempt' | 'escalation'
│       ├── claimId: string
│       ├── payoutId: string
│       ├── performedBy: 'system' | userId
│       ├── timestamp: timestamp
│       └── metadata: object
│
└── reconciliation_runs/       (new)
    └── {runId}/
        ├── reconciliationId: string
        ├── startedAt: ISO timestamp
        ├── completedAt: ISO timestamp
        ├── mismatchedStatesFixed: number
        ├── failedOperationsRetried: number
        ├── successfulRetries: number
        ├── escalatedToAdmin: number
        ├── durationMs: number
        └── errors: array
```

---

## 🚀 Deployment Instructions

### 1. Set Environment Variables

**Required Firebase Config:**
```bash
firebase functions:config:set \
  stripe.secret_key="sk_live_..." \
  sendgrid.api_key="SG...." \
  slack.webhook_url="https://hooks.slack.com/services/..." \
  admin.email="admin@petuwrite.com"
```

**Verify Config:**
```bash
firebase functions:config:get
```

### 2. Deploy Cloud Functions

```bash
# Deploy only reconciliation function
firebase deploy --only functions:reconcileClaimsState,functions:retryFailedOperation

# Or deploy all functions
firebase deploy --only functions
```

### 3. Deploy Firestore Rules

```bash
firebase deploy --only firestore:rules
```

### 4. Verify Cloud Scheduler

After deployment, verify the scheduled function:

```bash
# Check in Firebase Console:
# Cloud Scheduler → Jobs → reconcileClaimsState
# - Schedule: "0 * * * *" (hourly)
# - Time zone: America/New_York
# - Target: Cloud Function
```

---

## 💻 Frontend Integration

### System Health Widget

**Location:** `lib/widgets/system_health_widget.dart`

**Features:**
- Real-time health score (0-100)
- Visual health indicators (🟢🟡🟠🔴🚨)
- Latest reconciliation statistics
- Failed operations list with retry buttons
- Auto-refresh capability

**Integration:** Added to Admin Dashboard as 5th tab

**Access:** Navigate to Admin Dashboard → "System Health" tab

### Service Layer

**Location:** `lib/services/reconciliation_service.dart`

**Key Methods:**
```dart
// Get latest reconciliation stats
ReconciliationStats stats = await reconciliationService.getLatestReconciliationStats();

// Calculate system health score
SystemHealthScore health = await reconciliationService.calculateSystemHealth();

// Get failed operations
List<FailedOperation> failed = await reconciliationService.getFailedOperations();

// Manually retry a failed payout (admin only)
await reconciliationService.retryFailedPayout(payoutId);
```

---

## 📝 Firestore Rules

Added security rules for new collections:

```javascript
// Payout Audit Trail - Admin read-only
match /payout_audit_trail/{auditId} {
  allow read: if isAdmin();
  allow write: if false; // Only Cloud Functions
}

// Payouts Collection
match /payouts/{payoutId} {
  allow read: if isAdmin() || (
    isAuthenticated() && resource.data.ownerId == request.auth.uid
  );
  allow write: if false; // Only Cloud Functions
}

// Reconciliation Runs - Admin monitoring
match /reconciliation_runs/{runId} {
  allow read: if isAdmin();
  allow write: if false; // Only Cloud Functions
}
```

---

## 🔍 Monitoring & Alerting

### Slack Notifications

**Sent When:**
- Failed operation escalated after 3 retries
- More than 10 mismatched states fixed in one run
- Any escalations occur

**Format:**
```
🚨 Payout Escalation Required

Payout ID: payout_123
Claim ID: claim_456
Amount: $250.00
Retry Count: 3
Failure Type: stripe_payout
Last Error: Request timeout

⚠️ Manual intervention required. Check admin dashboard.
```

### Email Notifications

**Sent To:** Admin email (configured in Firebase)

**Includes:**
- Full escalation details
- Direct link to Firestore document
- Troubleshooting context

### System Health Monitoring

**Health Score Calculation:**
```javascript
Base Score: 100

Deductions:
- Failure rate > 5%: -30 points
- Failure rate > 2%: -20 points
- Failure rate > 1%: -10 points
- More than 5 escalated: -30 points
- More than 2 escalated: -15 points
- Any escalated: -5 points
- Per error in run: -2 points each

Final Score: Clamped to 0-100
```

**Health Status:**
- 🟢 Excellent: 90-100
- 🟡 Good: 75-89
- 🟠 Fair: 50-74
- 🔴 Poor: 25-49
- 🚨 Critical: 0-24

---

## 🧪 Testing

### Manual Testing

**1. Test Mismatched State Detection:**
```javascript
// In Firestore Console:
// 1. Create a claim with status 'processing'
// 2. Create a payout with status 'completed' for that claim
// 3. Wait for next hourly run (or trigger manually)
// 4. Verify claim updated to 'settled'
// 5. Check payout_audit_trail for 'state_reconciliation' entry
```

**2. Test Retry Logic:**
```javascript
// In Firestore Console:
// 1. Create a payout with status 'failed', retryCount: 0
// 2. Set failureType: 'stripe_payout'
// 3. Wait for next hourly run
// 4. Verify retryCount incremented
// 5. Check audit trail for 'retry_attempt'
```

**3. Test Escalation:**
```javascript
// In Firestore Console:
// 1. Create a payout with status 'failed', retryCount: 3
// 2. Wait for next hourly run
// 3. Verify status changed to 'escalated'
// 4. Check Slack/Email for admin notification
// 5. Verify audit trail has 'escalation' entry
```

### Manual Trigger (Cloud Functions Shell)

```bash
# Start Cloud Functions shell
firebase functions:shell

# Trigger reconciliation manually
reconcileClaimsState({})
```

### Frontend Testing

**1. System Health Widget:**
```bash
# Run app and navigate to Admin Dashboard → System Health tab
flutter run

# Should display:
# - Current health score with color-coded indicator
# - Latest reconciliation statistics
# - List of failed operations (if any)
# - Retry buttons for failed operations
```

**2. Manual Retry:**
```dart
// In System Health widget, click "Retry" button on a failed operation
// Should:
// - Call retryFailedOperation Cloud Function
// - Show success/error snackbar
// - Reload data after 2 seconds
// - Update operation status in UI
```

---

## 🐛 Troubleshooting

### Issue: Cloud Function Not Running Hourly

**Check:**
```bash
# Verify Cloud Scheduler job
gcloud scheduler jobs list --project=pet-underwriter-ai

# Check function logs
firebase functions:log --only reconcileClaimsState --limit 50
```

**Fix:**
```bash
# Re-deploy with scheduler
firebase deploy --only functions:reconcileClaimsState

# Manually trigger to test
gcloud scheduler jobs run reconcileClaimsState --project=pet-underwriter-ai
```

### Issue: Stripe API Calls Failing

**Check:**
- Verify Stripe secret key in Firebase config
- Check Stripe account status
- Review Stripe API logs at dashboard.stripe.com

**Logs:**
```bash
# Check function logs for Stripe errors
firebase functions:log | grep "Stripe"
```

### Issue: Notifications Not Sending

**Check:**
- Verify SendGrid API key in Firebase config
- Check Slack webhook URL is valid
- Verify admin email address

**Test:**
```javascript
// In functions/claimsReconciliation.js
// Add test notification at start of function:
await sendAdminNotification({
  type: 'test',
  message: 'Test notification from reconciliation function'
});
```

### Issue: Widget Shows "Error loading system health data"

**Check:**
- Firestore rules allow admin to read reconciliation collections
- User has admin privileges (userRole == 2)
- Collections exist in Firestore

**Debug:**
```dart
// In lib/services/reconciliation_service.dart
// Add debug logging:
print('Fetching reconciliation stats...');
try {
  final snapshot = await _firestore.collection('reconciliation_runs')...
  print('Found ${snapshot.docs.length} runs');
} catch (e) {
  print('Error: $e');
}
```

---

## 📈 Performance Considerations

### Cloud Function Limits

**Current Settings:**
- Memory: 512 MiB
- Timeout: 540 seconds (9 minutes)
- Max instances: 10 (set in setGlobalOptions)

**Expected Performance:**
- Average run time: 5-30 seconds
- Claims processed per run: up to 500
- Payouts checked per run: up to 100

**Scaling:**
If you have more than 500 pending claims, consider:
1. Increase batch size (line 117: `.limit(500)`)
2. Add pagination to process in multiple batches
3. Increase function memory to 1024 MiB

### Firestore Read/Write Costs

**Estimated Per Run:**
- Reads: ~100-200 documents
- Writes: ~10-50 documents (depends on issues found)
- Monthly cost (24 runs/day): ~$0.50-$2.00

**Optimization:**
- Use Firestore query limits to process batches
- Cache recent reconciliation stats
- Only notify admin on significant issues

---

## 🔐 Security Considerations

### Cloud Function Authorization

- Uses Firebase Admin SDK with full Firestore access
- No user authentication required (system function)
- Triggered by Cloud Scheduler (internal)

### Manual Retry Authorization

```javascript
// retryFailedOperation requires admin token
if (!request.auth || !request.auth.token.admin) {
  throw new Error("Unauthorized: Admin access required");
}
```

**How to set admin role:**
```javascript
// In Firebase Admin SDK or Cloud Functions
await admin.auth().setCustomUserClaims(uid, { admin: true });

// In Firestore user document
await db.collection('users').doc(uid).update({ userRole: 2 });
```

### Firestore Rules

All reconciliation collections are:
- ✅ Read-only for admins
- ✅ Write-only for Cloud Functions (via Admin SDK)
- ✅ No public access

---

## 📊 Metrics & KPIs

### Track These Metrics

**Daily:**
- Total reconciliation runs
- Average mismatched states per run
- Failure rate (failed payouts / total payouts)
- Escalation count

**Weekly:**
- System health score trend
- Top failure types
- Average retry success rate
- Payout processing time

**Monthly:**
- Total payouts processed
- Total reconciliation fixes
- Manual intervention rate
- Cost of reconciliation (Firestore + Functions)

### Dashboard Queries

```javascript
// Get reconciliation stats for last 7 days
const last7Days = new Date();
last7Days.setDate(last7Days.getDate() - 7);

const stats = await db.collection('reconciliation_runs')
  .where('timestamp', '>=', last7Days)
  .orderBy('timestamp', 'desc')
  .get();

// Calculate totals
const totals = {
  runs: stats.docs.length,
  statesFixed: 0,
  retries: 0,
  escalations: 0
};

stats.docs.forEach(doc => {
  const data = doc.data();
  totals.statesFixed += data.mismatchedStatesFixed || 0;
  totals.retries += data.successfulRetries || 0;
  totals.escalations += data.escalatedToAdmin || 0;
});
```

---

## 🎓 Future Enhancements

### Potential Improvements

**1. Predictive Alerts**
- ML model to predict payout failures
- Proactive notification before failures occur
- Historical pattern analysis

**2. Auto-Resolution**
- Automatic Stripe payment method updates
- Self-healing retry strategies
- Dynamic retry intervals based on failure type

**3. Advanced Analytics**
- Grafana dashboard integration
- Real-time alerting via PagerDuty
- Failure root cause analysis

**4. Multi-Region Support**
- Replicate reconciliation across regions
- Failover for high availability
- Geographic load balancing

**5. Testing Framework**
- Integration tests with Firebase Emulator
- Automated regression testing
- Performance benchmarking

---

## 📚 References

### Documentation Links

- [Firebase Cloud Functions](https://firebase.google.com/docs/functions)
- [Cloud Scheduler](https://cloud.google.com/scheduler/docs)
- [Firestore Transactions](https://firebase.google.com/docs/firestore/manage-data/transactions)
- [Stripe API - Idempotency](https://stripe.com/docs/api/idempotent_requests)
- [SendGrid API](https://docs.sendgrid.com/api-reference/mail-send/mail-send)

### Related Files

**Cloud Functions:**
- `functions/index.js` - Main exports
- `functions/claimsReconciliation.js` - Reconciliation logic (new)
- `functions/package.json` - Dependencies

**Flutter App:**
- `lib/services/reconciliation_service.dart` - Service layer (new)
- `lib/widgets/system_health_widget.dart` - UI widget (new)
- `lib/screens/admin_dashboard.dart` - Dashboard integration

**Firestore:**
- `firestore.rules` - Security rules (updated)
- `firestore.indexes.json` - Required indexes

---

## ✅ Deployment Checklist

Before deploying to production:

- [ ] Set all Firebase config variables (Stripe, SendGrid, Slack, Admin email)
- [ ] Deploy Cloud Functions with reconciliation logic
- [ ] Deploy updated Firestore rules
- [ ] Verify Cloud Scheduler job is created and active
- [ ] Test manual trigger in Cloud Functions console
- [ ] Verify Slack/Email notifications working
- [ ] Test System Health widget in admin dashboard
- [ ] Monitor first 24 hours of hourly runs
- [ ] Set up alerts for function errors
- [ ] Document any custom configurations
- [ ] Train admin team on System Health dashboard
- [ ] Create runbook for manual interventions

---

## 📞 Support

For issues or questions:

1. Check Firebase Functions logs: `firebase functions:log`
2. Review Firestore audit trail: `payout_audit_trail` collection
3. Check System Health widget for real-time status
4. Review this documentation for troubleshooting steps

**Emergency Contact:** admin@petuwrite.com

---

**Implementation Complete:** October 10, 2025  
**Next Review:** After 7 days of production monitoring
