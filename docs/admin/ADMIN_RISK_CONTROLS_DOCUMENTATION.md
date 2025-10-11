# Admin Risk Controls Page - Complete Documentation

## 🎯 Overview

A comprehensive admin dashboard for managing all underwriting parameters, pricing rules, and AI configurations across the PetUwrite platform.

**Access Level:** Admin users only (`userRole == 2`)

**Location:** `/lib/admin/admin_risk_controls_page.dart`

---

## ✅ Features Implemented

### 1. **Access Control**
- ✅ Checks Firebase Auth user role
- ✅ Only permits `userRole == 2` (admin level)
- ✅ Shows "Access Denied" screen for unauthorized users
- ✅ Automatic redirect protection

### 2. **Risk Appetite Control**
- **Max Acceptable Risk Score** slider (0-100)
- Color-coded display:
  - 0-29: Green (Low Risk)
  - 30-59: Teal (Medium Risk)
  - 60-79: Orange (High Risk)
  - 80-100: Red (Very High Risk)
- Saved to: `admin_settings/global_config → risk_max_score`
- **Purpose:** Quotes above this threshold get flagged for manual review

### 3. **Breed Exclusion List**
- Multi-select chip interface
- Pre-populated with 10 high-risk breeds:
  - Pit Bull, Rottweiler, Doberman, German Shepherd
  - Chow Chow, Akita, Wolf Hybrid, Bulldog
  - Mastiff, Great Dane
- Selected breeds highlighted in coral red
- Shows exclusion count badge
- Saved to: `admin_settings/global_config → excluded_breeds` (array)

### 4. **Medical Condition Flags**
- Toggle switches for 8 common pre-existing conditions:
  - Allergies
  - Hip Dysplasia
  - Heart Murmur
  - Diabetes
  - Cancer
  - Kidney Disease
  - Liver Disease
  - Epilepsy
- Teal active/inactive switches
- Saved to: `admin_settings/global_config → excluded_conditions` (map)
- **Purpose:** Conditions flagged as true trigger exclusions or premium increases

### 5. **Pricing Multipliers**
- **Base Premium ($):** Starting monthly premium (default: $35.00)
- **Risk Multiplier:** Multiplier per risk score (default: 1.5)
- **Breed Risk Add-on:** Additional % for high-risk breeds (default: 0.15 = 15%)
- **Regional Modifier:** Geographic cost adjustment (default: 1.0 = baseline)
- Number input fields with validation
- Helper text explaining each parameter
- Saved to: `admin_settings/global_config → pricing_config` (nested map)

### 6. **AI Prompt Tweaks**
- Multi-line TextField (5 rows)
- Customizes GPT-4o system prompt
- Default: "Analyze pet insurance risk focusing on age, breed health history, and regional factors."
- Info box explaining impact on all new quotes
- Saved to: `admin_settings/global_config → ai_prompt_override` (string)

### 7. **Quote Display Settings (UI Flags)**
- **Show Explainability Factors:** Display detailed risk breakdown to customers
- **Allow Manual Override by Underwriter:** Permit admin users to adjust quotes manually
- Toggle switches with descriptions
- Saved to: `admin_settings/global_config → ui_flags` (map)

### 8. **State Management**
- Real-time change detection
- "Unsaved" warning badge in AppBar
- Loads existing config from Firestore on mount
- Batched save operation
- Shows "Last Updated" timestamp

### 9. **Save Functionality**
- Floating Action Button (FAB) at bottom right
- Saves all sections to single Firestore document
- Success/error SnackBar feedback
- Tracks `last_updated` timestamp
- Records `updated_by` email

---

## 🎨 Visual Design

