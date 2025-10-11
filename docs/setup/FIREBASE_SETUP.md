# Firebase and Stripe Setup Guide

## Firebase Configuration Complete ✅

### What's Been Set Up:

1. **Firebase Project**: `pet-underwriter-ai` (Project ID: pet-underwriter-ai)
2. **Firebase Authentication**: Ready for email/password and social logins
3. **Firestore Database**: With security rules and indexes
4. **Cloud Functions**: Webhook triggers for quotes and policies
5. **Firebase Options**: Generated in `lib/firebase_options.dart`

## Next Steps

### 1. Complete Firebase App Registration

The `firebase_options.dart` file has placeholder API keys. To get the real keys:

```bash
# Go to Firebase Console
open https://console.firebase.google.com/project/pet-underwriter-ai

# Add apps for each platform:
# 1. Click "Add app" and select platform (iOS/Android/Web)
# 2. Follow the setup wizard
# 3. Run FlutterFire configure again to update keys:
flutterfire configure --project=pet-underwriter-ai
```

Or manually:
1. Go to Project Settings > General
2. Add apps and download config files
3. Update `lib/firebase_options.dart` with the real API keys

### 2. Enable Authentication Providers

```bash
# Go to Authentication section
open https://console.firebase.google.com/project/pet-underwriter-ai/authentication/providers

# Enable these providers:
```

**Email/Password:**
- Click "Email/Password"
- Toggle "Enable"
- Save

**Google Sign-In:**
- Click "Google"
- Toggle "Enable"
- Enter project support email
- Save

**Apple Sign-In (for iOS):**
- Click "Apple"
- Toggle "Enable"
- Configure Services ID and key
- Save

### 3. Deploy Firestore Rules

```bash
# Deploy security rules
firebase deploy --only firestore:rules --project pet-underwriter-ai

# Deploy indexes
firebase deploy --only firestore:indexes --project pet-underwriter-ai
```

### 4. Deploy Cloud Functions

```bash
# Deploy all functions
cd functions
npm install
cd ..
firebase deploy --only functions --project pet-underwriter-ai
```

### 5. Install and Configure Stripe Extension

#### Option A: Using Firebase Console (Recommended)

1. Go to Firebase Console Extensions:
```bash
open https://console.firebase.google.com/project/pet-underwriter-ai/extensions
```

2. Click "Install Extension"
3. Search for "Run Payments with Stripe"
4. Click Install
5. Follow the setup wizard:
   - Enter Stripe API keys (get from https://dashboard.stripe.com/apikeys)
   - Configure webhook settings
   - Set up customer and payment collections

#### Option B: Using Firebase CLI

```bash
# Install Stripe extension
firebase ext:install stripe/firestore-stripe-payments \
  --project=pet-underwriter-ai
```

When prompted, configure:
- **Stripe API Secret Key**: Get from Stripe Dashboard
- **Stripe Webhook Secret**: Get from Stripe Dashboard > Webhooks
- **Customer collection**: `users`
- **Products collection**: `products`

### 6. Stripe Configuration

1. **Get Stripe Keys:**
```bash
# Sign up or login to Stripe
open https://dashboard.stripe.com/

# Get your keys from Dashboard > Developers > API Keys
# You'll need:
# - Publishable key (starts with pk_)
# - Secret key (starts with sk_)
```

2. **Create Products in Stripe:**
```bash
# Create products for each insurance plan:
# - Basic Plan
# - Standard Plan
# - Premium Plan

# Each with monthly/quarterly/annual pricing
```

3. **Set up Webhook Endpoint:**
```bash
# After deploying Cloud Functions, get the webhook URL:
firebase functions:config:get --project pet-underwriter-ai

# Add webhook endpoint in Stripe Dashboard:
open https://dashboard.stripe.com/webhooks

# Add endpoint: https://us-central1-pet-underwriter-ai.cloudfunctions.net/stripeWebhook
# Select events:
# - payment_intent.succeeded
# - payment_intent.failed
# - customer.subscription.created
# - customer.subscription.updated
# - customer.subscription.deleted
```

4. **Update Flutter App with Stripe:**

Add to `pubspec.yaml`:
```yaml
dependencies:
  flutter_stripe: ^10.1.1
```

Create `lib/services/stripe_service.dart`:
```dart
import 'package:flutter_stripe/flutter_stripe.dart';

class StripeService {
  static Future<void> init() async {
    Stripe.publishableKey = 'pk_test_YOUR_KEY_HERE';
    await Stripe.instance.applySettings();
  }
}
```

Update `main.dart`:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize Stripe
  await StripeService.init();
  
  runApp(const PetUnderwriterAI());
}
```

### 7. Environment Variables (Optional but Recommended)

Create `.env` file (add to .gitignore):
```bash
STRIPE_PUBLISHABLE_KEY=pk_test_xxxxx
STRIPE_SECRET_KEY=sk_test_xxxxx
OPENAI_API_KEY=sk-xxxxx
VERTEX_AI_PROJECT_ID=pet-underwriter-ai
```

Use `flutter_dotenv` package to load:
```yaml
dependencies:
  flutter_dotenv: ^5.1.0
