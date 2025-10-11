import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/pet.dart';
import '../models/owner.dart';
import '../models/quote.dart';
import '../models/policy.dart';

/// Service class for Firebase operations
class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Collections
  static const String _petsCollection = 'pets';
  static const String _ownersCollection = 'owners';
  static const String _quotesCollection = 'quotes';
  static const String _policiesCollection = 'policies';
  
  // Authentication
  Future<User?> get currentUser async => _auth.currentUser;
  
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }
  
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }
  
  Future<void> signOut() async {
    await _auth.signOut();
  }
  
  // Pet operations
  Future<void> savePet(Pet pet) async {
    await _firestore.collection(_petsCollection).doc(pet.id).set(pet.toJson());
  }
  
  Future<Pet?> getPet(String petId) async {
    final doc = await _firestore.collection(_petsCollection).doc(petId).get();
    if (doc.exists) {
      return Pet.fromJson(doc.data()!);
    }
    return null;
  }
  
  Stream<List<Pet>> getPetsByOwner(String ownerId) {
    return _firestore
        .collection(_petsCollection)
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Pet.fromJson(doc.data()))
            .toList());
  }
  
  Future<void> updatePet(Pet pet) async {
    await _firestore.collection(_petsCollection).doc(pet.id).update(pet.toJson());
  }
  
  Future<void> deletePet(String petId) async {
    await _firestore.collection(_petsCollection).doc(petId).delete();
  }
  
  // Owner operations
  Future<void> saveOwner(Owner owner) async {
    await _firestore.collection(_ownersCollection).doc(owner.id).set(owner.toJson());
  }
  
  Future<Owner?> getOwner(String ownerId) async {
    final doc = await _firestore.collection(_ownersCollection).doc(ownerId).get();
    if (doc.exists) {
      return Owner.fromJson(doc.data()!);
    }
    return null;
  }
  
  Future<void> updateOwner(Owner owner) async {
    await _firestore.collection(_ownersCollection).doc(owner.id).update(owner.toJson());
  }
  
  // Quote operations
  Future<void> saveQuote(Quote quote) async {
    await _firestore.collection(_quotesCollection).doc(quote.id).set(quote.toJson());
  }
  
  Future<Quote?> getQuote(String quoteId) async {
    final doc = await _firestore.collection(_quotesCollection).doc(quoteId).get();
    if (doc.exists) {
      return Quote.fromJson(doc.data()!);
    }
    return null;
  }
  
  Stream<List<Quote>> getQuotesByPet(String petId) {
    return _firestore
        .collection(_quotesCollection)
        .where('petId', isEqualTo: petId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Quote.fromJson(doc.data()))
            .toList());
  }
  
  Future<void> updateQuote(Quote quote) async {
    await _firestore.collection(_quotesCollection).doc(quote.id).update(quote.toJson());
  }
  
  // Policy operations
  Future<void> savePolicy(Policy policy) async {
    await _firestore.collection(_policiesCollection).doc(policy.id).set(policy.toJson());
  }
  
  Future<Policy?> getPolicy(String policyId) async {
    final doc = await _firestore.collection(_policiesCollection).doc(policyId).get();
    if (doc.exists) {
      return Policy.fromJson(doc.data()!);
    }
    return null;
  }
  
  Stream<List<Policy>> getPoliciesByOwner(String ownerId) {
    return _firestore
        .collection(_policiesCollection)
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Policy.fromJson(doc.data()))
            .toList());
  }
  
  Future<void> updatePolicy(Policy policy) async {
    await _firestore.collection(_policiesCollection).doc(policy.id).update(policy.toJson());
  }
  
  // Batch operations
  Future<void> batchWrite(List<Function(WriteBatch)> operations) async {
    final batch = _firestore.batch();
    for (final operation in operations) {
      operation(batch);
    }
    await batch.commit();
  }
}
