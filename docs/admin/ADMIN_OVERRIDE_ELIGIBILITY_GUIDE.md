# Admin Override Eligibility Feature - Complete Guide

## 🎯 Overview

The **Override Eligibility** feature allows admins to manually override AI eligibility decisions for declined quotes. This provides human oversight for edge cases where the AI may have been too strict or when additional context justifies approval.

---

## 🔐 Access Control

**Who Can Override:**
- Users with `userRole == 2` (Admin/Underwriter role only)
- Must be authenticated in Firebase Auth

**Where to Access:**
- Navigate to Admin Dashboard → **Ineligible Tab**
- Click on any declined quote card
- Modal opens with quote details
- Click **"Override Eligibility"** button

---

## 🎨 User Interface

### Declined Quote Card
Each ineligible quote displays:
- **DECLINED** badge (red)
- Pet name, breed
- Risk score
- Rule violated
- Decline reason
- Date of decline
- **"Request Review"** button OR **"Review Requested"** status

### Quote Details Modal
When you click a declined quote:
```
┌─────────────────────────────────────────────┐
│ Ineligible Quote Details                    │
├─────────────────────────────────────────────┤
│ [Quote Declined Card]                        │
│   • Rule Violated: maxRiskScore             │
│   • Reason: Risk score 95 exceeds max 85    │
│                                              │
│ [Risk Assessment Card]                       │
│   • Overall Risk Score: 95                  │
│   • Risk Level: Very High Risk              │
│                                              │
│ [Pet Information Card]                       │
│ [Owner Information Card]                     │
│ [Quote Information Card]                     │
│                                              │
│ [Admin Override Section]                     │
│   ┌─────────────────────────────────────┐  │
│   │ 🛡️ Admin Override                   │  │
│   │                                      │  │
│   │ This quote was automatically         │  │
│   │ declined. As an admin, you can      │  │
│   │ override this decision with proper  │  │
│   │ justification.                       │  │
│   │                                      │  │
│   │ [Override Eligibility Button]       │  │
│   └─────────────────────────────────────┘  │
│                                              │
│ [Request Manual Review Button]               │
└─────────────────────────────────────────────┘
```

### Override Dialog
When you click **"Override Eligibility"**:
```
┌──────────────────────────────────────┐
│ 🛡️ Override Eligibility              │
├──────────────────────────────────────┤
│ You are about to override the AI     │
│ eligibility decision. This action    │
│ will be logged in the audit trail.   │
│                                       │
│ Decision                              │
│ ┌────────────────────────────────┐   │
│ │ ✅ Approve                 ▼   │   │
│ └────────────────────────────────┘   │
│   Options:                            │
│   • Approve                           │
│   • Deny                              │
│   • Adjust Premium                    │
│                                       │
│ New Risk Score (Optional)             │
│ ┌────────────────────────────────┐   │
│ │ Current: 95               │   │
│ └────────────────────────────────┘   │
│ Enter 0-100, or leave blank           │
│                                       │
│ Manual Justification (Required)       │
│ ┌────────────────────────────────┐   │
│ │ Condition resolved for >2      │   │
│ │ years, recent clean checkup... │   │
│ │                                │   │
│ │                                │   │
│ └────────────────────────────────┘   │
│ Explain why you are overriding        │
│                                       │
│        [Cancel] [Submit Override]     │
└──────────────────────────────────────┘
```

---

## 📋 Override Form Fields

### 1. **Decision Dropdown** (Required)
Select one of three options:

#### ✅ **Approve**
- Overrides the decline and allows quote to proceed
- Customer can purchase policy
- Updates `eligibility.status` to `"overridden"`
- Removes eligibility block

**Use When:**
- Condition is well-managed or resolved
- Customer has documentation supporting coverage
- Risk is acceptable despite high score
- Edge case where AI was too strict

**Example:**
```
Pet has diabetes but has been stable for 3+ years with 
excellent management. Owner provided vet records showing 
consistent monitoring and no complications.
```

#### ❌ **Deny**
- Confirms the AI's decline decision
- Adds human reasoning to the denial
- Permanently denies the quote

**Use When:**
- AI decision is correct
- Risk is genuinely too high
- Policy terms cannot accommodate the condition
- Confirming decline for compliance reasons

**Example:**
```
Confirmed severe heart condition with poor prognosis. 
Multiple vet visits show progressive worsening. Risk 
exceeds acceptable underwriting guidelines.
```

#### 💰 **Adjust Premium**
- Approves the quote with modified pricing
- Allows coverage with higher premium
- Balances risk with appropriate pricing
- Customer receives revised quote

