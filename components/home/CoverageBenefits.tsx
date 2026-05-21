import Link from "next/link";
import { HeartCareIcon, PillIcon, ShieldIcon } from "./BenefitIcons";
import { MotionReveal } from "@/components/shared/MotionReveal";
import { SectionHeading } from "@/components/shared/SectionHeading";

const cards = [
  {
    title: "Accident & illness",
    body: "Surgery, cancer, broken bones, infections — covered. No arbitrary breed exclusions.",
    link: "See what's included →",
    href: "/coverage",
    icon: ShieldIcon
  },
  {
    title: "Prescriptions & specialists",
    body: "Ongoing medications and specialist referrals included. Not charged as add-ons.",
    link: "See what's included →",
    href: "/coverage",
    icon: PillIcon,
    featured: true
  },
  {
    title: "Wellness add-on",
    body: "Annual checkups, vaccines, flea prevention. Available on any plan.",
    link: "Add to my plan →",
    href: "/coverage",
    icon: HeartCareIcon
  }
];

export function CoverageBenefits() {
  return (
    <section className="bg-clv-white py-20 md:py-28">
      <div className="mx-auto max-w-7xl px-5 md:px-8">
        <MotionReveal>
          <SectionHeading
            centered
            eyebrow="Why Clovara"
            title="Everything your pet needs. Nothing you don't."
            body="Choose from three plan tiers. Every plan covers accidents and illness. Add wellness care anytime."
          />
        </MotionReveal>
        <div className="mt-12 grid gap-5 md:grid-cols-3">
          {cards.map((card, index) => {
            const Icon = card.icon;
            return (
              <MotionReveal key={card.title} delay={index * 0.08}>
                <article
                  className={`relative h-full rounded-xl border bg-white p-6 transition-all duration-200 hover:border-clv-green hover:shadow-[0_4px_16px_rgba(0,0,0,0.06)] ${
                    card.featured
                      ? "border-[1.5px] border-clv-green"
                      : "border-clv-gray-border"
                  }`}
                >
                  {card.featured ? (
                    <span className="absolute -top-4 left-6 rounded bg-clv-green px-3 py-1 text-[11px] font-semibold text-white">
                      Most popular
                    </span>
                  ) : null}
                  <Icon />
                  <h3 className="mt-6 text-base font-semibold text-clv-charcoal">
                    {card.title}
                  </h3>
                  <p className="mt-3 text-base leading-[1.75] text-clv-gray">
                    {card.body}
                  </p>
                  <Link
                    href={card.href}
                    className="mt-6 inline-flex text-sm font-semibold text-clv-green underline-offset-4 hover:underline"
                  >
                    {card.link}
                  </Link>
                </article>
              </MotionReveal>
            );
          })}
        </div>
      </div>
    </section>
  );
}
