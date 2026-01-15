#!/usr/bin/env dart
// Dart CLI Tool to Seed Underwriting Rules to Firestore
// Usage: dart run bin/seed_underwriting_rules.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Seed underwriting rules to Firestore
/// Creates admin_settings/underwriting_rules document with complete schema
Future<void> main() async {
  print('🔧 Starting Firestore Underwriting Rules Seeder...\n');

  try {
    // Initialize Firebase (requires firebase_options.dart)
    print('📱 Initializing Firebase...');
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'YOUR_API_KEY', // Replace with your Firebase config
        appId: 'YOUR_APP_ID',
        messagingSenderId: 'YOUR_SENDER_ID',
        projectId: 'YOUR_PROJECT_ID',
      ),
    );
    print('✅ Firebase initialized\n');

    final firestore = FirebaseFirestore.instance;

    // Prepare underwriting rules document
    print('📋 Preparing underwriting rules document...');
    final underwritingRules = {
      'enabled': true,
      'maxRiskScore': 85,
      'minAgeMonths': 8,
      'maxAgeYears': 12,
      'excludedBreeds': [
        'Wolf Hybrid',
        'Pit Bull Terrier',
        'American Bulldog',
        'Presa Canario',
        'Cane Corso',
        'Dogo Argentino',
      ],
      'criticalConditions': [
        'cancer',
        'heart murmur',
        'epilepsy',
        'terminal illness',
        'seizure disorder',
        'chronic kidney disease',
      ],
      'excludableConditions': [
        // Orthopedic / musculoskeletal
        'cruciate',
        'cranial cruciate ligament',
        'degenerative joint disease',
        'djd',
        'arthritis',
        'osteoarthritis',
        'hip dysplasia',
        'patellar luxation',
        'luxating patella',
        'elbow dysplasia',
        // Spine
        'intervertebral disc disease',
        'ivdd',
        // Other common exclusions
        'allergies',
        'skin conditions',
        'ear infections',
        'diabetes',
        'asthma',
        'dental disease',
        'obesity',
        'anxiety',
      ],
      'rejectionRules': [
        {
          'ruleId': 'AGE_TOO_YOUNG',
          'description': 'Pet is too young for coverage',
          'condition': 'pet.ageMonths < minAgeMonths',
          'autoDecline': true,
        },
        {
          'ruleId': 'AGE_TOO_OLD',
          'description': 'Pet exceeds maximum age for new policies',
          'condition': 'pet.ageMonths > maxAgeYears * 12',
          'autoDecline': true,
        },
        {
          'ruleId': 'BREED_EXCLUDED',
          'description': 'Breed is excluded from underwriting',
          'condition': 'pet.breed in excludedBreeds',
          'autoDecline': true,
        },
        {
          'ruleId': 'HIGH_RISK_SCORE',
          'description': 'AI Risk Score exceeds allowable maximum',
          'condition': 'riskScore.total > maxRiskScore',
          'autoDecline': true,
        },
        {
          'ruleId': 'CRITICAL_CONDITION',
          'description': 'Pre-existing condition is uninsurable',
          'condition': 'pet.conditions containsAny criticalConditions',
          'autoDecline': true,
        },
      ],
      'aiPromptOverrides': {
        'riskDeclineTriggers': [
          'riskScore > 85',
          'condition in [cancer, epilepsy, terminal illness]',
          'breed in [Wolf Hybrid, Pit Bull Terrier]',
          'pet.ageMonths < 8 or pet.ageYears > 12',
        ],
        'recommendationLogic':
            'If any of the above are true, recommend: eligibility = \'deny\'',
      },
      'lastUpdated': FieldValue.serverTimestamp(),
      'updatedBy': 'system_seed',
    };

    // Write to Firestore
    print('💾 Writing to Firestore: admin_settings/underwriting_rules...');
    await firestore
        .collection('admin_settings')
        .doc('underwriting_rules')
        .set(underwritingRules);

    print('\n✅ Underwriting rules successfully seeded to Firestore.');
    print('\n📊 Summary:');
    print('   Collection: admin_settings');
    print('   Document: underwriting_rules');
    print('   Max Risk Score: ${underwritingRules['maxRiskScore']}');
    print(
      '   Age Range: ${underwritingRules['minAgeMonths']} months - ${underwritingRules['maxAgeYears']} years',
    );
    print(
      '   Excluded Breeds: ${(underwritingRules['excludedBreeds'] as List).length}',
    );
    print(
      '   Critical Conditions: ${(underwritingRules['criticalConditions'] as List).length}',
    );
    print(
      '   Excludable Conditions: ${(underwritingRules['excludableConditions'] as List).length}',
    );
    print(
      '   Rejection Rules: ${(underwritingRules['rejectionRules'] as List).length}',
    );
    print('\n🎯 Next Steps:');
    print(
      '   1. Verify in Firebase Console: Firestore → admin_settings → underwriting_rules',
    );
    print('   2. Run your app - permission errors should be resolved');
    print(
      '   3. Test underwriting flow with excluded breeds and critical conditions',
    );

    exit(0);
  } catch (e) {
    print('\n❌ Error seeding underwriting rules: $e');
    print('\n🔍 Troubleshooting:');
    print('   1. Ensure Firebase is configured in your project');
    print(
      '   2. Update Firebase options in this script with your project config',
    );
    print(
      '   3. Ensure firestore.rules allow authenticated writes to admin_settings',
    );
    print('   4. Check Firebase Console for any authentication errors');
    print(
      '\n💡 Alternative: Use the Node.js version (seed_underwriting_rules.js) with Admin SDK',
    );
    exit(1);
  }
}
