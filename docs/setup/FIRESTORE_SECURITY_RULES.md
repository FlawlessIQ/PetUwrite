# Firestore Security Rules Documentation

## 🔐 Overview

This document describes the Firebase Firestore security rules for the PetUwrite application, including role-based access control and data protection policies.

---

## 👥 User Roles

### Role Levels
- **0** = Regular User (Customer)
- **1** = Underwriter (Review Access)
- **2** = Admin (Full Access)

**Storage Location:** `users/{uid}/userRole`

---

## 🛠️ Helper Functions

### `isAuthenticated()`
**Purpose:** Check if user is logged in  
**Returns:** `true` if user has valid Firebase Auth session

```javascript
function isAuthenticated() {
  return request.auth != null;
}
```

---

### `isOwner(userId)`
**Purpose:** Check if authenticated user matches the specified user ID  
**Returns:** `true` if request.auth.uid equals userId

```javascript
function isOwner(userId) {
  return isAuthenticated() && request.auth.uid == userId;
}
```

---

### `isOwnDocument()`
**Purpose:** Check if user owns the document being accessed  
**Returns:** `true` if document's userId field matches authenticated user

```javascript
function isOwnDocument() {
  return isAuthenticated() && request.auth.uid == resource.data.userId;
}
```

---

### `isAdmin()`
**Purpose:** Check if user has admin privileges (userRole == 2)  
**Returns:** `true` if user's userRole field equals 2

```javascript
function isAdmin() {
  return isAuthenticated() && 
         get(/databases/$(database)/documents/users/$(request.auth.uid)).data.userRole == 2;
}
```

**Usage Example:**
```javascript
allow write: if isAdmin();
```

---

## 📁 Collection Security Rules

### `users/{userId}`

**Purpose:** User profile data  

| Operation | Rule | Explanation |
|-----------|------|-------------|
| `read` | `isOwner(userId)` | Users can only read their own profile |
| `create` | `isOwner(userId)` | Users can create their own profile |
| `update` | `isOwner(userId)` | Users can update their own profile |
| `delete` | `isOwner(userId)` | Users can delete their own profile |

**Data Structure:**
```json
{
  "users/{uid}": {
    "email": "user@example.com",
    "firstName": "John",
    "lastName": "Doe",
    "userRole": 0,  // 0=user, 1=underwriter, 2=admin
    "createdAt": "timestamp",
    "phone": "555-1234"
  }
}
```

---

### `pets/{petId}`

**Purpose:** Pet profile data  

| Operation | Rule | Explanation |
|-----------|------|-------------|
| `read` | `resource.data.ownerId == request.auth.uid` | Users can only read their own pets |
| `create` | `request.resource.data.ownerId == request.auth.uid` | Must set ownerId to current user |
| `update` | `resource.data.ownerId == request.auth.uid` | Only owner can update pet |
| `delete` | `resource.data.ownerId == request.auth.uid` | Only owner can delete pet |

**Data Structure:**
```json
{
  "pets/{petId}": {
    "name": "Buddy",
    "species": "dog",
    "breed": "Golden Retriever",
    "ownerId": "user_uid",
    "age": 5,
    "weight": 65
  }
}
```

---

### `quotes/{quoteId}`

**Purpose:** Insurance quotes  

| Operation | Rule | Explanation |
|-----------|------|-------------|
| `read` | `ownerId == user OR isAdmin()` | Owner or admin can read |
| `create` | `ownerId == current user` | Owner creates quote |
| `update` | `ownerId == user OR admin override` | Owner updates OR admin can override eligibility |
| `delete` | `ownerId == current user` | Only owner can delete |

**Admin Update Restrictions:**
Admins can only update specific fields:
- `humanOverride`
- `eligibility.status`
- `eligibility.overriddenAt`
- `eligibility.overriddenBy`
- `eligibility.reviewRequestedAt`
- `eligibility.reviewRequestedBy`
- `riskScore.totalScore`
- `riskScore.overridden`
- `riskScore.originalScore`
- `status`

**Data Structure:**
```json
{
  "quotes/{quoteId}": {
    "ownerId": "user_uid",
    "pet": { "name": "Buddy", "breed": "Golden Retriever" },
    "riskScore": { "totalScore": 75 },
    "eligibility": {
      "eligible": true,
      "status": "approved"
    },
    "createdAt": "timestamp"
  }
}
```

---

#### `quotes/{quoteId}/risk_score/{riskScoreId}`

