# 🚀 Unauthenticated Quote Flow Setup Guide

## 🎯 Overview

The app now starts with an **unauthenticated quote flow**, allowing users to explore insurance options without creating an account. Authentication is only required when users are ready to purchase.

---

## 📋 What Changed

### ✅ 1. Landing Page is Now Quote Flow
- **Before:** App opened to login/auth screen (AuthGate)
- **After:** App opens directly to "Get a Quote" flow
- Users can browse, enter pet info, and view plans **without logging in**

### ✅ 2. Login Button in Top Right
- Quote flow and plan selection screens now have a **Login** button in the app bar
- If logged in, shows **account menu** with user email and sign out option
- Users can create an account or sign in **anytime** during the flow

### ✅ 3. Authentication Required at Checkout
- When user clicks to purchase, they hit **authentication gate**
- Shows beautiful "Sign In Required" screen
- After login/signup, automatically continues to checkout
- New accounts are created as `userRole: 0` (customer)

---

## 🗺️ User Flow

```
App Launch
    ↓
Quote Flow (Unauthenticated)
    ↓
Enter Pet Info
    ↓
Enter Owner Info
    ↓
Upload Medical Records
    ↓
View Plans (Unauthenticated)
    ↓
Select Plan
    ↓
Click "Proceed to Checkout"
    ↓
┌───────────────────────────────┐
│ Are you authenticated?         │
└───────────────────────────────┘
    ↓           ↓
   NO          YES
    ↓           ↓
Sign In    Checkout Flow
Required   (4 Steps)
Screen
    ↓
Login/Signup
    ↓
Auto-redirect to Checkout
    ↓
Complete Purchase
    ↓
Policy Created
```

---

## 📁 Files Modified

### 1. **lib/main.dart**
**Changes:**
- Changed `home:` from `AuthGate()` to `QuoteFlowScreen()`
- Added `/auth-gate` route for authenticated users
- Updated checkout route to use `AuthRequiredCheckout` wrapper

**Code:**
```dart
// Start with quote flow - authentication only required at checkout
home: const QuoteFlowScreen(),
routes: {
  '/quote': (context) => const QuoteFlowScreen(),
  '/plan-selection': (context) => const PlanSelectionScreen(),
  '/auth-gate': (context) => const AuthGate(),
},
onGenerateRoute: (settings) {
  if (settings.name == '/checkout') {
    return MaterialPageRoute(
      builder: (context) => AuthRequiredCheckout(
        pet: args['pet'],
        selectedPlan: args['selectedPlan'],
      ),
    );
  }
}
```

### 2. **lib/screens/quote_flow_screen.dart**
**Changes:**
- Added Firebase Auth imports
- Added StreamBuilder in AppBar to show login button or account menu
- Login button navigates to `LoginScreen`
- Account menu shows user email, dashboard link, and sign out

**New AppBar:**
```dart
appBar: AppBar(
  title: const Text('Get a Quote'),
  actions: [
    StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          // Show account menu
          return PopupMenuButton(...);
        } else {
          // Show login button
          return TextButton.icon(
            onPressed: () => Navigator.push(...),
            icon: const Icon(Icons.login),
            label: const Text('Login'),
          );
        }
      },
    ),
  ],
),
```

### 3. **lib/screens/plan_selection_screen.dart**
**Changes:**
- Same login button/account menu as quote flow screen
- Consistent UI across all unauthenticated screens

### 4. **lib/screens/auth_required_checkout.dart** (NEW)
**Purpose:** Wrapper that checks authentication before showing checkout

**Components:**
- `AuthRequiredCheckout`: StreamBuilder widget that checks auth state
- `_LoginRequiredScreen`: Beautiful screen prompting user to sign in

**Features:**
- Shows selected plan summary
- "Sign In or Create Account" button
- Lists benefits of creating account (manage policies, file claims, etc.)
- After login, auto-continues to checkout

