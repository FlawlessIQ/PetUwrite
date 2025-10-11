# Add these sections to your pubspec.yaml

## Assets Section (add under flutter:)
```yaml
flutter:
  uses-material-design: true
  
  assets:
    - .env
    - flutter_assets/PetUwrite navy background.png
    - flutter_assets/PetUwrite transparent.png
    # Add more assets as needed
```

## Fonts Section (add under flutter:)
```yaml
  fonts:
    # Poppins - For headings
    - family: Poppins
      fonts:
        - asset: fonts/Poppins/Poppins-Regular.ttf
          weight: 400
        - asset: fonts/Poppins/Poppins-Medium.ttf
          weight: 500
        - asset: fonts/Poppins/Poppins-SemiBold.ttf
          weight: 600
        - asset: fonts/Poppins/Poppins-Bold.ttf
          weight: 700
    
    # Inter - For body text
    - family: Inter
      fonts:
        - asset: fonts/Inter/Inter-Regular.ttf
          weight: 400
        - asset: fonts/Inter/Inter-Medium.ttf
          weight: 500
        - asset: fonts/Inter/Inter-SemiBold.ttf
          weight: 600
    
    # Nunito Sans - Alternative body text (optional)
    - family: Nunito Sans
      fonts:
        - asset: fonts/NunitoSans/NunitoSans-Regular.ttf
          weight: 400
        - asset: fonts/NunitoSans/NunitoSans-SemiBold.ttf
          weight: 600
```

## Download Fonts

### Poppins
https://fonts.google.com/specimen/Poppins
- Download Regular (400)
- Download Medium (500)
- Download SemiBold (600)
- Download Bold (700)

### Inter
https://fonts.google.com/specimen/Inter
- Download Regular (400)
- Download Medium (500)
- Download SemiBold (600)

### Nunito Sans (Optional)
https://fonts.google.com/specimen/Nunito+Sans
- Download Regular (400)
- Download SemiBold (600)

## Directory Structure
```
your_project/
├── flutter_assets/
│   ├── PetUwrite navy background.png
│   └── PetUwrite transparent.png
├── fonts/
│   ├── Poppins/
│   │   ├── Poppins-Regular.ttf
│   │   ├── Poppins-Medium.ttf
│   │   ├── Poppins-SemiBold.ttf
│   │   └── Poppins-Bold.ttf
│   ├── Inter/
│   │   ├── Inter-Regular.ttf
│   │   ├── Inter-Medium.ttf
│   │   └── Inter-SemiBold.ttf
│   └── NunitoSans/ (optional)
│       ├── NunitoSans-Regular.ttf
│       └── NunitoSans-SemiBold.ttf
├── lib/
│   └── theme/
│       └── petuwrite_theme.dart
└── pubspec.yaml
```

## After Adding Assets

1. Create the directories:
```bash
mkdir -p flutter_assets fonts/Poppins fonts/Inter fonts/NunitoSans
```

2. Add your logo files to `flutter_assets/`

3. Download and add fonts to respective folders

4. Update `pubspec.yaml` with the sections above

5. Run:
```bash
flutter pub get
flutter clean
flutter run
```

## Logo Specifications

### PetUwrite Navy Background
- **File:** `flutter_assets/PetUwrite navy background.png`
- **Use:** Splash screen, login, onboarding, marketing
- **Background:** Navy blue (#0A2647)
- **Logo:** Full color with text
- **Recommended size:** 512x512px or 1024x1024px

### PetUwrite Transparent
- **File:** `flutter_assets/PetUwrite transparent.png`
- **Use:** App bars, overlays, light backgrounds
- **Background:** Transparent PNG
- **Logo:** Full color with text
- **Recommended size:** 256x256px or 512x512px

## Using Logos in Code

### Navy Background Logo (Full Screen)
```dart
Image.asset(
  PetUwriteAssets.logoNavyBackground,
  width: 200,
  height: 200,
)
```

### Transparent Logo (App Bar)
```dart
Image.asset(
  PetUwriteAssets.logoTransparent,
  width: 120,
  height: 40,
  fit: BoxFit.contain,
)
```

### Placeholder (Until Logo is Added)
```dart
// Temporary placeholder
Container(
  height: 80,
  width: 80,
  decoration: BoxDecoration(
    gradient: PetUwriteColors.brandGradient,
    borderRadius: BorderRadius.circular(16),
  ),
  child: Icon(
    Icons.pets,
    size: 50,
    color: Colors.white,
  ),
)
```
