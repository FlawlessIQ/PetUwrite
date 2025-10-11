# 🎨 PetUwrite Branding Implementation Guide

## ✅ Completed

### 1. Theme Configuration Created
**File:** `lib/theme/petuwrite_theme.dart`

**What's included:**
- ✅ Complete color palette (Navy, Teal, Sky, Mint, Coral)
- ✅ Typography styles (Poppins for headings, Inter for body)
- ✅ Light and dark themes
- ✅ Custom gradients (brand gradient, soft gradient, dark gradient)
- ✅ Rounded button styles (12-16px radius)
- ✅ Custom input fields with teal focus
- ✅ Helper widgets (BrandGradientBackground, BrandGradientCard)
- ✅ Brand assets constants (logo paths, tagline, copyright)

### 2. Main App Updated
**File:** `lib/main.dart`

**Changes:**
- ✅ Imported PetUwrite theme
- ✅ Updated app title to "PetUwrite"
- ✅ Applied light and dark themes
- ✅ All screens now inherit brand colors automatically

### 3. Login Screen Updated (In Progress)
**File:** `lib/auth/login_screen.dart`

**New features:**
- ✅ Dark gradient background (Navy to Dark)
- ✅ White card with logo placeholder
- ✅ PetUwrite branding and tagline
- ✅ Teal/Sky color scheme
- ✅ Rounded corners (12px)
- ✅ Copyright footer

---

## 📋 Brand Identity Reference

### Colors
```dart
kPrimaryNavy    = #0A2647  // Deep trust blue
kSecondaryTeal  = #00C2CB  // Smart teal accent
kAccentSky      = #A8E6E8  // Soft sky tone
kBackgroundLight = #F8FAFB  // Light background
kBackgroundDark  = #061122  // Dark background
kSuccessMint    = #4CE1A5  // Success/positive
kWarmCoral      = #FF6F61  // Alerts/CTAs
```

### Typography
```dart
// Headings - Poppins SemiBold
h1: 32px, weight 600
h2: 24px, weight 600
h3: 20px, weight 600
h4: 18px, weight 600

// Body - Inter Regular
bodyLarge: 16px
body: 14px
bodySmall: 12px

// Buttons - Inter SemiBold
button: 14px, weight 600, letter-spacing 0.5
buttonLarge: 16px, weight 600
```

### Brand Gradient
```dart
LinearGradient(
  colors: [kSecondaryTeal, kPrimaryNavy],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
)
```

### Logo Assets
```dart
logoNavyBackground  = 'flutter_assets/PetUwrite navy background.png'
logoTransparent     = 'flutter_assets/PetUwrite transparent.png'
```

**Usage:**
- Navy background logo: Splash, login, onboarding, marketing screens
- Transparent logo: App bars, overlays, light backgrounds

### Tagline
**"Trust powered by intelligence"**

### Copyright
**© 2025 FlawlessIQ LLC**

---

## 🎨 Component Styling Guide

### Buttons

#### Primary Button (Teal)
```dart
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: PetUwriteColors.kSecondaryTeal,
    foregroundColor: Colors.white,
    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  ),
  child: Text('Button Text', style: PetUwriteTypography.button),
)
```

#### Secondary Button (Transparent)
```dart
OutlinedButton(
  style: OutlinedButton.styleFrom(
    foregroundColor: PetUwriteColors.kSecondaryTeal,
    side: BorderSide(color: PetUwriteColors.kSecondaryTeal, width: 2),
    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  ),
  child: Text('Button Text', style: PetUwriteTypography.button),
)
```

### Cards

#### Standard Card
```dart
Card(
  elevation: 2,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  ),
  child: Padding(
    padding: EdgeInsets.all(16),
    child: // Your content
  ),
)
```

#### Gradient Card
```dart
BrandGradientCard(
  padding: EdgeInsets.all(20),
  child: Column(
    children: [
      Text('Title', style: PetUwriteTypography.h3.copyWith(color: Colors.white)),
      // More content
    ],
  ),
)
```

### Input Fields

#### Light Background
```dart
TextFormField(
  decoration: InputDecoration(
    labelText: 'Email',
    prefixIcon: Icon(Icons.email_outlined, color: PetUwriteColors.kSecondaryTeal),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: PetUwriteColors.kSecondaryTeal, width: 2),
    ),
  ),
)
```

#### Dark Background
```dart
TextFormField(
  style: TextStyle(color: Colors.white),
  decoration: InputDecoration(
    labelText: 'Email',
    labelStyle: TextStyle(color: PetUwriteColors.kAccentSky),
    prefixIcon: Icon(Icons.email_outlined, color: PetUwriteColors.kSecondaryTeal),
    filled: true,
    fillColor: PetUwriteColors.kPrimaryNavy.withOpacity(0.5),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: PetUwriteColors.kSecondaryTeal),
    ),
  ),
)
```

### App Bar

