import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// دائرة بالحرفين الأولين من الاسم («م ح»).
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar(
    this.initials, {
    super.key,
    this.size = 40,
    this.background = AppColors.leaf,
    this.foreground = Colors.white,
  });

  final String initials;
  final double size;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Text(
          initials,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: TextStyle(
            fontSize: size * 0.35,
            fontWeight: FontWeight.w700,
            color: foreground,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}
