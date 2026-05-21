import Image from "next/image";
import Link from "next/link";
import clovaraMark from "@/assets/images/clovara_mark_refined.svg";

interface BrandLogoProps {
  dark?: boolean;
}

export function BrandLogo({ dark = false }: BrandLogoProps) {
  return (
    <Link
      href="/"
      className="inline-flex items-center gap-2"
      aria-label="Clovara home"
    >
      <Image
        src={clovaraMark}
        alt=""
        width={28}
        height={29}
        className="h-7 w-auto"
        aria-hidden="true"
        priority
      />
      <span
        className={`font-display text-xl font-bold tracking-[-0.02em] ${
          dark ? "text-clv-white" : "text-clv-charcoal"
        }`}
      >
        Clovara
      </span>
    </Link>
  );
}
