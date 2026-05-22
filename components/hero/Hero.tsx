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

const heroImages = {
  dog: {
    src: "https://images.unsplash.com/photo-1552053831-71594a27632d?w=700&q=85",
    alt: "Happy golden retriever",
    objectPosition: "center 20%"
  },
  cat: {
    src: "https://images.unsplash.com/photo-1574144611937-0df059b5ef3e?w=700&q=85",
    alt: "Warm-toned orange tabby cat",
    objectPosition: "center center"
  }
} satisfies Record<PetType, { src: string; alt: string; objectPosition: string }>;

export function Hero() {
  const [species, setSpecies] = useState<PetType>("dog");

  function chooseSpecies(value: PetType) {
    setSpecies(value);
    track("species_selected", { species: value, location: "hero" });
  }

  const activeImage = heroImages[species];

  return (
    <section className="bg-clv-white">
      <div className="mx-auto grid max-w-7xl items-center gap-10 px-5 pb-6 pt-10 md:grid-cols-[minmax(0,1fr)_minmax(420px,520px)] md:px-8 md:pb-8">
        <motion.div
          variants={stagger}
          initial="initial"
          animate="animate"
          className="max-w-[560px]"
        >
          <motion.p
            variants={fadeUp}
            className="text-[11px] font-semibold uppercase tracking-[0.12em] text-clv-green"
          >
            Pet insurance, finally done right
          </motion.p>
          <motion.h1
            variants={fadeUp}
            className="mt-3 max-w-[10ch] font-display text-[40px] font-bold leading-[0.94] tracking-[-0.03em] text-clv-charcoal md:text-[68px]"
          >
            Your vet bill
            <br />
            shouldn&apos;t be a
            <br />
            <span className="text-clv-green">gut punch.</span>
          </motion.h1>
          <motion.p
            variants={fadeUp}
            className="mt-5 max-w-[470px] text-[17px] leading-[1.75] text-clv-gray"
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
          <motion.div variants={fadeUp} className="mt-6 flex flex-wrap items-center gap-4">
            <Link
              href="/quote"
              onClick={() => {
                track("quote_started", { species, source: "hero" });
              }}
              className="inline-flex min-w-[200px] items-center justify-center rounded-md bg-clv-charcoal px-8 py-[13px] text-sm font-semibold tracking-[0.02em] text-clv-white transition-colors hover:bg-[#333]"
            >
              See my price →
            </Link>
            <Link
              href="/coverage"
              className="inline-flex text-sm text-clv-gray underline-offset-4 hover:text-clv-green hover:underline"
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
          <div className="relative w-full max-w-[520px]">
            <AnimatePresence mode="wait">
              <motion.div
                key={species}
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                transition={{ duration: 0.4, ease: "easeOut" }}
                className="relative aspect-[11/10] overflow-hidden rounded-[26px] shadow-[0_18px_50px_rgba(17,24,20,0.14)] ring-1 ring-black/5"
              >
                <Image
                  src={activeImage.src}
                  alt={activeImage.alt}
                  fill
                  priority
                  sizes="(min-width: 768px) 520px, 100vw"
                  className="object-cover"
                  style={{ objectPosition: activeImage.objectPosition }}
                />
                <div className="absolute bottom-4 left-4 flex items-center gap-3 rounded-xl bg-white px-4 py-3 shadow-[0_10px_30px_rgba(17,24,20,0.16)]">
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
