# 🎨 Logo Implementation Guide

## 📍 Logo Placement

### Login Screen
```
┌─────────────────────────────────────┐
│         NAVY BACKGROUND              │
│                                     │
│    ┌───────────────────────┐       │
│    │  ┌───────────────┐    │       │
│    │  │               │    │       │ ← Subtle glow container
│    │  │   [Clovara  │    │       │
│    │  │     LOGO]     │    │       │ ← 140px height
│    │  │               │    │       │
│    │  └───────────────┘    │       │
│    └───────────────────────┘       │
│                                     │
│  Trust powered by intelligence      │ ← Teal, 18px, italic
│                                     │
│    ┌───────────────────────┐       │
│    │ WHITE CARD WITH FORM  │       │
│    └───────────────────────┘       │
└─────────────────────────────────────┘
```

### Checkout Screen Header
```
┌──────────────────────────────────────────────┐
│  ← │ [LOGO] │        Checkout        ✕     │ ← 50px height
│    │ 50px   │    Owner Details              │
└──────────────────────────────────────────────┘
```

---

## 🖼️ Logo Assets

### Primary Logo: Navy Background
**File:** `assets/Clovara navy background.png`

**Used For:**
- Login screen (large, 140px)
- Checkout header (small, 50px)
- Any navy background context

**Why This Logo:**
✅ Blends seamlessly with navy background  
✅ No white borders or jarring edges  
✅ Professional, integrated appearance  
✅ Matches overall brand aesthetic  

**Implementation:**
```dart
Image.asset(
  'assets/Clovara navy background.png',
  height: 140, // or 50 for header
  fit: BoxFit.contain,
)
```

### Fallback Logo: Transparent
**File:** `assets/clovara_logo_transparent.svg`

**Used For:**
- Fallback if PNG fails to load
- Contexts where vector is preferred
- White/light backgrounds

**Why This Logo:**
✅ Works on any background  
✅ Vector format scales perfectly  
✅ Versatile and flexible  

**Implementation:**
```dart
errorBuilder: (context, error, stackTrace) {
  return Image.asset(
    'assets/clovara_logo_transparent.svg',
    height: 140,
    fit: BoxFit.contain,
  );
}
```

---

## 🎨 Styling Details

### Login Screen Logo Container:
```dart
Container(
  padding: const EdgeInsets.all(24),
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.08),    // Subtle background
    borderRadius: BorderRadius.circular(24),   // Rounded corners
    boxShadow: [
      BoxShadow(
        color: ClovaraColors.kSecondaryTeal.withOpacity(0.2),
        blurRadius: 30,     // Soft glow
        spreadRadius: 5,    // Spread the glow
      ),
    ],
  ),
  child: Image.asset(
    'assets/Clovara navy background.png',
    height: 140,
    fit: BoxFit.contain,
  ),
)
```

**Visual Effect:**
- Navy logo on navy background with slight glow
- Teal shadow creates depth
- 24px padding gives breathing room
- 24px border radius matches card style

### Checkout Header Logo Container:
```dart
Container(
  height: 50,
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.1),     // Subtle highlight
    borderRadius: BorderRadius.circular(12),   // Rounded corners
  ),
  child: Image.asset(
    'assets/Clovara navy background.png',
    fit: BoxFit.contain,
  ),
)
```

**Visual Effect:**
- Compact logo for header
- Slight white overlay creates definition
- Integrates seamlessly with header
- Maintains brand visibility

---

## 📐 Sizing Guidelines

### Logo Sizes by Context:

**Extra Large (Splash, Login):**
- Height: 140px
- Use: Main branding moments
- Container padding: 24px
- Glow effect: Strong

**Large (Hero sections):**
- Height: 100px
- Use: Feature introductions
- Container padding: 20px
- Glow effect: Medium

**Medium (Headers, Navigation):**
- Height: 50px
- Use: Checkout header, nav bars
- Container padding: 12px
- Glow effect: Subtle

**Small (Inline, Cards):**
- Height: 30px
- Use: Inline mentions, cards
- Container padding: 8px
- Glow effect: None

---

## 🎨 Color Combinations

### Navy Background + Navy Logo:
```
Background: #0A2647 (Navy)
Logo: Navy background version
Container: white.withOpacity(0.08)
Glow: Teal with opacity(0.2)
```

**Effect:** Integrated, subtle, professional

### White Background + Transparent Logo:
```
Background: #FFFFFF (White)
Logo: Transparent version
Container: none or light grey
Shadow: Grey with opacity(0.1)
```

**Effect:** Clean, clear, versatile

### Teal Accent + Navy Logo:
```
Background: #0A2647 (Navy)
Logo: Navy background version
Border: #00C2CB (Teal)
Glow: Teal
```

**Effect:** Highlighted, attention-grabbing

---

## 🎯 Best Practices

### DO:
✅ Use navy background logo on navy backgrounds  
✅ Give logo breathing room (24px+ padding)  
✅ Add subtle glow for depth  
✅ Maintain aspect ratio (contain, not cover)  
✅ Use fallback for error handling  
✅ Center logo for prominence  

### DON'T:
❌ Stretch or distort logo  
❌ Use on clashing background colors  
❌ Make too small (min 30px)  
❌ Overlay with busy patterns  
❌ Use low-quality versions  
❌ Forget fallback handling  

---

## 📱 Responsive Sizing

### Desktop (>1024px):
```dart
height: 140,  // Large and prominent
padding: EdgeInsets.all(24),
```

### Tablet (768-1024px):
```dart
height: 120,  // Slightly smaller
padding: EdgeInsets.all(20),
```

### Mobile (<768px):
```dart
height: 100,  // Compact but visible
padding: EdgeInsets.all(16),
```

### Mobile Portrait (<480px):
```dart
height: 80,   // Minimized for space
padding: EdgeInsets.all(12),
```

---

## 🔧 Implementation Checklist

### Login Screen:
- [x] Logo container with glow effect
- [x] Navy background PNG used
- [x] Fallback to transparent SVG
- [x] Height: 140px
- [x] Centered placement
- [x] Tagline below logo
- [x] Proper spacing (16-24px)
- [x] Responsive sizing

### Checkout Screen:
- [x] Logo in header
- [x] Navy background PNG used
- [x] Fallback handling
- [x] Height: 50px
- [x] Left-aligned with back button
- [x] Subtle container background
- [x] Integrates with header gradient
- [x] Scales with header

---

## 🎨 Visual Identity

### Primary Touchpoints:
1. **Login/Signup** → Large logo (140px)
2. **Checkout** → Header logo (50px)
3. **Email** → Logo in header
4. **Documents** → Logo in footer
5. **Error pages** → Centered logo

### Consistency:
- **Always use navy background version** on navy backgrounds
- **Always maintain aspect ratio** (no stretching)
- **Always include fallback** for robustness
- **Always give breathing room** (padding)
- **Always center for prominence** (login, errors)

---

## 🚀 Result

**Login Screen:**
- Logo is the **FIRST** thing users see
- **140px height** = prominent and memorable
- **Teal glow** = modern and professional
- **Navy blend** = seamless integration

**Checkout Screen:**
- Logo **always visible** during checkout
- **50px height** = present but not overwhelming
- **Header integration** = cohesive experience
- **Brand continuity** = trust and recognition

Both implementations successfully establish **strong brand presence** while maintaining **excellent usability**! 🎉
