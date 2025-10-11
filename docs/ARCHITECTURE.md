# Pet Underwriter AI - Architecture Diagram

## 📊 App Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER INTERFACE                          │
├─────────────────────────────────────────────────────────────────┤
│  Onboarding → Quote Flow → Plan Selection → Checkout → Confirm │
│     screens/onboarding_screen.dart                              │
│     screens/quote_flow_screen.dart                              │
│     screens/plan_selection_screen.dart                          │
│     screens/checkout_screen.dart                                │
│     screens/policy_confirmation_screen.dart                     │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 ↓
┌─────────────────────────────────────────────────────────────────┐
│                    STATE MANAGEMENT (Provider)                  │
├─────────────────────────────────────────────────────────────────┤
│  QuoteProvider  │  PetProvider  │  PolicyProvider               │
│  - Quote data   │  - Pet list   │  - Active policies            │
│  - Current step │  - Selected   │  - Policy operations          │
│  - Validation   │  - CRUD ops   │  - Loading states             │
└────────┬────────┴───────┬───────┴──────────┬─────────────────────┘
         │                │                  │
         ↓                ↓                  ↓
┌─────────────────────────────────────────────────────────────────┐
│                      BUSINESS LOGIC                             │
├─────────────────────────────────────────────────────────────────┤
│  FirebaseService          RiskScoringEngine                     │
│  - Authentication         - Age risk                            │
│  - CRUD operations        - Breed risk                          │
│  - Real-time streams      - Medical history                     │
│                           - Overall score                        │
│  VetHistoryParser         PaymentProcessor                      │
│  - Parse documents        - Process payment                     │
│  - Extract data           - Recurring billing                   │
│  - Validate records       - Refunds                             │
│                                                                  │
│  PolicyIssuance                                                 │
│  - Create policy                                                │
│  - Renew policy                                                 │
│  - Cancel policy                                                │
└────────┬────────────────────────────────────┬──────────────────┘
         │                                    │
         ↓                                    ↓
┌─────────────────────────┐    ┌────────────────────────────────┐
│   DATA PERSISTENCE      │    │      AI SERVICES               │
├─────────────────────────┤    ├────────────────────────────────┤
│  Firebase Firestore     │    │  GPT Service (OpenAI)          │
│  - pets/                │    │  - Text generation             │
│  - owners/              │    │  - Structured parsing          │
│  - quotes/              │    │  - Risk analysis               │
│  - policies/            │    │                                 │
│                         │    │  Vertex AI Service (Google)    │
│  Firebase Auth          │    │  - Text generation             │
│  - User authentication  │    │  - Structured parsing          │
│  - Session management   │    │  - Risk analysis               │
│                         │    │                                 │
│  Firebase Storage       │    │  VetRecordAIParser             │
│  - Document uploads     │    │  - Extract vaccinations        │
│  - Policy PDFs          │    │  - Extract treatments          │
│  - Images               │    │  - Medical insights            │
└─────────────────────────┘    │                                 │
                                │  RiskScoringAI                 │
                                │  - Predict health risks        │
                                │  - Generate recommendations    │
                                │  - Breed comparisons           │
                                └────────────────────────────────┘
```

## 🔄 User Flow Diagram

```
START
  │
  ↓
┌─────────────────┐
│  Onboarding     │ (4 screens: Welcome, Features, How it works, Get started)
│  Screens        │
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│  Quote Flow     │ Step 1: Pet Information (name, species, breed, DOB)
│  Step 1-4       │ Step 2: Owner Information (name, email, phone, address)
│                 │ Step 3: Medical History (vet records, conditions)
│                 │ Step 4: Review & Submit
└────────┬────────┘
         │
         ↓ [Risk Scoring Engine calculates risk]
         ↓ [Generate 3 plan options]
         ↓
┌─────────────────┐
│  Plan Selection │ Display: Basic, Standard (Popular), Premium
│                 │ Features comparison
│                 │ Price breakdown
└────────┬────────┘
         │
         ↓ [User selects plan]
         ↓
┌─────────────────┐
│  Checkout       │ Order summary
│                 │ Payment schedule (Monthly/Quarterly/Annual)
│                 │ Payment method (Card details)
│                 │ Terms & Conditions
└────────┬────────┘
         │
         ↓ [Process payment]
         ↓ [Issue policy]
         ↓
┌─────────────────┐
│  Confirmation   │ ✓ Policy activated
│                 │ Policy number & details
│                 │ Download documents
│                 │ Go to dashboard
└─────────────────┘
  │
  ↓
