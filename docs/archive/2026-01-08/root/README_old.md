# PetUwrite - AI-Powered Pet Insurance Platform# Pet Underwriter AI



**An intelligent pet insurance underwriting platform powered by AI and Flutter.**A Flutter application for pet insurance underwriting powered by AI technology. This app allows pet owners to get instant insurance quotes, upload veterinary records, and purchase pet insurance policies.



![Status](https://img.shields.io/badge/status-active-success)## Project Structure

![Flutter](https://img.shields.io/badge/Flutter-3.x-blue)

![Firebase](https://img.shields.io/badge/Firebase-enabled-orange)```

lib/

---├── screens/           # UI screens

│   ├── onboarding_screen.dart

## 🎯 Overview│   ├── quote_flow_screen.dart

│   ├── plan_selection_screen.dart

PetUwrite is a modern pet insurance platform that leverages AI to provide:│   ├── checkout_screen.dart

- **Instant Quotes** - Get pet insurance quotes in minutes through conversational AI│   └── policy_confirmation_screen.dart

- **Smart Underwriting** - AI-powered risk assessment with explainability│

- **Admin Dashboard** - Comprehensive management tools for underwriters├── models/           # Data models

- **Real-time Rules** - Dynamic underwriting rules without code deployment│   ├── pet.dart

│   ├── owner.dart

---│   ├── quote.dart

│   ├── risk_score.dart

## ✨ Key Features│   └── policy.dart

│

### For Customers├── services/         # Business logic services

- 🤖 **Conversational Quote Flow** - AI-guided insurance quotes│   ├── firebase_service.dart

- 📱 **Responsive Design** - Works on web, iOS, and Android│   ├── vet_history_parser.dart

- 🔐 **Secure Authentication** - Firebase Auth with role-based access│   ├── risk_scoring_engine.dart

- 💳 **Integrated Payments** - Secure checkout with Stripe│   ├── payment_processor.dart

- 📄 **Policy Management** - View and manage active policies│   └── policy_issuance.dart

│

### For Admins (userRole 2+)├── widgets/          # Reusable UI components

- 📊 **Admin Dashboard** with 4 tabs:│   ├── custom_stepper.dart

  - **High Risk Review** - Override AI decisions with explainability charts│   ├── plan_card.dart

  - **Ineligible Quotes** - Manage eligibility exceptions│   └── input_forms.dart

  - **Claims Analytics** - Business intelligence and trends│

  - **Rules Editor** - Real-time underwriting rule configuration├── providers/        # State management (Provider)

- 🔍 **Explainability** - Visual breakdown of AI decisions│   ├── quote_provider.dart

- 📝 **Audit Logging** - Track all admin actions│   ├── pet_provider.dart

- ⚙️ **Dynamic Rules** - Update underwriting criteria instantly│   └── policy_provider.dart

│

---└── ai/              # AI integration

    ├── ai_service.dart

## 🚀 Quick Start    ├── vet_record_ai_parser.dart

    └── risk_scoring_ai.dart

### Prerequisites```

- Flutter 3.x

- Node.js 16+## Features

- Firebase CLI

- Firebase project setup### Screens

- **Onboarding**: Welcome flow introducing the app features

### Installation- **Quote Flow**: Multi-step form for collecting pet and owner information

- **Plan Selection**: Compare and choose insurance coverage plans

1. **Clone the repository**- **Checkout**: Payment processing and policy purchase

   ```bash- **Policy Confirmation**: Success screen with policy details

   git clone <repository-url>

   cd PetUwrite### Models

   ```- **Pet**: Pet information (name, species, breed, age, medical history)

- **Owner**: Pet owner details and contact information

2. **Install dependencies**- **Quote**: Insurance quote with available plans

   ```bash- **RiskScore**: AI-powered risk assessment

   flutter pub get- **Policy**: Active insurance policy details

   cd functions && npm install && cd ..

   ```### Services

- **FirebaseService**: Firebase integration for data persistence

3. **Configure environment**- **VetHistoryParser**: Parse veterinary records

   ```bash- **RiskScoringEngine**: Calculate insurance risk scores

   cp .env.example .env- **PaymentProcessor**: Handle payment transactions

   # Edit .env with your API keys- **PolicyIssuance**: Issue and manage insurance policies

   ```

### AI Integration

4. **Setup Firebase**- **GPTService**: OpenAI GPT integration for text analysis

   ```bash- **VertexAIService**: Google Vertex AI integration

   firebase login- **VetRecordAIParser**: AI-powered veterinary record parsing

   firebase use <your-project-id>- **RiskScoringAI**: AI-enhanced risk assessment and predictions

   ```

## Setup

5. **Deploy Firestore rules and indexes**

   ```bash### Prerequisites

   firebase deploy --only firestore:rules,firestore:indexes- Flutter SDK (>= 3.8.0)

   ```- Dart SDK

- Firebase account (for backend services)

6. **Seed underwriting rules** (required for first run)- OpenAI or Google Cloud account (for AI features)

   ```bash

   ./seed_rules.sh### Installation

   ```

1. Install dependencies

7. **Run the app**```bash

   ```bashflutter pub get

   flutter run -d chrome```

   ```

2. Configure Firebase

---   - Add your google-services.json (Android) and GoogleService-Info.plist (iOS)

   - Update firebase_options.dart with your Firebase configuration

## 📚 Documentation

3. Configure AI Services

### Essential Guides   - Add API keys for GPT or Vertex AI

- **[Architecture](docs/ARCHITECTURE.md)** - System design and architecture

- **[Roadmap](ROADMAP.md)** - Feature roadmap and milestones4. Run the app

```bash

### Setup & Configurationflutter run

- [Firebase Setup](docs/setup/FIREBASE_SETUP.md)```

- [Environment Setup](docs/setup/ENV_SETUP_GUIDE.md)

- [Authentication Setup](docs/setup/AUTH_SETUP_GUIDE.md)## Dependencies

- [Firestore Security Rules](docs/setup/FIRESTORE_SECURITY_RULES.md)

- [Seed Underwriting Rules](docs/setup/SEED_UNDERWRITING_RULES_SETUP.md)- `provider`: State management

- `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`: Firebase services

### Feature Guides- `http`: HTTP requests for AI APIs

- [Explainability System](docs/guides/EXPLAINABILITY_GUIDE.md)- `file_picker`, `image_picker`: File handling

- [Claims Analytics](docs/guides/CLAIMS_ANALYTICS_GUIDE.md)- `pdf`: PDF generation for policies

- [Eligibility Integration](docs/guides/ELIGIBILITY_INTEGRATION_GUIDE.md)- `intl`: Date formatting

- [Underwriting Rules Engine](docs/guides/UNDERWRITING_RULES_ENGINE_GUIDE.md)

- [Unauthenticated Flow](docs/guides/UNAUTHENTICATED_FLOW_GUIDE.md)## TODO / Next Steps



### Admin Documentation- [ ] Initialize Firebase in main.dart

- [Admin Dashboard Features](docs/admin/ADMIN_DASHBOARD_FEATURES_SUMMARY.md)- [ ] Add authentication screens

- [Admin Dashboard Status](docs/admin/ADMIN_DASHBOARD_STATUS.md)- [ ] Integrate payment gateway (Stripe)

- [Rules Editor Guide](docs/admin/ADMIN_RULES_EDITOR_GUIDE.md)- [ ] Implement file upload for vet records

- [Ineligible Quotes Management](docs/admin/ADMIN_INELIGIBLE_QUOTES_GUIDE.md)- [ ] Complete AI service integration

- [Override Eligibility Guide](docs/admin/ADMIN_OVERRIDE_ELIGIBILITY_GUIDE.md)- [ ] Add tests

- [ ] Implement claims flow

### Implementation Details

See [docs/implementation/](docs/implementation/) for phase-by-phase implementation summaries## Getting Started with Flutter



---For help getting started with Flutter development, view the

[online documentation](https://docs.flutter.dev/), which offers tutorials,

## 🏗️ Project Structuresamples, guidance on mobile development, and a full API reference.


```
PetUwrite/
├── lib/
│   ├── screens/          # UI screens
│   ├── widgets/          # Reusable widgets
│   ├── models/           # Data models
│   ├── services/         # Business logic & API calls
│   ├── auth/            # Authentication screens
│   └── theme/           # App theming
├── functions/           # Firebase Cloud Functions
│   └── seed_underwriting_rules.js
├── assets/              # Images, logos
├── docs/               # Documentation
│   ├── admin/          # Admin guides
│   ├── guides/         # Feature guides
│   ├── setup/          # Setup instructions
│   └── implementation/ # Implementation details
├── firestore.rules     # Firestore security rules
├── firestore.indexes.json  # Firestore indexes
└── seed_rules.sh       # Helper script for seeding rules
```

---

## 🔑 Environment Variables

Required in `.env` file:

```env
# OpenAI API (for AI features)
OPENAI_API_KEY=your_openai_api_key_here

# Stripe (for payments)
STRIPE_PUBLISHABLE_KEY=your_stripe_key_here
STRIPE_SECRET_KEY=your_stripe_secret_here

# Firebase (auto-configured from Firebase project)
FIREBASE_API_KEY=...
FIREBASE_PROJECT_ID=...
```

See [.env.example](.env.example) for complete list.

---

## 👥 User Roles

The platform supports role-based access:

| Role | userRole | Access |
|------|----------|---------|
| Customer | 0 | Get quotes, purchase policies |
| Premium Customer | 1 | Enhanced features |
| Admin/Underwriter | 2 | Full admin dashboard access |
| Super Admin | 3 | All features + user management |

Set user roles in Firestore: `users/{userId}/userRole`

---

## 🧪 Testing Admin Features

To test admin dashboard:

1. **Create admin user in Firestore:**
   ```javascript
   // In Firebase Console > Firestore
   users/{userId}
   {
     email: "admin@test.com",
     userRole: 2,
     createdAt: <timestamp>
   }
   ```

2. **Login with admin email**

3. **Access admin dashboard** (automatic redirect for userRole 2+)

4. **Test features:**
   - High Risk tab: Review AI decisions
   - Ineligible tab: Manage exceptions (wait 2-5 min for index after first deploy)
   - Claims Analytics: View business data
   - Rules Editor: Update underwriting rules

---

## 🛠️ Common Tasks

### Update Underwriting Rules
```bash
# Option 1: Via Admin Dashboard (Recommended)
# Login as admin → Rules Editor tab → Make changes → Save

# Option 2: Via Script
./seed_rules.sh
```

### Deploy Changes
```bash
# Deploy everything
firebase deploy

# Deploy specific targets
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
firebase deploy --only functions
```

### Hot Reload (Development)
```bash
flutter run -d chrome
# Press 'r' for hot reload
# Press 'R' for hot restart
```

---

## 🐛 Troubleshooting

### "Index required" error in Ineligible tab
**Solution:** Wait 2-5 minutes for Firestore index to build after first deployment. See [Admin Dashboard Status](docs/admin/ADMIN_DASHBOARD_STATUS.md).

### Underwriting rules not loading
**Solution:** Run `./seed_rules.sh` to initialize rules in Firestore.

### Authentication errors
**Solution:** Check Firebase Auth is enabled. See [Auth Setup Guide](docs/setup/AUTH_SETUP_GUIDE.md).

### API key errors
**Solution:** Verify `.env` file exists and contains valid API keys.

---

## 📦 Tech Stack

- **Frontend:** Flutter 3.x (Web, iOS, Android)
- **Backend:** Firebase (Auth, Firestore, Functions)
- **AI:** OpenAI GPT-4
- **Payments:** Stripe
- **State Management:** Provider
- **UI:** Material Design 3

---

## 📈 Development Status

✅ **Production Ready Features:**
- Conversational quote flow with AI avatar
- Risk scoring engine with explainability
- Admin dashboard (4 tabs)
- Authentication & authorization
- Firestore security rules
- Payment integration
- Policy management

🚧 **In Development:**
- Claims filing system
- Email notifications
- Advanced analytics

See [ROADMAP.md](ROADMAP.md) for full feature list.

---

## 🤝 Contributing

1. Create a feature branch
2. Make your changes
3. Test thoroughly
4. Submit a pull request

---

## 📄 License

[Your License Here]

---

## 🆘 Support

For issues or questions:
- Check [docs/](docs/) for detailed guides
- Review [troubleshooting section](#-troubleshooting)
- Create an issue in the repository

---

## 🎯 Quick Commands Reference

```bash
# Development
flutter run -d chrome                    # Run app in Chrome
flutter pub get                          # Install dependencies

# Firebase
firebase deploy --only firestore:rules   # Deploy security rules
firebase deploy --only firestore:indexes # Deploy indexes
./seed_rules.sh                         # Seed underwriting rules

# Admin Testing
# 1. Set userRole=2 in Firestore users collection
# 2. Login and access admin dashboard
# 3. Test all 4 tabs: High Risk, Ineligible, Claims Analytics, Rules Editor

# Production
flutter build web                        # Build for web
firebase deploy                          # Deploy everything
```

---

**Built with ❤️ for pet owners and their furry friends** 🐾
