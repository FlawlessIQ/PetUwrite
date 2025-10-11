# Underwriting Rules Seeder

This directory contains CLI tools to seed the `admin_settings/underwriting_rules` document to Firebase Firestore.

## 📋 Purpose

Creates the required Firestore document that the app expects:
- **Collection:** `admin_settings`
- **Document ID:** `underwriting_rules`

This document contains:
- Risk score thresholds (maxRiskScore: 85)
- Age restrictions (8 months - 12 years)
- Excluded breeds (6 breeds)
- Critical conditions (6 conditions)
- Rejection rules (5 automated rules)
- AI prompt overrides

## 🚀 Quick Start (Node.js - Recommended)

### Prerequisites

1. **Install firebase-admin:**
   ```bash
   npm install firebase-admin
   ```

2. **Get Firebase Service Account Key:**
   - Go to [Firebase Console](https://console.firebase.google.com)
   - Select your project
   - Settings (⚙️) → Project Settings → Service Accounts
   - Click "Generate New Private Key"
   - Save as `firebase-service-account.json` in project root

### Run the Seeder

```bash
node seed_underwriting_rules.js
```

### Expected Output

```
═══════════════════════════════════════════════════════════
  PetUwrite - Underwriting Rules Seeder
═══════════════════════════════════════════════════════════

🔧 Initializing Firebase Admin SDK...
✅ Firebase initialized with service account file

📋 Preparing underwriting rules document...
💾 Writing to Firestore: admin_settings/underwriting_rules...

✅ Underwriting rules successfully seeded to Firestore.

📊 Summary:
   Collection: admin_settings
   Document: underwriting_rules
   Max Risk Score: 85
   Age Range: 8 months - 12 years
   Excluded Breeds: 6
   Critical Conditions: 6
   Rejection Rules: 5

🎯 Next Steps:
   1. Verify in Firebase Console: Firestore → admin_settings → underwriting_rules
   2. Run your Flutter app - permission errors should be resolved
   3. Test underwriting flow with excluded breeds and critical conditions
   4. Check Admin Dashboard for risk-based quote filtering
```

## 🔐 Authentication Options

### Option 1: Service Account File (Recommended)

Place `firebase-service-account.json` in project root:
```
PetUwrite/
├── seed_underwriting_rules.js
├── firebase-service-account.json  ← Place here
└── ...
```

### Option 2: Environment Variable

```bash
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/firebase-service-account.json"
node seed_underwriting_rules.js
```

## 🐛 Troubleshooting

### Error: "No Firebase credentials found"

**Solution:** Download service account key from Firebase Console and save as `firebase-service-account.json`.

### Error: "Permission denied"

**Solutions:**
1. Verify service account has "Cloud Datastore User" or "Firebase Admin" role
2. Check firestore.rules allow writes to `admin_settings` collection:
   ```javascript
   match /admin_settings/{document} {
     allow read: if request.auth != null;
     allow write: if request.auth != null && 
                     get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
   }
   ```

### Error: "firebase-admin not found"

**Solution:** 
```bash
npm install firebase-admin
```

## 📊 Document Schema

The seeder creates this exact structure in Firestore:

```json
{
  "enabled": true,
  "maxRiskScore": 85,
  "minAgeMonths": 8,
  "maxAgeYears": 12,
  "excludedBreeds": [
    "Wolf Hybrid",
    "Pit Bull Terrier",
    "American Bulldog",
    "Presa Canario",
    "Cane Corso",
    "Dogo Argentino"
  ],
  "criticalConditions": [
    "cancer",
    "heart murmur",
    "epilepsy",
    "terminal illness",
    "seizure disorder",
    "chronic kidney disease"
  ],
  "rejectionRules": [
    {
      "ruleId": "AGE_TOO_YOUNG",
      "description": "Pet is too young for coverage",
      "condition": "pet.ageMonths < minAgeMonths",
      "autoDecline": true
    },
    {
      "ruleId": "AGE_TOO_OLD",
      "description": "Pet exceeds maximum age for new policies",
      "condition": "pet.ageMonths > maxAgeYears * 12",
      "autoDecline": true
    },
    {
      "ruleId": "BREED_EXCLUDED",
      "description": "Breed is excluded from underwriting",
      "condition": "pet.breed in excludedBreeds",
      "autoDecline": true
    },
    {
      "ruleId": "HIGH_RISK_SCORE",
      "description": "AI Risk Score exceeds allowable maximum",
      "condition": "riskScore.total > maxRiskScore",
      "autoDecline": true
    },
    {
      "ruleId": "CRITICAL_CONDITION",
      "description": "Pre-existing condition is uninsurable",
      "condition": "pet.conditions containsAny criticalConditions",
      "autoDecline": true
    }
  ],
  "aiPromptOverrides": {
    "riskDeclineTriggers": [
      "riskScore > 85",
      "condition in [cancer, epilepsy, terminal illness]",
      "breed in [Wolf Hybrid, Pit Bull Terrier]",
      "pet.ageMonths < 8 or pet.ageYears > 12"
    ],
    "recommendationLogic": "If any of the above are true, recommend: eligibility = 'deny'"
  },
  "lastUpdated": "2025-10-10T12:00:00.000Z",
  "updatedBy": "system_seed"
}
```

## 🎯 How It's Used in the App

### 1. Risk Scoring Engine
**File:** `lib/services/risk_scoring_engine.dart`

Loads rules at startup:
```dart
final rules = await _underwritingRulesEngine.getRules();
if (riskScore > rules.maxRiskScore) {
  return RiskDecision.decline;
}
```

### 2. Conversational Quote Flow
**File:** `lib/screens/conversational_quote_flow.dart`

Validates pet age and breed:
```dart
if (pet.ageMonths < rules.minAgeMonths) {
  showError('Pet must be at least ${rules.minAgeMonths} months old');
}

if (rules.excludedBreeds.contains(pet.breed)) {
  showError('Unfortunately, we cannot cover ${pet.breed} at this time');
}
```

### 3. Admin Dashboard
**File:** `lib/screens/admin_dashboard.dart`

Filters high-risk quotes:
```dart
.where('riskScore', isGreaterThan: rules.maxRiskScore)
```

## 🔄 Alternative: Manual Creation in Firebase Console

If you prefer not to run the script, you can manually create the document:

1. Go to Firebase Console → Firestore Database
2. Click "Start collection"
3. Collection ID: `admin_settings`
4. Document ID: `underwriting_rules`
5. Add fields from the schema above

**Note:** This takes ~5-10 minutes vs ~10 seconds with the script.

## 📝 Dart Version (Alternative)

A Dart version is available in `bin/seed_underwriting_rules.dart`, but requires:
- Firebase configuration in code
- Running from Flutter environment
- More setup complexity

**Recommendation:** Use the Node.js version for simplicity.

## 🧪 Verification

After running the seeder, verify in Firebase Console:

1. Go to Firestore Database
2. Navigate to `admin_settings` collection
3. Click on `underwriting_rules` document
4. Verify all fields are present
5. Check `lastUpdated` timestamp is recent

## 🔗 Related Files

- **Firestore Rules:** `firestore.rules` - Security rules for admin_settings
- **Engine:** `lib/services/underwriting_rules_engine.dart` - Loads and applies rules
- **Risk Scoring:** `lib/services/risk_scoring_engine.dart` - Uses rules for decisions
- **Documentation:** `UNDERWRITING_PROCESS_ANALYSIS.md` - Complete underwriting flow

## 📞 Support

If you encounter issues:
1. Check Firebase Console for error logs
2. Verify service account permissions
3. Review firestore.rules for write access
4. Check `QUICK_FIXES_TEST_ISSUES.md` for common problems

---

**Last Updated:** October 10, 2025  
**Version:** 1.0.0
