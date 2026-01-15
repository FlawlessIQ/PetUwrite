# Claims Analytics & ML Retraining System Guide

## 🎯 Overview

Clovara's Claims Analytics system provides **real-time insights** into claims patterns, risk accuracy, and model performance. The system automatically collects training data from every filed claim to enable **supervised fine-tuning** of the AI risk scoring model.

---

## 📊 System Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                     CLAIMS LIFECYCLE                          │
└──────────────────────────────────────────────────────────────┘

1. Policy Holder Files Claim
   ├─ ClaimsService.submitClaim()
   ├─ Store in claims/ collection
   └─ Auto-generate training data
            ↓
2. Training Data Generation
   ├─ Link claim to original quote
   ├─ Extract features (breed, age, conditions, risk score)
   ├─ Extract labels (had claim, amount, outcome)
   └─ Store in model_training_data/ collection
            ↓
3. Analytics Dashboard
   ├─ Claims grouped by risk bands (0-10, 10-20, ..., 90-100)
   ├─ Heatmap visualization
   ├─ Average claim amounts
   └─ Claims frequency analysis
            ↓
4. Future: ML Model Retraining
   ├─ Export training data to JSON
   ├─ Train custom model or fine-tune GPT
   ├─ Deploy updated risk scoring model
   └─ Continuous improvement loop
```

---

## 🗄️ Firestore Schema

### **Collection: `claims/`**

Each claim document contains:

```json
{
  "quoteId": "quote_abc123",
  "policyId": "policy_xyz789",
  "riskScoreAtBind": 75.5,
  "wasApprovedManually": false,
  "claimAmount": 1250.00,
  "claimReason": "ACL surgery for torn ligament during hike",
  "diagnosisCode": "M23.6",  // Optional ICD-10 or custom code
  "outcome": "approved",     // approved | denied | partial
  "timestamp": "2025-10-10T14:30:00Z"
}
```

**Fields Explained:**
- `quoteId`: Reference to original insurance quote
- `policyId`: Reference to active policy
- `riskScoreAtBind`: Risk score when policy was purchased (0-100)
- `wasApprovedManually`: True if policy was manually approved by underwriter
- `claimAmount`: Dollar amount claimed by policyholder
- `claimReason`: Free-text description of claim
- `diagnosisCode`: Optional medical diagnosis code
- `outcome`: approved (fully paid), denied (rejected), partial (partially paid)
- `timestamp`: When claim was filed

---

### **Collection: `model_training_data/`**

Auto-generated from claims for ML retraining:

```json
{
  "claimId": "claim_def456",
  "quoteId": "quote_abc123",
  "policyId": "policy_xyz789",
  "input": {
    "breed": "Golden Retriever",
    "species": "dog",
    "age": 7,
    "weight": 32.5,
    "isNeutered": true,
    "conditions": ["hip dysplasia"],
    "riskScore": 75.5,
    "wasApprovedManually": false
  },
  "label": {
    "hadClaim": true,
    "claimAmount": 1250.00,
    "outcome": "approved",
    "claimReason": "ACL surgery",
    "diagnosisCode": "M23.6"
  },
  "timestamp": "2025-10-10T14:30:00Z",
  "dataSource": "actual_claim"
}
```

**Purpose:**
- **Input**: Features used to predict risk
- **Label**: Ground truth outcome (did claim happen? how much?)
- **Data Source**: Tracks whether data came from actual claims or other sources

---

## 🎨 Admin Dashboard - Claims Analytics Tab

Located in: `lib/screens/admin_dashboard.dart` → **Tab 3: Claims Analytics**

### **Features:**

#### **1. Summary Cards**
- **Total Claims**: Total number of claims across all risk bands
- **Avg Claim Amount**: Average dollar amount per claim
- **High Risk Claims**: Claims from risk scores 80-100

#### **2. Risk Band Table**

| Risk Band | Claims | Avg Amount | Frequency | Approved | Denied |
|-----------|--------|------------|-----------|----------|--------|
| 0-10      | 5      | $450       | 2.5%      | 5        | 0      |
| 10-20     | 12     | $620       | 5.1%      | 11       | 1      |
| ...       | ...    | ...        | ...       | ...      | ...    |
| 90-100    | 3      | $2,100     | 45%       | 1        | 2      |

**Columns:**
- **Risk Band**: Score range (0-10, 10-20, ..., 90-100)
- **Claims**: Number of claims in that risk band
- **Avg Amount**: Average claim amount in USD
- **Frequency**: Percentage of policies in band that filed claims
- **Approved/Denied**: Claim outcomes

**Visual Indicators:**
- Risk bands 80-100 highlighted in red
- Color-coded approval/denial counts

#### **3. Heatmap Visualization**

Bar chart showing:
- **X-Axis**: Risk Score Bands (0, 10, 20, ..., 90)
- **Y-Axis**: Claims Frequency (0-100%)
- **Color**: Green (low frequency) → Yellow → Orange → Red (high frequency)

**Interactive Tooltips:**
Hovering over bars shows:
```
40-50
12 claims
$780 avg
15.3% frequency
```

---

## 🔐 Security Rules

### **Claims Collection**

```javascript
match /claims/{claimId} {
  // Admins can read all claims
  allow read: if isAdmin();
  
  // Users can create claims for their own policies
  allow create: if isAuthenticated() && (
    exists(/databases/$(database)/documents/policies/$(request.resource.data.policyId)) &&
    get(/databases/$(database)/documents/policies/$(request.resource.data.policyId)).data.ownerId == request.auth.uid
  );
  
  // Only admins can update claims
  allow update: if isAdmin();
  
  // Never allow deletion of claims
  allow delete: if false;
}
```

**Access Control:**
- **Read**: Admins only
- **Create**: Authenticated users (for their own policies only)
- **Update**: Admins only
- **Delete**: Never (immutable for audit trail)

### **Model Training Data Collection**

```javascript
match /model_training_data/{trainingDataId} {
  allow read: if isAdmin();
  allow create: if isAdmin(); // Auto-generated by ClaimsService
  allow update, delete: if false; // Training data is immutable
}
```

**Access Control:**
- **Read**: Admins only
- **Create**: Admins only (auto-generated by backend)
- **Update/Delete**: Never (immutable for ML reproducibility)

---

## 💻 Code Usage

### **Filing a Claim**

```dart
import 'package:pet_underwriter_ai/services/claims_service.dart';
import 'package:pet_underwriter_ai/models/claim.dart';

