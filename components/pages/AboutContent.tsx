import Link from "next/link";
import { LazySection } from "@/components/shared/LazySection";

export function AboutContent() {
  return (
    <>
      <section className="bg-clv-white px-5 py-24 md:px-8 md:py-28">
        <div className="mx-auto max-w-5xl">
          <p className="text-[11px] font-semibold uppercase tracking-[0.12em] text-clv-green">
            About Clovara
          </p>
          <h1 className="mt-4 max-w-4xl font-display text-[40px] font-bold leading-none tracking-[-0.03em] text-clv-charcoal md:text-[64px]">
            We built Clovara because vet bills shouldn&apos;t break families.
          </h1>
          <p className="mt-5 max-w-2xl text-base leading-[1.75] text-clv-gray md:text-[17px]">
            Pet insurance should feel like help, not homework. Clovara is built
            for families who want clear coverage, fast claims, and fewer
            stomach-drop moments at the vet.
          </p>
        </div>
      </section>

      <LazySection minHeight={520}>
        <section className="bg-clv-paper px-5 py-20 md:px-8 md:py-28">
          <div className="mx-auto grid max-w-6xl items-center gap-10 md:grid-cols-[0.8fr_1.2fr]">
            <div className="flex justify-center md:justify-start">
              {/* TODO: Replace with real founder photo */}
              <div className="flex h-[200px] w-[200px] items-center justify-center rounded-full bg-clv-green font-display text-5xl font-bold text-white">
                CL
              </div>
            </div>
            <div>
              <p className="text-[11px] font-semibold uppercase tracking-[0.12em] text-clv-green">
                Founder
              </p>
              <h2 className="mt-3 font-display text-[28px] font-bold tracking-[-0.02em] text-clv-charcoal md:text-[40px]">
                Built by Conor Lawless.
              </h2>
              {/* TODO: Conor to fill in bio */}
              <div className="mt-5 space-y-4 text-base leading-[1.75] text-clv-gray">
                <p>
                  Conor started Clovara after seeing how confusing pet insurance
                  feels when families need help quickly. The goal is simple:
                  make coverage easier to understand before the stressful moment
                  arrives.
                </p>
                <p>
                  This placeholder bio will be replaced with Conor&apos;s real
                  background, story, and why he believes pet parents deserve a
                  calmer way to protect their dogs and cats.
                </p>
              </div>
            </div>
          </div>
        </section>
      </LazySection>

      <LazySection minHeight={360}>
        <section className="bg-clv-white px-5 py-20 md:px-8 md:py-28">
          <div className="mx-auto max-w-5xl rounded-2xl bg-clv-sage-light p-8 md:p-12">
            <blockquote className="font-display text-[30px] italic leading-tight tracking-[-0.02em] text-clv-charcoal md:text-[46px]">
              &ldquo;A great pet insurance company should make families feel calmer,
              clearer, and less alone when the bill arrives.&rdquo;
            </blockquote>
          </div>
        </section>
      </LazySection>

      <LazySection minHeight={620}>
        <section className="bg-clv-paper px-5 py-20 md:px-8 md:py-28">
          <div className="mx-auto grid max-w-6xl gap-10 md:grid-cols-[0.8fr_1.2fr]">
            <div>
              <p className="text-[11px] font-semibold uppercase tracking-[0.12em] text-clv-green">
                Questions?
              </p>
              <h2 className="mt-3 font-display text-[28px] font-bold tracking-[-0.02em] text-clv-charcoal md:text-[40px]">
                We are happy to help.
              </h2>
              <p className="mt-4 text-base leading-[1.75] text-clv-gray">
                Start with the FAQ, or send a note and we will point you in the
                right direction.
              </p>
              <div className="mt-6 flex flex-wrap gap-3">
                <Link
                  href="/#faq"
                  className="rounded-md bg-clv-charcoal px-7 py-[13px] text-sm font-semibold tracking-[0.02em] text-clv-white transition-colors hover:bg-[#333]"
                >
                  Read the FAQ
                </Link>
                <Link
                  href="/quote"
                  className="rounded-md border border-clv-gray-light px-7 py-[13px] text-sm font-semibold tracking-[0.02em] text-clv-gray transition-colors hover:border-clv-green hover:text-clv-green"
                >
                  Get a quote
                </Link>
              </div>
            </div>

            <form className="rounded-xl border border-clv-gray-border bg-white p-6">
              {/* TODO: Connect contact form before launch */}
              <div className="grid gap-5">
                <FormField id="contactName" label="Name" />
                <FormField id="contactEmail" label="Email" type="email" />
                <div>
                  <label
                    htmlFor="contactMessage"
                    className="mb-2 block text-sm font-semibold text-clv-charcoal"
                  >
                    Message
                  </label>
                  <textarea
                    id="contactMessage"
                    rows={5}
                    className="w-full rounded-md border border-clv-gray-border bg-white px-4 py-3 text-base text-clv-charcoal focus:border-clv-green"
                  />
                </div>
                <button
                  type="button"
                  className="rounded-md bg-clv-green px-7 py-[13px] text-sm font-semibold tracking-[0.02em] text-white transition-colors hover:bg-clv-green-dark"
                >
                  Send message
                </button>
              </div>
            </form>
          </div>
        </section>
      </LazySection>
    </>
  );
}

function FormField({
  id,
  label,
  type = "text"
}: {
  id: string;
  label: string;
  type?: "text" | "email";
}) {
  return (
    <div>
      <label htmlFor={id} className="mb-2 block text-sm font-semibold text-clv-charcoal">
        {label}
      </label>
      <input
        id={id}
        type={type}
        className="min-h-[48px] w-full rounded-md border border-clv-gray-border bg-white px-4 text-base text-clv-charcoal focus:border-clv-green"
      />
    </div>
  );
}
