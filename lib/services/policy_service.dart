import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/checkout_state.dart';
import '../models/pet.dart';
import '../services/quote_engine.dart';

/// Service for creating and managing insurance policies
class PolicyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Create a new policy document in Firestore
  Future<PolicyDocument> createPolicy({
    required Pet pet,
    required OwnerDetails owner,
    required Plan plan,
    required PaymentInfo payment,
    required String policyNumber,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final now = DateTime.now();
      final effectiveDate = now;
      final expirationDate = DateTime(now.year + 1, now.month, now.day);

      // Create policy document
      final policyRef = _firestore.collection('policies').doc();
      
      final policy = PolicyDocument(
        policyId: policyRef.id,
        policyNumber: policyNumber,
        pet: pet,
        owner: owner,
        plan: plan,
        payment: payment,
        effectiveDate: effectiveDate,
        expirationDate: expirationDate,
        createdAt: now,
        status: 'active',
      );

      // Save to Firestore
      final documentData = {
        ...policy.toJson(),
        'ownerId': user.uid,  // Changed from userId to ownerId to match Firestore rules
        'createdBy': user.email,
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      
      print('🔍 Saving policy document with data: ${documentData.keys.toList()}');
      print('🔍 OwnerId being saved: ${user.uid}');
      print('🔍 Current user authenticated: ${user.email}');
      
      await policyRef.set(documentData);

      // Create user policy reference
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('policies')
          .doc(policyRef.id)
          .set({
        'policyId': policyRef.id,
        'policyNumber': policyNumber,
        'petId': pet.id,
        'petName': pet.name,
        'planName': plan.name,
        'monthlyPremium': plan.monthlyPremium,
        'status': 'active',
        'effectiveDate': effectiveDate.toIso8601String(),
        'expirationDate': expirationDate.toIso8601String(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      return policy;
    } catch (e) {
      throw Exception('Failed to create policy: ${e.toString()}');
    }
  }

  /// Get a policy by ID
  Future<PolicyDocument?> getPolicy(String policyId) async {
    try {
      final doc = await _firestore.collection('policies').doc(policyId).get();
      
      if (!doc.exists) {
        return null;
      }

      return PolicyDocument.fromJson(doc.data()!);
    } catch (e) {
      throw Exception('Failed to get policy: ${e.toString()}');
    }
  }

  /// Get all policies for current user
  Future<List<PolicyDocument>> getUserPolicies() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final querySnapshot = await _firestore
          .collection('policies')
          .where('ownerId', isEqualTo: user.uid)  // Changed from userId to ownerId
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => PolicyDocument.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get user policies: ${e.toString()}');
    }
  }

  /// Update policy status
  Future<void> updatePolicyStatus(String policyId, String status) async {
    try {
      await _firestore.collection('policies').doc(policyId).update({
        'status': status,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Update user's policy reference
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('policies')
            .doc(policyId)
            .update({
          'status': status,
        });
      }
    } catch (e) {
      throw Exception('Failed to update policy status: ${e.toString()}');
    }
  }

  /// Cancel a policy
  Future<void> cancelPolicy(String policyId, String reason) async {
    try {
      await _firestore.collection('policies').doc(policyId).update({
        'status': 'cancelled',
        'cancellationReason': reason,
        'cancelledAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Update user's policy reference
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('policies')
            .doc(policyId)
            .update({
          'status': 'cancelled',
        });
      }
    } catch (e) {
      throw Exception('Failed to cancel policy: ${e.toString()}');
    }
  }

  /// Generate policy PDF document
  Future<String> generatePolicyPDF(PolicyDocument policy) async {
    try {
      final callable = _functions.httpsCallable('generatePolicyPDF');
      final result = await callable.call({
        'policyId': policy.policyId,
        'policyNumber': policy.policyNumber,
        'policyData': policy.toJson(),
      });

      final data = result.data as Map<String, dynamic>;
      return data['pdfUrl'] as String;
    } catch (e) {
      throw Exception('Failed to generate PDF: ${e.toString()}');
    }
  }

  /// Send policy email with PDF attachment
  Future<void> sendPolicyEmail(PolicyDocument policy) async {
    try {
      final callable = _functions.httpsCallable('sendPolicyEmail');
      await callable.call({
        'policyId': policy.policyId,
        'policyNumber': policy.policyNumber,
        'recipientEmail': policy.owner.email,
        'recipientName': policy.owner.fullName,
        'policyData': policy.toJson(),
      });
    } catch (e) {
      throw Exception('Failed to send email: ${e.toString()}');
    }
  }

  /// Record a policy renewal
  Future<PolicyDocument> renewPolicy(String policyId) async {
    try {
      final existingPolicy = await getPolicy(policyId);
      if (existingPolicy == null) {
        throw Exception('Policy not found');
      }

      final now = DateTime.now();
      final effectiveDate = existingPolicy.expirationDate;
      final expirationDate = DateTime(
        effectiveDate.year + 1,
        effectiveDate.month,
        effectiveDate.day,
      );

      // Create new policy document for renewal
      final policyRef = _firestore.collection('policies').doc();
      
      final renewalPolicy = PolicyDocument(
        policyId: policyRef.id,
        policyNumber: '${existingPolicy.policyNumber}R',
        pet: existingPolicy.pet,
        owner: existingPolicy.owner,
        plan: existingPolicy.plan,
        payment: existingPolicy.payment,
        effectiveDate: effectiveDate,
        expirationDate: expirationDate,
        createdAt: now,
        status: 'active',
      );

      await policyRef.set({
        ...renewalPolicy.toJson(),
        'ownerId': _auth.currentUser!.uid,  // Changed from userId to ownerId
        'originalPolicyId': policyId,
        'isRenewal': true,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Update old policy status
      await updatePolicyStatus(policyId, 'renewed');

      return renewalPolicy;
    } catch (e) {
      throw Exception('Failed to renew policy: ${e.toString()}');
    }
  }

  /// Get policy statistics for a user
  Future<Map<String, dynamic>> getPolicyStatistics(String userId) async {
    try {
      final policies = await _firestore
          .collection('policies')
          .where('ownerId', isEqualTo: userId)  // Changed from userId to ownerId
          .get();

      int activePolicies = 0;
      int cancelledPolicies = 0;
      int expiredPolicies = 0;
      double totalPremiums = 0;

      for (final doc in policies.docs) {
        final data = doc.data();
        final status = data['status'] as String?;
        final premium = (data['plan'] as Map?)?['monthlyPremium'] as num? ?? 0;

        if (status == 'active') {
          activePolicies++;
          totalPremiums += premium.toDouble();
        } else if (status == 'cancelled') {
          cancelledPolicies++;
        } else if (status == 'expired') {
          expiredPolicies++;
        }
      }

      return {
        'totalPolicies': policies.docs.length,
        'activePolicies': activePolicies,
        'cancelledPolicies': cancelledPolicies,
        'expiredPolicies': expiredPolicies,
        'totalMonthlyPremiums': totalPremiums,
        'totalAnnualPremiums': totalPremiums * 12,
      };
    } catch (e) {
      throw Exception('Failed to get statistics: ${e.toString()}');
    }
  }
}
