import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/claim.dart';

/// AI Retraining Service
/// 
/// Collects data from settled claims to create training datasets for AI model improvement.
/// 
/// Responsibilities:
/// 1. Collect AI decisions and human overrides from settled claims
/// 2. Automatically label data (correct/misclassified)
/// 3. Store in batches of 500 records
/// 4. Export batches to Google Cloud Storage
/// 5. Generate JSONL datasets for fine-tuning
/// 
/// Flow:
/// Settled Claim → Extract AI Decision + Human Override → Label Data → 
/// Add to Current Batch → When 500 records → Export to GCS → Notify Admin
class AIRetrainingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  static const int batchSize = 500;
  static const String trainingDataCollection = 'ai_training_data';
  static const String batchMetadataCollection = 'ai_training_batches';

  /// Collect training data from a settled claim
  /// Called automatically when a claim reaches 'settled' status
  Future<void> collectTrainingDataFromClaim(String claimId) async {
    try {
      // Get claim data
      final claimDoc = await _firestore.collection('claims').doc(claimId).get();
      
      if (!claimDoc.exists) {
        throw Exception('Claim not found: $claimId');
      }

      final claimData = claimDoc.data()!;
      final claim = Claim.fromMap(claimData, claimId);

      // Only process settled claims with both AI decision and human override
      if (claim.status != ClaimStatus.settled) {
        return; // Not ready for training data collection
      }

      if (claim.aiDecision == null || claim.humanOverride == null) {
        return; // Missing required data
      }

      // Extract training features
      final trainingRecord = await _extractTrainingFeatures(claim);

      // Label the data
      final labeledRecord = _labelTrainingData(trainingRecord);

      // Add to current batch
      await _addToCurrentBatch(labeledRecord);

    } catch (e) {
      throw Exception('Failed to collect training data from claim: $e');
    }
  }

  /// Extract features from claim for training
  Future<Map<String, dynamic>> _extractTrainingFeatures(Claim claim) async {
    // Get additional context
    final policyDoc = await _firestore.collection('policies').doc(claim.policyId).get();
    final petDoc = await _firestore.collection('pets').doc(claim.petId).get();

    final policyData = policyDoc.data() ?? {};
    final petData = petDoc.data() ?? {};

    return {
      'claimId': claim.claimId,
      'timestamp': FieldValue.serverTimestamp(),
      
      // Claim details
      'claimType': claim.claimType,
      'claimAmount': claim.claimAmount,
      'currency': claim.currency,
      'incidentDate': claim.incidentDate,
      'description': claim.description,
      
      // Pet details
      'petBreed': petData['breed'],
      'petAge': petData['age'],
      'petSpecies': petData['species'],
      'petPreExistingConditions': petData['preExistingConditions'] ?? [],
      
      // Policy details
      'policyTier': policyData['plan']?['tier'],
      'annualLimit': policyData['plan']?['annualLimit'],
      'deductible': policyData['plan']?['deductible'],
      'reimbursementRate': policyData['plan']?['reimbursementPercentage'],
      
      // AI Decision
      'aiDecision': claim.aiDecision!.value,
      'aiConfidenceScore': claim.aiConfidenceScore ?? 0.0,
      'aiReasoning': '', // TODO: Add aiReasoning field to Claim model
      'aiCategoryScores': {}, // TODO: Add aiCategoryScores field to Claim model
      
      // Human Override
      'humanDecision': claim.humanOverride!['decision'],
      'humanReason': claim.humanOverride!['reason'],
      'overriddenBy': claim.humanOverride!['overriddenBy'],
      'overriddenAt': claim.humanOverride!['overriddenAt'],
      
      // Outcome
      'finalStatus': claim.status.value,
      'settledAmount': claim.claimAmount, // Could be different if adjusted
      'settledAt': claim.settledAt,
      
      // Document analysis (if available)
      'documentsAnalyzed': claim.attachments.length,
      'attachmentUrls': claim.attachments, // Store URLs for reference
    };
  }

  /// Label training data based on AI vs Human decision
  Map<String, dynamic> _labelTrainingData(Map<String, dynamic> record) {
    final aiDecision = record['aiDecision'] as String;
    final humanDecision = record['humanDecision'] as String;
    final aiConfidence = record['aiConfidenceScore'] as double;

    String label;
    String labelCategory;
    double labelConfidence = 1.0;

    // Determine label
    if (aiDecision == humanDecision) {
      // AI was correct
      if (aiDecision == 'approve') {
        label = 'approved_correct';
        labelCategory = 'true_positive';
      } else if (aiDecision == 'deny') {
        label = 'denied_correct';
        labelCategory = 'true_negative';
      } else {
        label = 'escalated_correct';
        labelCategory = 'true_escalation';
      }
    } else {
      // AI was incorrect (misclassified)
      if (aiDecision == 'approve' && humanDecision == 'deny') {
        label = 'false_approval';
        labelCategory = 'false_positive';
      } else if (aiDecision == 'deny' && humanDecision == 'approve') {
        label = 'false_denial';
        labelCategory = 'false_negative';
      } else {
        label = 'misclassified_escalation';
        labelCategory = 'incorrect_escalation';
      }
    }

    // Calculate label confidence based on human override reasoning
    final humanReason = record['humanReason'] as String?;
    if (humanReason != null && humanReason.contains('borderline')) {
      labelConfidence = 0.7; // Lower confidence for borderline cases
    } else if (humanReason != null && humanReason.contains('clear')) {
      labelConfidence = 1.0; // High confidence for clear cases
    } else {
      labelConfidence = 0.85; // Default confidence
    }

    return {
      ...record,
      'label': label,
      'labelCategory': labelCategory,
      'labelConfidence': labelConfidence,
      'aiWasCorrect': aiDecision == humanDecision,
      'confidenceGap': aiConfidence, // How confident AI was (useful for learning)
      'labeledAt': FieldValue.serverTimestamp(),
    };
  }

  /// Add training record to current batch
  Future<void> _addToCurrentBatch(Map<String, dynamic> record) async {
    try {
      // Get or create current batch
      final currentBatch = await _getCurrentBatch();
      final batchId = currentBatch['id'] as String;
      final recordCount = currentBatch['recordCount'] as int;

      // Add record to batch
      await _firestore
          .collection(trainingDataCollection)
          .doc(batchId)
          .collection('records')
          .add(record);

      // Update batch metadata
      await _firestore
          .collection(batchMetadataCollection)
          .doc(batchId)
          .update({
            'recordCount': recordCount + 1,
            'lastUpdated': FieldValue.serverTimestamp(),
          });

      // Check if batch is complete
      if (recordCount + 1 >= batchSize) {
        await _completeBatch(batchId);
      }
    } catch (e) {
      throw Exception('Failed to add record to batch: $e');
    }
  }

  /// Get or create current active batch
  Future<Map<String, dynamic>> _getCurrentBatch() async {
    // Check for existing active batch
    final activeBatchQuery = await _firestore
        .collection(batchMetadataCollection)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (activeBatchQuery.docs.isNotEmpty) {
      final doc = activeBatchQuery.docs.first;
      return {
        'id': doc.id,
        'recordCount': doc.data()['recordCount'] ?? 0,
      };
    }

    // Create new batch
    final batchId = 'batch_${DateTime.now().millisecondsSinceEpoch}';
    await _firestore.collection(batchMetadataCollection).doc(batchId).set({
      'batchId': batchId,
      'status': 'active',
      'recordCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'lastUpdated': FieldValue.serverTimestamp(),
      'targetSize': batchSize,
    });

    return {
      'id': batchId,
      'recordCount': 0,
    };
  }

  /// Complete a batch and trigger export
  Future<void> _completeBatch(String batchId) async {
    try {
      // Update batch status
      await _firestore.collection(batchMetadataCollection).doc(batchId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Trigger export Cloud Function
      await _functions
          .httpsCallable('exportAITrainingBatch')
          .call({'batchId': batchId});

    } catch (e) {
      throw Exception('Failed to complete batch: $e');
    }
  }

  /// Get training statistics
  Future<TrainingStats> getTrainingStats() async {
    try {
      // Get all batches
      final batchesSnapshot = await _firestore
          .collection(batchMetadataCollection)
          .orderBy('createdAt', descending: true)
          .get();

      int totalRecords = 0;
      int completedBatches = 0;
      int activeBatches = 0;
      int exportedBatches = 0;

      for (final doc in batchesSnapshot.docs) {
        final data = doc.data();
        final recordCount = data['recordCount'] ?? 0;
        totalRecords += recordCount as int;

        final status = data['status'] as String?;
        if (status == 'completed') completedBatches++;
        if (status == 'active') activeBatches++;
        if (status == 'exported') exportedBatches++;
      }

      // Get label distribution from most recent completed batch
      final labelDistribution = await _getLabelDistribution();

      // Get accuracy metrics
      final accuracyMetrics = await _getAccuracyMetrics();

      return TrainingStats(
        totalRecords: totalRecords,
        completedBatches: completedBatches,
        activeBatches: activeBatches,
        exportedBatches: exportedBatches,
        currentBatchProgress: await _getCurrentBatchProgress(),
        labelDistribution: labelDistribution,
        accuracyMetrics: accuracyMetrics,
        lastExportDate: await _getLastExportDate(),
      );
    } catch (e) {
      throw Exception('Failed to get training stats: $e');
    }
  }

  /// Get current batch progress
  Future<double> _getCurrentBatchProgress() async {
    final currentBatch = await _getCurrentBatch();
    final recordCount = currentBatch['recordCount'] as int;
    return recordCount / batchSize;
  }

  /// Get label distribution from recent data
  Future<Map<String, int>> _getLabelDistribution() async {
    try {
      // Get most recent completed batch
      final batchQuery = await _firestore
          .collection(batchMetadataCollection)
          .where('status', isEqualTo: 'completed')
          .orderBy('completedAt', descending: true)
          .limit(1)
          .get();

      if (batchQuery.docs.isEmpty) {
        return {};
      }

      final batchId = batchQuery.docs.first.id;
      
      // Get records from this batch
      final recordsSnapshot = await _firestore
          .collection(trainingDataCollection)
          .doc(batchId)
          .collection('records')
          .get();

      final distribution = <String, int>{};
      
      for (final doc in recordsSnapshot.docs) {
        final label = doc.data()['label'] as String?;
        if (label != null) {
          distribution[label] = (distribution[label] ?? 0) + 1;
        }
      }

      return distribution;
    } catch (e) {
      return {};
    }
  }

  /// Calculate AI accuracy metrics
  Future<Map<String, double>> _getAccuracyMetrics() async {
    try {
      // Get all completed batches (last 5 for performance)
      final batchesQuery = await _firestore
          .collection(batchMetadataCollection)
          .where('status', whereIn: ['completed', 'exported'])
          .orderBy('completedAt', descending: true)
          .limit(5)
          .get();

      int totalRecords = 0;
      int correctPredictions = 0;
      int falsePositives = 0;
      int falseNegatives = 0;
      int truePositives = 0;
      // int trueNegatives = 0; // Collected but not yet used in metrics

      for (final batchDoc in batchesQuery.docs) {
        final recordsSnapshot = await _firestore
            .collection(trainingDataCollection)
            .doc(batchDoc.id)
            .collection('records')
            .get();

        for (final record in recordsSnapshot.docs) {
          final data = record.data();
          totalRecords++;

          final aiWasCorrect = data['aiWasCorrect'] as bool? ?? false;
          final labelCategory = data['labelCategory'] as String?;

          if (aiWasCorrect) correctPredictions++;

          if (labelCategory == 'false_positive') falsePositives++;
          if (labelCategory == 'false_negative') falseNegatives++;
          if (labelCategory == 'true_positive') truePositives++;
          // if (labelCategory == 'true_negative') trueNegatives++;
        }
      }

      if (totalRecords == 0) {
        return {
          'accuracy': 0.0,
          'precision': 0.0,
          'recall': 0.0,
          'f1Score': 0.0,
        };
      }

      final accuracy = correctPredictions / totalRecords;
      
      final precision = (truePositives + falsePositives) > 0
          ? truePositives / (truePositives + falsePositives)
          : 0.0;
      
      final recall = (truePositives + falseNegatives) > 0
          ? truePositives / (truePositives + falseNegatives)
          : 0.0;
      
      final f1Score = (precision + recall) > 0
          ? 2 * (precision * recall) / (precision + recall)
          : 0.0;

      return {
        'accuracy': accuracy,
        'precision': precision,
        'recall': recall,
        'f1Score': f1Score,
      };
    } catch (e) {
      return {
        'accuracy': 0.0,
        'precision': 0.0,
        'recall': 0.0,
        'f1Score': 0.0,
      };
    }
  }

  /// Get last export date
  Future<DateTime?> _getLastExportDate() async {
    try {
      final exportedBatchQuery = await _firestore
          .collection(batchMetadataCollection)
          .where('status', isEqualTo: 'exported')
          .orderBy('exportedAt', descending: true)
          .limit(1)
          .get();

      if (exportedBatchQuery.docs.isEmpty) {
        return null;
      }

      final exportedAt = exportedBatchQuery.docs.first.data()['exportedAt'];
      if (exportedAt is Timestamp) {
        return exportedAt.toDate();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get recent training batches
  Future<List<TrainingBatch>> getRecentBatches({int limit = 10}) async {
    try {
      final batchesSnapshot = await _firestore
          .collection(batchMetadataCollection)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return batchesSnapshot.docs
          .map((doc) => TrainingBatch.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get recent batches: $e');
    }
  }

  /// Manually trigger batch export (admin only)
  Future<void> triggerBatchExport(String batchId) async {
    try {
      await _functions
          .httpsCallable('exportAITrainingBatch')
          .call({'batchId': batchId});
    } catch (e) {
      throw Exception('Failed to trigger batch export: $e');
    }
  }

  /// Get export history
  Future<List<ExportHistory>> getExportHistory({int limit = 20}) async {
    try {
      final exportsSnapshot = await _firestore
          .collection('ai_training_exports')
          .orderBy('exportedAt', descending: true)
          .limit(limit)
          .get();

      return exportsSnapshot.docs
          .map((doc) => ExportHistory.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get export history: $e');
    }
  }
}

/// Training statistics model
class TrainingStats {
  final int totalRecords;
  final int completedBatches;
  final int activeBatches;
  final int exportedBatches;
  final double currentBatchProgress;
  final Map<String, int> labelDistribution;
  final Map<String, double> accuracyMetrics;
  final DateTime? lastExportDate;

  TrainingStats({
    required this.totalRecords,
    required this.completedBatches,
    required this.activeBatches,
    required this.exportedBatches,
    required this.currentBatchProgress,
    required this.labelDistribution,
    required this.accuracyMetrics,
    this.lastExportDate,
  });

  double get accuracy => accuracyMetrics['accuracy'] ?? 0.0;
  double get precision => accuracyMetrics['precision'] ?? 0.0;
  double get recall => accuracyMetrics['recall'] ?? 0.0;
  double get f1Score => accuracyMetrics['f1Score'] ?? 0.0;

  int get recordsInCurrentBatch => (currentBatchProgress * 500).round();
  int get recordsNeededForExport => 500 - recordsInCurrentBatch;
}

/// Training batch model
class TrainingBatch {
  final String batchId;
  final String status;
  final int recordCount;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? exportedAt;
  final String? exportPath;

  TrainingBatch({
    required this.batchId,
    required this.status,
    required this.recordCount,
    required this.createdAt,
    this.completedAt,
    this.exportedAt,
    this.exportPath,
  });

  factory TrainingBatch.fromMap(String id, Map<String, dynamic> map) {
    return TrainingBatch(
      batchId: id,
      status: map['status'] ?? 'unknown',
      recordCount: map['recordCount'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      completedAt: map['completedAt'] != null
          ? (map['completedAt'] as Timestamp).toDate()
          : null,
      exportedAt: map['exportedAt'] != null
          ? (map['exportedAt'] as Timestamp).toDate()
          : null,
      exportPath: map['exportPath'],
    );
  }

  bool get isComplete => status == 'completed' || status == 'exported';
  bool get isExported => status == 'exported';
  double get progress => recordCount / 500.0;
}

/// Export history model
class ExportHistory {
  final String exportId;
  final String batchId;
  final DateTime exportedAt;
  final String format;
  final String gcsPath;
  final int recordCount;
  final Map<String, dynamic> metadata;

  ExportHistory({
    required this.exportId,
    required this.batchId,
    required this.exportedAt,
    required this.format,
    required this.gcsPath,
    required this.recordCount,
    required this.metadata,
  });

  factory ExportHistory.fromMap(String id, Map<String, dynamic> map) {
    return ExportHistory(
      exportId: id,
      batchId: map['batchId'] ?? '',
      exportedAt: (map['exportedAt'] as Timestamp).toDate(),
      format: map['format'] ?? 'jsonl',
      gcsPath: map['gcsPath'] ?? '',
      recordCount: map['recordCount'] ?? 0,
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }

  String get fileName => gcsPath.split('/').last;
}