**Use When:**
- Coverage is possible but at higher cost
- Risk is manageable with premium adjustment
- Competitive pricing still achievable
- Customer willing to pay more for coverage

**Example:**
```
Pre-existing hip dysplasia is manageable. Approved with 
15% premium increase to account for increased claim 
likelihood. Condition excluded for first 12 months.
```

---

### 2. **New Risk Score** (Optional)
- Numeric input: 0-100
- Overrides the AI-calculated risk score
- Stores original score for audit trail

**When to Use:**
- AI risk score seems inaccurate
- Manual assessment suggests different risk level
- New information changes risk profile

**Guidelines:**
- Leave blank if AI score is accurate
- Use conservative estimates
- Document reasoning in justification field

**Examples:**
```
AI Score: 95
Manual Score: 78
Reason: "AI overestimated breed risk; this is a well-bred, 
health-tested line with no genetic issues"

AI Score: 82
Manual Score: 65
Reason: "Recent surgery resolved condition; AI didn't 
account for post-op clean bill of health"
```

---

### 3. **Manual Justification** (Required)
- Text area: 5 lines
- Minimum 20 characters
- Detailed explanation required

**What to Include:**
1. **Reason for Override:** Why AI decision was wrong/strict
2. **Evidence:** What information supports your decision
3. **Risk Mitigation:** How risk is managed/acceptable
4. **Documentation:** Reference any vet records, reports
5. **Compliance:** Note any policy exceptions applied

**Good Examples:**
```
✅ "Customer provided 2 years of vet records showing 
   diabetes is well-controlled with no complications. 
   Latest A1C test is within normal range. Owner is 
   experienced with diabetic pets and has excellent 
   compliance with treatment protocols. Risk is 
   acceptable for Elite plan coverage."

✅ "While AI flagged Cavalier King Charles Spaniel breed 
   risk for heart conditions, this specific dog is only 
   2 years old with recent cardiac ultrasound showing 
   completely normal heart function. No family history 
   of MVD. Approved with standard premium."

✅ "Condition resolved for >2 years. Clean checkup 
   confirms no recurrence. Vet states low likelihood 
   of future issues. Acceptable risk profile."
```

**Bad Examples:**
```
❌ "Seems fine" (Too vague, no details)

❌ "Customer asked nicely" (Not a valid reason)

❌ "Override" (No explanation)

❌ "Low risk" (No supporting evidence)
```

---

## 🔄 Override Workflow

### Step-by-Step Process

1. **Admin Views Ineligible Tab**
   - Sees all declined quotes
   - Filters by "Review Requested" if needed

2. **Admin Clicks Declined Quote**
   - Modal opens with full quote details
   - Reviews AI decline reason
   - Reviews risk score and risk factors
   - Reviews pet/owner information

3. **Admin Decides to Override**
   - Clicks **"Override Eligibility"** button
   - Dialog opens with override form

4. **Admin Fills Form**
   - Selects decision: Approve/Deny/Adjust Premium
   - Optionally enters new risk score
   - Writes detailed justification (minimum 20 characters)

5. **Admin Submits Override**
   - Clicks **"Submit Override"**
   - System validates all fields
   - Shows success message

6. **System Updates Quote**
   - Updates `eligibility.status` to `"overridden"`
   - Stores override details in `humanOverride` field
   - Logs to `audit_logs` collection
   - Sends notification (if configured)

7. **Customer Receives Update**
   - Email notification of decision
   - Can proceed with purchase (if approved)
   - Sees revised premium (if adjusted)

---

## 🗄️ Data Structure

### Firestore Updates

#### Quote Document Updated
```json
{
  "quotes/{quoteId}": {
    "eligibility": {
      "eligible": false,           // Original AI decision
      "status": "overridden",      // Changed from "declined"
      "reason": "Risk score 95 exceeds maximum 85",
      "ruleViolated": "maxRiskScore",
      "overriddenAt": "2025-10-10T15:30:00Z",
      "overriddenBy": "admin_uid_123"
    },
    "humanOverride": {
      "decision": "Approve",
      "underwriterId": "admin_uid_123",
      "underwriterName": "Sarah Johnson",
      "timestamp": "2025-10-10T15:30:00Z",
      "reasoning": "Condition resolved for >2 years, recent clean checkup...",
      "originalStatus": "declined",
      "originalReason": "Risk score 95 exceeds maximum 85",
      "newRiskScore": 78             // Optional: if admin adjusted score
    },
    "riskScore": {
      "totalScore": 78,               // Updated if admin provided new score
      "overridden": true,
      "originalScore": 95             // Preserved for audit
    }
  }
}
```

