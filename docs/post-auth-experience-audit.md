# Clovara Post-Auth Experience Audit

Date: May 21, 2026

## Executive read

The authenticated experience still exists in the legacy Flutter app, but it was disconnected when Firebase Hosting was switched to the static Next.js marketing site. The immediate bridge is to serve the Flutter app under `/app` and link the website sign-in button to `/app/sign-in`.

Current auth routing is role-based:

- `lib/auth/login_screen.dart`: Firebase email/password sign-in and sign-up.
- `lib/auth/auth_gate.dart`: routes by `users/{uid}.userRole`.
- Customer roles `0` and `1`: `CustomerHomeScreen`.
- Admin roles `2` and `3`: `AdminConsoleScreen`.

This preserves the previous customer/admin split, but the post-auth UI is not yet at the standard set by the new marketing site.

## Customer Policy Management

Relevant screens:

- `lib/auth/customer_home_screen.dart`
- `lib/screens/claims/claims_list_screen.dart`
- `lib/screens/claims/claim_intake_screen.dart`
- `lib/screens/claims/claim_details_screen.dart`
- `lib/screens/policy_confirmation_screen.dart`
- `lib/screens/underwriting_followup_documents_screen.dart`

What already works:

- Customers can sign in, see active policies, continue pending quotes, resume underwriting follow-up, start claims, continue claim drafts, and view recent claim status.
- The dashboard has a sensible information hierarchy: welcome, quick stats, quick actions, pending work, policies, claims.
- There is real Firebase data binding rather than static UI.
- Underwriting follow-up is represented as a customer-facing task, which matters for no-human-touch underwriting.

Where it falls short against the current website UI:

- Visual language is still from the previous Flutter system: rounded cards, gradients, emoji, Material icons, and heavier shadows. It does not fully match the current warm editorial Next design.
- Policy cards are too shallow. They show pet, plan, and premium, but not enough for a policyholder to feel in control.
- Claims status is useful but not world-class. Customers need a timeline, next-step clarity, expected payout date, documents, and decision explanation.
- The dashboard relies on hidden empty sections. If a customer has no active policy, claim, or pending item, the page can feel sparse rather than intentionally guided.
- Support is a modal with placeholder phone/email. It should be a structured support/contact surface.

World-class customer expectation:

- A policyholder should land on a calm command center: policy status, coverage summary, deductible progress, reimbursement rate, waiting periods, exclusions, renewal date, billing status, and next action.
- Every claim should have a transparent tracker: submitted, invoice read, coverage checked, decision made, payout initiated, paid.
- Every automated underwriting decision should be explainable in plain English: approved, approved with exclusions, declined, or more information needed.
- Document tasks should feel like TurboTax-style completion, not an admin queue leaking into the customer app.
- Billing and payment status need to be first-class: payment method, invoices, failed payment recovery, cancellation, renewal, and downloadable policy docs.

Recommended customer rebuild:

- `Home`: policy snapshot, claim snapshot, next action, pet cards.
- `Policies`: full policy detail, coverage, exclusions, documents, billing, cancellation.
- `Claims`: claim filing, draft recovery, claim timeline, payout status, explanation.
- `Pets`: pet profile, vet details, weight/history updates, uploaded records.
- `Tasks`: underwriting follow-ups, document requests, conflicting-info resolution.
- `Account`: profile, security, notification preferences, payment methods.

## Admin Operations Management

Relevant screens:

- `lib/screens/admin_console_screen.dart`
- `lib/admin_console/admin_scaffold.dart`
- `lib/admin_console/pages/admin_overview_page.dart`
- `lib/screens/admin/underwriting_cases_tab.dart`
- `lib/screens/admin/claims_review_tab.dart`
- `lib/screens/admin/claims_analytics_tab.dart`
- `lib/screens/admin/policies_pipeline_tab.dart`
- `lib/screens/admin/benchmarking_tab.dart`
- `lib/screens/admin_rules_editor_page.dart`
- `lib/admin/admin_product_catalog_page.dart`
- `lib/widgets/system_health_widget.dart`

