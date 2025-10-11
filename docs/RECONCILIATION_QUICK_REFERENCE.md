# Claims Reconciliation System - Quick Reference

## 🚀 Quick Start

### Deploy
```bash
# Set environment variables
firebase functions:config:set \
  stripe.secret_key="sk_live_..." \
  sendgrid.api_key="SG...." \
  slack.webhook_url="https://hooks.slack.com/..." \
  admin.email="admin@petuwrite.com"

# Deploy functions
firebase deploy --only functions:reconcileClaimsState,functions:retryFailedOperation

# Deploy rules
firebase deploy --only firestore:rules
```

### Access System Health Dashboard
1. Navigate to Admin Dashboard
2. Click "System Health" tab (heart icon)
3. View real-time metrics and failed operations

---

## 📊 Key Metrics

| Metric | Description | Good Value |
|--------|-------------|------------|
| Health Score | Overall system health (0-100) | > 90 |
| Failure Rate | Failed payouts / total payouts | < 1% |
| Escalated | Operations requiring manual fix | 0 |
| Mismatched States | Claims/payouts out of sync | < 5 per hour |

---

## 🔧 Common Operations

### Manually Trigger Reconciliation
```bash
gcloud scheduler jobs run reconcileClaimsState --project=pet-underwriter-ai
```

### Check Function Logs
```bash
firebase functions:log --only reconcileClaimsState --limit 50
```

### Manually Retry Failed Payout
1. Go to System Health dashboard
2. Find failed operation in list
3. Click "Retry" button
4. Confirm action

### View Audit Trail
```javascript
// In Firestore Console
Collections → payout_audit_trail

// Filter by type
type == "state_reconciliation"
type == "retry_attempt"
type == "escalation"
```

---

## 🚨 Alert Thresholds

| Condition | Action |
|-----------|--------|
| Health Score < 75 | Review failed operations |
| Escalations > 0 | Check Slack/Email for details |
| Mismatched States > 10/hour | Investigate root cause |
| Function timeout | Increase memory or batch size |

---

## 📁 File Locations

**Cloud Functions:**
- `functions/claimsReconciliation.js` - Main logic
- `functions/index.js` - Export declarations

**Flutter App:**
- `lib/services/reconciliation_service.dart` - Data service
- `lib/widgets/system_health_widget.dart` - UI component
- `lib/screens/admin_dashboard.dart` - Integration

**Firestore:**
- `firestore.rules` - Security rules

**Documentation:**
- `docs/implementation/CLAIMS_RECONCILIATION_SYSTEM.md` - Full guide

---

## 🐛 Quick Troubleshooting

| Issue | Solution |
|-------|----------|
| Function not running hourly | Check Cloud Scheduler in GCP Console |
| Notifications not sending | Verify Firebase config variables |
| Widget shows errors | Check Firestore rules, verify admin role |
| Stripe failures | Verify API key, check Stripe dashboard |
| High memory usage | Reduce batch size in reconciliation query |

---

## 📞 Emergency Response

### Critical Failure (Health Score < 50)
1. Check Slack for escalation notifications
2. Review System Health dashboard
3. Check Firebase Functions logs
4. Manually retry failed operations
5. If persistent, trigger reconciliation manually
6. Contact Stripe/SendGrid support if API issues

### Escalated Payout
1. Find payout in Firestore: `payouts/{payoutId}`
2. Review `lastError` field
3. Check associated claim: `claims/{claimId}`
4. Verify Stripe transaction (if applicable)
5. Manual retry via System Health widget
6. If still failing, process payment manually in Stripe dashboard

---

## 📈 Monitoring Commands

```bash
# View last 10 reconciliation runs
firebase firestore:get reconciliation_runs \
  --order-by timestamp \
  --limit 10

# Count failed payouts
firebase firestore:count payouts \
  --where status==failed

# Check function performance
gcloud functions logs read reconcileClaimsState \
  --limit=50 \
  --format="table(timestamp,severity,textPayload)"
```

---

**Last Updated:** October 10, 2025  
**Version:** 1.0.0
