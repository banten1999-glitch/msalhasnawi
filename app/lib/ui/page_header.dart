import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// عنوان الصفحة على الشاشات العريضة (على الهاتف يظهر العنوان في الشريط العلوي).
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.subtitle, this.actions = const []});

  final String title;
  final String? subtitle;

  /// عناصر في الطرف الآخر (فلاتر، زر تحديث...). تنزل لسطر جديد عند ضيق العرض.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 220),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                    height: 1.3,
                  ),
                ),
              ),
              if (subtitle != null)
                Text(subtitle!, style: const TextStyle(fontSize: 14, color: AppColors.inkMuted, height: 1.5)),
            ],
          ),
        ),
        if (actions.isNotEmpty)
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: actions),
      ],
    );
  }
}
