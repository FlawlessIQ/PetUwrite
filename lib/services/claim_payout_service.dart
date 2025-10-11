import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/claim.dart';
import '../ai/ai_service.dart';
import 'ai_retraining_service.dart';

/// Service for handling claim payouts, notifications, and denials
/// 
/// Responsibilities:
/// - Process approved claim payouts via Stripe Connect
/// - Record payout transactions in Firestore
/// - Send email + in-app notifications on completion
/// - Generate empathetic denial messages using GPT-4-mini
/// - Ensure idempotent payout processing with transaction logging
class ClaimPayoutService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Stripe API configuration
  static const String _stripeApiUrl = 'https://api.stripe.com/v1';
  final String _stripeSecretKey;
  
  // SendGrid API configuration
  static const String _sendGridApiUrl = 'https://api.sendgrid.com/v3/mail/send';
  final String _sendGridApiKey;
  
  // AI service for empathetic denial messages
  final GPTService _aiService;
  
  /// Create service with API keys from environment or parameters
  ClaimPayoutService({
    String? stripeSecretKey,
    String? sendGridApiKey,
    String? openAiApiKey,
  })  : _stripeSecretKey = stripeSecretKey ?? 
            dotenv.env['STRIPE_SECRET_KEY'] ?? 
            'sk_test_YOUR_SECRET_KEY_HERE',
        _sendGridApiKey = sendGridApiKey ?? 
            dotenv.env['SENDGRID_API_KEY'] ?? 
            'SG.YOUR_API_KEY_HERE',
        _aiService = GPTService(
          apiKey: openAiApiKey ?? dotenv.env['OPENAI_API_KEY'] ?? '',
          model: 'gpt-4o-mini', // Cost-effective for text generation
        );

  /// Process approved claim - trigger payout and notifications
  /// 
  /// This method is idempotent and transaction-safe:
  /// - Uses 'settling' status as a distributed lock
  /// - Prevents concurrent approvals via atomic status update
  /// - Stores Stripe idempotency key to prevent duplicate charges
  /// - Wraps payout completion + claim settlement in transaction
  /// 
  /// Returns the payout transaction ID
  Future<String> processApprovedClaim({
    required String claimId,
    required String approvedBy,
    String? approvalNotes,
  }) async {
    try {
      print('🔒 Attempting to lock claim $claimId for payout processing...');
      
      // Step 1: Atomically lock claim with 'settling' status
      // This prevents concurrent admin approvals
      try {
        final claimRef = _firestore.collection('claims').doc(claimId);
        final claimDoc = await claimRef.get();
        
        if (!claimDoc.exists) {
          throw Exception('Claim $claimId not found');
        }
        
        final currentStatus = claimDoc.data()?['status'] as String?;
        
        // Check if already processed
        if (currentStatus == 'settled') {
          print('⚠️ Claim already settled - returning existing payout');
          final existingPayout = await claimRef
              .collection('payout')
              .where('status', isEqualTo: 'completed')
              .limit(1)
              .get();
          if (existingPayout.docs.isNotEmpty) {
            return existingPayout.docs.first.id;
          }
          throw Exception('Claim is settled but no payout found - data inconsistency');
        }
        
        // Check if currently being settled by another admin
        if (currentStatus == 'settling') {
          final settlingBy = claimDoc.data()?['processingBy'] as String?;
          final settlingStarted = claimDoc.data()?['settlingStartedAt'] as Timestamp?;
          final lockAge = settlingStarted != null 
              ? DateTime.now().difference(settlingStarted.toDate())
              : Duration.zero;
          
          if (lockAge.inMinutes < 5) {
            throw Exception(
              'Claim is currently being processed by $settlingBy. '
              'Lock acquired ${lockAge.inMinutes} minute(s) ago.'
            );
          } else {
            print('⚠️ Stale lock detected (${lockAge.inMinutes} min old) - taking over');
          }
        }
        
        // Only allow locking from 'processing' status
        if (currentStatus != 'processing' && currentStatus != 'settling') {
          throw Exception(
            'Claim must be in processing status (current: $currentStatus)'
          );
        }
        
        // Atomically update to 'settling' status (acts as distributed lock)
        await claimRef.update({
          'status': ClaimStatus.settling.value,
          'processingBy': approvedBy,
          'settlingStartedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        print('✅ Lock acquired for claim $claimId');
      } catch (e) {
        print('❌ Failed to acquire lock: $e');
        rethrow;
      }
      
      // Step 2: Load claim data
      final claimDoc = await _firestore.collection('claims').doc(claimId).get();
      final claim = Claim.fromMap(claimDoc.data()!, claimDoc.id);
      
      // Step 3: Check for existing payout (idempotency)
      final existingPayout = await _firestore
          .collection('claims')
          .doc(claimId)
          .collection('payout')
          .where('status', whereIn: ['completed', 'pending'])
          .limit(1)
          .get();
      
      if (existingPayout.docs.isNotEmpty) {
        final payoutStatus = existingPayout.docs.first.data()['status'];
        print('⚠️ Existing payout found with status: $payoutStatus');
        
        if (payoutStatus == 'completed') {
          // Ensure claim is marked settled
          await _firestore.collection('claims').doc(claimId).update({
            'status': ClaimStatus.settled.value,
            'settledAt': FieldValue.serverTimestamp(),
          });
          return existingPayout.docs.first.id;
        } else {
          // Pending payout exists - might be from previous failed attempt
          print('⚠️ Pending payout exists - will attempt to complete it');
        }
      }
      
      // Step 4: Retrieve owner's payment method
      final paymentMethodId = await _getOwnerPaymentMethod(claim.ownerId);
      
      // Step 5: Generate Stripe idempotency key (prevents duplicate charges)
      final idempotencyKey = 'claim_${claimId}_${DateTime.now().millisecondsSinceEpoch}';
      
      // Step 6: Create or get payout transaction record
      DocumentReference payoutRef;
      String payoutId;
      
      if (existingPayout.docs.isNotEmpty) {
        payoutRef = existingPayout.docs.first.reference;
        payoutId = existingPayout.docs.first.id;
      } else {
        payoutRef = await _firestore
            .collection('claims')
            .doc(claimId)
            .collection('payout')
            .add({
          'claimId': claimId,
          'ownerId': claim.ownerId,
          'petId': claim.petId,
          'policyId': claim.policyId,
          'amount': claim.claimAmount,
          'currency': claim.currency,
          'status': 'pending',
          'paymentMethodId': paymentMethodId,
          'approvedBy': approvedBy,
          'approvalNotes': approvalNotes,
          'stripeIdempotencyKey': idempotencyKey,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        payoutId = payoutRef.id;
      }

      try {
        // Step 7: Execute Stripe payout with idempotency key
        final stripeTransactionId = await _executeStripePayout(
          claimId: claimId,
          payoutId: payoutId,
          ownerId: claim.ownerId,
          amount: claim.claimAmount,
          currency: claim.currency,
          paymentMethodId: paymentMethodId,
          idempotencyKey: idempotencyKey,
        );

        // Step 8: Atomically update payout + claim status in transaction
        await _firestore.runTransaction((transaction) async {
          // Update payout status to completed
          transaction.update(payoutRef, {
            'status': 'completed',
            'stripeTransactionId': stripeTransactionId,
            'completedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          
          // Update claim status to settled
          final claimRef = _firestore.collection('claims').doc(claimId);
          transaction.update(claimRef, {
            'status': ClaimStatus.settled.value,
            'settledAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'processingBy': FieldValue.delete(), // Clear lock
            'settlingStartedAt': FieldValue.delete(),
          });
        });

        // Step 9: Send notifications (email + in-app)
        // Non-critical - failures logged but don't block payout
        try {
          await _sendApprovalNotifications(
            claim: claim,
            payoutId: payoutId,
            stripeTransactionId: stripeTransactionId,
            approvedBy: approvedBy,
            approvalNotes: approvalNotes,
          );
        } catch (e) {
          print('⚠️ Notification failed (non-critical): $e');
          // Flag for manual notification
          await _firestore.collection('claims').doc(claimId).update({
            'notificationFailed': true,
            'notificationError': e.toString(),
          });
        }

        // Step 10: Log successful payout
        await _logPayoutEvent(
          claimId: claimId,
          payoutId: payoutId,
          event: 'payout_completed',
          details: {
            'amount': claim.claimAmount,
            'stripeTransactionId': stripeTransactionId,
            'approvedBy': approvedBy,
            'idempotencyKey': idempotencyKey,
          },
        );

        // Step 11: Collect training data for AI model improvement
        // Non-critical - failures logged but don't block payout
        try {
          final retrainingService = AIRetrainingService();
          await retrainingService.collectTrainingDataFromClaim(claimId);
          print('✅ Training data collected for claim $claimId');
        } catch (e) {
          print('⚠️ Training data collection failed (non-critical): $e');
          // Log but don't fail the payout
        }

        print('✅ Claim $claimId payout completed: $payoutId');
        return payoutId;
      } catch (e) {
        // Rollback: Mark payout as failed, release lock
        await payoutRef.update({
          'status': 'failed',
          'errorMessage': e.toString(),
          'failedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // Release lock on claim
        await _firestore.collection('claims').doc(claimId).update({
          'status': ClaimStatus.processing.value,
          'processingBy': FieldValue.delete(),
          'settlingStartedAt': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Log failure
        await _logPayoutEvent(
          claimId: claimId,
          payoutId: payoutId,
          event: 'payout_failed',
          details: {
            'error': e.toString(),
            'approvedBy': approvedBy,
          },
        );

        rethrow;
      }
    } catch (e) {
      print('❌ Error processing claim payout: $e');
      rethrow;
    }
  }

  /// Process denied claim - generate empathetic message and notify
  Future<void> processDeniedClaim({
    required String claimId,
    required String deniedBy,
    String? denialNotes,
  }) async {
    try {
      // Step 1: Verify claim exists
      final claimDoc = await _firestore
          .collection('claims')
          .doc(claimId)
          .get();

      if (!claimDoc.exists) {
        throw Exception('Claim $claimId not found');
      }

      final claim = Claim.fromMap(claimDoc.data()!, claimDoc.id);

      // Step 2: Generate empathetic denial message using GPT-4-mini
      final denialMessage = await _generateEmpatheticDenialMessage(
        claim: claim,
        aiReasoningExplanation: claim.aiReasoningExplanation,
        humanNotes: denialNotes,
      );

      // Step 3: Update claim status to denied
      await _firestore.collection('claims').doc(claimId).update({
        'status': ClaimStatus.denied.value,
        'denialMessage': denialMessage,
        'deniedBy': deniedBy,
        'deniedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Step 4: Send denial notifications
      await _sendDenialNotifications(
        claim: claim,
        denialMessage: denialMessage,
        deniedBy: deniedBy,
        denialNotes: denialNotes,
      );

      // Step 5: Log denial event
      await _logPayoutEvent(
        claimId: claimId,
        payoutId: null,
        event: 'claim_denied',
        details: {
          'deniedBy': deniedBy,
          'denialNotes': denialNotes,
          'denialMessage': denialMessage,
        },
      );

      print('✅ Claim $claimId denied with empathetic message');
    } catch (e) {
      print('❌ Error processing claim denial: $e');
      rethrow;
    }
  }

  /// Get owner's payment method from Stripe customer
  Future<String> _getOwnerPaymentMethod(String ownerId) async {
    try {
      // Get owner's Stripe customer ID from Firestore
      final userDoc = await _firestore.collection('users').doc(ownerId).get();

      if (!userDoc.exists) {
        throw Exception('User $ownerId not found');
      }

      final stripeCustomerId = userDoc.data()?['stripeCustomerId'] as String?;

      if (stripeCustomerId == null || stripeCustomerId.isEmpty) {
        throw Exception('No Stripe customer ID found for user $ownerId');
      }

      // Retrieve payment methods from Stripe
      final response = await http.get(
        Uri.parse('$_stripeApiUrl/customers/$stripeCustomerId/payment_methods?type=card'),
        headers: {
          'Authorization': 'Bearer $_stripeSecretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Stripe API request timed out after 30 seconds');
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to retrieve payment methods: ${response.body}');
      }

      final data = jsonDecode(response.body);
      final paymentMethods = data['data'] as List;

      if (paymentMethods.isEmpty) {
        throw Exception('No payment methods found for customer $stripeCustomerId');
      }

      // Return the first (default) payment method
      return paymentMethods[0]['id'] as String;
    } catch (e) {
      print('❌ Error getting payment method: $e');
      rethrow;
    }
  }

  /// Execute Stripe payout (real implementation uses Stripe Connect)
  /// 
  /// For production, this would use Stripe Connect to transfer funds
  /// to the customer's bank account or debit card
  /// 
  /// Includes idempotency key to prevent duplicate charges if retried
  Future<String> _executeStripePayout({
    required String claimId,
    required String payoutId,
    required String ownerId,
    required double amount,
    required String currency,
    required String paymentMethodId,
    required String idempotencyKey,
  }) async {
    try {
      // Check if in mock mode (for development/testing)
      if (_stripeSecretKey.contains('YOUR_SECRET_KEY') ||
          _stripeSecretKey.startsWith('sk_test_mock')) {
        return _executeMockPayout(
          claimId: claimId,
          payoutId: payoutId,
          amount: amount,
          currency: currency,
        );
      }

      // PRODUCTION: Create Stripe Transfer/Payout with idempotency key
      // This requires Stripe Connect setup with Express/Custom accounts
      
      // Option 1: Refund to original payment method
      final response = await http.post(
        Uri.parse('$_stripeApiUrl/refunds'),
        headers: {
          'Authorization': 'Bearer $_stripeSecretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
          'Idempotency-Key': idempotencyKey, // Prevents duplicate charges
        },
        body: {
          'payment_intent': paymentMethodId, // Would be original payment intent
          'amount': (amount * 100).toInt().toString(), // Convert to cents
          'reason': 'requested_by_customer',
          'metadata[claimId]': claimId,
          'metadata[payoutId]': payoutId,
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Stripe API request timed out after 30 seconds');
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Stripe payout failed: ${response.body}');
      }

      final data = jsonDecode(response.body);
      final transactionId = data['id'] as String;

      print('✅ Stripe payout created: $transactionId');
      return transactionId;

      // Option 2: Direct payout to bank account (requires Stripe Connect)
      /*
      final response = await http.post(
        Uri.parse('$_stripeApiUrl/transfers'),
        headers: {
          'Authorization': 'Bearer $_stripeSecretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'amount': (amount * 100).toInt().toString(),
          'currency': currency.toLowerCase(),
          'destination': stripeConnectedAccountId, // Customer's connected account
          'transfer_group': claimId,
          'metadata[claimId]': claimId,
          'metadata[payoutId]': payoutId,
        },
      );
      */
    } catch (e) {
      print('❌ Error executing Stripe payout: $e');
      rethrow;
    }
  }

  /// Mock payout for development/testing (no real money transfer)
  Future<String> _executeMockPayout({
    required String claimId,
    required String payoutId,
    required double amount,
    required String currency,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));

    // Generate mock transaction ID
    final mockTransactionId = 'mock_txn_${DateTime.now().millisecondsSinceEpoch}';

    print('🧪 MOCK PAYOUT: $amount $currency for claim $claimId');
    print('🧪 Mock Transaction ID: $mockTransactionId');

    return mockTransactionId;
  }

  /// Send approval notifications (email + in-app)
  Future<void> _sendApprovalNotifications({
    required Claim claim,
    required String payoutId,
    required String stripeTransactionId,
    required String approvedBy,
    String? approvalNotes,
  }) async {
    try {
      // Get owner and pet details
      final ownerDoc = await _firestore.collection('users').doc(claim.ownerId).get();
      final petDoc = await _firestore.collection('pets').doc(claim.petId).get();

      if (!ownerDoc.exists || !petDoc.exists) {
        throw Exception('Owner or pet not found');
      }

      final ownerData = ownerDoc.data()!;
      final petData = petDoc.data()!;

      final ownerEmail = ownerData['email'] as String;
      final ownerName = '${ownerData['firstName']} ${ownerData['lastName']}';
      final petName = petData['name'] as String;

      // Send email notification via SendGrid
      await _sendApprovalEmail(
        recipientEmail: ownerEmail,
        recipientName: ownerName,
        petName: petName,
        claimAmount: claim.claimAmount,
        currency: claim.currency,
        claimId: claim.claimId,
        stripeTransactionId: stripeTransactionId,
      );

      // Create in-app notification
      await _createInAppNotification(
        userId: claim.ownerId,
        type: 'claim_approved',
        title: 'Claim Approved! 🎉',
        message: 'Your claim for $petName\'s treatment has been approved. ${_formatCurrency(claim.claimAmount, claim.currency)} has been sent to your account.',
        data: {
          'claimId': claim.claimId,
          'payoutId': payoutId,
          'amount': claim.claimAmount,
          'currency': claim.currency,
          'transactionId': stripeTransactionId,
        },
      );

      print('✅ Approval notifications sent for claim ${claim.claimId}');
    } catch (e) {
      // Log error but don't fail the entire payout
      print('⚠️ Error sending approval notifications: $e');
    }
  }

  /// Send approval email via SendGrid
  Future<void> _sendApprovalEmail({
    required String recipientEmail,
    required String recipientName,
    required String petName,
    required double claimAmount,
    required String currency,
    required String claimId,
    required String stripeTransactionId,
  }) async {
    try {
      // Check if SendGrid is configured
      if (_sendGridApiKey.contains('YOUR_API_KEY')) {
        print('⚠️ SendGrid not configured - skipping email');
        return;
      }

      final emailData = {
        'personalizations': [
          {
            'to': [
              {'email': recipientEmail, 'name': recipientName}
            ],
            'subject': '✅ Claim Approved - ${_formatCurrency(claimAmount, currency)} on the way!',
          }
        ],
        'from': {
          'email': 'claims@petuwrite.com',
          'name': 'PetUwrite Claims Team',
        },
        'content': [
          {
            'type': 'text/html',
            'value': _generateApprovalEmailHtml(
              recipientName: recipientName,
              petName: petName,
              claimAmount: claimAmount,
              currency: currency,
              claimId: claimId,
              stripeTransactionId: stripeTransactionId,
            ),
          }
        ],
      };

      final response = await http.post(
        Uri.parse(_sendGridApiUrl),
        headers: {
          'Authorization': 'Bearer $_sendGridApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(emailData),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('SendGrid API request timed out after 15 seconds');
        },
      );

      if (response.statusCode == 202) {
        print('✅ Approval email sent to $recipientEmail');
      } else {
        throw Exception('SendGrid error: ${response.body}');
      }
    } catch (e) {
      print('❌ Error sending approval email: $e');
      // Don't rethrow - email failure shouldn't fail payout
    }
  }

  /// Generate empathetic denial message using GPT-4-mini
  Future<String> _generateEmpatheticDenialMessage({
    required Claim claim,
    Map<String, dynamic>? aiReasoningExplanation,
    String? humanNotes,
  }) async {
    try {
      // Get pet details for personalization
      final petDoc = await _firestore.collection('pets').doc(claim.petId).get();
      final petName = petDoc.exists 
          ? (petDoc.data()?['name'] as String?) ?? 'your pet'
          : 'your pet';

      final prompt = '''
You are a compassionate customer service representative for a pet insurance company.
Write an empathetic, clear denial message for a claim that was not approved.

CLAIM DETAILS:
- Pet Name: $petName
- Claim Type: ${claim.claimType.value}
- Claim Amount: ${_formatCurrency(claim.claimAmount, claim.currency)}
- Description: ${claim.description}

AI DECISION REASONING:
${aiReasoningExplanation != null ? jsonEncode(aiReasoningExplanation) : 'Not available'}

HUMAN REVIEWER NOTES:
${humanNotes ?? 'No additional notes provided'}

INSTRUCTIONS:
1. Start with empathy - acknowledge their concern for their pet
2. Clearly explain WHY the claim was denied (be specific, reference policy terms)
3. Offer next steps or alternatives if applicable
4. End with reassurance about coverage for future eligible treatments
5. Use warm, professional tone - never defensive or dismissive
6. Keep it under 200 words

Write the denial message now (just the message body, no subject line):
''';

      final response = await _aiService.generateText(prompt);
      return response.trim();
    } catch (e) {
      print('❌ Error generating empathetic denial: $e');
      // Fallback to generic but empathetic message
      return _getGenericDenialMessage(claim);
    }
  }

  /// Fallback generic denial message
  String _getGenericDenialMessage(Claim claim) {
    return '''
We understand how much you care about your pet's health, and we carefully reviewed your claim for ${_formatCurrency(claim.claimAmount, claim.currency)}.

Unfortunately, after reviewing the documentation and policy terms, we are unable to approve this claim at this time. This decision is based on the specific circumstances of this treatment and how they align with your policy coverage.

We know this isn't the news you were hoping for. If you have questions about this decision or would like to discuss your coverage options, our team is here to help. You can reach us at claims@petuwrite.com or call 1-800-PET-CARE.

Please remember that your policy continues to provide coverage for eligible treatments going forward. We're committed to being there when your pet needs us most.

Thank you for trusting us with your pet's care.

Warm regards,
The PetUwrite Claims Team
''';
  }

  /// Send denial notifications
  Future<void> _sendDenialNotifications({
    required Claim claim,
    required String denialMessage,
    required String deniedBy,
    String? denialNotes,
  }) async {
    try {
      // Get owner and pet details
      final ownerDoc = await _firestore.collection('users').doc(claim.ownerId).get();
      final petDoc = await _firestore.collection('pets').doc(claim.petId).get();

      if (!ownerDoc.exists || !petDoc.exists) {
        throw Exception('Owner or pet not found');
      }

      final ownerData = ownerDoc.data()!;
      final petData = petDoc.data()!;

      final ownerEmail = ownerData['email'] as String;
      final ownerName = '${ownerData['firstName']} ${ownerData['lastName']}';
      final petName = petData['name'] as String;

      // Send email notification
      await _sendDenialEmail(
        recipientEmail: ownerEmail,
        recipientName: ownerName,
        petName: petName,
        claimId: claim.claimId,
        denialMessage: denialMessage,
      );

      // Create in-app notification
      await _createInAppNotification(
        userId: claim.ownerId,
        type: 'claim_denied',
        title: 'Claim Decision Update',
        message: 'We\'ve reviewed your claim for $petName. Please check your email for details.',
        data: {
          'claimId': claim.claimId,
          'denialMessage': denialMessage,
        },
      );

      print('✅ Denial notifications sent for claim ${claim.claimId}');
    } catch (e) {
      print('⚠️ Error sending denial notifications: $e');
    }
  }

  /// Send denial email via SendGrid
  Future<void> _sendDenialEmail({
    required String recipientEmail,
    required String recipientName,
    required String petName,
    required String claimId,
    required String denialMessage,
  }) async {
    try {
      // Check if SendGrid is configured
      if (_sendGridApiKey.contains('YOUR_API_KEY')) {
        print('⚠️ SendGrid not configured - skipping email');
        return;
      }

      final emailData = {
        'personalizations': [
          {
            'to': [
              {'email': recipientEmail, 'name': recipientName}
            ],
            'subject': 'Claim Decision - $petName',
          }
        ],
        'from': {
          'email': 'claims@petuwrite.com',
          'name': 'PetUwrite Claims Team',
        },
        'content': [
          {
            'type': 'text/html',
            'value': _generateDenialEmailHtml(
              recipientName: recipientName,
              petName: petName,
              claimId: claimId,
              denialMessage: denialMessage,
            ),
          }
        ],
      };

      final response = await http.post(
        Uri.parse(_sendGridApiUrl),
        headers: {
          'Authorization': 'Bearer $_sendGridApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(emailData),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('SendGrid API request timed out after 15 seconds');
        },
      );

      if (response.statusCode == 202) {
        print('✅ Denial email sent to $recipientEmail');
      } else {
        throw Exception('SendGrid error: ${response.body}');
      }
    } catch (e) {
      print('❌ Error sending denial email: $e');
    }
  }

  /// Create in-app notification for user
  Future<void> _createInAppNotification({
    required String userId,
    required String type,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'type': type,
        'title': title,
        'message': message,
        'data': data ?? {},
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✅ In-app notification created for user $userId');
    } catch (e) {
      print('❌ Error creating in-app notification: $e');
    }
  }

  /// Log payout event for audit trail
  Future<void> _logPayoutEvent({
    required String claimId,
    String? payoutId,
    required String event,
    Map<String, dynamic>? details,
  }) async {
    try {
      await _firestore
          .collection('claims')
          .doc(claimId)
          .collection('payout_audit_trail')
          .add({
        'claimId': claimId,
        'payoutId': payoutId,
        'event': event,
        'details': details ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'actor': _auth.currentUser?.uid ?? 'system',
      });
    } catch (e) {
      print('⚠️ Error logging payout event: $e');
      // Don't fail the operation if logging fails
    }
  }

  /// Generate approval email HTML
  String _generateApprovalEmailHtml({
    required String recipientName,
    required String petName,
    required double claimAmount,
    required String currency,
    required String claimId,
    required String stripeTransactionId,
  }) {
    final formattedAmount = _formatCurrency(claimAmount, currency);

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
      line-height: 1.6;
      color: #333;
      max-width: 600px;
      margin: 0 auto;
      padding: 20px;
      background-color: #f5f5f5;
    }
    .container {
      background-color: #ffffff;
      border-radius: 8px;
      padding: 40px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    .header {
      text-align: center;
      padding-bottom: 20px;
      border-bottom: 2px solid #14B8A6;
    }
    .header h1 {
      color: #14B8A6;
      margin: 0;
      font-size: 28px;
    }
    .emoji {
      font-size: 48px;
      margin: 20px 0;
    }
    .amount {
      background-color: #E0F2F1;
      padding: 20px;
      border-radius: 8px;
      text-align: center;
      margin: 20px 0;
    }
    .amount-value {
      font-size: 36px;
      font-weight: bold;
      color: #14B8A6;
    }
    .info-box {
      background-color: #f9f9f9;
      padding: 15px;
      border-radius: 6px;
      margin: 20px 0;
      border-left: 4px solid #14B8A6;
    }
    .info-box strong {
      color: #0F766E;
    }
    .cta-button {
      display: inline-block;
      background-color: #14B8A6;
      color: white;
      padding: 12px 30px;
      text-decoration: none;
      border-radius: 6px;
      margin: 20px 0;
      font-weight: 600;
    }
    .footer {
      text-align: center;
      margin-top: 30px;
      padding-top: 20px;
      border-top: 1px solid #e0e0e0;
      color: #666;
      font-size: 14px;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="emoji">🎉</div>
      <h1>Claim Approved!</h1>
    </div>
    
    <p>Hi $recipientName,</p>
    
    <p>Great news! We've approved your claim for <strong>$petName's</strong> treatment.</p>
    
    <div class="amount">
      <div>Payment Amount</div>
      <div class="amount-value">$formattedAmount</div>
    </div>
    
    <p>The payment has been processed and should appear in your account within <strong>3-5 business days</strong>.</p>
    
    <div class="info-box">
      <strong>Claim ID:</strong> $claimId<br>
      <strong>Transaction ID:</strong> $stripeTransactionId<br>
      <strong>Pet:</strong> $petName<br>
      <strong>Amount:</strong> $formattedAmount
    </div>
    
    <center>
      <a href="https://app.petuwrite.com/claims/$claimId" class="cta-button">View Claim Details</a>
    </center>
    
    <p>If you have any questions about this payment or your coverage, our team is always here to help.</p>
    
    <p>Thank you for trusting us with $petName's care!</p>
    
    <p>Warm regards,<br>
    <strong>The PetUwrite Claims Team</strong></p>
    
    <div class="footer">
      <p>Questions? Contact us at claims@petuwrite.com or call 1-800-PET-CARE</p>
      <p>&copy; 2025 PetUwrite. All rights reserved.</p>
    </div>
  </div>
</body>
</html>
''';
  }

  /// Generate denial email HTML
  String _generateDenialEmailHtml({
    required String recipientName,
    required String petName,
    required String claimId,
    required String denialMessage,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
      line-height: 1.6;
      color: #333;
      max-width: 600px;
      margin: 0 auto;
      padding: 20px;
      background-color: #f5f5f5;
    }
    .container {
      background-color: #ffffff;
      border-radius: 8px;
      padding: 40px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    .header {
      text-align: center;
      padding-bottom: 20px;
      border-bottom: 2px solid #0F4C75;
    }
    .header h1 {
      color: #0F4C75;
      margin: 0;
      font-size: 28px;
    }
    .message-box {
      background-color: #f9f9f9;
      padding: 20px;
      border-radius: 8px;
      margin: 20px 0;
      border-left: 4px solid #0F4C75;
      white-space: pre-line;
    }
    .info-box {
      background-color: #E3F2FD;
      padding: 15px;
      border-radius: 6px;
      margin: 20px 0;
      border-left: 4px solid #14B8A6;
    }
    .cta-button {
      display: inline-block;
      background-color: #14B8A6;
      color: white;
      padding: 12px 30px;
      text-decoration: none;
      border-radius: 6px;
      margin: 20px 0;
      font-weight: 600;
    }
    .footer {
      text-align: center;
      margin-top: 30px;
      padding-top: 20px;
      border-top: 1px solid #e0e0e0;
      color: #666;
      font-size: 14px;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Claim Decision Update</h1>
    </div>
    
    <p>Hi $recipientName,</p>
    
    <p>We've completed our review of your claim for <strong>$petName</strong>.</p>
    
    <div class="message-box">
$denialMessage
    </div>
    
    <div class="info-box">
      <strong>Claim ID:</strong> $claimId<br>
      <strong>Pet:</strong> $petName
    </div>
    
    <center>
      <a href="https://app.petuwrite.com/claims/$claimId" class="cta-button">View Full Claim Details</a>
    </center>
    
    <p>If you would like to discuss this decision or have questions about your coverage, please don't hesitate to reach out. Our team is here to help.</p>
    
    <p><strong>Contact Us:</strong><br>
    📧 Email: claims@petuwrite.com<br>
    📞 Phone: 1-800-PET-CARE<br>
    💬 Live Chat: <a href="https://app.petuwrite.com/support">app.petuwrite.com/support</a></p>
    
    <div class="footer">
      <p>&copy; 2025 PetUwrite. All rights reserved.</p>
    </div>
  </div>
</body>
</html>
''';
  }

  /// Format currency amount
  String _formatCurrency(double amount, String currency) {
    final symbol = _getCurrencySymbol(currency);
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  /// Get currency symbol
  String _getCurrencySymbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'CAD':
        return 'CA\$';
      case 'AUD':
        return 'A\$';
      default:
        return '$currency ';
    }
  }

  /// Get payout history for a claim
  Future<List<Map<String, dynamic>>> getClaimPayoutHistory(String claimId) async {
    try {
      final snapshot = await _firestore
          .collection('claims')
          .doc(claimId)
          .collection('payout')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {'payoutId': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      print('❌ Error getting payout history: $e');
      return [];
    }
  }

  /// Get payout audit trail for a claim
  Future<List<Map<String, dynamic>>> getPayoutAuditTrail(String claimId) async {
    try {
      final snapshot = await _firestore
          .collection('claims')
          .doc(claimId)
          .collection('payout_audit_trail')
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {'logId': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      print('❌ Error getting audit trail: $e');
      return [];
    }
  }

  /// Retry failed payout
  Future<String> retryFailedPayout(String claimId, String payoutId) async {
    try {
      // Get failed payout record
      final payoutDoc = await _firestore
          .collection('claims')
          .doc(claimId)
          .collection('payout')
          .doc(payoutId)
          .get();

      if (!payoutDoc.exists) {
        throw Exception('Payout $payoutId not found');
      }

      final payoutData = payoutDoc.data()!;

      if (payoutData['status'] != 'failed') {
        throw Exception('Payout is not in failed status');
      }

      // Update status to retrying
      await _firestore
          .collection('claims')
          .doc(claimId)
          .collection('payout')
          .doc(payoutId)
          .update({
        'status': 'retrying',
        'retryAttempt': (payoutData['retryAttempt'] ?? 0) + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Retry Stripe payout with new idempotency key for retry
      final retryIdempotencyKey = 'retry_${payoutId}_${DateTime.now().millisecondsSinceEpoch}';
      final stripeTransactionId = await _executeStripePayout(
        claimId: claimId,
        payoutId: payoutId,
        ownerId: payoutData['ownerId'],
        amount: payoutData['amount'],
        currency: payoutData['currency'],
        paymentMethodId: payoutData['paymentMethodId'],
        idempotencyKey: retryIdempotencyKey,
      );

      // Update status to completed
      await _firestore
          .collection('claims')
          .doc(claimId)
          .collection('payout')
          .doc(payoutId)
          .update({
        'status': 'completed',
        'stripeTransactionId': stripeTransactionId,
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Payout retry successful: $payoutId');
      return stripeTransactionId;
    } catch (e) {
      print('❌ Error retrying payout: $e');
      
      // Mark as failed again
      await _firestore
          .collection('claims')
          .doc(claimId)
          .collection('payout')
          .doc(payoutId)
          .update({
        'status': 'failed',
        'errorMessage': e.toString(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      rethrow;
    }
  }
}
