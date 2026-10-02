import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/models/user.dart';
import '../../ui/ui.dart';
import 'business_settings_tab.dart';
import 'sheets_tab.dart';
import 'users_tab.dart';

/// تبويبات الإعدادات. تظهر حسب الصلاحيات، والخادم يتحقق منها مع كل طلب.
enum SettingsTab {
  sheets('Google Sheets'),
  users('المستخدمون'),
  business('إعدادات العمل');

  const SettingsTab(this.label);
  final String label;

  bool isVisibleFor(UserPermissions p) => switch (this) {
        SettingsTab.sheets => p.manageSettings,
        SettingsTab.users => p.manageUsers,
        SettingsTab.business => p.manageSettings || p.manageUsers,
      };
}

/// إعدادات المدير: ربط Google Sheets، المستخدمون والصلاحيات، وإعدادات العمل (للعرض).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.initialTab});

  final SettingsTab? initialTab;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SettingsTab? _selected;

  /// التبويبات التي فُتحت، تبقى في الذاكرة حتى لا يُعاد تحميلها عند التنقل بينها.
  final _visited = <SettingsTab>{};

  @override
  Widget build(BuildContext context) {
    final perms = AppScope.of(context).auth.user?.permissions ?? const UserPermissions(viewData: false);
    final tabs = [for (final t in SettingsTab.values) if (t.isVisibleFor(perms)) t];
    final wide = isWideLayout(context);

    if (tabs.isEmpty) {
      return const ErrorView(
        title: 'لا تملك صلاحية الإعدادات',
        message: 'هذه الصفحة للمدير فقط. اطلب من المدير منحك الصلاحية إن كنت تحتاجها.',
      );
    }

    final selected = tabs.contains(_selected) ? _selected! : (tabs.contains(widget.initialTab) ? widget.initialTab! : tabs.first);
    _visited.add(selected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(wide ? 32 : 16, wide ? 24 : 0, wide ? 32 : 16, 4),
          child: ResponsiveCenter(
            maxWidth: 760,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (wide) ...[
                  const PageHeader(title: 'الإعدادات', actions: [StatusChip(StatusKind.adminOnly)]),
                  const SizedBox(height: 12),
                ],
                PillTabs(
                  labels: [for (final t in tabs) t.label],
                  selected: tabs.indexOf(selected),
                  onSelected: (i) => setState(() => _selected = tabs[i]),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: tabs.indexOf(selected),
            children: [
              for (final t in tabs)
                _visited.contains(t) ? KeyedSubtree(key: ValueKey(t), child: _tabBody(t)) : const SizedBox.shrink(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tabBody(SettingsTab t) => switch (t) {
        SettingsTab.sheets => const SheetsTab(),
        SettingsTab.users => const UsersTab(),
        SettingsTab.business => const BusinessSettingsTab(),
      };
}
