# Stripe Test Key Setup - Complete Instructions

**Date:** October 14, 2025  
**Status:** ✅ Local `.env` updated, 🟡 Firebase Functions config needed

---

## ✅ What's Been Done

### 1. Local `.env` File Updated
Your Stripe test key has been added to `.env`:
```properties
STRIPE_SECRET_KEY=sk_test_your_stripe_test_secret_key_here
```

This will work for local Flutter development and testing.

---

## 🔧 What You Need To Do Next

### 2. Add Stripe Key to Firebase Functions Config

Your Cloud Functions (in `functions/index.js` and `functions/claimsReconciliation.js`) expect the Stripe key to be in Firebase Functions environment config.

**Run this command to set it:**

```bash
cd /Users/conorlawless/Development/PetUwrite
firebase functions:config:set stripe.secret_key="sk_test_your_stripe_test_secret_key_here"
```

**Then verify it was set:**
```bash
firebase functions:config:get
```

You should see:
```json
{
  "stripe": {
    "secret_key": "sk_test_your_stripe_test_secret_key_here"
  }
}
```

**Redeploy your functions to pick up the new config:**
```bash
firebase deploy --only functions
```

---

### 3. Update Your Cloud Functions Code

Your functions are currently reading from `process.env.STRIPE_SECRET_KEY`, but Firebase Functions config uses a different format. You need to update this:

#### File: `functions/claimsReconciliation.js`

**Current code (line 21):**
```javascript
const STRIPE_SECRET_KEY = process.env.STRIPE_SECRET_KEY;
```

**Should be changed to:**
```javascript
const functions = require('firebase-functions');
const STRIPE_SECRET_KEY = functions.config().stripe?.secret_key || process.env.STRIPE_SECRET_KEY;
```

This will work both in production (Firebase) and local development (.env file).

---

### 4. Test Stripe Integration

Once you've set up the config, test your Stripe integration:

#### A. Install Stripe CLI (if not already installed)
```bash
brew install stripe/stripe-cli/stripe
```

#### B. Login to Stripe
```bash
stripe login
```

#### C. Forward webhooks to local functions
```bash
stripe listen --forward-to http://localhost:5001/YOUR-PROJECT-ID/us-central1/stripeWebhook
```

Replace `YOUR-PROJECT-ID` with your Firebase project ID.

#### D. Test a payment
```bash
stripe trigger payment_intent.succeeded
```

---

## 📋 Where Stripe is Used in Your Codebase

### Flutter App (Client-Side)
- **`lib/services/stripe_service.dart`** - Stripe SDK wrapper
- **`lib/services/payment_processor.dart`** - Payment processing logic (uses StripeService)

### Cloud Functions (Server-Side)
- **`functions/index.js`** - `stripeWebhook` endpoint (line 335)
- **`functions/claimsReconciliation.js`** - Stripe payout retries (line 21)

---

## 🔒 Security Notes

1. **Test Key:** The key you provided is a test key (`sk_test_...`), which is safe for development
2. **Never commit:** Your `.env` file should already be in `.gitignore`
3. **Production key:** When ready to launch, you'll need to:
   - Get production key from Stripe dashboard
   - Update Firebase Functions config: `firebase functions:config:set stripe.secret_key="sk_live_..."`
   - Never expose production keys in code or logs

---

## ✅ Quick Start Checklist

Run these commands in order:

```bash
# 1. Set Stripe key in Firebase Functions config
firebase functions:config:set stripe.secret_key="sk_test_your_stripe_test_secret_key_here"

# 2. Verify it was set
firebase functions:config:get

# 3. Deploy functions with new config
firebase deploy --only functions

# 4. Install Stripe CLI (if needed)
brew install stripe/stripe-cli/stripe

# 5. Login to Stripe
stripe login

# 6. Start local functions emulator
firebase emulators:start --only functions

# 7. In a new terminal, forward webhooks
stripe listen --forward-to http://localhost:5001/YOUR-PROJECT-ID/us-central1/stripeWebhook

# 8. Test a payment
stripe trigger payment_intent.succeeded
```

---

## 📚 Next Steps

After setting up Stripe, refer to your `TECHNICAL_GAPS_ANALYSIS.md` for the complete testing checklist:

### Week 1 Priority: Stripe Payment Testing
- [ ] Test payment intent creation (test mode) ✅ Key now added!
- [ ] Test subscription management
- [ ] Test webhook handlers with Stripe CLI
- [ ] Test failed payment scenarios
- [ ] Test refund processing

**Estimated Time:** 3-4 days

**Docs:** See Section 1.A in `TECHNICAL_GAPS_ANALYSIS.md`

---

## 🆘 Troubleshooting

### Issue: "Stripe key not found"
**Solution:** Make sure you ran `firebase functions:config:set` and redeployed functions

### Issue: "Webhooks not being received"
**Solution:** Check that your Stripe CLI is running and forwarding to the correct URL

### Issue: "Payment intent creation fails"
**Solution:** Check Firebase Functions logs: `firebase functions:log`

### Issue: "Invalid API key"
**Solution:** Verify the key in Stripe dashboard (https://dashboard.stripe.com/test/apikeys)

---

**Status:** Ready for testing! 🚀

Run the commands above and you'll be ready to test your Stripe integration.
