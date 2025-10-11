# Business Intelligence Panel System

## Overview

The BI Panel System provides comprehensive analytics for claims administrators, featuring advanced breakdowns, fraud detection metrics, export capabilities, and email sharing. It transforms raw claims data into actionable business insights.

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                     ClaimsAnalyticsTab                    │
│                     (Flutter UI Layer)                    │
├──────────────────────────────────────────────────────────┤
│  • Interactive Charts (fl_chart)                          │
│  • Export CSV Button                                      │
│  • Share via Email Button                                │
│  • Date Range Filters                                     │
└─────────────────┬────────────────────────────────────────┘
                  │
                  ▼
┌──────────────────────────────────────────────────────────┐
│              Cloud Functions (Backend)                    │
├──────────────────────────────────────────────────────────┤
│  functions/claimsAnalytics.js - aggregateClaimsData      │
│  functions/analyticsEmail.js - sendAnalyticsEmail        │
└─────────────────┬────────────────────────────────────────┘
                  │
                  ▼
┌──────────────────────────────────────────────────────────┐
│             Flutter Services Layer                        │
├──────────────────────────────────────────────────────────┤
│  lib/services/csv_export_service.dart                    │
│  lib/services/analytics_email_service.dart               │
└──────────────────────────────────────────────────────────┘
```

---

## Analytics Metrics

### 1. Summary Metrics

**Total Claims**: Count of all claims in date range

**Total Payout**: Sum of all approved claim amounts

**Auto-Approval Rate**: Percentage of claims approved without human review

**Average Confidence**: Mean AI confidence score across all decisions

**Average Time-to-Settlement**: Mean hours from filing to settlement

### 2. Payout Breakdowns

#### By Breed

Average payout amount grouped by pet breed. Helps identify:
- High-risk breeds requiring larger payouts
- Breed-specific patterns
- Premium pricing opportunities

**Data Structure:**
```javascript
{
  "Golden Retriever": 1250.00,
  "Beagle": 890.50,
  "German Shepherd": 1450.75,
  "Labrador": 1100.00,
  ...
}
```

**Use Cases:**
- Adjust premiums for high-payout breeds
- Identify breeds with suspicious payout patterns
- Market segmentation analysis

#### By Region

Average payout amount grouped by US state or region. Reveals:
- Geographic cost differences (vet costs vary by location)
- Fraud hotspots
- Market expansion opportunities

**Data Structure:**
```javascript
{
  "CA": 1500.00,  // California (higher vet costs)
  "TX": 1100.00,  // Texas
  "NY": 1650.00,  // New York (highest)
  "FL": 1200.00,  // Florida
  ...
}
```

**Use Cases:**
- Regional premium pricing
- Identify fraud patterns in specific areas
- Allocate claims review resources

#### By Claim Type

Average payout grouped by accident, illness, routine, or other. Shows:
- Costliest claim categories
- Type-specific approval patterns
- Product design insights

**Data Structure:**
```javascript
{
  "accident": 2000.00,  // Highest (surgeries)
  "illness": 1200.00,
  "routine": 150.00,    // Lowest
  "other": 800.00
}
```

**Use Cases:**
- Coverage limit recommendations
- Product bundling strategies
- Risk assessment by type

### 3. AI Confidence Histogram

Distribution of AI confidence scores in 10% buckets (0-10%, 10-20%, ..., 90-100%).

**Data Structure:**
```javascript
{
  "0-10%": 5,      // Very low confidence
  "10-20%": 12,
  "20-30%": 18,
  "30-40%": 25,
  "40-50%": 30,
  "50-60%": 42,
  "60-70%": 65,
  "70-80%": 88,    // Human review threshold
  "80-90%": 120,   // Auto-approval range
  "90-100%": 234   // Highest confidence
}
```

**Insights:**
- **Peak at 90-100%**: AI is very confident on most claims (good)
- **Peak at 40-60%**: AI struggles with ambiguous cases (needs retraining)
- **Many < 70%**: Too many human reviews (adjust threshold or retrain)
- **Few > 80%**: AI rarely confident (underfit model)

**Ideal Distribution:**
```
90-100%: ████████████████████ 60% (auto-approvals)
80-90%:  ██████████           20% (high confidence)
70-80%:  ████                 8%  (borderline)
60-70%:  ███                  6%  (needs review)
< 60%:   ██                   6%  (complex cases)
```

### 4. Auto-Approval vs Manual Review Rate

Time series showing percentage of claims auto-approved vs requiring human review each month.

**Data Structure:**
```javascript
{
  autoApprovalByMonth: {
    "Jan 2025": 45,
    "Feb 2025": 52,
    "Mar 2025": 58,  // Improving trend
    ...
  },
  manualReviewByMonth: {
    "Jan 2025": 10,
    "Feb 2025": 8,
    "Mar 2025": 6,   // Decreasing trend (good)
    ...
  }
}
```

**Trends to Monitor:**
- **Increasing auto-approval rate**: AI is learning and improving ✓
- **Decreasing manual review rate**: Less workload for team ✓
- **Sudden drop in auto-approval**: Model degradation or new fraud pattern ✗
- **Spike in manual reviews**: Data drift or edge cases ✗

**Target Metrics:**
- Auto-approval rate: 80-85%
- Manual review rate: 15-20%

### 5. Fraud Detection Ratio

Tracks accuracy of AI denial decisions vs human overrides.

**Data Structure:**
```javascript
{
  aiDenialsCorrect: 45,      // AI denied, human confirmed denial
  aiDenialsOverridden: 5,    // AI denied, human approved anyway
  accuracy: 0.90             // 90% (45 / 50)
}
```

**Metrics:**
- **High accuracy (>85%)**: AI correctly identifies fraud/invalid claims
- **Low accuracy (<70%)**: AI too aggressive on denials, needs tuning
- **Increasing overrides**: AI becoming outdated or biased

**Action Thresholds:**
- **Accuracy < 75%**: Urgent retraining needed
- **Accuracy 75-85%**: Monitor closely, prepare retraining
- **Accuracy > 85%**: AI performing well

**Use Cases:**
- Validate AI denial decisions
- Identify false positives (legitimate claims wrongly denied)
- Tune confidence thresholds for denials

### 6. Time-to-Settlement Metrics

Distribution of hours from claim filing to final settlement.

**Data Structure:**
```javascript
{
  mean: 48.5,      // Average: 48.5 hours (2 days)
  p90: 72.3,       // 90% settle within 72 hours (3 days)
  p99: 96.7,       // 99% settle within 97 hours (4 days)
  count: 234       // Sample size
}
```

**Percentile Interpretation:**
- **Mean**: Average customer experience
- **P90**: Most customers (90%) experience this or better
- **P99**: Worst-case scenario for nearly all customers

**Benchmarks:**
- **Excellent**: Mean < 24h, P90 < 48h, P99 < 72h
- **Good**: Mean < 48h, P90 < 72h, P99 < 96h
- **Needs Improvement**: Mean > 72h, P90 > 96h, P99 > 120h

**Factors Affecting Settlement Time:**
- AI confidence (high confidence = faster)
- Document quality (complete docs = faster)
- Human review queue size
- Claim complexity

---

## CSV Export System

### Overview

The CSV Export Service generates comprehensive 8-section reports from analytics data.

**File**: `lib/services/csv_export_service.dart`

### CSV Structure

```csv
=== CLAIMS ANALYTICS REPORT ===
Generated: 2025-01-15 14:30:00
Date Range: 2024-01-01 to 2025-01-15

