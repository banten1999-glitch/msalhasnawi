import 'package:flutter/material.dart';

import 'ui_tokens.dart';

/// بطاقة بيضاء بزوايا 16 وحد #ECE4D8 كما في التصميم.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = Colors.white,
    this.borderColor = UiColors.cardBorder,
    this.borderWidth = 1,
    this.radius = 16,
    this.onTap,
    this.clip = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final double borderWidth;
  final double radius;
  final VoidCallback? onTap;

  /// يقصّ المحتوى على حدود الزوايا (للخلفيات الملونة داخل البطاقة).
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: borderColor, width: borderWidth),
    );
    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = InkWell(onTap: onTap, customBorder: shape, child: content);
    }
    return Material(
      color: color,
      shape: shape,
      clipBehavior: clip || onTap != null ? Clip.antiAlias : Clip.none,
      shadowColor: const Color(0x0A1C1714),
      elevation: 0.5,
      child: content,
    );
  }
}