What already works:

- The admin console has real operational breadth: overview, marketing, underwriting, claims, analytics, benchmarking, policies, rules/pricing, products, and system health.
- It has a persistent admin scaffold, left rail, global search placeholder, alerts placeholder, tasks placeholder, KPIs, and filtered queues.
- Underwriting cases include decided statuses: approved, approved with exclusions, and declined.
- The admin surface already thinks in terms of audit trail, rules, pricing, product catalog, and system monitoring.

Where it falls short against a world-class operations dashboard:

- The language still assumes manual operations. Labels like "review", "inbox", and "queue-based underwriting" conflict with the stated goal of 100% no-human-touch automation.
- Some high-value surfaces are scaffolded rather than operational: global search, alerts, tasks, operational alerts, and decision transparency panels.
- Admin design is enterprise-functional, but not yet at the same visual quality as the new website. It needs the same Clovara logo, typography direction, spacing discipline, and restrained color system.
- The underwriting console should distinguish automated final decisions from automation exceptions. Today, open/referred states can read like human work queues.
- Fraud and conflicting-information detection need a dedicated operational lens: signal severity, evidence, automated action taken, customer-facing outcome, and audit log.
- There is not yet a single no-touch health metric showing how many applications/claims completed without intervention, why any fell out, and whether the automation recovered.

World-class admin expectation:

- Admin should feel like a mission control system for automation, not a back-office manual review tool.
- The primary metric should be automation rate: quote-to-bind no-touch percentage, claim no-touch percentage, decline/exclusion automation success, false-positive rate, and automation fallout reasons.
- Every decision should have an immutable ledger: inputs, rules fired, AI extraction output, deterministic decision, fraud/conflict checks, customer disclosure, payment/bind result.
- Exceptions should be rare and categorized as system exceptions, not underwriting work: missing records, unreadable file, payment failure, identity mismatch, regulatory constraint, vendor outage.
- Admin needs safe controls: rule versioning, dry runs, rollback, approval gates for rule changes, and monitoring after deploy.

Recommended admin rebuild:

- `Command Center`: no-touch rate, bind rate, claims SLA, automation exceptions, revenue/premium, system health.
- `Decision Ledger`: searchable record of every quote, underwriting decision, exclusion, decline, and bind event.
- `Automation Exceptions`: only cases that automation could not complete, with clear reason and recovery path.
- `Fraud & Conflict Signals`: duplicate policies, inconsistent pet data, document tampering, invoice anomalies, impossible timelines.
- `Claims Ops`: claim status, payout automation, vendor/payment failures, denial/exclusion explanation quality.
- `Rules & Pricing`: versioned rules, pricing tables, rider eligibility, test cases, deploy history.
- `Products`: plans, riders, state availability, policy form versions, waiting periods, exclusions.
- `Audit & Compliance`: immutable event history, admin actions, disclosures, customer acknowledgements, policy documents.

## Integration status after this change

- The Next.js website now has a visible `Sign in` entry in the nav and footer.
- The sign-in target is `/app/sign-in`.
- The build copies the existing Flutter web bundle into `out/app` and patches its base href to `/app/`.
- Firebase Hosting rewrites `/app/**` to `/app/index.html`, allowing Flutter deep links such as `/app/sign-in`.

## Product recommendation

Keep this bridge short-lived. It is the right immediate recovery because it reconnects the existing authenticated system without rewriting it blindly. The next durable move should be a deliberate post-auth rebuild that keeps the proven Firebase/underwriting/claims logic but recreates the customer and admin surfaces in the current Clovara design language.

The strategic north star should be:

- Customer app: "I always know what is covered, what is happening, and what I need to do next."
- Admin app: "The platform runs itself, and I only see automation health, controls, and true exceptions."
