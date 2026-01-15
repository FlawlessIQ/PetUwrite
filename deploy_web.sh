#!/bin/bash

echo "🚀 Building Flutter web app..."

# IMPORTANT: API keys must NOT be injected into the web build.
# All AI calls go through Firebase Functions, which read keys from Secret Manager.
flutter build web --release

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo "🚀 Deploying to Firebase Hosting..."
    firebase deploy --only hosting
    
    if [ $? -eq 0 ]; then
        echo "✅ Deployment complete!"
        echo "🌐 Your app is live at: https://pet-underwriter-ai.web.app"
    else
        echo "❌ Deployment failed"
        exit 1
    fi
else
    echo "❌ Build failed"
    exit 1
fi
