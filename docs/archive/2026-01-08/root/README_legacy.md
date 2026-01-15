# 🐾 Clovara AI# Clovara - AI-Powered Pet Insurance Platform# Pet Underwriter AI



![Status](https://img.shields.io/badge/status-active-success)

![Flutter](https://img.shields.io/badge/Flutter-3.x-blue)

![Firebase](https://img.shields.io/badge/Firebase-enabled-orange)**An intelligent pet insurance underwriting platform powered by AI and Flutter.**A Flutter application for pet insurance underwriting powered by AI technology. This app allows pet owners to get instant insurance quotes, upload veterinary records, and purchase pet insurance policies.

![License](https://img.shields.io/badge/license-MIT-green)



> **Intelligent pet insurance underwriting platform with emotional intelligence**

![Status](https://img.shields.io/badge/status-active-success)## Project Structure

Clovara transforms the pet insurance experience with AI-powered underwriting, real-time claims processing, and an empathetic user interface featuring **Pawla**, your AI assistant.

![Flutter](https://img.shields.io/badge/Flutter-3.x-blue)

---

![Firebase](https://img.shields.io/badge/Firebase-enabled-orange)```

## 🎯 Overview

lib/

Clovara is a comprehensive pet insurance platform that combines cutting-edge AI technology with human-centered design to make pet insurance simple, transparent, and fair.

---├── screens/           # UI screens

### Key Highlights

│   ├── onboarding_screen.dart

- **🤖 AI-Powered Underwriting** - Instant risk assessment with explainable AI decisions

- **💜 Emotional Intelligence** - Pawla avatar with 6 expressions provides empathy throughout the claims journey## 🎯 Overview│   ├── quote_flow_screen.dart

- **📊 Advanced Analytics** - BI panel with fraud detection, time-to-settlement metrics, and CSV/email exports

- **⚡ Real-Time Processing** - Live claim tracking with contextual status updates│   ├── plan_selection_screen.dart

- **🔍 Complete Transparency** - Factor analysis showing exactly why AI made each decision

- **📱 Cross-Platform** - Works on web, iOS, Android, and desktopClovara is a modern pet insurance platform that leverages AI to provide:│   ├── checkout_screen.dart



---- **Instant Quotes** - Get pet insurance quotes in minutes through conversational AI│   └── policy_confirmation_screen.dart



## ✨ Features- **Smart Underwriting** - AI-powered risk assessment with explainability│



### For Customers- **Admin Dashboard** - Comprehensive management tools for underwriters├── models/           # Data models



#### Quote & Purchase Flow- **Real-time Rules** - Dynamic underwriting rules without code deployment│   ├── pet.dart

- **Conversational Quote Engine** - AI-guided questions to get accurate quotes

- **Smart Risk Scoring** - Analyzes breed, age, location, and medical history│   ├── owner.dart

- **Plan Comparison** - Side-by-side coverage options with recommendations

- **Instant Checkout** - Secure payment processing with Stripe---│   ├── quote.dart



#### Claims Experience│   ├── risk_score.dart

- **Pawla Avatar** - Empathetic AI assistant with 6 emotional expressions

  - 😊 Happy - Welcome messages and positive updates## ✨ Key Features│   └── policy.dart

  - 🤔 Thinking - Processing documents and decisions

  - 💗 Empathetic - Supporting during denials or delays│

  - 🎉 Celebrating - Claim approved!

  - 😟 Concerned - Issues detected### For Customers├── services/         # Business logic services

  - ⚙️ Working - Active analysis

- 🤖 **Conversational Quote Flow** - AI-guided insurance quotes│   ├── firebase_service.dart

- **Interactive Timeline** - Visual journey through 5 claim stages:

  1. Claim Filed ✓- 📱 **Responsive Design** - Works on web, iOS, and Android│   ├── vet_history_parser.dart

  2. Documents Review ⏳

  3. AI Analysis 🤖- 🔐 **Secure Authentication** - Firebase Auth with role-based access│   ├── risk_scoring_engine.dart

  4. Human Review (if needed) 👤

  5. Final Decision ✅- 💳 **Integrated Payments** - Secure checkout with Stripe│   ├── payment_processor.dart



- **Real-Time Updates** - Contextual messages based on claim state:- 📄 **Policy Management** - View and manage active policies│   └── policy_issuance.dart

  - "I'm analyzing your 3 documents right now..."

  - "Almost done! Your claim looks great..."│

  - "Our team is carefully reviewing..."

### For Admins (userRole 2+)├── widgets/          # Reusable UI components

- **AI Explainability** - Transparent factor analysis showing:

  - Contributing factors with impact percentages- 📊 **Admin Dashboard** with 4 tabs:│   ├── custom_stepper.dart

  - Positive/negative influences (SHAP-style visualization)

  - Key insights in plain language  - **High Risk Review** - Override AI decisions with explainability charts│   ├── plan_card.dart

  - Confidence level breakdown

  - **Ineligible Quotes** - Manage eligibility exceptions│   └── input_forms.dart

- **Sentiment Feedback** - "Was this fair?" rating system

  - 3-option feedback (Fair/Neutral/Unfair)  - **Claims Analytics** - Business intelligence and trends│

  - Optional comments

  - Logged for AI training and improvement  - **Rules Editor** - Real-time underwriting rule configuration├── providers/        # State management (Provider)



### For Administrators- 🔍 **Explainability** - Visual breakdown of AI decisions│   ├── quote_provider.dart



#### Admin Dashboard- 📝 **Audit Logging** - Track all admin actions│   ├── pet_provider.dart

- **Claims Review** - Real-time claim queue with priority sorting

- **Human Override** - Review and override AI decisions with reasoning- ⚙️ **Dynamic Rules** - Update underwriting criteria instantly│   └── policy_provider.dart

- **Reconciliation System** - Audit trail for all decision changes

- **Rules Editor** - Modify underwriting rules without code deployment│



#### Business Intelligence Panel---└── ai/              # AI integration

- **Summary Metrics**

  - Total claims and payouts    ├── ai_service.dart

  - Auto-approval rate

  - Average AI confidence## 🚀 Quick Start    ├── vet_record_ai_parser.dart

  - Settlement times (mean, P90, P99)

    └── risk_scoring_ai.dart

- **Advanced Analytics**

  - Average payout by breed, region, and claim type### Prerequisites```

  - AI confidence histogram (10% buckets)

  - Auto-approval vs manual review trends- Flutter 3.x

  - Fraud detection accuracy

  - Time-to-settlement percentiles- Node.js 16+## Features



- **Export & Sharing**- Firebase CLI

  - CSV export (8-section reports)

  - Email sharing with beautiful HTML templates- Firebase project setup### Screens

  - CSV attachments for detailed analysis

- **Onboarding**: Welcome flow introducing the app features

---

### Installation- **Quote Flow**: Multi-step form for collecting pet and owner information

## 🏗️ Architecture

- **Plan Selection**: Compare and choose insurance coverage plans

### Technology Stack

1. **Clone the repository**- **Checkout**: Payment processing and policy purchase

**Frontend:**

- Flutter 3.x (Dart)   ```bash- **Policy Confirmation**: Success screen with policy details

- Material Design 3

- Custom animations & CustomPainter   git clone <repository-url>

- Provider for state management

   cd Clovara### Models

**Backend:**

- Firebase (Firestore, Auth, Functions, Storage)   ```- **Pet**: Pet information (name, species, breed, age, medical history)

- Node.js Cloud Functions

- SendGrid for email delivery- **Owner**: Pet owner details and contact information

- OpenAI API for AI capabilities

2. **Install dependencies**- **Quote**: Insurance quote with available plans

**Infrastructure:**

- GitHub Actions (CI/CD)   ```bash- **RiskScore**: AI-powered risk assessment

- Firebase Hosting

- Firestore indexes for query optimization   flutter pub get- **Policy**: Active insurance policy details



### Project Structure   cd functions && npm install && cd ..



```   ```### Services

Clovara/

├── lib/- **FirebaseService**: Firebase integration for data persistence

│   ├── screens/               # UI screens

│   │   ├── homepage.dart3. **Configure environment**- **VetHistoryParser**: Parse veterinary records

│   │   ├── conversational_quote_flow.dart

│   │   ├── plan_selection_screen.dart   ```bash- **RiskScoringEngine**: Calculate insurance risk scores

│   │   ├── checkout_screen.dart

│   │   ├── claims/   cp .env.example .env- **PaymentProcessor**: Handle payment transactions

│   │   │   └── claim_intake_screen.dart

│   │   └── admin/   # Edit .env with your API keys- **PolicyIssuance**: Issue and manage insurance policies

│   │       ├── claims_analytics_tab.dart

│   │       └── claims_review_tab.dart   ```

│   ├── widgets/               # Reusable widgets

│   │   ├── pawla_avatar.dart         # 6-expression AI avatar### AI Integration

│   │   ├── claim_timeline_widget.dart # 5-stage timeline

│   │   ├── ai_explainability_widget.dart # Factor analysis4. **Setup Firebase**- **GPTService**: OpenAI GPT integration for text analysis

│   │   └── sentiment_feedback_widget.dart # "Was this fair?"

│   ├── services/              # Business logic   ```bash- **VertexAIService**: Google Vertex AI integration

│   │   ├── claim_tracker_service.dart    # Real-time messages

│   │   ├── claim_decision_engine.dart    # AI decisions   firebase login- **VetRecordAIParser**: AI-powered veterinary record parsing

│   │   ├── csv_export_service.dart       # Analytics export

│   │   ├── analytics_email_service.dart  # Email sharing   firebase use <your-project-id>- **RiskScoringAI**: AI-enhanced risk assessment and predictions

│   │   ├── quote_engine.dart

│   │   ├── risk_scoring_engine.dart   ```

│   │   └── underwriting_rules_engine.dart

│   ├── models/                # Data models## Setup

│   │   ├── claim.dart

│   │   ├── pet.dart5. **Deploy Firestore rules and indexes**

│   │   ├── quote.dart

│   │   └── policy.dart   ```bash### Prerequisites

│   └── theme/

│       └── clovara_theme.dart   firebase deploy --only firestore:rules,firestore:indexes- Flutter SDK (>= 3.8.0)

├── functions/                 # Cloud Functions

│   ├── claimsAnalytics.js     # Analytics aggregation   ```- Dart SDK

│   ├── analyticsEmail.js      # Email sending

│   ├── claimsReconciliation.js- Firebase account (for backend services)

│   ├── pdfExtraction.js

│   └── policyEmails.js6. **Seed underwriting rules** (required for first run)- OpenAI or Google Cloud account (for AI features)

├── docs/                      # Documentation

│   ├── implementation/   ```bash

│   │   ├── EMOTIONAL_INTELLIGENCE_SYSTEM.md  # Full EI guide

│   │   └── BI_PANEL_SYSTEM.md                # Analytics guide   ./seed_rules.sh### Installation

│   ├── guides/

│   └── setup/   ```

├── assets/                    # Images & fonts

└── test/                      # Unit tests1. Install dependencies

```

7. **Run the app**```bash

---

   ```bashflutter pub get

## 🚀 Getting Started

   flutter run -d chrome```

### Prerequisites

   ```

- Flutter 3.x or higher

- Dart SDK 3.x or higher2. Configure Firebase

- Firebase project with Firestore, Auth, Functions, and Storage

- OpenAI API key---   - Add your google-services.json (Android) and GoogleService-Info.plist (iOS)

- (Optional) SendGrid API key for email features

   - Update firebase_options.dart with your Firebase configuration

### Installation

## 📚 Documentation

1. **Clone the repository**

   ```bash3. Configure AI Services

   git clone https://github.com/FlawlessIQ/Clovara.git

   cd Clovara### Essential Guides   - Add API keys for GPT or Vertex AI

   ```

- **[Architecture](docs/ARCHITECTURE.md)** - System design and architecture

2. **Install dependencies**

   ```bash- **[Roadmap](ROADMAP.md)** - Feature roadmap and milestones4. Run the app

   flutter pub get

   cd functions && npm install && cd ..```bash

   ```

### Setup & Configurationflutter run

3. **Set up environment variables**

   - [Firebase Setup](docs/setup/FIREBASE_SETUP.md)```

   Create `.env` file in project root:

   ```bash- [Environment Setup](docs/setup/ENV_SETUP_GUIDE.md)

   OPENAI_API_KEY=your-openai-api-key-here

   ```- [Authentication Setup](docs/setup/AUTH_SETUP_GUIDE.md)## Dependencies



4. **Configure Firebase**- [Firestore Security Rules](docs/setup/FIRESTORE_SECURITY_RULES.md)

   

   - Copy your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)- [Seed Underwriting Rules](docs/setup/SEED_UNDERWRITING_RULES_SETUP.md)- `provider`: State management

   - Update `firebase_options.dart` with your Firebase config

   - Place Firebase service account JSON in `functions/` (add to `.gitignore`)- `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`: Firebase services



5. **Deploy Firestore rules and indexes**### Feature Guides- `http`: HTTP requests for AI APIs

   ```bash

   firebase deploy --only firestore:rules,firestore:indexes- [Explainability System](docs/guides/EXPLAINABILITY_GUIDE.md)- `file_picker`, `image_picker`: File handling

   ```

- [Claims Analytics](docs/guides/CLAIMS_ANALYTICS_GUIDE.md)- `pdf`: PDF generation for policies

6. **Deploy Cloud Functions**

   ```bash- [Eligibility Integration](docs/guides/ELIGIBILITY_INTEGRATION_GUIDE.md)- `intl`: Date formatting

   cd functions

   npm install- [Underwriting Rules Engine](docs/guides/UNDERWRITING_RULES_ENGINE_GUIDE.md)

   firebase deploy --only functions

   ```- [Unauthenticated Flow](docs/guides/UNAUTHENTICATED_FLOW_GUIDE.md)## TODO / Next Steps



7. **Run the app**

   ```bash

   flutter run### Admin Documentation- [ ] Initialize Firebase in main.dart

   ```

- [Admin Dashboard Features](docs/admin/ADMIN_DASHBOARD_FEATURES_SUMMARY.md)- [ ] Add authentication screens

### Configuration

- [Admin Dashboard Status](docs/admin/ADMIN_DASHBOARD_STATUS.md)- [ ] Integrate payment gateway (Stripe)

#### SendGrid (Email Sharing)

- [Rules Editor Guide](docs/admin/ADMIN_RULES_EDITOR_GUIDE.md)- [ ] Implement file upload for vet records

```bash

firebase functions:config:set \- [Ineligible Quotes Management](docs/admin/ADMIN_INELIGIBLE_QUOTES_GUIDE.md)- [ ] Complete AI service integration

  sendgrid.api_key="YOUR_SENDGRID_API_KEY" \

  sendgrid.from_email="analytics@yourdomain.com" \- [Override Eligibility Guide](docs/admin/ADMIN_OVERRIDE_ELIGIBILITY_GUIDE.md)- [ ] Add tests

  sendgrid.from_name="Clovara Analytics"

```- [ ] Implement claims flow



#### Stripe (Payments)### Implementation Details



Add to `.env`:See [docs/implementation/](docs/implementation/) for phase-by-phase implementation summaries## Getting Started with Flutter

```bash

STRIPE_PUBLISHABLE_KEY=pk_test_...

```

---For help getting started with Flutter development, view the

---

[online documentation](https://docs.flutter.dev/), which offers tutorials,

## 📚 Documentation

## 🏗️ Project Structuresamples, guidance on mobile development, and a full API reference.

### Quick References



- **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Cheat sheet for integration```

- **[ROADMAP.md](ROADMAP.md)** - Feature roadmap and prioritiesClovara/

├── lib/

### Implementation Guides│   ├── screens/          # UI screens

│   ├── widgets/          # Reusable widgets

- **[Emotional Intelligence System](docs/implementation/EMOTIONAL_INTELLIGENCE_SYSTEM.md)**│   ├── models/           # Data models

  - Complete guide to Pawla avatar, timeline, explainability, and sentiment feedback│   ├── services/         # Business logic & API calls

  - Integration patterns and testing scenarios│   ├── auth/            # Authentication screens

  │   └── theme/           # App theming

- **[BI Panel System](docs/implementation/BI_PANEL_SYSTEM.md)**├── functions/           # Firebase Cloud Functions

  - Analytics metrics reference│   └── seed_underwriting_rules.js

  - CSV export and email sharing├── assets/              # Images, logos

  - Chart implementation examples├── docs/               # Documentation

│   ├── admin/          # Admin guides

### Setup Guides│   ├── guides/         # Feature guides

│   ├── setup/          # Setup instructions

- **[Environment Setup](docs/setup/ENV_SETUP_GUIDE.md)** - API keys and configuration│   └── implementation/ # Implementation details

- **[Firebase Setup](docs/setup/FIREBASE_SETUP.md)** - Firestore, Auth, Functions├── firestore.rules     # Firestore security rules

- **[Deployment Checklist](docs/setup/DEPLOYMENT_CHECKLIST.md)** - Production readiness├── firestore.indexes.json  # Firestore indexes

└── seed_rules.sh       # Helper script for seeding rules

---```



## 🎨 Design Philosophy---



### Emotional Intelligence## 🔑 Environment Variables



Clovara is built on the principle that insurance claims are stressful for pet owners. Our emotional intelligence system:Required in `.env` file:



1. **Shows Empathy** - Pawla's expressions match the emotional context```env

2. **Provides Transparency** - Users always know what's happening and why# OpenAI API (for AI features)

3. **Builds Trust** - Explainability shows AI reasoning in plain languageOPENAI_API_KEY=your_openai_api_key_here

4. **Empowers Users** - Sentiment feedback gives users a voice

# Stripe (for payments)

### User Journey ExampleSTRIPE_PUBLISHABLE_KEY=your_stripe_key_here

STRIPE_SECRET_KEY=your_stripe_secret_here

```

User submits claim with documents# Firebase (auto-configured from Firebase project)

         ↓FIREBASE_API_KEY=...

Pawla: "I'm analyzing your 3 documents right now..." (Working expression)FIREBASE_PROJECT_ID=...

         ↓```

Timeline shows: Documents Review ✓, AI Analysis ⏳

         ↓See [.env.example](.env.example) for complete list.

AI analyzes → 92% confidence approval

         ↓---

Pawla: "Almost done! Your claim looks great..." (Happy expression)

         ↓## 👥 User Roles

Claim auto-approved

         ↓The platform supports role-based access:

Pawla: "🎉 Great news! Your claim has been approved!" (Celebrating)

         ↓| Role | userRole | Access |

Timeline shows: All stages complete ✓|------|----------|---------|

         ↓| Customer | 0 | Get quotes, purchase policies |

Explainability expands showing 4 positive factors| Premium Customer | 1 | Enhanced features |

         ↓| Admin/Underwriter | 2 | Full admin dashboard access |

"Was this fair?" → User rates: Fair 👍| Super Admin | 3 | All features + user management |

```

Set user roles in Firestore: `users/{userId}/userRole`

---

---

## 🧪 Testing

## 🧪 Testing Admin Features

### Run Tests

To test admin dashboard:

```bash

# Unit tests1. **Create admin user in Firestore:**

flutter test   ```javascript

   // In Firebase Console > Firestore

# Integration tests   users/{userId}

flutter test integration_test/   {

     email: "admin@test.com",

# Specific test file     userRole: 2,

flutter test test/services/claim_tracker_service_test.dart     createdAt: <timestamp>

```   }

   ```

### Test Coverage

2. **Login with admin email**

```bash

flutter test --coverage3. **Access admin dashboard** (automatic redirect for userRole 2+)

genhtml coverage/lcov.info -o coverage/html

open coverage/html/index.html4. **Test features:**

```   - High Risk tab: Review AI decisions

   - Ineligible tab: Manage exceptions (wait 2-5 min for index after first deploy)

---   - Claims Analytics: View business data

   - Rules Editor: Update underwriting rules

## 📊 Analytics & Monitoring

---

### Key Metrics

## 🛠️ Common Tasks

- **Auto-Approval Rate** - Target: 80-85%

- **AI Confidence (avg)** - Target: >80%### Update Underwriting Rules

- **Fraud Detection Accuracy** - Target: >85%```bash

- **Time-to-Settlement (mean)** - Target: <48 hours# Option 1: Via Admin Dashboard (Recommended)

- **Time-to-Settlement (P90)** - Target: <72 hours# Login as admin → Rules Editor tab → Make changes → Save



### Firebase Console# Option 2: Via Script

./seed_rules.sh

Monitor in real-time:```

- Claims processing queue

- AI decision accuracy### Deploy Changes

- User sentiment feedback```bash

- Email delivery rates# Deploy everything

- Function execution timesfirebase deploy



---# Deploy specific targets

firebase deploy --only firestore:rules

## 🤝 Contributingfirebase deploy --only firestore:indexes

firebase deploy --only functions

We welcome contributions! Please see our contributing guidelines:```



1. Fork the repository### Hot Reload (Development)

2. Create a feature branch (`git checkout -b feature/amazing-feature`)```bash

3. Commit your changes (`git commit -m 'Add amazing feature'`)flutter run -d chrome

4. Push to the branch (`git push origin feature/amazing-feature`)# Press 'r' for hot reload

5. Open a Pull Request# Press 'R' for hot restart

```

### Coding Standards

---

- Follow Flutter/Dart style guide

- Write unit tests for new features## 🐛 Troubleshooting

- Update documentation

- Add comments for complex logic### "Index required" error in Ineligible tab

- Use meaningful commit messages**Solution:** Wait 2-5 minutes for Firestore index to build after first deployment. See [Admin Dashboard Status](docs/admin/ADMIN_DASHBOARD_STATUS.md).



---### Underwriting rules not loading

**Solution:** Run `./seed_rules.sh` to initialize rules in Firestore.

## 🔒 Security

### Authentication errors

### Best Practices**Solution:** Check Firebase Auth is enabled. See [Auth Setup Guide](docs/setup/AUTH_SETUP_GUIDE.md).



- **Never commit secrets** - Use `.env` files (gitignored)### API key errors

- **Firestore rules** - Enforce row-level security**Solution:** Verify `.env` file exists and contains valid API keys.

- **Admin-only access** - Verify `userRole: 'admin'` in Cloud Functions

- **Rate limiting** - Prevent abuse in Cloud Functions---

- **Input validation** - Sanitize all user inputs

## 📦 Tech Stack

### Reporting Vulnerabilities

- **Frontend:** Flutter 3.x (Web, iOS, Android)

Email security concerns to: security@clovara.com- **Backend:** Firebase (Auth, Firestore, Functions)

- **AI:** OpenAI GPT-4

---- **Payments:** Stripe

- **State Management:** Provider

## 📝 License- **UI:** Material Design 3



This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.---



---## 📈 Development Status



## 👥 Team✅ **Production Ready Features:**

- Conversational quote flow with AI avatar

Built with ❤️ by the Clovara team- Risk scoring engine with explainability

- Admin dashboard (4 tabs)

- **GitHub**: [@FlawlessIQ](https://github.com/FlawlessIQ)- Authentication & authorization

- Firestore security rules

---- Payment integration

- Policy management

## 🙏 Acknowledgments

🚧 **In Development:**

- Flutter team for the amazing framework- Claims filing system

- Firebase for backend infrastructure- Email notifications

- OpenAI for AI capabilities- Advanced analytics

- SendGrid for email delivery

- All the pet owners who inspired this projectSee [ROADMAP.md](ROADMAP.md) for full feature list.



------



## 📞 Support## 🤝 Contributing



- **Documentation**: [docs/](docs/)1. Create a feature branch

- **Issues**: [GitHub Issues](https://github.com/FlawlessIQ/Clovara/issues)2. Make your changes

- **Email**: support@clovara.com3. Test thoroughly

4. Submit a pull request

---

---

## 🗺️ Roadmap

## 📄 License

See [ROADMAP.md](ROADMAP.md) for upcoming features:

[Your License Here]

- [ ] Voice narration for Pawla

- [ ] Multilingual support---

- [ ] Mobile app optimization

- [ ] Advanced fraud detection ML models## 🆘 Support

- [ ] API for external integrations

- [ ] Predictive analytics dashboardFor issues or questions:

- Check [docs/](docs/) for detailed guides

---- Review [troubleshooting section](#-troubleshooting)

- Create an issue in the repository

**Made with 🐾 for pets and their humans**

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
