# setup/ — one-time setup, per system

Each of these is something you do once per environment or per machine. None of
them is a deployment guide: **deploying is `../DEPLOYMENT.md`.**

| | |
|---|---|
| [ENV_SETUP_GUIDE.md](ENV_SETUP_GUIDE.md) | Environment variables and local configuration |
| [FIREBASE_SETUP.md](FIREBASE_SETUP.md) | Firebase and Stripe, together |
| [FIREBASE_AUTH_SETUP_GUIDE.md](FIREBASE_AUTH_SETUP_GUIDE.md) · [AUTH_SETUP_GUIDE.md](AUTH_SETUP_GUIDE.md) | Auth providers, then role-based access |
| [FIRESTORE_SECURITY_RULES.md](FIRESTORE_SECURITY_RULES.md) · [FIRESTORE_RULES_DEPLOYMENT.md](FIRESTORE_RULES_DEPLOYMENT.md) | The underwriting product's rules, and how to ship them |
| [POLICY_FUNCTIONS_SETUP.md](POLICY_FUNCTIONS_SETUP.md) | The policy Cloud Functions |
| [DECLINED_QUOTE_NOTIFICATIONS_SETUP.md](DECLINED_QUOTE_NOTIFICATIONS_SETUP.md) | The declined-quote notification function |
| [VET_RECORD_IMAGE_OCR_SETUP.md](VET_RECORD_IMAGE_OCR_SETUP.md) · [google_vision_setup.md](google_vision_setup.md) | Google Cloud Vision, for vet-record OCR |
| [SEED_UNDERWRITING_RULES_QUICK_START.md](SEED_UNDERWRITING_RULES_QUICK_START.md) · [_SETUP](SEED_UNDERWRITING_RULES_SETUP.md) · [_README](SEED_UNDERWRITING_RULES_README.md) | Seeding the rules collection, three times over |

**Two traps in here.**

- `DEPLOYMENT_CHECKLIST.md` is a **checkout-flow** checklist despite the name. It
  is not how you deploy the site.
- The Firestore rules documents describe the **underwriting** collections.
  Clovara Life's block is the same file but a different audience — see
  `../FIRESTORE-REVIEW-BRIEF.md`.
