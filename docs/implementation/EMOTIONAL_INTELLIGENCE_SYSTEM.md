# Emotional Intelligence System

## Overview

The Emotional Intelligence System transforms the claims experience from a cold, automated process into an empathetic, transparent journey. It features **Pawla**, an AI assistant avatar, along with real-time tracking, timeline visualization, AI explainability, and sentiment feedback.

## System Components

### 1. Pawla Avatar Widget
**File**: `lib/widgets/pawla_avatar.dart`

A custom-painted animated avatar with 6 emotional expressions that provides visual empathy throughout the claims process.

#### Expressions

| Expression | When to Use | Visual Features | Color Scheme |
|------------|-------------|-----------------|--------------|
| **happy** | Welcome messages, positive updates | Curved eyes, smile, paw nose | Purple gradient |
| **thinking** | Processing documents, making decisions | Squinted eye, thought bubble | Cyan gradient |
| **empathetic** | Difficult news, denials, delays | Soft eyes, sparkles, heart | Pink gradient |
| **celebrating** | Claim approved, process complete | Wide smile, confetti animation | Warm gradient |
| **concerned** | Issues detected, missing info | Worried eyebrows, down mouth | Grey gradient |
| **working** | Active analysis, AI running | Focused eyes, progress arc | Purple gradient |

#### Usage Example

```dart
import 'package:pet_underwriter_ai/widgets/pawla_avatar.dart';

// Basic usage
PawlaAvatar(
  expression: PawlaExpression.happy,
  size: 120,
)

// With message bubble
PawlaAvatar(
  expression: PawlaExpression.celebrating,
  size: 140,
  message: "Great news! Your claim has been approved!",
  animated: true,
)

// Dynamic based on claim state
PawlaAvatar(
  expression: _getExpressionForClaim(claim),
  size: 100,
  message: ClaimTrackerService.getCurrentMessage(claim).message,
)
```

#### Animation

- **Float Animation**: Gentle vertical movement (-5 to +5 pixels)
- **Pulse Animation**: Subtle scale change (1.0 to 1.05)
- **Duration**: 2-second loop
- **Can be disabled**: Set `animated: false`

---

### 2. Claim Timeline Widget
**File**: `lib/widgets/claim_timeline_widget.dart`

Interactive vertical timeline showing the claim journey through 5 stages with progress indicators.

#### Timeline Stages

```
┌─────────────────────────────────────┐
│  1. Claim Filed                     │ Always shown (✓ Complete)
│     └─ Timestamp: When submitted    │
├─────────────────────────────────────┤
│  2. Documents Review                │ Complete when attachments uploaded
│     └─ Timestamp: Upload time       │
├─────────────────────────────────────┤
│  3. AI Analysis                     │ Complete when aiDecision present
│     └─ Confidence badge shown       │
├─────────────────────────────────────┤
│  4. Human Review (Conditional)      │ Only if confidence < 80% or override
│     └─ Timestamp: Override time     │
├─────────────────────────────────────┤
│  5. Final Decision                  │ Settled/Denied/Pending
│     └─ Payment amount or reason     │
└─────────────────────────────────────┘
```

#### Status Indicators

- **✓ Completed**: Solid color circle with white icon, timestamp shown
- **⏳ In Progress**: White circle with animated spinner, glowing shadow
- **◯ Pending**: Grey circle with grey icon, no timestamp

#### Usage Example

```dart
import 'package:pet_underwriter_ai/widgets/claim_timeline_widget.dart';
import 'package:pet_underwriter_ai/models/claim.dart';

ClaimTimelineWidget(
  claim: claim, // Pass the Claim model
)
```

#### Color Coding

| Stage | Color | Icon |
|-------|-------|------|
| Claim Filed | Blue | file_upload |
| Documents Review | Purple | description |
| AI Analysis | Teal | psychology |
| Human Review | Orange | person |
| Final Decision | Green/Red/Grey | check_circle/cancel/hourglass_empty |

---

### 3. Claim Tracker Service
**File**: `lib/services/claim_tracker_service.dart`

