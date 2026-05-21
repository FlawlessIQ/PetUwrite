import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Privacy Policy",
  description:
    "Placeholder privacy policy page for Clovara before launch legal review.",
  keywords: ["Clovara privacy", "pet insurance privacy"],
  openGraph: {
    title: "Clovara Privacy Policy",
    description:
      "Placeholder privacy policy page for Clovara before launch legal review.",
    images: [{ url: "/og-image.svg", width: 1200, height: 630 }]
  },
  twitter: {
    card: "summary_large_image",
    title: "Clovara Privacy Policy",
    description:
      "Placeholder privacy policy page for Clovara before launch legal review.",
    images: ["/og-image.svg"]
  }
};

export default function PrivacyPage() {
  return (
    <main id="main-content" className="bg-clv-white">
      <section className="mx-auto max-w-4xl px-5 py-24 md:px-8 md:py-32">
        <p className="text-[11px] font-semibold uppercase tracking-[0.12em] text-clv-green">
          Legal
        </p>
        <h1 className="mt-4 font-display text-[40px] font-bold leading-none tracking-[-0.03em] text-clv-charcoal md:text-[64px]">
          Privacy Policy
        </h1>
        {/* TODO: Replace this placeholder with launch-ready privacy policy. */}
        <p className="mt-8 text-base leading-[1.75] text-clv-gray">
          This page is a placeholder for Clovara&apos;s final privacy policy.
          Legal copy should be reviewed and approved before public launch.
        </p>
      </section>
    </main>
  );
}
