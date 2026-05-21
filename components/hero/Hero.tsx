"use client";

import { AnimatePresence, motion } from "framer-motion";
import Image from "next/image";
import Link from "next/link";
import { useState } from "react";
import { track } from "@/hooks/useAnalytics";
import type { PetType } from "@/types";
import { SpeciesToggle } from "./SpeciesToggle";

const stagger = {
  animate: {
    transition: {
      staggerChildren: 0.1
    }
  }
};

const fadeUp = {
  initial: { opacity: 0, y: 20 },
  animate: { opacity: 1, y: 0 }
};

export function Hero() {
  const [species, setSpecies] = useState<PetType>("dog");

  function chooseSpecies(value: PetType) {
    setSpecies(value);
    track("species_selected", { species: value, location: "hero" });
  }

  return (
    <section className="bg-clv-white">
      <div
        className="mx-auto grid max-w-7xl gap-8 px-5 md:grid-cols-[55fr_45fr] md:px-8"
        style={{ paddingTop: "48px", paddingBottom: "48px", alignItems: "center" }}
      >
        <motion.div
          variants={stagger}
          initial="initial"
          animate="animate"
          className="max-w-xl"
        >
          <motion.p
            variants={fadeUp}
            className="text-[11px] font-semibold uppercase tracking-[0.12em] text-clv-green"
          >
            Pet insurance, finally done right
          </motion.p>
          <motion.h1
            variants={fadeUp}
            className="mt-3 font-display text-[40px] font-bold leading-[0.98] tracking-[-0.03em] text-clv-charcoal md:text-[60px]"
          >
            Your vet bill
            <br />
            shouldn&apos;t be a
            <br />
            <span className="text-clv-green">gut punch.</span>
          </motion.h1>
          <motion.p
            variants={fadeUp}
            className="mt-5 max-w-[420px] text-[17px] leading-[1.75] text-clv-gray"
          >
            Clovara covers accidents, illness, and surgery — with no surprise
            exclusions and claims paid in 2 days.
          </motion.p>
          <motion.div variants={fadeUp} className="mt-6 max-w-[340px]">
            <SpeciesToggle value={species} onChange={chooseSpecies} />
            <p className="mt-3 text-[13px] font-medium text-clv-green">
              Get a quote for your {species}
            </p>
          </motion.div>
          <motion.div variants={fadeUp} className="mt-5 max-w-[340px]">
            <Link
              href="/quote"
              onClick={() => {
                track("quote_started", { species, source: "hero" });
              }}
              className="inline-flex min-w-[200px] w-fit items-center justify-center rounded-md bg-clv-charcoal px-8 py-[13px] text-sm font-semibold tracking-[0.02em] text-clv-white transition-colors hover:bg-[#333]"
            >
              See my price →
            </Link>
            <Link
              href="/coverage"
              className="mt-4 inline-flex text-sm text-clv-gray underline-offset-4 hover:text-clv-green hover:underline"
            >
              See what&apos;s covered
            </Link>
          </motion.div>
        </motion.div>
        <motion.div
          initial={{ opacity: 0, x: 32 }}
          animate={{ opacity: 1, x: 0 }}
          transition={{ duration: 0.7, ease: [0.22, 1, 0.36, 1] }}
          className="flex justify-center pt-2 md:justify-end"
        >
          <div className="relative h-auto w-full max-w-[540px] max-h-[480px]">
            <AnimatePresence mode="wait">
              <motion.div
                key={species}
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                transition={{ duration: 0.4, ease: "easeOut" }}
                className="relative overflow-hidden rounded-[20px] shadow-[0_8px_40px_rgba(0,0,0,0.10)]"
              >
                <Image
                  src={
                    species === "dog"
                      ? "https://images.unsplash.com/photo-1552053831-71594a27632d?w=700&q=85"
                      : "https://images.unsplash.com/photo-1574144611937-0df059b5ef3e?w=700&q=85"
                  }
                  alt={species === "dog" ? "Happy dog" : "Happy cat"}
                  width={540}
                  height={460}
                  priority
                  style={{
                    objectFit: "cover",
                    objectPosition:
                      species === "dog" ? "center top" : "center center",
                    borderRadius: "20px",
                    width: "100%",
                    height: "auto"
                  }}
                />
                <div className="absolute bottom-5 left-5 flex items-center gap-3 rounded-xl bg-white px-4 py-[10px] shadow-[0_4px_16px_rgba(0,0,0,0.12)]">
                  <span
                    aria-hidden="true"
                    className="flex h-6 w-6 items-center justify-center rounded-full bg-clv-green text-xs font-bold text-white"
                  >
                    ✓
                  </span>
                  <span className="text-[13px] font-semibold text-clv-charcoal">
                    Claims paid in 2 days
                  </span>
                </div>
              </motion.div>
            </AnimatePresence>
          </div>
        </motion.div>
      </div>
    </section>
  );
}
