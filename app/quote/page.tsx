import type { Metadata } from "next";
import { QuoteFlow } from "@/components/quote/QuoteFlow";

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
      <QuoteFlow />
    </main>
  );
}
