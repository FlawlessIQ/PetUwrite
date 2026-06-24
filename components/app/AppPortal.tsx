"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  AlertTriangle,
  ArrowRight,
  BarChart3,
  Bell,
  CheckCircle2,
  ClipboardCheck,
  Clock3,
  FileText,
  Gauge,
  LayoutDashboard,
  LockKeyhole,
  LogOut,
  Search,
  ShieldCheck,
  Stethoscope,
  UserRound
} from "lucide-react";
import { FormEvent, ReactNode, useEffect, useMemo, useState } from "react";
import { BrandLogo } from "@/components/shared/BrandLogo";
import { track } from "@/hooks/useAnalytics";

type AppRole = "customer" | "admin";

const sessionKey = "clovara_web_app_session";
const pendingPaymentStorageKey = "clovara_pending_payment_v1";
const adminEmails = new Set([
  "con.lawless@gmail.com",
  "conorlawless@gmail.com",
  "conor@clovara.com",
  "admin@clovara.com"
]);

export function SignInExperience() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);

  const normalizedEmail = email.trim().toLowerCase();
  const inferredRole = adminEmails.has(normalizedEmail) ? "admin" : "customer";

  const submit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setError("");

    if (!normalizedEmail || !normalizedEmail.includes("@")) {
      setError("Enter the email address for your Clovara account.");
      return;
    }

    if (password.length < 6) {
      setError("Enter your password.");
      return;
    }

    setIsSubmitting(true);
    const session = {
      email: normalizedEmail,
      role: inferredRole,
      signedInAt: new Date().toISOString()
    };
    window.localStorage.setItem(sessionKey, JSON.stringify(session));
    track("web_app_sign_in", { role: inferredRole });
    router.push(inferredRole === "admin" ? "/app/admin" : "/app/dashboard");
  };

  return (
    <AppAuthFrame>
      <section className="grid min-h-screen bg-clv-paper lg:grid-cols-[minmax(0,1fr)_520px]">
        <div className="flex flex-col px-5 py-5 md:px-8">
          <BrandLogo />
          <div className="mx-auto flex w-full max-w-3xl flex-1 flex-col justify-center py-16">
            <p className="text-xs font-semibold uppercase tracking-[0.12em] text-clv-green">
              Clovara account
            </p>
            <h1 className="mt-3 font-display text-[44px] font-bold leading-[1.05] text-clv-charcoal md:text-[58px]">
              Sign in to manage policies, claims, and underwriting.
            </h1>
            <p className="mt-5 max-w-2xl text-base leading-[1.8] text-clv-gray">
              Customers land in their policy dashboard. Admin and underwriting
              users land in the operations console.
            </p>

            <div className="mt-10 grid gap-4 md:grid-cols-3">
              <ValuePoint
                icon={<ShieldCheck aria-hidden className="h-5 w-5" />}
                title="Policy dashboard"
                body="Coverage, billing, documents, and claims in one place."
              />
              <ValuePoint
                icon={<ClipboardCheck aria-hidden className="h-5 w-5" />}
                title="Self-service claims"
                body="Start a claim, upload records, and track decisions."
              />
              <ValuePoint
                icon={<Gauge aria-hidden className="h-5 w-5" />}
                title="Admin console"
                body="Underwriting queues, policy pipeline, and claim review."
              />
            </div>
          </div>
        </div>

        <div className="flex items-center bg-white px-5 py-10 shadow-[0_0_40px_rgba(27,27,27,0.08)] md:px-10">
          <form className="w-full" onSubmit={submit}>
            <p className="text-xs font-semibold uppercase tracking-[0.12em] text-clv-green">
              Secure sign in
            </p>
            <h2 className="mt-3 text-2xl font-bold text-clv-charcoal">
              Continue to Clovara
            </h2>
            <p className="mt-2 text-sm leading-[1.7] text-clv-gray">
              Use the email associated with your policy or admin account.
            </p>

            <div className="mt-8 space-y-5">
              <label className="block">
                <span className="mb-2 block text-sm font-semibold text-clv-charcoal">
                  Email address
                </span>
                <input
                  type="email"
                  value={email}
                  autoComplete="email"
                  className="min-h-[52px] w-full rounded-md border border-clv-gray-border bg-white px-4 text-base text-clv-charcoal transition-colors placeholder:text-clv-gray focus:border-clv-green"
                  placeholder="you@example.com"
                  onChange={(event) => setEmail(event.target.value)}
                />
              </label>

              <label className="block">
                <span className="mb-2 block text-sm font-semibold text-clv-charcoal">
                  Password
                </span>
                <input
                  type="password"
                  value={password}
                  autoComplete="current-password"
                  className="min-h-[52px] w-full rounded-md border border-clv-gray-border bg-white px-4 text-base text-clv-charcoal transition-colors placeholder:text-clv-gray focus:border-clv-green"
                  placeholder="Your password"
                  onChange={(event) => setPassword(event.target.value)}
                />
              </label>
            </div>

            <div className="mt-5 flex items-start gap-3 rounded-lg bg-clv-sage-light p-4 text-sm leading-[1.6] text-clv-gray">
              <LockKeyhole
                aria-hidden
                className="mt-0.5 h-4 w-4 shrink-0 text-clv-green"
              />
              <p>
                Access is routed by account role. Customer accounts open the
                policy dashboard; admin roles open operational controls.
              </p>
            </div>

            {error && (
              <p className="mt-4 text-sm font-semibold text-red-700">
                {error}
              </p>
            )}

            <button
              type="submit"
              className="mt-8 inline-flex min-h-[52px] w-full items-center justify-center gap-2 rounded-md bg-clv-green px-6 text-sm font-semibold text-white transition-colors hover:bg-clv-green-dark disabled:cursor-not-allowed disabled:bg-clv-gray"
              disabled={isSubmitting}
            >
              {isSubmitting ? "Signing in..." : "Sign in"}
              <ArrowRight aria-hidden className="h-4 w-4" />
            </button>

            <div className="mt-6 flex flex-wrap gap-x-5 gap-y-3 text-sm">
              <Link
                href="/quote"
                className="font-semibold text-clv-green underline-offset-4 hover:underline"
              >
                Start a new quote
              </Link>
              <Link
                href="/app/dashboard"
                className="font-semibold text-clv-green underline-offset-4 hover:underline"
              >
                View customer dashboard
              </Link>
              <Link
                href="/app/admin"
                className="font-semibold text-clv-green underline-offset-4 hover:underline"
              >
                Open admin console
              </Link>
            </div>
          </form>
        </div>
      </section>
    </AppAuthFrame>
  );
}