#### Audit Log Created
```json
{
  "audit_logs/{logId}": {
    "type": "eligibility_override",
    "quoteId": "quote_abc123",
    "adminId": "admin_uid_123",
    "adminName": "Sarah Johnson",
    "decision": "Approve",
    "justification": "Condition resolved for >2 years...",
    "originalStatus": "declined",
    "originalReason": "Risk score 95 exceeds maximum 85",
    "ruleViolated": "maxRiskScore",
    "newRiskScore": 78,
    "originalRiskScore": 95,
    "timestamp": "2025-10-10T15:30:00Z"
  }
}
```

---

## 🎯 Use Cases

### Use Case 1: Resolved Medical Condition
**Scenario:**
- Quote declined due to pre-existing heart murmur
- Customer provides vet records showing murmur resolved
- Recent echocardiogram is clean

**Admin Action:**
- Decision: **Approve**
- New Risk Score: `70` (down from 88)
- Justification: "Heart murmur documented as resolved per 2024 echo. Cardiologist cleared pet for normal activity. Risk now acceptable."

---

### Use Case 2: Breed Risk Overestimation
**Scenario:**
- German Shepherd declined due to breed risk (hip dysplasia)
- Dog is only 1 year old with OFA "Excellent" hip certification
- Parents both OFA certified

**Admin Action:**
- Decision: **Approve**
- New Risk Score: `65` (down from 82)
- Justification: "While breed has genetic predisposition, this specific dog has OFA Excellent certification. Parents both certified. Health-tested line reduces risk significantly."

---

### Use Case 3: Premium Adjustment
**Scenario:**
- Quote declined due to diabetes diagnosis
- Condition is stable but increases claim likelihood
- Customer willing to pay higher premium

**Admin Action:**
- Decision: **Adjust Premium**
- New Risk Score: `72` (keep AI score)
- Justification: "Diabetes well-controlled per 6 months of records. Approved with 20% premium increase. Pre-existing exclusion applied for first policy year."

---

### Use Case 4: Confirming Denial
**Scenario:**
- Quote declined due to terminal cancer diagnosis
- AI decision is correct
- Customer asks for reconsideration

**Admin Action:**
- Decision: **Deny**
- New Risk Score: (leave blank)
- Justification: "Confirmed terminal diagnosis with poor prognosis per oncology report dated 2025-09-15. Risk exceeds underwriting guidelines. Respectfully denying coverage."

---

## 🔍 Audit Trail & Compliance

### What Gets Logged
Every override creates two audit records:

1. **In Quote Document:**
   - Full override details
   - Admin identity
   - Original AI decision preserved
   - Timestamp of override

2. **In Audit Logs Collection:**
   - Separate audit_logs document
   - Searchable and reportable
   - Cannot be deleted (write-only)
   - Compliance-ready format

### Audit Reports
Query audit logs to generate reports:

```javascript
// All eligibility overrides in last 30 days
db.collection('audit_logs')
  .where('type', '==', 'eligibility_override')
  .where('timestamp', '>', thirtyDaysAgo)
  .orderBy('timestamp', 'desc')
  .get();

// Overrides by specific admin
db.collection('audit_logs')
  .where('type', '==', 'eligibility_override')
  .where('adminId', '==', 'admin_uid_123')
  .get();

// All "Approve" overrides
db.collection('audit_logs')
  .where('type', '==', 'eligibility_override')
  .where('decision', '==', 'Approve')
  .get();
```

### Compliance Features
- ✅ **Immutable Audit Trail:** Original decisions preserved
- ✅ **Admin Accountability:** Every override linked to admin user
- ✅ **Timestamp Accuracy:** Exact time of override recorded
- ✅ **Justification Required:** Cannot override without explanation
- ✅ **Multi-level Logging:** Quote doc + separate audit collection

---

## 🚨 Validation & Error Handling

### Form Validation

#### Justification Field
- ✅ **Required:** Cannot be empty
- ✅ **Minimum Length:** 20 characters
- ❌ **Error:** "Please provide a justification for the override"
- ❌ **Error:** "Justification must be at least 20 characters"

#### New Risk Score Field
- ⚠️ **Optional:** Can be left blank
- ✅ **Valid Range:** 0-100
- ❌ **Error:** "Risk score must be a number between 0 and 100"
- ❌ **Invalid Input:** "abc", "-5", "150"

#### Decision Field
- ✅ **Required:** Pre-selected to "Approve"
- ✅ **Options:** Approve, Deny, Adjust Premium

