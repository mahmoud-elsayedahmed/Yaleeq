import 'dart:ui';

/// Curated dark-mode color palette for Yaleeq.
abstract final class AppColors {
  // ── Backgrounds ───────────────────────────────────────
  static const Color background = Color(0xFF0D0D1A);
  static const Color surface = Color(0xFF1A1A2E);
  static const Color surfaceLight = Color(0xFF16213E);

  // ── Primary ───────────────────────────────────────────
  static const Color primary = Color(0xFF6C5CE7);
  static const Color primaryLight = Color(0xFFA29BFE);

  // ── Accent ────────────────────────────────────────────
  static const Color accent = Color(0xFFFDCB6E);

  // ── Text ──────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xB3FFFFFF); // 70 %
  static const Color textHint = Color(0x80FFFFFF); // 50 %

  // ── Semantic ──────────────────────────────────────────
  static const Color success = Color(0xFF00B894);
  static const Color error = Color(0xFFFF6B6B);

  // ── Cards / Glassmorphism ─────────────────────────────
  static const Color cardFill = Color(0x14FFFFFF); //  8 %
  static const Color cardBorder = Color(0x1AFFFFFF); // 10 %
  static const Color selectedBorder = Color(0xFF6C5CE7);
}
