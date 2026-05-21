import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Pet insurance for dogs and cats",
  description:
    "Clovara covers accidents, illness, surgery, and vet bills with fast quotes and clear claims.",
  keywords: ["pet insurance", "dog insurance", "cat insurance", "vet bills"],
  openGraph: {
    title: "Clovara | Pet insurance for dogs and cats",
    description:
      "Fast quotes, clear coverage, and claims paid in days.",
    images: [{ url: "/og-image.svg", width: 1200, height: 630 }]
  },
  twitter: {
    card: "summary_large_image",
    title: "Clovara | Pet insurance for dogs and cats",
    description: "Fast quotes, clear coverage, and claims paid in days.",
    images: ["/og-image.svg"]
  }
};

export default function HomePage() {
  return (
    <main id="main-content" className="bg-clv-white">
      <section className="mx-auto max-w-5xl px-5 py-24">
        <p className="text-[11px] font-semibold uppercase tracking-[0.12em] text-clv-green">
          Clovara
        </p>
        <h1 className="mt-4 font-display text-[40px] font-bold leading-none tracking-[-0.03em] text-clv-charcoal md:text-[64px]">
          Pet insurance, finally done right.
        </h1>
        <p className="mt-5 max-w-xl text-base leading-[1.75] text-clv-gray">
          The customer-facing rebuild is in progress. Phase 1a establishes the
          design system and base project shell.
        </p>
      </section>
    </main>
  );
}
