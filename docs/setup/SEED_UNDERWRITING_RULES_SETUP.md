# ✅ Underwriting Rules Seeder - Complete Setup

## 📦 What Was Created

Three tools to seed the required `admin_settings/underwriting_rules` Firestore document:

### 1. **Node.js Seeder (RECOMMENDED)** ⭐
   - **File:** `functions/seed_underwriting_rules.js`
   - **Why use it:** Uses Firebase Admin SDK, already have dependencies installed
   - **Run:** `cd functions && node seed_underwriting_rules.js`

### 2. **Dart CLI Tool** 
   - **File:** `bin/seed_underwriting_rules.dart`
   - **Why use it:** If you prefer pure Dart (requires more setup)
   - **Run:** `dart run bin/seed_underwriting_rules.dart`

### 3. **Documentation**
   - **Quick Start:** `SEED_UNDERWRITING_RULES_QUICK_START.md` (2-minute read)
   - **Full Guide:** `SEED_UNDERWRITING_RULES_README.md` (complete reference)

---

## 🚀 Quick Start (30 seconds)

### Step 1: Get Firebase Credentials

**Option A: Download New Key (Recommended)**
1. Go to [Firebase Console](https://console.firebase.google.com) → Your Project
2. ⚙️ Settings → Project Settings → Service Accounts
3. Click **"Generate New Private Key"**
4. Save as `firebase-service-account.json` in **Clovara/functions/** directory

**Option B: Use Existing Credentials**
If you have GOOGLE_APPLICATION_CREDENTIALS set, skip to Step 2.

### Step 2: Run the Seeder

```bash
cd functions
node seed_underwriting_rules.js
```

### Step 3: Verify Success

You should see:
```
✅ Underwriting rules successfully seeded to Firestore.

📊 Summary:
   Collection: admin_settings
   Document: underwriting_rules
   Max Risk Score: 85
   Age Range: 8 months - 12 years
   Excluded Breeds: 6
   Critical Conditions: 6
   Rejection Rules: 5
```

### Step 4: Verify in Firebase Console

1. Firebase Console → Firestore Database
2. Collection: `admin_settings` → Document: `underwriting_rules`
3. Should see all fields populated

---

## 📊 What This Document Contains

```json
{
  "enabled": true,
  "maxRiskScore": 85,           // Quotes > 85 auto-declined
  "minAgeMonths": 8,             // Pets under 8 months rejected
  "maxAgeYears": 12,             // Pets over 12 years rejected
  
  "excludedBreeds": [            // 6 breeds blocked
    "Wolf Hybrid",
    "Pit Bull Terrier",
    "American Bulldog",
    "Presa Canario",
    "Cane Corso",
    "Dogo Argentino"
  ],
  
  "criticalConditions": [        // 6 high-risk conditions
    "cancer",
    "heart murmur",
    "epilepsy",
    "terminal illness",
    "seizure disorder",
    "chronic kidney disease"
  ],
  
  "rejectionRules": [            // 5 automated decline rules
    {
      "ruleId": "AGE_TOO_YOUNG",
      "description": "Pet is too young for coverage",
      "condition": "pet.ageMonths < minAgeMonths",
      "autoDecline": true
    },
    // ... 4 more rules
  ],
  
  "aiPromptOverrides": {         // AI risk triggers
    "riskDeclineTriggers": [
      "riskScore > 85",
      "condition in [cancer, epilepsy, terminal illness]",
      "breed in [Wolf Hybrid, Pit Bull Terrier]",
      "pet.ageMonths < 8 or pet.ageYears > 12"
    ],
    "recommendationLogic": "If any of the above are true, recommend: eligibility = 'deny'"
  },
  
  "lastUpdated": <timestamp>,
  "updatedBy": "system_seed"
}
```

---

## 🎯 Why This Document Is Required

### Before Seeding (Current State)
❌ App shows error: "Error loading underwriting rules: [cloud_firestore/not-found]"  
❌ Permission denied when loading admin_settings/underwriting_rules  
❌ Risk scoring falls back to defaults  
❌ Admin dashboard can't filter high-risk quotes  

### After Seeding (Fixed State)
✅ Underwriting rules load successfully  
✅ Risk scoring uses configured thresholds  
✅ Age/breed validation works correctly  
✅ Admin dashboard filters by maxRiskScore  
✅ AI prompts use custom decline triggers  

---

## 🔧 How Your App Uses This Document

### 1. **Risk Scoring Engine** (`lib/services/risk_scoring_engine.dart`)
```dart
final rules = await _underwritingRulesEngine.getRules();

if (riskScore > rules.maxRiskScore) {
  // Quote automatically declined
  return RiskDecision.decline;
}
```

### 2. **Quote Flow** (`lib/screens/conversational_quote_flow.dart`)
```dart
// Age validation
if (pet.ageMonths < rules.minAgeMonths) {
  showError('Pet must be at least ${rules.minAgeMonths} months old');
}

// Breed validation
if (rules.excludedBreeds.contains(pet.breed)) {
  showError('We cannot cover ${pet.breed} at this time');
}
```

### 3. **Admin Dashboard** (`lib/screens/admin_dashboard.dart`)
```dart
// Filter high-risk quotes
final rules = await _rulesEngine.getRules();
FirebaseFirestore.instance
  .collection('quotes')
  .where('riskScore', isGreaterThan: rules.maxRiskScore)
  .get();
```

### 4. **AI Risk Analysis** (`lib/services/conversational_ai_service.dart`)
```dart
// AI uses decline triggers from rules
final prompt = '''
Risk Decline Triggers:
${rules.aiPromptOverrides.riskDeclineTriggers.join('\n')}

Recommendation Logic:
${rules.aiPromptOverrides.recommendationLogic}
''';
```

---

## 🧪 Testing After Seeding

### Test 1: Age Restrictions
1. Start quote flow
2. Enter pet age: **6 months** (under minimum)
3. ✅ Should show: "Pet must be at least 8 months old"

### Test 2: Breed Restrictions
1. Start quote flow
2. Enter breed: **"Pit Bull Terrier"**
3. ✅ Should show: "We cannot cover Pit Bull Terrier at this time"

### Test 3: Critical Conditions
1. Complete quote flow
2. Add condition: **"cancer"**
3. ✅ Risk score should be very high (80+)
4. ✅ Admin dashboard should flag for review

### Test 4: High Risk Score
1. Create quote with:
   - Senior pet (10+ years)
   - Pre-existing conditions
   - High-risk breed (not excluded)
2. ✅ If score > 85, quote goes to admin review
3. ✅ Admin can see "High Risk" badge

### Test 5: Admin Dashboard
1. Open admin dashboard
2. ✅ Should load without permission errors
3. ✅ Filter dropdown should work
4. ✅ Risk score sorting should work

---

## 🐛 Troubleshooting

### Error: "No Firebase credentials found"

**Solution:**
```bash
# Download service account key from Firebase Console
# Save as functions/firebase-service-account.json
cd functions
node seed_underwriting_rules.js
```

### Error: "Permission denied"

**Solution:** Your service account needs write permissions.

1. Firebase Console → IAM & Admin
2. Find your service account (ends with @*.iam.gserviceaccount.com)
3. Add role: **"Cloud Datastore User"** or **"Firebase Admin"**
4. Wait 60 seconds for permissions to propagate
5. Re-run: `node seed_underwriting_rules.js`

### Error: "firebase-admin not found"

**Solution:**
```bash
cd functions
npm install firebase-admin
node seed_underwriting_rules.js
```

### Seeder Runs But Document Not Created

**Check Firestore Rules:**
```javascript
// firestore.rules
match /admin_settings/{document} {
  allow read: if request.auth != null;
  allow write: if true;  // Temporarily allow all writes for seeding
}
```

After seeding, tighten rules:
```javascript
match /admin_settings/{document} {
  allow read: if request.auth != null;
  allow write: if request.auth != null && 
                  get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
}
```

### App Still Shows Error After Seeding

1. **Verify document exists:**
   - Firebase Console → Firestore → admin_settings → underwriting_rules
   - Should have 10+ fields

2. **Restart Flutter app:**
   - Stop the app completely
   - Hot restart doesn't reload Firestore listeners
   - `flutter run` again

3. **Check Flutter console:**
   - Look for "Successfully loaded underwriting rules"
   - Should not see "[cloud_firestore/not-found]"

---

## 📁 File Structure After Setup

```
Clovara/
├── functions/
│   ├── seed_underwriting_rules.js          ← Run this script
│   ├── firebase-service-account.json       ← Place credentials here
│   ├── package.json                        ← Already has firebase-admin
│   └── ...
│
├── bin/
│   └── seed_underwriting_rules.dart        ← Dart alternative
│
├── SEED_UNDERWRITING_RULES_QUICK_START.md  ← 2-minute guide
├── SEED_UNDERWRITING_RULES_README.md       ← Full documentation
└── SEED_UNDERWRITING_RULES_SETUP.md        ← This file
```

---

## 🎯 Next Steps

### Immediate (Now)
1. ✅ Run the seeder: `cd functions && node seed_underwriting_rules.js`
2. ✅ Verify in Firebase Console
3. ✅ Restart your Flutter app

### Testing (Next 10 minutes)
1. ✅ Test age restrictions (try 6 months old pet)
2. ✅ Test breed restrictions (try "Pit Bull Terrier")
3. ✅ Test critical conditions (add "cancer")
4. ✅ Check admin dashboard loads without errors

### Production (Before Launch)
1. 📝 Review and adjust `maxRiskScore` (currently 85)
2. 📝 Review `excludedBreeds` list (currently 6 breeds)
3. 📝 Review `criticalConditions` (currently 6 conditions)
4. 📝 Tighten Firestore rules (require admin role for writes)
5. 📝 Set up monitoring for rule changes

---

## 🔗 Related Documentation

- **Underwriting Process:** `UNDERWRITING_PROCESS_ANALYSIS.md` - Complete AI decision flow
- **Admin Dashboard:** `ADMIN_DASHBOARD_GUIDE.md` - How admins review high-risk quotes
- **Risk Scoring:** `lib/services/risk_scoring_engine.dart` - How risk scores are calculated
- **Test Fixes:** `QUICK_FIXES_TEST_ISSUES.md` - Other runtime issue fixes

---

## 💡 Tips

- **Updating Rules:** Edit values in Firebase Console directly (no re-seeding needed)
- **Backup:** Export the document before making changes
- **Version Control:** Don't commit `firebase-service-account.json` to git (already in .gitignore)
- **Multiple Environments:** Run seeder for dev/staging/prod separately

---

**Status:** ✅ Ready to run  
**Time to Complete:** ~30 seconds  
**Last Updated:** October 10, 2025  
**Version:** 1.0.0
