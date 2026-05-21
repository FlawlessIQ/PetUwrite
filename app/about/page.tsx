import type { Metadata } from "next";
import { AboutContent } from "@/components/pages/AboutContent";

export const metadata: Metadata = {
  title: "About",
  description:
    "Learn why Clovara is building warmer, clearer pet insurance for families.",
  keywords: ["Clovara about", "pet insurance company", "FlawlessIQ"],
  openGraph: {
    title: "About Clovara",
    description:
      "Clovara helps families protect their pets without confusing coverage.",
    images: [{ url: "/og-image.svg", width: 1200, height: 630 }]
  },
  twitter: {
    card: "summary_large_image",
    title: "About Clovara",
    description:
      "Clovara helps families protect their pets without confusing coverage.",
    images: ["/og-image.svg"]
  }
};

export default function AboutPage() {
  return (
    <main id="main-content" className="bg-clv-white">
      <AboutContent />
    </main>
  );
}
