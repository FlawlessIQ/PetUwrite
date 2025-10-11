# Admin Dashboard Features Summary

**Last Updated:** October 10, 2025  
**Dashboard Title:** Admin Dashboard  
**Access Level:** userRole 2 (Admin/Underwriter) & userRole 3 (Super Admin)

---

## 📊 Dashboard Tabs

The Admin Dashboard (`lib/screens/admin_dashboard.dart`) provides comprehensive tools for managing the PetUwrite insurance platform with **4 main tabs**:

### 1️⃣ **High Risk Tab** 🚨
Review and manage high-risk insurance quotes that require human oversight.

**Features:**
- ✅ Real-time quote filtering (riskScore > 80)
- ✅ Sort by: Risk Score or Date
- ✅ Filter by: All, Pending Review, Overridden
- ✅ Statistics dashboard (Total/Pending/Overridden counts)
- ✅ Risk score badges with color coding
- ✅ **Explainability Charts** - Visual breakdown of AI decisions
  - Feature contributions (Age, Breed, Medical History, etc.)
  - Risk factor analysis
  - AI confidence scores
- ✅ Detailed quote view with complete pet/owner information
- ✅ **Override Capability** - Approve/Deny/Request More Info
- ✅ Audit logging for all underwriter decisions
- ✅ AI Analysis review (reasoning, risk factors, recommendations)

**Quote Card Information:**
- Risk score and level
- Override status
- Pet details (name, breed, age)
- Owner contact info
- Creation timestamp
- AI decision summary

**Override Actions:**
- Approve quote (overrides AI deny)
- Deny quote (confirms AI or overrides AI approve)
- Request more information
- Mandatory justification (min 20 characters)
- Full audit trail

---

### 2️⃣ **Ineligible Tab** 🚫
Manage quotes that were automatically declined due to eligibility rules.

**Features:**
- ✅ View all ineligible quotes
- ✅ See specific reasons for ineligibility
- ✅ **Override eligibility decisions** when appropriate
- ✅ Filter and sort ineligible quotes
- ✅ Review failed rules (age limits, breed restrictions, etc.)
- ✅ Approve exceptions with documented justification
- ✅ Track override history

**Common Ineligibility Reasons:**
- Pet age outside acceptable range
- Breed restrictions
- Pre-existing conditions
- Location limitations
- Failed underwriting rules

**Override Process:**
1. Review ineligibility reason
2. Evaluate exception request
3. Document justification
4. Approve or maintain denial
5. Logged to audit trail

---

### 3️⃣ **Claims Analytics Tab** 📈
Comprehensive analytics and insights into claims patterns and business performance.

**Features:**
- ✅ Claims trends over time
- ✅ Loss ratio analysis
- ✅ Breed-specific claims data
- ✅ Age group risk analysis
- ✅ Condition frequency tracking
- ✅ Geographic claims patterns
- ✅ Cost analysis and projections
- ✅ Interactive charts and visualizations
- ✅ Export capabilities for reporting

**Analytics Views:**
- Claims volume by time period
- Average claim amounts
- Most common claim types
- High-risk breed identification
- Seasonal patterns
- Regional variations
- Underwriting accuracy metrics

**Benefits:**
- Data-driven underwriting decisions
- Identify emerging risk patterns
- Optimize pricing strategies
- Improve AI model accuracy
- Regulatory reporting support

---

### 4️⃣ **Rules Editor Tab** ⚙️
Edit and manage underwriting rules in real-time without code deployment.

**Features:**
- ✅ **Real-time rule updates** - Changes apply immediately
- ✅ **Master enable/disable switch** - Turn entire rules engine on/off
- ✅ **Visual rule configuration:**
  - Maximum Risk Score threshold (slider)
  - Age limits (min/max for dogs/cats)
  - Weight restrictions
  - Breed blacklist/whitelist
  - Medical condition restrictions
  - Geographic exclusions
- ✅ **Input validation** - Prevents invalid configurations
- ✅ **Last updated tracking** - Shows who changed what and when
- ✅ **Auto-save functionality** - One-click updates to Firestore
- ✅ **Cache clearing** - Forces immediate rule reload across platform

**Editable Rules:**
1. **Risk Score Threshold**
   - Maximum acceptable risk score
   - Affects eligibility decisions

2. **Age Restrictions**
   - Minimum/maximum age for dogs
   - Minimum/maximum age for cats
   - Measured in months

3. **Weight Limits**
   - Minimum/maximum weight
   - Species-specific settings

4. **Breed Lists**
   - High-risk breeds (auto-deny or higher premiums)
   - Approved breeds (standard processing)
   - Breed-specific multipliers

