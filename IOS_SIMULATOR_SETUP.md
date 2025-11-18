# iOS Simulator Setup - Clovara

## ✅ Completed Setup Steps

### 1. **iOS Deployment Target Updated**
- Updated `ios/Podfile` to target iOS 13.0 minimum
- This ensures compatibility with all required dependencies (especially Stripe SDK)

### 2. **Flutter Dependencies**
- Ran `flutter clean` to remove old build artifacts
- Ran `flutter pub get` to fetch all Flutter packages
- All 60 packages downloaded successfully

### 3. **iOS Build Configuration**
- App name: **Clovara** (updated in `Info.plist`)
- Bundle identifier: `com.petunderwriter.petUnderwriterAi`
- Version: 1.0.0+1
- Launch screen configured with Clovara branding

### 4. **Build In Progress**
- Running `flutter build ios --simulator --no-codesign`
- This will automatically handle CocoaPods installation via Flutter's tooling
- Build artifacts will be ready for Xcode simulator

## 📋 Next Steps to Run in Xcode

### Option 1: Open in Xcode and Run
```bash
open ios/Runner.xcworkspace
```
Then in Xcode:
1. Select a simulator (iPhone 15 Pro recommended)
2. Click the Play ▶️ button to build and run

### Option 2: Run from Command Line
```bash
# List available simulators
flutter devices

# Run on a specific simulator
flutter run -d <device-id>

# Or just run (Flutter will pick an available simulator)
flutter run
```

## 🔧 Configuration Files Needed

### Firebase Configuration (Required)
You need to add your Firebase iOS configuration:

1. Download `GoogleService-Info.plist` from Firebase Console:
   - Go to Firebase Console → Project Settings
   - iOS app → Download GoogleService-Info.plist

2. Add it to the project:
   ```bash
   cp ~/Downloads/GoogleService-Info.plist ios/Runner/
   ```

3. In Xcode, add the file to the Runner target:
   - Right-click on `Runner` folder → Add Files to "Runner"
   - Select `GoogleService-Info.plist`
   - Ensure "Copy items if needed" is checked
   - Select target: Runner

### Environment Variables (Required)
Update `.env` file in the project root:
```bash
OPENAI_API_KEY=sk-your-actual-key-here
STRIPE_PUBLISHABLE_KEY=pk_test_your-key-here
```

## 🎨 App Icons and Splash Screen

The app already has:
- ✅ Clovara app icon configured (`clovara_appicon_1024.png`)
- ✅ Splash screen with Clovara branding
- ✅ White background theme (#F7FAF8)

To regenerate if needed:
```bash
flutter pub run flutter_launcher_icons
flutter pub run flutter_native_splash:create
```

## 📱 iOS Specific Features Configured

1. **Permissions** (configured in `Info.plist`):
   - Camera access (for pet photos)
   - Photo library access
   - File access (for documents)

2. **Orientation Support**:
   - iPhone: Portrait, Landscape Left, Landscape Right
   - iPad: All orientations

3. **UI Features**:
   - High refresh rate support enabled
   - Indirect input events support
   - Modern iOS design guidelines

## 🐛 Troubleshooting

### If CocoaPods fails:
```bash
cd ios
rm -rf Pods Podfile.lock
pod cache clean --all
pod install --repo-update
```

### If build fails in Xcode:
1. Product → Clean Build Folder (Cmd+Shift+K)
2. Close Xcode
3. Delete derived data:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```
4. Reopen and build

### If simulator doesn't launch:
```bash
# Reset Flutter
flutter clean
flutter pub get

# Reset iOS build
cd ios
rm -rf build
pod install
cd ..

# Try again
flutter run
```

## 🎯 Current Status

The app is **being built for iOS simulator** and should be ready to run once the build completes. The Flutter build process handles all CocoaPods dependencies automatically, so you don't need to manually run `pod install`.

After the build finishes, you can:
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select any iOS simulator
3. Hit Run to launch Clovara on the simulator

All admin dashboard mobile optimizations are included and will display correctly on iPhone and iPad simulators!
