"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Menu, X } from "lucide-react";
import { BrandLogo } from "@/components/shared/BrandLogo";
import { navItems } from "@/data/site";
import { track } from "@/hooks/useAnalytics";

export function SiteNav() {
  const [scrolled, setScrolled] = useState(false);
  const [open, setOpen] = useState(false);

  useEffect(() => {
    const update = () => setScrolled(window.scrollY > 60);
    update();
    window.addEventListener("scroll", update, { passive: true });
    return () => window.removeEventListener("scroll", update);
  }, []);

  return (
    <header
      className={`sticky top-0 z-50 transition-all ${
        scrolled
          ? "border-b border-clv-gray-border bg-clv-white/95 backdrop-blur-[10px]"
          : "border-b border-transparent bg-clv-white"
      }`}
    >
      <nav
        className="mx-auto flex max-w-7xl items-center justify-between px-5 py-5 md:px-8"
        aria-label="Primary navigation"
      >
        <BrandLogo />
        <div className="hidden items-center gap-8 md:flex">
          {navItems.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className="text-sm font-normal text-[#555] transition-colors hover:text-clv-charcoal"
            >
              {item.label}
            </Link>
          ))}
        </div>
        <div className="hidden items-center gap-4 md:flex">
          <Link
            href="/app/sign-in"
            className="rounded-[24px] border border-clv-gray-border px-5 py-[9px] text-[13px] font-semibold text-clv-charcoal transition-colors hover:border-clv-green hover:text-clv-green"
            onClick={() =>
              track("sign_in_started", {
                source: "site_nav",
                destination: "post_auth_app"
              })
            }
          >
            Sign in
          </Link>
          <Link
            href="/quote"
            className="rounded-[24px] bg-clv-green px-5 py-[9px] text-[13px] font-semibold text-white transition-colors hover:bg-clv-green-dark"
          >
            Get a free quote
          </Link>
        </div>
        <button
          type="button"
          className="flex h-11 w-11 items-center justify-center rounded-md border border-clv-gray-border text-clv-charcoal md:hidden"
          aria-label={open ? "Close menu" : "Open menu"}
          aria-expanded={open}
          aria-controls="mobile-menu"
          onClick={() => setOpen((value) => !value)}
        >
          {open ? <X size={22} aria-hidden /> : <Menu size={22} aria-hidden />}
        </button>
      </nav>
      {open ? (
        <div
          id="mobile-menu"
          className="fixed inset-0 top-[81px] z-40 bg-clv-white px-5 pb-8 pt-8 md:hidden"
        >
          <div className="flex h-full flex-col">
            <div className="grid gap-6">
              {navItems.map((item) => (
                <Link
                  key={item.href}
                  href={item.href}
                  className="border-b border-clv-gray-border pb-5 text-2xl font-medium text-clv-charcoal"
                  onClick={() => setOpen(false)}
                >
                  {item.label}
                </Link>
              ))}
            </div>
            <Link
              href="/app/sign-in"
              className="mt-8 rounded-[24px] border border-clv-gray-border px-5 py-4 text-center text-sm font-semibold text-clv-charcoal"
              onClick={() => {
                track("sign_in_started", {
                  source: "mobile_nav",
                  destination: "post_auth_app"
                });
                setOpen(false);
              }}
            >
              Sign in
            </Link>
            <Link
              href="/quote"
              className="mt-4 rounded-[24px] bg-clv-green px-5 py-4 text-center text-sm font-semibold text-white"
              onClick={() => setOpen(false)}
            >
              Get a free quote
            </Link>
          </div>
        </div>
      ) : null}
    </header>
  );
}
