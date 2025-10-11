# RiskScoringEngine Architecture & Flow

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    PetUnderwriterAI App                      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    RiskScoringEngine                         │
│  ┌───────────────────────────────────────────────────┐      │
│  │  calculateRiskScore()                             │      │
│  │  - Traditional risk calculation                   │      │
│  │  - AI enhancement                                 │      │
│  │  - Firestore storage                              │      │
│  └───────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────┘
           │                  │                    │
           ▼                  ▼                    ▼
    ┌──────────┐      ┌──────────┐        ┌──────────┐
    │Traditional│      │AI Service│        │Firestore │
    │ Scoring  │      │(GPT/Vertex)│       │ Storage  │
    └──────────┘      └──────────┘        └──────────┘
```

## Data Flow Diagram

```
User Input
    │
    ├─► Pet Data
    │   ├─ Age (from DOB)
    │   ├─ Breed
    │   ├─ Weight
    │   ├─ Gender
    │   └─ Pre-existing conditions
    │
    ├─► Owner Data
    │   ├─ Zip Code ──────────┐
    │   ├─ State              │ Geographic
    │   └─ City               │ Risk Factors
    │                         │
    └─► Vet History (optional)│
        ├─ Vaccinations       │
        ├─ Treatments         │
        ├─ Surgeries          │
        └─ Medications        │
                             │
            ▼                ▼
    ┌────────────────────────────────┐
    │  RiskScoringEngine             │
    │                                │
    │  Step 1: Traditional Scoring   │
    │  ┌──────────────────────────┐  │
    │  │ ► Age Risk     : 50/100  │  │
    │  │ ► Breed Risk   : 55/100  │  │
    │  │ ► Pre-existing : 35/100  │  │
    │  │ ► Medical Hist : 40/100  │  │
    │  │ ► Lifestyle    : 30/100  │  │
    │  │                          │  │
    │  │ Overall: 52.5/100        │  │
    │  └──────────────────────────┘  │
    │                                │
    │  Step 2: AI Enhancement        │
    │  ┌──────────────────────────┐  │
    │  │ Build AI Prompt:         │  │
    │  │ ├─ Pet profile           │  │
    │  │ ├─ Geographic data       │  │
    │  │ ├─ Medical history       │  │
    │  │ ├─ Traditional scores    │  │
    │  │ └─ Analysis questions    │  │
    │  │                          │  │
    │  │ Call External AI API     │  │
    │  │ (GPT-4o or Vertex AI)    │  │
    │  └──────────────────────────┘  │
    │              │                 │
    │              ▼                 │
    │  ┌──────────────────────────┐  │
    │  │ AI Response:             │  │
    │  │ ├─ Risk validation       │  │
    │  │ ├─ Top risk categories   │  │
    │  │ ├─ Breed insights        │  │
    │  │ ├─ Geographic factors    │  │
    │  │ ├─ Recommendations       │  │
    │  │ └─ Claim probability     │  │
    │  └──────────────────────────┘  │
    │                                │
    │  Step 3: Combine Results       │
    │  ┌──────────────────────────┐  │
    │  │ RiskScore Object:        │  │
    │  │ ├─ overallScore: 52.5    │  │
    │  │ ├─ riskLevel: MEDIUM     │  │
    │  │ ├─ categoryScores: {...} │  │
    │  │ ├─ riskFactors: [...]    │  │
    │  │ └─ aiAnalysis: "..."     │  │
    │  └──────────────────────────┘  │
    │              │                 │
    └──────────────┼─────────────────┘
                   │
                   ▼
    ┌────────────────────────────────┐
    │  Firestore Storage (optional)  │
    │                                │
    │  quotes/{quoteId}/risk_score/  │
    │    ├─ risk_1234567890          │
    │    └─ (RiskScore JSON)         │
    │                                │
    │  quotes/{quoteId}              │
    │    ├─ riskScoreId              │
    │    ├─ riskScore: 52.5          │
    │    └─ lastRiskAssessment       │
    └────────────────────────────────┘
                   │
                   ▼
            Return to Client
