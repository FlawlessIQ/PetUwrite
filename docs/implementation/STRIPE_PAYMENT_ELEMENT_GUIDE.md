# Stripe Payment Element Integration - Implementation Guide

## Overview

This implementation adds **Stripe Payment Element** directly to the payment screen with a **dev-only bypass button** for testing. The solution is web-first but maintains mobile compatibility using flutter_stripe's PaymentSheet.

## Files Added/Modified

### New Files
1. `/lib/payments/stripe_payment_element.dart` - Web-only Payment Element widget using HtmlElementView
2. `/lib/payments/stripe_payment_element_stub.dart` - Stub for non-web platforms
3. `/functions/payment.js` - Cloud Functions for PaymentIntent creation and webhook handling

### Modified Files
1. `/lib/screens/payment_screen.dart` - Integrated Payment Element and bypass button
2. `/functions/index.js` - Exported new payment functions

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ payment_screen.dart (Flutter Web)                           │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ 1. Initialize PaymentIntent                          │  │
│  │    → Call createPaymentIntent Cloud Function         │  │
│  │    → Receive clientSecret                            │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ 2. Mount Stripe Payment Element                      │  │
│  │    → stripe_payment_element.dart (HtmlElementView)   │  │
│  │    → Load Stripe.js, create Elements, mount          │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ 3. User enters card → Clicks "Pay & Activate"        │  │
│  │    → Call stripe.confirmPayment()                    │  │
│  │    → Handle success/error                            │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                               ↓
┌─────────────────────────────────────────────────────────────┐
│ Firebase Cloud Functions                                     │
│                                                               │
│  createPaymentIntent → Stripe API → Return clientSecret     │
│  handlePaymentIntentSucceeded (webhook) → Update Firestore  │
└─────────────────────────────────────────────────────────────┘
```

## Security Features

### Dev-Only Bypass Button

The bypass button is protected by multiple layers:

```dart
// 1. Compile-time environment flag
static const bool _kAllowPaymentBypass = bool.fromEnvironment(
  'ALLOW_PAYMENT_BYPASS',
  defaultValue: false,
);

// 2. Debug mode check
bool get _showBypassButton => kDebugMode || _kAllowPaymentBypass;

// 3. Runtime assertion
assert(!kReleaseMode, 'Payment bypass must never be enabled in release mode');
```

**Bypass Button Behavior:**
- Only visible when `kDebugMode == true` OR `ALLOW_PAYMENT_BYPASS=true` is set during build
- Never visible in release builds
- Creates PaymentInfo with status='test_bypass' and paymentIntentId='TEST_BYPASS_*'
- Shows orange warning snackbar
- Logs to console with ⚠️ prefix

## Testing Instructions

### Test 1: Payment Element on Web (Stripe Test Card)

1. **Start the app in debug mode:**
   ```bash
   flutter run -d chrome --web-port 8080
   ```

2. **Navigate to payment screen:**
   - Complete pet details
   - Complete owner information
   - Arrive at payment screen

3. **Verify Payment Element loads:**
   - Should see Stripe Payment Element embedded on page
   - Should show card input fields, expiry, CVC, ZIP
   - Styling should match premium white canvas design (green accent)

4. **Enter Stripe test card:**
   ```
   Card: 4242 4242 4242 4242
   Expiry: 12/34
   CVC: 123
   ZIP: 12345
   ```

5. **Click "Pay & Activate":**
   - Should process payment via Stripe.js
   - Should show green success snackbar: "Payment successful!"
   - Should advance to confirmation screen
   - Check console for: ✅ Payment confirmed: {result}

6. **Verify payment in Stripe Dashboard:**
   - Go to https://dashboard.stripe.com/test/payments
   - Should see new PaymentIntent with status "succeeded"

### Test 2: Dev Bypass Button

1. **Start in debug mode:**
   ```bash
   flutter run -d chrome --web-port 8080
   ```

2. **Navigate to payment screen**

3. **Verify bypass button visible:**
   - Should see "Bypass Payment (DEV)" button below save/resume options
   - Button should be outlined, orange/warning color
   - Should have code icon

4. **Click "Bypass Payment (DEV)":**
   - Should show confirmation dialog with warning icon
   - Title: "Dev Mode: Bypass Payment"
   - Content explains this is dev-only

5. **Confirm bypass:**
   - Should show orange snackbar: "DEV MODE: Payment bypassed!"
   - Should advance to confirmation screen immediately
   - Check console for: ⚠️ DEV MODE: Payment bypassed - TEST_BYPASS_*

6. **Verify state:**
   - PaymentInfo.status should be 'test_bypass'
   - PaymentInfo.paymentIntentId should start with 'TEST_BYPASS_'
   - Amount should be $0.00

### Test 3: Bypass NOT Visible in Release

1. **Build for release:**
   ```bash
   flutter build web --release
   ```

2. **Serve the build:**
   ```bash
   cd build/web
   python3 -m http.server 8080
   ```

3. **Navigate to payment screen**

4. **Verify:**
   - ❌ Bypass button should NOT be visible
   - ✅ Only "Pay & Activate" button visible
   - ✅ Payment Element should work normally

### Test 4: Mobile Payment Sheet (Native)

1. **Run on iOS simulator:**
   ```bash
   flutter run -d "iPhone 15"
   ```

2. **Navigate to payment screen:**
   - Should see CardField (native Stripe component)
   - Should NOT see HtmlElementView
   - Should NOT see "Payment Element is only available on web" message

3. **Enter card details in CardField:**
   - Use same test card: 4242 4242 4242 4242

4. **Click "Pay & Activate":**
   - Should present native PaymentSheet
   - Should complete payment
   - Should advance to confirmation

### Test 5: Coupon Code (TEST100)

1. **On payment screen, apply coupon "TEST100"**

2. **Verify:**
   - Should show "Test coupon applied - no payment required"
   - Card input section should be replaced with success banner
   - Bypass button should still be visible (dev mode)
   - "Pay & Activate" should skip Stripe, mark as 'test_waived'

### Test 6: Error Handling

1. **Test declined card:**
   ```
   Card: 4000 0000 0000 0002 (declined card)
   ```

2. **Verify:**
   - Should show inline error banner (not snackbar)
   - Error message should be clear
   - Should allow retry without reload

3. **Test incomplete card:**
   - Enter partial card number, click "Pay & Activate"
   - Should show validation error

## Configuration

### Stripe Keys

**Publishable Key** (hardcoded in payment_screen.dart):
```dart
publishableKey: 'pk_test_51SI7vTPzjq9wJkU5zFAJvBSWvFLKfu9Be4klAyLdG8IOjHpQwsw8My1WxhrbagFztc549VKyQAmAtCklGOpbeo4v00IAlWsINb'
```

**Secret Key** (Firebase Functions config):
```bash
firebase functions:config:set stripe.secret_key="sk_test_..."
```

### Environment Variables

To enable bypass in non-debug builds (e.g., staging):
```bash
flutter run --dart-define=ALLOW_PAYMENT_BYPASS=true
```

## Cloud Functions Setup

### Deploy Payment Functions

```bash
cd functions
npm install stripe --save
firebase deploy --only functions:createPaymentIntent,functions:handlePaymentIntentSucceeded
```

### Configure Stripe Webhook

1. Go to Stripe Dashboard → Webhooks
2. Add endpoint: `https://us-central1-pet-underwriter-ai.cloudfunctions.net/handlePaymentIntentSucceeded`
3. Select events:
   - `payment_intent.succeeded`
   - `payment_intent.payment_failed`
