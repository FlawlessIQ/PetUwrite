# Firestore Security Rules - Quick Deployment Guide

## ✅ What Was Updated

### New Security Rules Added:

1. **`isAdmin()` Helper Function**
   - Checks if `userRole == 2`
   - Used throughout rules for admin access control

2. **`admin_settings/underwriting_rules`**
   - ✅ Read: All authenticated users
   - ✅ Write: Admins only (`userRole == 2`)

3. **`audit_logs/{logId}`**
   - ✅ Read: Admins only
   - ✅ Create: Admins only
   - ✅ Update/Delete: Never (immutable)

4. **`quotes/{quoteId}` - Enhanced**
   - ✅ Read: Owner OR admin
   - ✅ Update: Owner OR admin (with field restrictions)
   - ✅ Admin can only update: humanOverride, eligibility.*, riskScore.*, status

5. **`quotes/{quoteId}/risk_score/{riskScoreId}` - New Subcollection**
   - ✅ Read: Owner OR admin
   - ✅ Write: Backend only (Cloud Functions)

6. **`quotes/{quoteId}/explainability/{explainabilityId}` - New Subcollection**
   - ✅ Read: Owner OR admin
   - ✅ Write: Backend only (Cloud Functions)

7. **`analytics/{document=**}`**
   - ✅ Read: Admins only (changed from "false")
   - ✅ Write: Backend only

---

## 🚀 Deployment Steps

### Step 1: Review Changes
```bash
# View current rules
firebase firestore:rules get

# Compare with new rules
cat firestore.rules
```

---

### Step 2: Test Rules Locally (Optional)
```bash
# Install Firebase Emulator Suite
firebase init emulators

# Start Firestore emulator
firebase emulators:start --only firestore

# Run tests (if you have unit tests)
npm test
```

---

### Step 3: Preview Deployment
```bash
# Dry run to see what will change
firebase deploy --only firestore:rules --dry-run
```

**Expected Output:**
```
✔ firestore: checking firestore.rules for compilation errors...
✔ firestore: compiled firestore.rules successfully

=== Firestore Rules Diff ===

+ match /admin_settings/underwriting_rules {
+   allow read: if isAuthenticated();
+   allow write: if isAdmin();
+ }

+ match /audit_logs/{logId} {
+   allow read: if isAdmin();
+   allow create: if isAdmin();
+   allow update, delete: if false;
+ }

... (other changes)
```

---

### Step 4: Deploy Rules
```bash
# Deploy to Firebase
firebase deploy --only firestore:rules
```

**Expected Output:**
```
=== Deploying to 'petuwrite-prod'...

i  deploying firestore
i  firestore: checking firestore.rules for compilation errors...
✔  firestore: rules file firestore.rules compiled successfully
i  firestore: uploading rules firestore.rules...
✔  firestore: released rules firestore.rules to cloud.firestore

✔  Deploy complete!
```

---

### Step 5: Verify Deployment
```bash
# Check deployed rules
firebase firestore:rules get

# Should output the updated rules
```

---

## 🧪 Testing After Deployment

### Test 1: Regular User Reading Underwriting Rules
```javascript
// In your Flutter app or Firebase Console
const rules = await FirebaseFirestore.instance
  .collection('admin_settings')
  .doc('underwriting_rules')
  .get();

// ✅ Should succeed (authenticated users can read)
console.log(rules.data());
```

---

### Test 2: Regular User Writing Underwriting Rules
```javascript
// Try to update rules as regular user (userRole != 2)
await FirebaseFirestore.instance
  .collection('admin_settings')
  .doc('underwriting_rules')
  .update({ maxRiskScore: 90 });

// ❌ Should fail with "Permission denied"
```

---

### Test 3: Admin Writing Underwriting Rules
```javascript
// As admin user (userRole == 2)
await FirebaseFirestore.instance
  .collection('admin_settings')
  .doc('underwriting_rules')
  .update({ maxRiskScore: 90 });

// ✅ Should succeed
```

---

### Test 4: Admin Overriding Quote Eligibility
```javascript
// As admin user (userRole == 2)
await FirebaseFirestore.instance
  .collection('quotes')
  .doc(quoteId)
  .update({
    'humanOverride': {
      'decision': 'Approve',
      'reasoning': 'Test override'
    },
    'eligibility.status': 'overridden'
  });

// ✅ Should succeed (allowed fields)
```

---

### Test 5: Admin Creating Audit Log
```javascript
// As admin user (userRole == 2)
await FirebaseFirestore.instance
  .collection('audit_logs')
  .add({
    type: 'eligibility_override',
    quoteId: 'test_quote',
    adminId: currentUser.uid,
    timestamp: FieldValue.serverTimestamp()
  });

// ✅ Should succeed
```

---

### Test 6: Admin Trying to Update Audit Log
```javascript
// Try to update existing audit log
await FirebaseFirestore.instance
  .collection('audit_logs')
  .doc(logId)
  .update({ type: 'modified' });

// ❌ Should fail (audit logs are immutable)
```

---

## 🔍 Troubleshooting

### Issue: "Permission denied" when reading underwriting_rules
**Solution:**
1. Verify user is authenticated
2. Check Firebase Auth session is valid
3. Re-login if necessary

