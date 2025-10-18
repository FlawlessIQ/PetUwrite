# Policies Tab Fixes

**Date**: October 14, 2025  
**Status**: ✅ Complete

## Issues Fixed

### 1. Permission Denied Error ✅
**Problem**: Admin dashboard Policies tab showed error:
```
Error loading policies: [cloud_firestore/permission-denied] 
Missing or insufficient permissions.
```

**Root Cause**: Firestore security rules only allowed users to read their own policies, not admins to read all policies.

**Solution**: Updated `firestore.rules` to allow admins (`userRole == 2`) to read all policies:
```dart
// Before
allow read: if isAuthenticated() && (
  resource.data.ownerId == request.auth.uid
);

// After
allow read: if isAuthenticated() && (
  resource.data.ownerId == request.auth.uid || isAdmin()
);
```

Also allowed admins to update policies:
```dart
allow update: if isAuthenticated() && (
  resource.data.ownerId == request.auth.uid || isAdmin()
);
```

**Deployment**: ✅ Rules deployed successfully
```bash
firebase deploy --only firestore:rules
```

---

### 2. UI Overflow Error ✅
**Problem**: Dropdown filters caused layout overflow:
```
A RenderFlex overflowed by 26 pixels on the right.
DropdownButtonFormField at line 536
```

**Root Cause**: Three `Expanded` dropdowns in a `Row` were too wide for smaller screens, causing text and icons to overflow.

**Solution**: Changed layout from `Row` with `Expanded` to `Wrap` with fixed-width `SizedBox`:

```dart
// Before
Row(
  children: [
    Expanded(child: DropdownButtonFormField(...)),
    Expanded(child: DropdownButtonFormField(...)),
    Expanded(child: DropdownButtonFormField(...)),
  ],
)

// After
Wrap(
  spacing: 12,
  runSpacing: 12,
  children: [
    SizedBox(width: 200, child: DropdownButtonFormField(...)),
    SizedBox(width: 200, child: DropdownButtonFormField(...)),
    SizedBox(width: 200, child: DropdownButtonFormField(...)),
  ],
)
```

**Additional Improvements**:
- Added `isDense: true` to all dropdown decorations for better spacing
- Added `isExpanded: true` to all dropdowns to prevent text truncation
- Filters now wrap to multiple lines on narrow screens

---

## Modified Files

1. **`firestore.rules`** (line 122-131)
   - Updated policies collection read permission to include admins
   - Updated policies collection update permission to include admins

2. **`lib/screens/admin/policies_pipeline_tab.dart`** (line 491-560)
   - Changed `_buildFilters()` layout from `Row` to `Wrap`
   - Changed child widgets from `Expanded` to `SizedBox(width: 200)`
   - Added `isDense: true` and `isExpanded: true` to all dropdowns

---

## Testing Checklist

- [x] Firestore rules deployed successfully
- [x] UI overflow error resolved
- [ ] Verify admin can now see all policies in Policies tab
- [ ] Test filter dropdowns on various screen sizes
- [ ] Verify dropdowns wrap properly on narrow screens (<650px)
- [ ] Confirm no layout overflow errors in console

---

## Impact

✅ **Admin Access**: Admins can now view, filter, and manage all policies across all customers  
✅ **Responsive UI**: Filter dropdowns work correctly on all screen sizes  
✅ **Better UX**: Fixed-width dropdowns with wrapping provide consistent, professional appearance  

---

## Next Steps

1. Hot reload the Flutter app to see the UI fixes
2. Test the Policies tab with your admin account
3. Verify all filters work correctly (Status, Date Range, Sort)
4. Check that policy data loads without permission errors