#### Light Theme
```dart
AppBar(
  backgroundColor: PetUwriteColors.kPrimaryNavy,
  foregroundColor: Colors.white,
  title: Text('Title', style: PetUwriteTypography.h3.copyWith(color: Colors.white)),
  leading: Icon(Icons.arrow_back, color: Colors.white),
)
```

### Background Gradients

#### Brand Gradient Background
```dart
BrandGradientBackground(
  child: Scaffold(
    backgroundColor: Colors.transparent,
    // Your content
  ),
)
```

#### Dark Gradient Background
```dart
Container(
  decoration: BoxDecoration(
    gradient: PetUwriteColors.darkGradient,
  ),
  child: // Your content
)
```

---

## 📱 Screen-by-Screen Update Guide

### ✅ Login Screen (`lib/auth/login_screen.dart`)
**Status:** Updated

**Features:**
- Dark gradient background
- White logo card with shadow
- Teal primary button
- Sky accent outlined button
- Copyright footer

**Screenshot description:**
- Navy-to-dark gradient background
- Centered white card with logo
- "PetUwrite" in navy, "Trust powered by intelligence" in teal
- Form fields with teal accents
- Teal "Sign In" button, Sky "Create Account" button

### 🔲 Quote Flow Screen (`lib/screens/quote_flow_screen.dart`)
**Status:** Needs update

**Required changes:**
1. Update AppBar:
   ```dart
   AppBar(
     backgroundColor: PetUwriteColors.kPrimaryNavy,
     title: Text('Get a Quote', style: PetUwriteTypography.h3.copyWith(color: Colors.white)),
     leading: // Transparent logo image
   )
   ```

2. Update step indicator with teal accent
3. Change primary button to teal
4. Update card corners to 16px

### 🔲 Plan Selection Screen (`lib/screens/plan_selection_screen.dart`)
**Status:** Needs update

**Required changes:**
1. Update AppBar with navy background
2. Apply gradient to plan cards:
   ```dart
   Container(
     decoration: BoxDecoration(
       gradient: PetUwriteColors.brandGradient,
       borderRadius: BorderRadius.circular(16),
     ),
   )
   ```
3. Update "Most Popular" badge to mint color
4. Change button colors to teal
5. Update typography to PetUwrite styles

### 🔲 Customer Home Screen (`lib/auth/customer_home_screen.dart`)
**Status:** Needs update

**Required changes:**
1. Update AppBar:
   ```dart
   AppBar(
     backgroundColor: PetUwriteColors.kPrimaryNavy,
     title: // Transparent logo
     actions: // Account menu
   )
   ```

2. Update action cards:
   ```dart
   BrandGradientCard(
     child: // Card content
   )
   ```

3. Apply teal accents to interactive elements
4. Update welcome banner with gradient
5. Change "Get Quote" button to teal

### 🔲 Admin Dashboard (`lib/screens/admin_dashboard.dart`)
**Status:** Needs update

