# Firebase Authentication Setup Guide

## 📋 Current Status

✅ **Firebase Project:** `pet-underwriter-ai`  
✅ **Firebase CLI:** v14.16.0 installed  
✅ **Login Screen:** Already exists with signup functionality (`lib/auth/login_screen.dart`)  
⚠️ **Firebase Authentication:** Needs to be enabled in console

---

## 🚀 Quick Setup: Enable Authentication via Firebase Console

### Option 1: Via Web Console (Recommended - Easiest)

1. **Open Firebase Console:**
   ```bash
   open https://console.firebase.google.com/project/pet-underwriter-ai/authentication
   ```

2. **Enable Authentication:**
   - Click "Get Started" (if first time)
   - Click "Sign-in method" tab
   - Click "Email/Password"
   - Toggle "Enable" to ON
   - Click "Save"

3. **Done!** Authentication is now enabled ✅

---

## 🔧 Option 2: Via CLI (Alternative Method)

Unfortunately, Firebase CLI doesn't have a direct command to enable authentication. You must use the web console for initial setup.

However, you can use CLI for user management after enabling:

```bash
# List all users (after auth is enabled)
firebase auth:export users.json --format=JSON

# Import users from file
firebase auth:import users.json --hash-algo=scrypt

# Delete all users (careful!)
# firebase auth:delete --all-users
```

---

## ✅ What You Already Have

### 1. **Login/Signup Screen** (`lib/auth/login_screen.dart`)

Your app already has a complete authentication screen with:

✅ **Email/Password Login**
✅ **Email/Password Signup** 
✅ **Password Reset**
✅ **Error Handling**
✅ **PetUwrite Branding**
✅ **Auto-creates user document in Firestore**
✅ **Sets `userRole: 0` for customers**

**Features:**
```dart
// Login
await FirebaseAuth.instance.signInWithEmailAndPassword(
  email: email,
  password: password,
);

// Signup
final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
  email: email,
  password: password,
);

// Create user document
await FirebaseFirestore.instance
    .collection('users')
    .doc(credential.user!.uid)
    .set({
  'email': email,
  'userRole': 0,  // Customer
  'createdAt': FieldValue.serverTimestamp(),
});
```

### 2. **Authentication Flow**

Your current flow:
```
1. User opens app
2. Shows ConversationalQuoteFlow (unauthenticated)
3. User completes quote
4. At checkout, redirects to LoginScreen if not logged in
5. User logs in or signs up
6. Continues to payment
```

**Code in `auth_required_checkout.dart`:**
```dart
StreamBuilder<User?>(
  stream: FirebaseAuth.instance.authStateChanges(),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      // User is logged in - show checkout
      return CheckoutScreen(...);
    } else {
      // User needs to log in
      return LoginScreen();
    }
  },
)
```

---

## 🎨 Do You Need a Separate Signup Page?

**Answer: NO, but you could add one for better UX**

### Current Setup (Already Working):
- ✅ Single screen with Login/Signup tabs
- ✅ Users can toggle between login and signup
- ✅ Simple, works well

### Optional Enhancement: Separate Signup Page

If you want a dedicated signup page (better for marketing/onboarding):

**Benefits:**
- Collect more user info (name, phone)
- Add terms & conditions checkbox
- Better onboarding flow
- Separate branding for new customers

**I can create this for you** - just let me know!

---

## 🔐 Security Rules for Firestore

