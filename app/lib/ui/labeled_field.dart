import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ui_tokens.dart';

/// تسمية الحقل فوقه، ثم الحقل، ثم رسالة خطأ اختيارية بجانبه مباشرة.
///
/// لحقول النص استخدم errorText في [uiInputDecoration]؛ [errorText] هنا للعناصر الأخرى (أزرار الاختيار، المفاتيح).
class LabeledField extends StatelessWidget {
  const LabeledField({super.key, required this.label, required this.child, this.errorText, this.helperText});

  final String label;
  final Widget child;
  final String? errorText;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: UiText.fieldLabel),
        const SizedBox(height: 6),
        child,
        if (errorText != null) ...[
          const SizedBox(height: 6),
          FieldError(errorText!),
        ] else if (helperText != null) ...[
          const SizedBox(height: 6),
          Text(helperText!, style: UiText.small),
        ],
      ],
    );
  }
}

/// رسالة خطأ حمراء تحت عنصر في النموذج.
class FieldError extends StatelessWidget {
  const FieldError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.error_outline, size: 16, color: AppColors.error),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w600, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
