import Link from "next/link";
import { BrandLogo } from "@/components/shared/BrandLogo";
import { navItems } from "@/data/site";

export function Footer() {
  return (
    <footer className="bg-[#111111] text-[#8a8a8a]">
      <div className="mx-auto max-w-7xl px-5 py-10 md:px-8">
        <div className="grid gap-8 md:grid-cols-[1fr_auto_1fr] md:items-center">
          <BrandLogo dark />
          <nav className="flex flex-wrap gap-x-7 gap-y-3" aria-label="Footer">
            {navItems.map((item) => (
              <Link
                key={item.href}
                href={item.href}
                className="text-[13px] hover:text-[#b8b8b8]"
              >
                {item.label}
              </Link>
            ))}
          </nav>
          <Link
            href="/quote"
            className="rounded-[24px] bg-clv-green px-5 py-[9px] text-center text-[13px] font-semibold text-white md:justify-self-end"
          >
            Get a free quote
          </Link>
        </div>
        <div className="my-8 h-px bg-white/10" />
        <div className="grid gap-4 text-[13px] md:grid-cols-2">
          <p>
            © 2026 FlawlessIQ Inc. ·{" "}
            <Link href="/privacy" className="hover:text-[#b8b8b8]">
              Privacy Policy
            </Link>{" "}
            ·{" "}
            <Link href="/terms" className="hover:text-[#b8b8b8]">
              Terms of Service
            </Link>
          </p>
          <p className="md:text-right">
            Clovara is a trade name of FlawlessIQ Inc. Insurance products
            subject to state availability.
          </p>
        </div>
      </div>
    </footer>
  );
}
