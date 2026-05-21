import type { Metadata } from "next";
import { HowItWorksContent } from "@/components/pages/HowItWorksContent";

export const metadata: Metadata = {
  title: "How it works",
  description:
    "See how Clovara helps pet parents get a quote, choose a plan, and file claims.",
  keywords: ["pet insurance quote", "pet claims", "vet bill reimbursement"],
  openGraph: {
    title: "How Clovara works",
    description:
      "Get a quote, choose coverage, and file claims from your phone.",
    images: [{ url: "/og-image.svg", width: 1200, height: 630 }]
  },
  twitter: {
    card: "summary_large_image",
    title: "How Clovara works",
    description:
      "Get a quote, choose coverage, and file claims from your phone.",
    images: ["/og-image.svg"]
  }
};

export default function HowItWorksPage() {
  return (
    <main id="main-content" className="bg-clv-white">
      <HowItWorksContent />
    </main>
  );
}
