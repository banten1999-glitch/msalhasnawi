import 'package:flutter/material.dart';

/// أيقونة تنعكس أفقيًا في الاتجاه من اليمين لليسار (مثل أيقونة الخروج التي لا تنعكس تلقائيًا).
class DirectionalIcon extends StatelessWidget {
  const DirectionalIcon(this.icon, {super.key, this.size, this.color});

  final IconData icon;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final child = Icon(icon, size: size, color: color);
    return rtl ? Transform.flip(flipX: true, child: child) : child;
  }
}
