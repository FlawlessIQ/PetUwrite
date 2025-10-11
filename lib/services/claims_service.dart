import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/claim.dart';

/// Service for managing claims and claims analytics
/// Handles claims submission, aggregation, and training data generation
class ClaimsService {
  final FirebaseFirestore _firestore;

  ClaimsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Submit a new claim
  Future<String> submitClaim({
    required String quoteId,
    required String policyId,
    required double riskScoreAtBind,
    required bool wasApprovedManually,
    required double claimAmount,
    required String claimReason,
    String? diagnosisCode,
    required ClaimOutcome outcome,
  }) async {
    try {
      final claim = InsuranceClaim(
        id: '', // Will be set by Firestore
        quoteId: quoteId,
        policyId: policyId,
        riskScoreAtBind: riskScoreAtBind,
        wasApprovedManually: wasApprovedManually,
        claimAmount: claimAmount,
        claimReason: claimReason,
        diagnosisCode: diagnosisCode,
        outcome: outcome,
        timestamp: DateTime.now(),
      );

      final docRef = await _firestore.collection('claims').add(claim.toMap());
      
      // Auto-generate training data from this claim
      await _generateTrainingDataFromClaim(docRef.id, claim);
      
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to submit claim: $e');
    }
  }

  /// Get all claims
  Stream<List<InsuranceClaim>> getAllClaims() {
    return _firestore
        .collection('claims')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => InsuranceClaim.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Get claims by risk band
  Future<List<InsuranceClaim>> getClaimsByRiskBand(int bandStart, int bandEnd) async {
    try {
      final snapshot = await _firestore
          .collection('claims')
          .where('riskScoreAtBind', isGreaterThanOrEqualTo: bandStart)
          .where('riskScoreAtBind', isLessThan: bandEnd)
          .orderBy('riskScoreAtBind')
          .get();

      return snapshot.docs
          .map((doc) => InsuranceClaim.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to get claims by risk band: $e');
    }
  }

  /// Get claims analytics aggregated by risk bands
  Future<List<RiskBandAnalytics>> getClaimsAnalytics() async {
    try {
      // Get all claims
      final snapshot = await _firestore.collection('claims').get();
      final claims = snapshot.docs
          .map((doc) => InsuranceClaim.fromMap(doc.data(), doc.id))
          .toList();

      // Group by risk bands (0-10, 10-20, ..., 90-100)
      final bandMap = <int, List<InsuranceClaim>>{};
      for (int i = 0; i < 10; i++) {
        bandMap[i] = [];
      }

      for (final claim in claims) {
        bandMap[claim.riskBandIndex]!.add(claim);
      }

      // Calculate analytics for each band
      final analytics = <RiskBandAnalytics>[];
      for (int i = 0; i < 10; i++) {
        final bandClaims = bandMap[i]!;
        final bandStart = i * 10;
        final bandEnd = bandStart + 10;

        if (bandClaims.isEmpty) {
          analytics.add(RiskBandAnalytics(
            band: '$bandStart-$bandEnd',
            bandIndex: i,
            claimCount: 0,
            averageClaimAmount: 0.0,
            claimsFrequency: 0.0,
            approvedCount: 0,
            deniedCount: 0,
            partialCount: 0,
          ));
          continue;
        }

        final totalAmount = bandClaims.fold<double>(
          0.0,
          (sum, claim) => sum + claim.claimAmount,
        );
        final averageAmount = totalAmount / bandClaims.length;

        final approvedCount = bandClaims
            .where((c) => c.outcome == ClaimOutcome.approved)
            .length;
        final deniedCount = bandClaims
            .where((c) => c.outcome == ClaimOutcome.denied)
            .length;
        final partialCount = bandClaims
            .where((c) => c.outcome == ClaimOutcome.partial)
            .length;

        // Get total policies in this risk band to calculate frequency
        final policiesSnapshot = await _firestore
            .collection('policies')
            .where('riskScore', isGreaterThanOrEqualTo: bandStart)
            .where('riskScore', isLessThan: bandEnd)
            .get();
        final totalPoliciesInBand = policiesSnapshot.docs.length;
        
        final claimsFrequency = totalPoliciesInBand > 0
            ? (bandClaims.length / totalPoliciesInBand) * 100
            : 0.0;

        analytics.add(RiskBandAnalytics(
          band: '$bandStart-$bandEnd',
          bandIndex: i,
          claimCount: bandClaims.length,
          averageClaimAmount: averageAmount,
          claimsFrequency: claimsFrequency,
          approvedCount: approvedCount,
          deniedCount: deniedCount,
          partialCount: partialCount,
        ));
      }

      return analytics;
    } catch (e) {
      throw Exception('Failed to get claims analytics: $e');
    }
  }

  /// Get claims for a specific policy
  Future<List<InsuranceClaim>> getClaimsByPolicy(String policyId) async {
    try {
      final snapshot = await _firestore
          .collection('claims')
          .where('policyId', isEqualTo: policyId)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => InsuranceClaim.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to get claims by policy: $e');
    }
  }

  /// Get claims that were manually approved
  Future<List<InsuranceClaim>> getManuallyApprovedClaims() async {
    try {
      final snapshot = await _firestore
          .collection('claims')
          .where('wasApprovedManually', isEqualTo: true)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => InsuranceClaim.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to get manually approved claims: $e');
    }
  }

  /// Get high-value claims (above threshold)
  Future<List<InsuranceClaim>> getHighValueClaims(double threshold) async {
    try {
      final snapshot = await _firestore
          .collection('claims')
          .where('claimAmount', isGreaterThan: threshold)
          .orderBy('claimAmount', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => InsuranceClaim.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to get high-value claims: $e');
    }
  }

  /// Generate heatmap data: X=Risk Band, Y=Avg Claim Amount, Z=Frequency
  Future<Map<String, dynamic>> getHeatmapData() async {
    try {
      final analytics = await getClaimsAnalytics();

      return {
        'bands': analytics.map((a) => a.band).toList(),
        'averageAmounts': analytics.map((a) => a.averageClaimAmount).toList(),
        'frequencies': analytics.map((a) => a.claimsFrequency).toList(),
        'claimCounts': analytics.map((a) => a.claimCount).toList(),
        'approvalRates': analytics.map((a) => a.approvalRate).toList(),
      };
    } catch (e) {
      throw Exception('Failed to get heatmap data: $e');
    }
  }

  /// Generate training data from a filed claim
  /// Links claim data to original quote/policy data for ML retraining
  Future<void> _generateTrainingDataFromClaim(
    String claimId,
    InsuranceClaim claim,
  ) async {
    try {
      // Get original quote data
      final quoteDoc = await _firestore
          .collection('quotes')
          .doc(claim.quoteId)
          .get();

      if (!quoteDoc.exists) {
        print('Warning: Quote ${claim.quoteId} not found for training data');
        return;
      }

      final quoteData = quoteDoc.data()!;
      final petData = quoteData['petData'] as Map<String, dynamic>;

      // Extract training features
      final trainingInput = {
        'breed': petData['breed'] ?? 'Unknown',
        'species': petData['species'] ?? 'dog',
        'age': petData['ageInYears'] ?? 0,
        'weight': petData['weight'] ?? 0.0,
        'isNeutered': petData['isNeutered'] ?? false,
        'conditions': petData['preExistingConditions'] ?? [],
        'riskScore': claim.riskScoreAtBind,
        'wasApprovedManually': claim.wasApprovedManually,
      };

      // Extract training labels
      final trainingLabel = {
        'hadClaim': true,
        'claimAmount': claim.claimAmount,
        'outcome': claim.outcome.value,
        'claimReason': claim.claimReason,
        'diagnosisCode': claim.diagnosisCode,
      };

      // Store in model_training_data collection
      await _firestore.collection('model_training_data').add({
        'claimId': claimId,
        'quoteId': claim.quoteId,
        'policyId': claim.policyId,
        'input': trainingInput,
        'label': trainingLabel,
        'timestamp': FieldValue.serverTimestamp(),
        'dataSource': 'actual_claim',
      });
    } catch (e) {
      print('Warning: Failed to generate training data from claim: $e');
      // Don't throw - training data generation should not block claim submission
    }
  }

  /// Get all training data samples
  Future<List<Map<String, dynamic>>> getTrainingData({int? limit}) async {
    try {
      Query query = _firestore
          .collection('model_training_data')
          .orderBy('timestamp', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      throw Exception('Failed to get training data: $e');
    }
  }

  /// Export training data to JSON format for ML model training
  Future<List<Map<String, dynamic>>> exportTrainingDataForML() async {
    try {
      final trainingData = await getTrainingData();
      
      return trainingData.map((sample) {
        return {
          'input': sample['input'],
          'label': sample['label'],
          'metadata': {
            'claimId': sample['claimId'],
            'quoteId': sample['quoteId'],
            'policyId': sample['policyId'],
            'timestamp': sample['timestamp']?.toString(),
          },
        };
      }).toList();
    } catch (e) {
      throw Exception('Failed to export training data: $e');
    }
  }

  /// Get statistics for training data
  Future<Map<String, dynamic>> getTrainingDataStats() async {
    try {
      final snapshot = await _firestore.collection('model_training_data').get();
      final samples = snapshot.docs;

      int claimCount = 0;
      int approvedCount = 0;
      int deniedCount = 0;
      double totalClaimAmount = 0.0;

      for (final doc in samples) {
        final data = doc.data();
        final label = data['label'] as Map<String, dynamic>;
        
        if (label['hadClaim'] == true) {
          claimCount++;
          totalClaimAmount += (label['claimAmount'] as num).toDouble();
          
          if (label['outcome'] == 'approved') {
            approvedCount++;
          } else if (label['outcome'] == 'denied') {
            deniedCount++;
          }
        }
      }

      return {
        'totalSamples': samples.length,
        'claimsWithData': claimCount,
        'approvedClaims': approvedCount,
        'deniedClaims': deniedCount,
        'averageClaimAmount': claimCount > 0 ? totalClaimAmount / claimCount : 0.0,
        'approvalRate': claimCount > 0 ? (approvedCount / claimCount) * 100 : 0.0,
      };
    } catch (e) {
      throw Exception('Failed to get training data stats: $e');
    }
  }

  /// Create a new operational claim (for claim intake flow)
  Future<String> createClaim(Claim claim) async {
    try {
      final claimRef = _firestore.collection('claims').doc(claim.claimId);
      await claimRef.set(claim.toMap());
      return claim.claimId;
    } catch (e) {
      throw Exception('Failed to create claim: $e');
    }
  }

  /// Save draft claim
  Future<void> saveDraftClaim(Claim claim) async {
    try {
      final claimRef = _firestore.collection('claims').doc(claim.claimId);
      await claimRef.set(claim.toMap(), SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to save draft claim: $e');
    }
  }

  /// Upload claim document to Firebase Storage
  Future<String> uploadClaimDocument(String filePath, String claimId) async {
    try {
      // For now, return a mock URL
      // In production, you'd use Firebase Storage:
      // final storageRef = FirebaseStorage.instance.ref();
      // final fileRef = storageRef.child('claims/$claimId/${DateTime.now().millisecondsSinceEpoch}.jpg');
      // await fileRef.putFile(File(filePath));
      // return await fileRef.getDownloadURL();
      
      return 'https://storage.googleapis.com/pet-underwriter-ai/claims/$claimId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    } catch (e) {
      throw Exception('Failed to upload document: $e');
    }
  }
}
