import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class BenchmarkReferenceBand {
  final String metric;
  final double low;
  final double median;
  final double high;
  final String? unit;

  const BenchmarkReferenceBand({
    required this.metric,
    required this.low,
    required this.median,
    required this.high,
    this.unit,
  });

  factory BenchmarkReferenceBand.fromJson(Map<String, dynamic> json) {
    return BenchmarkReferenceBand(
      metric: (json['metric'] ?? '').toString(),
      low: (json['low'] as num?)?.toDouble() ?? 0.0,
      median: (json['median'] as num?)?.toDouble() ?? 0.0,
      high: (json['high'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit']?.toString(),
    );
  }
}

class BenchmarkReferenceCurrent {
  final String activeVersionId;
  final DateTime? updatedAt;

  const BenchmarkReferenceCurrent({
    required this.activeVersionId,
    required this.updatedAt,
  });

  factory BenchmarkReferenceCurrent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final ts = data['updatedAt'];
    return BenchmarkReferenceCurrent(
      activeVersionId: (data['activeVersionId'] ?? '').toString(),
      updatedAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}

class BenchmarkReferenceVersion {
  final String versionId;
  final String source;
  final String? notes;
  final DateTime? createdAt;
  final String? checksum;
  final List<BenchmarkReferenceBand> bands;

  const BenchmarkReferenceVersion({
    required this.versionId,
    required this.source,
    required this.notes,
    required this.createdAt,
    required this.checksum,
    required this.bands,
  });

  factory BenchmarkReferenceVersion.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final ts = data['createdAt'];
    final rawBands = (data['bands'] as List?) ?? const [];
    return BenchmarkReferenceVersion(
      versionId: doc.id,
      source: (data['source'] ?? '').toString(),
      notes: data['notes']?.toString(),
      checksum: data['checksum']?.toString(),
      createdAt: ts is Timestamp ? ts.toDate() : null,
      bands: rawBands
          .whereType<Map>()
          .map((e) => BenchmarkReferenceBand.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false),
    );
  }
}

class PortfolioMetricsSnapshot {
  final String id;
  final DateTime? computedAt;
  final Map<String, dynamic> filters;
  final Map<String, dynamic> metrics;
  final String? benchmarkVersionId;

  const PortfolioMetricsSnapshot({
    required this.id,
    required this.computedAt,
    required this.filters,
    required this.metrics,
    required this.benchmarkVersionId,
  });

  factory PortfolioMetricsSnapshot.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final ts = data['computedAt'];
    return PortfolioMetricsSnapshot(
      id: doc.id,
      computedAt: ts is Timestamp ? ts.toDate() : null,
      filters: (data['filters'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
      metrics: (data['metrics'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
      benchmarkVersionId: data['benchmarkVersionId']?.toString(),
    );
  }
}

class BenchmarkingService {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  BenchmarkingService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  Stream<BenchmarkReferenceCurrent?> watchCurrentReference() {
    return _firestore
        .collection('benchmark_reference_current')
        .doc('current')
        .snapshots()
        .map((doc) => doc.exists ? BenchmarkReferenceCurrent.fromDoc(doc) : null);
  }

  Stream<BenchmarkReferenceVersion?> watchReferenceVersion(String versionId) {
    if (versionId.isEmpty) {
      return const Stream<BenchmarkReferenceVersion?>.empty();
    }
    return _firestore
        .collection('benchmark_reference_versions')
        .doc(versionId)
        .snapshots()
        .map((doc) => doc.exists ? BenchmarkReferenceVersion.fromDoc(doc) : null);
  }

  Stream<List<PortfolioMetricsSnapshot>> watchSnapshots({int limit = 25}) {
    return _firestore
        .collection('portfolio_metrics_snapshots')
        .orderBy('computedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(PortfolioMetricsSnapshot.fromDoc).toList(growable: false));
  }

  Future<Map<String, dynamic>> refreshBenchmarkReference({
    Map<String, dynamic>? reference,
    String? source,
    String? notes,
  }) async {
    final callable = _functions.httpsCallable('refreshBenchmarkReference');
    final result = await callable.call({
      if (reference != null) 'reference': reference,
      if (source != null) 'source': source,
      if (notes != null) 'notes': notes,
    });
    return (result.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> computePortfolioMetricsSnapshot({
    required DateTime start,
    required DateTime end,
    String? cohort,
  }) async {
    final callable = _functions.httpsCallable('computePortfolioMetricsSnapshot');
    final result = await callable.call({
      'startDate': start.toIso8601String(),
      'endDate': end.toIso8601String(),
      if (cohort != null && cohort.trim().isNotEmpty) 'cohort': cohort.trim(),
    });
    return (result.data as Map).cast<String, dynamic>();
  }
}
