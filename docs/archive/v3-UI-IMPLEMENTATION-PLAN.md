# Milano Orders v3 UI — Implementation Plan

## Overview

Seven visual changes to Home tab, global nav, splash, and app background from `docs/v3-UI.txt`. No new features or data logic — purely relocating existing widgets and styling.

**Key architectural insight:** `StatefulShellRoute.indexedStack` has one **outer** `Scaffold` (`_ScaffoldWithNavBar`) wrapping the 4 tab branches, each with its own **nested inner** `Scaffold`. The FAB and background must live on the outer Scaffold for correct layering and visibility.

---

## Phase 1: Setup & Dependencies

### Action Items
1. Add local Poppins fonts to the project
   - Create `assets/fonts/` directory
   - Add 4 weight files: Poppins-Regular.ttf, Poppins-Medium.ttf (weight 500), Poppins-SemiBold.ttf (weight 600), Poppins-Bold.ttf (weight 700)
   - Source: Google Fonts official open-source Poppins release (OFL license)

2. Update `pubspec.yaml`
   - Add `fonts:` block declaring all 4 weights with `family: Poppins`
   - Update `flutter_native_splash:` block: remove both `image:` keys, change `color` to `#FFFBF5`
   - Remove `google_fonts: ^6.2.1` dependency (no longer needed after local fonts added)

3. Run `dart run flutter_native_splash:create` to regenerate native splash files

### Success Criteria
- ✅ `pubspec.yaml` has no `google_fonts` dependency
- ✅ `pubspec.yaml` declares 4 Poppins weights under `fonts:`
- ✅ `assets/fonts/` contains 4 `.ttf` files
- ✅ `flutter analyze` reports no unused `google_fonts` imports
- ✅ `android/app/src/main/res/drawable/launch_background.xml` has no `splash` bitmap layer
- ✅ iOS `LaunchScreen.storyboard` shows plain color background (no logo)

---

## Phase 2: Global App Shell — Floating Nav Bar & Shared FAB

### Action Items

#### 2a. Create `lib/widgets/floating_nav_bar.dart` (new file)
- Icon-only floating pill nav bar widget
- `StatefulWidget` with `SingleTickerProviderStateMixin`
- Visual: 64px tall, pill-shaped (32px border radius), 2-left/2-right icon split around center FAB gap
- Icons: `home_outlined/home`, `receipt_long_outlined/receipt_long`, `restaurant_outlined/restaurant`, `person_outline/person`
- Colors: `kBrandBrown` when selected, `Colors.grey.shade600` unselected
- Entrance animation: 450ms `Curves.easeOutBack`, respects `MediaQuery.disableAnimations`
  - Left icons slide in from `dx: +small → 0`
  - Right icons slide in from `dx: -small → 0`
  - Staggered opacity/scale on all icons
  - Small delayed scale-in on the FAB area
- **Contract:** takes `selectedIndex: int`, `onDestinationSelected: (int) → void`

#### 2b. Create `lib/widgets/app_background.dart` (new file)
- `StatelessWidget` wrapping `CustomPaint`
- `_AppBackgroundPainter` draws sparse, low-opacity vector motif (e.g., faint circles/dots)
- Colors: `kBrandGold.withAlpha(~10-15)` and `kBrandBrown.withAlpha(~8-10)`
- `shouldRepaint => false` (static pattern)
- No package dependencies, no asset files

#### 2c. Modify `lib/app.dart`
- Import the two new widgets and remove `google_fonts` imports
- Switch `textTheme: GoogleFonts.poppinsTextTheme()` to `textTheme: ThemeData(..., fontFamily: 'Poppins', ...)`
- Replace `GoogleFonts.poppins(...)` calls in `navigationBarTheme` with plain `TextStyle(fontFamily: 'Poppins', ...)`
- Update `_ScaffoldWithNavBar.build()`:
  - Replace `bottomNavigationBar: NavigationBar(...)` with `bottomNavigationBar: showNavBar ? FloatingNavBar(...) : null`
  - Add `floatingActionButton:` (shown when `showNavBar` is true):
    ```dart
    floatingActionButton: FloatingActionButton(
      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tap a shop card to enter an order'), duration: Duration(seconds: 2))
      ),
      backgroundColor: kBrandGold,
      foregroundColor: Colors.black87,
      child: const Icon(Icons.add),
    ),
    ```
  - Add `floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked`
  - Wrap `body: navigationShell` in `Stack(children: [Positioned.fill(child: AppBackground()), navigationShell])`
  - Set `backgroundColor: kSurface` on the Scaffold

