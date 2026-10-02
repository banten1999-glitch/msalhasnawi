import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// ألوان إضافية من لوحة التصميم لا تحتاجها بقية أجزاء التطبيق (حدود البطاقات، الخلفيات الملونة...).
/// الألوان الأساسية في [AppColors].
abstract final class UiColors {
  static const cardBorder = Color(0xFFECE4D8);
  static const divider = Color(0xFFF0EAE0);
  static const fieldBorder = AppColors.border;
  static const label = Color(0xFF3D3530);
  static const hint = Color(0xFF8F857D);
  static const beige = Color(0xFFF3EEE6);
  static const greyBg = Color(0xFFEEE9E2);
  static const greyFg = Color(0xFF4A423C);
  static const unpaidFg = Color(0xFFA3152A);
  static const paidBg = Color(0xFFF2F8F4);
  static const paidBorder = Color(0xFFD3E7DA);
  static const remainingBg = Color(0xFFFFF8EA);
  static const remainingBorder = Color(0xFFF3DDB0);
  static const errorBg = Color(0xFFFDECEA);
  static const errorInk = Color(0xFF8F1D14);
  static const errorBorder = Color(0xFFE7B4AE);
  static const amberBorder = Color(0xFFE3B25C);
  static const warningBg = Color(0xFFFFFCF5);
  static const currentBorder = Color(0xFFE8C4CB);
  static const darkBanner = Color(0xFF2B2420);
  static const infoBorder = Color(0xFFB9CDE8);
  static const tableHead = Color(0xFFFBF8F3);
  static const selectedRow = Color(0xFFFFF7F8);
}

/// أنماط نصية متكررة.
abstract final class UiText {
  /// أرقام بارزة بعرض ثابت (Readex Pro).
  static TextStyle number({double size = 18, Color color = AppColors.ink, FontWeight weight = FontWeight.w700}) =>
      TextStyle(
        fontFamily: AppFonts.display,
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: 1.3,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static const label = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkSecondary, height: 1.4);
  static const muted = TextStyle(fontSize: 13, color: AppColors.inkMuted, height: 1.45);
  static const small = TextStyle(fontSize: 12.5, color: AppColors.inkMuted, height: 1.45);
  static const section = TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: UiColors.label, height: 1.4);
  static const cardTitle = TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink, height: 1.4);
  static const fieldLabel = TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: UiColors.label, height: 1.4);
  static const pageTitle = TextStyle(
    fontFamily: AppFonts.display,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    height: 1.3,
  );
}

/// زخرفة حقل إدخال بأسلوب التصميم: حد 1.5، زوايا 12، ارتفاع 50 على الأقل.
InputDecoration uiInputDecoration({
  String? hint,
  String? errorText,
  String? helperText,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  OutlineInputBorder border(Color c, [double w = 1.5]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c, width: w));
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: UiColors.hint, fontSize: 15),
    errorText: errorText,
    errorMaxLines: 4,
    errorStyle: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w600, height: 1.4),
    helperText: helperText,
    helperMaxLines: 3,
    helperStyle: UiText.small,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: errorText == null ? Colors.white : const Color(0xFFFFFBFA),
    isDense: false,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: border(UiColors.fieldBorder),
    enabledBorder: border(UiColors.fieldBorder),
    disabledBorder: border(UiColors.greyBg),
    focusedBorder: border(AppColors.pomegranate, 2),
    errorBorder: border(AppColors.error),
    focusedErrorBorder: border(AppColors.error, 2),
  );
}