final claimsService = ClaimsService();

// Submit a claim
final claimId = await claimsService.submitClaim(
  quoteId: 'quote_abc123',
  policyId: 'policy_xyz789',
  riskScoreAtBind: 75.5,
  wasApprovedManually: false,
  claimAmount: 1250.00,
  claimReason: 'ACL surgery for torn ligament',
  diagnosisCode: 'M23.6', // Optional
  outcome: ClaimOutcome.approved,
);

// Training data is automatically generated!
```

**What Happens:**
1. Claim stored in `claims/` collection
2. `_generateTrainingDataFromClaim()` called automatically
3. Original quote data fetched
4. Training sample created in `model_training_data/`
5. Returns claim ID

---

### **Retrieving Analytics**

```dart
// Get claims analytics by risk bands
final analytics = await claimsService.getClaimsAnalytics();

for (final band in analytics) {
  print('${band.band}: ${band.claimCount} claims');
  print('  Avg Amount: \$${band.averageClaimAmount}');
  print('  Frequency: ${band.claimsFrequency}%');
  print('  Approved: ${band.approvedCount}');
  print('  Denied: ${band.deniedCount}');
}
```

**Output:**
```
0-10: 5 claims
  Avg Amount: $450
  Frequency: 2.5%
  Approved: 5
  Denied: 0
10-20: 12 claims
  Avg Amount: $620
  Frequency: 5.1%
  Approved: 11
  Denied: 1
...
```

---

### **Getting Claims by Risk Band**

```dart
// Get all claims in the 80-90 risk band
final highRiskClaims = await claimsService.getClaimsByRiskBand(80, 90);

print('Found ${highRiskClaims.length} claims in 80-90 band');
```

---

### **Exporting Training Data for ML**

```dart
// Export all training data in ML-ready format
final trainingData = await claimsService.exportTrainingDataForML();

// Save to JSON file
File('training_data.json').writeAsStringSync(
  jsonEncode(trainingData)
);
```

**Output Format:**
```json
[
  {
    "input": {
      "breed": "Golden Retriever",
      "age": 7,
      "conditions": ["hip dysplasia"],
      "riskScore": 75.5
    },
    "label": {
      "hadClaim": true,
      "claimAmount": 1250.00,
      "outcome": "approved"
    },
    "metadata": {
      "claimId": "claim_def456",
      "quoteId": "quote_abc123",
      "timestamp": "2025-10-10T14:30:00Z"
    }
  }
]
```

---

### **Getting Training Data Statistics**

```dart
// Get overview of training data
final stats = await claimsService.getTrainingDataStats();

