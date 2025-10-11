# Override Eligibility - Quick Reference

## 🎯 Quick Access

**Path:** Admin Dashboard → Ineligible Tab → Click Quote → Override Eligibility

**Who:** Admins only (userRole == 2)

**Purpose:** Override AI eligibility decisions for declined quotes

---

## 📋 3 Override Decisions

### ✅ Approve
- Removes eligibility block
- Customer can purchase policy
- Use for: Resolved conditions, edge cases, acceptable risk

### ❌ Deny
- Confirms AI decline
- Adds human reasoning
- Use for: Valid declines, high risk, compliance

### 💰 Adjust Premium
- Approves with higher price
- Balances risk vs. coverage
- Use for: Manageable conditions with increased cost

---

## 📝 Form Fields

| Field | Required | Format | Example |
|-------|----------|--------|---------|
| **Decision** | ✅ Yes | Dropdown | Approve |
| **New Risk Score** | ⚠️ Optional | 0-100 | 75 |
| **Justification** | ✅ Yes | 20+ chars | "Condition resolved for >2 years, vet confirms..." |

---

## 🔄 Quick Workflow

1. **View** declined quote in Ineligible tab
2. **Click** quote card to open details
3. **Click** "Override Eligibility" button
4. **Select** decision (Approve/Deny/Adjust Premium)
5. **Enter** new risk score (optional)
6. **Write** justification (minimum 20 characters)
7. **Submit** override
8. **Verify** success message

---

## ✍️ Justification Template

```
[Reason for override]

[Evidence supporting decision]

[Risk mitigation strategy]

[Documentation reference]

[Compliance notes if applicable]
```

**Example:**
```
Customer provided 2 years of vet records showing diabetes 
is well-controlled with no complications. Latest A1C test 
within normal range. Owner experienced with diabetic pets 
and has excellent treatment compliance. Risk acceptable 
for Elite plan coverage.
```

---

## 🗄️ Data Updated

### Quote Document
```json
{
  "eligibility.status": "overridden",
  "humanOverride": {
    "decision": "Approve",
    "underwriterId": "admin_uid",
    "underwriterName": "Sarah Johnson",
    "timestamp": "2025-10-10T15:30:00Z",
    "reasoning": "Condition resolved...",
    "newRiskScore": 75  // if provided
  }
}
```

### Audit Log
```json
{
  "type": "eligibility_override",
  "quoteId": "quote_123",
  "adminId": "admin_uid",
  "decision": "Approve",
  "justification": "...",
  "timestamp": "..."
}
```

---

## ⚠️ Validation Rules

| Rule | Validation |
|------|------------|
| Justification | Minimum 20 characters |
| Risk Score | 0-100 or blank |
| Decision | Must select one option |
| Auth | Admin role required |

---

## 🚨 Common Errors

| Error | Solution |
|-------|----------|
| "Please provide a justification" | Enter justification text |
| "Justification must be at least 20 characters" | Add more detail |
| "Risk score must be 0-100" | Enter valid number |
| "User not authenticated" | Re-login to Firebase |

---

## 🎯 Use Case Cheat Sheet

| Scenario | Decision | Risk Score | Example Justification |
|----------|----------|------------|----------------------|
| Condition resolved | Approve | Lower | "2+ years resolved, vet confirms" |
| Breed risk overestimated | Approve | Lower | "Health-tested line, OFA certified" |
| Stable condition | Adjust Premium | Keep/Lower | "Well-controlled, 20% premium increase" |
| Valid decline | Deny | Keep | "Confirmed terminal diagnosis, exceeds guidelines" |

---

## 📊 After Override

**Approve Decision:**
- Quote status → "approved"
- Customer can purchase policy
- Email notification sent

**Deny Decision:**
- Quote status → "denied"
- Adds human confirmation
- Customer receives denial notice

**Adjust Premium Decision:**
- Quote status → "approved"
- New premium calculated
- Revised quote sent to customer

---

## 🔍 Audit Trail

**Every override creates:**
- Update in quote document (`humanOverride` field)
- New document in `audit_logs` collection
- Timestamp and admin identity recorded
- Original AI decision preserved

**Query example:**
```javascript
// All overrides in last 30 days
db.collection('audit_logs')
  .where('type', '==', 'eligibility_override')
  .where('timestamp', '>', thirtyDaysAgo)
  .get();
```

---

## 🎨 UI States

**Before Override:**
```
[Override Eligibility] button visible
```

**During Submit:**
```
[Submitting...] spinner visible
```

**After Override:**
```
✅ Eligibility Overridden
   Decision: Approve
   Admin: Sarah Johnson
   Date: Oct 10, 2025
```

---

## 🔒 Security

- ✅ Role check: `userRole == 2`
- ✅ Firebase Auth required
- ✅ Firestore security rules enforce admin-only updates
- ✅ Audit logs are write-only (no edits/deletes)

---

## 📞 Quick Support

**Can't see override button?**
→ Check user role in Firestore (must be 2)

**Override not saving?**
→ Check Firestore security rules

**Need to modify override?**
→ Create new override (originals are immutable)

**Want to query overrides?**
→ Use `audit_logs` collection

---

## 📚 Related Docs

- [Full Override Guide](./ADMIN_OVERRIDE_ELIGIBILITY_GUIDE.md) - Complete documentation
- [Admin Dashboard Guide](./ADMIN_DASHBOARD_GUIDE.md) - Dashboard overview
- [Ineligible Quotes](./ADMIN_INELIGIBLE_QUOTES_GUIDE.md) - Declined quotes workflow

---

## ✅ Quick Checklist

Before overriding a quote:
- [ ] Review AI decline reason
- [ ] Review risk score and factors
- [ ] Review pet medical history
- [ ] Check for supporting documentation
- [ ] Determine appropriate decision
- [ ] Write detailed justification (20+ chars)
- [ ] Consider risk score adjustment
- [ ] Submit and verify success

---

**Made with ❤️ for PetUwrite Admins**