**Purpose:** Detailed risk scoring data (subcollection)  

| Operation | Rule | Explanation |
|-----------|------|-------------|
| `read` | `quote owner OR isAdmin()` | Owner or admin can read |
| `write` | `false` | Only backend service can write |

**Data Structure:**
```json
{
  "risk_score/{riskScoreId}": {
    "overallScore": 75,
    "riskLevel": "medium",
    "categoryScores": {
      "age": 60,
      "breed": 70,
      "preExisting": 85
    },
    "aiAnalysis": "Full GPT-4o analysis text"
  }
}
```

---

#### `quotes/{quoteId}/explainability/{explainabilityId}`

**Purpose:** Risk score explainability data (subcollection)  

| Operation | Rule | Explanation |
|-----------|------|-------------|
| `read` | `quote owner OR isAdmin()` | Owner or admin can read |
| `write` | `false` | Only backend service can write |

**Data Structure:**
```json
{
  "explainability/{explainabilityId}": {
    "baselineScore": 50,
    "contributions": [
      { "feature": "Age", "impact": 10 },
      { "feature": "Breed", "impact": 15 }
    ],
    "finalScore": 75
  }
}
```

---

### `policies/{policyId}`

**Purpose:** Active insurance policies  

| Operation | Rule | Explanation |
|-----------|------|-------------|
| `read` | `ownerId == current user` | Only owner can read |
| `create` | `ownerId == current user` | Owner creates policy |
| `update` | `ownerId == current user` | Owner updates policy |
| `delete` | `false` | Policies cannot be deleted |

**Data Structure:**
```json
{
  "policies/{policyId}": {
    "ownerId": "user_uid",
    "quoteId": "quote_id",
    "status": "active",
    "premium": 85.50,
    "startDate": "timestamp",
    "endDate": "timestamp"
  }
}
```

---

#### `policies/{policyId}/claims/{claimId}`

**Purpose:** Insurance claims (subcollection)  

| Operation | Rule | Explanation |
|-----------|------|-------------|
| `read` | `policy owner` | Only policy owner can read |
| `create` | `policy owner` | Only policy owner can create |
| `update` | `policy owner` | Only policy owner can update |
| `delete` | `false` | Claims cannot be deleted |

**Data Structure:**
```json
{
  "claims/{claimId}": {
    "policyId": "policy_id",
    "type": "illness",
    "amount": 1500.00,
    "status": "pending",
    "submittedAt": "timestamp"
  }
}
```

---

### `riskScores/{scoreId}`

**Purpose:** Legacy risk scores collection (deprecated - use subcollection)  

| Operation | Rule | Explanation |
|-----------|------|-------------|
| `read` | `ownerId == current user` | Owner can read |
| `write` | `false` | Only Cloud Functions can write |

---

### `payments/{paymentId}`

**Purpose:** Payment records (managed by Stripe extension)  

| Operation | Rule | Explanation |
|-----------|------|-------------|
| `read` | `userId == current user` | Owner can read |
| `write` | `false` | Only Stripe extension can write |

**Data Structure:**
```json
{
  "payments/{paymentId}": {
    "userId": "user_uid",
    "amount": 85.50,
    "status": "succeeded",
    "stripePaymentIntentId": "pi_...",
    "createdAt": "timestamp"
  }
}
```

---

### `admin_settings/underwriting_rules`

**Purpose:** Configuration for underwriting eligibility rules  

| Operation | Rule | Explanation |
|-----------|------|-------------|
| `read` | `isAuthenticated()` | All authenticated users can read |
| `write` | `isAdmin()` | Only admins (userRole == 2) can write |

**Why Read Access for All Users?**
- Frontend needs rules for real-time validation
- Risk scoring engine caches rules
- No sensitive data (just business logic)
- Write access strictly controlled

**Data Structure:**
```json
{
  "admin_settings/underwriting_rules": {
    "maxRiskScore": 85,
    "excludedBreeds": [
      "Pit Bull",
      "Rottweiler",
      "Wolf Hybrid"
    ],
    "criticalConditions": [
      "cancer",
      "heart failure",
      "kidney failure"
    ],
    "minAgeMonths": 2,
    "maxAgeYears": 14,
    "updatedAt": "timestamp",
    "updatedBy": "admin_uid"
  }
}
```

---

### `audit_logs/{logId}`

**Purpose:** Immutable audit trail for admin actions  

