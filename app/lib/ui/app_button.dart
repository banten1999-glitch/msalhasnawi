import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ui_tokens.dart';

enum AppButtonVariant {
  /// رماني — الإجراء الرئيسي.
  primary,

  /// أبيض بحد — إجراء ثانوي.
  secondary,

  /// أخضر داكن — تأكيد (تقفيل، إصلاح الملف).
  success,

  /// أبيض بنص أحمر — إلغاء سجل أو خروج.
  danger,

  /// نص فقط.
  text,
}

/// زر بأسلوب التصميم: ارتفاع 52 للإجراء الرئيسي، ويتحول إلى «جارٍ...» ويُقفل أثناء التنفيذ
/// حتى لا تتكرر العملية.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.busy = false,
    this.busyLabel,
    this.height = 52,
    this.expand = false,
    this.foreground,
    this.borderColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final bool busy;

  /// النص أثناء التنفيذ، مثل «جارٍ الحفظ».
  final String? busyLabel;
  final double height;

  /// يملأ العرض المتاح.
  final bool expand;
  final Color? foreground;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    const textStyle = TextStyle(fontFamily: AppFonts.body, fontSize: 15.5, fontWeight: FontWeight.w700, height: 1.3);
    final minSize = Size(expand ? double.infinity : 48, height);
    const padding = EdgeInsets.symmetric(horizontal: 16, vertical: 8);
    const disabledBg = UiColors.greyBg;
    const disabledFg = Color(0xFF9A9089);

    final (Color bg, Color fg, BorderSide? side) = switch (variant) {
      AppButtonVariant.primary => (AppColors.pomegranate, Colors.white, null),
      AppButtonVariant.success => (AppColors.leaf, Colors.white, null),
      AppButtonVariant.secondary =>
        (Colors.white, foreground ?? AppColors.ink, BorderSide(color: borderColor ?? UiColors.fieldBorder, width: 1.5)),
      AppButtonVariant.danger =>
        (Colors.white, AppColors.error, BorderSide(color: borderColor ?? UiColors.errorBorder, width: 1.5)),
      AppButtonVariant.text => (Colors.transparent, foreground ?? AppColors.pomegranate, null),
    };

    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(minSize),
      padding: const WidgetStatePropertyAll(padding),
      shape: WidgetStatePropertyAll(shape),
      textStyle: const WidgetStatePropertyAll(textStyle),
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled) && !busy) {
          return variant == AppButtonVariant.text ? Colors.transparent : disabledBg;
        }
        return bg;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled) && !busy) return disabledFg;
        return fg;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        if (side == null) return null;
        if (states.contains(WidgetState.disabled) && !busy) return const BorderSide(color: disabledBg, width: 1.5);
        return side;
      }),
      overlayColor: WidgetStatePropertyAll(fg.withValues(alpha: 0.08)),
    );

    final children = <Widget>[
      if (busy)
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: fg),
        )
      else if (icon != null)
        Icon(icon, size: 20),
      if (busy || icon != null) const SizedBox(width: 8),
      Flexible(
        child: Text(
          busy ? (busyLabel ?? label) : label,
          textAlign: TextAlign.center,
          softWrap: true,
        ),
      ),
    ];

    final child = Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: children);
    final pressed = busy ? null : onPressed;

    return switch (variant) {
      AppButtonVariant.secondary || AppButtonVariant.danger =>
        OutlinedButton(onPressed: pressed, style: style, child: child),
      AppButtonVariant.text => TextButton(onPressed: pressed, style: style, child: child),
      _ => FilledButton(onPressed: pressed, style: style, child: child),
    };
  }
}
