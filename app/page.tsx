import type { Metadata } from "next";
import { Hero } from "@/components/hero/Hero";
import { TrustBar } from "@/components/home/TrustBar";

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
  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Organization",
        name: "Clovara",
        url: "https://pet-underwriter-ai.web.app",
        legalName: "FlawlessIQ Inc."
      },
      {
        "@type": "WebSite",
        name: "Clovara",
        url: "https://pet-underwriter-ai.web.app",
        potentialAction: {
          "@type": "SearchAction",
          target: "https://pet-underwriter-ai.web.app/quote",
          "query-input": "required name=quote"
        }
      }
    ]
  };

  return (
    <main id="main-content" className="bg-clv-white">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(structuredData) }}
      />
      <Hero />
      <TrustBar />
    </main>
  );
}
