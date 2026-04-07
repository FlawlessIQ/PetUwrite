# Environment Setup Guide

This repo uses two different config paths:

1. Shell environment variables for Cloud Functions, scripts, and local tooling.
2. Flutter `--dart-define` values for a small set of runtime toggles, including Android Firebase when native config is not present in the repo.

## Shell Environment

Start from the root template:

```bash
cp .env.example .env.local
```

The variables most commonly needed for backend work are:

```bash
OPENAI_API_KEY=
GEMINI_API_KEY=
STRIPE_SECRET_KEY=
STRIPE_WEBHOOK_SECRET=
SENDGRID_API_KEY=
SLACK_WEBHOOK_URL=
ADMIN_EMAIL=admin@clovara.com
```

Additional optional values are documented inline in [.env.example](../../.env.example).

Important notes:

- The Flutter app does not automatically load `.env` files.
- Cloud Functions code reads environment variables such as `STRIPE_SECRET_KEY`, `SENDGRID_API_KEY`, `SLACK_WEBHOOK_URL`, `APP_URL`, and `PUBLIC_APP_URL`.
- Some legacy scripts still expect shell-exported variables, so sourcing `.env.local` before running them is the safest default.

## Flutter Runtime Defines

The app supports these useful runtime flags:

```bash
flutter run -d chrome --dart-define=DISABLE_FIREBASE=true
flutter run --dart-define=USE_FIREBASE_EMULATORS=true
flutter run --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1
```

### Android Firebase

This workspace does not include `android/app/google-services.json`, so Android Firebase must be provided explicitly until FlutterFire is re-run or the native config file is added.

Required Android defines:

```bash
flutter run -d android \
  --dart-define=FIREBASE_ANDROID_API_KEY=... \
  --dart-define=FIREBASE_ANDROID_APP_ID=... \
  --dart-define=FIREBASE_ANDROID_PROJECT_ID=pet-underwriter-ai \
  --dart-define=FIREBASE_ANDROID_MESSAGING_SENDER_ID=984654950987 \
  --dart-define=FIREBASE_ANDROID_STORAGE_BUCKET=pet-underwriter-ai.firebasestorage.app
```

If `FIREBASE_ANDROID_API_KEY` or `FIREBASE_ANDROID_APP_ID` is missing, the app now fails with a clear Android Firebase configuration error instead of silently using placeholder values.

## Cloud Functions Setup

Install Functions dependencies locally before doing full backend verification:

```bash
cd functions
npm install
```

Relevant environment variables used by Functions today include:

- `STRIPE_SECRET_KEY`
- `STRIPE_WEBHOOK_SECRET`
- `STRIPE_API_VERSION`
- `SENDGRID_API_KEY`
- `SLACK_WEBHOOK_URL`
- `ADMIN_EMAIL`
- `NOTIFICATION_EMAIL`
- `FROM_EMAIL`
- `APP_URL`
- `PUBLIC_APP_URL`
- `STORAGE_BUCKET`
- `PDF_EXTRACTION_FAILURE_ALERT_THRESHOLD`
- `PDF_EXTRACTION_FAILURE_ALERT_THROTTLE_MINUTES`

## Recommended First-Run Checklist

1. Copy `.env.example` to `.env.local` and fill in the backend secrets you actually need.
2. Run `flutter pub get`.
3. Run `cd functions && npm install`.
4. Supply Android Firebase `--dart-define` values if testing on Android.
5. Run `flutter analyze` and `flutter test`.
