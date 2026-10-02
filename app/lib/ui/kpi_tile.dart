import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_card.dart';
import 'money_text.dart';
import 'ui_tokens.dart';

/// لون مميز لبطاقة المؤشر.
enum KpiAccent {
  none,

  /// المدفوع فعليًا (أخضر).
  paid,

  /// المتبقي (كهرماني).
  remaining,
}

/// بطاقة مؤشر: تسمية + رقم كبير + وحدة اختيارية + ملاحظة.
class KpiTile extends StatelessWidget {
  const KpiTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.accent = KpiAccent.none,
    this.note,
    this.valueSize = 22,
  });

  final String label;

  /// الرقم منسقًا (formatCount / formatMoney / formatWeight).
  final String value;
  final String? unit;
  final KpiAccent accent;
  final String? note;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    final (bg, border, fg) = switch (accent) {
      KpiAccent.none => (Colors.white, UiColors.cardBorder, AppColors.ink),
      KpiAccent.paid => (UiColors.paidBg, UiColors.paidBorder, AppColors.leaf),
      KpiAccent.remaining => (UiColors.remainingBg, UiColors.remainingBorder, AppColors.amber),
    };
    return AppCard(
      color: bg,
      borderColor: border,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Semantics(
        container: true,
        label: label,
        value: unit == null ? value : '$value $unit',
        excludeSemantics: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: UiText.label.copyWith(color: accent == KpiAccent.none ? AppColors.inkSecondary : fg)),
            const SizedBox(height: 2),
            NumberText(value, unit: unit, fontSize: valueSize, color: fg, unitFontSize: 13),
            if (note != null) ...[
              const SizedBox(height: 2),
              Text(note!, style: const TextStyle(fontSize: 12, color: AppColors.inkMuted, height: 1.4)),
            ],
          ],
        ),
      ),
    );
  }
}
