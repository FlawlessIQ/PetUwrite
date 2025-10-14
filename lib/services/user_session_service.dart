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
    if (user == null) throw Exception('User not authenticated');

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
