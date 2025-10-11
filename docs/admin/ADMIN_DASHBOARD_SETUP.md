# Admin Dashboard Setup Guide

## 🚀 Quick Setup (5 Minutes)

### Step 1: Deploy Firestore Security Rules

```bash
# From project root
firebase deploy --only firestore:rules

# Or copy firestore_rules_with_admin.rules to firestore.rules
cp firestore_rules_with_admin.rules firestore.rules
firebase deploy --only firestore:rules
```

### Step 2: Set User Role to Underwriter

In Firebase Console or via code:

**Option A: Firebase Console**
1. Open Firestore Database
2. Navigate to `users/{userId}`
3. Add field: `userRole: 2`
4. Save

**Option B: Via Code (One-time setup)**
```dart
// Run this once to set underwriter role
Future<void> setUnderwriterRole(String userId) async {
  await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .update({'userRole': 2});
}
```

**Option C: Cloud Function (Recommended for Production)**
```javascript
// functions/setUnderwriterRole.js
exports.setUnderwriterRole = functions.https.onCall(async (data, context) => {
  // Only allow admins to set roles
  const requesterRole = (await admin.firestore()
    .collection('users')
    .doc(context.auth.uid)
    .get()).data()?.userRole;
  
  if (requesterRole !== 3) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can set user roles'
    );
  }
  
  const { userId, role } = data;
  
  await admin.firestore()
    .collection('users')
    .doc(userId)
    .update({ userRole: role });
  
  return { success: true };
});
```

### Step 3: Add Route to App

In `main.dart`:

```dart
import 'screens/admin_dashboard.dart';

// Add route
routes: {
  '/admin': (context) => const AdminDashboard(),
  // ... other routes
},
```

### Step 4: Add Navigation (Optional)

Add to your app drawer or settings:

```dart
// Check user role first
final user = FirebaseAuth.instance.currentUser;
if (user != null) {
  final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();
  
  final userRole = userDoc.data()?['userRole'] ?? 0;
  
  if (userRole == 2) {
    // Show admin dashboard option
    ListTile(
      leading: const Icon(Icons.admin_panel_settings),
      title: const Text('Underwriter Dashboard'),
      onTap: () {
        Navigator.pushNamed(context, '/admin');
      },
    );
  }
}
```

---

## 👥 User Role Levels

```dart
0 = Regular User (default)
1 = Premium User
2 = Underwriter (Admin Dashboard access)
3 = Administrator (Full access)
```

---

## 🧪 Test the Dashboard

### 1. Create Test High-Risk Quote

```dart
// Run this to create a test quote
Future<void> createTestHighRiskQuote() async {
  await FirebaseFirestore.instance.collection('quotes').add({
    'riskScore': {
      'totalScore': 85, // High risk (> 80)
      'aiAnalysis': {
        'decision': 'Deny - High Risk',
        'reasoning': 'Senior age with multiple pre-existing conditions',
        'confidence': 92,
        'riskFactors': [
          'Senior age (12 years)',
          'Chronic kidney disease',
          'Diabetes history',
        ],
        'recommendations': [
          'Consider higher deductible plan',
          'Exclude pre-existing conditions',
        ],
      },
    },
    'pet': {
      'name': 'Test Pet',
      'species': 'Dog',
      'breed': 'Golden Retriever',
      'age': 12,
      'gender': 'Male',
      'weight': 75,
      'medicalConditions': ['Kidney Disease', 'Diabetes'],
    },
    'owner': {
      'firstName': 'Test',
      'lastName': 'Owner',
      'email': 'test@example.com',
      'phone': '555-1234',
      'state': 'CA',
      'zipCode': '90210',
    },
    'ownerId': FirebaseAuth.instance.currentUser!.uid,
    'status': 'pending',
    'createdAt': Timestamp.now(),
  });
}
```

### 2. Navigate to Dashboard

```dart
Navigator.pushNamed(context, '/admin');
```

### 3. Test Override Flow

1. Click on a quote card
2. Review the AI decision
3. Select "Approve" or "Deny"
4. Write justification (min 20 chars)
5. Click "Submit Override"
6. Verify quote status updates
7. Check audit log created

