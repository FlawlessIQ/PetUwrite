"use client";

import type { PetType } from "@/types";

interface SpeciesToggleProps {
  value: PetType;
  onChange: (value: PetType) => void;
  dark?: boolean;
}

export function SpeciesToggle({
  value,
  onChange,
  dark = false
}: SpeciesToggleProps) {
  return (
    <div className="grid grid-cols-2 gap-3" role="group" aria-label="Pet type">
      {([
        ["dog", "Dog"],
        ["cat", "Cat"]
      ] as const).map(([species, label]) => {
        const active = value === species;
        return (
          <button
            key={species}
            type="button"
            aria-pressed={active}
            onClick={() => onChange(species)}
            className={`rounded-[99px] border px-5 py-3 text-sm font-semibold transition-colors ${
              active
                ? "border-clv-green bg-clv-green text-white"
                : dark
                  ? "border-white/30 bg-transparent text-white"
                  : "border-clv-gray-light bg-transparent text-clv-gray"
            }`}
          >
            {species === "dog" ? "🐶" : "🐱"} {label}
          </button>
        );
      })}
    </div>
  );
}
