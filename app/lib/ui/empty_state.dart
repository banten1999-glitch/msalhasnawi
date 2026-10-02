import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_button.dart';
import 'ui_tokens.dart';

/// حالة فارغة: أيقونة في دائرة، عنوان، شرح، وزر اختياري.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.footer,
    this.iconColor = AppColors.leaf,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  /// محتوى إضافي تحت الزر (مثل خطوات البدء).
  final Widget? footer;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: UiColors.cardBorder),
                  ),
                  child: Icon(icon, size: 60, color: iconColor),
                ),
              ),
              const SizedBox(height: 18),
              Semantics(
                header: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: AppFonts.display, fontSize: 22, fontWeight: FontWeight.w700, height: 1.35),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: AppColors.inkMuted, height: 1.6),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 20),
                AppButton(label: actionLabel!, icon: actionIcon, onPressed: onAction, expand: true),
              ],
              if (footer != null) ...[const SizedBox(height: 18), footer!],
            ],
          ),
        ),
      ),
    );
  }
}