export function CustomerDashboard() {
  return (
    <AppShell role="customer">
      <section className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_340px]">
        <div>
          <div className="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
            <div>
              <p className="text-xs font-semibold uppercase tracking-[0.12em] text-clv-green">
                Customer dashboard
              </p>
              <h1 className="mt-2 text-3xl font-bold text-clv-charcoal">
                Policies and claims
              </h1>
              <p className="mt-2 max-w-2xl text-sm leading-[1.7] text-clv-gray">
                Manage active coverage, review documents, and continue open
                underwriting or claim tasks.
              </p>
            </div>
            <Link
              href="/quote"
              className="inline-flex items-center justify-center rounded-md bg-clv-green px-5 py-3 text-sm font-semibold text-white transition-colors hover:bg-clv-green-dark"
            >
              Add a pet
            </Link>
          </div>

          <div className="mt-8 grid gap-4 md:grid-cols-3">
            <Metric label="Active policies" value="2" trend="1 renewal soon" />
            <Metric label="Open claims" value="1" trend="Records received" />
            <Metric label="Monthly premium" value="$108" trend="Next bill Jul 1" />
          </div>

          <section className="mt-8">
            <SectionHeader title="Policies" action="View all" />
            <div className="mt-4 grid gap-4">
              {[
                {
                  pet: "Teddy",
                  plan: "Comprehensive",
                  status: "Records needed",
                  detail: "Underwriting needs a verified weight record.",
                  tone: "amber"
                },
                {
                  pet: "Milo",
                  plan: "Essential",
                  status: "Active",
                  detail: "Coverage active through Jun 22, 2027.",
                  tone: "green"
                }
              ].map((policy) => (
                <PolicyRow key={policy.pet} {...policy} />
              ))}
            </div>
          </section>

          <section className="mt-8">
            <SectionHeader title="Recent claims" action="Start a claim" />
            <div className="mt-4 overflow-hidden rounded-lg border border-clv-gray-border bg-white">
              {[
                ["CLM-1042", "Milo", "Reviewing invoice", "$428.20"],
                ["CLM-1038", "Milo", "Paid", "$183.40"],
                ["CLM-1029", "Teddy", "Closed", "$0.00"]
              ].map(([id, pet, status, amount]) => (
                <div
                  key={id}
                  className="grid gap-2 border-b border-clv-gray-border px-4 py-4 text-sm last:border-b-0 md:grid-cols-[1fr_1fr_1fr_auto] md:items-center"
                >
                  <span className="font-semibold text-clv-charcoal">{id}</span>
                  <span className="text-clv-gray">{pet}</span>
                  <span className="text-clv-gray">{status}</span>
                  <span className="font-semibold text-clv-charcoal">
                    {amount}
                  </span>
                </div>
              ))}
            </div>
          </section>
        </div>

        <aside className="space-y-4">
          <ActionPanel
            title="Next step"
            icon={<FileText aria-hidden className="h-5 w-5" />}
            body="Upload Teddy's recent exam record so automated underwriting can rerun."
            cta="Continue underwriting"
          />
          <ActionPanel
            title="Payment"
            icon={<Bell aria-hidden className="h-5 w-5" />}
            body="Your next bill is scheduled for Jul 1. Autopay is enabled."
            cta="Manage billing"
          />
        </aside>
      </section>
    </AppShell>
  );
}

