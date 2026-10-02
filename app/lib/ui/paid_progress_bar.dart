import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// شريط المدفوع من القيمة: أخضر للمدفوع على خلفية كهرمانية للمتبقي.
class PaidProgressBar extends StatelessWidget {
  const PaidProgressBar({super.key, required this.paid, required this.total, this.height = 8});

  final int paid;
  final int total;
  final double height;

  /// نسبة المدفوع بين 0 و1.
  double get fraction => total <= 0 ? 0 : (paid / total).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final percent = (fraction * 100).round();
    return Semantics(
      label: 'نسبة المدفوع',
      value: '$percent٪',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              const Positioned.fill(child: ColoredBox(color: AppColors.amberLight)),
              // يبدأ المدفوع من بداية السطر (اليمين في العربية).
              FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: fraction,
                heightFactor: 1,
                child: const ColoredBox(color: AppColors.leaf),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
