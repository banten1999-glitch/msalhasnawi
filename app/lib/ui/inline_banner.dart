import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ui_tokens.dart';

enum BannerKind { info, success, warning, error, offline }

/// شريط رسالة داخل الصفحة (نجاح، تنبيه، خطأ، لا اتصال) مع إجراء اختياري.
class InlineBanner extends StatelessWidget {
  const InlineBanner({
    super.key,
    required this.message,
    this.kind = BannerKind.info,
    this.title,
    this.actionLabel,
    this.onAction,
    this.icon,
    this.dense = false,
  });

  final String message;
  final String? title;
  final BannerKind kind;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, IconData defIcon) = switch (kind) {
      BannerKind.info => (AppColors.infoLight, AppColors.info, Icons.info_outline),
      BannerKind.success => (AppColors.leafLight, AppColors.leaf, Icons.check_circle_outline),
      BannerKind.warning => (AppColors.amberLight, AppColors.amber, Icons.warning_amber_rounded),
      BannerKind.error => (UiColors.errorBg, AppColors.error, Icons.error_outline),
      BannerKind.offline => (UiColors.darkBanner, Colors.white, Icons.cloud_off_outlined),
    };
    final textColor = kind == BannerKind.error ? UiColors.errorInk : fg;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: dense ? 6 : 10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(dense ? 0 : 12)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon ?? defIcon, size: 20, color: fg),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null)
                    Text(title!, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor, height: 1.45)),
                  Text(message, style: TextStyle(fontSize: dense ? 13 : 14, color: textColor, height: 1.45)),
                ],
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: fg,
                  minimumSize: const Size(48, 44),
                  textStyle: const TextStyle(fontFamily: AppFonts.body, fontWeight: FontWeight.w700, fontSize: 14),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
