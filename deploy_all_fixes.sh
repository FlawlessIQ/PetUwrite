#!/bin/bash

# Quick deployment script for all claim upload fixes

set -e

echo "🚀 Deploying Claims Upload Fixes..."
echo ""

# Deploy Firestore rules
echo "📝 Deploying Firestore rules..."
firebase deploy --only firestore:rules
echo "✅ Firestore rules deployed"
echo ""

# Deploy Storage rules
echo "📦 Deploying Storage rules..."
firebase deploy --only storage
echo "✅ Storage rules deployed"
echo ""

echo "✨ All fixes deployed successfully!"
echo ""
echo "⚠️  IMPORTANT: Don't forget to configure CORS!"
echo "   See STORAGE_SETUP_URGENT.md for CORS setup instructions"
echo ""
echo "🧪 Test your upload by:"
echo "   1. Restart your Flutter app: flutter run -d chrome"
echo "   2. Navigate to a submitted claim"
echo "   3. Click 'Upload Documents'"
echo "   4. Upload a test file"
echo ""
