import 'package:cloud_functions/cloud_functions.dart';

import '../services/quote_engine.dart';

class PricingQuoteService {
  final FirebaseFunctions _functions;

  PricingQuoteService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  Future<List<Plan>> getDayOnePlans({
    required String riskBand,
    required String zipCode,
    String? state,
    int numberOfPets = 1,
    List<String> addOns = const <String>[],
  }) async {
    final callable = _functions.httpsCallable('getPricingQuotePublic');
    final result = await callable.call({
      'riskBand': riskBand,
      'zipCode': zipCode,
      if (state != null) 'state': state,
      'numberOfPets': numberOfPets,
      'addOns': addOns,
    });

    final raw = result.data;
    final Map<String, dynamic> data = raw is Map
        ? raw.map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};

    final rawPlans = data['plans'];
    if (rawPlans is! List) return const <Plan>[];

    return rawPlans
        .whereType<Map>()
        .map((p) => Plan.fromJson(p.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<Plan?> priceSku({
    required String riskBand,
    required String zipCode,
    String? state,
    int numberOfPets = 1,
    required String tier,
    required int reimbursementPercent,
    required int annualDeductible,
    required int? annualLimit,
    List<String> addOns = const <String>[],
  }) async {
    final callable = _functions.httpsCallable('getPricingQuotePublic');
    final result = await callable.call({
      'riskBand': riskBand,
      'zipCode': zipCode,
      if (state != null) 'state': state,
      'numberOfPets': numberOfPets,
      'addOns': addOns,
      'skus': [
        {
          'tier': tier,
          'reimb': reimbursementPercent,
          'ded': annualDeductible,
          'limit': annualLimit,
        }
      ],
    });

    final raw = result.data;
    final Map<String, dynamic> data = raw is Map
        ? raw.map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};

    final rawPlans = data['plans'];
    if (rawPlans is! List || rawPlans.isEmpty) return null;

    final first = rawPlans.first;
    if (first is! Map) return null;
    return Plan.fromJson(first.cast<String, dynamic>());
  }
}