```

## AI Prompt Structure

```
┌─────────────────────────────────────────────────────────────┐
│                      AI PROMPT                               │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Given this pet's profile and veterinary history, provide   │
│  a comprehensive insurance risk assessment.                  │
│                                                              │
│  ┌────────────────────────────────────────────────┐         │
│  │ PET PROFILE                                    │         │
│  │ - Name: Max                                    │         │
│  │ - Species: dog                                 │         │
│  │ - Breed: German Shepherd                       │         │
│  │ - Age: 7 years                                 │         │
│  │ - Weight: 35 kg                                │         │
│  │ - Gender: Male                                 │         │
│  │ - Neutered: Yes                                │         │
│  │ - Pre-existing: Hip Dysplasia                  │         │
│  └────────────────────────────────────────────────┘         │
│                                                              │
│  ┌────────────────────────────────────────────────┐         │
│  │ OWNER LOCATION                                 │         │
│  │ - Zip Code: 94102                              │         │
│  │ - State: CA                                    │         │
│  │ - City: San Francisco                          │         │
│  └────────────────────────────────────────────────┘         │
│                                                              │
│  ┌────────────────────────────────────────────────┐         │
│  │ MEDICAL HISTORY                                │         │
│  │ - Vaccinations: 5 records                      │         │
│  │ - Treatments: 3 records                        │         │
│  │ - Surgeries: 1 surgery                         │         │
│  │ - Medications: 2 medications                   │         │
│  │ - Allergies: None                              │         │
│  └────────────────────────────────────────────────┘         │
│                                                              │
│  ┌────────────────────────────────────────────────┐         │
│  │ TRADITIONAL RISK ASSESSMENT                    │         │
│  │ - Overall Risk Score: 52.5/100                 │         │
│  │ - Category Breakdown:                          │         │
│  │   • age: 50.0/100                              │         │
│  │   • breed: 55.0/100                            │         │
│  │   • preExisting: 35.0/100                      │         │
│  │   • medicalHistory: 40.0/100                   │         │
│  │   • lifestyle: 30.0/100                        │         │
│  │ - Identified Risk Factors:                     │         │
│  │   • Senior pet - increased health risks        │         │
│  │   • Breed-specific health issues               │         │
│  │   • Pre-existing: Hip Dysplasia                │         │
│  └────────────────────────────────────────────────┘         │
│                                                              │
│  ┌────────────────────────────────────────────────┐         │
│  │ ANALYSIS REQUEST                               │         │
│  │ Return a risk score (0-100) and analysis:      │         │
│  │ 1. Overall Risk Assessment                     │         │
│  │ 2. Top 3-5 Risk Categories                     │         │
│  │ 3. Breed-specific considerations               │         │
│  │ 4. Geographic risk factors                     │         │
│  │ 5. Preventive care recommendations             │         │
│  │ 6. Coverage recommendations                    │         │
│  │ 7. Expected claim probability (12 months)      │         │
│  └────────────────────────────────────────────────┘         │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                     ┌─────────────────┐
                     │  GPT-4o/Vertex  │
                     │      AI API     │
                     └─────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      AI RESPONSE                             │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Overall Risk Assessment: Score 52.5/100 (Medium Risk)      │
│                                                              │
│  Top Risk Categories:                                        │
│  1. Age: Senior pet (7 years) - increased likelihood of     │
│     age-related conditions                                   │
│  2. Breed: German Shepherd - prone to hip dysplasia and      │
│     degenerative myelopathy                                  │
│  3. Pre-existing: Hip dysplasia requires ongoing mgmt        │
│                                                              │
│  Breed-specific Considerations:                              │
│  - Hip and elbow dysplasia common in German Shepherds        │
│  - Higher risk of degenerative myelopathy after age 8        │
│  - Prone to bloat (GDV) - emergency condition                │
│                                                              │
│  Geographic Risk Factors:                                    │
│  - California: Moderate vet costs (15% above average)        │
│  - Urban area (SF): Higher access but higher costs           │
│  - Regional diseases: Low tick-borne risk in Bay Area        │
│                                                              │
│  Preventive Care Recommendations:                            │
│  - Regular hip/joint monitoring and X-rays                   │
│  - Maintain healthy weight to reduce joint stress            │
│  - Consider joint supplements (glucosamine)                  │
│                                                              │
│  Coverage Recommendations:                                   │
│  - Deductible: $500-$1000 (based on age and breed)          │
│  - Coverage limit: $10,000+ annually                         │
│  - Orthopedic coverage essential for this breed              │
│                                                              │
│  Expected Claim Probability: 65% in next 12 months          │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Component Interaction Sequence

```
Client                RiskScoringEngine     AIService      Firestore
  │                          │                  │              │
  │ calculateRiskScore()     │                  │              │
  ├─────────────────────────►│                  │              │
  │                          │                  │              │
  │                          │ Traditional      │              │
  │                          │ Calculation      │              │
  │                          │ (age, breed,     │              │
  │                          │  conditions...)  │              │
  │                          │                  │              │
  │                          │ generateText()   │              │
  │                          ├─────────────────►│              │
  │                          │                  │              │
  │                          │              [AI Processing]    │
  │                          │              [2-5 seconds]      │
  │                          │                  │              │
  │                          │ AI Analysis      │              │
  │                          │◄─────────────────┤              │
  │                          │                  │              │
  │                          │ Combine Results  │              │
  │                          │ (RiskScore obj)  │              │
  │                          │                  │              │
  │                          │ storeRiskScore() │              │
  │                          ├─────────────────────────────────►│
  │                          │                  │              │
  │                          │                  │      [Store] │
  │                          │                  │              │
  │                          │                  │    Stored ✓  │
  │                          │◄─────────────────────────────────┤
  │                          │                  │              │
  │  RiskScore Object        │                  │              │
  │◄─────────────────────────┤                  │              │
  │                          │                  │              │
  │ Display to User          │                  │              │
  │                          │                  │              │
```