After enabling authentication, update your Firestore rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users can read/write their own document
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Admin settings - read by all authenticated, write by admin only
    match /admin_settings/{document=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
                     get(/databases/$(database)/documents/users/$(request.auth.uid)).data.userRole == 2;
    }
    
    // Quotes - owned by user
    match /quotes/{quoteId} {
      allow read, write: if request.auth != null && 
                           resource.data.ownerId == request.auth.uid;
      allow create: if request.auth != null;
    }
    
    // Policies - owned by user
    match /policies/{policyId} {
      allow read: if request.auth != null && 
                    resource.data.ownerId == request.auth.uid;
      allow create: if request.auth != null;
    }
    
    // Pets - owned by user
    match /users/{userId}/pets/{petId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

**Deploy rules:**
```bash
# Save rules to firestore.rules file
# Then deploy:
firebase deploy --only firestore:rules
```

---

## 📝 Step-by-Step Setup Instructions

### Step 1: Enable Authentication (Required)

```bash
# Open Firebase Console
open https://console.firebase.google.com/project/pet-underwriter-ai/authentication

# Then in console:
# 1. Click "Get Started"
# 2. Click "Sign-in method"
# 3. Enable "Email/Password"
# 4. Save
```

### Step 2: Test Authentication (Optional)

```bash
# Run your app
cd /Users/conorlawless/Development/PetUwrite
flutter run -d chrome

# Test flow:
# 1. Complete quote
# 2. Click "Continue to Checkout"
# 3. Should see login screen
# 4. Click "Sign Up" tab
# 5. Enter email/password
# 6. Should create account and proceed to checkout
```

### Step 3: Create Test Users (Optional)

Via Firebase Console:
```bash
open https://console.firebase.google.com/project/pet-underwriter-ai/authentication/users

# Add users manually:
# - customer@test.com (userRole: 0)
# - underwriter@test.com (userRole: 1)  
# - admin@test.com (userRole: 2)
```

Or via CLI after enabling auth:
```bash
# Create admin user programmatically
# (Requires authentication to be enabled first)
```

### Step 4: Set User Roles in Firestore

After creating test users, set their roles:

```bash
# Open Firestore Console
open https://console.firebase.google.com/project/pet-underwriter-ai/firestore

# For each user in the 'users' collection:
# 1. Find user by UID
# 2. Add field: userRole = 0 (customer), 1 (underwriter), or 2 (admin)
```

Or use this script:
```javascript
// Run in Firebase Console > Firestore > Rules playground
const admin = require('firebase-admin');
const db = admin.firestore();

// Set user role
await db.collection('users').doc('USER_UID_HERE').set({
  userRole: 2,  // 0=customer, 1=underwriter, 2=admin
  email: 'admin@test.com'
}, { merge: true });
```

---

## 🧪 Testing Checklist

- [ ] Authentication enabled in Firebase Console
- [ ] Can create new account via signup
- [ ] Can login with existing account
- [ ] Password reset email works
- [ ] User document created in Firestore with `userRole: 0`
- [ ] Unauthenticated users can complete quote
- [ ] Checkout requires login
- [ ] After login, checkout flow continues
- [ ] Admin users (`userRole: 2`) can access AdminRiskControlsPage

---

## 🎯 Quick Command Summary

```bash
# 1. Enable auth (must use console)
open https://console.firebase.google.com/project/pet-underwriter-ai/authentication

# 2. Test your app
cd /Users/conorlawless/Development/PetUwrite
flutter run -d chrome

# 3. Check users (after auth enabled)
open https://console.firebase.google.com/project/pet-underwriter-ai/authentication/users

# 4. Check Firestore
open https://console.firebase.google.com/project/pet-underwriter-ai/firestore

# 5. Deploy security rules (optional)
firebase deploy --only firestore:rules
```

---

## 💡 Recommendations

### For MVP/Testing:
1. ✅ **Use existing login screen** - it's already complete
2. ✅ **Enable Email/Password auth in console** - 2 minutes
3. ✅ **Create 3 test users** - customer, underwriter, admin
4. ✅ **Test signup flow** - make sure it works end-to-end

### For Production:
1. **Add Email Verification:**
   ```dart
   await credential.user!.sendEmailVerification();
   ```

2. **Add Password Strength Requirements:**
   ```dart
   if (password.length < 8) {
     throw Exception('Password must be at least 8 characters');
   }
   ```

3. **Add Terms & Conditions:**
   ```dart
   bool _acceptedTerms = false;
   // Add checkbox before signup
   ```

4. **Add Additional User Info:**
   ```dart
   // Collect name, phone during signup
   await db.collection('users').doc(uid).set({
     'email': email,
     'name': name,
     'phone': phone,
     'userRole': 0,
     'createdAt': FieldValue.serverTimestamp(),
   });
   ```

5. **Enable Google Sign-In** (optional):
   - Easier for users
   - Requires Google Console setup
   - I can help implement this

---

## 🆘 Troubleshooting

### Error: "The email address is already in use"
- User exists, try logging in instead
- Or use password reset

### Error: "Please specify a valid email and password"
- Check email format
- Password must be at least 6 characters

### Error: "There is no user record corresponding to this identifier"
- User doesn't exist, sign up first

### Can't access admin controls
- Check `userRole` field in Firestore
- Must be exactly `2` (number, not string)

### Authentication not working
- Make sure it's enabled in Firebase Console
- Check Firebase configuration in `main.dart`
- Verify `google-services.json` (Android) or `GoogleService-Info.plist` (iOS)

---

## 🎉 Summary

**What you need to do:**

1. **Enable Authentication** (2 minutes):
   ```bash
   open https://console.firebase.google.com/project/pet-underwriter-ai/authentication
   # Enable Email/Password
   ```

2. **You're Done!** Your app already has:
   - ✅ Complete login/signup screen
   - ✅ User document creation
   - ✅ Role-based access control
   - ✅ Unauthenticated quote flow
   - ✅ Auth-required checkout

3. **Optional:** Create test users and set roles

**Do you need a separate signup page?**
- **No** - current screen works great
- **Yes** - I can create a dedicated onboarding flow

Let me know if you want me to create a separate signup page or if you need help with anything else! 🚀
