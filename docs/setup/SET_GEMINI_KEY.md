# Set Gemini API Key (Server-side)

For security, **do not** put API keys into Flutter `--dart-define` or commit them into `.env` tracked by git.

This project now expects a Secret Manager secret named `GEMINI_API_KEY` in the `pet-underwriter-ai` GCP project.

## 1) Create / update secret value

Run this locally (it will prompt-free set the secret version from stdin):

```bash
export GEMINI_API_KEY="<PASTE_YOUR_GEMINI_API_KEY_HERE>"
printf "%s" "$GEMINI_API_KEY" | gcloud secrets versions add GEMINI_API_KEY \
  --project=pet-underwriter-ai \
  --data-file=-
```

If you accidentally committed or shared a key, rotate it in Google AI Studio and add the new value as a new Secret Manager version.

## 2) Deploy functions

```bash
./deploy_functions.sh
```

## 3) Verify

In logs you should see `chatCompletion provider: gemini` and a `200` response for the callable.
