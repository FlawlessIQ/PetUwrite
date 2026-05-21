import type { Metadata } from "next";
import Script from "next/script";
import { DM_Sans, Playfair_Display } from "next/font/google";
import { PageTracker } from "@/components/layout/PageTracker";
import "./globals.css";

const playfair = Playfair_Display({
  subsets: ["latin"],
  variable: "--font-playfair",
  display: "swap"
});

const dmSans = DM_Sans({
  subsets: ["latin"],
  variable: "--font-dm-sans",
  display: "swap"
});

export const metadata: Metadata = {
  metadataBase: new URL("https://pet-underwriter-ai.web.app"),
  title: {
    default: "Clovara | Pet insurance, finally done right",
    template: "%s | Clovara"
  },
  description:
    "Clovara helps pet parents cover accidents, illness, surgery, and vet bills with fast quotes and clear claims.",
  keywords: [
    "pet insurance",
    "dog insurance",
    "cat insurance",
    "vet bill coverage",
    "pet claims"
  ],
  openGraph: {
    title: "Clovara | Pet insurance, finally done right",
    description:
      "Cover accidents, illness, surgery, and vet bills with no surprise exclusions.",
    url: "/",
    siteName: "Clovara",
    images: [{ url: "/og-image.svg", width: 1200, height: 630 }],
    locale: "en_US",
    type: "website"
  },
  twitter: {
    card: "summary_large_image",
    title: "Clovara | Pet insurance, finally done right",
    description:
      "Cover accidents, illness, surgery, and vet bills with no surprise exclusions.",
    images: ["/og-image.svg"]
  }
};

export default function RootLayout({
  children
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className={`${playfair.variable} ${dmSans.variable}`}>
      <body>
        <a href="#main-content" className="skip-link">
          Skip to main content
        </a>
        <Script id="segment-stub" strategy="afterInteractive">
          {`
            // TODO: Replace with real Segment write key before launch.
            window.analytics = window.analytics || {
              track: function(eventName, properties) {
                console.log('[Segment stub]', eventName, properties || {});
              }
            };
          `}
        </Script>
        <PageTracker />
        {children}
      </body>
    </html>
  );
}
