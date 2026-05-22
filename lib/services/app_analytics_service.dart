import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AppAnalyticsService {
  AppAnalyticsService._();

  static final AppAnalyticsService instance = AppAnalyticsService._();

  Future<void> track(
    String eventName, {
    Map<String, Object?> properties = const {},
  }) async {
    debugPrint('[Analytics] $eventName $properties');

    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('client_events').add({
        'event': eventName,
        'properties': properties,
        'userId': user?.uid,
        'isAnonymous': user?.isAnonymous,
        'surface': 'post_auth_app',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      debugPrint('[Analytics] Failed to persist $eventName: $error');
    }
  }
}
