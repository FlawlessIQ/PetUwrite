# 🔐 Environment Variables Setup Guide

## Overview

Your OpenAI API key is now securely stored and **will NOT be committed to GitHub**.

---

## ✅ What Was Done

### 1. Created Environment Files

**`.env`** (Your actual API key - **IGNORED by Git**)
```bash
OPENAI_API_KEY=your-actual-openai-api-key-here
```

**`.env.example`** (Template for other developers)
```bash
OPENAI_API_KEY=your_openai_api_key_here
```

**Note:** Replace `your-actual-openai-api-key-here` with your real OpenAI API key.

### 2. Updated `.gitignore`

Added these lines to prevent committing secrets:
```
# Environment variables - DO NOT COMMIT
.env
.env.local
.env.*.local
*.env
```

### 3. Installed `flutter_dotenv` Package

Added to `pubspec.yaml`:
```yaml
dependencies:
  flutter_dotenv: ^5.1.0

flutter:
  assets:
    - .env
```

### 4. Updated `main.dart`

Loads environment variables at app startup:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Initialize Firebase
  await Firebase.initializeApp(...);
  
  runApp(const PetUnderwriterAI());
}
```

### 5. Updated `ai_service.dart`

Automatically reads API key from environment:
```dart
class GPTService implements AIService {
  final String apiKey;
  
  GPTService({
    String? apiKey,
    this.model = 'gpt-4',
  }) : apiKey = apiKey ?? dotenv.env['OPENAI_API_KEY'] ?? '' {
    if (this.apiKey.isEmpty) {
      throw Exception('OPENAI_API_KEY not found in environment variables');
    }
  }
}
```

---

## 🔒 Security Verification

### ✅ Confirmed: .env is Ignored by Git

Run this command to verify:
```bash
git check-ignore .env
```

Expected output: `.env` (meaning it's ignored)

You can also check git status:
```bash
git status
```

`.env` should **NOT** appear in the untracked files list.

---

## 📝 How to Use in Your Code

### Creating AI Service Instance

**Before (hardcoded key - BAD):**
```dart
final aiService = GPTService(apiKey: 'sk-proj-...');
```

**After (from environment - GOOD):**
```dart
final aiService = GPTService(); // Automatically uses OPENAI_API_KEY from .env
```

### Accessing Environment Variables Anywhere

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Get API key
final apiKey = dotenv.env['OPENAI_API_KEY'];

// Check if variable exists
if (dotenv.env.containsKey('OPENAI_API_KEY')) {
  print('API key is configured');
}

// Get with default value
final apiKey = dotenv.env['OPENAI_API_KEY'] ?? 'default-key';
```

---

## 🚀 Deployment Configurations

### Development (.env)
```bash
OPENAI_API_KEY=your-development-openai-api-key-here
STRIPE_PUBLISHABLE_KEY=pk_test_...
ENVIRONMENT=development
```

### Production (.env.production)
```bash
OPENAI_API_KEY=your-production-openai-api-key-here
STRIPE_PUBLISHABLE_KEY=pk_live_...
ENVIRONMENT=production
```

**Note:** Replace placeholder values with your actual API keys.

To load different environment files:
```dart
await dotenv.load(fileName: ".env.production");
```

---

## 👥 Team Setup Instructions

When a new developer joins the team:

1. **Clone the repository**
   ```bash
   git clone <repo-url>
   cd PetUwrite
   ```

2. **Copy the example file**
   ```bash
   cp .env.example .env
   ```

3. **Get the API key** (from team lead or password manager)

4. **Add to .env file**
   ```bash
   nano .env
   # Or use any text editor
   ```

5. **Run the app**
   ```bash
   flutter pub get
   flutter run
   ```

---

## 🔧 Adding More Environment Variables

### 1. Add to .env file
```bash
# OpenAI
OPENAI_API_KEY=sk-proj-...

# Stripe
STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_SECRET_KEY=sk_test_...

# Firebase (if needed)
FIREBASE_API_KEY=AIza...

# Custom settings
APP_NAME=PetUwrite
DEBUG_MODE=true
```

### 2. Update .env.example
```bash
OPENAI_API_KEY=your_openai_api_key_here
STRIPE_PUBLISHABLE_KEY=your_stripe_key_here
STRIPE_SECRET_KEY=your_stripe_secret_here
```

### 3. Use in code
```dart
final stripePubKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'];
final appName = dotenv.env['APP_NAME'] ?? 'PetUwrite';
final isDebug = dotenv.env['DEBUG_MODE'] == 'true';
```