### Success Messages
```
✅ "Eligibility override submitted: Approve"
✅ "Eligibility override submitted: Adjust Premium"
```

### Error Messages
```
❌ "Please provide a justification for the override"
❌ "Justification must be at least 20 characters"
❌ "Risk score must be a number between 0 and 100"
❌ "User not authenticated"
❌ "Error submitting override: [error details]"
```

---

## 📊 UI States

### State 1: Before Override
```
┌────────────────────────────────┐
│ 🛡️ Admin Override             │
│                                │
│ This quote was automatically   │
│ declined. As an admin, you can │
│ override this decision...      │
│                                │
│ [Override Eligibility Button]  │
└────────────────────────────────┘
```

### State 2: Dialog Open
```
Dialog with form fields visible
User can fill out decision, risk score, justification
```

### State 3: Submitting
```
[Override Eligibility Button]
  (Loading spinner visible)
  "Submitting..."
```

### State 4: After Override
```
┌────────────────────────────────┐
│ ✅ Eligibility Overridden      │
│                                │
│ Decision: Approve              │
│ Admin: Sarah Johnson           │
│ Override Date: Oct 10, 2025    │
│                                │
│ Justification:                 │
│ ┌──────────────────────────┐  │
│ │ Condition resolved for   │  │
│ │ >2 years, recent clean   │  │
│ │ checkup...               │  │
│ └──────────────────────────┘  │
└────────────────────────────────┘
```

---

## 🎨 Visual Design

### Color Scheme
- **Override Section Background:** Amber 50 (`Colors.amber[50]`)
- **Override Button:** Amber 700 (`Colors.amber[700]`)
- **Success State:** Green 50 (`Colors.green[50]`)
- **Dialog Icons:** Amber (`Colors.amber`)

### Button Styling
```dart
ElevatedButton.icon(
  backgroundColor: Colors.amber[700],
  foregroundColor: Colors.white,
  padding: EdgeInsets.symmetric(vertical: 16),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(8),
  ),
)
```

### Card Styling
```dart
Card(
  elevation: 2,
  color: Colors.amber[50],
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12)
  ),
)
```

---

## 🧪 Testing Checklist

### Manual Testing Steps

#### Test 1: Basic Override - Approve
1. ✅ Navigate to Admin Dashboard → Ineligible tab
2. ✅ Click on a declined quote
3. ✅ Verify quote details display correctly
4. ✅ Click **"Override Eligibility"** button
5. ✅ Dialog opens with form
6. ✅ Select "Approve" from dropdown
7. ✅ Leave risk score blank
8. ✅ Enter justification: "Condition resolved, vet confirms no issues"
9. ✅ Click **"Submit Override"**
10. ✅ Success message appears
11. ✅ Modal refreshes showing override details
12. ✅ Quote document updated in Firestore
13. ✅ Audit log created

#### Test 2: Override with New Risk Score
1. ✅ Open declined quote modal
2. ✅ Click **"Override Eligibility"**
3. ✅ Select "Adjust Premium"
4. ✅ Enter new risk score: `70`
5. ✅ Enter justification: "Risk reassessed based on additional documentation"
6. ✅ Submit override
7. ✅ Verify `riskScore.totalScore` updated to 70
8. ✅ Verify `riskScore.originalScore` preserved

#### Test 3: Validation Errors
1. ✅ Open override dialog
2. ✅ Try to submit with empty justification → Error shown
3. ✅ Enter justification < 20 chars → Error shown
4. ✅ Enter invalid risk score ("abc") → Error shown
5. ✅ Enter risk score > 100 → Error shown
6. ✅ Enter risk score < 0 → Error shown

#### Test 4: Already Overridden Quote
1. ✅ Override a quote
2. ✅ Reopen the same quote
3. ✅ Verify override details section shows
4. ✅ Verify override button is hidden
5. ✅ Verify admin name, decision, justification displayed

#### Test 5: Audit Trail
1. ✅ Override a quote
2. ✅ Query Firestore `audit_logs` collection
3. ✅ Verify log document created
4. ✅ Verify all fields populated correctly
5. ✅ Verify timestamp matches override time

---

## 🔒 Security Considerations

### Role-Based Access
```dart
// Check admin role before showing override button
final user = FirebaseAuth.instance.currentUser;
final userDoc = await FirebaseFirestore.instance
    .collection('users')
    .doc(user.uid)
    .get();
    
final userRole = userDoc.data()?['userRole'];
if (userRole != 2) {
  // Hide override functionality
  // Only admins can override
}
```