4. Copy webhook signing secret
5. Set in Firebase config:
   ```bash
   firebase functions:config:set stripe.webhook_secret="whsec_..."
   ```

## Troubleshooting

### Payment Element not loading

**Symptom:** Shows spinner indefinitely

**Fix:**
- Check console for "Failed to initialize payment intent"
- Verify Cloud Function is deployed: `firebase functions:list`
- Check function logs: `firebase functions:log --only createPaymentIntent`
- Verify user is authenticated

### "Payment form not initialized" error

**Symptom:** Error when clicking "Pay & Activate"

**Fix:**
- Check `_clientSecret` is not null (add breakpoint)
- Verify `_paymentElementKey?.currentState` exists
- Check browser console for Stripe.js errors

### Bypass button visible in release

**Symptom:** Dev bypass button shows in production

**Fix:**
- Verify build was `--release` mode
- Check `kDebugMode` value in running app
- Ensure no `--dart-define=ALLOW_PAYMENT_BYPASS=true` flag was used

### CORS errors on web

**Symptom:** Network requests fail with CORS error

**Fix:**
- Add to `firebase.json`:
  ```json
  "hosting": {
    "headers": [
      {
        "source": "**",
        "headers": [
          {
            "key": "Access-Control-Allow-Origin",
            "value": "*"
          }
        ]
      }
    ]
  }
  ```

## Code Snippets

### Manually test createPaymentIntent

```dart
final callable = FirebaseFunctions.instance.httpsCallable('createPaymentIntent');
final response = await callable.call({
  'amount': 4999, // $49.99
  'currency': 'usd',
  'policyId': 'test_policy_123',
});
print(response.data['clientSecret']);
```

### Check if bypass is enabled

```dart
import 'package:flutter/foundation.dart';

void checkBypassStatus() {
  const bypass = bool.fromEnvironment('ALLOW_PAYMENT_BYPASS', defaultValue: false);
  print('kDebugMode: $kDebugMode');
  print('kReleaseMode: $kReleaseMode');
  print('ALLOW_PAYMENT_BYPASS: $bypass');
  print('Bypass visible: ${kDebugMode || bypass}');
}
```

## Next Steps

1. **Replace test keys with live keys** for production
2. **Add loading states** during Payment Element initialization
3. **Implement retry logic** for failed payment confirmations
4. **Add analytics** to track payment success/failure rates
5. **Test 3D Secure** cards (4000 0027 6000 3184)
6. **Mobile optimization** - consider PaymentSheet for mobile too

## Support

For Stripe API issues:
- Stripe Docs: https://stripe.com/docs/payments/payment-element
- Stripe Support: https://support.stripe.com

For Flutter Stripe integration:
- flutter_stripe package: https://pub.dev/packages/flutter_stripe
- GitHub: https://github.com/flutter-stripe/flutter_stripe