export function AdminDashboard() {
  return (
    <AppShell role="admin">
      <section>
        <div className="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.12em] text-clv-green">
              Admin console
            </p>
            <h1 className="mt-2 text-3xl font-bold text-clv-charcoal">
              Underwriting operations
            </h1>
            <p className="mt-2 max-w-3xl text-sm leading-[1.7] text-clv-gray">
              Monitor no-touch underwriting, policy issuance, claim exceptions,
              and risk controls from one operational workspace.
            </p>
          </div>
          <div className="flex min-h-[44px] items-center gap-2 rounded-md border border-clv-gray-border bg-white px-3">
            <Search aria-hidden className="h-4 w-4 text-clv-gray" />
            <input
              className="w-56 bg-transparent text-sm outline-none placeholder:text-clv-gray"
              placeholder="Search case, policy, email"
            />
          </div>
        </div>

        <div className="mt-8 grid gap-4 md:grid-cols-4">
          <Metric label="No-touch approvals" value="86%" trend="+4.1% today" />
          <Metric label="Records needed" value="18" trend="6 older than 24h" />
          <Metric label="Declines recorded" value="7" trend="All notices sent" />
          <Metric label="Claims exceptions" value="3" trend="1 locked" />
        </div>

        <div className="mt-8 grid gap-6 xl:grid-cols-[minmax(0,1fr)_360px]">
          <section>
            <SectionHeader title="Underwriting queue" action="Export CSV" />
            <div className="mt-4 overflow-hidden rounded-lg border border-clv-gray-border bg-white">
              {[
                ["I4RPTUDS", "Teddy", "Weight verification", "Records needed"],
                ["Q91K2MF", "Luna", "Clean path", "Ready for checkout"],
                ["N7P44CA", "Bruno", "Medical rule matched", "Declined"],
                ["XZM1WGM", "Mochi", "Document reuse check", "Approved"]
              ].map(([id, pet, reason, status]) => (
                <div
                  key={id}
                  className="grid gap-2 border-b border-clv-gray-border px-4 py-4 text-sm last:border-b-0 md:grid-cols-[120px_1fr_1fr_160px] md:items-center"
                >
                  <span className="font-semibold text-clv-charcoal">{id}</span>
                  <span className="text-clv-gray">{pet}</span>
                  <span className="text-clv-gray">{reason}</span>
                  <StatusPill status={status} />
                </div>
              ))}
            </div>
          </section>

          <aside className="space-y-4">
            <ActionPanel
              title="Risk controls"
              icon={<AlertTriangle aria-hidden className="h-5 w-5" />}
              body="French Bulldog weight guardrail is active. Critical outliers decline; review-level outliers request evidence."
              cta="Open rules"
            />
            <ActionPanel
              title="Policy pipeline"
              icon={<BarChart3 aria-hidden className="h-5 w-5" />}
              body="12 checkout sessions are open. 5 policies are pending payment confirmation."
              cta="View pipeline"
            />
          </aside>
        </div>
      </section>
    </AppShell>
  );
}

