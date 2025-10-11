# Checkout Flow Deployment Checklist

Complete checklist for deploying the checkout flow and policy management system.

## ✅ Pre-Deployment Checklist

### 1. Firebase Configuration

- [ ] Firebase project created: `pet-underwriter-ai`
- [ ] Firebase Authentication enabled
- [ ] Cloud Firestore database created
- [ ] Firebase Storage enabled
- [ ] Cloud Functions enabled (Blaze plan required)
- [ ] Firebase project configured in Flutter app

### 2. Stripe Configuration

- [ ] Stripe account created
- [ ] Test API keys obtained
- [ ] Production API keys obtained (for production)
- [ ] `flutter_stripe` package added to `pubspec.yaml`
- [ ] Stripe publishable key configured in Flutter app
- [ ] Stripe webhook endpoint set up (if using webhooks)

### 3. SendGrid Configuration

- [ ] SendGrid account created
- [ ] SendGrid API key generated
- [ ] Sender email verified in SendGrid
- [ ] API key configured in Firebase Functions:
  ```bash
  firebase functions:config:set sendgrid.key="YOUR_API_KEY"
  ```

### 4. Dependencies Installed

#### Flutter App
```bash
cd /Users/conorlawless/Development/PetUwrite
flutter pub get
```

Verify these packages are in `pubspec.yaml`:
- [ ] `firebase_core: ^3.1.0`
- [ ] `firebase_auth: ^5.1.0`
- [ ] `cloud_firestore: ^5.0.0`
- [ ] `firebase_storage: ^12.0.0`
- [ ] `cloud_functions: ^5.0.0`
- [ ] `flutter_stripe: ^10.1.1`
- [ ] `provider: ^6.1.1`
- [ ] `intl: ^0.19.0`
- [ ] `http: ^1.2.0`

#### Cloud Functions
```bash
cd /Users/conorlawless/Development/PetUwrite/functions
npm install
```

Verify these packages are in `package.json`:
- [ ] `firebase-admin: ^12.6.0`
- [ ] `firebase-functions: ^6.0.1`
- [ ] `nodemailer: ^6.9.8`
- [ ] `pdfkit: ^0.14.0`
- [ ] `@google-cloud/storage: ^7.7.0`

## 🚀 Deployment Steps

### Phase 1: Deploy Cloud Functions

1. **Set Firebase Project**
   ```bash
   cd /Users/conorlawless/Development/PetUwrite
   firebase use pet-underwriter-ai
   ```

2. **Configure SendGrid**
   ```bash
   firebase functions:config:set sendgrid.key="YOUR_SENDGRID_API_KEY"
   ```

3. **Deploy Functions**
   ```bash
   firebase deploy --only functions
   ```

   This deploys:
   - `sendPolicyEmail` - Sends policy confirmation emails
   - `generatePolicyPDF` - Creates policy PDF documents
   - `checkExpiringPolicies` - Scheduled daily reminder check

4. **Verify Deployment**
   ```bash
   firebase functions:list
   ```

   Expected output:
   ```
   ✔ sendPolicyEmail [https://us-central1-pet-underwriter-ai...]
   ✔ generatePolicyPDF [https://us-central1-pet-underwriter-ai...]
   ✔ checkExpiringPolicies [scheduled]
   ```

### Phase 2: Configure Firestore Security Rules

Create/update `firestore.rules`:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users collection
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      // User's policies subcollection
      match /policies/{policyId} {
        allow read: if request.auth.uid == userId;
        allow write: if request.auth.uid == userId;
      }
    }
    
    // Policies collection (main)
    match /policies/{policyId} {
      allow read: if request.auth != null && 
                     resource.data.ownerId == request.auth.uid;
      allow create: if request.auth != null &&
                       request.resource.data.ownerId == request.auth.uid;
      allow update: if request.auth != null &&
                       resource.data.ownerId == request.auth.uid;
    }
    
    // Email logs (admin only in production)
    match /email_logs/{logId} {
      allow read: if request.auth != null;
      allow write: if false; // Only Cloud Functions can write
    }
    
    // Quotes collection
    match /quotes/{quoteId} {
      allow read, write: if request.auth != null &&
                            resource.data.ownerId == request.auth.uid;
    }
  }
}
```

Deploy rules:
```bash
firebase deploy --only firestore:rules
```

### Phase 3: Configure Storage Security Rules

Create/update `storage.rules`:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    
    // Policy PDFs
    match /policies/{policyId}/{fileName} {
      // Allow read if user owns the policy
      allow read: if request.auth != null;
      
      // Only Cloud Functions can write
      allow write: if false;
    }
    
    // User uploads (for claim attachments, etc.)
    match /users/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && 
                            request.auth.uid == userId;
    }
  }
}
```

