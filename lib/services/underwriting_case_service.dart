import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/owner.dart';
import '../models/pet.dart';
import '../models/underwriting_case.dart';
import '../models/underwriting_decision.dart';
import '../models/underwriting_medical_history.dart';

class UnderwritingCaseService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  UnderwritingCaseService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _cases =>
      _firestore.collection('underwriting_cases');

  Future<String> createCase({
    required Pet pet,
    required Owner owner,
    String? quoteId,
    required List<String> triggerReasons,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final now = DateTime.now();
    final docRef = _cases.doc();

    final caseDoc = UnderwritingCase(
      id: docRef.id,
      userId: user.uid,
      quoteId: quoteId,
      petId: pet.id,
      petSnapshot: pet,
      ownerSnapshot: owner,
      status: UnderwritingCaseStatus.inProgress,
      triggerReasons: triggerReasons,
      createdAt: now,
      updatedAt: now,
    );

    await docRef.set({
      ...caseDoc.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Create empty medical_history doc for save/resume.
    await docRef.collection('medical_history').doc('current').set({
      ...UnderwritingMedicalHistory.empty().toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await logEvent(docRef.id, 'case_created', {
      'triggerReasons': triggerReasons,
      'quoteId': quoteId,
    });

    return docRef.id;
  }

  Future<UnderwritingCase?> getCase(String caseId) async {
    final doc = await _cases.doc(caseId).get();
    if (!doc.exists) return null;
    return UnderwritingCase.fromJson(doc.id, doc.data()!);
  }

  Future<UnderwritingMedicalHistory> getMedicalHistory(String caseId) async {
    final doc = await _cases.doc(caseId).collection('medical_history').doc('current').get();
    if (!doc.exists) return UnderwritingMedicalHistory.empty();
    return UnderwritingMedicalHistory.fromJson(doc.data()!);
  }

  Future<void> saveMedicalHistory(String caseId, UnderwritingMedicalHistory history) async {
    await _cases.doc(caseId).collection('medical_history').doc('current').set({
      ...history.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _cases.doc(caseId).update({'updatedAt': FieldValue.serverTimestamp()});
    await logEvent(caseId, 'medical_history_saved', {
      'conditionsCount': history.conditions.length,
      'userAttestation': history.userAttestation,
    });
  }

  Future<void> updateStatus(String caseId, UnderwritingCaseStatus status) async {
    await _cases.doc(caseId).update({
      'status': underwritingCaseStatusToString(status),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await logEvent(caseId, 'status_changed', {
      'status': underwritingCaseStatusToString(status),
    });
  }

  Future<void> saveDecision(String caseId, UnderwritingDecision decision) async {
    await _cases.doc(caseId).collection('decisions').doc('current').set({
      ...decision.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Denormalize a decision summary onto the case doc for fast admin queues and reporting.
    await _cases.doc(caseId).update({
      'updatedAt': FieldValue.serverTimestamp(),
      'decisionOutcome': underwritingOutcomeToString(decision.outcome),
      'decisionReasonCodes': decision.reasonCodes,
      'decisionExclusionsCount': decision.exclusions.length,
      'decisionDecidedAt': FieldValue.serverTimestamp(),
      'decisionDecidedBy': decision.decidedBy,
      'decisionVersion': decision.version,
    });
    await logEvent(caseId, 'decision_saved', {
      'outcome': underwritingOutcomeToString(decision.outcome),
      'reasonCodes': decision.reasonCodes,
      'exclusionsCount': decision.exclusions.length,
      'version': decision.version,
      'decidedBy': decision.decidedBy,
    });
  }

  Future<UnderwritingDecision?> getCurrentDecision(String caseId) async {
    final doc = await _cases.doc(caseId).collection('decisions').doc('current').get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    return UnderwritingDecision.fromJson(data);
  }

  Future<void> logEvent(String caseId, String eventType, Map<String, dynamic> payload) async {
    final user = _auth.currentUser;
    await _cases.doc(caseId).collection('events').add({
      'eventType': eventType,
      'payload': payload,
      'actorUserId': user?.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