```

### 8. Test the Setup

```bash
# 1. Start Firebase emulators (optional for local testing)
firebase emulators:start --project pet-underwriter-ai

# 2. Run the Flutter app
flutter run

# 3. Test authentication
# 4. Create a quote
# 5. Check Cloud Functions logs
firebase functions:log --project pet-underwriter-ai

# 6. Test payment flow (use Stripe test cards)
# Card number: 4242 4242 4242 4242
# Expiry: Any future date
# CVC: Any 3 digits
```

## Firestore Collections Structure

Your Firestore will have these collections:

```
/users/{userId}
  - firstName: string
  - lastName: string
  - email: string
  - phoneNumber: string
  - address: map
  - createdAt: timestamp

/pets/{petId}
  - ownerId: string
  - name: string
  - species: string
  - breed: string
  - dateOfBirth: timestamp
  - preExistingConditions: array
  - createdAt: timestamp

/quotes/{quoteId}
  - ownerId: string
  - petId: string
  - riskScore: map
  - availablePlans: array
  - status: string
  - createdAt: timestamp
  - expiresAt: timestamp

/policies/{policyId}
  - ownerId: string
  - petId: string
  - quoteId: string
  - policyNumber: string
  - plan: map
  - status: string
  - effectiveDate: timestamp
  - expirationDate: timestamp
  - subscriptionId: string
  - createdAt: timestamp

/riskScores/{scoreId}
  - petId: string
  - ownerId: string
  - overallScore: number
  - riskLevel: string
  - categoryScores: map
  - calculatedAt: timestamp

/payments/{paymentId}
  - userId: string
  - policyId: string
  - amount: number
  - status: string
  - paymentIntentId: string
  - createdAt: timestamp

/paymentReminders/{reminderId}
  - policyId: string
  - ownerId: string
  - nextPaymentDate: timestamp
  - status: string
  - createdAt: timestamp
```

## Security Notes

1. **Never commit API keys** to version control
2. Use environment variables for sensitive data
3. Enable Firestore security rules before going to production
4. Use Stripe test keys during development
5. Set up proper error handling and logging
6. Implement rate limiting on Cloud Functions
7. Enable Firebase App Check for additional security

## Useful Commands

```bash
# View Cloud Functions logs
firebase functions:log --project pet-underwriter-ai

# Test functions locally
firebase emulators:start --only functions

# Deploy specific function
firebase deploy --only functions:onQuoteCreated --project pet-underwriter-ai

# View Firestore data
open https://console.firebase.google.com/project/pet-underwriter-ai/firestore

# Monitor authentication
open https://console.firebase.google.com/project/pet-underwriter-ai/authentication

# Check billing and usage
open https://console.firebase.google.com/project/pet-underwriter-ai/usage
```

## Troubleshooting

**Issue: Firebase initialization fails**
- Ensure you've run `flutterfire configure`
- Check that API keys in `firebase_options.dart` are correct
- Verify internet connection

**Issue: Authentication not working**
- Check that providers are enabled in Firebase Console
- Verify SHA certificates for Android (for Google Sign-In)
- Check iOS configuration for Apple Sign-In

**Issue: Firestore permission denied**
- Deploy security rules: `firebase deploy --only firestore:rules`
- Check that user is authenticated
- Verify userId matches in security rules

**Issue: Cloud Functions not triggering**
- Check function deployment status
- View logs: `firebase functions:log`
- Verify Firestore triggers are correct
- Ensure billing is enabled (required for Cloud Functions)

**Issue: Stripe payments failing**
- Verify Stripe keys are correct
- Check webhook endpoint is accessible
- Use Stripe test cards during development
- Check Stripe Dashboard logs

## Cost Considerations

- **Firebase Free Tier (Spark Plan)**:
  - 50K reads, 20K writes, 20K deletes per day
  - 1GB storage
  - 10GB network egress per month
  - No Cloud Functions (need Blaze plan)

- **Firebase Blaze Plan** (Pay as you go):
  - Required for Cloud Functions
  - Free tier included, then pay for usage
  - Estimated cost for moderate use: $10-50/month

- **Stripe**:
  - 2.9% + $0.30 per successful transaction
  - No monthly fees
  - Test mode is free

## Resources

- [Firebase Console](https://console.firebase.google.com/project/pet-underwriter-ai)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Stripe Dashboard](https://dashboard.stripe.com)
- [FlutterFire Documentation](https://firebase.flutter.dev/)
- [Cloud Functions Documentation](https://firebase.google.com/docs/functions)