**Code Structure:**
```dart
class AuthRequiredCheckout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return CheckoutScreen(...); // Authenticated - show checkout
        }
        return _LoginRequiredScreen(...); // Not authenticated - show login prompt
      },
    );
  }
}
```

---

## 🎨 UI/UX Features

### Login Button (Unauthenticated State)
```
┌─────────────────────────────────┐
│  Get a Quote     [🔓 Login]     │
└─────────────────────────────────┘
```

### Account Menu (Authenticated State)
```
┌─────────────────────────────────┐
│  Get a Quote     [👤]           │
│                   ↓              │
│            ┌──────────────┐     │
│            │ 📧 user@...  │     │
│            │ 📊 Dashboard │     │
│            │ 🚪 Sign Out  │     │
│            └──────────────┘     │
└─────────────────────────────────┘
```

### Sign In Required Screen
```
┌─────────────────────────────────┐
│ ← Sign In Required              │
├─────────────────────────────────┤
│                                 │
│         🔒                      │
│                                 │
│   Sign In to Continue           │
│                                 │
│   Create an account or sign in  │
│   to complete your purchase...  │
│                                 │
│   ┌───────────────────────────┐ │
│   │  Your Selected Plan       │ │
│   │  Standard           $49.99│ │
│   │  For Bella                │ │
│   └───────────────────────────┘ │
│                                 │
│   ┌─────────────────────────┐   │
│   │ Sign In or Create Account│ │
│   └─────────────────────────┘   │
│                                 │
│   ℹ️ Why create an account?     │
│   ✓ Manage policies online      │
│   ✓ File claims easily          │
│   ✓ Track pet's coverage        │
│   ✓ 24/7 support                │
│                                 │
└─────────────────────────────────┘
```

---

## 🔐 Authentication Behavior

### New Account Creation
When users sign up during checkout:
1. Firebase Auth account created
2. Firestore user document created:
   ```json
   {
     "uid": "abc123",
     "email": "user@example.com",
     "userRole": 0,
     "createdAt": Timestamp,
     "updatedAt": Timestamp
   }
   ```
3. User automatically authenticated
4. Redirected to checkout to complete purchase

### Existing User Login
1. User enters credentials
2. Firebase Auth validates
3. Auto-redirects to checkout
4. Purchase flow continues

### Optional Login
Users can click the **Login** button anytime:
- Top right of quote flow screen
- Top right of plan selection screen
- After login, returns to where they were
- All form data preserved

---

## 🛣️ Routing Structure

### Public Routes (No Auth Required)
- `/` - Quote flow screen (landing page)
- `/quote` - Quote flow screen
- `/plan-selection` - Plan selection screen

### Protected Routes (Auth Required)
- `/checkout` - Wrapped in `AuthRequiredCheckout`
- `/confirmation` - Policy confirmation screen
- `/auth-gate` - Role-based routing for authenticated users

### Auth Routes
- `LoginScreen` - Push navigation (not route-based)
- `CustomerHomeScreen` - Accessed via account menu

---

## 🧪 Testing the Flow

### Test 1: Unauthenticated User
1. **Run app:** `flutter run`
2. **Expected:** See "Get a Quote" screen (not login)
3. **Check:** Login button visible in top right
4. **Action:** Fill out pet info, proceed to plans
5. **Action:** Select a plan, click checkout
6. **Expected:** See "Sign In Required" screen
7. **Action:** Click "Sign In or Create Account"
8. **Expected:** See login screen
9. **Action:** Create account or sign in
10. **Expected:** Auto-redirect to checkout flow

### Test 2: Optional Login
1. **Start at quote flow**
2. **Click:** Login button in top right
3. **Action:** Sign in
4. **Expected:** Return to quote flow with account menu visible
5. **Check:** Account menu shows email and dashboard option

### Test 3: Already Authenticated
1. **Launch app while logged in**
2. **Expected:** See quote flow (not customer dashboard)
3. **Check:** Account menu visible instead of login button
4. **Action:** Proceed through flow and select plan
5. **Action:** Click checkout
6. **Expected:** Go directly to checkout (no login prompt)