=== SUMMARY METRICS ===
Metric,Value
Total Claims,234
Total Payout,$287,500.00
Auto-Approval Rate,78.5%
Average Confidence,82.3%
Average Settlement Time,48.5 hours

=== TIME SERIES (Monthly) ===
Month,Auto-Approvals,Manual Reviews,Auto-Approval Rate
Jan 2025,45,10,81.8%
Feb 2025,52,8,86.7%
Mar 2025,58,6,90.6%

=== AVERAGE PAYOUT BY BREED ===
Breed,Average Payout,Claim Count
Golden Retriever,$1250.00,45
German Shepherd,$1450.75,38
Labrador,$1100.00,52

=== AVERAGE PAYOUT BY REGION ===
Region,Average Payout,Claim Count
CA,$1500.00,67
TX,$1100.00,45
NY,$1650.00,34

=== AVERAGE PAYOUT BY CLAIM TYPE ===
Claim Type,Average Payout,Claim Count
Accident,$2000.00,89
Illness,$1200.00,102
Routine,$150.00,43

=== AI CONFIDENCE HISTOGRAM ===
Confidence Bucket,Claim Count,Percentage
0-10%,5,2.1%
10-20%,12,5.1%
...
90-100%,234,59.8%

=== FRAUD DETECTION METRICS ===
Metric,Value
AI Denials Confirmed,45
AI Denials Overridden,5
Accuracy,90.0%