Generates contextual, empathetic messages and progress metrics based on real-time claim state.

#### Key Methods

##### getCurrentMessage(Claim claim)

Returns a `PawlaMessage` with expression and contextual text.

**Message Logic:**

| Claim State | Expression | Sample Message |
|-------------|-----------|----------------|
| **Settled** | celebrating | "🎉 Great news! Your claim has been approved for $1,250!" |
| **Denied** | empathetic | "I know this isn't the news you hoped for. Let me explain why..." |
| **Processing (no AI)** | working | "I'm analyzing your 3 document(s) right now. This usually takes just a few minutes!" |
| **Processing (AI done, high conf)** | happy | "Almost done! Your claim looks great. Just doing a final quality check..." |
| **Processing (AI done, low conf)** | thinking | "Our team is carefully reviewing your claim to make sure we get everything right for you." |
| **Draft** | happy | "Hi! I'm Pawla, and I'm here to help you with your claim!" |

##### getProgressPercentage(Claim claim)

Calculates 0-95% completion (never shows 100% until settled):

- **Filed**: 20%
- **Documents uploaded**: +20% (40% total)
- **AI analysis complete**: +30% (70% total)
- **Human review complete**: +15-30% (85-95% total, depending on confidence)

##### getEstimatedTimeRemaining(Claim claim)

Returns human-friendly time estimates:

- **No documents**: "Waiting for documents"
- **AI processing**: "5-10 minutes"
- **Human review needed**: "1-2 hours"
- **High confidence auto-approval**: "A few minutes"

##### getDetailedUpdates(Claim claim)

Returns checkmark list of completed steps:

```
✓ Claim filed successfully
✓ Documents uploaded and verified
⏳ AI is analyzing your claim...
```

##### getNextAction(Claim claim)

Suggests user's next step:

- **Draft**: "Upload your documents to continue"
- **Processing**: `null` (no action needed)
- **Settled**: "Download your policy documents"
- **Denied**: "Contact support if you have questions"

#### Usage Example

```dart
import 'package:pet_underwriter_ai/services/claim_tracker_service.dart';

// Get current message
final message = ClaimTrackerService.getCurrentMessage(claim);

// Display in UI
PawlaAvatar(
  expression: message.expression,
  message: message.message,
)

// Show progress
final progress = ClaimTrackerService.getProgressPercentage(claim);
LinearProgressIndicator(value: progress / 100)

// Show time estimate
final timeRemaining = ClaimTrackerService.getEstimatedTimeRemaining(claim);
Text('Estimated: $timeRemaining')

// Show detailed steps
final updates = ClaimTrackerService.getDetailedUpdates(claim);
Column(
  children: updates.map((u) => Text(u)).toList(),
)
```

---

### 4. AI Explainability Widget
**File**: `lib/widgets/ai_explainability_widget.dart`

Visual explanation of AI decisions with SHAP-style factor analysis showing positive/negative impacts.

#### Components

1. **Decision Summary** (Gradient card)
   - Green for approval, red for denial
   - Confidence percentage
   - Check/cancel icon

2. **Confidence Level** (Progress bar)
   - Very High: ≥ 90% (green)
   - High: ≥ 80% (green)
   - Moderate: ≥ 60% (orange)
   - Low: ≥ 40% (red)
   - Very Low: < 40% (red)

3. **Contributing Factors** (Impact bars)
   - Sorted by absolute impact
   - Positive factors: ↑ green bars
   - Negative factors: ↓ red bars
   - Shows percentage contribution

4. **Key Insights** (Bullet list)
   - 3-5 human-readable explanations
   - Contextual to decision type

5. **Transparency Note** (Info box)
   - Explains AI + human review process
   - Reassures about accuracy

#### Usage Example

```dart
import 'package:pet_underwriter_ai/widgets/ai_explainability_widget.dart';

// Only show if AI decision exists
if (claim.aiDecision != null) {
  AIExplainabilityWidget(
    claim: claim,
  )
}
```

#### Data Structure

The widget extracts factors from `claim.aiReasoningExplanation` Map:

```dart
{
  'policyCompliance': 0.85,        // +85% (green)
  'claimHistory': 0.70,            // +70% (green)
  'documentQuality': 0.60,         // +60% (green)
  'claimAmount': -0.30,            // -30% (red)
  'preExistingCondition': -0.50,   // -50% (red)
}
```

Factors are automatically formatted:
- `policyCompliance` → "Policy Compliance"
- `claimHistory` → "Claim History"

---

### 5. Sentiment Feedback Widget
**File**: `lib/widgets/sentiment_feedback_widget.dart`

Allows users to rate claim fairness and provide comments for AI training.

#### Features

- **3 Sentiment Options**: Fair (positive), Neutral, Unfair (negative)
- **Optional Comment Field**: Expands after sentiment selection
- **Duplicate Prevention**: Checks for existing feedback, shows thank-you if already submitted
- **Firestore Logging**: Saves to `claim_feedback` collection with metadata
- **Analytics Event**: Logs to `analytics` collection for tracking
- **Success Feedback**: Shows snackbar and thank-you card after submission

#### Data Logged

```javascript
{
  claimId: "CLM123456",
  userId: "user_abc",
  sentiment: "positive", // "positive" | "neutral" | "negative"
  comment: "Very satisfied with the process!",
  claimStatus: "settled",
  aiDecision: "approve",
  aiConfidence: 0.92,
  humanOverride: false,
  claimAmount: 1250.00,
  submittedAt: Timestamp,
  metadata: {
    claimType: "accident",
    petId: "pet_123",
    wasApproved: true,
    timeToFeedback: 24 // hours since decision
  }
}
```

#### Usage Example

```dart
import 'package:pet_underwriter_ai/widgets/sentiment_feedback_widget.dart';

// Only show for settled/denied claims
if (claim.status == ClaimStatus.settled || claim.status == ClaimStatus.denied) {
  SentimentFeedbackWidget(
    claim: claim,
  )
}
```

#### AI Training Integration

Sentiment feedback is linked to the AI retraining system:

1. Negative feedback on approvals → Flag for review, may indicate fraud
2. Negative feedback on denials → Review denial factors, check for bias
3. Positive feedback → Reinforcement signal for good decisions
4. Comments → Qualitative analysis for edge cases

---

## Integration Guides

### ClaimStatusScreen Integration

**Complete Example:**

```dart
import 'package:flutter/material.dart';
import 'package:pet_underwriter_ai/models/claim.dart';
import 'package:pet_underwriter_ai/widgets/pawla_avatar.dart';
import 'package:pet_underwriter_ai/widgets/claim_timeline_widget.dart';
import 'package:pet_underwriter_ai/widgets/ai_explainability_widget.dart';
import 'package:pet_underwriter_ai/widgets/sentiment_feedback_widget.dart';
import 'package:pet_underwriter_ai/services/claim_tracker_service.dart';

class ClaimStatusScreen extends StatefulWidget {
  final String claimId;
  
  const ClaimStatusScreen({super.key, required this.claimId});

  @override
  State<ClaimStatusScreen> createState() => _ClaimStatusScreenState();
}

class _ClaimStatusScreenState extends State<ClaimStatusScreen> {
  Claim? _claim;
  
  @override
  void initState() {
    super.initState();
    _loadClaim();
  }
  
  Future<void> _loadClaim() async {
    // Load claim from Firestore with real-time updates
    FirebaseFirestore.instance
        .collection('claims')
        .doc(widget.claimId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        setState(() {
          _claim = Claim.fromFirestore(snapshot);
        });
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    if (_claim == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    final message = ClaimTrackerService.getCurrentMessage(_claim!);
    final progress = ClaimTrackerService.getProgressPercentage(_claim!);
    final timeRemaining = ClaimTrackerService.getEstimatedTimeRemaining(_claim!);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Claim #${_claim!.claimId}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Pawla Avatar with dynamic message
            Center(
              child: PawlaAvatar(
                expression: message.expression,
                size: 140,
                message: message.message,
                animated: true,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 2. Progress bar with percentage
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Progress',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${progress.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: progress / 100,
                      backgroundColor: Colors.grey[200],
                      minHeight: 8,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Estimated: $timeRemaining',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 3. Claim Timeline
            ClaimTimelineWidget(claim: _claim!),
            
            const SizedBox(height: 16),
            
            // 4. AI Explainability (if AI decision exists)
            if (_claim!.aiDecision != null) ...[
              AIExplainabilityWidget(claim: _claim!),
              const SizedBox(height: 16),
            ],
            
            // 5. Sentiment Feedback (if settled/denied)
            SentimentFeedbackWidget(claim: _claim!),
            
            const SizedBox(height: 16),
            
            // 6. Claim Details Card
            _buildClaimDetailsCard(),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
  
  Widget _buildClaimDetailsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Claim Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Claim Type', _claim!.claimType.value),
            _buildDetailRow('Amount', '\$${_claim!.claimAmount.toStringAsFixed(2)}'),
            _buildDetailRow('Filed', _formatDate(_claim!.createdAt)),
            _buildDetailRow('Status', _claim!.status.value),
            if (_claim!.aiConfidenceScore != null)
              _buildDetailRow(
                'AI Confidence',
                '${(_claim!.aiConfidenceScore! * 100).toStringAsFixed(0)}%',
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}
```