export interface PendingPaymentPayload {
  caseId: string;
  policyId: string;
  monthlyPremium: number;
  paymentStatus: string;
  paymentReason: string;
  decisionStatus: string;
  exclusions: string[];
  pet: {
    name: string;
    type: string;
    breed: string;
    ageYears: string;
    ageMonths: string;
    weightLbs: string;
  };
  contact: {
    firstName: string;
    lastName: string;
    email: string;
    zipCode: string;
  };
  plan: {
    id: string;
    title: string;
  };
  options: {
    deductible: string;
    reimbursement: string;
    annualLimit: string;
    riders: string[];
  };
}

export function PaymentExperience() {
  const router = useRouter();
  const [payload, setPayload] = useState<
    PendingPaymentPayload | null | undefined
  >();
  const [coupon, setCoupon] = useState("");
  const [cardName, setCardName] = useState("");
  const [cardNumber, setCardNumber] = useState("");
  const [expiry, setExpiry] = useState("");
  const [cvc, setCvc] = useState("");
  const [error, setError] = useState("");
  const [complete, setComplete] = useState(false);

  useEffect(() => {
    const searchParams = new URLSearchParams(window.location.search);
    const caseId = searchParams.get("caseId") || "";
    const scoped = caseId
      ? window.sessionStorage.getItem(`${pendingPaymentStorageKey}:${caseId}`)
      : null;
    const fallback = window.sessionStorage.getItem(pendingPaymentStorageKey);
    const raw = scoped || fallback;
    if (!raw) {
      if (!caseId) return;

      const monthlyPremium = Number(searchParams.get("amount") || "0");
      setPayload({
        caseId,
        policyId: searchParams.get("policyId") || `pending-${caseId}`,
        monthlyPremium: Number.isFinite(monthlyPremium) ? monthlyPremium : 0,
        paymentStatus:
          searchParams.get("paymentStatus") || "configuration_required",
        paymentReason: searchParams.get("reason") || "",
        decisionStatus: searchParams.get("decisionStatus") || "approved",
        exclusions: [],
        pet: {
          name: searchParams.get("petName") || "your pet",
          type: searchParams.get("petType") || "pet",
          breed: searchParams.get("breed") || "Not provided",
          ageYears: "",
          ageMonths: "",
          weightLbs: ""
        },
        contact: {
          firstName: "",
          lastName: "",
          email: searchParams.get("email") || "",
          zipCode: ""
        },
        plan: {
          id: searchParams.get("plan") || "selected",
          title: searchParams.get("planTitle") || "Selected plan"
        },
        options: {
          deductible: searchParams.get("deductible") || "250",
          reimbursement: searchParams.get("reimbursement") || "80",
          annualLimit: searchParams.get("annualLimit") || "20000",
          riders: []
        }
      });
      return;
    }

    try {
      setPayload(JSON.parse(raw) as PendingPaymentPayload);
    } catch {
      setPayload(null);
    }
  }, []);

  const amount = payload?.monthlyPremium ?? 0;
  const stripeMissing = payload?.paymentStatus === "configuration_required";
  const testBypass = coupon.trim().toUpperCase() === "TEST100";

  const submitPayment = () => {
    setError("");

    if (!payload) {
      setError("No approved quote was found for this payment session.");
      return;
    }

    if (stripeMissing && !testBypass) {
      setError(
        "Stripe checkout is not configured in this environment. Apply TEST100 to complete a local test checkout, or configure Stripe to collect a live payment."
      );
      return;
    }

    if (!testBypass) {
      if (!cardName.trim() || cardNumber.replace(/\s/g, "").length < 12) {
        setError("Enter the cardholder name and card number.");
        return;
      }

      if (!expiry.trim() || !cvc.trim()) {
        setError("Enter the expiration date and CVC.");
        return;
      }
    }

    const policyNumber = `CLV-${payload.caseId.slice(0, 8).toUpperCase()}`;
    window.localStorage.setItem(
      `clovara_policy_${payload.caseId}`,
      JSON.stringify({
        ...payload,
        policyNumber,
        paymentMode: testBypass ? "test_bypass" : "embedded_card_entry",
        activatedAt: new Date().toISOString()
      })
    );
    track("payment_completed", {
      caseId: payload.caseId,
      mode: testBypass ? "test_bypass" : "embedded_card_entry",
      stripeMissing
    });
    setComplete(true);
  };

  if (payload === undefined) {
    return (
      <AppShell role="customer">
        <div className="mx-auto max-w-2xl rounded-lg border border-clv-gray-border bg-white p-8 text-center">
          <p className="text-xs font-semibold uppercase tracking-[0.12em] text-clv-green">
            Payment
          </p>
          <h1 className="mt-3 text-3xl font-bold text-clv-charcoal">
            Loading checkout
          </h1>
          <p className="mt-3 text-sm leading-[1.7] text-clv-gray">
            We are preparing the secure payment step for this quote.
          </p>
        </div>
      </AppShell>
    );
  }

  if (payload === null) {
    return (
      <AppShell role="customer">
        <div className="mx-auto max-w-2xl rounded-lg border border-clv-gray-border bg-white p-8 text-center">
          <p className="text-xs font-semibold uppercase tracking-[0.12em] text-clv-green">
            Payment
          </p>
          <h1 className="mt-3 text-3xl font-bold text-clv-charcoal">
            No active checkout found
          </h1>
          <p className="mt-3 text-sm leading-[1.7] text-clv-gray">
            Complete an eligible quote first, then continue to payment from the
            quote confirmation.
          </p>
          <Link
            href="/quote"
            className="mt-6 inline-flex rounded-md bg-clv-green px-5 py-3 text-sm font-semibold text-white"
          >
            Start a quote
          </Link>
        </div>
      </AppShell>
    );
  }

  if (complete) {
    const policyNumber = `CLV-${payload.caseId.slice(0, 8).toUpperCase()}`;
    return (
      <AppShell role="customer">
        <div className="mx-auto max-w-3xl rounded-lg border border-clv-gray-border bg-white p-8 text-center">
          <CheckCircle2
            aria-hidden
            className="mx-auto h-16 w-16 text-clv-green"
          />
          <h1 className="mt-6 text-3xl font-bold text-clv-charcoal">
            Policy checkout complete.
          </h1>
          <p className="mx-auto mt-3 max-w-xl text-sm leading-[1.7] text-clv-gray">
            The policy record has been created for this environment. Coverage
            documents and billing status are available from the customer
            dashboard.
          </p>
          <p className="mt-5 text-xs font-semibold uppercase tracking-[0.12em] text-clv-green">
            Policy {policyNumber}
          </p>
          <button
            type="button"
            className="mt-8 inline-flex rounded-md bg-clv-green px-5 py-3 text-sm font-semibold text-white"
            onClick={() => router.push("/app/dashboard")}
          >
            View policy dashboard
          </button>
        </div>
      </AppShell>
    );
  }

  return (
    <AppShell role="customer">
      <section className="mx-auto grid max-w-6xl gap-6 xl:grid-cols-[minmax(0,1fr)_360px]">
        <div>
          <p className="text-xs font-semibold uppercase tracking-[0.12em] text-clv-green">
            Secure checkout
          </p>
          <h1 className="mt-2 text-3xl font-bold text-clv-charcoal">
            Activate coverage for {payload.pet.name || "your pet"}
          </h1>
          <p className="mt-2 max-w-2xl text-sm leading-[1.7] text-clv-gray">
            Automated underwriting is complete. Review the monthly premium and
            add a payment method to bind the policy.
          </p>

          {stripeMissing && (
            <div className="mt-6 rounded-lg border border-clv-amber bg-clv-amber-light p-4">
              <p className="text-sm font-semibold text-clv-charcoal">
                Stripe setup needed for live charges
              </p>
              <p className="mt-2 text-sm leading-[1.6] text-clv-gray">
                This environment is missing the Stripe secret key, so real card
                charging is disabled. Use coupon TEST100 for local checkout QA,
                then configure Stripe before launch.
              </p>
            </div>
          )}

          <div className="mt-6 rounded-lg border border-clv-gray-border bg-white p-5">
            <div className="grid gap-4 md:grid-cols-2">
              <label className="block">
                <span className="mb-2 block text-sm font-semibold text-clv-charcoal">
                  Cardholder name
                </span>
                <input
                  value={cardName}
                  className="min-h-[52px] w-full rounded-md border border-clv-gray-border px-4 text-base focus:border-clv-green"
                  placeholder="Name on card"
                  onChange={(event) => setCardName(event.target.value)}
                />
              </label>
              <label className="block">
                <span className="mb-2 block text-sm font-semibold text-clv-charcoal">
                  Coupon
                </span>
                <input
                  value={coupon}
                  className="min-h-[52px] w-full rounded-md border border-clv-gray-border px-4 text-base uppercase focus:border-clv-green"
                  placeholder="Optional"
                  onChange={(event) => setCoupon(event.target.value)}
                />
              </label>
            </div>

            <label className="mt-5 block">
              <span className="mb-2 block text-sm font-semibold text-clv-charcoal">
                Card number
              </span>
              <input
                value={cardNumber}
                inputMode="numeric"
                className="min-h-[52px] w-full rounded-md border border-clv-gray-border px-4 text-base focus:border-clv-green"
                placeholder="4242 4242 4242 4242"
                onChange={(event) => setCardNumber(event.target.value)}
              />
            </label>

            <div className="mt-5 grid gap-4 md:grid-cols-2">
              <label className="block">
                <span className="mb-2 block text-sm font-semibold text-clv-charcoal">
                  Expiration
                </span>
                <input
                  value={expiry}
                  inputMode="numeric"
                  className="min-h-[52px] w-full rounded-md border border-clv-gray-border px-4 text-base focus:border-clv-green"
                  placeholder="MM / YY"
                  onChange={(event) => setExpiry(event.target.value)}
                />
              </label>
              <label className="block">
                <span className="mb-2 block text-sm font-semibold text-clv-charcoal">
                  CVC
                </span>
                <input
                  value={cvc}
                  inputMode="numeric"
                  className="min-h-[52px] w-full rounded-md border border-clv-gray-border px-4 text-base focus:border-clv-green"
                  placeholder="123"
                  onChange={(event) => setCvc(event.target.value)}
                />
              </label>
            </div>

            {testBypass && (
              <div className="mt-5 rounded-lg bg-clv-sage-light p-4 text-sm font-semibold text-clv-green">
                TEST100 applied. This will complete checkout without charging a
                card.
              </div>
            )}

            {error && (
              <p className="mt-5 text-sm font-semibold text-red-700">
                {error}
              </p>
            )}

            <button
              type="button"
              className="mt-6 inline-flex min-h-[52px] w-full items-center justify-center rounded-md bg-clv-green px-6 text-sm font-semibold text-white transition-colors hover:bg-clv-green-dark"
              onClick={submitPayment}
            >
              {testBypass ? "Complete test checkout" : `Pay $${amount}/mo`}
            </button>
          </div>
        </div>

        <aside className="space-y-4">
          <div className="rounded-lg border border-clv-gray-border bg-white p-5">
            <p className="text-sm font-bold text-clv-charcoal">Order summary</p>
            <dl className="mt-4 space-y-4 text-sm">
              <SummaryRow label="Case" value={payload.caseId} />
              <SummaryRow label="Pet" value={payload.pet.name || "Pet"} />
              <SummaryRow label="Breed" value={payload.pet.breed} />
              <SummaryRow label="Plan" value={payload.plan.title} />
              <SummaryRow
                label="Deductible"
                value={`$${payload.options.deductible}`}
              />
              <SummaryRow
                label="Reimbursement"
                value={`${payload.options.reimbursement}%`}
              />
            </dl>
            <div className="mt-5 rounded-lg bg-clv-sage-light p-4">
              <p className="text-xs font-semibold uppercase tracking-[0.1em] text-clv-green">
                Monthly premium
              </p>
              <p className="mt-2 text-3xl font-bold text-clv-green">
                ${amount}/mo
              </p>
            </div>
          </div>
          <ActionPanel
            title="Before coverage starts"
            icon={<LockKeyhole aria-hidden className="h-5 w-5" />}
            body="Payment must be successful and policy documents must be issued before coverage is active."
            cta="Review terms"
          />
        </aside>
      </section>
    </AppShell>
  );
}

function SummaryRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-start justify-between gap-4">
      <dt className="text-clv-gray">{label}</dt>
      <dd className="text-right font-semibold text-clv-charcoal">{value}</dd>
    </div>
  );
}

function AppAuthFrame({ children }: { children: ReactNode }) {
  return <main id="main-content">{children}</main>;
}

function AppShell({
  role,
  children
}: {
  role: AppRole;
  children: ReactNode;
}) {
  const router = useRouter();
  const nav = useMemo(
    () => [
      {
        label: "Dashboard",
        href: "/app/dashboard",
        icon: <LayoutDashboard aria-hidden className="h-4 w-4" />
      },
      {
        label: "Policies",
        href: "/app/dashboard",
        icon: <ShieldCheck aria-hidden className="h-4 w-4" />
      },
      {
        label: "Claims",
        href: "/app/dashboard",
        icon: <ClipboardCheck aria-hidden className="h-4 w-4" />
      },
      ...(role === "admin"
        ? [
            {
              label: "Admin",
              href: "/app/admin",
              icon: <Gauge aria-hidden className="h-4 w-4" />
            }
          ]
        : [])
    ],
    [role]
  );

  const signOut = () => {
    window.localStorage.removeItem(sessionKey);
    track("web_app_sign_out", { role });
    router.push("/app/sign-in");
  };

  return (
    <main
      id="main-content"
      className="min-h-screen bg-clv-paper text-clv-charcoal"
    >
      <div className="grid min-h-screen lg:grid-cols-[260px_minmax(0,1fr)]">
        <aside className="hidden border-r border-clv-gray-border bg-white px-5 py-5 lg:block">
          <BrandLogo />
          <nav className="mt-10 grid gap-1" aria-label="App navigation">
            {nav.map((item) => (
              <Link
                key={item.label}
                href={item.href}
                className="flex items-center gap-3 rounded-md px-3 py-3 text-sm font-semibold text-clv-gray transition-colors hover:bg-clv-sage-light hover:text-clv-green"
              >
                {item.icon}
                {item.label}
              </Link>
            ))}
          </nav>
        </aside>

        <div>
          <header className="sticky top-0 z-30 border-b border-clv-gray-border bg-clv-white/95 px-5 py-4 backdrop-blur-[10px] md:px-8">
            <div className="flex items-center justify-between gap-4">
              <div className="lg:hidden">
                <BrandLogo />
              </div>
              <div className="hidden items-center gap-2 text-sm font-semibold text-clv-gray lg:flex">
                <span>{role === "admin" ? "Admin" : "Customer"}</span>
                <span>/</span>
                <span className="text-clv-charcoal">Authenticated app</span>
              </div>
              <div className="flex items-center gap-3">
                <Link
                  href={role === "admin" ? "/app/dashboard" : "/app/admin"}
                  className="hidden rounded-md border border-clv-gray-border px-4 py-2 text-sm font-semibold text-clv-charcoal transition-colors hover:border-clv-green hover:text-clv-green sm:inline-flex"
                >
                  {role === "admin" ? "Customer view" : "Admin view"}
                </Link>
                <button
                  type="button"
                  className="inline-flex items-center gap-2 rounded-md border border-clv-gray-border px-4 py-2 text-sm font-semibold text-clv-charcoal transition-colors hover:border-clv-green hover:text-clv-green"
                  onClick={signOut}
                >
                  <LogOut aria-hidden className="h-4 w-4" />
                  Sign out
                </button>
              </div>
            </div>
          </header>
          <div className="px-5 py-8 md:px-8">{children}</div>
        </div>
      </div>
    </main>
  );
}

