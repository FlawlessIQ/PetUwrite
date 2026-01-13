# Admin Flows

Admin access is restricted to `userRole` admin values (see auth gate + rules).

## Admin Dashboard

The admin dashboard provides multiple tabs:

- High risk / ineligible quote review (legacy quote risk tooling)
- Policies pipeline
- Claims analytics
- Underwriting review
- Underwriting rules
- System health

## Underwriting review

- Underwriting cases are listed by status (open vs decided, and per-status filters).
- Selecting a case opens the underwriting case review screen.
- Manual decisions:
  - Approve / approve-with-exclusions / decline / refer
  - Saves decision to `underwriting_cases/{caseId}/decisions/current`
  - Updates `underwriting_cases/{caseId}.status`

## Policies pipeline

- KPI dashboard (policy counts, active, new in window, MRR/ARR)
- Status breakdown and funnel-style views
- Filtered policy list for review

## Claims review & analytics

- Claims review tab:
  - Focused on claims that need human review
  - Displays month-to-date metrics and a filtered list

- Claims analytics tab:
  - Aggregates claims for charts and distribution views
  - Supports client-side filtering for development (with a TODO to move to Cloud Functions aggregation)
