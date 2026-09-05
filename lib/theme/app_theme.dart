import 'package:flutter/material.dart';

import 'brand_config.dart';
import 'tokens.dart';

/// Builds the app's single [ThemeData] from [AppColors]/[AppType] and the
/// supplied [BrandConfig].
///
/// This used to be ~90 lines inline in `lib/app.dart` seeded from
/// `ColorScheme.fromSeed`, which meant Material's own widgets — dialogs, date
/// pickers, snackbars — drew themselves from generated tonal palettes and
/// looked like a different app. Every scheme field that those widgets read is
/// now set explicitly.
///
/// Light only. No screen may branch on brightness in this release: a
/// half-built dark mode is worse than none.
ThemeData buildAppTheme(BrandConfig brand) {
  final scheme = ColorScheme.light(
    primary: brand.deep,
    onPrimary: AppColors.textOnDark,
    primaryContainer: brand.primary,
    onPrimaryContainer: brand.onPrimary,
    secondary: brand.primary,
    onSecondary: brand.onPrimary,
    secondaryContainer: AppColors.surfaceMuted,
    onSecondaryContainer: AppColors.textPrimary,
    tertiary: AppColors.info,
    onTertiary: AppColors.textOnDark,
    surface: AppColors.bg,
    onSurface: AppColors.textPrimary,
    surfaceContainerLowest: AppColors.surface,
    surfaceContainerLow: AppColors.surface,
    surfaceContainer: AppColors.bg,
    surfaceContainerHigh: AppColors.surfaceMuted,
    surfaceContainerHighest: AppColors.surfaceMuted,
    onSurfaceVariant: AppColors.textSecondary,
    outline: AppColors.border,
    outlineVariant: AppColors.border,
    error: AppColors.negative,
    onError: AppColors.textOnDark,
    errorContainer: AppColors.negativeSoft,
    onErrorContainer: AppColors.negative,
    shadow: const Color(0xFF000000),
  );

  // Material `elevation:` is not used anywhere; the two AppShadow entries are
  // the only shadows in the app. Buttons and cards therefore ship flat.
  ButtonStyle buttonBase(Color fg, Color? bg) => ButtonStyle(
    elevation: const WidgetStatePropertyAll(0),
    foregroundColor: WidgetStatePropertyAll(fg),
    backgroundColor: bg == null ? null : WidgetStatePropertyAll(bg),
    textStyle: const WidgetStatePropertyAll(AppType.label),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: AppSpace.s4, vertical: AppSpace.s3),
    ),
    shape: const WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: AppRadius.rS),
    ),
    minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
  );

  return ThemeData(
    useMaterial3: true,
    visualDensity: VisualDensity.compact,
    fontFamily: 'Raleway',
    colorScheme: scheme,
    // Transparent, not `AppColors.bg`. The decorative background is painted
    // once for the whole app in `app.dart`'s builder; an opaque Scaffold ground
    // would cover it on every screen, which is what it did before the device
    // pass. The cream is still there — it is the `ColoredBox` under the art.
    //
    // Dialogs, sheets, snackbars and the date picker all set their own opaque
    // surfaces below, so none of them go see-through with this.
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: AppColors.bg,
    dividerColor: AppColors.border,
    textTheme: AppType.textTheme,
    primaryTextTheme: AppType.textTheme,
    iconTheme: const IconThemeData(color: AppColors.textSecondary),
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: AppType.titleL,
      iconTheme: IconThemeData(color: AppColors.textPrimary),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.rM),
    ),
    listTileTheme: ListTileThemeData(
      dense: true,
      visualDensity: VisualDensity.compact,
      iconColor: AppColors.textSecondary,
      titleTextStyle: AppType.titleS,
      subtitleTextStyle: AppType.bodyS.copyWith(color: AppColors.textSecondary),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.rS),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      elevation: 0,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? brand.deep
              : AppColors.textTertiary,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => AppType.caption.copyWith(
          color: states.contains(WidgetState.selected)
              ? brand.deep
              : AppColors.textTertiary,
        ),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: brand.deep,
      unselectedLabelColor: AppColors.textTertiary,
      labelStyle: AppType.titleS,
      unselectedLabelStyle: AppType.titleS,
      indicatorColor: brand.deep,
      dividerColor: Colors.transparent,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceMuted,
      selectedColor: brand.primary,
      side: const BorderSide(color: AppColors.border),
      labelStyle: AppType.label,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.rFull),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s3,
        vertical: AppSpace.s1,
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: TextStyle(color: AppColors.textTertiary),
      labelStyle: TextStyle(color: AppColors.textSecondary),
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppSpace.s4,
        vertical: AppSpace.s3,
      ),
      border: OutlineInputBorder(
        borderRadius: AppRadius.rM,
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.rM,
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.rM,
        borderSide: BorderSide(color: AppColors.brandDeep, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.rM,
        borderSide: BorderSide(color: AppColors.negative),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: AppType.titleM,
      contentTextStyle: AppType.body.copyWith(color: AppColors.textSecondary),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.rM),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.brandDeepest,
      contentTextStyle: TextStyle(color: AppColors.textOnDark),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.rS),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      headerBackgroundColor: brand.deep,
      headerForegroundColor: AppColors.textOnDark,
      todayBorder: BorderSide(color: brand.deep),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.rM),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: brand.deep,
      linearTrackColor: AppColors.surfaceMuted,
      circularTrackColor: AppColors.surfaceMuted,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? brand.deep
            : AppColors.surface,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? brand.primary
            : AppColors.surfaceMuted,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: brand.primary,
      foregroundColor: brand.onPrimary,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.rFull),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: buttonBase(AppColors.textOnDark, brand.deep),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: buttonBase(AppColors.textOnDark, brand.deep),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: buttonBase(
        brand.deep,
        null,
      ).copyWith(side: WidgetStatePropertyAll(BorderSide(color: brand.deep))),
    ),
    textButtonTheme: TextButtonThemeData(style: buttonBase(brand.deep, null)),
  );
}
