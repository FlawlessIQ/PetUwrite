# 🔧 Quick Fixes for Test Issues

## Issues Fixed

### ✅ 1. UI Overflow in Plan Selection Screen
**Problem:** RenderFlex overflow by 293 pixels  
**Fix:** Wrapped Column in SingleChildScrollView  
**File:** `lib/screens/plan_selection_screen.dart`  
**Status:** ✅ FIXED

---

### 🔧 2. Firestore Permission Error - Underwriting Rules
**Problem:** `[cloud_firestore/permission-denied] Missing or insufficient permissions`  
**Root Cause:** The `admin_settings/underwriting_rules` document doesn't exist in Firestore yet.

**Quick Fix:** Create the document manually in Firebase Console:

#### Option A: Firebase Console (Recommended - 2 minutes)
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Navigate to **Firestore Database**
4. Click **Start collection**
   - Collection ID: `admin_settings`
   - Document ID: `underwriting_rules`
5. Add these fields:

```
maxRiskScore: 90 (number)
minAgeMonths: 2 (number)
maxAgeYears: 14 (number)
excludedBreeds: ["Wolf Hybrid", "Wolf Dog", "Pit Bull Terrier"] (array of strings)
criticalConditions: ["cancer", "terminal illness", "end stage kidney disease"] (array of strings)
enabled: true (boolean)
lastUpdated: (timestamp - click "Set to current time")
```

6. Click **Save**
7. Refresh your app - error should be gone!

#### Option B: Using Firestore UI
1. In Firebase Console → Firestore
2. Click "+" next to root to add collection
3. Enter collection ID: `admin_settings`
4. Enter document ID: `underwriting_rules`
5. Add fields as shown above

**Why this happens:**  
The app expects this document to exist but it's not created automatically. The security rules allow reading it, but the document must exist first.

---

### ⚠️ 3. Font Loading Warnings (Optional Fix)
**Problem:** Failed to load Inter fonts  
**Impact:** Low - Falls back to system fonts  
**Fix:** Either:
- Ignore (app still works)
- OR add Inter fonts to `assets/fonts/Inter/` folder
- OR remove font declarations from `pubspec.yaml`

---

### 🔍 4. Null Type Error Investigation Needed
**Error:** `null: type 'Null' is not a subtype of type 'String'`  
**Status:** Needs more debugging to identify exact location

**Likely causes:**
1. Missing pet/owner data field
2. Firestore document field returning null
3. Route argument not passed correctly

**To debug:** Check browser console for full stack trace showing which line caused this error.

---

## Testing Checklist

After fixes:
- [ ] Create `admin_settings/underwriting_rules` in Firestore
- [ ] Restart your app
- [ ] Test full flow: Login → Quote → Plans
- [ ] Verify no permission errors
- [ ] Verify no UI overflow
- [ ] Check if null error persists (report back if it does)

---

## If Issues Persist

### Permission Error Still Happening?
1. Verify firestore.rules are deployed:
   ```bash
   firebase deploy --only firestore:rules
   ```

2. Check Firebase Console → Firestore → Rules tab - should show:
   ```javascript
   match /admin_settings/underwriting_rules {
     allow read: if isAuthenticated();
     allow write: if isAdmin();
   }
   ```

3. Verify the document exists in Firestore Database view

### UI Still Overflowing?
1. Hard refresh: Cmd+Shift+R (Mac) or Ctrl+Shift+R (Windows)
2. Clear browser cache
3. Run: `flutter clean && flutter pub get && flutter run -d chrome`

### Null Error Persists?
Share the full stack trace from browser console - it will show the exact file/line causing the issue.

---

## Files Modified
- ✅ `lib/screens/plan_selection_screen.dart` - Added SingleChildScrollView to prevent overflow
- 📝 `lib/scripts/init_firestore.dart` - Helper script (optional, can use Firebase Console instead)

---

## Summary

**Critical Fix:** Create `admin_settings/underwriting_rules` document in Firebase Console manually (takes 2 minutes).

**UI Fix:** Already applied - SingleChildScrollView added to plan cards.

**Next:** Test app again and report if null error persists!
