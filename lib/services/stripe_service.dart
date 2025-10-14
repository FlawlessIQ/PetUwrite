import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for handling Stripe payments
class StripeService {
  // Stripe Test Publishable Key (safe to use in client-side code)
  static const String _publishableKey = 'pk_test_51SI7vTPzjq9wJkU5zFAJvBSWvFLKfu9Be4klAyLdG8IOjHpQwsw8My1WxhrbagFztc549VKyQAmAtCklGOpbeo4v00IAlWsINb';
  // Secret key should only be used server-side (in Cloud Functions)
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  /// Initialize Stripe with publishable key
  static Future<void> init() async {
    Stripe.publishableKey = _publishableKey;
    await Stripe.instance.applySettings();
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
      
      // Create payment intent on server (Cloud Function)
      final response = await http.post(
        Uri.parse('https://us-central1-pet-underwriter-ai.cloudfunctions.net/createPaymentIntent'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'amount': (amount * 100).round(), // Convert to cents
          'currency': currency,
          'userId': user.uid,
          'policyId': policyId,
        }),
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to create payment intent: ${response.body}');
      }
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
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');
      
      // Get or create Stripe customer
      final customerId = await _getOrCreateCustomer(user.uid);
      
      // Create subscription via Cloud Function
      final response = await http.post(
        Uri.parse('https://us-central1-pet-underwriter-ai.cloudfunctions.net/createSubscription'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'customerId': customerId,
          'priceId': priceId,
          'userId': user.uid,
          'policyId': policyId,
        }),
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to create subscription: ${response.body}');
      }
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
          customerId: paymentIntentData['customer'],
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
          customerId: subscriptionData['customer'],
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
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');
      
      final response = await http.post(
        Uri.parse('https://us-central1-pet-underwriter-ai.cloudfunctions.net/cancelSubscription'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'subscriptionId': subscriptionId,
          'userId': user.uid,
        }),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to cancel subscription: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error canceling subscription: $e');
    }
  }
  
  /// Get or create Stripe customer for user
  Future<String> _getOrCreateCustomer(String userId) async {
    // Check if customer exists in Firestore
    final userDoc = await _firestore.collection('users').doc(userId).get();
    
    if (userDoc.exists && userDoc.data()?['stripeCustomerId'] != null) {
      return userDoc.data()!['stripeCustomerId'] as String;
    }
    
    // Create new customer via Cloud Function
    final response = await http.post(
      Uri.parse('https://us-central1-pet-underwriter-ai.cloudfunctions.net/createCustomer'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'userId': userId,
        'email': _auth.currentUser?.email,
      }),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['customerId'] as String;
    } else {
      throw Exception('Failed to create customer');
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
    
    return snapshot.docs.map((doc) => {
      'id': doc.id,
      ...doc.data(),
    }).toList();
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
    
    return snapshot.docs.map((doc) => {
      'id': doc.id,
      ...doc.data(),
    }).toList();
  }
}
