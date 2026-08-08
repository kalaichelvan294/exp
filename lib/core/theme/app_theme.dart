import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Builds the app-wide [ThemeData] from the design tokens.
///
/// Typography scale (ux-guidelines.md):
///   Page Title    28/700   Section Title 20/600
///   Card Title    16/600   Standard      14/400
///   Helper        12/400 (neutral-500)
class AppTheme {
  AppTheme._();

  static const String _fontFamily = 'Inter';
  static const List<String> _fontFallback = ['Segoe UI', 'Arial', 'sans-serif'];

  static ThemeData light() {
    const colorScheme = ColorScheme.light(
      primary: AppColors.primary500,
      onPrimary: AppColors.neutral0,
      secondary: AppColors.primary600,
      surface: AppColors.neutral0,
      onSurface: AppColors.neutral900,
      error: AppColors.error500,
      onError: AppColors.neutral0,
    );

    final textTheme = _textTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.neutral50,
      fontFamily: _fontFamily,
      fontFamilyFallback: _fontFallback,
      textTheme: textTheme,
      dividerTheme: const DividerThemeData(
        color: AppColors.neutral200,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: AppColors.neutral0,
        textColor: AppColors.neutral900,
        iconColor: AppColors.neutral700,
      ),
      inputDecorationTheme: _inputTheme(),
      elevatedButtonTheme: _primaryButtonTheme(),
      outlinedButtonTheme: _secondaryButtonTheme(),
      cardTheme: CardThemeData(
        color: AppColors.neutral0,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: BorderSide(color: AppColors.neutral200),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.neutral0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.dialog),
      ),
      visualDensity: VisualDensity.standard,
    );
  }

  /// Dark variant applied at the [MaterialApp] level when the user selects the
  /// dark theme in appearance settings. Framework surfaces (dialogs, pickers,
  /// menus) follow this scheme.
  static ThemeData dark() {
    const colorScheme = ColorScheme.dark(
      primary: AppColors.neutral0,
      onPrimary: AppColors.neutral900,
      secondary: AppColors.neutral200,
      surface: AppColors.neutral800,
      onSurface: AppColors.neutral0,
      error: AppColors.error500,
      onError: AppColors.neutral0,
    );

    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.neutral900,
      textTheme: base.textTheme.apply(
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFallback,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.neutral700,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: AppColors.neutral800,
        textColor: AppColors.neutral0,
        iconColor: AppColors.neutral200,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.neutral800,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.dialog),
      ),
      visualDensity: VisualDensity.standard,
    );
  }

  static TextTheme _textTheme() {
    return const TextTheme(
      // Page Title
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 36 / 28,
        color: AppColors.neutral900,
      ),
      // Section Title
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 28 / 20,
        color: AppColors.neutral900,
      ),
      // Card Title
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 24 / 16,
        color: AppColors.neutral900,
      ),
      // Standard Text
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: AppColors.neutral800,
      ),
      // Helper Text
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 18 / 12,
        color: AppColors.neutral500,
      ),
    );
  }

  static InputDecorationTheme _inputTheme() {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: AppRadius.input,
      borderSide: BorderSide(color: color),
    );

    return InputDecorationTheme(
      filled: true,
      fillColor: AppColors.neutral0,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      enabledBorder: border(AppColors.neutral300),
      border: border(AppColors.neutral300),
      hoverColor: Colors.transparent,
      focusedBorder: border(AppColors.primary500),
      disabledBorder: border(AppColors.neutral200),
      errorBorder: border(AppColors.error500),
      focusedErrorBorder: border(AppColors.error500),
      helperStyle: const TextStyle(fontSize: 12, color: AppColors.neutral500),
    );
  }

  static ElevatedButtonThemeData _primaryButtonTheme() {
    return ElevatedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(
          Size(0, AppSizing.controlHeight),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16),
        ),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) return AppColors.primary600;
          return AppColors.primary500;
        }),
        foregroundColor: const WidgetStatePropertyAll(AppColors.neutral0),
        elevation: const WidgetStatePropertyAll(0),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: AppRadius.button),
        ),
      ),
    );
  }

  static OutlinedButtonThemeData _secondaryButtonTheme() {
    return OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(
          Size(0, AppSizing.controlHeight),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16),
        ),
        backgroundColor: const WidgetStatePropertyAll(AppColors.neutral0),
        foregroundColor: const WidgetStatePropertyAll(AppColors.neutral700),
        side: const WidgetStatePropertyAll(
          BorderSide(color: AppColors.neutral300),
        ),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: AppRadius.button),
        ),
      ),
    );
  }
}
