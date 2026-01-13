# Quote Collector (Human-in-the-loop)

Collects competitor pet insurance quote premiums for a fixed scenario set.

## Safety / Terms

- This tool **does not bypass CAPTCHAs, OTP, login walls, or other access controls**.
- If a site blocks automation, the runner will pause and ask you to take over.
- Use conservative pacing; do not run aggressively.

## Install

From repo root:

```bash
cd tools/quote_collector
npm install
npx playwright install
```

## Run

Full run (all competitors/states/scenarios):

```bash
npm run collect -- --headless=false --slowMo=100 --timeoutMs=60000
```

Filter run:

```bash
npm run collect -- --competitors=lemonade,embrace --states=PA --headless=false
```

Non-interactive smoke test (won’t wait for ENTER; marks blocked rows as `manual_required`):

```bash
npm run collect -- --competitors=lemonade --states=PA --scenarios=80_250_10k --headless=true --nonInteractive=true
```

## Outputs

Each run writes under:

- `tools/quote_collector/output/runs/<timestamp>/run.json`
- `tools/quote_collector/output/runs/<timestamp>/quotes.csv`
- `tools/quote_collector/output/runs/<timestamp>/premiums.csv` (premium-focused)
- `tools/quote_collector/output/runs/<timestamp>/evidence/.../step_*.png`

## Spreadsheet import

`quotes.csv` columns match the “Competitor Quotes” tab:

- Competitor
- State
- Zip
- Reimbursement %
- Annual Deductible
- Annual Limit
- Add-ons Included
- Monthly Premium ($)
- Notes / URL
- Run Timestamp
- Evidence Folder

## CAPTCHA / OTP guidance

If you see a CAPTCHA / OTP / login wall:

1. Complete it manually in the visible browser.
2. Navigate to the premium result screen.
3. Return to the terminal and press **ENTER** to continue.

The runner will attempt extraction again and capture screenshots.

## Premium-first workflow

This repo’s primary output is premiums.

- If automation cannot extract a premium, the runner will ask you to type/paste the monthly premium.
- If you run with `--nonInteractive=true`, it will never prompt (rows will be `manual_required`).
- If you want to disable the premium prompt even in interactive mode, pass `--askPremium=false`.
