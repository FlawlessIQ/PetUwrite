import Link from "next/link";
import { MotionReveal } from "@/components/shared/MotionReveal";

const claims = [
  {
    icon: "🦴",
    title: "Knee surgery — Biscuit",
    date: "May 12",
    amount: "$3,200",
    status: "Paid ✓",
    paid: true
  },
  {
    icon: "💉",
    title: "Ear infection — Biscuit",
    date: "Apr 28",
    amount: "$180",
    status: "Paid ✓",
    paid: true
  },
  {
    icon: "🩻",
    title: "X-ray + lab work",
    date: "Today",
    amount: "$490",
    status: "In review",
    paid: false
  }
];

export function ClaimsExperience() {
  return (
    <section id="claims" className="bg-clv-sage-light py-20 md:py-28">
      <div className="mx-auto grid max-w-7xl gap-12 px-5 md:grid-cols-2 md:items-center md:px-8">
        <MotionReveal>
          <div>
            <p className="text-[11px] font-semibold uppercase tracking-[0.12em] text-clv-green">
              Claims experience
            </p>
            <h2 className="mt-3 font-display text-[28px] font-bold leading-tight tracking-[-0.02em] text-clv-charcoal md:text-[40px]">
              Claims shouldn&apos;t feel like a second job.
            </h2>
            <p className="mt-5 max-w-xl text-base leading-[1.75] text-clv-gray">
              Take a photo of your vet bill. Upload it in the app. That&apos;s
              it. We handle the rest and keep you updated the whole way.
            </p>
            <div className="mt-6 inline-flex rounded-[99px] bg-clv-green px-4 py-2 text-sm font-semibold text-white">
              Average 2-day payout
            </div>
            <div className="mt-8">
              <Link
                href="/how-it-works"
                className="inline-flex rounded-md border border-clv-gray-light px-7 py-[13px] text-sm font-semibold tracking-[0.02em] text-clv-gray transition-colors hover:border-clv-green hover:text-clv-green"
              >
                See how claims work →
              </Link>
            </div>
          </div>
        </MotionReveal>
        <MotionReveal delay={0.1}>
          <div className="mx-auto max-w-[320px] rounded-2xl border border-clv-gray-border bg-white p-5">
            <div className="mb-5 flex items-center justify-between">
              <p className="text-xs font-semibold uppercase tracking-[0.08em] text-clv-gray">
                Your claims
              </p>
              <button
                type="button"
                className="rounded bg-clv-green px-3 py-2 text-xs font-semibold text-white"
              >
                File new claim
              </button>
            </div>
            <div>
              {claims.map((claim, index) => (
                <div
                  key={claim.title}
                  className={`flex items-center gap-3 py-4 ${
                    index !== claims.length - 1
                      ? "border-b border-clv-gray-border"
                      : ""
                  }`}
                >
                  <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-clv-sage-light text-lg">
                    {claim.icon}
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-semibold text-clv-charcoal">
                      {claim.title}
                    </p>
                    <p className="text-xs text-clv-gray">{claim.date}</p>
                  </div>
                  <div className="text-right">
                    <p className="text-sm font-semibold text-clv-charcoal">
                      {claim.amount}
                    </p>
                    <span
                      className={`mt-1 inline-flex rounded-[99px] px-2 py-1 text-[10px] font-semibold ${
                        claim.paid
                          ? "bg-clv-sage-light text-clv-green"
                          : "bg-clv-amber-light text-clv-amber"
                      }`}
                    >
                      {claim.status}
                    </span>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </MotionReveal>
      </div>
    </section>
  );
}
