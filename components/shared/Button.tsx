import Link from "next/link";
import type { ButtonHTMLAttributes, ReactNode } from "react";

type ButtonVariant = "primary" | "secondary" | "ghost";

const variantClasses: Record<ButtonVariant, string> = {
  primary: "bg-clv-charcoal text-clv-white hover:bg-[#333]",
  secondary: "bg-clv-green text-white hover:bg-clv-green-dark",
  ghost:
    "border border-clv-gray-light bg-transparent text-clv-gray hover:border-clv-green hover:text-clv-green"
};

const baseClasses =
  "inline-flex min-h-[48px] items-center justify-center rounded-md px-7 py-[13px] text-sm font-semibold tracking-[0.02em] transition-colors";

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  children: ReactNode;
  variant?: ButtonVariant;
}

interface ButtonLinkProps {
  href: string;
  children: ReactNode;
  variant?: ButtonVariant;
  className?: string;
  onClick?: () => void;
}

export function Button({
  children,
  variant = "primary",
  className = "",
  ...props
}: ButtonProps) {
  return (
    <button
      className={`${baseClasses} ${variantClasses[variant]} ${className}`}
      {...props}
    >
      {children}
    </button>
  );
}

export function ButtonLink({
  href,
  children,
  variant = "primary",
  className = "",
  onClick
}: ButtonLinkProps) {
  return (
    <Link
      href={href}
      onClick={onClick}
      className={`${baseClasses} ${variantClasses[variant]} ${className}`}
    >
      {children}
    </Link>
  );
}