## Error Flow

```
                RiskScoringEngine
                       │
                       ▼
            ┌──────────────────┐
            │ AI API Call      │
            └──────────────────┘
                │            │
         Success│            │Failure
                │            │
                ▼            ▼
    ┌─────────────────┐  ┌──────────────────┐
    │ Use AI Analysis │  │ Use Fallback     │
    │ Full insights   │  │ "Risk Score: XX  │
    │ Recommendations │  │  Key Factors..." │
    └─────────────────┘  └──────────────────┘
                │            │
                └────────┬───┘
                         │
                         ▼
                ┌─────────────────┐
                │ Return RiskScore│
                │ (always works)  │
                └─────────────────┘
```

## Integration Points

```
┌──────────────────────────────────────────────────────────┐
│                      Quote Flow                           │
├──────────────────────────────────────────────────────────┤
│                                                           │
│  1. User enters pet info         [PetInfoScreen]         │
│                    │                                      │
│                    ▼                                      │
│  2. Upload vet records (opt)     [VetRecordsScreen]      │
│                    │                                      │
│                    ▼                                      │
│  3. Create quote                 [QuoteService]          │
│                    │                                      │
│                    ▼                                      │
│  4. ┌───────────────────────────────────────────┐        │
│     │ Calculate Risk Score                      │        │
│     │  ► RiskScoringEngine.calculateRiskScore() │        │
│     │  ► Includes AI analysis                   │        │
│     │  ► Auto-saves to Firestore                │        │
│     └───────────────────────────────────────────┘        │
│                    │                                      │
│                    ▼                                      │
│  5. Calculate pricing            [PricingEngine]         │
│     (based on risk score)                                │
│                    │                                      │
│                    ▼                                      │
│  6. Display quote to user        [QuoteDisplayScreen]    │
│     - Show risk insights                                 │
│     - Show AI recommendations                            │
│     - Show pricing                                       │
│                                                           │
└──────────────────────────────────────────────────────────┘
```

## File Structure

```
lib/
├── services/
│   └── risk_scoring_engine.dart ◄─── Main implementation
├── ai/
│   └── ai_service.dart ◄────────────── AI provider interface
├── models/
│   ├── pet.dart
│   ├── owner.dart
│   └── risk_score.dart ◄────────────── Data structure
│
examples/
└── risk_scoring_example.dart ◄──────── Usage examples

test/
└── services/
    └── risk_scoring_engine_test.dart ◄ Unit tests

docs/
├── RISK_SCORING_USAGE.md ◄─────────── Full documentation
├── RISK_SCORING_QUICKSTART.md ◄────── Quick reference
├── IMPLEMENTATION_SUMMARY.md ◄─────── Implementation details
└── RISK_SCORING_ARCHITECTURE.md ◄─── This file
```

## Key Design Decisions

1. **AI Integration**: External API calls for enhanced analysis
   - Pros: Leverages advanced AI models, natural language insights
   - Cons: Network dependency, cost per call, latency

2. **Fallback Strategy**: Traditional scoring if AI fails
   - Ensures system always returns a result
   - Graceful degradation

3. **Firestore Storage**: Subcollection under quotes
   - Pros: Clean data structure, easy querying
   - Cons: Requires proper security rules

4. **Required Owner Parameter**: Added for geographic analysis
   - Breaking change from original implementation
   - Necessary for comprehensive risk assessment

5. **Auto-save Option**: Controlled via quoteId parameter
   - Flexible: Calculate without saving
   - Convenient: Auto-save when ready

## Performance Optimization Opportunities

1. **Caching**: Cache risk scores to avoid recalculation
2. **Batch Processing**: Calculate multiple pets in parallel
3. **Streaming**: Stream AI response for faster perceived performance
4. **Background Processing**: Calculate risk in background job
5. **Rate Limiting**: Implement API rate limiting and queuing

## Security Considerations

1. **API Keys**: Never expose in client code
2. **Firestore Rules**: Enforce user ownership
3. **Data Privacy**: Encrypt sensitive health data
4. **Audit Logging**: Track all risk calculations
5. **Rate Limiting**: Prevent abuse of AI API