5. **Medical Conditions**
   - Pre-existing condition rules
   - Chronic illness handling
   - Required waiting periods

6. **Geographic Rules**
   - State/region restrictions
   - Location-based pricing
   - Service area definitions

**Rule Update Process:**
1. Navigate to Rules Editor tab
2. Expand section to edit
3. Adjust values using sliders/inputs
4. Review changes
5. Click "Save Rules"
6. System updates Firestore
7. Cache cleared automatically
8. New rules active immediately

---

## 🔐 Access Control & Security

### User Roles
- **userRole 0**: Regular customer (no dashboard access)
- **userRole 1**: Premium customer (no dashboard access)
- **userRole 2**: Admin/Underwriter (full dashboard access) ✅
- **userRole 3**: Super Admin (full dashboard access + user management)

### Security Features
- ✅ Role-based access control via `auth_gate.dart`
- ✅ Firestore security rules prevent unauthorized access
- ✅ All override actions are audit-logged
- ✅ Underwriter identity tracked on all decisions
- ✅ Timestamp tracking for compliance

### Audit Trail
Every admin action is logged to `/audit_logs/{logId}`:
```
{
  action: "override" | "edit_rules" | "approve_ineligible",
  quoteId: "quote_123",
  underwriterId: "user_456",
  underwriterName: "Jane Smith",
  underwriterEmail: "jane@example.com",
  decision: "Approve",
  justification: "Owner has excellent history...",
  originalAIDecision: "Deny",
  riskScore: 85,
  timestamp: Timestamp,
  changes: {} // For rule edits
}
```

---

## 📱 UI/UX Features

### Design Elements
- **Color Coding:**
  - 🟢 Green: Approved/Low Risk
  - 🟡 Yellow: Medium Risk
  - 🟠 Orange: High Risk
  - 🔴 Red: Critical Risk/Denied
  - 🔵 Blue: Pending Review

- **Icons:**
  - ⚠️ Warning: High Risk tab
  - 🚫 Block: Ineligible tab
  - 📊 Analytics: Claims Analytics tab
  - ✏️ Edit: Rules Editor tab

- **Interactive Elements:**
  - ExpansionTiles for detailed views
  - Sliders for numeric inputs
  - Toggle switches for boolean values
  - Chips for multi-select options
  - Refresh button for manual reload
  - Sort/filter dropdowns

### Responsive Layout
- ✅ Works on desktop and tablet
- ✅ Scrollable content areas
- ✅ Modal bottom sheets for details
- ✅ Collapsible sections
- ✅ Optimized for admin workflows

---

## 🚀 How to Access

### As an Admin (userRole 2)
1. Log in to your account
2. AuthGate automatically routes to Admin Dashboard
3. You see all 4 tabs immediately
4. Select the tab for your task:
   - Review high-risk quotes → High Risk tab
   - Handle ineligible quotes → Ineligible tab
   - View analytics → Claims Analytics tab
   - Edit rules → Rules Editor tab

### For Testing
```dart
// Set a user to admin role in Firestore
await FirebaseFirestore.instance
  .collection('users')
  .doc(userId)
  .set({
    'email': 'admin@petuwrite.com',
    'userRole': 2,  // Admin access
    'createdAt': FieldValue.serverTimestamp(),
  });
```

---

## 📚 Related Documentation

- **Setup Guide:** `ADMIN_DASHBOARD_SETUP.md`
- **Detailed Features:** `ADMIN_DASHBOARD_GUIDE.md`
- **Quick Reference:** `ADMIN_DASHBOARD_QUICK_REF.md`
- **Rules Editor:** `ADMIN_RULES_EDITOR_GUIDE.md`
- **Explainability:** `EXPLAINABILITY_GUIDE.md`
- **Claims Analytics:** `CLAIMS_ANALYTICS_GUIDE.md`
- **Ineligible Quotes:** `ADMIN_INELIGIBLE_QUOTES_GUIDE.md`
- **Override System:** `ADMIN_OVERRIDE_ELIGIBILITY_GUIDE.md`

---

## ✅ Summary

The Admin Dashboard is a **comprehensive management interface** with 4 powerful tabs:

1. **High Risk** - AI decision review + explainability
2. **Ineligible** - Exception handling + overrides  
3. **Claims Analytics** - Business intelligence + reporting
4. **Rules Editor** - Real-time configuration management

All features include audit logging, role-based access, and intuitive UI for efficient admin workflows.

**Status:** ✅ Production Ready  
**Access:** userRole 2 & 3  
**Location:** `lib/screens/admin_dashboard.dart`
