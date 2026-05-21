"use client";

import { useState } from "react";
import { faqs } from "@/data/site";
import { SectionHeading } from "@/components/shared/SectionHeading";

export function FaqSection() {
  const [openIndex, setOpenIndex] = useState(0);

  return (
    <section id="faq" className="bg-clv-paper py-20 md:py-28">
      <div className="mx-auto grid max-w-7xl gap-10 px-5 md:grid-cols-[0.8fr_1.2fr] md:px-8">
        <SectionHeading eyebrow="Common questions" title="Straight answers." />
        <div className="divide-y divide-clv-gray-border border-y border-clv-gray-border">
          {faqs.map((item, index) => {
            const open = openIndex === index;
            return (
              <article key={item.question}>
                <button
                  type="button"
                  className="flex w-full items-center justify-between gap-6 py-5 text-left text-[15px] font-semibold text-clv-charcoal"
                  aria-expanded={open}
                  aria-controls={`faq-${index}`}
                  onClick={() => setOpenIndex(open ? -1 : index)}
                >
                  {item.question}
                  <span
                    className={`text-2xl font-normal text-clv-green transition-transform duration-200 ${
                      open ? "rotate-45" : ""
                    }`}
                    aria-hidden="true"
                  >
                    +
                  </span>
                </button>
                <div
                  id={`faq-${index}`}
                  className={`grid transition-[grid-template-rows] duration-300 ease-in-out ${
                    open ? "grid-rows-[1fr]" : "grid-rows-[0fr]"
                  }`}
                >
                  <div className="overflow-hidden">
                    <p className="pb-5 text-[15px] leading-[1.75] text-clv-gray">
                      {item.answer}
                    </p>
                  </div>
                </div>
              </article>
            );
          })}
        </div>
      </div>
    </section>
  );
}