Deploy rules:
```bash
firebase deploy --only storage:rules
```

### Phase 4: Test in Development

1. **Start Flutter App in Debug Mode**
   ```bash
   flutter run
   ```

2. **Test Checkout Flow**
   - [ ] Navigate to quote selection
   - [ ] Select a plan
   - [ ] Fill out owner details form
   - [ ] Complete e-sign consent
   - [ ] Test Stripe payment (use test card: 4242 4242 4242 4242)
   - [ ] Verify confirmation screen appears
   - [ ] Check policy created in Firestore
   - [ ] Test PDF download
   - [ ] Test email receipt

3. **Verify Cloud Functions**
   ```bash
   firebase functions:log
   ```

   Check for:
   - [ ] `sendPolicyEmail` executed successfully
   - [ ] `generatePolicyPDF` created PDF
   - [ ] No errors in logs

4. **Check Firestore Data**
   ```bash
   firebase firestore:get /policies --limit 1
   ```

   Or view in Firebase Console:
   - [ ] Policy document created with all fields
   - [ ] `pdfUrl` field populated
   - [ ] User reference created in `/users/{uid}/policies/`

5. **Verify Email Delivery**
   - [ ] Check inbox for policy confirmation
   - [ ] Verify PDF attachment present
   - [ ] Check email formatting looks correct
   - [ ] Verify all links work

### Phase 5: Production Deployment

1. **Update Stripe Keys**
   
   In your Flutter app, update to production keys:
   ```dart
   // lib/config/stripe_config.dart
   static const String publishableKey = 'pk_live_...'; // Production key
   ```

2. **Update Environment Variables**
   ```bash
   # Set production SendGrid key
   firebase functions:config:set sendgrid.key="YOUR_PRODUCTION_KEY"
   
   # Deploy updated config
   firebase deploy --only functions
   ```

3. **Build Production Flutter App**
   
   For Android:
   ```bash
   flutter build apk --release
   # or
   flutter build appbundle --release
   ```
   
   For iOS:
   ```bash
   flutter build ios --release
   ```
   
   For Web:
   ```bash
   flutter build web --release
   ```

4. **Deploy to Production**
   - [ ] Upload to App Store (iOS)
   - [ ] Upload to Play Store (Android)
   - [ ] Deploy to web hosting (if applicable)

## 🧪 Testing Checklist

### Unit Tests

Create test files:

```dart
// test/services/policy_service_test.dart
test('PolicyService.createPolicy creates valid policy', () async {
  // Test implementation
});

// test/models/checkout_state_test.dart
test('OwnerDetails validates email format', () {
  // Test implementation
});

// test/widgets/plan_cards_test.dart
testWidgets('PlanCards displays correct pricing', (tester) async {
  // Test implementation
});
```

Run tests:
```bash
flutter test
```

### Integration Tests

```bash
flutter drive --target=test_driver/checkout_flow.dart
```

### Manual Testing Scenarios

- [ ] **Happy Path**: Complete checkout with valid data
- [ ] **Invalid Email**: Enter invalid email format
- [ ] **Missing E-sign**: Try to proceed without consent
- [ ] **Payment Failure**: Use Stripe test card that fails
- [ ] **Network Error**: Test offline behavior
- [ ] **Expired Session**: Test after auth token expires
- [ ] **Multi-pet Discount**: Verify discount applied correctly
- [ ] **Regional Pricing**: Test different zip codes
- [ ] **PDF Generation**: Download PDF multiple times
- [ ] **Email Sending**: Send to different email providers

## 📊 Monitoring Setup

### 1. Firebase Performance Monitoring

Add to Flutter app:
```bash
flutter pub add firebase_performance
```

### 2. Firebase Crashlytics

Add to Flutter app:
```bash
flutter pub add firebase_crashlytics
```

### 3. Analytics Events