---

## 🐛 Troubleshooting

### Problem: "OPENAI_API_KEY not found in environment variables"

**Solution 1:** Make sure `.env` file exists
```bash
ls -la .env
```

**Solution 2:** Verify .env is in assets in pubspec.yaml
```yaml
flutter:
  assets:
    - .env
```

**Solution 3:** Run flutter pub get
```bash
flutter pub get
```

**Solution 4:** Hot restart the app (not just hot reload)
```
Press 'R' in terminal or click restart button in IDE
```

### Problem: Changes to .env not reflecting

**Solution:** You need to **hot restart**, not hot reload
- Hot reload (r) - doesn't reload assets
- Hot restart (R) - reloads everything including .env

### Problem: .env is showing up in git status

**Solution:** Make sure it's in .gitignore
```bash
cat .gitignore | grep "\.env"
```

If not there, add:
```bash
echo -e "\n# Environment variables\n.env\n*.env" >> .gitignore
```

Then remove from git cache:
```bash
git rm --cached .env
```

---

## 🔐 Security Best Practices

### ✅ DO:
- ✅ Use `.env` for all secrets
- ✅ Add `.env` to `.gitignore`
- ✅ Commit `.env.example` with placeholder values
- ✅ Share API keys through secure channels (password managers, encrypted chat)
- ✅ Use different keys for development and production
- ✅ Rotate API keys regularly
- ✅ Limit API key permissions to minimum required

### ❌ DON'T:
- ❌ Never commit `.env` to git
- ❌ Never hardcode API keys in source code
- ❌ Never share API keys in Slack/Discord/email
- ❌ Never use production keys in development
- ❌ Never push `.env` to GitHub (even in private repos)
- ❌ Never log API keys to console

---

## 🎯 Testing Your Setup

### 1. Verify API Key is Loaded
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

void testApiKey() {
  final key = dotenv.env['OPENAI_API_KEY'];
  print('API Key loaded: ${key != null && key.isNotEmpty ? "✓" : "✗"}');
  print('Key starts with: ${key?.substring(0, 10)}...');
}
```

### 2. Test AI Service
```dart
import 'ai/ai_service.dart';

void testAIService() async {
  try {
    final service = GPTService(); // Uses .env key
    final response = await service.generateText('Say hello!');
    print('AI Response: $response');
  } catch (e) {
    print('Error: $e');
  }
}
```

### 3. Verify Git Ignore
```bash
# Should output: .env
git check-ignore .env

# Should NOT show .env
git status

# Show what's being ignored
git status --ignored
```

---

## 📦 Alternative: Platform-Specific Config

For production apps, consider platform-specific config:

### iOS (Info.plist)
```xml
<key>OPENAI_API_KEY</key>
<string>$(OPENAI_API_KEY)</string>
```

### Android (local.properties)
```properties
openai.api.key=sk-proj-...
```

### Flutter Flavor Configuration
```dart
flutter run --dart-define=OPENAI_API_KEY=sk-proj-...
```

---

## 🌐 Cloud Functions Environment

For Firebase Cloud Functions (in `/functions`):

### 1. Set environment variable
```bash
cd functions
firebase functions:config:set openai.key="sk-proj-..."
```

### 2. Use in Cloud Function
```javascript
const functions = require('firebase-functions');
const apiKey = functions.config().openai.key;
```

### 3. For local development
```bash
firebase functions:config:get > .runtimeconfig.json
```

---

## 📋 Summary

✅ **Completed:**
- OpenAI API key stored in `.env`
- `.env` added to `.gitignore`
- `flutter_dotenv` package installed
- `main.dart` loads environment variables
- `ai_service.dart` uses environment variables
- `.env.example` created for team reference

✅ **Verified:**
- `.env` is ignored by git
- API key is secure and not in source code
- Ready for team collaboration

⚠️ **Remember:**
- Never commit `.env` to GitHub
- Share API keys securely (password manager, encrypted channels)
- Use different keys for dev/staging/production
- Rotate keys regularly for security

---

## 🎉 You're All Set!

Your OpenAI API key is now securely configured and **will never be committed to GitHub**.

To test it:
```bash
flutter run
```

The app will automatically load your API key from `.env` and use it for all AI operations.

---

**Generated:** October 8, 2025  
**Status:** ✅ Complete and Secure  
**Next Steps:** Test AI integration with quote risk scoring
