import Link from "next/link";
import { LazySection } from "@/components/shared/LazySection";
import { coverageRows, exclusions } from "@/data/site";

const planNames = ["Essential", "Comprehensive", "Premium"];

export function CoverageContent() {
  return (
    <>
      <section className="bg-clv-white px-5 py-24 md:px-8 md:py-28">
        <div className="mx-auto max-w-5xl">
          <p className="text-[11px] font-semibold uppercase tracking-[0.12em] text-clv-green">
            Coverage
          </p>
          <h1 className="mt-4 max-w-4xl font-display text-[40px] font-bold leading-none tracking-[-0.03em] text-clv-charcoal md:text-[64px]">
            Clear coverage for the stuff pet parents actually worry about.
          </h1>
          <p className="mt-5 max-w-2xl text-base leading-[1.75] text-clv-gray md:text-[17px]">
            Compare the plan tiers, see what is not covered, and get a real
            price when you are ready. Plain language first, always.
          </p>
        </div>
      </section>

      <LazySection minHeight={620}>
        <section className="bg-clv-paper px-5 py-20 md:px-8 md:py-28">
          <div className="mx-auto max-w-6xl">
            <div className="mb-8 flex flex-col justify-between gap-4 md:flex-row md:items-end">
              <div>
                <p className="text-[11px] font-semibold uppercase tracking-[0.12em] text-clv-green">
                  Plan comparison
                </p>
                <h2 className="mt-3 font-display text-[28px] font-bold tracking-[-0.02em] text-clv-charcoal md:text-[40px]">
                  What is in each plan.
                </h2>
              </div>
              <Link
                href="/quote"
                className="inline-flex rounded-md bg-clv-charcoal px-7 py-[13px] text-sm font-semibold tracking-[0.02em] text-clv-white transition-colors hover:bg-[#333]"
              >
                See my price →
              </Link>
            </div>

            <div className="overflow-x-auto rounded-xl border border-clv-gray-border bg-white">
              <table className="w-full min-w-[760px] border-collapse text-left">
                <caption className="sr-only">
                  Clovara coverage comparison by plan tier
                </caption>
                <thead>
                  <tr>
                    <th
                      scope="col"
                      className="sticky left-0 z-10 bg-white px-5 py-4 text-sm font-semibold text-clv-charcoal"
                    >
                      Coverage
                    </th>
                    {planNames.map((name) => (
                      <th
                        key={name}
                        scope="col"
                        className="border-l border-clv-gray-border px-5 py-4 text-sm font-semibold text-clv-charcoal"
                      >
                        {name}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {coverageRows.map((row) => (
                    <tr key={row.feature} className="border-t border-clv-gray-border">
                      <th
                        scope="row"
                        className="sticky left-0 z-10 bg-white px-5 py-4 text-sm font-semibold text-clv-charcoal"
                      >
                        {row.feature}
                      </th>
                      <td className="border-l border-clv-gray-border px-5 py-4 text-sm text-clv-gray">
                        {row.essential}
                      </td>
                      <td className="border-l border-clv-gray-border px-5 py-4 text-sm text-clv-gray">
                        {row.comprehensive}
                      </td>
                      <td className="border-l border-clv-gray-border px-5 py-4 text-sm text-clv-gray">
                        {row.premium}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </section>
      </LazySection>

      <LazySection minHeight={520}>
        <section className="bg-clv-white px-5 py-20 md:px-8 md:py-28">
          <div className="mx-auto grid max-w-6xl gap-10 md:grid-cols-[0.8fr_1.2fr]">
            <div>
              <p className="text-[11px] font-semibold uppercase tracking-[0.12em] text-clv-green">
                What we do not cover
              </p>
              <h2 className="mt-3 font-display text-[28px] font-bold tracking-[-0.02em] text-clv-charcoal md:text-[40px]">
                Trust starts with the no.
              </h2>
              <p className="mt-4 text-base leading-[1.75] text-clv-gray">
                The clearest policy is the one that tells you what is excluded
                before you buy it.
              </p>
            </div>
            <div className="grid gap-4">
              {exclusions.map((item) => (
                <article
                  key={item.title}
                  className="rounded-xl border border-clv-gray-border bg-white p-6 transition-all duration-200 hover:border-clv-green hover:shadow-[0_4px_16px_rgba(0,0,0,0.06)]"
                >
                  <h3 className="text-base font-semibold text-clv-charcoal">
                    {item.title}
                  </h3>
                  <p className="mt-2 text-sm leading-[1.75] text-clv-gray">
                    {item.body}
                  </p>
                </article>
              ))}
            </div>
          </div>
        </section>
      </LazySection>

      <LazySection minHeight={430}>
        <section className="bg-clv-sage-light px-5 py-20 md:px-8 md:py-24">
          <div className="mx-auto grid max-w-6xl gap-8 rounded-2xl bg-white p-8 md:grid-cols-[1.3fr_0.7fr] md:p-10">
            <div>
              <p className="text-[11px] font-semibold uppercase tracking-[0.12em] text-clv-green">
                Breed-friendly coverage
              </p>
              <h2 className="mt-3 font-display text-[28px] font-bold tracking-[-0.02em] text-clv-charcoal md:text-[40px]">
                We cover breeds other insurers exclude.
              </h2>
              <p className="mt-4 text-base leading-[1.75] text-clv-gray">
                Bulldogs, French Bulldogs, Great Danes, and other loved-but-pricey
                breeds deserve clear options too. No breed bans. No shame tax.
              </p>
            </div>
            <div className="grid content-center gap-3">
              {["Bulldogs", "French Bulldogs", "Great Danes"].map((breed) => (
                <div
                  key={breed}
                  className="rounded-lg border border-clv-gray-border bg-clv-white px-4 py-3 text-sm font-semibold text-clv-charcoal"
                >
                  {breed}
                </div>
              ))}
            </div>
          </div>
        </section>
      </LazySection>
    </>
  );
}
