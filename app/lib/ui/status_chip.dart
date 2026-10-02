import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ui_tokens.dart';

/// أنواع الشارات بألوان التصميم.
enum StatusKind {
  open,
  closed,
  draft,
  incomplete,
  pending,
  paid,
  partial,
  unpaid,
  cancelled,
  approved,
  active,
  disabled,
  adminOnly,
  role,
  late,
  info,
}

class _ChipStyle {
  const _ChipStyle(this.bg, this.fg, this.label, {this.border, this.icon, this.dot = false, this.strike = false});
  final Color bg;
  final Color fg;
  final String label;
  final Color? border;
  final IconData? icon;
  final bool dot;
  final bool strike;
}

const _styles = <StatusKind, _ChipStyle>{
  StatusKind.open: _ChipStyle(AppColors.leafLight, AppColors.leaf, 'مفتوح', dot: true),
  StatusKind.closed: _ChipStyle(UiColors.greyBg, UiColors.greyFg, 'مقفّل', icon: Icons.lock_outline),
  StatusKind.draft: _ChipStyle(AppColors.amberLight, AppColors.amber, 'مسودة'),
  StatusKind.incomplete: _ChipStyle(Colors.white, AppColors.amber, 'غير مكتمل', border: UiColors.amberBorder),
  StatusKind.pending: _ChipStyle(AppColors.infoLight, AppColors.info, 'بانتظار المزامنة', icon: Icons.cloud_upload_outlined),
  StatusKind.paid: _ChipStyle(AppColors.leafLight, AppColors.leaf, 'مدفوع'),
  StatusKind.partial: _ChipStyle(AppColors.amberLight, AppColors.amber, 'دفع جزئي'),
  StatusKind.unpaid: _ChipStyle(AppColors.pomegranateLight, UiColors.unpaidFg, 'غير مدفوع'),
  StatusKind.cancelled: _ChipStyle(UiColors.greyBg, UiColors.greyFg, 'ملغى', strike: true),
  StatusKind.approved: _ChipStyle(AppColors.leafLight, AppColors.leaf, 'معتمد'),
  StatusKind.active: _ChipStyle(AppColors.leafLight, AppColors.leaf, 'نشط'),
  StatusKind.disabled: _ChipStyle(UiColors.greyBg, UiColors.greyFg, 'معطّل'),
  StatusKind.adminOnly: _ChipStyle(AppColors.ink, Colors.white, 'للمدير فقط'),
  StatusKind.role: _ChipStyle(UiColors.beige, UiColors.label, ''),
  StatusKind.late: _ChipStyle(Colors.white, AppColors.info, 'تكلفة متأخرة', border: UiColors.infoBorder),
  StatusKind.info: _ChipStyle(AppColors.infoLight, AppColors.info, ''),
};

/// شارة حالة صغيرة: «مفتوح»، «مسودة»، «غير مدفوع»...
class StatusChip extends StatelessWidget {
  const StatusChip(this.kind, {super.key, this.label, this.dense = false});

  /// يحوّل حالة من الخادم (paid، partial، draft، open...) إلى شارة. [label] من الخادم يتقدّم على الافتراضي.
  factory StatusChip.fromStatus(String status, {Key? key, String? label, bool dense = false}) =>
      StatusChip(kindForStatus(status), key: key, label: (label == null || label.isEmpty) ? null : label, dense: dense);

  final StatusKind kind;
  final String? label;

  /// أصغر قليلًا داخل القوائم.
  final bool dense;

  static StatusKind kindForStatus(String status) => switch (status) {
        'open' => StatusKind.open,
        'closed' => StatusKind.closed,
        'draft' => StatusKind.draft,
        'incomplete' => StatusKind.incomplete,
        'pending' => StatusKind.pending,
        'paid' => StatusKind.paid,
        'partial' => StatusKind.partial,
        'unpaid' => StatusKind.unpaid,
        'cancelled' || 'removed' => StatusKind.cancelled,
        'approved' || 'complete' => StatusKind.approved,
        'active' => StatusKind.active,
        'disabled' || 'inactive' => StatusKind.disabled,
        _ => StatusKind.info,
      };

  @override
  Widget build(BuildContext context) {
    final s = _styles[kind]!;
    final text = label ?? s.label;
    final fontSize = dense ? 11.5 : 12.5;
    return Container(
      constraints: BoxConstraints(minHeight: dense ? 22 : 26),
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: 2),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(999),
        border: s.border == null ? null : Border.all(color: s.border!, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (s.dot) ...[
            Container(width: 7, height: 7, decoration: BoxDecoration(color: s.fg, shape: BoxShape.circle)),
            const SizedBox(width: 5),
          ],
          if (s.icon != null) ...[
            Icon(s.icon, size: dense ? 13 : 15, color: s.fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: s.fg,
                height: 1.2,
                decoration: s.strike ? TextDecoration.lineThrough : null,
                decorationColor: s.fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
