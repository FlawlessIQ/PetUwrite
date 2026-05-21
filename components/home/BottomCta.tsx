"use client";

import Link from "next/link";
import { useState } from "react";
import { SpeciesToggle } from "@/components/hero/SpeciesToggle";
import { track } from "@/hooks/useAnalytics";
import type { PetType } from "@/types";

export function BottomCta() {
  const [species, setSpecies] = useState<PetType>("dog");

  return (
    <section className="bg-clv-green py-20 text-center">
      <div className="mx-auto max-w-3xl px-5 md:px-8">
        <h2 className="font-display text-[28px] font-bold leading-tight tracking-[-0.02em] text-white md:text-[40px]">
          Get a quote in 90 seconds.
        </h2>
        <p className="mt-4 text-base leading-[1.75] text-clv-green-muted">
          No commitment. No credit card. Just a real price for your pet.
        </p>
        <div className="mx-auto mt-8 max-w-[340px]">
          <SpeciesToggle
            dark
            value={species}
            onChange={(value) => {
              setSpecies(value);
              track("species_selected", { species: value, location: "bottom_cta" });
            }}
          />
        </div>
        <Link
          href="/quote"
          onClick={() => track("quote_started", { species, source: "bottom_cta" })}
          className="mt-7 inline-flex rounded-md bg-white px-7 py-[13px] text-sm font-semibold tracking-[0.02em] text-clv-green-dark transition-colors hover:bg-clv-white"
        >
          Get my free quote →
        </Link>
        <Link
          href="/coverage"
          className="mt-5 block text-sm text-clv-green-muted underline-offset-4 hover:underline"
        >
          See a sample policy
        </Link>
      </div>
    </section>
  );
}
