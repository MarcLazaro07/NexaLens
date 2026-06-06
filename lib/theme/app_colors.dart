import 'package:flutter/material.dart';

class AppColors {
  // ─── Primary Gradient ───
  static const Color primaryCyan = Color(0xFF00D4AA);
  static const Color primaryBlue = Color(0xFF0088FF);
  static const Color accentPurple = Color(0xFF7C3AED);
  static const Color accentPink = Color(0xFFE040FB);

  // ─── Background ───
  static const Color darkBg = Color(0xFF0A0E1A);
  static const Color darkBgSecondary = Color(0xFF1A1F35);
  static const Color darkSurface = Color(0xFF141829);
  static const Color darkCard = Color(0xFF1E2340);

  // ─── Glass ───
  static const Color glassWhite = Color(0x14FFFFFF);
  static const Color glassBorder = Color(0x1AFFFFFF);
  static const Color glassHighlight = Color(0x0DFFFFFF);

  // ─── Semantic ───
  static const Color success = Color(0xFF00E676);
  static const Color warning = Color(0xFFFFD600);
  static const Color error = Color(0xFFFF5252);
  static const Color info = Color(0xFF40C4FF);

  // ─── Text ───
  static const Color textPrimary = Color(0xFFF0F0F5);
  static const Color textSecondary = Color(0xFF9CA3BF);
  static const Color textTertiary = Color(0xFF6B7299);

  // ─── Gradients ───
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryCyan, primaryBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accentPurple, accentPink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [darkBg, darkBgSecondary],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0x14FFFFFF), Color(0x08FFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Module Colors ───
  static const Color moduleDocument = Color(0xFF42A5F5);
  static const Color moduleQR = Color(0xFFAB47BC);
  static const Color moduleTranslate = Color(0xFF26A69A);
  static const Color moduleProduct = Color(0xFFFF7043);
  static const Color moduleOCR = Color(0xFFFFCA28);
  static const Color moduleObject = Color(0xFF66BB6A);
  static const Color moduleAcademic = Color(0xFFEF5350);
  static const Color moduleHistory = Color(0xFF78909C);
  static const Color moduleQRGen = Color(0xFF5C6BC0);
  static const Color moduleColor = Color(0xFFEC407A);
  static const Color moduleMagnifier = Color(0xFF8D6E63);
}
