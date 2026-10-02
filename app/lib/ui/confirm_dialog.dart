import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_button.dart';

/// نافذة تأكيد بسيطة. تعيد true فقط عند الضغط على زر التأكيد.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'إلغاء',
  bool destructive = false,
  IconData? icon,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: icon == null ? null : Icon(icon, color: destructive ? AppColors.error : AppColors.pomegranate, size: 32),
      title: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: AppFonts.display, fontSize: 20, fontWeight: FontWeight.w700),
      ),
      content: Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, height: 1.6)),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: cancelLabel,
                variant: AppButtonVariant.secondary,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppButton(
                label: confirmLabel,
                variant: destructive ? AppButtonVariant.danger : AppButtonVariant.primary,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return result ?? false;
}
