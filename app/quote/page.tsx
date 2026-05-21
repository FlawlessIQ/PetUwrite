import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Get a free quote",
  description:
    "Get a free Clovara pet insurance quote for your dog or cat.",
  keywords: ["free pet insurance quote", "dog insurance quote", "cat insurance quote"],
  openGraph: {
    title: "Get a free Clovara quote",
    description: "See a real price for your pet in minutes.",
    images: [{ url: "/og-image.svg", width: 1200, height: 630 }]
  },
  twitter: {
    card: "summary_large_image",
    title: "Get a free Clovara quote",
    description: "See a real price for your pet in minutes.",
    images: ["/og-image.svg"]
  }
};

export default function QuotePage() {
  return (
    <main id="main-content" className="bg-clv-paper">
      <section className="mx-auto max-w-5xl px-5 py-24">
        <h1 className="font-display text-[40px] font-bold leading-none tracking-[-0.03em] text-clv-charcoal md:text-[64px]">
          Get a free quote
        </h1>
      </section>
    </main>
  );
}
