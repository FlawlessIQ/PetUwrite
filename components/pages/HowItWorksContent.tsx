import { BottomCta } from "@/components/home/BottomCta";
import { FaqSection } from "@/components/home/FaqSection";
import { LazySection } from "@/components/shared/LazySection";
import { MotionReveal } from "@/components/shared/MotionReveal";
import { expandedHowItWorksSteps } from "@/data/site";

export function HowItWorksContent() {
  return (
    <>
      <section className="bg-clv-white px-5 py-24 md:px-8 md:py-28">
        <div className="mx-auto max-w-5xl text-center">
          <p className="text-[11px] font-semibold uppercase tracking-[0.12em] text-clv-green">
            How it works
          </p>
          <h1 className="mt-4 font-display text-[40px] font-bold leading-none tracking-[-0.03em] text-clv-charcoal md:text-[64px]">
            From quote to covered without the insurance fog.
          </h1>
          <p className="mx-auto mt-5 max-w-2xl text-base leading-[1.75] text-clv-gray md:text-[17px]">
            Clovara keeps the process short, readable, and built around your pet.
            No phone tree. No mystery pricing. No guessing what happens next.
          </p>
        </div>
      </section>

      {expandedHowItWorksSteps.map((step, index) => (
        <LazySection key={step.number} minHeight={520}>
          <section
            className={`px-5 py-20 md:px-8 md:py-28 ${
              index % 2 === 0 ? "bg-clv-sage-light" : "bg-clv-white"
            }`}
          >
            <div
              className={`mx-auto grid max-w-6xl items-center gap-10 md:grid-cols-2 ${
                index % 2 === 1 ? "md:[&>*:first-child]:order-2" : ""
              }`}
            >
              <MotionReveal>
                <div>
                  <p className="font-display text-[72px] font-bold leading-none text-clv-green-mid/50">
                    {step.number}
                  </p>
                  <h2 className="mt-4 font-display text-[28px] font-bold tracking-[-0.02em] text-clv-charcoal md:text-[40px]">
                    {step.title}
                  </h2>
                  <div className="mt-5 space-y-4 text-base leading-[1.75] text-clv-gray">
                    {step.paragraphs.map((paragraph) => (
                      <p key={paragraph}>{paragraph}</p>
                    ))}
                  </div>
                </div>
              </MotionReveal>

              <MotionReveal delay={0.1}>
                <div className="mx-auto flex h-[350px] w-full max-w-[350px] items-center justify-center rounded-2xl bg-clv-sage-light p-6">
                  <div className="w-full rounded-2xl border border-clv-gray-border bg-white p-5">
                    <p className="text-xs uppercase tracking-[0.12em] text-clv-green">
                      {step.mockupTitle}
                    </p>
                    <div className="mt-5 space-y-3">
                      {step.mockupRows.map((row, rowIndex) => (
                        <div
                          key={row}
                          className="flex items-center gap-3 rounded-lg bg-clv-white p-3"
                        >
                          <span className="flex h-8 w-8 items-center justify-center rounded-full bg-clv-green text-xs font-semibold text-white">
                            {rowIndex + 1}
                          </span>
                          <span className="text-sm font-semibold text-clv-charcoal">
                            {row}
                          </span>
                        </div>
                      ))}
                    </div>
                  </div>
                </div>
              </MotionReveal>
            </div>
          </section>
        </LazySection>
      ))}

      <LazySection minHeight={640}>
        <FaqSection />
      </LazySection>
      <LazySection minHeight={320}>
        <BottomCta />
      </LazySection>
    </>
  );
}
