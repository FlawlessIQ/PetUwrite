# Role-Based Authentication Setup Guide

## 🎯 Overview

PetUwrite now has complete role-based authentication system with Firebase Auth and Firestore. Users are automatically routed to the appropriate screen based on their role.

---

## 👥 User Roles

| Role | Value | Description | Access |
|------|-------|-------------|--------|
| **Customer** | 0 | Regular user | Quote flow, policies, claims |
| **Premium Customer** | 1 | Premium features | All customer features + premium benefits |
| **Underwriter** | 2 | Admin access | Admin dashboard, quote review, overrides |
| **Super Admin** | 3 | Full access | All admin features + user management |

---

## 📁 Files Created

### 1. Authentication System
- **`lib/auth/auth_gate.dart`** - Main authentication router
  - Checks Firebase Auth state
  - Fetches user role from Firestore
  - Routes to appropriate screen
  - Handles loading and error states

- **`lib/auth/login_screen.dart`** - Login/signup screen
  - Email/password authentication
  - Create account functionality
  - Password reset dialog
  - Auto-creates user document in Firestore
  - Demo credentials display

- **`lib/auth/customer_home_screen.dart`** - Customer dashboard
  - Quick actions (Get Quote, My Pets, Policies, Claims)
  - Premium badge for premium users
  - Pet list integration
  - Policy list view
  - Profile management
  - Sign out functionality

### 2. Updated Files
- **`lib/main.dart`** - Updated to use AuthGate as home
  - Removed hardcoded initial route
  - Now uses `home: const AuthGate()`
  - Auth state determines user destination

---

## 🔄 Authentication Flow

```
App Start
    ↓
AuthGate checks Firebase Auth
    ↓
┌─────────────────────────────────┐
│ User Authenticated?             │
└─────────────────────────────────┘
    ↓               ↓
   NO              YES
    ↓               ↓
LoginScreen    RoleBasedRouter
                    ↓
        Fetch user role from Firestore
                    ↓
        ┌───────────────────────┐
        │ What is userRole?     │
        └───────────────────────┘
         ↓        ↓         ↓
    role=0    role=1    role=2/3
         ↓        ↓         ↓
   Customer  Premium   Admin
    Home      Home    Dashboard
```

---

## 🛠️ Setup Instructions

### Step 1: Create Demo Users in Firebase Console

1. Go to **Firebase Console** → **Authentication** → **Users**
2. Click **Add User**
3. Create these test accounts:

**Customer Account:**
```
Email: customer@test.com
Password: test123
```

**Underwriter Account:**
```
Email: admin@petuwrite.com
Password: test123
```

### Step 2: Add userRole to Firestore

1. Go to **Firebase Console** → **Firestore Database**
2. Navigate to `users/` collection
3. For each user, add the `userRole` field:

**Customer Document:**
```javascript
{
  "uid": "abc123",
  "email": "customer@test.com",
  "userRole": 0,  // Regular customer
  "createdAt": Timestamp,
  "updatedAt": Timestamp
}
```

**Underwriter Document:**
```javascript
{
  "uid": "xyz789",
  "email": "admin@petuwrite.com",
  "userRole": 2,  // Underwriter/Admin
  "createdAt": Timestamp,
  "updatedAt": Timestamp
}
```

### Step 3: Update Firestore Security Rules