=== TIME-TO-SETTLEMENT ===
Metric,Hours,Days
Mean,48.5,2.0
P90,72.3,3.0
P99,96.7,4.0
Sample Size,234,
```

### Usage Example

```dart
import 'package:pet_underwriter_ai/services/csv_export_service.dart';

// In ClaimsAnalyticsTab
Future<void> _exportToCsv() async {
  try {
    // Get analytics data from Cloud Function
    final analyticsData = await _fetchAnalytics();
    
    // Generate CSV content
    final csvContent = await CSVExportService.exportClaimsAnalytics(
      analyticsData,
      startDate: _startDate,
      endDate: _endDate,
    );
    
    // Platform-specific save
    if (kIsWeb) {
      // Web: Download via blob
      final bytes = utf8.encode(csvContent);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', CSVExportService.generateFilename())
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      // Mobile/Desktop: Save to file system
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/${CSVExportService.generateFilename()}');
      await file.writeAsString(csvContent);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to ${file.path}')),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Export failed: $e')),
    );
  }
}
```

### Filename Format

`claims_analytics_YYYYMMDD_HHMMSS.csv`

Examples:
- `claims_analytics_20250115_143000.csv`
- `claims_analytics_20250201_091530.csv`

---

## Email Sharing System

### Overview

Admins can share analytics reports via email with beautiful HTML templates and CSV attachments.

**Files:**
- `lib/services/analytics_email_service.dart` (Flutter service)
- `functions/analyticsEmail.js` (Cloud Function)

### Email Components

#### 1. Subject Line

`Claims Analytics Report - January 1, 2024 to January 15, 2025`

#### 2. HTML Template

```html
┌────────────────────────────────────────────────┐
│ [Purple Gradient Header]                       │
│                                                 │
│  📊 Claims Analytics Report                    │
│  Generated: January 15, 2025 at 2:30 PM       │
│                                                 │
├────────────────────────────────────────────────┤
│ Summary Metrics                                 │
├────────────────────────────────────────────────┤
│  [White Card]  [White Card]  [White Card]      │
│  Total Claims  Total Payout  Auto-Approval     │
│     234        $287,500         78.5%          │
├────────────────────────────────────────────────┤
│ Financial Metrics                               │
├────────────────────────────────────────────────┤
│  Average Confidence: 82.3%                      │
│  Avg Settlement Time: 48.5 hours (2.0 days)    │
├────────────────────────────────────────────────┤
│ AI Performance                                  │
├────────────────────────────────────────────────┤
│  Fraud Detection Accuracy: 90.0%                │
│  AI Denials Confirmed: 45                       │
│  AI Denials Overridden: 5                       │
├────────────────────────────────────────────────┤
│ [Yellow Note Box]                               │
│  📎 A detailed CSV report is attached           │
│  for further analysis.                          │
├────────────────────────────────────────────────┤
│ Footer: Powered by PetUwrite AI                 │
└────────────────────────────────────────────────┘
```

#### 3. Plain Text Fallback

```
═════════════════════════════════════════
       CLAIMS ANALYTICS REPORT
═════════════════════════════════════════
Generated: January 15, 2025 at 2:30 PM
Date Range: Jan 1, 2024 - Jan 15, 2025

─────────────────────────────────────────
SUMMARY METRICS
─────────────────────────────────────────
Total Claims:         234
Total Payout:         $287,500.00
Auto-Approval Rate:   78.5%

─────────────────────────────────────────
FINANCIAL METRICS
─────────────────────────────────────────
Average Confidence:   82.3%
Avg Settlement Time:  48.5 hours (2.0 days)

─────────────────────────────────────────
AI PERFORMANCE
─────────────────────────────────────────
Fraud Detection Accuracy: 90.0%
AI Denials Confirmed:     45
AI Denials Overridden:    5

═════════════════════════════════════════
A detailed CSV report is attached for further analysis.

Powered by PetUwrite AI
```

#### 4. CSV Attachment

Full 8-section CSV report attached as `claims_analytics_YYYYMMDD_HHMMSS.csv`

### SendGrid Configuration

**Environment Variables (functions/.env):**

```bash
SENDGRID_API_KEY=SG.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
FROM_EMAIL=analytics@petuwrite.com
FROM_NAME="PetUwrite Analytics"
```

**SendGrid Setup:**

1. Create account at sendgrid.com
2. Generate API key with "Mail Send" permission
3. Verify sender email address
4. Add API key to Firebase Functions config:

```bash
firebase functions:config:set sendgrid.api_key="SG.xxxx" \
  sendgrid.from_email="analytics@petuwrite.com" \
  sendgrid.from_name="PetUwrite Analytics"