---

### ClaimIntakeScreen Integration

**Enhanced Welcome Experience:**

```dart
// At the top of the form
Column(
  children: [
    PawlaAvatar(
      expression: PawlaExpression.happy,
      size: 120,
      message: "Hi! I'm Pawla, and I'm here to help you with your claim!",
      animated: true,
    ),
    const SizedBox(height: 16),
    const Text(
      'Let\'s get started! I\'ll guide you through each step.',
      style: TextStyle(fontSize: 16, color: Colors.grey),
      textAlign: TextAlign.center,
    ),
  ],
)

// After document upload
if (_documentsUploaded) {
  PawlaAvatar(
    expression: PawlaExpression.thinking,
    size: 100,
    message: "Great! I can see your documents uploading...",
  )
}

// During form validation
if (_isValidating) {
  PawlaAvatar(
    expression: PawlaExpression.working,
    size: 100,
    message: "Let me make sure everything looks good...",
  )
}

// On submit
PawlaAvatar(
  expression: PawlaExpression.celebrating,
  size: 120,
  message: "Perfect! I'll start reviewing your claim right away!",
)
```

---

## Best Practices

### Expression Selection

1. **Use `happy` for**: General positive updates, welcome messages, confirmations
2. **Use `thinking` for**: Processing that requires analysis, decision-making
3. **Use `empathetic` for**: Denials, bad news, delays, apologies
4. **Use `celebrating` for**: Approvals, completions, success states
5. **Use `concerned` for**: Errors, missing information, issues detected
6. **Use `working` for**: Active processing, AI running, background tasks

### Message Tone

- **Be conversational**: "I'm analyzing..." not "The system is analyzing..."
- **Be encouraging**: "Almost done!" not "Please wait"
- **Be empathetic**: "I know this isn't the news you hoped for..." not "Claim denied"
- **Be transparent**: Explain what's happening and why
- **Be specific**: "5-10 minutes" not "Soon"

### Timeline Stages

- **Always show all stages**: Users want to see the full journey
- **Hide human review conditionally**: Only show if actually needed
- **Show timestamps**: Helps users understand timing
- **Animate in-progress**: Pulse effect indicates active processing

### Explainability

- **Auto-expand for denials**: Users need to see why immediately
- **Keep collapsed for approvals**: Users can expand if curious
- **Show top 5 factors max**: Avoid overwhelming with too many factors
- **Use positive language**: "Meets requirements" not "No issues found"

### Sentiment Feedback

- **Show immediately after decision**: Capture fresh reactions
- **Make optional**: Don't force feedback
- **Allow updates**: Users can change their mind
- **Thank users**: Acknowledge their contribution

---

## Real-Time Updates

For the best UX, use Firestore snapshot listeners instead of polling:

```dart
StreamBuilder<DocumentSnapshot>(
  stream: FirebaseFirestore.instance
      .collection('claims')
      .doc(claimId)
      .snapshots(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return CircularProgressIndicator();
    
    final claim = Claim.fromFirestore(snapshot.data!);
    final message = ClaimTrackerService.getCurrentMessage(claim);
    
    return PawlaAvatar(
      expression: message.expression,
      message: message.message,
    );
  },
)
```

This ensures users see updates immediately as the claim progresses through stages.

---

## Testing Scenarios

### Scenario 1: Happy Path (Auto-Approval)

```
1. User submits claim with documents → Pawla: working, "I'm analyzing..."
2. AI analyzes (high confidence) → Pawla: happy, "Almost done! Looks great..."
3. Claim auto-approved → Pawla: celebrating, "🎉 Great news! Approved!"
4. Timeline shows: Filed ✓ → Docs ✓ → AI ✓ → Decision ✓
5. Explainability shows 4 green factors
6. Sentiment feedback shown: User clicks "Fair"
```

### Scenario 2: Human Review Path

```
1. User submits claim → Pawla: working
2. AI analyzes (low confidence 65%) → Pawla: thinking
3. Human review triggered → Pawla: thinking, "Our team is reviewing..."
4. Timeline shows: Filed ✓ → Docs ✓ → AI ✓ → Human ⏳ → Decision ◯
5. Human approves → Pawla: celebrating
6. Explainability shows mixed factors (2 green, 1 orange)
7. Sentiment feedback: User clicks "Fair" + comment "Took a while but fair"
```

### Scenario 3: Denial Path

```
1. User submits claim → Pawla: working
2. AI analyzes (high confidence denial) → Pawla: empathetic
3. Claim denied → Pawla: empathetic, "I know this isn't the news..."
4. Timeline shows: Filed ✓ → Docs ✓ → AI ✓ → Decision ✓ (red X)
5. Explainability AUTO-EXPANDED showing 3 red factors
6. Sentiment feedback: User clicks "Unfair" + comment "Pre-existing condition wasn't clear"
7. Feedback logged for AI training review
```

---

## Performance Considerations

- **Avatar animations**: ~30 FPS, minimal CPU usage
- **Timeline rendering**: Static except for in-progress steps
- **Real-time updates**: Use Firestore snapshots (1 connection per screen)
- **Feedback submission**: Async with loading state
- **Custom painting**: Cached by Flutter, repaints only on expression change

---

## Accessibility

- **Semantic labels**: All icons have labels for screen readers
- **Color contrast**: Meets WCAG AA standards
- **Font scaling**: Supports system font size settings
- **Tap targets**: Minimum 48x48 dp for buttons
- **Focus indicators**: Visible focus states for keyboard navigation

---

## Future Enhancements

1. **Voice Narration**: Pawla can read messages aloud
2. **Multilingual Support**: Translations for messages and expressions
3. **Custom Expressions**: Allow users to upload pet photos for personalized avatar
4. **Emotion History**: Show timeline of Pawla's expressions throughout process
5. **Push Notifications**: Send messages via push when claim status changes
6. **Chat Integration**: Allow users to ask Pawla questions about their claim

---

## Troubleshooting

### Pawla not animating

- Check `animated: true` is set
- Ensure widget is in a `StatefulWidget` with `SingleTickerProviderStateMixin`
- Verify no parent widgets are constraining size to 0

### Timeline not updating

- Verify Firestore snapshot listener is active
- Check `Claim` model has correct status values
- Ensure `updatedAt` field is being updated in Firestore

### Explainability showing generic factors

- Check `claim.aiReasoningExplanation` is populated
- Verify Map has numeric values (0-1 range)
- Ensure keys are camelCase strings

### Sentiment feedback not saving

- Check Firebase Auth user is logged in
- Verify Firestore rules allow write to `claim_feedback` collection
- Check SendGrid configuration if email sharing fails

---

## Support

For questions or issues with the Emotional Intelligence System:

1. Check this documentation first
2. Review widget source code comments
3. Test with sample `Claim` objects
4. Check Firestore console for data structure
5. Review error logs in Firebase Console

