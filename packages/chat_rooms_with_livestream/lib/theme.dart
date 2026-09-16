import 'package:flutter/material.dart';

/// The app palette: near-black surfaces, an electric purple accent, and a
/// single hot pink reserved exclusively for anything live.
abstract class AppColors {
  static const background = Color(0xFF0D0A14);
  static const surface = Color(0xFF16121F);
  static const surfaceHigh = Color(0xFF211B2E);
  static const outline = Color(0xFF322A44);
  static const primary = Color(0xFFA855F7);
  static const onPrimary = Color(0xFF17021F);
  static const live = Color(0xFFFF3D71);
  static const text = Color(0xFFEDE9F5);
  static const textMuted = Color(0xFF9B91B0);
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    secondary: AppColors.live,
    onSecondary: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    surfaceContainerHighest: AppColors.surfaceHigh,
    onSurfaceVariant: AppColors.textMuted,
    outline: AppColors.outline,
    outlineVariant: AppColors.outline,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.outline,
      space: 1,
      thickness: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.surfaceHigh,
      contentTextStyle: TextStyle(color: AppColors.text),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
