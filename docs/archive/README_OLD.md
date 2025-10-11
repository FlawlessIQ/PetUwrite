# Pet Underwriter AI

A Flutter application for pet insurance underwriting powered by AI technology. This app allows pet owners to get instant insurance quotes, upload veterinary records, and purchase pet insurance policies.

## Project Structure

```
lib/
├── screens/           # UI screens
│   ├── onboarding_screen.dart
│   ├── quote_flow_screen.dart
│   ├── plan_selection_screen.dart
│   ├── checkout_screen.dart
│   └── policy_confirmation_screen.dart
│
├── models/           # Data models
│   ├── pet.dart
│   ├── owner.dart
│   ├── quote.dart
│   ├── risk_score.dart
│   └── policy.dart
│
├── services/         # Business logic services
│   ├── firebase_service.dart
│   ├── vet_history_parser.dart
│   ├── risk_scoring_engine.dart
│   ├── payment_processor.dart
│   └── policy_issuance.dart
│
├── widgets/          # Reusable UI components
│   ├── custom_stepper.dart
│   ├── plan_card.dart
│   └── input_forms.dart
│
├── providers/        # State management (Provider)
│   ├── quote_provider.dart
│   ├── pet_provider.dart
│   └── policy_provider.dart
│
└── ai/              # AI integration
    ├── ai_service.dart
    ├── vet_record_ai_parser.dart
    └── risk_scoring_ai.dart
```

## Features

### Screens
- **Onboarding**: Welcome flow introducing the app features
- **Quote Flow**: Multi-step form for collecting pet and owner information
- **Plan Selection**: Compare and choose insurance coverage plans
- **Checkout**: Payment processing and policy purchase
- **Policy Confirmation**: Success screen with policy details

### Models
- **Pet**: Pet information (name, species, breed, age, medical history)
- **Owner**: Pet owner details and contact information
- **Quote**: Insurance quote with available plans
- **RiskScore**: AI-powered risk assessment
- **Policy**: Active insurance policy details

### Services
- **FirebaseService**: Firebase integration for data persistence
- **VetHistoryParser**: Parse veterinary records
- **RiskScoringEngine**: Calculate insurance risk scores
- **PaymentProcessor**: Handle payment transactions
- **PolicyIssuance**: Issue and manage insurance policies

### AI Integration
- **GPTService**: OpenAI GPT integration for text analysis
- **VertexAIService**: Google Vertex AI integration
- **VetRecordAIParser**: AI-powered veterinary record parsing
- **RiskScoringAI**: AI-enhanced risk assessment and predictions

## Setup

### Prerequisites
- Flutter SDK (>= 3.8.0)
- Dart SDK
- Firebase account (for backend services)
- OpenAI or Google Cloud account (for AI features)

### Installation

1. Install dependencies
```bash
flutter pub get
```

2. Configure Firebase
   - Add your google-services.json (Android) and GoogleService-Info.plist (iOS)
   - Update firebase_options.dart with your Firebase configuration

3. Configure AI Services
   - Add API keys for GPT or Vertex AI

4. Run the app
```bash
flutter run
```

## Dependencies

- `provider`: State management
- `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`: Firebase services
- `http`: HTTP requests for AI APIs
- `file_picker`, `image_picker`: File handling
- `pdf`: PDF generation for policies
- `intl`: Date formatting

## TODO / Next Steps

- [ ] Initialize Firebase in main.dart
- [ ] Add authentication screens
- [ ] Integrate payment gateway (Stripe)
- [ ] Implement file upload for vet records
- [ ] Complete AI service integration
- [ ] Add tests
- [ ] Implement claims flow

## Getting Started with Flutter

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
