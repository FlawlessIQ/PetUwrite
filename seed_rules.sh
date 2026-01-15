#!/bin/bash
# Quick helper script to run the underwriting rules seeder

echo "═══════════════════════════════════════════════════════════"
echo "  Clovara - Underwriting Rules Seeder Helper"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Check if we're in the right directory
if [ ! -d "functions" ]; then
    echo "❌ Error: Must run from Clovara root directory"
    echo "   Current: $(pwd)"
    echo "   Expected: /path/to/Clovara"
    echo ""
    echo "📝 Run: cd /path/to/Clovara && ./seed_rules.sh"
    exit 1
fi

# Check if firebase-service-account.json exists
if [ ! -f "functions/firebase-service-account.json" ] && [ -z "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
    echo "⚠️  Warning: No Firebase credentials found"
    echo ""
    echo "📝 Please choose ONE of these options:"
    echo ""
    echo "   Option 1: Download Service Account Key (Recommended)"
    echo "   ────────────────────────────────────────────────────"
    echo "   1. Go to Firebase Console → Project Settings → Service Accounts"
    echo "   2. Click 'Generate New Private Key'"
    echo "   3. Save as: functions/firebase-service-account.json"
    echo "   4. Re-run: ./seed_rules.sh"
    echo ""
    echo "   Option 2: Set Environment Variable"
    echo "   ────────────────────────────────────────────────────"
    echo "   export GOOGLE_APPLICATION_CREDENTIALS='/path/to/key.json'"
    echo "   ./seed_rules.sh"
    echo ""
    exit 1
fi

# Check if node_modules exists
if [ ! -d "functions/node_modules" ]; then
    echo "📦 Installing dependencies..."
    cd functions
    npm install
    cd ..
    echo ""
fi

# Run the seeder
echo "🚀 Running underwriting rules seeder..."
echo ""
cd functions
node seed_underwriting_rules.js
exit_code=$?

if [ $exit_code -eq 0 ]; then
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  ✅ SUCCESS - Underwriting rules seeded!"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "🎯 Next Steps:"
    echo "   1. Verify in Firebase Console: Firestore → admin_settings"
    echo "   2. Restart your Flutter app"
    echo "   3. Test quote flow - errors should be gone"
    echo ""
else
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  ❌ FAILED - See errors above"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "📖 For help, see: SEED_UNDERWRITING_RULES_SETUP.md"
    echo ""
fi

cd ..
exit $exit_code
