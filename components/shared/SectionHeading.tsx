interface SectionHeadingProps {
  eyebrow?: string;
  title: string;
  body?: string;
  centered?: boolean;
  dark?: boolean;
}

export function SectionHeading({
  eyebrow,
  title,
  body,
  centered = false,
  dark = false
}: SectionHeadingProps) {
  return (
    <div className={centered ? "mx-auto max-w-3xl text-center" : "max-w-3xl"}>
      {eyebrow ? (
        <p
          className={`mb-3 text-[11px] font-semibold uppercase tracking-[0.12em] ${
            dark ? "text-[#B7E4C7]" : "text-clv-green"
          }`}
        >
          {eyebrow}
        </p>
      ) : null}
      <h2
        className={`font-display text-[28px] font-bold leading-tight tracking-[-0.02em] md:text-[40px] ${
          dark ? "text-white" : "text-clv-charcoal"
        }`}
      >
        {title}
      </h2>
      {body ? (
        <p
          className={`mt-4 text-base leading-[1.75] ${
            dark ? "text-white/85" : "text-clv-gray"
          }`}
        >
          {body}
        </p>
      ) : null}
    </div>
  );
}
