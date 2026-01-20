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
    
    // Underwriting rules are authored in the repo and published via tooling.
    // See: tools/underwriting_rules/publish_underwriting_rules.js
    print('ℹ️ Skipping underwriting rules initialization (canonical publish pipeline required)\n');

    // Initialize product catalog availability
    print('📦 Creating admin_settings/product_catalog...');
    await firestore.collection('admin_settings').doc('product_catalog').set({
      'enabled': true,
      'enabledTiers': {
        'basic': true,
        'standard': true,
        'plus': true,
        'premium': true,
        'unlimited': true,
      },
      'enabledAddOns': {
        'examFees': true,
        'wellnessLite': true,
        'wellnessPremium': true,
        'dentalPlus': true,
        'rehab': true,
        'behavioral': true,
        'prescriptionFood': true,
      },
      'lastUpdated': FieldValue.serverTimestamp(),
    });
    print('✅ Product catalog config created\n');
    
    print('✅ Firestore initialization complete!');
    print('\n📝 Next steps:');
    print('   1. Publish underwriting rules: node tools/underwriting_rules/publish_underwriting_rules.js --env dev');
    print('   1b. Verify product config: Firestore → admin_settings → product_catalog');
    print('   2. Re-run your app - permission errors should be resolved');
    
  } catch (e) {
    print('❌ Error initializing Firestore: $e');
    print('\n🔍 Troubleshooting:');
    print('   1. Ensure Firebase is configured (firebase_options.dart exists)');
    print('   2. Ensure firestore.rules are deployed: firebase deploy --only firestore:rules');
    print('   3. Check Firebase Console for any auth/permission issues');
  }
}
