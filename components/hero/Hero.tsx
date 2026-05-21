"use client";

import { motion } from "framer-motion";
import Link from "next/link";
import { useState } from "react";
import { DogIllustration, CatIllustration } from "@/components/shared/SpeciesIllustrations";
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
      <div className="mx-auto grid min-h-[calc(100vh-81px)] max-w-7xl items-center gap-12 px-5 py-16 md:grid-cols-[55fr_45fr] md:px-8">
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
            className="mt-5 font-display text-[40px] font-bold leading-[0.98] tracking-[-0.03em] text-clv-charcoal md:text-[64px]"
          >
            Your vet bill
            <br />
            shouldn&apos;t be a
            <br />
            <span className="text-clv-green">gut punch.</span>
          </motion.h1>
          <motion.p
            variants={fadeUp}
            className="mt-6 max-w-[420px] text-[17px] leading-[1.75] text-clv-gray"
          >
            Clovara covers accidents, illness, and surgery — with no surprise
            exclusions and claims paid in 2 days.
          </motion.p>
          <motion.div variants={fadeUp} className="mt-8 max-w-[340px]">
            <SpeciesToggle value={species} onChange={chooseSpecies} />
            <p className="mt-3 text-[13px] font-medium text-clv-green">
              Get a quote for your {species}
            </p>
          </motion.div>
          <motion.div variants={fadeUp} className="mt-6 max-w-[340px]">
            <Link
              href="/quote"
              onClick={() => {
                track("quote_started", { species, source: "hero" });
              }}
              className="flex w-full items-center justify-center rounded-md bg-clv-charcoal px-7 py-[13px] text-sm font-semibold tracking-[0.02em] text-clv-white transition-colors hover:bg-[#333]"
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
          className="flex justify-center md:justify-end"
        >
          <motion.div
            key={species}
            initial={{ opacity: 0, scale: 0.96 }}
            animate={{
              opacity: 1,
              scale: 1,
              y: [-6, 6, -6]
            }}
            transition={{
              opacity: { duration: 0.3 },
              scale: { duration: 0.3 },
              y: {
                duration: 3,
                ease: "easeInOut",
                repeat: Infinity
              }
            }}
          >
            {species === "dog" ? <DogIllustration /> : <CatIllustration />}
          </motion.div>
        </motion.div>
      </div>
    </section>
  );
}
