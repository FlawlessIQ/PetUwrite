# Admin Dashboard - Ineligible Quotes Quick Reference

## 🎯 Quick Overview

**File:** `lib/screens/admin_dashboard.dart`  
**New Feature:** "Ineligible" tab for declined quotes  
**Status:** ✅ Production Ready

---

## 📱 UI Layout

### **Two Tabs**

```
┌────────────────────────────────────┐
│  ⚠️ High Risk  |  🚫 Ineligible    │
└────────────────────────────────────┘
```

- **High Risk:** Risk score > 80 (existing)
- **Ineligible:** Declined by eligibility rules (NEW)

---

## 🔍 Ineligible Tab Components

### **Statistics Bar**
- 🚫 **Total Declined** - All ineligible quotes
- ⏳ **Pending Review** - Review requested count

### **Quote Card**
```
[🚫 DECLINED] [⏳ Review Requested?]
Pet Name + Breed
Risk Score: XX
❌ Rule: ruleViolated
   Decline reason text
📅 Date            [Request Review]
```

### **Detail Modal**
- 🚫 Eligibility status (rule + reason)
- 📊 Risk assessment (score + level)
- 🐾 Pet information (full details)
- 👤 Owner information (contact + location)
- ℹ️ Quote info (ID + date)
- 📝 **Request Review** button

---

## 🔄 Firestore Query

```dart
.collection('quotes')
.where('eligibility.eligible', isEqualTo: false)
.orderBy('createdAt', descending: true)
```

---

## 📋 Document Structure

```json
{
  "eligibility": {
    "eligible": false,
    "reason": "Decline reason text",
    "ruleViolated": "excludedBreeds",
    "violatedValue": "Pit Bull Terrier",
    "status": "declined" // or "review_requested"
  }
}
```

---

## 🎬 Request Review Flow

1. Admin clicks **"Request Review"** on quote card (or in detail modal)
2. System updates Firestore:
   ```dart
   'eligibility.status': 'review_requested'
   'eligibility.reviewRequestedAt': Timestamp.now()
   'eligibility.reviewRequestedBy': currentUserId
   ```
3. Badge changes to **"⏳ Review Requested"**
4. Quote appears in "Pending Review" count
5. Button disabled (can't request twice)

---

## 🚦 Status Values

| Status | Badge | Action Available |
|--------|-------|------------------|
| `declined` | 🚫 DECLINED | ✅ Request Review |
| `review_requested` | ⏳ Review Requested | ❌ Already Requested |

---

## 🔐 Security

**Access Control:**
- Requires `userRole == 2` (admin)
- Same as existing admin dashboard

**Firestore Rules:**
```javascript
match /quotes/{quoteId} {
  allow read: if request.auth != null;
  allow update: if request.auth != null && 
    get(/databases/$(database)/documents/users/$(request.auth.uid))
      .data.userRole == 2;
}
```

---

## 📊 Rule Violations

Common `ruleViolated` values:

| Rule | Description | Example |
|------|-------------|---------|
| `excludedBreeds` | Breed on exclusion list | Pit Bull, Wolf Hybrid |
| `maxRiskScore` | Risk score too high | Score 92, limit 85 |
| `maxAgeYears` | Pet too old | 15 years, limit 14 |
| `minAgeMonths` | Pet too young | 1 month, limit 2 |
| `criticalConditions` | Has critical condition | Cancer, terminal illness |

---

## 🧪 Testing Checklist

### **Quick Tests**
- [ ] Tab appears and switches correctly
- [ ] Declined quotes display in list
- [ ] Click card opens detail modal
- [ ] "Request Review" updates Firestore
- [ ] Badge changes after request
- [ ] Statistics calculate correctly
- [ ] Empty state shows when no quotes
- [ ] Error handling works

---

## 📝 Code Snippets

### **Query Ineligible Quotes**
```dart
final quotes = await FirebaseFirestore.instance
    .collection('quotes')
    .where('eligibility.eligible', isEqualTo: false)
    .get();
```

### **Request Review**
```dart
await FirebaseFirestore.instance
    .collection('quotes')
    .doc(quoteId)
    .update({
  'eligibility.status': 'review_requested',
  'eligibility.reviewRequestedAt': Timestamp.now(),
  'eligibility.reviewRequestedBy': FirebaseAuth.instance.currentUser?.uid,
});
```

### **Get Pending Count**
```dart
final pending = await FirebaseFirestore.instance
    .collection('quotes')
    .where('eligibility.eligible', isEqualTo: false)
    .where('eligibility.status', isEqualTo: 'review_requested')
    .get();

final count = pending.docs.length;
```

---

## 🎯 Common Use Cases

### **1. Breed Exception**
Pet breed excluded but has low risk → Request review → Manual approval

### **2. Age Boundary**
Pet just over age limit with good health → Request review → Possible approval

### **3. High Risk Score**
Score slightly over limit with manageable factors → Request review → Adjusted pricing approval

---

## 🚀 Integration

### **With UnderwritingRulesEngine**
```dart
// In risk_scoring_engine.dart
final eligibility = await _rulesEngine.checkEligibility(...);

if (!eligibility.eligible) {
  await _storeEligibilityStatus(quoteId, eligibility);
  // ⬆️ Quote appears in "Ineligible" tab
}
```

### **With Admin Rules Editor**
- Admin changes rules in `AdminRulesEditorPage`
- New quotes use updated rules
- Past declined quotes can be reviewed manually

---

## ✅ Summary

**What's New:**
- ✅ "Ineligible" tab in admin dashboard
- ✅ Shows all declined quotes with reasons
- ✅ "Request Review" button for manual override
- ✅ Real-time statistics and updates
- ✅ Detailed modal with full quote info

**Status:** ✅ **READY FOR PRODUCTION**

**Files Changed:**
- `lib/screens/admin_dashboard.dart` (updated)

**Zero Compilation Errors** 🎉

---

## 📞 Quick Actions

| Task | Method |
|------|--------|
| View declined quotes | Navigate to "Ineligible" tab |
| See decline reason | Look at red box on card |
| Request review | Click "Request Review" button |
| View full details | Click anywhere on card |
| Check pending reviews | Look at statistics bar |
| Refresh list | Pull to refresh or click refresh icon |

---

**Everything you need to manage ineligible quotes in one place!** 🚀
