#!/bin/bash

# Deploy PetUwrite to Firebase Hosting with OpenAI API key enabled
# This script builds the Flutter web app with the API key from .env and deploys it

echo "🚀 Building Flutter web app with OpenAI API key..."

# Load API key from .env file
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "❌ Error: .env file not found"
    exit 1
fi

if [ -z "$OPENAI_API_KEY" ]; then
    echo "❌ Error: OPENAI_API_KEY not found in .env file"
    exit 1
fi

echo "✅ API key loaded from .env"

# Build with the API key as a compile-time constant
flutter build web --release --dart-define=OPENAI_API_KEY=$OPENAI_API_KEY

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
