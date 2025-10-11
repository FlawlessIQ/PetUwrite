# Admin Dashboard - Underwriter Override System

## 📋 Overview

The Admin Dashboard (`lib/screens/admin_dashboard.dart`) provides human underwriters with a comprehensive interface to review high-risk insurance quotes and override AI decisions when necessary.

## 🔐 Access Control

**Required Permission**: `userRole == 2` (Underwriter)

Only users with underwriter privileges can access this dashboard. Implement access control in your routing:

```dart
// Example route guard
if (userData['userRole'] == 2) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const AdminDashboard()),
  );
} else {
  // Show access denied message
}
```

---

## ✨ Key Features

### 1. **High-Risk Quote Filtering**
- Automatically displays quotes with `riskScore > 80`
- Real-time updates via Firestore streams
- Filter by status: All, Pending Review, Overridden

### 2. **Sorting Options**
- Risk Score (High to Low / Low to High)
- Date (Newest First / Oldest First)

### 3. **Statistics Dashboard**
- Total High-Risk Quotes count
- Pending Review count
- Overridden count

### 4. **Quote Cards**
Displays essential information at a glance:
- Risk score badge with color coding
- Status badge (Pending/Overridden)
- Pet information (name, breed, age)
- Owner details (name, email)
- Creation date and time
- AI decision summary

### 5. **Detailed Quote View**
Modal bottom sheet with complete information:
- **Risk Assessment**: Score, level, AI confidence
- **AI Analysis**: Decision, reasoning, risk factors, recommendations
- **Pet Information**: Complete profile with medical conditions
- **Owner Information**: Contact and location details
- **Override Section**: Form or display of existing override

### 6. **Override Capability**
Underwriters can:
- Choose decision: Approve, Deny, Request More Info
- Provide detailed justification (minimum 20 characters)
- Submit override to update quote status

### 7. **Audit Logging**
All overrides are logged to `audit_logs/` collection with:
- Quote ID
- Underwriter ID and name
- Decision (override)
- Justification
- Original AI decision
- Risk score
- Timestamp

---

## 📊 Firestore Structure

### Quotes Collection
```
/quotes/{quoteId}
  - riskScore: {
      totalScore: 85,
      aiAnalysis: {
        decision: "Deny - High Risk",
        reasoning: "Multiple pre-existing conditions...",
        confidence: 92,
        riskFactors: ["Senior age", "Chronic condition"],
        recommendations: ["Consider higher deductible"]
      }
    }
  - pet: {...}
  - owner: {...}
  - status: "pending" | "approved" | "denied"
  - humanOverride: {  // Added when underwriter overrides
      decision: "Approve",
      justification: "Owner has excellent vet history...",
      underwriterId: "user123",
      underwriterName: "John Smith",
      timestamp: Timestamp
    }
  - createdAt: Timestamp
```

### Audit Logs Collection
```
/audit_logs/{logId}
  - type: "quote_override"
  - quoteId: "quote_abc123"
  - underwriterId: "user456"
  - underwriterName: "Jane Doe"
  - decision: "Approve"
  - justification: "Pet is in good health despite age..."
  - aiDecision: "Deny - High Risk"
  - riskScore: 85
  - timestamp: Timestamp
```

---

## 🎨 UI Components

### Risk Score Color Coding
```dart
90+: Red (#C62828)     - Very High Risk
80-89: Orange (#EF6C00) - High Risk
70-79: Amber (#F57C00)  - Moderate Risk
<70: Green (#2E7D32)    - Low Risk
```

### Status Badges
- **Pending Review**: Orange badge with clock icon
- **Overridden**: Green badge with checkmark icon

### Decision Options
1. **Approve**: Allow policy issuance
2. **Deny**: Reject policy application
3. **Request More Info**: Need additional information

---

## 🚀 Usage Examples

### Navigate to Dashboard
```dart
// From main app navigation
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AdminDashboard(),
      ),
    );
  },
  child: const Text('Underwriter Dashboard'),
);
```

### Check User Role Before Access
```dart
Future<void> _checkUnderwriterAccess() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();

  final userRole = userDoc.data()?['userRole'] ?? 0;

  if (userRole == 2) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminDashboard()),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Access denied. Underwriter role required.'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
```

