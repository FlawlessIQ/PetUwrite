import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/quote.dart';
import '../models/policy.dart';
import 'stripe_service.dart';

/// Service for processing payments with Stripe integration
class PaymentProcessor {
  final StripeService _stripeService;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  
  PaymentProcessor({
    StripeService? stripeService,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _stripeService = stripeService ?? StripeService(),
       _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;
  
  /// Process payment for a policy using Stripe
  Future<PaymentResult> processPayment({
    required String policyId,
    required double amount,
    required PaymentMethod paymentMethod,
    required PaymentSchedule schedule,
  }) async {
    try {
      // Validate payment method
      if (!await _validatePaymentMethod(paymentMethod)) {
        return PaymentResult(
          success: false,
          transactionId: null,
          errorMessage: 'Invalid payment method',
        );
      }
      
      // Execute payment via Stripe
      final transactionId = await _executePayment(
        policyId: policyId,
        amount: amount,
        paymentMethod: paymentMethod,
      );
      
      // Record transaction in Firestore
      await _recordTransaction(
        policyId: policyId,
        amount: amount,
        transactionId: transactionId,
        schedule: schedule,
        status: 'succeeded',
      );
      
      // Update policy status to active
      await _firestore.collection('policies').doc(policyId).update({
        'status': 'PolicyStatus.active',
        'lastPaymentDate': FieldValue.serverTimestamp(),
        'paymentStatus': 'current',
      });
      
      return PaymentResult(
        success: true,
        transactionId: transactionId,
        errorMessage: null,
      );
    } catch (e) {
      print('❌ Payment processing failed: $e');
      
      // Record failed transaction
      await _recordTransaction(
        policyId: policyId,
        amount: amount,
        transactionId: null,
        schedule: schedule,
        status: 'failed',
      );
      
      return PaymentResult(
        success: false,
        transactionId: null,
        errorMessage: 'Payment processing failed: $e',
      );
    }
  }
  
  /// Setup recurring payment via Stripe Subscription
  Future<RecurringPaymentResult> setupRecurringPayment({
    required String policyId,
    required CoveragePlan plan,
    required PaymentMethod paymentMethod,
    required PaymentSchedule schedule,
  }) async {
    try {
      // Calculate payment amount based on schedule
      final amount = _calculateScheduledAmount(plan, schedule);
      
      // Map payment schedule to Stripe price ID
      final priceId = _getPriceIdForSchedule(plan, schedule);
      
      // Create subscription via Stripe
      final subscriptionId = await _createSubscription(
        policyId: policyId,
        priceId: priceId,
        amount: amount,
        paymentMethod: paymentMethod,
        schedule: schedule,
      );
      
      // Calculate next payment date
      final nextPaymentDate = _calculateNextPaymentDate(schedule);
      
      // Update policy with subscription info
      await _firestore.collection('policies').doc(policyId).update({
        'subscriptionId': subscriptionId,
        'subscriptionStatus': 'active',
        'paymentSchedule': schedule.toString(),
        'nextPaymentDate': nextPaymentDate,
      });
      
      print('✅ Recurring payment setup: $subscriptionId');
      
      return RecurringPaymentResult(
        success: true,
        subscriptionId: subscriptionId,
        amount: amount,
        nextPaymentDate: nextPaymentDate,
        errorMessage: null,
      );
    } catch (e) {
      print('❌ Failed to setup recurring payment: $e');
      return RecurringPaymentResult(
        success: false,
        subscriptionId: null,
        amount: 0,
        nextPaymentDate: null,
        errorMessage: 'Failed to setup recurring payment: $e',
      );
    }
  }
  
  /// Cancel recurring payment (Stripe subscription)
  Future<bool> cancelRecurringPayment(String subscriptionId) async {
    try {
      // Cancel subscription via Stripe service
      await _cancelSubscription(subscriptionId);
      
      // Update policy status
      final policySnapshot = await _firestore
          .collection('policies')
          .where('subscriptionId', isEqualTo: subscriptionId)
          .limit(1)
          .get();
      
      if (policySnapshot.docs.isNotEmpty) {
        await policySnapshot.docs.first.reference.update({
          'subscriptionStatus': 'canceled',
          'status': 'PolicyStatus.cancelled',
          'cancellationDate': FieldValue.serverTimestamp(),
        });
      }
      
      print('✅ Subscription cancelled: $subscriptionId');
      return true;
    } catch (e) {
      print('❌ Failed to cancel subscription: $e');
      return false;
    }
  }
  
  /// Refund payment via Stripe Refund API
  Future<bool> refundPayment({
    required String transactionId,
    required double amount,
    String? reason,
  }) async {
    try {
      // Process refund via Stripe
      await _processRefund(transactionId, amount, reason: reason);
      
      // Record refund in Firestore
      await _firestore.collection('refunds').add({
        'transactionId': transactionId,
        'amount': amount,
        'reason': reason ?? 'Customer request',
        'status': 'succeeded',
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ Refund processed: $transactionId ($amount)');
      return true;
    } catch (e) {
      print('❌ Failed to process refund: $e');
      
      // Record failed refund attempt
      await _firestore.collection('refunds').add({
        'transactionId': transactionId,
        'amount': amount,
        'reason': reason ?? 'Customer request',
        'status': 'failed',
        'error': e.toString(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      return false;
    }
  }
  
  /// Retry failed payment
  Future<PaymentResult> retryFailedPayment({
    required String policyId,
    required String failedTransactionId,
  }) async {
    try {
      // Get policy details
      final policyDoc = await _firestore.collection('policies').doc(policyId).get();
      if (!policyDoc.exists) {
        return PaymentResult(
          success: false,
          transactionId: null,
          errorMessage: 'Policy not found',
        );
      }
      
      final policyData = policyDoc.data()!;
      final amount = policyData['plan']['monthlyPremium'] as double;
      final schedule = _parsePaymentSchedule(policyData['paymentSchedule'] as String?);
      
      // Create new payment method token (user must provide updated payment info)
      // This would typically come from the UI after user updates their payment method
      
      print('🔄 Retrying payment for policy: $policyId');
      
      // Note: In production, you'd need to collect new payment method from user
      return PaymentResult(
        success: false,
        transactionId: null,
        errorMessage: 'Payment method update required - please provide new payment information',
      );
    } catch (e) {
      print('❌ Failed to retry payment: $e');
      return PaymentResult(
        success: false,
        transactionId: null,
        errorMessage: 'Payment retry failed: $e',
      );
    }
  }
  
  /// Validate payment method token
  Future<bool> _validatePaymentMethod(PaymentMethod method) async {
    // Check if token exists and is not empty
    if (method.token.isEmpty) {
      print('❌ Invalid payment method: empty token');
      return false;
    }
    
    // Validate token format (basic check)
    if (!method.token.startsWith('pm_') && 
        !method.token.startsWith('tok_') &&
        !method.token.startsWith('card_')) {
      print('❌ Invalid payment method: invalid token format');
      return false;
    }
    
    return true;
  }
  
  /// Execute payment via Stripe Payment Intent
  Future<String> _executePayment({
    required String policyId,
    required double amount,
    required PaymentMethod paymentMethod,
  }) async {
    try {
      // Create payment intent via Stripe service
      final paymentIntentData = await _stripeService.createPaymentIntent(
        amount: amount,
        currency: 'usd',
        policyId: policyId,
      );
      
      // Return payment intent ID as transaction ID
      final transactionId = paymentIntentData['paymentIntent'] as String;
      print('✅ Payment executed: $transactionId');
      
      return transactionId;
    } catch (e) {
      print('❌ Payment execution failed: $e');
      rethrow;
    }
  }
  
  /// Record transaction in Firestore
  Future<void> _recordTransaction({
    required String policyId,
    required double amount,
    required String? transactionId,
    required PaymentSchedule schedule,
    required String status,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('⚠️ No authenticated user for transaction recording');
        return;
      }
      
      await _firestore.collection('payments').add({
        'userId': user.uid,
        'policyId': policyId,
        'amount': amount,
        'transactionId': transactionId,
        'paymentSchedule': schedule.toString(),
        'status': status,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ Transaction recorded: $transactionId ($status)');
    } catch (e) {
      print('❌ Failed to record transaction: $e');
      // Don't throw - transaction recording is logging, not critical
    }
  }
  
  /// Create Stripe subscription
  Future<String> _createSubscription({
    required String policyId,
    required String priceId,
    required double amount,
    required PaymentMethod paymentMethod,
    required PaymentSchedule schedule,
  }) async {
    try {
      final subscriptionData = await _stripeService.createSubscription(
        priceId: priceId,
        policyId: policyId,
      );
      
      return subscriptionData['subscriptionId'] as String;
    } catch (e) {
      print('❌ Failed to create Stripe subscription: $e');
      rethrow;
    }
  }
  
  /// Cancel Stripe subscription
  Future<void> _cancelSubscription(String subscriptionId) async {
    try {
      await _stripeService.cancelSubscription(subscriptionId);
      print('✅ Stripe subscription canceled: $subscriptionId');
    } catch (e) {
      print('❌ Failed to cancel Stripe subscription: $e');
      rethrow;
    }
  }
  
  /// Process refund via Stripe Refund API
  Future<void> _processRefund(
    String transactionId, 
    double amount, 
    {String? reason}
  ) async {
    // Note: Refunds must be processed server-side via Cloud Function
    // This method calls the Cloud Function endpoint
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');
      
      final response = await http.post(
        Uri.parse('https://us-central1-pet-underwriter-ai.cloudfunctions.net/processRefund'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'paymentIntentId': transactionId,
          'amount': (amount * 100).round(), // Convert to cents
          'reason': reason ?? 'requested_by_customer',
          'userId': user.uid,
        }),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Refund request failed: ${response.body}');
      }
      
      print('✅ Refund processed via Cloud Function');
    } catch (e) {
      print('❌ Refund processing failed: $e');
      rethrow;
    }
  }
  
  /// Calculate scheduled payment amount
  double _calculateScheduledAmount(CoveragePlan plan, PaymentSchedule schedule) {
    switch (schedule) {
      case PaymentSchedule.monthly:
        return plan.monthlyPremium;
      case PaymentSchedule.quarterly:
        return plan.monthlyPremium * 3;
      case PaymentSchedule.annually:
        return plan.annualPremium;
    }
  }
  
  /// Calculate next payment date based on schedule
  DateTime _calculateNextPaymentDate(PaymentSchedule schedule) {
    final now = DateTime.now();
    switch (schedule) {
      case PaymentSchedule.monthly:
        return DateTime(now.year, now.month + 1, now.day);
      case PaymentSchedule.quarterly:
        return DateTime(now.year, now.month + 3, now.day);
      case PaymentSchedule.annually:
        return DateTime(now.year + 1, now.month, now.day);
    }
  }
  
  /// Map payment schedule to Stripe Price ID
  String _getPriceIdForSchedule(CoveragePlan plan, PaymentSchedule schedule) {
    // In production, these would be actual Stripe Price IDs created in your Stripe Dashboard
    // Format: price_XXXXXXXXXXXXXXXXXXXXX
    
    // For now, generate placeholder IDs based on plan tier and schedule
    final planTier = plan.tier.toString().split('.').last; // e.g., 'basic', 'premium'
    final scheduleType = schedule.toString().split('.').last; // e.g., 'monthly', 'annually'
    
    return 'price_${planTier}_${scheduleType}_placeholder';
  }
  
  /// Parse payment schedule string back to enum
  PaymentSchedule _parsePaymentSchedule(String? scheduleStr) {
    if (scheduleStr == null) return PaymentSchedule.monthly;
    
    if (scheduleStr.contains('monthly')) return PaymentSchedule.monthly;
    if (scheduleStr.contains('quarterly')) return PaymentSchedule.quarterly;
    if (scheduleStr.contains('annually')) return PaymentSchedule.annually;
    
    return PaymentSchedule.monthly; // Default
  }
}

/// Payment method types
class PaymentMethod {
  final PaymentType type;
  final String token; // Payment token from gateway
  final Map<String, dynamic> metadata;
  
  PaymentMethod({
    required this.type,
    required this.token,
    this.metadata = const {},
  });
}

enum PaymentType {
  creditCard,
  debitCard,
  bankAccount,
  paypal,
  applePay,
  googlePay,
}

/// Result of a payment transaction
class PaymentResult {
  final bool success;
  final String? transactionId;
  final String? errorMessage;
  
  PaymentResult({
    required this.success,
    required this.transactionId,
    required this.errorMessage,
  });
}

/// Result of setting up recurring payment
class RecurringPaymentResult {
  final bool success;
  final String? subscriptionId;
  final double amount;
  final DateTime? nextPaymentDate;
  final String? errorMessage;
  
  RecurringPaymentResult({
    required this.success,
    required this.subscriptionId,
    required this.amount,
    required this.nextPaymentDate,
    required this.errorMessage,
  });
}
