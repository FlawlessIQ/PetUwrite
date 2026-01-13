import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'product_catalog.dart';

/// Loads which products (tiers) and riders (add-ons) are enabled.
///
/// Firestore source (admin write): `admin_settings/product_catalog`
/// Public read (unauth quote flows): callable `getProductCatalogPublic`
class ProductCatalogAvailabilityEngine {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  Map<String, dynamic>? _cached;
  DateTime? _cachedAt;
  static const Duration _cacheDuration = Duration(minutes: 15);

  ProductCatalogAvailabilityEngine({FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  Future<Map<String, dynamic>> getAvailability() async {
    if (_cached != null && _cachedAt != null && DateTime.now().difference(_cachedAt!) < _cacheDuration) {
      return _cached!;
    }

    // Prefer callable so unauth quote flows can read it.
    try {
      final callable = _functions.httpsCallable('getProductCatalogPublic');
      final result = await callable.call();

      final raw = result.data;
      final Map<String, dynamic> data = raw is Map
          ? raw.map((key, value) => MapEntry(key.toString(), value))
          : <String, dynamic>{};

      final merged = {
        ..._defaultAvailability(),
        ...data,
      };

      _cached = merged;
      _cachedAt = DateTime.now();
      return merged;
    } catch (e) {
      // Ignore and try Firestore next.
      // Keep log lightweight to avoid noisy console in prod.
      // ignore: avoid_print
      print('ℹ️ getProductCatalogPublic unavailable, falling back to Firestore: $e');
    }

    try {
      final doc = await _firestore.collection('admin_settings').doc('product_catalog').get();
      final merged = {
        ..._defaultAvailability(),
        ...(doc.exists ? (doc.data() ?? <String, dynamic>{}) : <String, dynamic>{}),
      };
      _cached = merged;
      _cachedAt = DateTime.now();
      return merged;
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error loading product catalog availability: $e');
      return _defaultAvailability();
    }
  }

  Map<String, dynamic> _defaultAvailability() {
    return {
      'enabled': true,
      'enabledTiers': {
        'basic': true,
        'standard': true,
        'plus': true,
        'premium': true,
        'unlimited': true,
      },
      'enabledAddOns': {
        for (final a in AddOnType.values) a.name: true,
      },
    };
  }

  void clearCache() {
    _cached = null;
    _cachedAt = null;
  }

  static bool isTierEnabled(Map<String, dynamic> availability, String tierName) {
    final enabled = availability['enabled'] != false;
    final tiers = availability['enabledTiers'];
    final tierEnabled = tiers is Map ? (tiers[tierName] != false) : true;
    return enabled && tierEnabled;
  }

  static bool isAddOnEnabled(Map<String, dynamic> availability, String addOnName) {
    final enabled = availability['enabled'] != false;
    final addOns = availability['enabledAddOns'];
    final addOnEnabled = addOns is Map ? (addOns[addOnName] != false) : true;
    return enabled && addOnEnabled;
  }
}