**Required changes:**
1. Apply dark theme (already configured in theme file)
2. Update AppBar with navy background
3. Change filter chips to teal/sky accent
4. Update quote cards with navy background
5. Apply teal highlights to interactive elements
6. Update risk badges:
   - Low: Mint (#4CE1A5)
   - Medium: Sky (#A8E6E8)
   - High: Coral (#FF6F61)

### 🔲 Checkout Screens (4 steps)
**Status:** Needs update

#### Review Screen
- Update header with gradient
- Apply brand colors to pet info card
- Update plan summary card with teal accents

#### Owner Details Screen
- Update form fields with brand styling
- Apply teal to e-sign checkbox
- Update address form with rounded corners

#### Payment Screen
- Update order summary with gradient card
- Apply teal to Stripe elements
- Update security badge colors

#### Confirmation Screen
- Add gradient header
- Update policy card with brand colors
- Apply mint to success indicators
- Update download/email buttons to teal

### 🔲 Onboarding Screen (`lib/screens/onboarding_screen.dart`)
**Status:** Needs update

**Required changes:**
1. Add navy background logo on first slide
2. Apply gradients to background
3. Update illustrations with teal/sky colors
4. Change dots indicator to teal
5. Update "Get Started" button to teal with white text

---

## 🖼️ Asset Requirements

### Logo Files Needed
```
flutter_assets/
├── PetUwrite navy background.png     # For splash, login, onboarding
└── PetUwrite transparent.png         # For app bars, overlays
```

**Recommended sizes:**
- **Navy background logo:** 512x512px (splash), 256x256px (login)
- **Transparent logo:** 128x128px (app bar), 48x48px (small icons)

### Font Files Needed
```
fonts/
├── Poppins/
│   ├── Poppins-Regular.ttf
│   ├── Poppins-SemiBold.ttf
│   └── Poppins-Bold.ttf
└── Inter/
    ├── Inter-Regular.ttf
    ├── Inter-Medium.ttf
    └── Inter-SemiBold.ttf
```

### App Icon
- **Primary color:** Navy (#0A2647)
- **Accent:** Teal (#00C2CB)
- **Design:** Paw print with circuit pattern overlay
- **Sizes needed:** 1024x1024 (iOS), 512x512 (Android)

---

## 📦 pubspec.yaml Updates

### Assets Section
```yaml
flutter:
  assets:
    - .env
    - flutter_assets/PetUwrite navy background.png
    - flutter_assets/PetUwrite transparent.png
```

### Fonts Section
```yaml
  fonts:
    - family: Poppins
      fonts:
        - asset: fonts/Poppins/Poppins-Regular.ttf
          weight: 400
        - asset: fonts/Poppins/Poppins-SemiBold.ttf
          weight: 600
        - asset: fonts/Poppins/Poppins-Bold.ttf
          weight: 700
    
    - family: Inter
      fonts:
        - asset: fonts/Inter/Inter-Regular.ttf
          weight: 400
        - asset: fonts/Inter/Inter-Medium.ttf
          weight: 500
        - asset: fonts/Inter/Inter-SemiBold.ttf
          weight: 600
```

---

## 🚀 Implementation Steps

### Phase 1: Core Setup (DONE ✅)
- [x] Create theme file
- [x] Update main.dart
- [x] Update login screen (in progress)

### Phase 2: Add Assets
- [ ] Add logo images to `flutter_assets/`
- [ ] Add font files to `fonts/`
- [ ] Update `pubspec.yaml`
- [ ] Run `flutter pub get`

### Phase 3: Update Public Screens
- [ ] Quote flow screen
- [ ] Plan selection screen
- [ ] Onboarding screen
- [ ] Auth required checkout screen

### Phase 4: Update Authenticated Screens
- [ ] Customer home screen
- [ ] Admin dashboard
- [ ] Checkout screens (4 steps)

### Phase 5: Update App Metadata
- [ ] App icon
- [ ] Splash screen
- [ ] About screen
- [ ] iOS Info.plist
- [ ] Android strings.xml

### Phase 6: Polish
- [ ] Test all screens
- [ ] Verify color contrast (WCAG AA)
- [ ] Test dark mode
- [ ] Update screenshots
- [ ] Update marketing materials

---

## 🎯 Quick Reference

### Import Statement
```dart
import 'package:pet_underwriter_ai/theme/petuwrite_theme.dart';
```

### Using Theme Colors
```dart
// In a widget
color: PetUwriteColors.kSecondaryTeal

// From theme
color: Theme.of(context).colorScheme.primary  // Navy
color: Theme.of(context).colorScheme.secondary  // Teal
```

### Using Typography
```dart
Text('Heading', style: PetUwriteTypography.h2)
Text('Body', style: PetUwriteTypography.body)
Text('Button', style: PetUwriteTypography.button)
```

### Using Assets
```dart
Image.asset(PetUwriteAssets.logoNavyBackground)
Image.asset(PetUwriteAssets.logoTransparent)
```

### Brand Elements
```dart
PetUwriteAssets.appName    // "PetUwrite"
PetUwriteAssets.tagline    // "Trust powered by intelligence"
PetUwriteAssets.copyright  // "© 2025 FlawlessIQ LLC"
```

---

## 🎨 Design Philosophy

**PetUwrite Brand Values:**
1. **Trust** - Deep navy blue conveys stability and reliability
2. **Intelligence** - Teal accent represents AI-powered innovation
3. **Care** - Soft sky tones show empathy and support
4. **Success** - Mint green celebrates positive outcomes
5. **Action** - Warm coral drives engagement

**Visual Principles:**
- **Rounded corners** (12-16px) = Friendly, approachable
- **Gradients** = Dynamic, modern, intelligent
- **Contrast** = Navy + teal = Professional yet innovative
- **Whitespace** = Clean, organized, trustworthy
- **Shadows** = Depth, dimension, quality

---

## ✅ Testing Checklist

### Visual Testing
- [ ] All text readable on backgrounds
- [ ] Colors consistent across screens
- [ ] Logo displays correctly
- [ ] Gradients render smoothly
- [ ] Shadows not too heavy
- [ ] Rounded corners consistent

### Functionality Testing
- [ ] Buttons respond to touch
- [ ] Forms validate properly
- [ ] Navigation works
- [ ] Dark mode looks good (admin)
- [ ] Light mode looks good (customer)

### Accessibility Testing
- [ ] Color contrast meets WCAG AA
- [ ] Font sizes readable
- [ ] Touch targets 44x44 minimum
- [ ] Screen reader compatible

---

## 📞 Support

For questions or issues with branding:
1. Review this guide
2. Check `lib/theme/petuwrite_theme.dart`
3. Refer to component examples above

**Status:** Theme created, main app updated, login screen partially updated
**Next Steps:** Add logo assets, update remaining screens

---

**Last Updated:** October 8, 2025  
**Version:** 1.0  
**Author:** GitHub Copilot