| Operation | Rule | Explanation |
|-----------|------|-------------|
| `read` | `isAdmin()` | Only admins can read logs |
| `create` | `isAdmin()` | Only admins can create logs |
| `update` | `false` | Logs are immutable |
| `delete` | `false` | Logs cannot be deleted |

**Why Immutable?**
- Compliance and regulatory requirements
- Audit trail integrity
- Legal protection
- Historical record

**Data Structure:**
```json
{
  "audit_logs/{logId}": {
    "type": "eligibility_override",
    "quoteId": "quote_abc123",
    "adminId": "admin_uid",
    "adminName": "Sarah Johnson",
    "decision": "Approve",
    "justification": "Condition resolved...",
    "timestamp": "timestamp"
  }
}
```

---

### `analytics/{document=**}`

**Purpose:** Analytics and reporting data  

| Operation | Rule | Explanation |
|-----------|------|-------------|
| `read` | `isAdmin()` | Only admins can read analytics |
| `write` | `false` | Only server-side access (Cloud Functions) |

**Data Structure:**
```json
{
  "analytics/daily_stats": {
    "date": "2025-10-10",
    "totalQuotes": 150,
    "approvalRate": 0.85,
    "avgRiskScore": 65.5,
    "calculatedAt": "timestamp"
  }
}
```

---

## 🔒 Security Patterns

### Pattern 1: Owner-Only Access
**Use Case:** User accessing their own data

```javascript
match /collection/{docId} {
  allow read, write: if resource.data.ownerId == request.auth.uid;
}
```

**Example:** pets, quotes, policies

---

### Pattern 2: Admin Override
**Use Case:** Admin reviewing/overriding user data

```javascript
match /collection/{docId} {
  allow read: if resource.data.ownerId == request.auth.uid || isAdmin();
  allow update: if isAdmin() && request.resource.data.diff(resource.data).affectedKeys().hasOnly([
    'fieldAllowedToChange'
  ]);
}
```

**Example:** quotes collection (eligibility override)

---

### Pattern 3: Read-Only for Users
**Use Case:** Data written by backend, readable by users

```javascript
match /collection/{docId} {
  allow read: if resource.data.ownerId == request.auth.uid;
  allow write: if false; // Only backend/Cloud Functions
}
```

**Example:** risk_score subcollection, payments

---

### Pattern 4: Admin Settings
**Use Case:** Configuration readable by all, writable by admins

```javascript
match /admin_settings/{document} {
  allow read: if isAuthenticated();
  allow write: if isAdmin();
}
```

**Example:** underwriting_rules

---

### Pattern 5: Immutable Audit Logs
**Use Case:** Write-once, read-only logs

```javascript
match /audit_logs/{logId} {
  allow read, create: if isAdmin();
  allow update, delete: if false;
}
```

**Example:** audit_logs collection

---

## 🧪 Testing Security Rules

### Test 1: Regular User Access
```javascript
// User can read their own quote
✅ user1 → read quotes/quote_owned_by_user1 → ALLOW

// User cannot read another user's quote
❌ user1 → read quotes/quote_owned_by_user2 → DENY

// User cannot update another user's quote
❌ user1 → update quotes/quote_owned_by_user2 → DENY
```

---

### Test 2: Admin Access
```javascript
// Admin can read any quote
✅ admin → read quotes/any_quote → ALLOW

// Admin can override eligibility
✅ admin → update quotes/any_quote.humanOverride → ALLOW

// Admin cannot modify pet data directly
❌ admin → update quotes/any_quote.pet.name → DENY
```

---

### Test 3: Underwriting Rules
```javascript
// Authenticated user can read rules
✅ user → read admin_settings/underwriting_rules → ALLOW

// Regular user cannot write rules
❌ user → update admin_settings/underwriting_rules → DENY

// Admin can write rules
✅ admin → update admin_settings/underwriting_rules → ALLOW
```

---

### Test 4: Audit Logs
```javascript
// Regular user cannot read audit logs
❌ user → read audit_logs/any_log → DENY

// Admin can create audit log
✅ admin → create audit_logs/new_log → ALLOW

// Admin cannot update existing log
❌ admin → update audit_logs/existing_log → DENY

// Admin cannot delete log
❌ admin → delete audit_logs/existing_log → DENY
```

---

## 🚀 Deployment

