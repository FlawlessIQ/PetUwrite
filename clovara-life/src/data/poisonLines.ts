/*
 * In a module of their own so that importing three phone numbers does not
 * import the toxin table. The companion kit's escalate card (DESIGN.md §5b)
 * needed them, and pulling them from toxins.ts put every toxin into the entry
 * chunk for every visitor; scripts/verify-bundle.mjs caught it. Second leak of
 * this shape — see engine/time.ts. Shares toxins.ts's VET-REVIEW status.
 */

/**
 * Poison lines. Numbers are rendered as tap-to-call links.
 *
 * The US services charge a consultation fee, which is stated rather than
 * discovered at the worst possible moment.
 */
export const POISON_LINES = [
  {
    id: 'aspca',
    region: 'United States',
    name: 'ASPCA Animal Poison Control',
    tel: '+18884264435',
    display: '(888) 426-4435',
    note: 'Open all hours. A consultation fee applies.',
  },
  {
    id: 'pph',
    region: 'United States & Canada',
    name: 'Pet Poison Helpline',
    tel: '+18557647661',
    display: '(855) 764-7661',
    note: 'Open all hours. A consultation fee applies.',
  },
  {
    id: 'apl',
    region: 'United Kingdom',
    name: 'Animal PoisonLine',
    tel: '+441202509000',
    display: '01202 509000',
    note: 'Open all hours. A fee applies; it is cheaper than an unnecessary out-of-hours visit.',
  },
]
