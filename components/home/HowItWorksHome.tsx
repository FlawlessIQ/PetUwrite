import { howItWorksSteps } from "@/data/site";
import { MotionReveal } from "@/components/shared/MotionReveal";
import { SectionHeading } from "@/components/shared/SectionHeading";

export function HowItWorksHome() {
  return (
    <section className="bg-clv-green-dark py-20 md:py-28">
      <div className="mx-auto max-w-7xl px-5 md:px-8">
        <MotionReveal>
          <SectionHeading
            dark
            centered
            eyebrow="How it works"
            title="Coverage in under 5 minutes."
            body="No vet appointment needed. No long forms. Just a few questions about your pet."
          />
        </MotionReveal>
        <div className="mt-12 grid gap-0 md:grid-cols-4">
          {howItWorksSteps.map((step, index) => (
            <MotionReveal key={step.title} delay={index * 0.08}>
              <article
                className={`p-6 ${
                  index !== howItWorksSteps.length - 1
                    ? "md:border-r md:border-[rgba(82,183,136,0.2)]"
                    : ""
                }`}
              >
                <p className="mb-3 font-display text-5xl font-bold text-clv-green-mid opacity-50">
                  {index + 1}
                </p>
                <h3 className="text-[15px] font-semibold text-white">
                  {step.title}
                </h3>
                <p className="mt-3 text-[13px] leading-[1.6] text-[#CFE8DA]">
                  {step.body}
                </p>
              </article>
            </MotionReveal>
          ))}
        </div>
      </div>
    </section>
  );
}
