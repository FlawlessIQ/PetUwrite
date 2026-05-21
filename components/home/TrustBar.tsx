import { trustStats } from "@/data/site";

export function TrustBar() {
  return (
    <section className="border-y border-clv-gray-border bg-clv-paper">
      <div className="mx-auto grid max-w-7xl grid-cols-2 px-5 md:grid-cols-5 md:px-8">
        {trustStats.map((stat, index) => (
          <div
            key={stat.label}
            className={`py-7 text-center ${
              index !== trustStats.length - 1
                ? "md:border-r md:border-clv-gray-border"
                : ""
            }`}
          >
            <p className="font-display text-[26px] font-bold text-clv-green">
              {stat.value}
            </p>
            <p className="mt-1 text-[10px] font-semibold uppercase tracking-[0.1em] text-clv-gray">
              {stat.label}
            </p>
          </div>
        ))}
      </div>
    </section>
  );
}
