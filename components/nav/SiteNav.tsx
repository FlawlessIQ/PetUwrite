"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Menu, X } from "lucide-react";
import { navItems } from "@/data/site";

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
        <Link
          href="/"
          className="font-display text-xl font-bold tracking-[-0.02em] text-clv-charcoal"
          aria-label="Clovara home"
        >
          Clovara
        </Link>
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
        <Link
          href="/quote"
          className="hidden rounded-[24px] bg-clv-green px-5 py-[9px] text-[13px] font-semibold text-white transition-colors hover:bg-clv-green-dark md:inline-flex"
        >
          Get a free quote
        </Link>
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
      <div
        id="mobile-menu"
        className={`fixed inset-0 top-[81px] z-40 bg-clv-white px-5 pb-8 pt-8 transition-transform duration-300 md:hidden ${
          open ? "translate-x-0" : "translate-x-full"
        }`}
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
            href="/quote"
            className="mt-auto rounded-[24px] bg-clv-green px-5 py-4 text-center text-sm font-semibold text-white"
            onClick={() => setOpen(false)}
          >
            Get a free quote
          </Link>
        </div>
      </div>
    </header>
  );
}
