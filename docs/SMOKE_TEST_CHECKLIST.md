# Smoke Test Checklist (Web)

This is a fast end-to-end validation for the unauth quote → plan selection → checkout → bind flow, including the dynamic Product Catalog + Riders config.

## 0) Pre-check
- Ensure latest backend is deployed:
  - Firestore rules deployed (product catalog locked down; underwriting rules public-read).
  - Callable functions deployed:
    - `getProductCatalogPublic`
    - `getUnderwritingRulesPublic`

## 1) Admin config sanity (authenticated)
1. Sign in as an admin.
2. Go to **Admin → Products & Riders**.
3. Toggle at least one tier off and one add-on off.
4. Save and verify the UI shows the updated enabled/disabled state.

## 2) Unauthenticated quote flow respects config
1. Open a fresh **incognito/private** window (or sign out).
2. Start a new quote.
3. Continue until **Plan Selection**.
4. Verify:
   - Disabled tiers are not selectable / not shown.
   - Disabled add-ons are not selectable / not shown.

## 3) Checkout shows selected configuration (downstream persistence)
1. Select an enabled tier.
2. Choose a **reimbursement %**, **deductible**, and **annual limit** (including Unlimited if enabled).
3. Select at least one enabled add-on.
4. Proceed to checkout.
5. Verify in **Review** screen:
   - Plan summary includes reimbursement %, deductible, annual limit (Unlimited shown correctly), and chosen add-ons.
6. Verify in **Payment** screen:
   - Order Summary includes the same configuration details (not just plan name/premium).

## 4) Bind / Confirmation
1. Complete payment flow (using your current test method).
2. Verify the **Confirmation** screen shows the expected plan configuration.

## 5) Data persistence spot-check (optional)
In Firestore (console), locate the created policy/quote and confirm the persisted plan/config fields match:
- tier
- reimbursementPercent
- deductible
- annualLimit (Unlimited represented consistently)
- selected add-ons

## 6) Quick callable health-checks (optional)
- Hit `getProductCatalogPublic` and confirm it returns:
  - `enabled`
  - `enabledTiers` map
  - `enabledAddOns` map
- Hit `getUnderwritingRulesPublic` and confirm a valid rules payload.

---

### Known non-blockers
- `flutter analyze` still reports a backlog of info-level lints (mostly `avoid_print` and deprecated `withOpacity`).
