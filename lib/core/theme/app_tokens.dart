import 'package:flutter/material.dart';

/// Design tokens ported from `ux-guidelines.md`.
///
/// AI/humans must not invent new colors, spacing, radii, or type styles.
/// Use only the tokens declared here.
class AppColors {
  AppColors._();

  // Primary brand
  static const primary500 = Color(0xFF1F3A5F);
  static const primary600 = Color(0xFF162C49);

  // Neutral system
  static const neutral0 = Color(0xFFFFFFFF);
  static const neutral50 = Color(0xFFF8FAFC);
  static const neutral100 = Color(0xFFF1F5F9);
  static const neutral200 = Color(0xFFE2E8F0);
  static const neutral300 = Color(0xFFCBD5E1);
  static const neutral400 = Color(0xFF94A3B8);
  static const neutral500 = Color(0xFF64748B);
  static const neutral600 = Color(0xFF475569);
  static const neutral700 = Color(0xFF334155);
  static const neutral800 = Color(0xFF1E293B);
  static const neutral900 = Color(0xFF0F172A);

  // Status
  static const success500 = Color(0xFF16A34A);
  static const warning500 = Color(0xFFD97706);
  static const error500 = Color(0xFFDC2626);
  static const info500 = Color(0xFF0284C7);

  static const focusRing = Color(0x1A1F3A5F); // rgba(31,58,95,.10)
}

/// Approved spacing values (8px base grid).
class AppSpacing {
  AppSpacing._();

  static const double x4 = 4;
  static const double x8 = 8;
  static const double x16 = 16;
  static const double x20 = 20;
  static const double x24 = 24;
  static const double x32 = 32;
  static const double x48 = 48;
  static const double x64 = 64;

  /// Standard page / container padding.
  static const EdgeInsets pagePadding = EdgeInsets.all(x20);
}

class AppRadius {
  AppRadius._();

  static const double small = 6;
  static const double medium = 8;
  static const double large = 12;

  static const BorderRadius input = BorderRadius.all(Radius.circular(medium));
  static const BorderRadius button = BorderRadius.all(Radius.circular(medium));
  static const BorderRadius card = BorderRadius.all(Radius.circular(large));
  static const BorderRadius dialog = BorderRadius.all(Radius.circular(large));
}

class AppShadows {
  AppShadows._();

  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 3, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> dialog = [
    BoxShadow(color: Color(0x1F000000), blurRadius: 30, offset: Offset(0, 10)),
  ];
}

/// Component sizing tokens.
class AppSizing {
  AppSizing._();

  static const double controlHeight = 40; // input / dropdown / button
  static const double navHeight = 48;
  static const double tableHeaderHeight = 44;
  static const double tableRowHeight = 48;
  static const double dialogMaxWidth = 640;
}
