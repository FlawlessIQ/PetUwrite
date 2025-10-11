# 🚀 Quick Reference: Unauthenticated Quote Flow

## What Changed

| Before | After |
|--------|-------|
| Landing page: Login screen | Landing page: Quote flow |
| Must login to browse | Browse freely, login at checkout |
| AuthGate controls entry | AuthGate used only for authenticated routes |

---

## User Journey

```
Launch App → Quote Flow → Plans → Checkout Gate → Sign In → Purchase
              ↑_____________Optional Login Button_______________↑
```

---

## Key Features

### ✅ Landing Page
- **Opens directly to:** "Get a Quote" screen
- **No login required:** Users can explore freely
- **Login option:** Button in top right corner

### ✅ Login Button
- **Location:** Top right of QuoteFlowScreen and PlanSelectionScreen
- **Unauthenticated:** Shows "Login" text button
- **Authenticated:** Shows account menu with email and sign out

### ✅ Authentication Gate
- **Triggered:** When user clicks to checkout
- **Shows:** Beautiful "Sign In Required" screen
- **Action:** Navigate to LoginScreen
- **After login:** Auto-redirect to checkout

### ✅ Account Creation
- **When:** User signs up during flow
- **Creates:** Firebase Auth account + Firestore user document
- **Role:** Automatically set to `userRole: 0` (customer)

---

## Modified Files

```
lib/
├── main.dart                           # Changed home to QuoteFlowScreen
├── screens/
│   ├── quote_flow_screen.dart         # Added login button in appBar
│   ├── plan_selection_screen.dart     # Added login button in appBar
│   └── auth_required_checkout.dart    # NEW - Auth wrapper for checkout
```

---

## Code Snippets

### Main.dart
```dart
home: const QuoteFlowScreen(), // Changed from AuthGate()
```

### Login Button Pattern
```dart
StreamBuilder<User?>(
  stream: FirebaseAuth.instance.authStateChanges(),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      return PopupMenuButton(...); // Account menu
    } else {
      return TextButton.icon(     // Login button
        icon: Icon(Icons.login),
        label: Text('Login'),
      );
    }
  },
)
```

### Checkout Routing
```dart
onGenerateRoute: (settings) {
  if (settings.name == '/checkout') {
    return MaterialPageRoute(
      builder: (context) => AuthRequiredCheckout(...),
    );
  }
}
```

---

## Testing Checklist

- [ ] App opens to quote flow (not login)
- [ ] Login button visible in top right
- [ ] Can fill out quote without authentication
- [ ] Can view plans without authentication
- [ ] Checkout triggers "Sign In Required" screen
- [ ] Login redirects back to checkout
- [ ] Account menu shows after login
- [ ] Sign out returns to quote flow

---

## Routes

| Route | Auth Required? | Purpose |
|-------|----------------|---------|
| `/` | No | Quote flow (landing) |
| `/quote` | No | Quote flow |
| `/plan-selection` | No | Plan selection |
| `/checkout` | **Yes** | Checkout (wrapped in AuthRequiredCheckout) |
| `/confirmation` | Yes | Policy confirmation |
| `/auth-gate` | Yes | Role-based routing |

---

## Quick Commands

```bash
# Run the app
flutter run

# Run on web
flutter run -d chrome

# Hot restart (reload environment changes)
# Press 'R' in terminal

# Hot reload (code changes)
# Press 'r' in terminal
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Still seeing login on launch | Clear app data and restart |
| Login button not showing | Check StreamBuilder in appBar |
| Checkout not requiring auth | Verify using AuthRequiredCheckout wrapper |
| Can't access admin dashboard | Login and navigate to `/auth-gate` |

---

## Architecture

```
App Launch
    ↓
QuoteFlowScreen (public)
    ├── Login Button (optional)
    └── Continue Flow
         ↓
PlanSelectionScreen (public)
    ├── Login Button (optional)
    └── Select Plan
         ↓
AuthRequiredCheckout (gate)
    ├── Not Authenticated → LoginScreen
    │                           ↓
    │                    Create Account (userRole: 0)
    │                           ↓
    └── Authenticated → CheckoutScreen
                            ↓
                     Complete Purchase
                            ↓
                     Policy Created
```

---

**Quick Tip:** Users can browse everything except checkout without an account!

**Status:** ✅ Ready to Use  
**Last Updated:** October 8, 2025