print('Total Samples: ${stats['totalSamples']}');
print('Claims with Data: ${stats['claimsWithData']}');
print('Approved: ${stats['approvedClaims']}');
print('Denied: ${stats['deniedClaims']}');
print('Avg Claim Amount: \$${stats['averageClaimAmount']}');
print('Approval Rate: ${stats['approvalRate']}%');
```

---

## 📈 Analytics Insights

### **Key Metrics to Monitor**

#### **1. Risk Score Accuracy**
Compare predicted risk bands to actual claim frequency:
- **Expected**: Higher risk scores → Higher claim frequency
- **Red Flag**: High-risk band (80-90) has lower claims than mid-risk (50-60)
- **Action**: Retrain model or adjust risk scoring weights

#### **2. Approval Rate by Risk Band**
Track which risk bands have highest claim approval rates:
- **Expected**: Lower risk bands → Higher approval rates
- **Red Flag**: Low-risk band (0-10) has many denied claims
- **Action**: Investigate claim denial reasons or policy exclusions

#### **3. Manual Approval Performance**
Compare manually approved policies vs. auto-approved:
- **Metric**: `wasApprovedManually = true` → Claim frequency
- **Goal**: Manual approvals should NOT have significantly higher claims
- **Action**: If manual approvals = high claims, tighten override criteria

#### **4. Average Claim Amount by Risk Band**
Identify cost patterns:
- **Expected**: Higher risk bands → Higher claim amounts
- **Red Flag**: Mid-risk band has highest avg claim amount
- **Action**: Adjust premium pricing for that risk band

---

## 🤖 Future: ML Model Retraining Workflow

### **Step 1: Data Collection (Automated)**

Already implemented! Every claim automatically generates training data.

```
claims/ collection
        ↓
_generateTrainingDataFromClaim()
        ↓
model_training_data/ collection
```

---

### **Step 2: Export Training Data**

```dart
// Export all training data
final trainingData = await ClaimsService().exportTrainingDataForML();

// Save to file
File('training_data.json').writeAsStringSync(
  jsonEncode(trainingData)
);
```

**File Structure:**
```json
[
  {
    "input": {...},  // Features
    "label": {...}   // Ground truth
  },
  ...
]
```

---

### **Step 3: Train Custom Model (Future)**

**Option A: Fine-Tune GPT-4o**
```python
import openai

# Convert to OpenAI format
training_file = openai.File.create(
  file=open("training_data.jsonl", "rb"),
  purpose='fine-tune'
)

# Fine-tune GPT-4o
fine_tuned_model = openai.FineTune.create(
  training_file=training_file.id,
  model="gpt-4o-2024-05-13"
)
```

**Option B: Train Custom TensorFlow Model**
```python
import tensorflow as tf

# Load training data
data = load_training_data('training_data.json')

# Define model
model = tf.keras.Sequential([
  tf.keras.layers.Dense(128, activation='relu'),
  tf.keras.layers.Dropout(0.2),
  tf.keras.layers.Dense(64, activation='relu'),
  tf.keras.layers.Dense(1, activation='sigmoid')  # Claim probability
])

# Train
model.compile(optimizer='adam', loss='binary_crossentropy')
model.fit(X_train, y_train, epochs=50)
```

**Option C: Use AutoML**
- Upload `training_data.json` to Google AutoML
- Train tabular regression model
- Deploy as Cloud Function endpoint

---

### **Step 4: Deploy Updated Model**

**Update Risk Scoring Engine:**

```dart
// lib/services/risk_scoring_engine.dart

class RiskScoringEngine {
  final AIService _aiService;
  final CustomMLModel? _customModel; // NEW

  Future<double> calculateRiskScore(Pet pet, Owner owner) async {
    // Calculate traditional score
    final traditionalScore = _calculateTraditionalScore(pet, owner);
    
    // Get AI enhancement
    final aiAnalysis = await _getAIRiskAnalysis(pet, owner, traditionalScore);
    
    // NEW: Get custom model prediction
    final customPrediction = _customModel != null
        ? await _customModel!.predict(pet, owner)
        : null;
    
    // Ensemble: Combine all scores
    final finalScore = _combineScores(
      traditional: traditionalScore,
      ai: aiAnalysis.score,
      custom: customPrediction,
    );
    
    return finalScore;
  }
}
```

---

### **Step 5: Monitor Performance**

Track model improvements:

```dart
// Before Retraining
final stats = await claimsService.getTrainingDataStats();
print('Approval Rate: ${stats['approvalRate']}%');
print('Avg Claim Amount: \$${stats['averageClaimAmount']}');

// After Retraining
// Compare metrics to see if model improved
```

**Key Metrics:**
- **Precision**: % of high-risk predictions that actually filed claims
- **Recall**: % of actual claims that were predicted as high-risk
- **MSE**: Mean squared error between predicted risk and actual claims
- **ROC-AUC**: Area under ROC curve for binary classification

---

## 🔄 Continuous Improvement Loop

```
1. Policies Issued
        ↓
2. Claims Filed
        ↓
3. Training Data Auto-Generated
        ↓
4. Analyze Claims Patterns
        ↓
5. Identify Model Weaknesses
        ↓
6. Retrain ML Model
        ↓
7. Deploy Updated Model
        ↓
