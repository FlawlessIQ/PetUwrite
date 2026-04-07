import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart' show MissingPluginException;

/// Service for handling Stripe payments
class StripeService {
  // Stripe Test Publishable Key (safe to use in client-side code)
  static const String _publishableKey =
      'pk_test_51SI7vTPzjq9wJkU5zFAJvBSWvFLKfu9Be4klAyLdG8IOjHpQwsw8My1WxhrbagFztc549VKyQAmAtCklGOpbeo4v00IAlWsINb';
  // Secret key should only be used server-side (in Cloud Functions)

  static String get publishableKey => _publishableKey;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );

  /// Initialize Stripe with publishable key
  static Future<void> init() async {
    try {
      Stripe.publishableKey = _publishableKey;
      await Stripe.instance.applySettings();
    } on MissingPluginException {
      // Desktop platforms (e.g., macOS) don't implement flutter_stripe.
      // Call sites should avoid calling init() there, but this prevents
      // hard crashes if it happens.
    }
  }

  /// Create a payment intent for one-time payment
  Future<Map<String, dynamic>> createPaymentIntent({
    required double amount,
    required String currency,
    required String policyId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final callable = _functions.httpsCallable('createPaymentIntent');
      final response = await callable.call({
        'amount': (amount * 100).round(),
        'currency': currency,
        'policyId': policyId,
        'email': user.email,
      });

      final raw = response.data;
      if (raw is Map) {
        return raw.map((key, value) => MapEntry(key.toString(), value));
      }
      throw Exception('Unexpected payment intent response shape');
    } catch (e) {
      throw Exception('Error creating payment intent: $e');
    }
  }

  /// Create a subscription for recurring payments
  Future<Map<String, dynamic>> createSubscription({
    required String priceId,
    required String policyId,
  }) async {
    try {
      final callable = _functions.httpsCallable('createSubscription');
      final response = await callable.call({
        'priceId': priceId,
        'policyId': policyId,
      });

      final raw = response.data;
      if (raw is Map) {
        return raw.map((key, value) => MapEntry(key.toString(), value));
      }
      throw Exception('Unexpected subscription response shape');
    } catch (e) {
      throw Exception('Error creating subscription: $e');
    }
  }

  /// Process payment with payment sheet
  Future<void> processPayment({
    required double amount,
    required String currency,
    required String policyId,
  }) async {
    try {
      // Create payment intent
      final paymentIntentData = await createPaymentIntent(
        amount: amount,
        currency: currency,
        policyId: policyId,
      );

      // Initialize payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntentData['clientSecret'],
          merchantDisplayName: 'Pet Underwriter AI',
          customerId: paymentIntentData['customerId'],
          customerEphemeralKeySecret: paymentIntentData['ephemeralKey'],
          style: ThemeMode.system,
        ),
      );

      // Present payment sheet
      await Stripe.instance.presentPaymentSheet();

      // Payment successful
      await _recordPayment(
        policyId: policyId,
        amount: amount,
        paymentIntentId: paymentIntentData['paymentIntent'],
        status: 'succeeded',
      );
    } catch (e) {
      if (e is StripeException) {
        throw Exception('Stripe error: ${e.error.localizedMessage}');
      } else {
        throw Exception('Payment failed: $e');
      }
    }
  }

  /// Set up recurring payment with payment sheet
  Future<void> setupRecurringPayment({
    required String priceId,
    required String policyId,
    required double amount,
  }) async {
    try {
      // Create subscription
      final subscriptionData = await createSubscription(
        priceId: priceId,
        policyId: policyId,
      );

      // Initialize payment sheet for subscription
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: subscriptionData['clientSecret'],
          merchantDisplayName: 'Pet Underwriter AI',
          customerId: subscriptionData['customerId'],
          customerEphemeralKeySecret: subscriptionData['ephemeralKey'],
          style: ThemeMode.system,
        ),
      );

      // Present payment sheet
      await Stripe.instance.presentPaymentSheet();

      // Subscription successful
      await _recordSubscription(
        policyId: policyId,
        subscriptionId: subscriptionData['subscriptionId'],
        amount: amount,
      );
    } catch (e) {
      if (e is StripeException) {
        throw Exception('Stripe error: ${e.error.localizedMessage}');
      } else {
        throw Exception('Subscription setup failed: $e');
      }
    }
  }

  /// Cancel subscription
  Future<void> cancelSubscription(String subscriptionId) async {
    try {
      final callable = _functions.httpsCallable('cancelSubscription');
      await callable.call({'subscriptionId': subscriptionId});
    } catch (e) {
      throw Exception('Error canceling subscription: $e');
    }
  }

  /// Record payment in Firestore
  Future<void> _recordPayment({
    required String policyId,
    required double amount,
    required String paymentIntentId,
    required String status,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('payments').add({
      'userId': user.uid,
      'policyId': policyId,
      'amount': amount,
      'paymentIntentId': paymentIntentId,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Record subscription in Firestore
  Future<void> _recordSubscription({
    required String policyId,
    required String subscriptionId,
    required double amount,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('subscriptions').add({
      'userId': user.uid,
      'policyId': policyId,
      'subscriptionId': subscriptionId,
      'amount': amount,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get payment history for user
  Future<List<Map<String, dynamic>>> getPaymentHistory() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final snapshot = await _firestore
        .collection('payments')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  /// Get active subscriptions for user
  Future<List<Map<String, dynamic>>> getActiveSubscriptions() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final snapshot = await _firestore
        .collection('subscriptions')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'active')
        .get();

    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }
}
