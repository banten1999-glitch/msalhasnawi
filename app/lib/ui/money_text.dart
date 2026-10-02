import 'package:flutter/material.dart';

import '../core/format/numbers.dart';
import '../theme/app_theme.dart';
import 'ui_tokens.dart';

/// رمز العملة الافتراضي (يطابق إعدادات العمل الافتراضية).
const kCurrencySymbol = 'ج.م';

/// وحدة الوزن المعروضة.
const kWeightUnit = 'كغ';

/// رقم بارز (Readex Pro بعرض ثابت) تليه وحدة صغيرة: «2,718.2 كغ».
class NumberText extends StatelessWidget {
  const NumberText(
    this.text, {
    super.key,
    this.unit,
    this.fontSize = 18,
    this.unitFontSize,
    this.color = AppColors.ink,
    this.unitColor,
    this.weight = FontWeight.w700,
    this.strike = false,
    this.textAlign,
  });

  final String text;
  final String? unit;
  final double fontSize;
  final double? unitFontSize;
  final Color color;
  final Color? unitColor;
  final FontWeight weight;
  final bool strike;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    // الأرقام السالبة تُعزل باتجاه LTR حتى تبقى علامة السالب بجانب الرقم داخل نص عربي.
    final shown = text.startsWith('-') ? '⁦$text⁩' : text;
    final deco = strike ? TextDecoration.lineThrough : null;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: shown, style: UiText.number(size: fontSize, color: color, weight: weight).copyWith(decoration: deco)),
          if (unit != null)
            TextSpan(
              text: ' $unit',
              style: TextStyle(
                fontFamily: AppFonts.body,
                fontSize: unitFontSize ?? (fontSize * 0.55).clamp(12, 16).toDouble(),
                fontWeight: FontWeight.w500,
                color: unitColor ?? (color == AppColors.ink ? AppColors.inkMuted : color),
                decoration: deco,
              ),
            ),
        ],
      ),
      textAlign: textAlign,
      softWrap: true,
    );
  }
}

/// مبلغ بالقرش يُعرض «8,250.00 ج.م».
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.piasters, {
    super.key,
    this.fontSize = 18,
    this.color = AppColors.ink,
    this.showCurrency = true,
    this.currencySymbol = kCurrencySymbol,
    this.unitFontSize,
    this.strike = false,
    this.textAlign,
  });

  final int piasters;
  final double fontSize;
  final Color color;
  final bool showCurrency;
  final String currencySymbol;
  final double? unitFontSize;
  final bool strike;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => NumberText(
        formatMoney(piasters),
        unit: showCurrency ? currencySymbol : null,
        fontSize: fontSize,
        unitFontSize: unitFontSize,
        color: color,
        strike: strike,
        textAlign: textAlign,
      );
}

/// وزن بالجرام يُعرض «2,718.2 كغ».
class WeightText extends StatelessWidget {
  const WeightText(this.grams, {super.key, this.fontSize = 18, this.color = AppColors.ink, this.showUnit = true});

  final int grams;
  final double fontSize;
  final Color color;
  final bool showUnit;

  @override
  Widget build(BuildContext context) =>
      NumberText(formatWeight(grams), unit: showUnit ? kWeightUnit : null, fontSize: fontSize, color: color);
}

const _months = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];

/// تاريخ مختصر من طابع ISO بتوقيت العمل: '2026-10-02T06:40:00+03:00' ← '2 أكتوبر 2026'.
/// يعرض الجزء المحلي كما هو دون تحويل المنطقة الزمنية.
String formatArabicDate(String? iso, {bool withYear = true}) {
  if (iso == null || iso.length < 10) return '';
  final y = iso.substring(0, 4);
  final m = int.tryParse(iso.substring(5, 7));
  final d = int.tryParse(iso.substring(8, 10));
  if (m == null || d == null || m < 1 || m > 12) return iso.substring(0, 10);
  return withYear ? '$d ${_months[m - 1]} $y' : '$d ${_months[m - 1]}';
}

/// تاريخ ووقت: '2 أكتوبر 2026 · 06:40 ص'.
String formatArabicDateTime(String? iso) {
  final date = formatArabicDate(iso);
  final time = formatLocalTimestamp(iso, withDate: false);
  if (date.isEmpty) return '';
  return time.isEmpty ? date : '$date · $time';
}
