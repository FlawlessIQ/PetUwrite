# Quick Start Guide - Pet Underwriter AI

## ✅ What's Been Created

Your Flutter app is fully structured with 21+ files organized into:
- `screens/` - 5 UI screens (onboarding → quote → plans → checkout → confirmation)
- `models/` - 5 data models (Pet, Owner, Quote, RiskScore, Policy)
- `services/` - 5 business logic services
- `widgets/` - 3 reusable UI components
- `providers/` - 3 state management providers
- `ai/` - 3 AI integration services

## 🚀 Run the App Now

```bash
# Make sure you're in the project directory
cd /Users/conorlawless/Development/PetUwrite

# Launch the app
flutter run
```

**Note**: The app will run but Firebase and AI features will show TODO warnings until configured.

## 🔧 Configuration Checklist

### 1. Firebase Setup (Required for full functionality)

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase (run from project root)
flutterfire configure
```

Then uncomment line 13 in `lib/main.dart`:
```dart
await Firebase.initializeApp();
```

### 2. AI Integration (Optional but recommended)

**Option A: OpenAI GPT**
1. Get API key: https://platform.openai.com/api-keys
2. Add to your app (example in `lib/ai/ai_service.dart`):
```dart
final gptService = GPTService(apiKey: 'your-api-key-here');
```

**Option B: Google Vertex AI**
1. Enable Vertex AI in Google Cloud Console
2. Create service account credentials
3. Configure in `lib/ai/ai_service.dart`

### 3. Payment Gateway (For checkout functionality)

Add Stripe or another payment processor:
```bash
flutter pub add flutter_stripe
```

## 📱 Test the App

### Without Configuration
The app will run and you can navigate through:
- ✅ Onboarding screens
- ✅ Quote flow forms
- ✅ Plan selection UI
- ✅ Checkout screens
- ✅ Confirmation screen

### With Firebase
All data persistence will work:
- Save pets, owners, quotes, policies
- Real-time data updates
- User authentication

### With AI Integration
Advanced features will activate:
- Vet record parsing
- Risk analysis
- Personalized recommendations

## 📂 Key Files to Know

| File | Purpose |
|------|---------|
| `lib/main.dart` | App entry, routing, theme |
| `lib/screens/onboarding_screen.dart` | First screen users see |
| `lib/models/pet.dart` | Pet data structure |
| `lib/services/firebase_service.dart` | All Firebase operations |
| `lib/ai/ai_service.dart` | AI integration logic |
| `pubspec.yaml` | Dependencies configuration |

## 🎨 Customize the App

### Change Theme Colors
Edit `lib/main.dart` line 45:
```dart
seedColor: Colors.blue,  // Change to your brand color
```

### Modify Plans
Edit `lib/screens/plan_selection_screen.dart` lines 12-66

### Update Branding
- App name in `pubspec.yaml` line 1
- Icon: Add to `assets/` and update in pubspec
- Splash screen: Use `flutter_native_splash` package

## 🐛 Common Issues

### "Target URI doesn't exist" errors
- These warnings are for unimplemented features
- They won't prevent the app from running
- Configure Firebase to resolve most of them

### Build fails
```bash
flutter clean
flutter pub get
flutter run
```

### Firebase errors
Make sure you've run `flutterfire configure` and added config files

## 📚 Learn More

### Flutter Resources
- [Flutter Documentation](https://docs.flutter.dev/)
- [Provider Package](https://pub.dev/packages/provider)
- [Firebase for Flutter](https://firebase.google.com/docs/flutter/setup)

### Project Structure
- Read `README.md` for full documentation
- Check `PROJECT_SUMMARY.md` for complete file listing

## 🎯 Next Development Tasks

1. **Authentication**
   - Create login/signup screens
   - Implement Firebase Auth

2. **File Upload**
   - Add image picker for vet records
   - Implement file storage

3. **Testing**
   - Write unit tests for models
   - Add widget tests for screens
   - Integration tests for flows

4. **Polish**
   - Add loading states
   - Error handling
   - Form validation
   - Animations

## 💡 Pro Tips

1. **Hot Reload**: Press `r` in terminal while app is running to see changes instantly
2. **DevTools**: Run `flutter pub global activate devtools` for debugging tools
3. **State Inspector**: Use Provider DevTools to inspect state changes
4. **Logging**: Add `print()` statements to debug data flow

## ✨ You're Ready!

Your app structure is complete. Start with:
1. Run `flutter run` to see it in action
2. Explore the screens and UI
3. Configure Firebase when ready for backend
4. Add AI integration for advanced features

**Happy Coding! 🎉**