```

### Usage Example

```dart
import 'package:pet_underwriter_ai/services/analytics_email_service.dart';

// In ClaimsAnalyticsTab
Future<void> _shareViaEmail() async {
  // Show email input dialog
  final email = await showDialog<String>(
    context: context,
    builder: (context) => _EmailInputDialog(),
  );
  
  if (email == null) return;
  
  try {
    setState(() => _isSharingEmail = true);
    
    // Get analytics data
    final analyticsData = await _fetchAnalytics();
    
    // Send via Cloud Function
    await AnalyticsEmailService.shareAnalyticsReport(
      recipientEmail: email,
      analyticsData: analyticsData,
      startDate: _startDate,
      endDate: _endDate,
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Report sent successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to send: $e'),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    setState(() => _isSharingEmail = false);
  }
}

// Email input dialog widget
class _EmailInputDialog extends StatefulWidget {
  @override
  State<_EmailInputDialog> createState() => _EmailInputDialogState();
}

class _EmailInputDialogState extends State<_EmailInputDialog> {
  final _controller = TextEditingController();
  String? _error;
  
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Share Analytics Report'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Enter recipient email address:'),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'email@example.com',
              errorText: _error,
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          const Text(
            'A detailed report with CSV attachment will be sent.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final email = _controller.text.trim();
            if (!_isValidEmail(email)) {
              setState(() => _error = 'Invalid email address');
              return;
            }
            Navigator.pop(context, email);
          },
          child: const Text('Send'),
        ),
      ],
    );
  }
}
```

### Analytics Logging

Each email share is logged to Firestore:

```javascript
// Collection: analytics_shares
{
  claimId: null,  // null for aggregate reports
  sharedBy: "admin_user_123",
  sharedWith: "manager@company.com",
  reportType: "claims_analytics",
  timestamp: Timestamp,
  dateRange: {
    startDate: "2024-01-01",
    endDate: "2025-01-15"
  }
}
```

---

## Cloud Function Details

### aggregateClaimsData

**File**: `functions/claimsAnalytics.js`

**Input Parameters:**
```javascript
{
  startDate: "2024-01-01T00:00:00Z",  // ISO 8601
  endDate: "2025-01-15T23:59:59Z",
  filters: {
    status: ["settled", "denied"],     // Optional
    claimType: ["accident", "illness"], // Optional
    region: ["CA", "TX"]                // Optional
  }
}
```

**Output Structure:**
```javascript
{
  summary: {
    totalClaims: 234,
    totalPayout: 287500.00,
    autoApprovalRate: 0.785,
    avgConfidence: 0.823,
    avgSettlementTime: 48.5
  },
  avgPayoutByBreed: { "Golden Retriever": 1250, ... },
  avgPayoutByRegion: { "CA": 1500, ... },
  avgPayoutByClaimType: { "accident": 2000, ... },
  confidenceBuckets: { "0-10%": 5, "10-20%": 12, ... },
  autoApprovalByMonth: { "Jan 2025": 45, ... },
  manualReviewByMonth: { "Jan 2025": 10, ... },
  fraudDetection: {
    aiDenialsCorrect: 45,
    aiDenialsOverridden: 5,
    accuracy: 0.90
  },
  settlementMetrics: {
    mean: 48.5,
    p90: 72.3,
    p99: 96.7,
    count: 234
  }
}
```

**Performance:**
- **Query Optimization**: Uses Firestore composite indexes
- **Execution Time**: ~2-3 seconds for 1000 claims
- **Memory Usage**: ~50MB for 10,000 claims
- **Timeout**: 60 seconds max

**Firestore Indexes Required:**

```json
// firestore.indexes.json
{
  "indexes": [
    {
      "collectionGroup": "claims",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "createdAt", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "claims",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "updatedAt", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" }
      ]
    }
  ]
}
```

### sendAnalyticsEmail

**File**: `functions/analyticsEmail.js`

**Input Parameters:**
```javascript
{
  recipientEmail: "manager@company.com",
  analyticsData: { /* Full analytics object */ },
  startDate: "2024-01-01",
  endDate: "2025-01-15"
}
```

**Authentication:**
- Requires admin role (`userRole: 'admin'` in Firestore user document)
- Validates caller is authenticated Firebase user

**Output:**
```javascript
{
  success: true,
  message: "Report sent successfully to manager@company.com"
}
```

**Error Handling:**
```javascript
// Possible errors:
{
  error: "unauthorized",
  message: "Only admins can share reports"
}

