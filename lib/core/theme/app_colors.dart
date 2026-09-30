import 'package:flutter/material.dart';

/// Design Tokens — دايت كنج POS
/// اللوحة اللونية الكاملة للنظام (Dark Theme)
abstract final class AppColors {
  // ── Backgrounds & Surfaces ──────────────────────────────────────────────────
  static const Color background = Color(0xFF101319);
  static const Color surface = Color(0xFF101319);
  static const Color surfaceContainerLowest = Color(0xFF0B0E14);
  static const Color surfaceContainerLow = Color(0xFF191C22);
  static const Color surfaceContainer = Color(0xFF1D2026);
  static const Color surfaceContainerHigh = Color(0xFF272A31);

  // ── Primary ─────────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFFFFC880);
  static const Color primaryContainer = Color(0xFFF5A623);
  static const Color primaryFixedDim = Color(0xFFFFB955);
  static const Color onPrimary = Color(0xFF452B00);
  static const Color onPrimaryContainer = Color(0xFF644000);

  // ── On-Surface ───────────────────────────────────────────────────────────────
  static const Color onSurface = Color(0xFFE1E2EB);
  static const Color onSurfaceVariant = Color(0xFFD7C3AE);
  static const Color outlineVariant = Color(0xFF524534);

  // ── Tertiary ─────────────────────────────────────────────────────────────────
  static const Color tertiary = Color(0xFF5BEAAD);
  static const Color tertiaryContainer = Color(0xFF38CD93);

  // ── Gradient helpers ─────────────────────────────────────────────────────────
  static const LinearGradient primaryButtonGradient = LinearGradient(
    colors: [primaryContainer, primaryFixedDim, primary],
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
  );

  static const LinearGradient topBarGradient = LinearGradient(
    colors: [Color(0x00F5A623), Color(0x66F5A623), Color(0x00F5A623)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}
