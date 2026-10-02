import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/user.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// محتوى تبويب قابل للتمرير بعرض مريح على الشاشات العريضة.
class SettingsTabBody extends StatelessWidget {
  const SettingsTabBody({super.key, required this.children, this.onRefresh});

  final List<Widget> children;

  /// سحب للتحديث على الهاتف.
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final wide = isWideLayout(context);
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(wide ? 32 : 16, 8, wide ? 32 : 16, 32),
      children: [
        ResponsiveCenter(
          maxWidth: 760,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 14),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
    if (onRefresh == null || wide) return list;
    return RefreshIndicator(color: AppColors.pomegranate, onRefresh: onRefresh!, child: list);
  }
}

/// عنوان بطاقة داخل الإعدادات.
class CardTitle extends StatelessWidget {
  const CardTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => SectionHeader(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink, height: 1.4),
        trailing: trailing,
      );
}

/// شارة الدور: المدير داكنة، والبقية بيج.
class RoleChip extends StatelessWidget {
  const RoleChip(this.role, {super.key, this.dense = true});

  final UserRole role;
  final bool dense;

  @override
  Widget build(BuildContext context) => role == UserRole.admin
      ? StatusChip(StatusKind.adminOnly, label: role.label, dense: dense)
      : StatusChip(StatusKind.role, label: role.label, dense: dense);
}

/// ملاحظة بأيقونة (قفل، درع...) على خلفية عاجية.
class IconNote extends StatelessWidget {
  const IconNote({
    super.key,
    required this.icon,
    required this.text,
    this.color = AppColors.inkSecondary,
    this.background = AppColors.ivory,
  });

  final IconData icon;
  final String text;
  final Color color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: background == null ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: background == null
          ? null
          : BoxDecoration(color: background, borderRadius: BorderRadius.circular(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 16, color: color)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, color: color, height: 1.5))),
        ],
      ),
    );
  }
}

/// «يتحقق الخادم من هذه الصلاحيات مع كل طلب».
class ServerEnforcedNote extends StatelessWidget {
  const ServerEnforcedNote({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.shield_outlined, size: 20, color: AppColors.leaf),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'يتحقق الخادم من هذه الصلاحيات مع كل طلب قراءة أو حفظ. إخفاء الأزرار في التطبيق للتوضيح فقط.',
              style: TextStyle(fontSize: 13, color: UiColors.label, height: 1.55),
            ),
          ),
        ],
      ),
    );
  }
}

/// قيمة للقراءة فقط بخط LTR (رابط، بريد) مع زر نسخ.
class CopyableValue extends StatelessWidget {
  const CopyableValue({super.key, required this.value, required this.copyTooltip, this.copiedMessage = 'تم النسخ.'});

  final String value;
  final String copyTooltip;
  final String copiedMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      padding: const EdgeInsetsDirectional.only(start: 12, end: 4, top: 2, bottom: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: UiColors.fieldBorder, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              value,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.left,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.ink, height: 1.4),
            ),
          ),
          IconButton(
            tooltip: copyTooltip,
            icon: const Icon(Icons.copy_outlined, size: 20, color: UiColors.label),
            style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (!context.mounted) return;
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(copiedMessage)));
            },
          ),
        ],
      ),
    );
  }
}

/// سطر «تسمية: قيمة» داخل بطاقة.
class KeyValueRow extends StatelessWidget {
  const KeyValueRow({super.key, required this.label, required this.value, this.first = false, this.ltr = false});

  final String label;
  final String value;
  final bool first;
  final bool ltr;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: first ? null : const BoxDecoration(border: Border(top: BorderSide(color: UiColors.divider))),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: UiText.label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              textDirection: ltr ? TextDirection.ltr : null,
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.ink, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
