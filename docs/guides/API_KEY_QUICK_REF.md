# 🔐 API Key Quick Reference

## ✅ Your API Key is Secure

Your OpenAI API key is stored in `.env` and **will NOT be committed to GitHub**.

---

## 📁 Files Created

| File | Purpose | Commit to Git? |
|------|---------|----------------|
| `.env` | Your actual API key | ❌ NO - Ignored |
| `.env.example` | Template for team | ✅ YES - Safe |
| `.gitignore` | Ignores .env files | ✅ YES - Required |

---

## 🚀 Usage

### Use AI Service
```dart
import 'package:pet_underwriter_ai/ai/ai_service.dart';

// Automatically uses OPENAI_API_KEY from .env
final aiService = GPTService();

// Generate text
final response = await aiService.generateText('Hello AI!');
```

### Access Environment Variables
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Get API key
final apiKey = dotenv.env['OPENAI_API_KEY'];

// Check if exists
if (dotenv.env.containsKey('OPENAI_API_KEY')) {
  print('API key configured ✓');
}
```

---

## 🔍 Verify Security

```bash
# Check .env is ignored (should output: .env)
git check-ignore .env

# Verify not in git status (should NOT show .env)
git status

# Confirm file exists
ls -la .env
```

---

## 🔧 Common Commands

```bash
# Install dependencies
flutter pub get

# Run app (loads .env automatically)
flutter run

# Hot restart to reload .env changes
# Press 'R' in terminal (not 'r')

# Test AI service
flutter run --debug
```

---

## 🆘 Troubleshooting

| Problem | Solution |
|---------|----------|
| "OPENAI_API_KEY not found" | Run `flutter pub get` then hot restart |
| .env changes not working | Hot **restart** (R), not reload (r) |
| .env in git status | Add to `.gitignore` and run `git rm --cached .env` |

---

## 👥 Team Setup (New Developer)

```bash
# 1. Clone repo
git clone <repo-url>

# 2. Copy example file
cp .env.example .env

# 3. Get API key from team lead

# 4. Edit .env and add key
nano .env

# 5. Install and run
flutter pub get
flutter run
```

---

## 🎯 Your API Key

**Location:** `.env` file in project root

**Content:**
```bash
OPENAI_API_KEY=your-openai-api-key-here
```

**Status:** ✅ Secure (Ignored by Git)

**Note:** Replace `your-openai-api-key-here` with your actual OpenAI API key.

---

**Last Updated:** October 8, 2025