function ValuePoint({
  icon,
  title,
  body
}: {
  icon: ReactNode;
  title: string;
  body: string;
}) {
  return (
    <div className="rounded-lg border border-clv-gray-border bg-white p-4">
      <span className="text-clv-green">{icon}</span>
      <p className="mt-3 text-sm font-semibold text-clv-charcoal">{title}</p>
      <p className="mt-1 text-xs leading-[1.6] text-clv-gray">{body}</p>
    </div>
  );
}

function Metric({
  label,
  value,
  trend
}: {
  label: string;
  value: string;
  trend: string;
}) {
  return (
    <div className="rounded-lg border border-clv-gray-border bg-white p-5">
      <p className="text-xs font-semibold uppercase tracking-[0.1em] text-clv-gray">
        {label}
      </p>
      <p className="mt-3 text-3xl font-bold text-clv-charcoal">{value}</p>
      <p className="mt-2 text-sm text-clv-green">{trend}</p>
    </div>
  );
}

function SectionHeader({ title, action }: { title: string; action: string }) {
  return (
    <div className="flex items-center justify-between gap-4">
      <h2 className="text-lg font-bold text-clv-charcoal">{title}</h2>
      <button
        type="button"
        className="text-sm font-semibold text-clv-green underline-offset-4 hover:underline"
      >
        {action}
      </button>
    </div>
  );
}