### Query Audit Logs
```dart
// Get all overrides by a specific underwriter
final overrides = await FirebaseFirestore.instance
    .collection('audit_logs')
    .where('type', isEqualTo: 'quote_override')
    .where('underwriterId', isEqualTo: userId)
    .orderBy('timestamp', descending: true)
    .get();

print('Underwriter has ${overrides.docs.length} overrides');
```

### Generate Override Report
```dart
// Get overrides in date range
final startDate = DateTime(2024, 1, 1);
final endDate = DateTime(2024, 12, 31);

final overrides = await FirebaseFirestore.instance
    .collection('audit_logs')
    .where('type', isEqualTo: 'quote_override')
    .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
    .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
    .get();

// Calculate statistics
int approved = 0;
int denied = 0;
int moreInfo = 0;

for (var doc in overrides.docs) {
  final data = doc.data();
  switch (data['decision']) {
    case 'Approve':
      approved++;
      break;
    case 'Deny':
      denied++;
      break;
    case 'Request More Info':
      moreInfo++;
      break;
  }
}

print('Approved: $approved, Denied: $denied, More Info: $moreInfo');
```

---

## 🔒 Security Rules

### Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Admin Dashboard - Only underwriters can access
    match /quotes/{quoteId} {
      // Read high-risk quotes (role 2 = underwriter)
      allow read: if request.auth != null && 
                     get(/databases/$(database)/documents/users/$(request.auth.uid)).data.userRole == 2;
      
      // Update quotes (add humanOverride)
      allow update: if request.auth != null && 
                       get(/databases/$(database)/documents/users/$(request.auth.uid)).data.userRole == 2 &&
                       request.resource.data.diff(resource.data).affectedKeys().hasOnly(['humanOverride', 'status']);
    }
    
    // Audit logs - Write only, no public read
    match /audit_logs/{logId} {
      allow create: if request.auth != null && 
                       get(/databases/$(database)/documents/users/$(request.auth.uid)).data.userRole == 2;
      
      // Allow admins to read audit logs
      allow read: if request.auth != null && 
                     get(/databases/$(database)/documents/users/$(request.auth.uid)).data.userRole >= 2;
    }
    
    // Users collection
    match /users/{userId} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

---

## 📈 Analytics & Monitoring

### Track Override Metrics

Create a Cloud Function to aggregate override statistics:

```javascript
// functions/analyzeOverrides.js
exports.analyzeOverrides = functions.pubsub
  .schedule('0 0 * * *') // Daily at midnight
  .onRun(async (context) => {
    const db = admin.firestore();
    
    // Get overrides from last 30 days
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    
    const overrides = await db.collection('audit_logs')
      .where('type', '==', 'quote_override')
      .where('timestamp', '>=', admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
      .get();
    
    const stats = {
      totalOverrides: overrides.size,
      approved: 0,
      denied: 0,
      moreInfo: 0,
      byUnderwriter: {},
    };
    
    overrides.forEach(doc => {
      const data = doc.data();
      
      // Count by decision
      if (data.decision === 'Approve') stats.approved++;
      else if (data.decision === 'Deny') stats.denied++;
      else if (data.decision === 'Request More Info') stats.moreInfo++;
      
      // Count by underwriter
      const underwriterId = data.underwriterId;
      if (!stats.byUnderwriter[underwriterId]) {
        stats.byUnderwriter[underwriterId] = {
          name: data.underwriterName,
          count: 0,
        };
      }
      stats.byUnderwriter[underwriterId].count++;
    });
    
    // Store statistics
    await db.collection('admin_stats').doc('override_summary').set({
      ...stats,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    console.log('Override statistics updated:', stats);
  });
```

### Display Statistics Dashboard

