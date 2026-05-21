import { testimonials } from "@/data/site";
import { MotionReveal } from "@/components/shared/MotionReveal";
import { SectionHeading } from "@/components/shared/SectionHeading";

export function TestimonialsSection() {
  return (
    <section className="bg-clv-white py-20 md:py-28">
      <div className="mx-auto max-w-7xl px-5 md:px-8">
        <MotionReveal>
          <SectionHeading
            centered
            eyebrow="Real pet parents"
            title="They were sceptical too."
          />
        </MotionReveal>
        <div className="mt-12 grid gap-5 md:grid-cols-3">
          {testimonials.map((item, index) => (
            <MotionReveal key={item.name} delay={index * 0.08}>
              <article className="h-full rounded-xl border border-clv-gray-border bg-white p-6 transition-all duration-200 hover:border-clv-green hover:shadow-[0_4px_16px_rgba(0,0,0,0.06)]">
                {/* TODO: Replace with real content */}
                <p className="text-sm text-clv-green" aria-label="Five out of five stars">
                  <span aria-hidden="true">★★★★★</span>
                </p>
                <blockquote className="mt-5 font-display text-[15px] italic leading-[1.6] text-clv-charcoal">
                  &ldquo;{item.quote}&rdquo;
                </blockquote>
                <div className="mt-7 flex items-center gap-3">
                  <div className="flex h-10 w-10 items-center justify-center rounded-full bg-clv-green text-xs font-semibold text-white">
                    {item.initials}
                  </div>
                  <div>
                    <p className="text-sm font-semibold text-clv-charcoal">
                      {item.name}
                    </p>
                    <p className="text-xs text-clv-gray">{item.detail}</p>
                  </div>
                </div>
              </article>
            </MotionReveal>
          ))}
        </div>
      </div>
    </section>
  );
}