---

## 🔍 Verify Setup

### Check Firestore Rules Deployed

```bash
firebase firestore:rules:get
```

### Check User Role

```dart
final userDoc = await FirebaseFirestore.instance
    .collection('users')
    .doc(FirebaseAuth.instance.currentUser!.uid)
    .get();
    
print('User Role: ${userDoc.data()?['userRole']}');
// Should print: User Role: 2
```

### Check Quotes Query

```dart
final highRiskQuotes = await FirebaseFirestore.instance
    .collection('quotes')
    .where('riskScore.totalScore', isGreaterThan: 80)
    .get();
    
print('High-risk quotes: ${highRiskQuotes.docs.length}');
```

### Check Audit Logs Permission

```dart
try {
  final logs = await FirebaseFirestore.instance
      .collection('audit_logs')
      .limit(1)
      .get();
  print('Can read audit logs: ${logs.docs.length >= 0}');
} catch (e) {
  print('Cannot read audit logs: $e');
}
```

---

## 🐛 Troubleshooting

### Issue: "Permission Denied" Error

**Cause**: Firestore rules not deployed or user role not set

**Solution**:
```bash
# Deploy rules
firebase deploy --only firestore:rules

# Verify user role in Firestore Console
# users/{userId} should have userRole: 2
```

### Issue: No Quotes Appearing

**Cause**: No quotes with `riskScore.totalScore > 80`

**Solution**: Create test quotes (see above) or adjust filter:
```dart
// In admin_dashboard.dart, change threshold temporarily
.where('riskScore.totalScore', isGreaterThan: 50) // Lower threshold
```

### Issue: Cannot Submit Override

**Cause**: Justification too short or security rules blocking

**Solution**:
- Ensure justification is at least 20 characters
- Check Firestore rules allow updates
- Verify user is authenticated

### Issue: Audit Log Not Created

**Cause**: Security rules blocking creation

**Solution**: Check `audit_logs` rules allow create with proper fields:
```javascript
allow create: if isUnderwriter() &&
                 request.resource.data.underwriterId == request.auth.uid;
```

---

## 📊 Monitoring

### View Audit Logs

Firebase Console → Firestore → `audit_logs` collection

### Query Overrides by User

```dart
final userOverrides = await FirebaseFirestore.instance
    .collection('audit_logs')
    .where('underwriterId', isEqualTo: userId)
    .orderBy('timestamp', descending: true)
    .get();
```

### Get Override Statistics

```dart
final overrides = await FirebaseFirestore.instance
    .collection('audit_logs')
    .where('type', isEqualTo: 'quote_override')
    .get();

int approved = 0, denied = 0, moreInfo = 0;

for (var doc in overrides.docs) {
  switch (doc.data()['decision']) {
    case 'Approve': approved++; break;
    case 'Deny': denied++; break;
    case 'Request More Info': moreInfo++; break;
  }
}

print('Approved: $approved, Denied: $denied, More Info: $moreInfo');
```

---

## 🔐 Security Checklist

- [ ] Firestore rules deployed
- [ ] User roles configured
- [ ] Audit logs write-only for underwriters
- [ ] Only underwriters can read high-risk quotes
- [ ] Only underwriters can add humanOverride field
- [ ] Audit logs are immutable (no updates/deletes)
- [ ] Underwriter ID verification in override submission

---

## 📚 Additional Resources

- **Full Documentation**: See `ADMIN_DASHBOARD_GUIDE.md`
- **Security Rules**: See `firestore_rules_with_admin.rules`
- **Dashboard Code**: `lib/screens/admin_dashboard.dart`

---

## ✅ Setup Complete!

You should now be able to:
1. ✅ Access admin dashboard as underwriter
2. ✅ View high-risk quotes (score > 80)
3. ✅ Review AI decisions
4. ✅ Submit overrides with justification
5. ✅ View audit logs

**Next Steps**:
- Create more test quotes
- Train underwriters on the system
- Set up monitoring alerts
- Export audit logs for compliance

---

**Need Help?** Check the full documentation in `ADMIN_DASHBOARD_GUIDE.md`