### Deploy Rules to Firebase
```bash
# Preview changes
firebase deploy --only firestore:rules --dry-run

# Deploy rules
firebase deploy --only firestore:rules

# View deployed rules
firebase firestore:rules get
```

---

### Test Rules in Console
1. Navigate to Firebase Console → Firestore → Rules
2. Click **"Rules Playground"**
3. Select collection and operation
4. Set authenticated user UID
5. Click **"Run"** to test

---

## 🔍 Common Issues & Solutions

### Issue 1: "Permission Denied" Error
**Cause:** User lacks required role or ownership  
**Solution:** 
- Check `userRole` field in users collection
- Verify `ownerId` matches authenticated user
- Ensure user is logged in (`request.auth != null`)

---

### Issue 2: Admin Cannot Update Quote
**Cause:** Trying to update non-allowed fields  
**Solution:**
- Only update allowed fields (humanOverride, eligibility.status, etc.)
- Check `affectedKeys()` whitelist in rules

---

### Issue 3: Rules Not Updating
**Cause:** Deployment failed or cached rules  
**Solution:**
```bash
# Force redeploy
firebase deploy --only firestore:rules --force

# Clear local cache
firebase logout
firebase login
```

---

### Issue 4: User Can't Read Underwriting Rules
**Cause:** User not authenticated  
**Solution:**
- Ensure Firebase Auth session is valid
- Check `request.auth != null` returns true

---

## 📊 Performance Considerations

### Rule Evaluation Cost
Each security rule evaluation counts toward Firestore read operations.

**Optimization Tips:**
1. **Cache User Role:** Store `userRole` in client after login
2. **Minimize `get()` Calls:** Each `get()` in rules = 1 read operation
3. **Use Subcollections:** Reduce need for complex queries
4. **Client-Side Validation:** Validate before sending request

**Example:**
```javascript
// ❌ BAD - Multiple get() calls per request
allow read: if get(/databases/$(database)/documents/users/$(request.auth.uid)).data.userRole == 2
            && get(/databases/$(database)/documents/settings/config).data.enabled == true;

// ✅ GOOD - Single get() call
allow read: if isAdmin(); // Uses helper function with single get()
```

---

## 🔐 Best Practices

### 1. Principle of Least Privilege
- ✅ Grant minimum necessary permissions
- ✅ Use owner-based access by default
- ✅ Require admin role for sensitive operations

### 2. Defense in Depth
- ✅ Validate on client side
- ✅ Enforce with security rules
- ✅ Validate again on server (Cloud Functions)

### 3. Immutable Audit Trails
- ✅ Never allow updates to audit logs
- ✅ Never allow deletes to audit logs
- ✅ Log all admin actions

### 4. Field-Level Restrictions
- ✅ Use `affectedKeys()` to limit admin updates
- ✅ Prevent modification of critical fields
- ✅ Preserve original data for audit

### 5. Role-Based Access Control
- ✅ Use helper functions (`isAdmin()`)
- ✅ Store roles in user document
- ✅ Validate roles before granting access

---

## 📞 Support

### Firebase Documentation
- [Security Rules Reference](https://firebase.google.com/docs/firestore/security/get-started)
- [Rules Language](https://firebase.google.com/docs/rules/rules-language)
- [Testing Rules](https://firebase.google.com/docs/rules/unit-tests)

### PetUwrite Documentation
- [Admin Dashboard Guide](./ADMIN_DASHBOARD_GUIDE.md)
- [Override Eligibility Guide](./ADMIN_OVERRIDE_ELIGIBILITY_GUIDE.md)
- [Underwriting Rules Engine](./UNDERWRITING_RULES_ENGINE_GUIDE.md)

---

## ✅ Summary

**Security Rules Implemented:**
- ✅ Owner-only access for personal data (pets, quotes, policies)
- ✅ Admin access for quote review and override
- ✅ Admin-only write access to underwriting rules
- ✅ Immutable audit logs for compliance
- ✅ Field-level restrictions for admin updates
- ✅ Role-based access control (userRole == 2)

**Collections Protected:**
- ✅ users
- ✅ pets
- ✅ quotes (with subcollections)
- ✅ policies (with claims)
- ✅ admin_settings/underwriting_rules
- ✅ audit_logs
- ✅ analytics

**Access Patterns:**
- ✅ Regular users: Own data only
- ✅ Admins: All quotes + admin settings + audit logs
- ✅ Backend: Risk scores, payments, analytics

Your Firestore is now secured with production-ready security rules! 🔒