8. Issue New Policies (with improved accuracy)
        ↓
(Repeat)
```

**Timeline:**
- **Quarterly**: Review claims analytics, identify trends
- **Bi-Annually**: Export training data, retrain model
- **Annually**: Major model overhaul with new features

---

## 📊 Sample Analytics Queries

### **Query 1: High-Risk Claims Analysis**

```dart
// Get all claims from risk bands 80-100
final highRiskClaims = await claimsService.getHighValueClaims(1000);

// Analyze manually approved vs. auto-approved
final manuallyApproved = highRiskClaims.where((c) => c.wasApprovedManually).length;
final autoApproved = highRiskClaims.length - manuallyApproved;

print('Manually Approved: $manuallyApproved');
print('Auto Approved: $autoApproved');
```

---

### **Query 2: Most Expensive Breeds**

```dart
// Get training data
final trainingData = await claimsService.getTrainingData();

// Group by breed
final breedClaims = <String, List<double>>{};
for (final sample in trainingData) {
  final breed = sample['input']['breed'] as String;
  final amount = sample['label']['claimAmount'] as double;
  
  breedClaims.putIfAbsent(breed, () => []).add(amount);
}

// Calculate average claim amount per breed
final avgByBreed = breedClaims.map((breed, amounts) {
  final avg = amounts.reduce((a, b) => a + b) / amounts.length;
  return MapEntry(breed, avg);
});

// Sort by highest avg
final sorted = avgByBreed.entries.toList()
  ..sort((a, b) => b.value.compareTo(a.value));

print('Top 10 Most Expensive Breeds:');
for (final entry in sorted.take(10)) {
  print('${entry.key}: \$${entry.value.toStringAsFixed(2)}');
}
```

---

### **Query 3: Claim Frequency Over Time**

```dart
// Get all claims
final snapshot = await FirebaseFirestore.instance
    .collection('claims')
    .orderBy('timestamp')
    .get();

final claims = snapshot.docs
    .map((doc) => InsuranceClaim.fromMap(doc.data(), doc.id))
    .toList();

// Group by month
final claimsByMonth = <String, int>{};
for (final claim in claims) {
  final month = DateFormat('yyyy-MM').format(claim.timestamp);
  claimsByMonth[month] = (claimsByMonth[month] ?? 0) + 1;
}

print('Claims by Month:');
claimsByMonth.forEach((month, count) {
  print('$month: $count claims');
});
```

---

## 🚀 Next Steps

### **Short Term (Now - 3 Months)**
- ✅ Claims collection schema implemented
- ✅ Auto-generate training data
- ✅ Admin dashboard with analytics tab
- ✅ Heatmap visualization
- 📋 Monitor claims for 3 months to collect baseline data

### **Medium Term (3-6 Months)**
- Export training data (1000+ samples minimum)
- Analyze claims patterns and model weaknesses
- Design custom ML model architecture
- Train initial custom model
- A/B test custom model vs. current GPT-4o scoring

### **Long Term (6-12 Months)**
- Deploy ensemble model (traditional + AI + custom ML)
- Implement continuous retraining pipeline
- Add anomaly detection for fraud prevention
- Expand training data with negative samples (policies with no claims)
- Build predictive claims forecasting model

---

## 🎓 Best Practices

### **Data Quality**
- ✅ Validate claim amounts (> $0, < $50,000)
- ✅ Require diagnosis codes for claims > $5,000
- ✅ Link claims to original quotes (referential integrity)
- ✅ Immutable claims and training data (audit trail)

### **Privacy & Security**
- ✅ Admin-only access to claims data
- ✅ Anonymize training data before exporting
- ✅ HIPAA-compliant data handling
- ✅ Encrypt sensitive fields at rest

### **Model Training**
- ✅ Collect 1000+ samples before first retraining
- ✅ Split data: 70% train, 15% validation, 15% test
- ✅ Use cross-validation to prevent overfitting
- ✅ Track model version and performance metrics
- ✅ A/B test new models before full deployment

---

## 📝 Summary

**Clovara's Claims Analytics system provides:**

1. **Real-Time Analytics**: Risk band breakdown, claim frequencies, avg amounts
2. **Heatmap Visualization**: Visual correlation between risk scores and claims
3. **Training Data Pipeline**: Auto-generation of ML-ready samples from claims
4. **Security**: Role-based access control for claims and training data
5. **Future-Ready**: Infrastructure for continuous model retraining

**Key Files:**
- `lib/models/claim.dart` - InsuranceClaim model
- `lib/services/claims_service.dart` - ClaimsService with analytics methods
- `lib/widgets/claims_analytics_tab.dart` - Admin dashboard tab
- `firestore.rules` - Security rules for claims/ and model_training_data/

**Next Action:** Monitor claims for 3 months, then export training data for first ML model retraining cycle! 🚀

