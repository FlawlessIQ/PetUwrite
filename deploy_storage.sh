#!/bin/bash

# Deploy Firebase Storage Rules and CORS Configuration
# This script deploys storage rules and configures CORS for Firebase Storage

set -e

echo "🔧 Deploying Firebase Storage configuration..."

# Deploy storage rules
echo "📝 Deploying Storage Rules..."
firebase deploy --only storage

# Configure CORS for the storage bucket
echo "🌐 Configuring CORS for Firebase Storage..."
echo "ℹ️  Please run this command manually with your bucket name:"
echo ""
echo "gsutil cors set cors.json gs://pet-underwriter-ai.firebasestorage.app"
echo ""
echo "Or if using Firebase default bucket:"
echo "gsutil cors set cors.json gs://pet-underwriter-ai.appspot.com"
echo ""
echo "⚠️  Note: You need Google Cloud SDK (gcloud) installed to run gsutil commands."
echo "   Install it from: https://cloud.google.com/sdk/docs/install"
echo ""
echo "✅ Storage rules deployed! Don't forget to configure CORS manually."