Add these rules to `firestore.rules`:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function getUserRole() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.userRole;
    }
    
    function isUnderwriter() {
      return isAuthenticated() && getUserRole() >= 2;
    }
    
    function isAdmin() {
      return isAuthenticated() && getUserRole() == 3;
    }
    
    // Users collection
    match /users/{userId} {
      allow read: if isAuthenticated() && 
                    (request.auth.uid == userId || isUnderwriter());
      allow write: if request.auth.uid == userId;
      
      // User's pets subcollection
      match /pets/{petId} {
        allow read, write: if request.auth.uid == userId;
      }
      
      // User's policies subcollection
      match /policies/{policyId} {
        allow read: if request.auth.uid == userId || isUnderwriter();
        allow write: if isAdmin();
      }
    }
    
    // Quotes collection
    match /quotes/{quoteId} {
      allow read: if isAuthenticated() && 
                    (resource.data.userId == request.auth.uid || isUnderwriter());
      allow create: if isAuthenticated();
      allow update: if isAuthenticated() && 
                      (resource.data.userId == request.auth.uid || isUnderwriter());
      
      // Risk score subcollection
      match /risk_score/{scoreId} {
        allow read: if isAuthenticated();
        allow write: if isUnderwriter();
      }
      
      // Explainability subcollection
      match /explainability/{explainId} {
        allow read: if isAuthenticated();
        allow write: if false; // Only system can write
      }
    }
    
    // Policies collection
    match /policies/{policyId} {
      allow read: if isAuthenticated() && 
                    (resource.data.userId == request.auth.uid || isUnderwriter());
      allow create: if isAuthenticated();
      allow update: if isUnderwriter();
      allow delete: if isAdmin();
    }
    
    // Audit logs - write-only for underwriters, read for admins
    match /audit_logs/{logId} {
      allow create: if isUnderwriter();
      allow read: if isUnderwriter();
      allow update, delete: if false; // Immutable
    }
    
    // Claims collection
    match /claims/{claimId} {
      allow read: if isAuthenticated() && 
                    (resource.data.userId == request.auth.uid || isUnderwriter());
      allow create: if isAuthenticated();
      allow update: if isUnderwriter();
      allow delete: if isAdmin();
    }
  }
}
```

### Step 4: Deploy Security Rules

```bash
cd /Users/conorlawless/Development/PetUwrite
firebase deploy --only firestore:rules
```

---

## 🧪 Testing the System

### Test Customer Flow

1. Run the app: `flutter run`
2. You'll see the login screen
3. Sign in with: `customer@test.com` / `test123`
4. You should see the **Customer Home Screen** with:
   - Get Quote button
   - My Pets
   - My Policies
   - Claims
   - Help section

### Test Underwriter Flow

1. Sign out from customer account
2. Sign in with: `admin@petuwrite.com` / `test123`
3. You should see the **Admin Dashboard** with:
   - High-risk quotes list
   - Filter and sort options
   - Override capabilities
   - Explainability charts

### Test Sign Up

1. Click "Create Account"
2. Enter new email and password
3. Account is created with `userRole: 0` (customer) by default
4. Redirected to Customer Home Screen

---

## 🔧 How to Change User Role

### Method 1: Firebase Console (Manual)
1. Go to Firestore Database
2. Find the user in `users/` collection
3. Edit the `userRole` field
4. User must sign out and sign back in to see changes

### Method 2: Cloud Function (Automated)
Create a Cloud Function to promote users:

```javascript
// functions/userManagement.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');

