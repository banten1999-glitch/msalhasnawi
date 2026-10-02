import 'package:flutter/material.dart';

import 'ui_tokens.dart';

/// عنوان قسم صغير مع عنصر اختياري في الطرف الآخر (تاريخ، رابط...).
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing, this.subtitle, this.style});

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(header: true, child: Text(title, style: style ?? UiText.section)),
              if (subtitle != null) Text(subtitle!, style: UiText.small),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}