END
```

## 🗂️ Data Model Relationships

```
┌──────────────┐
│    Owner     │
│ - id         │
│ - name       │
│ - email      │
│ - address    │
└──────┬───────┘
       │ 1
       │
       │ has many
       │
       ↓ *
┌──────────────┐          ┌──────────────┐
│     Pet      │ 1     1  │  RiskScore   │
│ - id         │──────────│ - id         │
│ - name       │  has     │ - score      │
│ - breed      │          │ - factors    │
│ - age        │          │ - level      │
│ - conditions │          └──────────────┘
└──────┬───────┘
       │ 1
       │
       │ generates
       │
       ↓ *
┌──────────────┐          ┌──────────────┐
│    Quote     │ 1     *  │ CoveragePlan │
│ - id         │──────────│ - id         │
│ - petId      │ includes │ - name       │
│ - riskScore  │          │ - premium    │
│ - status     │          │ - features   │
└──────┬───────┘          └──────────────┘
       │ 1
       │
       │ converts to
       │
       ↓ 1
┌──────────────┐          ┌──────────────┐
│    Policy    │ 1     *  │    Claim     │
│ - id         │──────────│ - id         │
│ - number     │   has    │ - amount     │
│ - plan       │          │ - status     │
│ - status     │          │ - documents  │
│ - effectiveDate         └──────────────┘
└──────────────┘
```

## 🔌 AI Integration Flow

```
User uploads vet record
         │
         ↓
VetHistoryParser.parseDocument()
         │
         ↓
AI Service (GPT/Vertex AI)
         │
         ├─→ Extract text (OCR if needed)
         │
         ├─→ Parse with AI prompt
         │
         └─→ Return structured data:
             - Vaccinations
             - Treatments
             - Medications
             - Surgeries
             - Allergies
         │
         ↓
RiskScoringEngine.calculateRiskScore()
         │
         ├─→ Analyze age risk
         ├─→ Analyze breed risk
         ├─→ Analyze medical history
         ├─→ Calculate overall score
         │
         ↓
RiskScoringAI.generateRiskAnalysis()
         │
         ├─→ AI generates detailed analysis
         ├─→ Predict future health risks
         └─→ Generate recommendations
         │
         ↓
Display to user in Quote
```

## 📱 Screen Component Structure

```
OnboardingScreen
├── PageView
│   ├── Page 1: Welcome
│   ├── Page 2: Upload Records
│   ├── Page 3: Get Quotes
│   └── Page 4: Get Coverage
├── Page Indicators
└── Navigation (Back, Skip, Next)

QuoteFlowScreen
├── AppBar
├── Stepper
│   ├── Step 1: Pet Info Form
│   │   ├── Name TextField
│   │   ├── Species Dropdown
│   │   ├── Breed TextField
│   │   └── DOB DatePicker
│   ├── Step 2: Owner Info Form
│   ├── Step 3: Medical History
│   └── Step 4: Review
└── Navigation

PlanSelectionScreen
├── Header
├── ListView
│   ├── Basic Plan Card
│   ├── Standard Plan Card (Popular)
│   └── Premium Plan Card
└── Bottom Bar
    ├── Selected Plan
    └── Continue Button

CheckoutScreen
├── Order Summary Card
├── Payment Schedule RadioButtons
├── Payment Method Form
├── Terms & Conditions Checkbox
└── Complete Purchase Button

ConfirmationScreen
├── Success Icon
├── Policy Details Card
│   ├── Policy Number
│   ├── Effective Date
│   ├── Plan Name
│   └── Premium
├── Download Documents Button
└── Go to Dashboard Button
```

## 🎯 Key Integration Points

1. **Firebase ↔ Providers**
   - Real-time data sync
   - Stream subscriptions
   - Error handling

2. **Providers ↔ Screens**
   - State updates trigger UI rebuilds
   - Form data validation
   - Loading states

3. **Services ↔ AI**
   - Text parsing
   - Risk analysis
   - Recommendations

4. **Payment ↔ Policy**
   - Payment success → Policy creation
   - Recurring billing setup
   - Transaction recording

## 🔐 Security Considerations

```
User Input → Validation → Sanitization → Processing
                ↓
         Firebase Rules
                ↓
         Secure Storage
                ↓
         API Keys (Environment Variables)
```

---

This architecture provides:
- ✅ Separation of concerns
- ✅ Scalable structure
- ✅ Easy testing
- ✅ Maintainable codebase
- ✅ Clear data flow