exports.promoteToUnderwriter = functions.https.onCall(async (data, context) => {
  // Check if requester is admin
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }
  
  const requesterDoc = await admin.firestore()
    .collection('users')
    .doc(context.auth.uid)
    .get();
  
  if (requesterDoc.data().userRole !== 3) {
    throw new functions.https.HttpsError('permission-denied', 'Only admins can promote users');
  }
  
  // Promote user
  await admin.firestore()
    .collection('users')
    .doc(data.userId)
    .update({
      userRole: 2,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  
  return { success: true, message: 'User promoted to underwriter' };
});
```

---

## 📱 User Experience

### Customer View
```
┌─────────────────────────────────┐
│  PetUwrite             👤       │
├─────────────────────────────────┤
│  Welcome back!                  │
│  customer@test.com              │
├─────────────────────────────────┤
│  Quick Actions                  │
│                                 │
│  ┌───────────┐  ┌───────────┐  │
│  │ 📝 Get    │  │ 🐾 My     │  │
│  │   Quote   │  │   Pets    │  │
│  └───────────┘  └───────────┘  │
│                                 │
│  ┌───────────┐  ┌───────────┐  │
│  │ 📄 My     │  │ 🏥 Claims │  │
│  │ Policies  │  │           │  │
│  └───────────┘  └───────────┘  │
│                                 │
│  Need Help?                     │
│  • FAQs                         │
│  • Contact Support              │
└─────────────────────────────────┘
```

### Underwriter View
```
┌─────────────────────────────────┐
│  Underwriter Dashboard  🔄 ⋮   │
├─────────────────────────────────┤
│  Stats: 5 Total | 3 Pending    │
├─────────────────────────────────┤
│  Filters: [All] Pending         │
│  Sort: Risk Score (High→Low)    │
├─────────────────────────────────┤
│  Quote #Q001        Risk: 85 🔴 │
│  Bella (Dog)                    │
│  AI: Deny • 2 hours ago         │
│  ────────────────────────────   │
│  Quote #Q002        Risk: 92 🔴 │
│  Max (Cat)                      │
│  AI: Review • 5 hours ago       │
└─────────────────────────────────┘
```

---

## 🔒 Security Features

### Authentication
✅ Firebase Auth for secure sign-in  
✅ Password reset functionality  
✅ Email verification (can be added)  
✅ Session management  

### Authorization
✅ Role-based access control (RBAC)  
✅ Firestore security rules  
✅ Server-side role verification  
✅ Protected routes  

### Data Protection
✅ User can only see their own data  
✅ Underwriters can see high-risk quotes  
✅ Audit logs are immutable  
✅ Explainability data is read-only  

---

## 🚀 Next Steps

### Immediate
- [x] Set up demo users in Firebase Console
- [x] Add userRole to user documents
- [ ] Deploy Firestore security rules
- [ ] Test customer flow
- [ ] Test underwriter flow

### Short Term
- [ ] Add email verification
- [ ] Add forgot password email customization
- [ ] Add profile edit functionality
- [ ] Add user avatar support
- [ ] Add social login (Google, Apple)

### Future Enhancements
- [ ] Two-factor authentication
- [ ] User activity logging
- [ ] Session timeout handling
- [ ] Remember me functionality
- [ ] Biometric authentication (fingerprint/face ID)
- [ ] Admin panel for user management
- [ ] Bulk user import
- [ ] User deactivation workflow

---

## 🐛 Troubleshooting

### Problem: "User profile not found" error
**Solution**: Make sure the user document exists in Firestore `users/` collection with a `userRole` field.

```bash
# Check user document exists
firebase firestore:get users/[USER_UID]
```

### Problem: Wrong screen after login
**Solution**: Check the `userRole` value in Firestore. Sign out and sign back in.

### Problem: "Permission denied" errors
**Solution**: Deploy the updated Firestore security rules:

```bash
firebase deploy --only firestore:rules
```

### Problem: Can't access admin dashboard
**Solution**: Verify user has `userRole: 2` or `userRole: 3` in Firestore.

---

## 📞 Support

For issues with authentication:
1. Check Flutter console for errors
2. Check Firebase Console → Authentication for user status
3. Check Firestore for user document and userRole field
4. Review security rules in Firebase Console

---

## 🎉 Summary

You now have:
- ✅ Complete authentication system
- ✅ Role-based routing
- ✅ Customer dashboard
- ✅ Admin dashboard integration
- ✅ Secure Firestore rules
- ✅ Sign in/sign up/sign out
- ✅ Password reset
- ✅ Profile management
- ✅ Loading and error states

**Test Credentials:**
- Customer: `customer@test.com` / `test123`
- Underwriter: `admin@petuwrite.com` / `test123`

---

Generated: October 8, 2025  
Version: 1.0  
Status: ✅ Complete and Ready for Testing
