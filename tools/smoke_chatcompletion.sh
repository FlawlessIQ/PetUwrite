#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# Extract Firebase web apiKey from FlutterFire options (public key)
FIREBASE_WEB_API_KEY="$(python3 - <<'PY'
import re
text=open('lib/firebase_options.dart','r',encoding='utf-8').read()
m=re.search(r"static const FirebaseOptions web = FirebaseOptions\([\s\S]*?apiKey:\s*'([^']+)'", text)
if not m:
  raise SystemExit('Could not find web apiKey in lib/firebase_options.dart')
print(m.group(1))
PY
)"

echo "🔑 Getting anonymous Firebase ID token (not printed)..."
ID_TOKEN="$(curl -sS --fail --show-error --no-progress-meter \
  "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${FIREBASE_WEB_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{}" \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["idToken"])')"

PAYLOAD="$(python3 - <<'PY'
import json
print(json.dumps({
  'data': {
    'messages': [{'role':'user','content':'Reply with exactly: ping'}],
    'model': 'gemini-3-pro-preview',
    'temperature': 0.2,
    'maxTokens': 256,
  }
}))
PY
)"

echo "🧪 Calling chatCompletion (expect provider=gemini)..."
TMP_RESP="$(mktemp)"
HTTP_STATUS="$(curl -sS --show-error --no-progress-meter \
  -o "$TMP_RESP" \
  -w '%{http_code}' \
  "https://us-central1-pet-underwriter-ai.cloudfunctions.net/chatCompletion" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${ID_TOKEN}" \
  -d "$PAYLOAD")"

RESP="$(cat "$TMP_RESP")"
rm -f "$TMP_RESP"

echo "HTTP $HTTP_STATUS"

if [[ "$HTTP_STATUS" != "200" ]]; then
  echo "Response (first 1000 chars):"
  echo "${RESP:0:1000}"
  exit 1
fi

REQUIRE_PROVIDER="${REQUIRE_PROVIDER:-}" RESP="$RESP" python3 - <<'PY'
import json, os, sys
resp=os.environ.get('RESP')
if not resp:
  raise SystemExit('Missing RESP env var')
data=json.loads(resp)
payload=data.get('result') or data.get('data') or data
provider=(payload or {}).get('provider')
model_used=(payload or {}).get('modelUsed')
message=(payload or {}).get('message')
require_provider=(os.environ.get('REQUIRE_PROVIDER') or '').strip().lower()
print('provider=', provider)
print('modelUsed=', model_used)
print('message=', message)
provider_norm=(provider or '').strip().lower()
if require_provider and provider_norm != require_provider:
  raise SystemExit(f'Expected provider={require_provider}, got {provider}')
if provider_norm not in ('gemini','openai'):
  raise SystemExit(f'Expected provider gemini/openai, got {provider}')

msg=(message or '').strip().lower()
if provider_norm == 'gemini':
  if msg != 'ping':
    raise SystemExit(f'Expected message "ping" from Gemini, got {message!r}')
else:
  # OpenAI can be chatty or respond with 'pong' to 'ping' prompts; accept either.
  if msg not in ('ping','pong'):
    raise SystemExit(f'Expected message ping/pong from OpenAI fallback, got {message!r}')

print('✅ chatCompletion smoke test passed')
PY