Track key events:
```dart
// Track checkout started
FirebaseAnalytics.instance.logEvent(name: 'begin_checkout');

// Track plan selected
FirebaseAnalytics.instance.logEvent(
  name: 'select_plan',
  parameters: {'plan_name': plan.name},
);

// Track purchase completed
FirebaseAnalytics.instance.logEvent(
  name: 'purchase',
  parameters: {
    'transaction_id': policyNumber,
    'value': plan.monthlyPremium,
    'currency': 'USD',
  },
);
```

### 4. Set Up Alerts

In Firebase Console:
- [ ] Alert on function errors
- [ ] Alert on high latency
- [ ] Alert on failed payments
- [ ] Alert on email delivery failures

## 🔐 Security Hardening

### 1. Enable App Check

```bash
flutter pub add firebase_app_check
```

Configure in `main.dart`:
```dart
await FirebaseAppCheck.instance.activate(
  webRecaptchaSiteKey: 'YOUR_SITE_KEY',
  androidProvider: AndroidProvider.playIntegrity,
  appleProvider: AppleProvider.deviceCheck,
);
```

### 2. Rate Limiting

Add to Cloud Functions:
```javascript
const rateLimit = require('express-rate-limit');

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100 // limit each IP to 100 requests per windowMs
});

exports.sendPolicyEmail = functions.https.onRequest(async (req, res) => {
  // Apply rate limiting
});
```

### 3. Input Validation

Ensure all user inputs are validated:
- [ ] Email format validation
- [ ] Phone number format
- [ ] Zip code format (5 digits)
- [ ] Name fields (no special characters)
- [ ] Address validation

### 4. API Key Protection

- [ ] Stripe keys stored securely (environment variables)
- [ ] SendGrid key stored in Functions config
- [ ] Firebase config files added to `.gitignore`
- [ ] No sensitive data committed to Git

## 📝 Documentation

- [ ] README.md updated with checkout flow info
- [ ] POLICY_FUNCTIONS_SETUP.md reviewed
- [ ] FLUTTER_INTEGRATION_GUIDE.md reviewed
- [ ] API documentation generated
- [ ] User guide created
- [ ] Admin dashboard documentation

## 🎉 Post-Deployment

### 1. Announce Launch

- [ ] Email existing users about new checkout flow
- [ ] Update marketing website
- [ ] Create tutorial video
- [ ] Update app store descriptions

### 2. Monitor Closely

For the first 24-48 hours:
- [ ] Check Firebase Console hourly
- [ ] Monitor error rates
- [ ] Track conversion funnel
- [ ] Review user feedback
- [ ] Check email delivery rates

### 3. Gather Feedback

- [ ] Set up in-app feedback form
- [ ] Monitor app store reviews
- [ ] Track support tickets
- [ ] Conduct user surveys

### 4. Iterate

Based on feedback:
- [ ] Fix critical bugs immediately
- [ ] Plan UX improvements
- [ ] Optimize performance bottlenecks
- [ ] Add requested features

## 🆘 Rollback Plan

If issues arise:

1. **Rollback Cloud Functions**
   ```bash
   firebase functions:delete sendPolicyEmail
   firebase functions:delete generatePolicyPDF
   ```

2. **Revert to Previous App Version**
   - Unpublish current version in app stores
   - Re-publish previous stable version

3. **Database Rollback**
   - Restore Firestore from backup if needed
   - Remove test policies

## 📞 Support Contacts

- **Firebase Support**: https://firebase.google.com/support
- **Stripe Support**: https://support.stripe.com
- **SendGrid Support**: https://support.sendgrid.com
- **Flutter Issues**: https://github.com/flutter/flutter/issues

## ✅ Final Verification

Before considering deployment complete:

- [ ] All tests passing
- [ ] No console errors
- [ ] All Cloud Functions deployed
- [ ] Security rules deployed
- [ ] Production API keys configured
- [ ] Monitoring enabled
- [ ] Documentation updated
- [ ] Team trained on new features
- [ ] Rollback plan documented
- [ ] Support team notified

---

**Deployment Date**: _____________  
**Deployed By**: _____________  
**Version**: _____________  
**Status**: ⬜ In Progress | ⬜ Completed | ⬜ Rolled Back

## Notes

_Add any deployment-specific notes here..._