### Color Scheme
- **Background:** Navy (#0A2647)
- **Cards:** Gradient soft teal with shadows
- **Primary Actions:** Teal (#00C2CB)
- **Warnings:** Orange (#FFB84D)
- **Errors/Exclusions:** Coral (#FF6B6B)
- **Success:** Mint (#4ECDC4)

### Layout
- **AppBar:** Navy with white text, unsaved badge
- **Header:** Last updated timestamp (gradient teal)
- **Content:** ScrollView with ExpansionTiles
- **FAB:** Teal "Save Settings" button

### Components
- **ExpansionTile cards:** Rounded corners (16px), teal icon badges
- **Sliders:** Teal active color, score badge on right
- **Chips:** Coral for selected (excluded breeds), white for unselected
- **Switches:** Teal active color, white background cards
- **TextFields:** White semi-transparent, teal focus border
- **Info boxes:** Teal/blue backgrounds with border

---

## 📊 Firestore Structure

### Document Path
```
admin_settings/global_config
```

### Document Schema
```javascript
{
  // Risk Appetite
  "risk_max_score": 80.0,  // double, 0-100
  
  // Breed Exclusions
  "excluded_breeds": [
    "Pit Bull",
    "Rottweiler",
    "Doberman"
  ],  // array of strings
  
  // Medical Conditions
  "excluded_conditions": {
    "Allergies": false,
    "Hip Dysplasia": true,
    "Heart Murmur": false,
    "Diabetes": true,
    "Cancer": true,
    "Kidney Disease": false,
    "Liver Disease": false,
    "Epilepsy": false
  },  // map of string -> bool
  
  // Pricing Configuration
  "pricing_config": {
    "base_premium": 35.0,      // double, starting $ amount
    "risk_multiplier": 1.5,    // double, risk adjustment factor
    "breed_addon": 0.15,       // double, breed risk percentage
    "regional_modifier": 1.0   // double, geographic multiplier
  },  // nested map
  
  // AI Prompt Override
  "ai_prompt_override": "Analyze pet insurance risk focusing on age, breed health history, and regional factors.",  // string
  
  // UI Feature Flags
  "ui_flags": {
    "show_explainability": true,    // bool
    "allow_manual_override": false  // bool
  },  // map of string -> bool
  
  // Metadata
  "last_updated": Timestamp(2025-10-08 14:30:00),  // server timestamp
  "updated_by": "admin@petuwrite.com"              // string, user email
}
```

---

## 🔧 Usage Instructions

### For Developers

**1. Add to Navigation:**
```dart
// In admin dashboard or menu
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AdminRiskControlsPage(),
      ),
    );
  },
  child: const Text('Risk Controls'),
)
```

**2. Set User Role in Firestore:**
```javascript
// In users collection
users/{userId} {
  "email": "admin@example.com",
  "userRole": 2,  // 0 = customer, 1 = underwriter, 2 = admin
  "name": "Admin User"
}
```

**3. Read Settings in Other Code:**
```dart
// Example: Reading pricing config
final doc = await FirebaseFirestore.instance
    .collection('admin_settings')
    .doc('global_config')
    .get();

final pricingConfig = doc.data()?['pricing_config'] as Map<String, dynamic>;
final basePremium = pricingConfig['base_premium'] as double;
final riskMultiplier = pricingConfig['risk_multiplier'] as double;

// Apply to quote
final adjustedPremium = basePremium * (1 + (riskScore / 100) * riskMultiplier);
```

**4. Check Breed Exclusions:**
```dart
final excludedBreeds = List<String>.from(
  doc.data()?['excluded_breeds'] ?? []
);

if (excludedBreeds.contains(pet.breed)) {
  // Show exclusion message
  return 'Coverage not available for this breed';
}
```

### For Admins

**1. Access the Page:**
- Log in with admin account (`userRole == 2`)
- Navigate to Risk Controls from admin menu
- Page loads current settings from Firestore

**2. Adjust Settings:**
- Expand any section by tapping header
- Modify values (sliders, chips, switches, text fields)
- "Unsaved" badge appears in top right

**3. Save Changes:**
- Tap blue "Save Settings" FAB at bottom right
- Success message appears: "Settings updated successfully!"
- Changes apply to all new quotes immediately

**4. Monitor Updates:**
- "Last Updated" shows at top of page
- Timestamp updates after each save
- Tracks which admin made changes

---

## 🧪 Testing Scenarios

### Test Case 1: Access Control

**Steps:**
1. Log in with regular user account (`userRole == 0`)
2. Navigate to AdminRiskControlsPage
3. Verify "Access Denied" screen appears
4. Check block icon and error message displayed

**Expected Result:**
- ✅ Unauthorized users cannot access page
- ✅ Friendly error message shown
- ✅ Can navigate back

### Test Case 2: Risk Appetite Adjustment

**Steps:**
1. Log in as admin (`userRole == 2`)
2. Open Risk Appetite section
3. Move slider to 65
4. Observe color change to orange
5. Save settings
6. Refresh page
7. Verify slider shows 65

**Expected Result:**
- ✅ Slider updates in real-time
- ✅ Color changes at thresholds (30, 60, 80)
- ✅ Value persists after save/reload

### Test Case 3: Breed Exclusion

**Steps:**
1. Open Breed Exclusion List section
2. Select "Pit Bull", "Rottweiler", "Bulldog"
3. Verify chips turn coral red
4. Check exclusion count shows "3 breed(s) excluded"
5. Save settings
6. Reload page
7. Verify 3 breeds still selected

**Expected Result:**
- ✅ Visual feedback on selection
- ✅ Count badge updates
- ✅ Selections persist

### Test Case 4: Pricing Multipliers

**Steps:**
1. Open Pricing Multipliers section
2. Change Base Premium to "40.00"
3. Change Risk Multiplier to "2.0"
4. Change Breed Addon to "0.20"
5. Save settings
6. Check Firestore document
7. Verify nested map structure correct

**Expected Result:**
- ✅ All fields accept decimal input
- ✅ Helper text visible
- ✅ Saved as numbers, not strings
- ✅ Nested in `pricing_config` map

### Test Case 5: AI Prompt Customization

**Steps:**
1. Open AI Prompt Tweaks section
2. Edit text to: "Focus heavily on breed-specific risks and age-related conditions. Be conservative in risk assessment."
3. Save settings
4. Trigger new quote with AI analysis
5. Check GPT-4o receives updated prompt

**Expected Result:**
- ✅ Multi-line text editable
- ✅ Info box explains impact
- ✅ Prompt used in AI calls
- ✅ Affects all new quotes

### Test Case 6: Unsaved Changes Warning

**Steps:**
1. Open any section
2. Make a change (don't save)
3. Check AppBar for warning badge
4. Navigate away (back button)
5. Return to page
6. Verify changes not persisted

**Expected Result:**
- ✅ Orange "Unsaved" badge appears immediately
- ✅ Badge shows warning icon
- ✅ Changes lost if not saved
- ✅ Fresh data loaded on return

### Test Case 7: Save Success Flow

**Steps:**
1. Make changes to 3+ different sections
2. Tap "Save Settings" FAB
3. Observe SnackBar message
4. Check "Last Updated" timestamp
5. Verify "Unsaved" badge disappears
6. Check Firestore for `updated_by` field

**Expected Result:**
- ✅ Green success SnackBar appears
- ✅ Timestamp updates to current time
- ✅ Badge removed after save
- ✅ Admin email recorded in Firestore

---

## 🚀 Integration Examples

### Example 1: Use in QuoteEngine

```dart
class QuoteEngine {
  Future<List<Plan>> generateQuote({
    required Pet pet,
    required RiskScore riskScore,
    required Owner owner,
  }) async {
    // Fetch admin settings
    final settings = await _fetchAdminSettings();
    
    // Check breed exclusions
    final excludedBreeds = settings['excluded_breeds'] as List<dynamic>;
    if (excludedBreeds.contains(pet.breed)) {
      throw Exception('Coverage not available for ${pet.breed}');
    }
    
    // Apply pricing config
    final pricingConfig = settings['pricing_config'] as Map<String, dynamic>;
    final basePremium = pricingConfig['base_premium'] as double;
    final riskMultiplier = pricingConfig['risk_multiplier'] as double;
    final breedAddon = pricingConfig['breed_addon'] as double;
    final regionalModifier = pricingConfig['regional_modifier'] as double;
    
    // Calculate with admin-defined parameters
    double price = basePremium;
    price *= (1 + (riskScore.overallScore / 100) * riskMultiplier);
    if (_isHighRiskBreed(pet.breed)) {
      price *= (1 + breedAddon);
    }
    price *= regionalModifier;
    
    return _generatePlansWithPrice(price);
  }
  
  Future<Map<String, dynamic>> _fetchAdminSettings() async {
    final doc = await FirebaseFirestore.instance
        .collection('admin_settings')
        .doc('global_config')
        .get();
    return doc.data() ?? {};
  }
}
```

### Example 2: Use in RiskScoringEngine

```dart
class RiskScoringEngine {
  Future<RiskScore> calculateRiskScore({
    required Pet pet,
    required Owner owner,
  }) async {
    // Fetch admin settings
    final settings = await _fetchAdminSettings();
    
    // Get AI prompt override
    final aiPrompt = settings['ai_prompt_override'] as String? ?? 
        'Analyze pet insurance risk focusing on age, breed health history, and regional factors.';
    
    // Check max acceptable risk
    final maxRiskScore = settings['risk_max_score'] as double? ?? 80.0;
    
    // Check excluded conditions
    final excludedConditions = settings['excluded_conditions'] as Map<String, dynamic>? ?? {};
    
    // Calculate risk with admin parameters
    final score = await _calculateWithAI(pet, owner, aiPrompt);
    
    // Flag for review if above threshold
    if (score > maxRiskScore) {
      await _flagForManualReview(pet, owner, score);
    }
    
    // Check for excluded conditions
    for (final condition in pet.preExistingConditions) {
      if (excludedConditions[condition] == true) {
        throw Exception('Coverage not available with $condition');
      }
    }
    
    return riskScore;
  }
}
```

### Example 3: Use in UI Display

```dart
class QuoteResultsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _fetchAdminSettings(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        
        final settings = snapshot.data as Map<String, dynamic>;
        final uiFlags = settings['ui_flags'] as Map<String, dynamic>? ?? {};
        final showExplainability = uiFlags['show_explainability'] ?? true;
        
        return Column(
          children: [
            PlanCards(),
            
            // Conditionally show risk breakdown
            if (showExplainability)
              RiskBreakdownCard(riskScore: riskScore),
            
            PurchaseButton(),
          ],
        );
      },
    );
  }
}
```

---

## 📈 Impact & Benefits

### For Admins
- ✅ **No Code Deployments:** Adjust underwriting rules instantly
- ✅ **Real-time Control:** Changes apply to all new quotes immediately
- ✅ **Audit Trail:** Track who changed what and when
- ✅ **Experimentation:** Test different pricing strategies easily

### For Business
- ✅ **Risk Management:** Control exposure with max risk threshold
- ✅ **Regulatory Compliance:** Exclude breeds/conditions as required
- ✅ **Pricing Optimization:** A/B test different multipliers
- ✅ **Market Adaptation:** Adjust regional modifiers per state

### For Users
- ✅ **Transparency:** Explainability toggle shows how quotes calculated
- ✅ **Fair Pricing:** AI prompts ensure consistent, unbiased assessment
- ✅ **Predictable:** Clear rules about exclusions/conditions

---

## 🎯 Future Enhancements

### Potential Additions
1. **Version History:** Track all setting changes over time
2. **A/B Testing:** Toggle between two pricing strategies
3. **State-Specific Rules:** Override settings per state/region
4. **Coverage Limits:** Set min/max coverage amounts
5. **Deductible Options:** Configure available deductible tiers
6. **Waiting Periods:** Adjust waiting periods per condition
7. **Discount Rules:** Configure multi-pet, annual pay discounts
8. **Claims Limits:** Set annual/lifetime claim limits
9. **Age Restrictions:** Min/max pet age for new policies
10. **Breed Categories:** Create custom risk tiers beyond exclusions

### Advanced Features
- **Rule Engine:** Visual workflow builder for complex rules
- **Simulation Mode:** Preview impact of changes before saving
- **Analytics Dashboard:** Show impact of settings on quote volume
- **Notifications:** Alert admins when quotes flagged for review
- **Approval Workflow:** Require multi-admin approval for major changes

---

## 🎉 Summary

**Status:** ✅ **COMPLETE AND PRODUCTION-READY**

**File:** `lib/admin/admin_risk_controls_page.dart`

**Lines of Code:** ~1,000+

**Features:** 7 major control sections, full CRUD with Firestore

**Access Control:** Role-based, admin-only (userRole == 2)

**UI Quality:** Full PetUwrite branding, polished interactions

**Data Persistence:** Single batched write to Firestore

**User Experience:** Intuitive ExpansionTiles, real-time feedback, save confirmation

This admin dashboard gives you complete control over the underwriting engine without touching code! 🚀