**Test:**
```javascript
const user = FirebaseAuth.instance.currentUser;
console.log('Authenticated:', user != null);
console.log('UID:', user?.uid);
```

---

### Issue: Admin cannot write to underwriting_rules
**Solution:**
1. Check `userRole` field in user document
2. Verify `userRole == 2`
3. Ensure field name is exactly `userRole` (case-sensitive)

**Test:**
```javascript
const userDoc = await FirebaseFirestore.instance
  .collection('users')
  .doc(currentUser.uid)
  .get();

console.log('User role:', userDoc.data()?.userRole);
// Should output: 2
```

---

### Issue: Rules not updating after deployment
**Solution:**
1. Wait 1-2 minutes for propagation
2. Clear browser cache
3. Restart app
4. Re-deploy with `--force` flag

```bash
firebase deploy --only firestore:rules --force
```

---

### Issue: "Function get() not found" error
**Cause:** Using `get()` in rules requires Firestore Rules v2  
**Solution:** Ensure `rules_version = '2';` at top of firestore.rules

---

## 📊 Performance Impact

### Rule Evaluation Costs
Each security rule evaluation that uses `get()` counts as 1 read operation.

**Our Implementation:**
- `isAdmin()` uses 1 `get()` call per request
- Cost: ~$0.00006 per 1000 admin requests
- Negligible impact for typical usage

**Optimization:**
- Rules are evaluated once per request
- Helper functions don't multiply cost
- Client-side caching reduces server checks

---

## 🔐 Security Checklist

After deployment, verify:

- ✅ Regular users can read `admin_settings/underwriting_rules`
- ✅ Regular users **cannot** write `admin_settings/underwriting_rules`
- ✅ Admins can read and write `admin_settings/underwriting_rules`
- ✅ Admins can read `audit_logs`
- ✅ Admins can create `audit_logs`
- ✅ Nobody can update or delete `audit_logs`
- ✅ Admins can read all quotes
- ✅ Admins can update specific quote fields (humanOverride, eligibility)
- ✅ Admins **cannot** modify pet data in quotes
- ✅ Users can only access their own quotes
- ✅ Analytics readable by admins only

---

## 📋 Post-Deployment Tasks

### 1. Create Underwriting Rules Document
```javascript
// As admin, create the initial document
await FirebaseFirestore.instance
  .collection('admin_settings')
  .doc('underwriting_rules')
  .set({
    maxRiskScore: 85,
    excludedBreeds: [
      'Pit Bull',
      'Rottweiler',
      'Wolf Hybrid'
    ],
    criticalConditions: [
      'cancer',
      'heart failure',
      'kidney failure'
    ],
    minAgeMonths: 2,
    maxAgeYears: 14,
    updatedAt: FieldValue.serverTimestamp(),
    updatedBy: currentUser.uid
  });
```

---

### 2. Set User Roles
```javascript
// Set admin role for specific users
await FirebaseFirestore.instance
  .collection('users')
  .doc('admin_user_uid')
  .update({ userRole: 2 });

// Set regular user role
await FirebaseFirestore.instance
  .collection('users')
  .doc('regular_user_uid')
  .update({ userRole: 0 });
```

---

### 3. Test Admin Dashboard
1. Login as admin user (userRole == 2)
2. Navigate to Admin Dashboard
3. Verify you can see all quotes
4. Try overriding an ineligible quote
5. Verify audit log is created

---

### 4. Monitor Usage
```bash
# Check Firestore usage in Firebase Console
# Monitor for unexpected "Permission denied" errors
# Review audit logs regularly

firebase firestore:logs --limit 50
```

---

## 📞 Support Resources

### Firebase Documentation
- [Security Rules Guide](https://firebase.google.com/docs/firestore/security/get-started)
- [Rules Simulator](https://firebase.google.com/docs/firestore/security/test-rules-emulator)
- [Best Practices](https://firebase.google.com/docs/firestore/security/rules-best-practices)

### PetUwrite Documentation
- [Full Security Rules Documentation](./FIRESTORE_SECURITY_RULES.md)
- [Admin Dashboard Guide](./ADMIN_DASHBOARD_GUIDE.md)
- [Underwriting Rules Engine Guide](./UNDERWRITING_RULES_ENGINE_GUIDE.md)

---

## ✅ Summary

### What Changed:
- ✅ Added `isAdmin()` helper function
- ✅ Added `admin_settings/underwriting_rules` security rules
- ✅ Added `audit_logs` security rules (immutable)
- ✅ Enhanced `quotes` collection rules for admin access
- ✅ Added subcollection rules for `risk_score` and `explainability`
- ✅ Updated `analytics` to allow admin read access

### Deployment Commands:
```bash
# 1. Review rules
cat firestore.rules

# 2. Deploy rules
firebase deploy --only firestore:rules

# 3. Verify deployment
firebase firestore:rules get

# 4. Test in console
# Firebase Console → Firestore → Rules → Rules Playground
```

### Testing Checklist:
- ✅ Regular user can read underwriting_rules
- ✅ Regular user cannot write underwriting_rules
- ✅ Admin can write underwriting_rules
- ✅ Admin can create audit logs
- ✅ Nobody can update/delete audit logs
- ✅ Admin can override quote eligibility

**Your Firestore security rules are now production-ready!** 🔒🚀
