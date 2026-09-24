/**
 * Calendar constants, in a module of their own so that importing one does not
 * import a data table.
 *
 * `WEEKS_PER_YEAR` lived in `passport.ts`, and `vaccines.ts` imported it from
 * there for a single multiplication. That one import put the whole socialisation
 * table — 103 stamps — into the main bundle for every visitor, because the
 * morning briefing reads the vaccination schedule on the home screen. Nothing
 * rendered them; they were simply along for the ride.
 *
 * `scripts/verify-bundle.mjs` now fails if that happens again.
 */

/** 365.2425 ÷ 7. Used wherever an age in years becomes an age in weeks. */
export const WEEKS_PER_YEAR = 52.1775
