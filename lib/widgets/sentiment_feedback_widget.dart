import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/claim.dart';

/// Sentiment Feedback Widget
/// 
/// Allows users to provide feedback on claim decisions with "Was this fair?"
/// Logs sentiment data to Firestore for AI training and improvement
class SentimentFeedbackWidget extends StatefulWidget {
  final Claim claim;
  
  const SentimentFeedbackWidget({
    super.key,
    required this.claim,
  });

  @override
  State<SentimentFeedbackWidget> createState() => _SentimentFeedbackWidgetState();
}

class _SentimentFeedbackWidgetState extends State<SentimentFeedbackWidget> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  FeedbackSentiment? _sentiment;
  String? _comment;
  bool _isSubmitting = false;
  bool _hasSubmitted = false;
  bool _showCommentField = false;

  @override
  void initState() {
    super.initState();
    _checkExistingFeedback();
  }

  Future<void> _checkExistingFeedback() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;
      
      final feedbackDoc = await _firestore
          .collection('claim_feedback')
          .doc('${widget.claim.claimId}_$userId')
          .get();
      
      if (feedbackDoc.exists && mounted) {
        setState(() {
          _hasSubmitted = true;
          _sentiment = FeedbackSentiment.values.firstWhere(
            (e) => e.toString().split('.').last == feedbackDoc.data()!['sentiment'],
            orElse: () => FeedbackSentiment.neutral,
          );
        });
      }
    } catch (e) {
      print('Error checking feedback: $e');
    }
  }

  Future<void> _submitFeedback() async {
    if (_sentiment == null) return;
    
    setState(() => _isSubmitting = true);
    
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');
      
      final feedbackData = {
        'claimId': widget.claim.claimId,
        'userId': userId,
        'sentiment': _sentiment.toString().split('.').last,
        'comment': _comment,
        'claimStatus': widget.claim.status.value,
        'aiDecision': widget.claim.aiDecision?.value,
        'aiConfidence': widget.claim.aiConfidenceScore,
        'humanOverride': widget.claim.humanOverride != null,
        'claimAmount': widget.claim.claimAmount,
        'submittedAt': FieldValue.serverTimestamp(),
        
        // Metadata for AI training
        'metadata': {
          'claimType': widget.claim.claimType.value,
          'petId': widget.claim.petId,
          'wasApproved': widget.claim.status == ClaimStatus.settled,
          'timeToFeedback': DateTime.now().difference(widget.claim.updatedAt).inHours,
        },
      };
      
      await _firestore
          .collection('claim_feedback')
          .doc('${widget.claim.claimId}_$userId')
          .set(feedbackData);
      
      // Log for analytics
      await _firestore.collection('analytics').add({
        'event': 'claim_feedback_submitted',
        'claimId': widget.claim.claimId,
        'sentiment': _sentiment.toString().split('.').last,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        setState(() {
          _hasSubmitted = true;
          _isSubmitting = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your feedback! This helps us improve.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit feedback: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show for settled or denied claims
    if (widget.claim.status != ClaimStatus.settled &&
        widget.claim.status != ClaimStatus.denied) {
      return const SizedBox.shrink();
    }
    
    if (_hasSubmitted) {
      return _buildThankYouMessage();
    }
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.feedback, color: Colors.amber),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Was this fair?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Your feedback helps us improve',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildSentimentButtons(),
            if (_showCommentField) ...[
              const SizedBox(height: 16),
              _buildCommentField(),
            ],
            if (_sentiment != null) ...[
              const SizedBox(height: 16),
              _buildSubmitButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSentimentButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildSentimentButton(
          icon: Icons.sentiment_very_satisfied,
          label: 'Fair',
          sentiment: FeedbackSentiment.positive,
          color: Colors.green,
        ),
        _buildSentimentButton(
          icon: Icons.sentiment_neutral,
          label: 'Neutral',
          sentiment: FeedbackSentiment.neutral,
          color: Colors.orange,
        ),
        _buildSentimentButton(
          icon: Icons.sentiment_dissatisfied,
          label: 'Unfair',
          sentiment: FeedbackSentiment.negative,
          color: Colors.red,
        ),
      ],
    );
  }

  Widget _buildSentimentButton({
    required IconData icon,
    required String label,
    required FeedbackSentiment sentiment,
    required Color color,
  }) {
    final isSelected = _sentiment == sentiment;
    
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          onTap: () {
            setState(() {
              _sentiment = sentiment;
              _showCommentField = true;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.15) : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 40,
                  color: isSelected ? color : Colors.grey[600],
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? color : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCommentField() {
    return TextField(
      maxLines: 3,
      decoration: InputDecoration(
        hintText: 'Tell us more about your experience (optional)...',
        hintStyle: TextStyle(color: Colors.grey[400]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).primaryColor),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      onChanged: (value) {
        setState(() => _comment = value);
      },
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitFeedback,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text(
                'Submit Feedback',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildThankYouMessage() {
    return Card(
      elevation: 1,
      color: Colors.green[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[100],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Thank you for your feedback!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your input helps us train our AI to make better decisions.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.green[800],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Feedback sentiment enum
enum FeedbackSentiment {
  positive,   // Fair/satisfied
  neutral,    // Okay/neutral
  negative,   // Unfair/dissatisfied
}