### Test 4: Sign Out
1. **Click:** Account menu in top right
2. **Click:** "Sign Out"
3. **Expected:** Remain on quote flow
4. **Check:** Login button now visible (not account menu)

---

## 🎯 Benefits of This Approach

### For Users
✅ **Lower barrier to entry** - No forced signup to explore  
✅ **Better conversion** - See value before committing  
✅ **Flexible authentication** - Sign in when ready  
✅ **Seamless experience** - Auto-redirect after auth  

### For Business
✅ **Higher funnel entry** - More users explore quotes  
✅ **Better analytics** - Track drop-off points  
✅ **Reduced friction** - Only authenticate when necessary  
✅ **Guest browsing** - Users can share links  

### For Development
✅ **Clean separation** - Quote flow independent of auth  
✅ **Reusable components** - Login button pattern  
✅ **Easy testing** - Can test flows separately  
✅ **Role-based routing** - Still works for admins/underwriters  

---

## 🔄 How Existing Features Work

### Admin Dashboard
Admins can still access their dashboard:
1. Click **Login** button
2. Sign in with `userRole: 2` or `3` account
3. Account menu appears
4. Navigate to dashboard via menu or go to `/auth-gate`

### Customer Dashboard
Customers can access their dashboard:
1. Sign in during quote flow (or after)
2. Click **account menu**
3. Select "Dashboard"
4. See CustomerHomeScreen with policies, pets, etc.

### Role-Based Routing
`AuthGate` still works for existing users:
- Navigate to `/auth-gate` route
- Checks user role
- Routes to appropriate screen:
  - `userRole: 0` → CustomerHomeScreen
  - `userRole: 1` → CustomerHomeScreen (premium)
  - `userRole: 2/3` → AdminDashboard

---

## 🚧 Future Enhancements

### Phase 1 (Current) ✅
- [x] Unauthenticated quote flow
- [x] Login button in app bar
- [x] Auth required at checkout
- [x] Auto-redirect after login

### Phase 2 (Recommended)
- [ ] Save quote progress to localStorage
- [ ] "Continue as guest" option
- [ ] Email quote summary without account
- [ ] Social login (Google, Apple)

### Phase 3 (Advanced)
- [ ] Guest checkout with optional account creation
- [ ] Email verification before policy activation
- [ ] Link guest quotes to new accounts
- [ ] Progressive profiling (ask for details over time)

---

## 📞 Common Questions

### Q: Can users checkout without an account?
**A:** No, an account is required to create a policy. However, they can explore quotes and plans without logging in.

### Q: What happens to their form data when they sign in?
**A:** Form data is preserved in the app state. After login, they continue right where they left off.

### Q: Can admins still access the admin dashboard?
**A:** Yes! They can log in via the Login button, then navigate to `/auth-gate` or access via the account menu.

### Q: Do users need to log in to see plan prices?
**A:** No! All plan information and pricing is visible to unauthenticated users. Only checkout requires authentication.

### Q: Can I change the landing page back to the login screen?
**A:** Yes, in `main.dart` change `home: const QuoteFlowScreen()` to `home: const AuthGate()`.

---

## 🎉 Summary

### What You Get
✅ Users land directly on quote flow (no forced login)  
✅ Login button in top right of all public screens  
✅ Authentication required only at checkout  
✅ Beautiful "Sign In Required" screen  
✅ Auto-redirect after login  
✅ New accounts created as `userRole: 0` (customer)  
✅ Admin/underwriter access still works  
✅ Seamless user experience  

### Key Files
- `lib/main.dart` - Updated routing
- `lib/screens/quote_flow_screen.dart` - Added login button
- `lib/screens/plan_selection_screen.dart` - Added login button
- `lib/screens/auth_required_checkout.dart` - New auth wrapper

### Test It
```bash
flutter run
```

**Expected:** See "Get a Quote" screen with Login button in top right!

---

**Generated:** October 8, 2025  
**Version:** 2.0  
**Status:** ✅ Complete and Ready to Use
