import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/models/user.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../dashboard/dashboard_screen.dart';
import '../settings/settings_screen.dart';
import 'navigation_panel.dart';
import 'placeholder_screen.dart';
import 'shell_scope.dart';
import 'shell_section.dart';

/// الواجهة الرئيسية بعد الدخول: قائمة منزلقة على الهاتف والجهاز اللوحي، ومثبتة على الشاشات العريضة.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  ShellSection _section = ShellSection.dashboard;

  void _select(ShellSection s) {
    if (s == _section) return;
    setState(() => _section = s);
  }

  void _selectFromDrawer(ShellSection s) {
    _scaffoldKey.currentState?.closeDrawer();
    _select(s);
  }

  Future<void> _confirmLogout(AuthController auth) async {
    _scaffoldKey.currentState?.closeDrawer();
    final ok = await showConfirmDialog(
      context,
      title: 'تسجيل الخروج؟',
      message: 'ستُحذف الجلسة من هذا الجهاز، وتحتاج إلى الدخول بحساب Google مرة أخرى لفتح التطبيق.',
      confirmLabel: 'تسجيل الخروج',
      destructive: true,
      icon: Icons.logout,
      mirrorIcon: true,
    );
    if (ok) await auth.signOut();
  }

  ConnectionNote _connection(AuthController auth) {
    if (auth.isDemo) return ConnectionNote.demo;
    if (auth.offline) return ConnectionNote.offline;
    return ConnectionNote.online;
  }

  @override
  Widget build(BuildContext context) {
    final auth = AppScope.of(context).auth;
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        final user = auth.user;
        final sections = ShellSection.visibleFor(user);
        // إن سُحبت صلاحية الإعدادات أثناء فتحها نعود إلى لوحة التحكم.
        final section = sections.contains(_section) ? _section : ShellSection.dashboard;
        final wide = MediaQuery.sizeOf(context).width >= kWideBreakpoint;

        final content = ShellScope(
          section: section,
          visibleSections: sections,
          onSelect: _select,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (auth.offline)
                const InlineBanner(
                  kind: BannerKind.offline,
                  dense: true,
                  message: 'لا يوجد اتصال — تعرض آخر بيانات محفوظة',
                ),
              Expanded(child: KeyedSubtree(key: ValueKey(section), child: _body(section))),
            ],
          ),
        );

        final panel = NavigationPanel(
          user: user,
          sections: sections,
          selected: section,
          onSelect: wide ? _select : _selectFromDrawer,
          onLogout: () => _confirmLogout(auth),
          connection: _connection(auth),
          pinned: wide,
          onClose: wide ? null : () => _scaffoldKey.currentState?.closeDrawer(),
        );

        if (wide) {
          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: AppColors.ivory,
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 272,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: BorderDirectional(end: BorderSide(color: UiColors.cardBorder)),
                  ),
                  child: panel,
                ),
                Expanded(child: content),
              ],
            ),
          );
        }

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: AppColors.ivory,
          appBar: AppBar(
            backgroundColor: AppColors.ivory,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            toolbarHeight: 64,
            titleSpacing: 4,
            leading: IconButton(
              tooltip: 'فتح القائمة',
              icon: const Icon(Icons.menu),
              style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            title: Text(section.label, style: UiText.pageTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              if (section == ShellSection.settings)
                const Padding(
                  padding: EdgeInsetsDirectional.only(end: 4),
                  child: StatusChip(StatusKind.adminOnly),
                ),
              if (user != null) _AccountButton(user: user, onLogout: () => _confirmLogout(auth)),
              const SizedBox(width: 4),
            ],
          ),
          drawer: Drawer(
            width: 316,
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadiusDirectional.horizontal(end: Radius.circular(24)),
            ),
            child: panel,
          ),
          body: content,
        );
      },
    );
  }

  Widget _body(ShellSection section) => switch (section) {
        ShellSection.dashboard => const DashboardScreen(),
        ShellSection.settings => const SettingsScreen(),
        _ => SectionPlaceholder(
            title: section.label,
            icon: section.icon,
            onBack: () => _select(ShellSection.dashboard),
          ),
      };
}

/// صورة الحساب في الشريط العلوي: الاسم والبريد والدور، وتسجيل الخروج.
class _AccountButton extends StatelessWidget {
  const _AccountButton({required this.user, required this.onLogout});

  final AppUser user;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'الحساب',
      position: PopupMenuPosition.under,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (v) {
        if (v == 'logout') onLogout();
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.name, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
              Text(user.email, textDirection: TextDirection.ltr, style: UiText.small),
              Text(roleDescription(user), style: UiText.small),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          height: 48,
          child: Row(
            children: [
              DirectionalIcon(Icons.logout, color: AppColors.error, size: 20),
              SizedBox(width: 10),
              Text('تسجيل الخروج', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(child: InitialsAvatar(user.initials, size: 36)),
      ),
    );
  }
}
