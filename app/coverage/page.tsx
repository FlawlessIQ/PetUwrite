import type { Metadata } from "next";
import { CoverageContent } from "@/components/pages/CoverageContent";

export const metadata: Metadata = {
  title: "Coverage",
  description:
    "Compare Clovara coverage for accidents, illness, surgery, wellness care, and claims.",
  keywords: ["pet insurance coverage", "dog coverage", "cat coverage"],
  openGraph: {
    title: "Clovara coverage",
    description:
      "Compare coverage for accidents, illness, surgery, and wellness care.",
    images: [{ url: "/og-image.svg", width: 1200, height: 630 }]
  },
  twitter: {
    card: "summary_large_image",
    title: "Clovara coverage",
    description:
      "Compare coverage for accidents, illness, surgery, and wellness care.",
    images: ["/og-image.svg"]
  }
};

export default function CoveragePage() {
  return (
    <main id="main-content" className="bg-clv-white">
      <CoverageContent />
    </main>
  );
}
