# Customer Flows

## Authentication and routing

- The app boots into an auth gate.
- Role routing is driven by `userRole`:
  - Customer: quote/claims/policies UI
  - Admin: admin dashboard

## Quote → Plan selection → Checkout → Bind

### 1) Quote intake

- Customer starts from the homepage and enters the conversational quote flow.
- The quote flow collects pet + owner info and can detect a “complex case”.

### 2a) Standard path (not complex)

- Proceeds to plan selection.
- Checkout is auth-gated.
- Confirmation/binding creates a policy.

### 2b) Complex case path (underwriting case lane)

- Creates `underwriting_cases/{caseId}` and seeds initial medical history state.
- Routes the user through:
  - Underwriting intake screen
  - Medical underwriting screen

### 3) Medical underwriting decision

- Medical underwriting persists current medical history.
- Eligibility/decision is computed deterministically (rules + mapping), producing:
  - Approve
  - Approve with exclusions
  - Decline

### 4) Disclosure acknowledgement

- If declined or exclusions exist, the user is shown a disclosure dialog.
- The user must explicitly acknowledge; an event is logged to the case.

### 5) Bind-time enforcement

- If `underwritingCaseId` exists during policy creation, policy binding requires that `underwriting_cases/{caseId}/decisions/current` exists.
- The policy is stamped with:
  - Underwriting snapshot
  - Exclusions

## Claim filing

- Claim filing is a conversational intake experience:
  - Incident date, claim type, description, estimate, attachments
  - Draft claims can be resumed

Admin tooling supports human review and analytics.