```dart
class OverrideStatistics extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('admin_stats')
          .doc('override_summary')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        }
        
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) return const Text('No data available');
        
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Last 30 Days',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text('Total Overrides: ${data['totalOverrides']}'),
                Text('Approved: ${data['approved']}'),
                Text('Denied: ${data['denied']}'),
                Text('More Info: ${data['moreInfo']}'),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

---

## 🧪 Testing

### Test Data Setup

```dart
// Create test high-risk quote
Future<void> createTestQuote() async {
  await FirebaseFirestore.instance.collection('quotes').add({
    'riskScore': {
      'totalScore': 85,
      'aiAnalysis': {
        'decision': 'Deny - High Risk',
        'reasoning': 'Multiple pre-existing conditions and senior age',
        'confidence': 92,
        'riskFactors': [
          'Senior age (12 years)',
          'Chronic kidney disease',
          'History of diabetes',
        ],
        'recommendations': [
          'Consider higher deductible',
          'Exclude pre-existing conditions',
        ],
      },
    },
    'pet': {
      'name': 'Max',
      'species': 'Dog',
      'breed': 'Golden Retriever',
      'age': 12,
      'gender': 'Male',
      'weight': 75,
      'medicalConditions': ['Kidney Disease', 'Diabetes'],
    },
    'owner': {
      'firstName': 'John',
      'lastName': 'Doe',
      'email': 'john.doe@example.com',
      'phone': '555-1234',
      'state': 'CA',
      'zipCode': '90210',
    },
    'status': 'pending',
    'createdAt': Timestamp.now(),
  });
}
```

### Test Override Flow

```dart
testWidgets('Underwriter can override AI decision', (tester) async {
  // Pump dashboard widget
  await tester.pumpWidget(
    MaterialApp(home: const AdminDashboard()),
  );
  
  // Wait for quotes to load
  await tester.pumpAndSettle();
  
  // Tap on a quote card
  await tester.tap(find.byType(Card).first);
  await tester.pumpAndSettle();
  
  // Select "Approve" decision
  await tester.tap(find.text('Approve'));
  await tester.pumpAndSettle();
  
  // Enter justification
  await tester.enterText(
    find.byType(TextField),
    'Owner has excellent vet history and pet is well-managed',
  );
  
  // Submit override
  await tester.tap(find.text('Submit Override'));
  await tester.pumpAndSettle();
  
  // Verify success message
  expect(find.text('Override submitted successfully: Approve'), findsOneWidget);
});
```

---

## 🎯 Best Practices

### 1. Justification Guidelines
- Minimum 20 characters required
- Should explain specific reasoning
- Reference specific facts about pet/owner
- Document any additional research done

### 2. Override Decision Criteria

**Approve** when:
- AI missed positive factors (excellent vet history, preventive care)
- Owner has strong financial history
- Risk factors are manageable
- Additional information supports approval

**Deny** when:
- AI analysis is correct
- Unacceptable risk level
- Missing critical information cannot be obtained
- Regulatory concerns

**Request More Info** when:
- Insufficient medical history
- Unclear ownership details
- Need veterinary records
- Require additional documentation

### 3. Regular Reviews
- Review pending quotes daily
- Prioritize highest risk scores first
- Document all decisions thoroughly
- Escalate unusual cases to senior underwriters

---

## 🆘 Troubleshooting

### Issue: Quotes Not Appearing
**Solution**: 
- Verify Firestore security rules allow read access for role 2
- Check that quotes have `riskScore.totalScore > 80`
- Ensure Firebase connection is active

### Issue: Cannot Submit Override
**Solution**:
- Verify user is authenticated
- Check that justification is at least 20 characters
- Ensure Firestore security rules allow updates
- Check network connection

### Issue: Audit Logs Not Created
**Solution**:
- Verify security rules allow `audit_logs` creation
- Check that user has role 2
- Review Cloud Firestore console for errors

---

## 📞 Support

For questions or issues:
- Check Firestore security rules
- Review Firebase Console logs
- Test with debug mode enabled
- Contact development team

---

## 🔄 Future Enhancements

Potential improvements:
1. **Bulk Actions**: Override multiple quotes at once
2. **Export Reports**: Download CSV of overrides
3. **Advanced Filtering**: By pet breed, age range, state
4. **Notes System**: Add private notes to quotes
5. **Collaboration**: Assign quotes to specific underwriters
6. **Real-time Notifications**: Alert when new high-risk quotes appear
7. **Machine Learning Feedback**: Track override patterns to improve AI

---

**Version**: 1.0.0  
**Last Updated**: October 2025  
**Status**: ✅ Production Ready
