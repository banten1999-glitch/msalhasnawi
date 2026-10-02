import 'package:flutter/material.dart';

import '../../brand/animated_logo.dart';
import '../../core/models/user.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'shell_section.dart';

/// حالة الاتصال التي تظهر أسفل القائمة.
enum ConnectionNote { online, offline, demo }

/// محتوى القائمة: الشعار، المستخدم، الأقسام، الخروج، ثم ملاحظة الاتصال.
/// يُستخدم داخل القائمة المنزلقة على الهاتف، ومثبتًا على جانب الشاشة العريضة.
class NavigationPanel extends StatelessWidget {
  const NavigationPanel({
    super.key,
    required this.user,
    required this.sections,
    required this.selected,
    required this.onSelect,
    required this.onLogout,
    required this.connection,
    this.onClose,
    this.pinned = false,
  });

  final AppUser? user;
  final List<ShellSection> sections;
  final ShellSection selected;
  final ValueChanged<ShellSection> onSelect;
  final VoidCallback onLogout;
  final ConnectionNote connection;

  /// زر الإغلاق (للقائمة المنزلقة فقط).
  final VoidCallback? onClose;

  /// مثبتة على جانب الشاشة العريضة.
  final bool pinned;

  @override
  Widget build(BuildContext context) {
    final itemHeight = pinned ? 48.0 : 52.0;
    return SafeArea(
      child: LayoutBuilder(builder: (context, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(12, pinned ? 20 : 18, 12, 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - (pinned ? 36 : 34)),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _brandRow(),
                  if (user != null && !pinned) ...[_userCard(user!), const SizedBox(height: 10)],
                  Semantics(
                    container: true,
                    label: 'القائمة الرئيسية',
                    explicitChildNodes: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final s in sections)
                          _NavItem(
                            label: s.label,
                            icon: s.icon,
                            selected: s == selected,
                            height: itemHeight,
                            onTap: () => onSelect(s),
                          ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          child: Divider(height: 1, thickness: 1, color: UiColors.divider),
                        ),
                        _NavItem(
                          label: 'تسجيل الخروج',
                          icon: Icons.logout,
                          selected: false,
                          height: itemHeight,
                          color: AppColors.error,
                          mirrorIcon: true,
                          onTap: onLogout,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(height: 16),
                  _ConnectionCard(connection: connection),
                  if (user != null && pinned) ...[const SizedBox(height: 10), _userRow(user!)],
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _brandRow() {
    return Padding(
      padding: EdgeInsets.fromLTRB(6, 0, 6, pinned ? 16 : 14),
      child: Row(
        children: [
          AppLogo(size: pinned ? 40 : 44),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'حاسبة الرمان',
              style: TextStyle(
                fontFamily: AppFonts.display,
                fontSize: pinned ? 19 : 20,
                fontWeight: FontWeight.w700,
                color: AppColors.pomegranate,
                height: 1.3,
              ),
            ),
          ),
          if (onClose != null)
            IconButton(
              tooltip: 'إغلاق القائمة',
              onPressed: onClose,
              icon: const Icon(Icons.close, color: AppColors.inkSecondary),
              style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
            ),
        ],
      ),
    );
  }

  Widget _userCard(AppUser u) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.ivory, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          InitialsAvatar(u.initials, size: 40),
          const SizedBox(width: 10),
          Expanded(child: _nameAndRole(u)),
        ],
      ),
    );
  }

  Widget _userRow(AppUser u) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        children: [
          InitialsAvatar(u.initials, size: 36),
          const SizedBox(width: 10),
          Expanded(child: _nameAndRole(u)),
        ],
      ),
    );
  }

  Widget _nameAndRole(AppUser u) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            u.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, height: 1.4),
          ),
          Text(roleDescription(u), style: UiText.small),
        ],
      );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.height,
    required this.onTap,
    this.color,
    this.mirrorIcon = false,
  });

  final String label;
  final IconData icon;
  final bool mirrorIcon;
  final bool selected;
  final double height;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? (selected ? AppColors.pomegranate : AppColors.ink);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.pomegranateLight : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: height),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                children: [
                  if (mirrorIcon) DirectionalIcon(icon, size: 22, color: fg) else Icon(icon, size: 22, color: fg),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                        color: fg,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.connection});

  final ConnectionNote connection;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, IconData icon, String title, String body) = switch (connection) {
      ConnectionNote.online => (
          UiColors.paidBg,
          AppColors.leaf,
          Icons.cloud_done_outlined,
          'متصل بالملف المركزي',
          'كل عملية تُحفظ مباشرة في ملف Google Sheets عبر الخادم.',
        ),
      ConnectionNote.offline => (
          AppColors.amberLight,
          AppColors.amber,
          Icons.cloud_off_outlined,
          'لا يوجد اتصال',
          'تعرض آخر بيانات محفوظة. الحفظ يحتاج اتصالًا بالإنترنت.',
        ),
      ConnectionNote.demo => (
          AppColors.infoLight,
          AppColors.info,
          Icons.science_outlined,
          'وضع تجريبي',
          'بيانات تجريبية في ذاكرة الجهاز، ولا يُكتب شيء في ملف Google Sheets.',
        ),
    };
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 20, color: fg)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: fg, fontSize: 13, height: 1.5)),
                  Text(body, style: const TextStyle(fontSize: 12.5, color: AppColors.inkMuted, height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