{
  error: "invalid_email",
  message: "Recipient email is invalid"
}

{
  error: "sendgrid_error",
  message: "Failed to send email: API key invalid"
}
```

---

## UI Components (To Be Implemented)

### Chart Widgets

**1. Payout by Breed Chart**

```dart
// Horizontal bar chart showing top 10 breeds
BarChart(
  data: avgPayoutByBreed,
  maxBars: 10,
  sortBy: 'value',
  orientation: 'horizontal',
  colors: Colors.blue,
)
```

**2. Confidence Histogram**

```dart
// Vertical bar chart with 10 buckets
BarChart(
  data: confidenceBuckets,
  xAxisLabel: 'AI Confidence (%)',
  yAxisLabel: 'Number of Claims',
  colors: [Colors.red, Colors.orange, Colors.green], // Gradient
  annotations: [
    { x: 7, label: 'Auto-Approval Threshold' }
  ]
)
```

**3. Auto-Approval Trend**

```dart
// Line chart with 2 series
LineChart(
  series: [
    { name: 'Auto-Approvals', data: autoApprovalByMonth, color: Colors.green },
    { name: 'Manual Reviews', data: manualReviewByMonth, color: Colors.orange }
  ],
  xAxisLabel: 'Month',
  yAxisLabel: 'Number of Claims',
  showLegend: true,
)
```

**4. Fraud Detection Pie**

```dart
// Pie chart showing accuracy
PieChart(
  data: {
    'Correct Denials': fraudDetection.aiDenialsCorrect,
    'Overridden Denials': fraudDetection.aiDenialsOverridden,
  },
  colors: [Colors.green, Colors.red],
  showPercentages: true,
)
```

### Header Actions

```dart
Row(
  mainAxisAlignment: MainAxisAlignment.end,
  children: [
    // Export CSV button
    ElevatedButton.icon(
      onPressed: _exportToCsv,
      icon: Icon(Icons.download),
      label: Text('Export CSV'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
      ),
    ),
    SizedBox(width: 12),
    // Share via email button
    ElevatedButton.icon(
      onPressed: _shareViaEmail,
      icon: Icon(Icons.email),
      label: Text('Share via Email'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
      ),
    ),
  ],
)
```

### Date Range Picker

```dart
Row(
  children: [
    Text('Date Range:'),
    SizedBox(width: 12),
    TextButton.icon(
      onPressed: () => _selectStartDate(),
      icon: Icon(Icons.calendar_today),
      label: Text(_formatDate(_startDate)),
    ),
    Text(' to '),
    TextButton.icon(
      onPressed: () => _selectEndDate(),
      icon: Icon(Icons.calendar_today),
      label: Text(_formatDate(_endDate)),
    ),
    SizedBox(width: 12),
    ElevatedButton(
      onPressed: _refreshAnalytics,
      child: Text('Refresh'),
    ),
  ],
)
```

---

## Best Practices

### Data Freshness

- **Real-time**: Use Firestore snapshots for live claims count
- **Aggregated**: Refresh analytics every 5-15 minutes
- **Historical**: Cache monthly aggregates, only recompute on filter change

### Performance Optimization

1. **Pagination**: Load charts progressively (summary first, then details)
2. **Caching**: Store last 24h of analytics in memory
3. **Lazy Loading**: Only render visible charts
4. **Debouncing**: Wait 500ms after filter change before fetching

### Error Handling

```dart
try {
  final analytics = await _fetchAnalytics();
  setState(() => _analyticsData = analytics);
} on FirebaseFunctionsException catch (e) {
  if (e.code == 'unauthenticated') {
    _showError('Please log in to view analytics');
  } else if (e.code == 'permission-denied') {
    _showError('Admin access required');
  } else {
    _showError('Failed to load analytics: ${e.message}');
  }
} catch (e) {
  _showError('Unexpected error: $e');
}
```

### Responsive Design

```dart
// Desktop: 3-column grid
if (MediaQuery.of(context).size.width > 1200) {
  return GridView.count(
    crossAxisCount: 3,
    children: _buildCharts(),
  );
}

