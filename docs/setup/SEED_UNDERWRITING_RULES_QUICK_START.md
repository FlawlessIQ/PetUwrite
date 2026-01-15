# 🚀 Quick Start: Seed Underwriting Rules

## One Command Setup

```bash
cd functions
node seed_underwriting_rules.js
```

That's it! The script will automatically use your existing Firebase configuration.

## ✅ What You'll See

```
═══════════════════════════════════════════════════════════
  Clovara - Underwriting Rules Seeder
═══════════════════════════════════════════════════════════

🔧 Initializing Firebase Admin SDK...
✅ Firebase initialized with service account file

📋 Preparing underwriting rules document...
💾 Writing to Firestore: admin_settings/underwriting_rules...

✅ Underwriting rules successfully seeded to Firestore.
```

## 🔐 Authentication

The script needs Firebase credentials. Two options:

### Option 1: Use Existing Service Account (Easiest)

If you've already deployed Cloud Functions, you likely have credentials set up:

```bash
cd functions
node seed_underwriting_rules.js
```

### Option 2: Download New Service Account Key

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. ⚙️ Settings → Project Settings → Service Accounts
4. Click "Generate New Private Key"
5. Save as `firebase-service-account.json` in the `functions/` directory
6. Run: `cd functions && node seed_underwriting_rules.js`

## 🧪 Verify It Worked

1. Go to Firebase Console → Firestore Database
2. Look for collection: `admin_settings`
3. Click document: `underwriting_rules`
4. You should see:
   - `maxRiskScore: 85`
   - `minAgeMonths: 8`
   - `maxAgeYears: 12`
   - `excludedBreeds: [6 items]`
   - `criticalConditions: [6 items]`
   - `rejectionRules: [5 items]`

## 📊 What This Document Does

This document is required by your app for:

1. **Risk Scoring** - Determines when quotes are declined (score > 85)
2. **Age Validation** - Rejects pets under 8 months or over 12 years
3. **Breed Restrictions** - Blocks 6 high-risk breeds
4. **Condition Checks** - Flags 6 critical health conditions
5. **Admin Dashboard** - Filters high-risk quotes automatically

## 🐛 Troubleshooting

### "No Firebase credentials found"
**Solution:** Download service account key (see Option 2 above)

### "Permission denied"
**Solution:** Your service account needs Firestore write permissions:
1. Firebase Console → IAM & Admin
2. Find your service account
3. Add role: "Cloud Datastore User" or "Firebase Admin"

### "firebase-admin not found"
**Solution:** 
```bash
cd functions
npm install firebase-admin
```

## 🎯 Next Steps After Seeding

1. ✅ **Restart your Flutter app** - The error should disappear
2. ✅ **Test quote flow** - Try creating a quote for a pet
3. ✅ **Test restrictions** - Try these edge cases:
   - Pet under 8 months old → Should show age error
   - Pit Bull Terrier breed → Should show breed restriction
   - Pet with "cancer" condition → Should flag as high risk
4. ✅ **Check Admin Dashboard** - Should now load without errors

## 📝 Document Schema Preview

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
  "rejectionRules": [...],
  "aiPromptOverrides": {...},
  "lastUpdated": <timestamp>,
  "updatedBy": "system_seed"
}
```

---

**Need more details?** See `SEED_UNDERWRITING_RULES_README.md` for full documentation.