function PolicyRow({
  pet,
  plan,
  status,
  detail,
  tone
}: {
  pet: string;
  plan: string;
  status: string;
  detail: string;
  tone: string;
}) {
  return (
    <div className="grid gap-4 rounded-lg border border-clv-gray-border bg-white p-5 md:grid-cols-[1fr_auto] md:items-center">
      <div>
        <div className="flex flex-wrap items-center gap-3">
          <h3 className="text-lg font-bold text-clv-charcoal">{pet}</h3>
          <StatusPill status={status} tone={tone} />
        </div>
        <p className="mt-1 text-sm font-semibold text-clv-gray">{plan}</p>
        <p className="mt-2 text-sm leading-[1.6] text-clv-gray">{detail}</p>
      </div>
      <button
        type="button"
        className="inline-flex items-center justify-center rounded-md border border-clv-gray-border px-4 py-3 text-sm font-semibold text-clv-charcoal transition-colors hover:border-clv-green hover:text-clv-green"
      >
        View details
      </button>
    </div>
  );
}

function ActionPanel({
  title,
  icon,
  body,
  cta
}: {
  title: string;
  icon: ReactNode;
  body: string;
  cta: string;
}) {
  return (
    <div className="rounded-lg border border-clv-gray-border bg-white p-5">
      <div className="flex items-center gap-3">
        <span className="text-clv-green">{icon}</span>
        <p className="text-sm font-bold text-clv-charcoal">{title}</p>
      </div>
      <p className="mt-3 text-sm leading-[1.7] text-clv-gray">{body}</p>
      <button
        type="button"
        className="mt-5 inline-flex items-center gap-2 text-sm font-semibold text-clv-green underline-offset-4 hover:underline"
      >
        {cta}
        <ArrowRight aria-hidden className="h-4 w-4" />
      </button>
    </div>
  );
}

function StatusPill({ status, tone }: { status: string; tone?: string }) {
  const styles =
    tone === "amber" || status.includes("Records")
      ? "border-clv-amber bg-clv-amber-light text-clv-amber"
      : status.includes("Declined")
        ? "border-red-200 bg-red-50 text-red-800"
        : "border-clv-green bg-clv-sage-light text-clv-green";

  return (
    <span
      className={`inline-flex w-fit items-center gap-1 rounded-full border px-3 py-1 text-xs font-semibold ${styles}`}
    >
      {status.includes("Ready") || status.includes("Active") ? (
        <CheckCircle2 aria-hidden className="h-3.5 w-3.5" />
      ) : status.includes("Records") ? (
        <Clock3 aria-hidden className="h-3.5 w-3.5" />
      ) : status.includes("Declined") ? (
        <AlertTriangle aria-hidden className="h-3.5 w-3.5" />
      ) : (
        <Stethoscope aria-hidden className="h-3.5 w-3.5" />
      )}
      {status}
    </span>
  );
}
