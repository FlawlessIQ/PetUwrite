# Clovara Enterprise Admin Console — Architecture

This document describes the “enterprise console” admin UI foundation, how it is wired into the app, and the patterns used to build high-density operational screens.

## Goals

- **Persistent shell**: left navigation + global top bar that never changes across modules.
- **High-density workflows**: inbox tables, filters, selection, bulk actions, drill-down.
- **Audit-first detail views**: “Read / Annotate / Decide / Override / Audit trail”.
- **Single source of truth** for navigation and module mounting.
- **Analyzer-safe incremental refactors**: migrate legacy tabs into console patterns without breaking business logic.

## Non-goals (for now)

- Replacing Firestore document shapes or rules.
- Re-implementing analytics aggregation server-side (some screens still aggregate client-side).
- Introducing a full RBAC framework beyond the existing `userRole` checks.

## Entry & Routing

- The console is entered via role routing in **AuthGate**.
- Roles `2` and `3` (underwriter/admin) are routed to the console entry screen.

Key files:
- [lib/auth/auth_gate.dart](../lib/auth/auth_gate.dart)
- [lib/screens/admin_console_screen.dart](../lib/screens/admin_console_screen.dart)

## Shell (Layout)

The console shell is implemented as a reusable scaffold that provides:

- **Top bar**: global search entry (scaffolded), alerts/tasks stubs, profile menu + sign out.
- **Left nav**:
  - Desktop: navigation rail
  - Mobile/compact: drawer
- **Body padding and background**: consistent operational layout spacing.

Key file:
- [lib/admin_console/admin_scaffold.dart](../lib/admin_console/admin_scaffold.dart)

## Navigation Model (Single Source of Truth)

Navigation is defined in one place so that adding/removing modules stays consistent.

- `enum AdminNavItem` is the canonical set of modules.
- `kAdminNavItems` provides icons/labels used by the rail and drawer.

Key file:
- [lib/admin_console/admin_nav.dart](../lib/admin_console/admin_nav.dart)

## Module Mounting

`AdminConsoleScreen` owns the selected nav item state and mounts the matching module widget.

Pattern:
- `AdminConsoleScreen` holds `AdminNavItem _selected`.
- `switch (_selected)` returns the correct page.
- Modules remain independently testable widgets (not tightly coupled to the shell).

Key file:
- [lib/screens/admin_console_screen.dart](../lib/screens/admin_console_screen.dart)

### Console-native drill-down

When a module wants to “open another module”, prefer **switching nav selection** over pushing nested routes.

Example:
- Claims Analytics “Open inbox” uses an optional callback passed from `AdminConsoleScreen`.

## Shared UI Primitives

These are the “console primitives” used to keep screens visually consistent and operationally dense.

- `AdminSectionCard`: standard card section with title, icon, optional actions, consistent padding.
- `AdminKpiCard`: compact KPI tile with icon/value/label and optional click handling.
- `AdminStatusChip`: status/badge chip with consistent color + typography.

Key files:
- [lib/admin_console/components/admin_section_card.dart](../lib/admin_console/components/admin_section_card.dart)
- [lib/admin_console/components/admin_kpi_card.dart](../lib/admin_console/components/admin_kpi_card.dart)
- [lib/admin_console/components/admin_status_chip.dart](../lib/admin_console/components/admin_status_chip.dart)

## Screen Patterns

### 1) Inbox tables

Used for operational queues (Underwriting, Claims, Policies).

Characteristics:
- **High information density** using `DataTable`.
- **Selection** (row checkboxes + select-all) stored as `Set<String>` IDs.
- **Bulk actions** appear when selection is non-empty.
- **Sort + filter** controlled by a small set of state variables.

Implementation examples:
- Underwriting inbox: [lib/screens/admin/underwriting_cases_tab.dart](../lib/screens/admin/underwriting_cases_tab.dart)
- Claims inbox: [lib/screens/admin/claims_review_tab.dart](../lib/screens/admin/claims_review_tab.dart)
- Policies pipeline: [lib/screens/admin/policies_pipeline_tab.dart](../lib/screens/admin/policies_pipeline_tab.dart)

Notes:
- Policies uses client-side date filtering due to mixed `createdAt` types (`Timestamp` vs `String`).

### 2) Audit-first detail views

Underwriting case review uses a split, detail-centric layout:

- Decision snapshot/editor
- Timeline/event stream
- Structured summary for overrides and audit trail

Implementation example:
- [lib/screens/admin/underwriting_case_review_screen.dart](../lib/screens/admin/underwriting_case_review_screen.dart)

### 3) Analytics → Action

Analytics screens should not be “dead dashboards”.

Preferred pattern:
- Summary KPIs at top
- Filters in a section card
- Charts in section cards
- “Drill down” actions that switch the console module selection (e.g., open inbox)

Implementation example:
- [lib/screens/admin/claims_analytics_tab.dart](../lib/screens/admin/claims_analytics_tab.dart)

### 4) Tools/Editors inside the shell

Avoid nested `Scaffold` widgets inside console modules.

Implementation example:
- Rules editor runs as in-console content (no inner scaffold):
  - [lib/screens/admin_rules_editor_page.dart](../lib/screens/admin_rules_editor_page.dart)

## Data & Performance Notes

- Several screens still aggregate data client-side. For large datasets, consider:
  - pre-aggregations (Cloud Functions / scheduled jobs)
  - denormalized summary docs
  - Firestore composite indexes
  - pagination / query cursors

- Claims Analytics currently performs extra Firestore reads for some filters; moving this to server-side aggregation is a recommended next step.

## Security / Access Control

- Routing is role-based using Firestore `users/{uid}.userRole`.
- Some screens (e.g., rules editing) also check `userRole` directly.

Recommended future improvement:
- Centralize permission checks into a single “capabilities” helper so screens can consistently gate actions.

## Adding a New Module

Checklist:

1. Add a new case to `AdminNavItem` and update `kAdminNavItems`.
2. Mount the widget in `AdminConsoleScreen`.
3. Build UI using `AdminSectionCard` + `AdminKpiCard`.
4. Prefer inbox tables for queues and ensure bulk actions are selection-safe.
5. Keep analyzer green (`flutter analyze`).

## Known Follow-ups / Roadmap

- Add a real global search implementation (ID/email -> route to detail).
- Standardize table components (sorting/selection) into a reusable widget.
- Add audit logging helpers for bulk actions.
- Move heavy analytics aggregation server-side.
- Expand “Rules & Pricing” into versioning/diff + staged deploy/rollback workflow.