// Tablet: 2-column grid
else if (MediaQuery.of(context).size.width > 600) {
  return GridView.count(
    crossAxisCount: 2,
    children: _buildCharts(),
  );
}

// Mobile: Single column
else {
  return ListView(
    children: _buildCharts(),
  );
}
```

---

## Security

### Authentication

- Only users with `userRole: 'admin'` can access analytics
- Enforce via Firestore security rules and Cloud Function checks

**Firestore Rules:**
```javascript
match /claims/{claimId} {
  allow read: if get(/databases/$(database)/documents/users/$(request.auth.uid)).data.userRole == 'admin';
}
```

**Cloud Function Check:**
```javascript
const userDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
if (userDoc.data().userRole !== 'admin') {
  throw new functions.https.HttpsError('permission-denied', 'Admin access required');
}
```

### Data Privacy

- **PII Redaction**: Never include pet owner names, emails, or addresses in exports
- **Aggregation**: Only show aggregated metrics, not individual claim details
- **Email Logging**: Log who shared reports with whom for audit trail

### Rate Limiting

```javascript
// In Cloud Function
const recentShares = await admin.firestore()
  .collection('analytics_shares')
  .where('sharedBy', '==', context.auth.uid)
  .where('timestamp', '>', Date.now() - 3600000) // Last hour
  .get();

if (recentShares.size > 10) {
  throw new functions.https.HttpsError('resource-exhausted', 'Too many shares in the last hour');
}
```

---

## Monitoring

### Key Metrics to Track

1. **Analytics Query Time**: Should be < 3 seconds
2. **CSV Export Success Rate**: Should be > 95%
3. **Email Delivery Rate**: Should be > 98%
4. **Admin Active Users**: Track daily usage
5. **Report Download Count**: Measure adoption

### Firebase Console

**Functions Logs:**
```
INFO: Analytics aggregation completed in 2.3s
INFO: Email sent successfully to manager@company.com
ERROR: SendGrid API error: Invalid API key
```

**Firestore Collections to Monitor:**
- `claims`: Growth rate, query patterns
- `analytics_shares`: Share frequency, recipients
- `analytics`: Event logging for A/B testing

---

## Troubleshooting

### Charts Not Rendering

**Issue**: fl_chart shows blank or errors

**Solutions:**
1. Check data format matches fl_chart expectations
2. Ensure data contains valid numbers (not null/NaN)
3. Verify chart dimensions are not zero
4. Check for division by zero in percentages

### CSV Export Fails

**Issue**: File not downloading or corrupted

**Solutions:**
1. **Web**: Check browser popup blocker settings
2. **Mobile**: Verify storage permissions granted
3. **Encoding**: Ensure UTF-8 with BOM for Excel compatibility
4. **File Size**: Split large CSVs (>10MB) into chunks

### Email Not Sending

**Issue**: sendAnalyticsEmail function fails

**Solutions:**
1. Verify SendGrid API key is valid: `curl -H "Authorization: Bearer $API_KEY" https://api.sendgrid.com/v3/scopes`
2. Check sender email is verified in SendGrid dashboard
3. Review Firebase Functions logs for error details
4. Ensure recipient email format is valid (regex check)
5. Check Firebase Functions config: `firebase functions:config:get`

### Analytics Data Mismatch

**Issue**: UI shows different numbers than Cloud Function

**Solutions:**
1. Clear cache and re-fetch
2. Check date range filters match
3. Verify Firestore indexes are built (check console)
4. Compare timestamp zones (UTC vs local)
5. Check for incomplete data migrations

---

## Future Enhancements

1. **Predictive Analytics**: Forecast claim trends using time series models
2. **Drill-Down**: Click on charts to filter and see detailed claim lists
3. **Custom Reports**: Let admins create saved report templates
4. **Scheduled Emails**: Auto-send weekly/monthly reports
5. **Dashboard Widgets**: Drag-and-drop customizable layout
6. **Comparison Mode**: Compare two date ranges side-by-side
7. **Export to PDF**: Generate visual PDF reports
8. **API Access**: REST API for external BI tools (Tableau, Power BI)

---

## Support

For BI Panel issues:

1. Check Firebase Functions logs
2. Verify SendGrid dashboard for email delivery
3. Review Firestore indexes are built
4. Test with sample data in development
5. Contact SendGrid support for delivery issues

