import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

/// Initialize Firestore with default admin settings
/// Run this once after deployment: dart run lib/scripts/init_firestore.dart
Future<void> main() async {
  print('🔧 Initializing Firestore Admin Settings...\n');
  
  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    final firestore = FirebaseFirestore.instance;
    
    // Initialize underwriting rules
    print('📋 Creating admin_settings/underwriting_rules...');
    await firestore.collection('admin_settings').doc('underwriting_rules').set({
      'maxRiskScore': 90,
      'minAgeMonths': 2,
      'maxAgeYears': 14,
      'excludedBreeds': [
        'Wolf Hybrid',
        'Wolf Dog',
        'Pit Bull Terrier',
        'American Pit Bull Terrier',
        'Staffordshire Bull Terrier',
        'Presa Canario',
        'Dogo Argentino',
      ],
      'criticalConditions': [
        'cancer',
        'terminal illness',
        'end stage kidney disease',
        'end stage liver disease',
        'congestive heart failure',
        'malignant tumor',
        'terminal cancer',
        'metastatic cancer',
      ],
      'enabled': true,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
    print('✅ Underwriting rules created\n');
    
    print('✅ Firestore initialization complete!');
    print('\n📝 Next steps:');
    print('   1. Verify rules in Firebase Console: Firestore → admin_settings → underwriting_rules');
    print('   2. Re-run your app - permission errors should be resolved');
    
  } catch (e) {
    print('❌ Error initializing Firestore: $e');
    print('\n🔍 Troubleshooting:');
    print('   1. Ensure Firebase is configured (firebase_options.dart exists)');
    print('   2. Ensure firestore.rules are deployed: firebase deploy --only firestore:rules');
    print('   3. Check Firebase Console for any auth/permission issues');
  }
}