### Success Criteria
- ✅ `FloatingNavBar` renders as a white/`kSurface` pill at the bottom with 2-left/2-right icon layout
- ✅ FAB sits centered and elevated over the nav bar
- ✅ Nav bar + FAB appear on all 4 tabs (Home, Orders, Kitchen, Profile)
- ✅ Nav bar + FAB hidden on nested routes (order entry, forms)
- ✅ Tapping any icon in the nav bar switches tabs correctly
- ✅ Tapping the FAB shows the SnackBar on every tab
- ✅ Reduced-motion enabled → no entrance animation replays
- ✅ Background pattern visible behind nav bar and content, low-opacity, readable text over it

---

## Phase 3: Home Screen — Remove Header, Promote Greeting, Add SafeArea

### Action Items

#### 3a. Modify `lib/screens/home/home_screen.dart`
- **Remove** the entire `appBar:` block (lines 26-93)
  - This removes: CircleAvatar, "Milano Orders" title, subtitle, notification bell icon
- **Remove** the entire `floatingActionButton:` block (lines 94-106)
  - This FAB is now handled by `_ScaffoldWithNavBar` (Phase 2c)
- **Add** `backgroundColor: Colors.transparent` to the Scaffold
- **Wrap** the body `Column` in `SafeArea(top: true, bottom: false, child: ...)`
  - `top: true` → absorbs status bar inset since there's no AppBar
  - `bottom: false` → avoids double-padding (outer Scaffold's nav already reserves space)

### Success Criteria
- ✅ No "Milano Orders" header visible on Home tab
- ✅ Greeting block ("WELCOME BACK", "Good morning, {name}") sits at the very top, under status bar
- ✅ Date selector visible below greeting
- ✅ Shop list visible below date selector
- ✅ No overlap between greeting text and status bar on notched devices
- ✅ Home screen background shows the app pattern (from Phase 2c)

---

## Phase 4: Date Selector — Restructure into Card

### Action Items

#### 4a. Modify `lib/widgets/date_selector.dart`
- Wrap the existing `Row` in a `Card`
  - `Card(color: kSurface, margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))`
- Inside the Card, place a `Row(mainAxisAlignment: MainAxisAlignment.spaceBetween)`:
  - `_ArrowBtn(Icons.chevron_left)` — left pinned
  - `Expanded(Center(TextButton.icon(...)))` — centered with calendar icon + date label
  - `_ArrowBtn(Icons.chevron_right)` — right pinned
- Retint `_ArrowBtn`:
  - Fill: `kBrandGold.withAlpha(30)`
  - Icon color: `kBrandBrown`
  - Keep 36x36 tap target and `InkWell` structure
- **Do not change** the `showDatePicker` call, `selectedDateProvider` wiring, or `DateFormat` label

### Success Criteria
- ✅ Date sits in a wide rounded card (full width minus margins)
- ✅ Chevron buttons visible at card edges (left/right)
- ✅ Date label centered with calendar icon
- ✅ Tapping date opens `showDatePicker` picker
- ✅ Tapping left/right chevrons steps date ±1 day (same as before)
- ✅ Card styling matches `shop_order_card.dart` rounded-card language

---

## Phase 5: Kitchen Screen — Move Share FAB to AppBar

### Action Items

#### 5a. Modify `lib/screens/kitchen/kitchen_screen.dart`
- **Remove** `floatingActionButton: linesAsync.maybeWhen(...)` block (lines 99-110)
- **Add** `backgroundColor: Colors.transparent` to the Scaffold
- **Modify** the `AppBar.actions` list:
  - Add an `IconButton` after the existing date `TextButton.icon`:
    ```dart
    IconButton(
      icon: const Icon(Icons.share),
      tooltip: 'Share kitchen list',
      onPressed: hasLines ? () => _share(lines, shopMap, productMap) : null,
    )
    ```
  - Compute `hasLines` once before building the AppBar (inside the `linesAsync.when(data: ...)` block)
  - Set `onPressed: null` when empty (disabled, not omitted) so the icon doesn't jump
- Drop the green `0xFF25D366` tint — use default neutral AppBar icon styling
- `_share(...)` method body: **no changes**

### Success Criteria
- ✅ Share icon appears in AppBar (next to date button)
- ✅ Share icon is enabled when `lines.isNotEmpty`, disabled when empty
- ✅ Tapping share icon produces the same share sheet output as before
- ✅ No floating green FAB visible on Kitchen tab
- ✅ Kitchen screen background shows the app pattern

---

## Phase 6: Transparent Backgrounds — Orders & Profile Screens

### Action Items

#### 6a. Modify `lib/screens/orders/orders_screen.dart`
- Add `backgroundColor: Colors.transparent` to the Scaffold (1 line)

#### 6b. Modify `lib/screens/profile/profile_screen.dart`
- Add `backgroundColor: Colors.transparent` to the Scaffold (1 line)

### Success Criteria
- ✅ Orders tab shows the app background pattern behind content
- ✅ Profile tab shows the app background pattern behind content
- ✅ No pattern visible on Order Entry screen (expected, scoped out)
- ✅ No pattern visible on profile sub-forms/screens (expected, scoped out)

---

## Phase 7: Verification & Testing

### Before Running
- ✅ All files edited and saved
- ✅ `flutter analyze` runs cleanly (no errors, no unused imports from removed `google_fonts`)
- ✅ `dart run flutter_native_splash:create` completed successfully

### Cold Start Test
1. Close the app completely
2. `flutter run` on Android emulator or iOS simulator
3. **Verify Item 1 (Splash):**
   - No logo visible on the native pre-Flutter splash screen
   - Plain `#FFFBF5` background shown instead
   - Note: Android 12+ will show the launcher icon (platform behavior, expected)
4. **Verify Item 2 (Poppins):**
   - Check font rendering on greeting text, date label, nav bar labels
   - Enable airplane mode (or disconnect from network) and restart to confirm local font works offline

### Home Tab Test
5. After splash → Home screen loads
6. **Verify Item 5 (No Header):**
   - No "Milano Orders" title visible
   - No notification bell icon visible
   - Greeting block sits at the top under the status bar
7. **Verify Item 7 (Date Card):**
   - Date sits in a rounded card with chevron buttons at edges
   - Tapping the date opens a date picker
   - Tapping left/right chevrons steps the date
8. **Verify Item 6 (Background Pattern):**
   - Low-opacity pattern visible behind content (bakery-themed, golden/brown tones)
   - Text remains readable over the pattern

### Navigation Bar & FAB Test (All Tabs)
9. **Verify Item 3/4 (Nav Bar & FAB):**
   - Bottom shows a white/cream floating pill nav bar (not edge-to-edge)
   - 4 icons visible in 2-left/2-right split around center space
   - Icon-only (no labels visible)
   - FAB centered and elevated above the bar
   - Tap each icon to switch tabs — verify Home, Orders, Kitchen, Profile tabs load correctly
   - Tap the FAB on each tab — verify the same SnackBar appears ("Tap a shop card to enter an order")

### Kitchen Tab Test
10. **Verify Kitchen AppBar Action:**
    - Share icon visible in the AppBar (next to date)
    - Share icon is enabled (clickable) when there are kitchen lines
    - Share icon is disabled (grey, not clickable) when there are no lines
    - Tap the share icon → verify share sheet appears with the same output as before

### Nested Route Test
11. Tap a shop card on Home → navigate to Order Entry screen
12. **Verify Nav Bar + FAB Hidden:**
    - Nav bar disappears
    - FAB disappears
    - Expected, since nested routes hide the nav
13. Tap back or close Order Entry
14. **Verify Nav Bar Reappears:**
    - Nav bar + FAB reappear on Home tab
    - Note entrance animation replays (expected behavior)

### Accessibility Test
15. Enable "Reduce Motion" (or "Disable Animations") in OS accessibility settings
16. Relaunch the app
17. **Verify Reduced Motion:**
    - Nav bar icons appear immediately on app launch (no expansion animation)
    - Nav bar icons appear immediately when returning from nested routes
    - `DateSelector` arrows and date button render instantly (no entrance animation expected)

### Notched Device Test (if available)
18. Run on a notched device (iPhone X+, Android with notch)
19. **Verify SafeArea:**
    - Greeting text does not overlap the status bar or notch
    - No visual glitches at screen edges

### Success Criteria Summary
- ✅ All 7 items from `docs/v3-UI.txt` visibly implemented and working
- ✅ No red errors in `flutter analyze`
- ✅ No SnackBar or log warnings during normal use
- ✅ Poppins font renders consistently (even offline, after bundling)
- ✅ Background pattern visible on main tabs, not on nested routes
- ✅ FAB behavior identical on all 4 tabs (placeholder SnackBar)
- ✅ Navigation (tab switching, nested routes) works as before
- ✅ Kitchen share action moved to AppBar, works identically
- ✅ Reduced-motion respected in animations
- ✅ No crashes or memory leaks during normal navigation

---

## Rollback / Undo Plan

If something breaks during implementation:

1. **Phase 1 only:** `git checkout pubspec.yaml`, remove `assets/fonts/`, re-add `google_fonts` dependency
2. **Phases 1-2:** Also revert `lib/app.dart` to the previous commit
3. **Phase 3:** Also revert `lib/screens/home/home_screen.dart`
4. **Full revert:** `git reset --hard HEAD`

---

## Timeline Estimate

- **Phase 1:** 5 min (pubspec + fonts)
- **Phase 2:** 20 min (2 new widgets, `app.dart` edits)
- **Phase 3:** 5 min (home_screen.dart edits)
- **Phase 4:** 10 min (date_selector.dart card restructure)
- **Phase 5:** 5 min (kitchen_screen.dart FAB → AppBar)
- **Phase 6:** 2 min (orders + profile background lines)
- **Phase 7:** 30 min+ (testing on device/emulator, verification)

**Total:** ~75 minutes for implementation + testing.
