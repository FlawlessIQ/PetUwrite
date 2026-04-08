import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Service to manage user session data and quote persistence
class UserSessionService {
  static final UserSessionService _instance = UserSessionService._internal();
  factory UserSessionService() => _instance;
  UserSessionService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Local storage keys
  static const String _pendingQuoteKey = 'pending_quote_data';
  static const String _pendingUnderwritingKey = 'pending_underwriting_data';
  static const String _pendingCheckoutKey = 'pending_checkout_data';
  static const String _quoteAttemptsKey = 'quote_attempts_v1';

  /// Get current authenticated user
  User? get currentUser => _auth.currentUser;

  /// Check if user is authenticated
  bool get isAuthenticated => _auth.currentUser != null;

  /// Get user display name (from Firebase Auth or Firestore)
  Future<String?> getUserName() async {
    final user = currentUser;
    if (user == null) return null;

    // Check Firebase Auth displayName first
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      return user.displayName;
    }

    // Check Firestore user document
    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        final firstName = data['firstName'] as String?;
        final lastName = data['lastName'] as String?;
        if (firstName != null) {
          return lastName != null ? '$firstName $lastName' : firstName;
        }
      }
    } catch (e) {
      print('Error fetching user name from Firestore: $e');
    }

    // Fallback to email
    return user.email?.split('@').first;
  }

  /// Get user email
  String? getUserEmail() {
    return currentUser?.email;
  }

  /// Get user phone number
  Future<String?> getUserPhone() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        return userDoc.data()?['phone'] as String?;
      }
    } catch (e) {
      print('Error fetching user phone: $e');
    }

    return user.phoneNumber;
  }

  /// Get user address/zip code
  Future<String?> getUserZipCode() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        return userDoc.data()?['zipCode'] as String?;
      }
    } catch (e) {
      print('Error fetching user zip code: $e');
    }

    return null;
  }

  /// Get complete user profile data
  Future<Map<String, dynamic>> getUserProfile() async {
    final user = currentUser;
    if (user == null) return {};

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        return userDoc.data() ?? {};
      }
    } catch (e) {
      print('Error fetching user profile: $e');
    }

    return {
      'email': user.email,
      'displayName': user.displayName,
      'phoneNumber': user.phoneNumber,
    };
  }

  /// Update user profile in Firestore
  Future<void> updateUserProfile({
    String? firstName,
    String? lastName,
    String? phone,
    String? zipCode,
    String? address,
  }) async {
    final user = currentUser;
    if (user == null) return; // Deferred until auth is available

    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (firstName != null) updates['firstName'] = firstName;
    if (lastName != null) updates['lastName'] = lastName;
    if (phone != null) updates['phone'] = phone;
    if (zipCode != null) updates['zipCode'] = zipCode;
    if (address != null) updates['address'] = address;

    // Use set with merge:true to create the document if it doesn't exist
    await _firestore.collection('users').doc(user.uid).set(updates, SetOptions(merge: true));
    
    print('✅ User profile updated: ${updates.keys.toList()}');
  }

  /// Save pending quote data locally (for unauthenticated users)
  Future<void> savePendingQuote(Map<String, dynamic> quoteData) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(quoteData);
    await prefs.setString(_pendingQuoteKey, jsonString);
    print('💾 Saved pending quote locally');
  }

  /// Record a quote attempt locally and return a velocity signal.
  ///
  /// This is a deterministic, carrier-grade abuse signal (quote-shopping / retry velocity).
  /// It is intentionally local-only so it works before authentication.
  Future<Map<String, dynamic>> recordQuoteAttempt({required String flow}) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    List<dynamic> raw = const [];
    try {
      final jsonString = prefs.getString(_quoteAttemptsKey);
      if (jsonString != null && jsonString.isNotEmpty) {
        final decoded = jsonDecode(jsonString);
        if (decoded is List) raw = decoded;
      }
    } catch (_) {
      raw = const [];
    }

    final attempts = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is Map) {
        attempts.add(item.cast<String, dynamic>());
      }
    }

    attempts.add({
      't': now.millisecondsSinceEpoch,
      'flow': flow,
    });

    // Prune to last 24h and cap to avoid unbounded growth.
    final cutoff = now.subtract(const Duration(hours: 24)).millisecondsSinceEpoch;
    final pruned = attempts
        .where((e) {
          final t = e['t'];
          return t is int && t >= cutoff;
        })
        .toList(growable: false);

    final capped = pruned.length <= 50
        ? pruned
        : pruned.sublist(pruned.length - 50);

    try {
      await prefs.setString(_quoteAttemptsKey, jsonEncode(capped));
    } catch (_) {
      // Best-effort only; do not break quote UX.
    }

    return _quoteVelocitySignalFromAttempts(capped, now: now);
  }

  Map<String, dynamic> _quoteVelocitySignalFromAttempts(
    List<Map<String, dynamic>> attempts, {
    required DateTime now,
  }) {
    int countSince(Duration window) {
      final cutoff = now.subtract(window).millisecondsSinceEpoch;
      return attempts.where((e) {
        final t = e['t'];
        return t is int && t >= cutoff;
      }).length;
    }

    final attempts2m = countSince(const Duration(minutes: 2));
    final attempts10m = countSince(const Duration(minutes: 10));
    final attempts1h = countSince(const Duration(hours: 1));

    // Conservative thresholds: we only flag obvious patterns.
    final suspicious = attempts10m >= 3 || attempts1h >= 6;

    return {
      'attempts2m': attempts2m,
      'attempts10m': attempts10m,
      'attempts1h': attempts1h,
      'suspicious': suspicious,
      'capturedAt': now.toIso8601String(),
    };
  }

  /// Get pending quote data
  Future<Map<String, dynamic>?> getPendingQuote() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_pendingQuoteKey);
    if (jsonString != null) {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    }
    return null;
  }

  /// Clear pending quote data
  Future<void> clearPendingQuote() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingQuoteKey);
    print('🗑️ Cleared pending quote');
  }

  /// Save a pending underwriting follow-up locally.
  ///
  /// This supports "save & revisit" when underwriting returns NEED_MORE_INFO
  /// (e.g., identity confirmation / missing vet documents).
  Future<void> savePendingUnderwriting({
    required String underwritingCaseId,
    String? petName,
    dynamic riskScore,
    String? reason,
    List<Map<String, dynamic>> requiredEvidence = const [],
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final payload = <String, dynamic>{
      'underwritingCaseId': underwritingCaseId,
      if (petName != null) 'petName': petName,
      if (riskScore != null) 'riskScore': riskScore,
      if (reason != null) 'reason': reason,
      if (requiredEvidence.isNotEmpty) 'requiredEvidence': requiredEvidence,
      'savedAt': DateTime.now().toIso8601String(),
    };

    try {
      await prefs.setString(_pendingUnderwritingKey, jsonEncode(payload));
      print('💾 Saved pending underwriting locally: $underwritingCaseId');
    } catch (e) {
      // Don't crash the flow if local persistence fails.
      print('Error saving pending underwriting: $e');
    }
  }

  /// Get pending underwriting follow-up data.
  Future<Map<String, dynamic>?> getPendingUnderwriting() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_pendingUnderwritingKey);
    if (jsonString == null) return null;
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (e) {
      print('Error reading pending underwriting: $e');
    }
    return null;
  }

  /// Clear any pending underwriting follow-up.
  Future<void> clearPendingUnderwriting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingUnderwritingKey);
    print('🗑️ Cleared pending underwriting');
  }

  /// Save a pending checkout snapshot locally.
  ///
  /// Used for "save & revisit" across owner details + payment (and to restore
  /// checkout step state after app/browser restart).
  Future<void> savePendingCheckout(Map<String, dynamic> checkoutData) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await prefs.setString(_pendingCheckoutKey, jsonEncode(checkoutData));
      print('💾 Saved pending checkout locally');
    } catch (e) {
      print('Error saving pending checkout: $e');
    }
  }

  /// Get pending checkout snapshot.
  Future<Map<String, dynamic>?> getPendingCheckout() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_pendingCheckoutKey);
    if (jsonString == null) return null;
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (e) {
      print('Error reading pending checkout: $e');
    }
    return null;
  }

  /// Clear any pending checkout snapshot.
  Future<void> clearPendingCheckout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingCheckoutKey);
    print('🗑️ Cleared pending checkout');
  }

  /// Save pending quote to Firestore (for authenticated users)
  Future<String> savePendingQuoteToFirestore(Map<String, dynamic> quoteData) async {
    final user = currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Create a pending quote document
    final quoteRef = _firestore.collection('quotes').doc();
    final quoteId = quoteRef.id;

    await quoteRef.set({
      'id': quoteId,
      'ownerId': user.uid,  // Changed from userId to ownerId to match Firestore rules
      'status': 'pending',
      'quoteData': quoteData,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'expiresAt': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
    });

    print('💾 Saved pending quote to Firestore: $quoteId');
    return quoteId;
  }

  /// Get user's pending quotes from Firestore
  Future<List<Map<String, dynamic>>> getUserPendingQuotes() async {
    final user = currentUser;
    if (user == null) return [];

    try {
      final querySnapshot = await _firestore
          .collection('quotes')
          .where('ownerId', isEqualTo: user.uid)  // Changed from userId to ownerId
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      return querySnapshot.docs
          .map((doc) => {
                ...doc.data(),
                'id': doc.id,
              })
          .toList();
    } catch (e) {
      print('Error fetching pending quotes: $e');
      return [];
    }
  }

  /// Resume a pending quote
  Future<Map<String, dynamic>?> resumePendingQuote(String quoteId) async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final quoteDoc = await _firestore.collection('quotes').doc(quoteId).get();
      
      if (!quoteDoc.exists) {
        print('Quote not found: $quoteId');
        return null;
      }

      final data = quoteDoc.data()!;
      
      // Verify ownership (check both ownerId and userId for backwards compatibility)
      final ownerId = data['ownerId'] ?? data['userId'];
      if (ownerId != user.uid) {
        print('Unauthorized access attempt for quote: $quoteId');
        return null;
      }

      return data['quoteData'] as Map<String, dynamic>?;
    } catch (e) {
      print('Error resuming quote: $e');
      return null;
    }
  }

  /// Migrate local pending quote to Firestore when user signs in
  Future<void> migratePendingQuoteOnSignIn() async {
    final user = currentUser;
    if (user == null) return;

    // Check for local pending quote
    final localQuote = await getPendingQuote();
    if (localQuote != null) {
      print('🔄 Migrating local pending quote to Firestore for user: ${user.uid}');
      
      // Save to Firestore
      await savePendingQuoteToFirestore(localQuote);
      
      // Clear local storage
      await clearPendingQuote();
      
      print('✅ Pending quote migrated successfully');
    }
  }

  /// Pre-fill quote data with user information
  Map<String, dynamic> getPrefillData({
    required String? userName,
    required String? email,
    required String? zipCode,
  }) {
    return {
      if (userName != null) 'ownerName': userName,
      if (email != null) 'email': email,
      if (zipCode != null) 'zipCode': zipCode,
    };
  }

  /// Listen to auth state changes and handle quote migration
  void setupAuthStateListener() {
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        // User just signed in
        migratePendingQuoteOnSignIn();
      }
    });
  }
}
