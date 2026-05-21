interface IllustrationProps {
  size?: number;
  className?: string;
  decorative?: boolean;
}

export function DogIllustration({
  size = 340,
  className = "",
  decorative = false
}: IllustrationProps) {
  return (
    <svg
      role={decorative ? undefined : "img"}
      aria-label={decorative ? undefined : "Friendly golden retriever illustration"}
      aria-hidden={decorative ? "true" : undefined}
      width={size}
      height={size}
      viewBox="0 0 340 340"
      className={className}
    >
      <circle cx="170" cy="170" r="145" fill="#EEF7F2" />
      <path
        d="M238 210 C292 196 292 145 249 160"
        fill="none"
        stroke="#B7E4C7"
        strokeWidth="12"
        strokeLinecap="round"
      />
      <ellipse cx="170" cy="214" rx="82" ry="76" fill="#B7E4C7" />
      <ellipse cx="118" cy="149" rx="28" ry="46" fill="#B7E4C7" transform="rotate(-24 118 149)" />
      <ellipse cx="222" cy="149" rx="28" ry="46" fill="#B7E4C7" transform="rotate(24 222 149)" />
      <circle cx="170" cy="145" r="62" fill="#D8F3DC" />
      <circle cx="148" cy="136" r="6" fill="#1B4332" />
      <circle cx="192" cy="136" r="6" fill="#1B4332" />
      <ellipse cx="170" cy="158" rx="12" ry="9" fill="#52B788" />
      <ellipse cx="142" cy="284" rx="24" ry="15" fill="#B7E4C7" />
      <ellipse cx="198" cy="284" rx="24" ry="15" fill="#B7E4C7" />
    </svg>
  );
}

export function CatIllustration({
  size = 340,
  className = "",
  decorative = false
}: IllustrationProps) {
  return (
    <svg
      role={decorative ? undefined : "img"}
      aria-label={decorative ? undefined : "Friendly cat illustration"}
      aria-hidden={decorative ? "true" : undefined}
      width={size}
      height={size}
      viewBox="0 0 340 340"
      className={className}
    >
      <circle cx="170" cy="170" r="145" fill="#EEF7F2" />
      <path
        d="M228 244 C292 244 286 154 237 177"
        fill="none"
        stroke="#B7E4C7"
        strokeWidth="13"
        strokeLinecap="round"
      />
      <ellipse cx="170" cy="221" rx="66" ry="78" fill="#B7E4C7" />
      <path d="M125 119 L143 77 L162 124 Z" fill="#B7E4C7" />
      <path d="M178 124 L197 77 L215 119 Z" fill="#B7E4C7" />
      <circle cx="170" cy="144" r="58" fill="#D8F3DC" />
      <circle cx="149" cy="136" r="6" fill="#1B4332" />
      <circle cx="191" cy="136" r="6" fill="#1B4332" />
      <ellipse cx="170" cy="157" rx="10" ry="7" fill="#52B788" />
      <path d="M158 164 C162 172 178 172 182 164" fill="none" stroke="#1B4332" strokeWidth="3" strokeLinecap="round" />
      <path d="M144 158 L105 149 M145 166 L106 171 M196 158 L235 149 M195 166 L234 171" stroke="#1B4332" strokeWidth="3" strokeLinecap="round" />
      <ellipse cx="146" cy="287" rx="21" ry="13" fill="#B7E4C7" />
      <ellipse cx="194" cy="287" rx="21" ry="13" fill="#B7E4C7" />
    </svg>
  );
}