### Firestore Security Rules
```javascript
// Only admins can update humanOverride field
match /quotes/{quoteId} {
  allow update: if request.auth != null 
    && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.userRole == 2
    && request.resource.data.diff(resource.data).affectedKeys().hasOnly([
      'humanOverride', 
      'eligibility.status',
      'eligibility.overriddenAt',
      'eligibility.overriddenBy',
      'riskScore.totalScore',
      'riskScore.overridden',
      'riskScore.originalScore'
    ]);
}

// Audit logs are write-only
match /audit_logs/{logId} {
  allow create: if request.auth != null 
    && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.userRole == 2;
  allow read: if request.auth != null 
    && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.userRole == 2;
  allow update, delete: if false;  // Never allow updates or deletes
}
```

---

## 📈 Analytics & Reporting

### Key Metrics to Track

1. **Override Rate**
   - Total overrides / Total declined quotes
   - Target: <15% (AI should be accurate)

2. **Override Decision Breakdown**
   - % Approve
   - % Deny
   - % Adjust Premium

3. **Average Time to Override**
   - Time from decline to override
   - Target: <24 hours

4. **Top Override Reasons**
   - Most common justification themes
   - Identify AI improvement opportunities

5. **Admin Activity**
   - Overrides per admin
   - Ensure balanced workload

### Sample Analytics Query
```javascript
// Firebase Cloud Function for analytics
exports.calculateOverrideMetrics = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const overrides = await admin.firestore()
      .collection('audit_logs')
      .where('type', '==', 'eligibility_override')
      .where('timestamp', '>', thirtyDaysAgo)
      .get();

    const totalOverrides = overrides.size;
    const approveCount = overrides.docs.filter(
      doc => doc.data().decision === 'Approve'
    ).length;

    const metrics = {
      totalOverrides,
      approveCount,
      approveRate: (approveCount / totalOverrides * 100).toFixed(2) + '%',
      calculatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await admin.firestore()
      .collection('analytics')
      .doc('override_metrics')
      .set(metrics);
  });
```

---

## 🚀 Future Enhancements

### Phase 2 Features
- **Bulk Override:** Override multiple quotes at once
- **Override Templates:** Pre-defined justification templates
- **Conditional Approval:** Approve with specific conditions (e.g., vet checkup required)
- **Approval Workflow:** Require multiple admin approvals for high-value overrides
- **Customer Notification:** Auto-send email when override approved
- **Premium Calculator:** Auto-suggest premium adjustment amount

### Phase 3 Features
- **AI Learning:** Feed override data back to AI model for improvement
- **Risk Model Tuning:** Adjust rules based on override patterns
- **Peer Review:** Second admin must confirm override
- **Escalation Path:** Require senior admin approval for certain cases

---

## 📞 Support & Troubleshooting

### Common Issues

#### Override Button Not Visible
**Cause:** User doesn't have admin role (userRole != 2)  
**Solution:** Verify user's `userRole` field in Firestore

#### "User not authenticated" Error
**Cause:** Firebase Auth session expired  
**Solution:** Log out and log back in

#### Override Not Saving
**Cause:** Firestore security rules blocking update  
**Solution:** Check Firestore rules allow admin updates

#### Justification Field Error
**Cause:** Less than 20 characters entered  
**Solution:** Expand justification with more detail

---

## 📚 Related Documentation

- [Admin Dashboard Guide](./ADMIN_DASHBOARD_GUIDE.md)
- [Ineligible Quotes Guide](./ADMIN_INELIGIBLE_QUOTES_GUIDE.md)
- [Underwriting Rules Engine](./UNDERWRITING_RULES_ENGINE_GUIDE.md)
- [Audit Trail & Compliance](./AUDIT_TRAIL_DOCUMENTATION.md)
- [Risk Scoring Engine](./RISK_SCORING_DOCUMENTATION.md)

---

## ✅ Summary

The **Override Eligibility** feature provides essential human oversight for AI-driven underwriting decisions:

✅ **Admin Control:** Authorized admins can override declined quotes  
✅ **Flexible Decisions:** Approve, Deny, or Adjust Premium  
✅ **Risk Adjustment:** Optionally modify AI risk score  
✅ **Required Justification:** All overrides must be explained  
✅ **Complete Audit Trail:** Every override is logged immutably  
✅ **User-Friendly UI:** Simple, intuitive interface  
✅ **Secure:** Role-based access and Firestore security rules  
✅ **Compliant:** Meets regulatory audit requirements  

This feature ensures that while AI provides speed and consistency, human expertise remains the final authority on coverage decisions. 🚀
