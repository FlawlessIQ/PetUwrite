# Admin Dashboard - Quick Reference Card

## 🚀 5-Minute Setup

```bash
# 1. Deploy rules
firebase deploy --only firestore:rules

# 2. Deploy functions
firebase deploy --only functions

# 3. Set user role (Flutter)
await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .update({'userRole': 2});

# 4. Navigate to dashboard
Navigator.pushNamed(context, '/admin');
```

---

## 🔑 Key Commands

### Create Test Quote
```dart
await FirebaseFirestore.instance.collection('quotes').add({
  'riskScore': {'totalScore': 85, 'aiAnalysis': {...}},
  'pet': {...},
  'owner': {...},
  'status': 'pending',
  'createdAt': Timestamp.now(),
});
```

### Query High-Risk Quotes
```dart
final quotes = await FirebaseFirestore.instance
    .collection('quotes')
    .where('riskScore.totalScore', isGreaterThan: 80)
    .get();
```

### Get Audit Logs
```dart
final logs = await FirebaseFirestore.instance
    .collection('audit_logs')
    .where('type', isEqualTo: 'quote_override')
    .orderBy('timestamp', descending: true)
    .get();
```

### Call Analytics API
```dart
final result = await FirebaseFunctions.instance
    .httpsCallable('getOverrideAnalytics')
    .call({'startDate': '2024-01-01', 'endDate': '2024-12-31'});
```

---

## 👥 User Roles

| Role | Value | Access |
|------|-------|--------|
| Regular User | 0 | Own data only |
| Premium User | 1 | Premium features |
| **Underwriter** | **2** | **Admin Dashboard** |
| Administrator | 3 | Full system access |

---

## 📊 Data Structure

### Quote Document
```
/quotes/{quoteId}
  - riskScore.totalScore: 85
  - humanOverride: {
      decision: "Approve",
      justification: "...",
      underwriterId: "...",
      timestamp: ...
    }
  - status: "approved"
```

### Audit Log
```
/audit_logs/{logId}
  - type: "quote_override"
  - quoteId: "..."
  - decision: "Approve"
  - underwriterId: "..."
  - timestamp: ...
```

---

## 🎨 UI Components

### Filters
- All Quotes
- Pending Review
- Overridden

### Sort Options
- Risk Score (High to Low)
- Risk Score (Low to High)
- Date (Newest First)
- Date (Oldest First)

### Override Decisions
- **Approve**: Issue policy
- **Deny**: Reject application
- **Request More Info**: Need additional data

---

## 🔥 Cloud Functions

| Function | Type | Schedule |
|----------|------|----------|
| `flagHighRiskQuote` | Trigger | On quote create |
| `onQuoteOverride` | Trigger | On quote update |
| `generateDailyOverrideReport` | Scheduled | 9 AM daily |
| `alertPendingQuotes` | Scheduled | Every 2 hours |
| `getOverrideAnalytics` | Callable | On demand |

---

## 🎯 Common Tasks

### Review Pending Quote
1. Open dashboard
2. Filter: "Pending Review"
3. Click quote card
4. Review AI analysis
5. Submit override

### Generate Report
```dart
// Daily reports auto-generated at 9 AM
final report = await FirebaseFirestore.instance
    .collection('daily_reports')
    .doc('2024-10-08')
    .get();
```

### Check Statistics
```dart
final stats = await FirebaseFirestore.instance
    .collection('admin_stats')
    .doc('override_summary')
    .get();
    
print('Total: ${stats.data()['totalOverrides']}');
```

---

## ⚡ Quick Checks

### Verify Role
```dart
final userDoc = await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .get();
print('Role: ${userDoc.data()?['userRole']}'); // Should be 2
```

### Test Query
```dart
final highRisk = await FirebaseFirestore.instance
    .collection('quotes')
    .where('riskScore.totalScore', isGreaterThan: 80)
    .limit(1)
    .get();
print('Found: ${highRisk.docs.length}'); // Should be > 0
```

### Check Rules
```bash
firebase firestore:rules:get
```

---

## 🐛 Troubleshooting

| Issue | Solution |
|-------|----------|
| No quotes visible | Check role is 2, create test quotes |
| Can't submit override | Check justification length (min 20) |
| Permission denied | Deploy security rules |
| Audit log not created | Verify role and authentication |

---

## 📱 Navigation

```dart
// Add to main.dart routes
routes: {
  '/admin': (context) => const AdminDashboard(),
}

// Navigate
Navigator.pushNamed(context, '/admin');
```

---

## 📚 Documentation

- **Full Guide**: ADMIN_DASHBOARD_GUIDE.md
- **Setup**: ADMIN_DASHBOARD_SETUP.md
- **Summary**: ADMIN_DASHBOARD_SUMMARY.md
- **This Card**: ADMIN_DASHBOARD_QUICK_REF.md

---

## ✅ Checklist

Before going live:
- [ ] Rules deployed
- [ ] Functions deployed
- [ ] User roles set
- [ ] Test quotes created
- [ ] Override tested
- [ ] Audit logs verified
- [ ] Analytics working
- [ ] Alerts configured

---

**Keep this card handy for daily operations!**
