# Homepage Quick Reference

## 🚀 What Changed

**Before:**
- App opened directly to conversational quote flow
- No landing page or navigation options

**After:**
- App opens to beautiful homepage with logo
- 3 clear navigation options
- Professional first impression

## 📍 File Locations

```
lib/
├── main.dart                    [MODIFIED]
│   └── Changed initial route to Homepage()
│
└── screens/
    └── homepage.dart            [NEW]
        └── Homepage landing screen
```

## 🎨 Homepage Features

### Visual Elements
- ✅ Navy background (#0A2647)
- ✅ Large centered logo (assets/Clovara transparent.png)
- ✅ App name "Clovara" in large white text
- ✅ Tagline "Trust powered by intelligence"
- ✅ 3 gradient action cards
- ✅ Professional footer with copyright

### Action Cards

**1. Get a Quote** (Teal gradient)
- Icon: 🐾 Pets
- Action: Navigates to `/conversational-quote`
- Purpose: Start insurance quote process

**2. File a Claim** (Sky blue gradient)
- Icon: 🏥 Medical services
- Action: Shows "Coming soon" message
- Purpose: Claims submission (not yet implemented)

**3. Sign In** (Dark navy gradient)
- Icon: 👤 Account
- Action: Navigates to `/auth-gate`
- Purpose: User authentication

## 🔀 Routing

### New Routes
```dart
'/home' → Homepage()
```

### Updated Initial Route
```dart
home: const Homepage()  // Was: ConversationalQuoteFlow()
```

### All Available Routes
```dart
'/'                     → Homepage (default)
'/home'                 → Homepage
'/conversational-quote' → ConversationalQuoteFlow
'/auth-gate'            → AuthGate (sign in)
'/plan-selection'       → PlanSelectionScreen
'/confirmation'         → PolicyConfirmationScreen
'/onboarding'           → OnboardingScreen
'/quote'                → QuoteFlowScreen
```

## 🎯 User Flows

### New User Journey
```
1. User lands on Homepage
2. Clicks "Get a Quote"
3. → Conversational quote flow
4. → Risk analysis
5. → Plan selection
6. → Checkout (auth required)
7. → Confirmation
```

### Returning User Journey
```
1. User lands on Homepage
2. Clicks "Sign In"
3. → Authentication
4. → User dashboard (or previous screen)
```

### Claims Journey (Future)
```
1. User lands on Homepage
2. Clicks "File a Claim"
3. → Claims submission form
4. → Upload documents
5. → Confirmation
```

## 🛠️ Customization

### Change Background Color
```dart
// In homepage.dart, line ~25
decoration: const BoxDecoration(
  color: ClovaraColors.kPrimaryNavy,  // Change this
),
```

### Change Logo Size
```dart
// In homepage.dart, line ~78
constraints: BoxConstraints(
  maxWidth: isSmallScreen ? 280 : 400,   // Adjust these
  maxHeight: isSmallScreen ? 280 : 400,
),
```

### Change Card Order
```dart
// In homepage.dart, line ~118
// Reorder these three _buildActionCard() calls
// First card appears at top, last card at bottom
```

### Add New Action Card
```dart
// In homepage.dart, after line ~170, add:
const SizedBox(height: 24),
_buildActionCard(
  context: context,
  icon: Icons.help_outline,
  title: 'Help Center',
  subtitle: 'Get support and answers',
  gradient: LinearGradient(...),
  onTap: () {
    Navigator.pushNamed(context, '/help');
  },
),
```

## 🐛 Troubleshooting

### Logo Not Showing
**Issue:** Image.asset can't find logo  
**Fix:** Verify `assets/Clovara transparent.png` exists  
**Check:** pubspec.yaml includes assets folder

### Cards Not Clickable
**Issue:** InkWell not responding  
**Fix:** Ensure Material widget wraps InkWell  
**Status:** ✅ Already implemented correctly

### Wrong Initial Screen
**Issue:** App still shows quote flow first  
**Fix:** Hot restart (not hot reload) - `r` key in terminal  
**Or:** Stop and run `flutter run` again

### Routing Error
**Issue:** "Could not find route /conversational-quote"  
**Fix:** Check main.dart routes map includes the route  
**Status:** ✅ All routes properly configured

## 📱 Testing Checklist

- [x] Homepage displays on app launch
- [x] Logo renders correctly
- [x] All 3 cards are visible
- [x] "Get a Quote" navigates to quote flow
- [x] "Sign In" navigates to auth gate
- [x] "File a Claim" shows "Coming soon"
- [x] Footer displays properly
- [x] Responsive on mobile (resize browser)
- [x] Responsive on desktop
- [x] No console errors

## 🔄 Reverting Changes

If you want to go back to the old behavior (direct to quote flow):

```dart
// In lib/main.dart, line ~45
home: const ConversationalQuoteFlow(),  // Change from Homepage()
```

## 📚 Related Documentation

- `HOMEPAGE_IMPLEMENTATION_SUMMARY.md` - Complete implementation details
- `HOMEPAGE_VISUAL_DESIGN_SPEC.md` - Full design specifications
- `lib/theme/clovara_theme.dart` - Brand colors and typography
- `lib/screens/homepage.dart` - Homepage source code

## 🎯 Next Steps

### Immediate
1. ✅ Run app and verify homepage displays
2. ✅ Test all 3 navigation options
3. ✅ Check responsive behavior

### Short Term
1. 📝 Implement claims flow
2. 📝 Add Terms/Privacy/Contact pages
3. 📝 Add page load animations

### Long Term
1. 📝 A/B test card order and text
2. 📝 Add analytics tracking
3. 📝 User testing and optimization

---

**Status:** ✅ Complete and Working  
**Version:** 1.0.0  
**Last Updated:** October 10, 2025
