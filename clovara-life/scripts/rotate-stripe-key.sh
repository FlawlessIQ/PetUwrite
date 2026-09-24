#!/usr/bin/env bash
# Rotate the Stripe secret key without it passing through a terminal transcript,
# a shell history, or a chat log.
#
#   1. Create the new key in the Stripe dashboard FIRST (leave the old one live).
#   2. Run this. It prompts silently, validates the key against Stripe, and
#      writes it as a new Secret Manager version.
#   3. Redeploy the functions so they pick the new version up.
#   4. Only then revoke the old key in the dashboard.
#
# That order means there is no window where the functions hold a dead key.
set -euo pipefail
PROJECT=pet-underwriter-ai
SECRET="${1:-STRIPE_SECRET_KEY}"

TOKEN=$(python3 -c "
import json,os
d=json.load(open(os.path.expanduser('~/.config/configstore/firebase-tools.json')))
print(d['tokens']['access_token'])" 2>/dev/null) || {
  echo "Could not read a Firebase CLI token. Run: firebase login" >&2; exit 1; }

printf 'Paste the new %s (input hidden): ' "$SECRET"
read -rs NEWKEY
printf '\n'
[ -n "$NEWKEY" ] || { echo "Nothing entered." >&2; exit 1; }

# Refuse a live key by accident. This project is a sandbox.
case "$SECRET:$NEWKEY" in
  STRIPE_SECRET_KEY:sk_live_*)
    echo "That is a LIVE key. This project is the FlawlessIQ sandbox — refusing." >&2; exit 1 ;;
  STRIPE_SECRET_KEY:sk_test_*) ;;
  STRIPE_WEBHOOK_SECRET:whsec_*) ;;
  *) echo "That does not look like a $SECRET." >&2; exit 1 ;;
esac

# Prove it works before storing it, so a typo cannot take the functions down.
if [ "$SECRET" = "STRIPE_SECRET_KEY" ]; then
  ACCT=$(curl -s https://api.stripe.com/v1/account -u "$NEWKEY:" \
    | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('id') or 'ERROR: '+d.get('error',{}).get('message','unknown'))")
  case "$ACCT" in
    ERROR:*) echo "Stripe rejected it — $ACCT" >&2; exit 1 ;;
    acct_1SI7vTPzjq9wJkU5) echo "Validated against the FlawlessIQ sandbox ($ACCT)." ;;
    *) echo "That key belongs to a DIFFERENT Stripe account ($ACCT). Refusing." >&2; exit 1 ;;
  esac
fi

PAYLOAD=$(printf '%s' "$NEWKEY" | base64 | tr -d '\n')
VER=$(curl -s -X POST \
  "https://secretmanager.googleapis.com/v1/projects/$PROJECT/secrets/$SECRET:addVersion" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d "{\"payload\":{\"data\":\"$PAYLOAD\"}}" \
  | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['name'].split('/')[-1] if 'name' in d else 'ERROR '+json.dumps(d)[:160])")

unset NEWKEY
case "$VER" in
  ERROR*) echo "$VER" >&2; exit 1 ;;
  *) echo "Stored as $SECRET version $VER."
     echo "Next: redeploy the functions, verify, then revoke the old key in Stripe." ;;
esac
