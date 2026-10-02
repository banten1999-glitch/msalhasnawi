import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/api/api_exception.dart';
import '../../core/models/dashboard.dart';
import '../../core/models/user.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../shell/placeholder_screen.dart';
import '../shell/shell_scope.dart';
import '../shell/shell_section.dart';
import 'dashboard_format.dart';
import 'dashboard_widgets.dart';

/// لوحة التحكم: تقرأ dashboard.get من الخادم وتعرض البراد الحالي وملخص الفترة والحساب المالي وآخر العمليات.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _period = 'season';

  /// '' = كل البرادات.
  String _coolerId = '';

  DashboardData? _data;
  Object? _error;
  bool _loading = false;
  int _request = 0;

  List<CoolerSummary> _coolers = const [];
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    unawaited(_load());
    unawaited(_loadCoolers());
  }

  Future<void> _load() async {
    final api = AppScope.of(context).api;
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await api.dashboard(period: _period, coolerId: _coolerId.isEmpty ? null : _coolerId);
      if (!mounted || request != _request) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  /// قائمة البرادات لفلتر «البراد». فشلها لا يمنع عرض اللوحة: يبقى خيار «الكل» فقط.
  Future<void> _loadCoolers() async {
    final api = AppScope.of(context).api;
    try {
      final data = await api.call('coolers.list', payload: const {'status': 'all'});
      final list = [
        for (final c in (data['coolers'] as List?) ?? const [])
          if (c is Map) CoolerSummary.fromJson(c.cast<String, dynamic>()),
      ];
      if (mounted) setState(() => _coolers = list);
    } catch (_) {
      // يُعاد التحميل مع التحديث التالي.
    }
  }

  Future<void> _refresh() async {
    unawaited(_loadCoolers());
    await _load();
  }

  void _setPeriod(String p) {
    setState(() => _period = p);
    unawaited(_load());
  }

  void _setCooler(String id) {
    setState(() => _coolerId = id);
    unawaited(_load());
  }

  void _placeholder(String title, IconData icon) => unawaited(openPlaceholderPage(context, title: title, icon: icon));

  // ------------------------------------------------------------------ الإجراءات حسب الصلاحيات

  List<DashboardAction> _actions(UserPermissions p) => [
        if (p.recordPurchases)
          DashboardAction('شراء من مزارع', Icons.scale_outlined, ActionTone.pomegranate,
              () => _placeholder('شراء من مزارع', Icons.scale_outlined),
              wideLabel: 'إضافة شراء من مزارع'),
        if (p.recordPurchases)
          DashboardAction('إنشاء براد', Icons.local_shipping_outlined, ActionTone.pomegranate,
              () => _placeholder('إنشاء براد', Icons.local_shipping_outlined)),
        if (p.packaging)
          DashboardAction('مشتريات تعبئة', Icons.inventory_2_outlined, ActionTone.leaf,
              () => _placeholder('مشتريات التعبئة والتغليف', Icons.inventory_2_outlined),
              wideLabel: 'إضافة مشتريات تعبئة'),
        if (p.recordPayments)
          DashboardAction('تسجيل دفعة', Icons.payments_outlined, ActionTone.leaf,
              () => _placeholder('تسجيل دفعة', Icons.payments_outlined)),
        // التقرير قراءة فقط، فيظهر لكل من يرى البيانات (ومنهم «مشاهدة فقط»).
        if (p.viewData)
          DashboardAction('تقرير البراد', Icons.assessment_outlined, ActionTone.neutral,
              () => _placeholder('تقرير البراد', Icons.assessment_outlined),
              wideLabel: 'عرض تقرير البراد'),
      ];

  /// على الهاتف يأتي «إنشاء براد» أولًا كما في التصميم؛ وعلى الشاشات العريضة يأتي الشراء أولًا كزر رئيسي.
  List<DashboardAction> _phoneOrder(List<DashboardAction> a) {
    final list = [...a];
    final create = list.indexWhere((x) => x.label == 'إنشاء براد');
    if (create > 0) list.insert(0, list.removeAt(create));
    return list;
  }

  // ------------------------------------------------------------------ البناء

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final user = scope.auth.user;
    final perms = user?.permissions ?? const UserPermissions(viewData: true);
    final wide = isWideLayout(context);
    final data = _data;

    if (data == null) {
      if (_error != null) return _errorView(_error!, perms);
      return const LoadingSkeleton(tiles: 6);
    }

    final noCoolersAtAll = data.kpis.openCoolers + data.kpis.closedCoolers == 0;
    if (data.empty && noCoolersAtAll && _coolerId.isEmpty) {
      return _onboarding(perms, wide);
    }

    final children = wide ? _wideChildren(data, perms) : _phoneChildren(data, perms);
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: wide ? const EdgeInsets.fromLTRB(32, 24, 32, 40) : const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        ResponsiveCenter(
          maxWidth: wide ? 1400 : 720,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 3,
          child: _loading ? const LinearProgressIndicator(minHeight: 3, color: AppColors.pomegranate) : null,
        ),
        Expanded(
          child: wide
              ? list
              : RefreshIndicator(color: AppColors.pomegranate, onRefresh: _refresh, child: list),
        ),
      ],
    );
  }

  Widget _errorView(Object error, UserPermissions perms) {
    final shell = ShellScope.maybeOf(context);
    final canOpenSettings = perms.manageSettings && (shell?.canOpen(ShellSection.settings) ?? false);
    return ErrorView.fromError(
      error,
      onRetry: _refresh,
      onOpenSheetSettings: canOpenSettings ? () => shell!.select(ShellSection.settings) : null,
    );
  }

  Widget _onboarding(UserPermissions perms, bool wide) {
    final create = perms.recordPurchases ? () => _placeholder('إنشاء براد', Icons.local_shipping_outlined) : null;
    final body = DashboardOnboarding(onCreateCooler: create);
    if (wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
            child: PageHeader(title: 'لوحة التحكم', actions: [_refreshButton()]),
          ),
          Expanded(child: body),
        ],
      );
    }
    return RefreshIndicator(
      color: AppColors.pomegranate,
      onRefresh: _refresh,
      child: LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(constraints: BoxConstraints(minHeight: c.maxHeight), child: body),
        ),
      ),
    );
  }

  Widget _refreshButton() => AppButton(
        label: 'تحديث',
        icon: Icons.refresh,
        height: 48,
        variant: AppButtonVariant.secondary,
        busy: _loading,
        busyLabel: 'جارٍ التحديث',
        onPressed: _refresh,
      );

  Widget _filters() {
    final coolerOptions = <(String, String)>[
      ('', 'الكل'),
      for (final c in _coolers) (c.id, c.isOpen ? '${c.title} (مفتوح)' : c.title),
    ];
    final selectedCooler = _coolers.where((c) => c.id == _coolerId).firstOrNull;
    final coolerLabel = _coolerId.isEmpty
        ? 'الكل'
        : (selectedCooler != null ? 'براد ${selectedCooler.no}' : (_data?.currentCooler?.title ?? 'براد محدد'));
    if (_coolerId.isNotEmpty && selectedCooler == null) {
      coolerOptions.add((_coolerId, coolerLabel));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        DashboardFilterButton(
          icon: Icons.calendar_month_outlined,
          label: 'الفترة: ${periodLabel(_period)}',
          tooltip: 'اختيار الفترة',
          options: dashboardPeriods,
          selected: _period,
          onSelected: _setPeriod,
        ),
        DashboardFilterButton(
          icon: Icons.local_shipping_outlined,
          label: 'البراد: $coolerLabel',
          tooltip: 'اختيار البراد',
          options: coolerOptions,
          selected: _coolerId,
          onSelected: _setCooler,
        ),
      ],
    );
  }

  Widget? _refreshError() {
    final e = _error;
    if (e == null || _data == null) return null;
    return InlineBanner(
      kind: BannerKind.error,
      title: 'تعذّر تحديث البيانات',
      message: '${errorMessage(e)} المعروض الآن آخر بيانات وصلت.',
      actionLabel: e is ApiException && e.requiresLogin ? null : 'إعادة المحاولة',
      onAction: _refresh,
    );
  }

  Widget _coolerSection(DashboardData data, UserPermissions perms, {required bool wide}) {
    final c = data.currentCooler;
    if (c == null) {
      return NoOpenCoolerCard(
        onCreate: perms.recordPurchases ? () => _placeholder('إنشاء براد', Icons.local_shipping_outlined) : null,
      );
    }
    final others = data.openCoolers.where((o) => o.id != c.id && o.isOpen).toList();
    return CurrentCoolerCard(
      cooler: c,
      others: wide ? const [] : others,
      filtered: _coolerId.isNotEmpty,
      wide: wide,
      onAddPurchase: perms.recordPurchases && c.isOpen
          ? () => _placeholder('إضافة شراء · ${c.title}', Icons.scale_outlined)
          : null,
      onOpenCooler: () => _placeholder(c.title, Icons.local_shipping_outlined),
      onSwitch: (o) => _setCooler(o.id),
    );
  }

  String _summaryTitle(DashboardData data) {
    final c = data.currentCooler;
    if (_coolerId.isNotEmpty && c != null) return '${periodSummaryTitle(_period)} · براد ${c.no}';
    return periodSummaryTitle(_period);
  }

  List<Widget> _phoneChildren(DashboardData data, UserPermissions perms) {
    final actions = _phoneOrder(_actions(perms));
    final banner = _refreshError();
    const gap = SizedBox(height: 18);
    return [
      _filters(),
      if (banner != null) ...[const SizedBox(height: 12), banner],
      const SizedBox(height: 14),
      _coolerSection(data, perms, wide: false),
      if (actions.isNotEmpty) ...[gap, QuickActionsGrid(actions: actions)],
      gap,
      SectionHeader(_summaryTitle(data), trailing: Text(periodRangeText(data.period), style: UiText.small)),
      const SizedBox(height: 10),
      ResponsiveGrid(minTileWidth: 150, maxColumns: 3, minColumns: 2, children: seasonKpiTiles(data.kpis)),
      gap,
      MoneyCard(kpis: data.kpis),
      gap,
      RecentOperationsCard(items: data.recent),
    ];
  }

  List<Widget> _wideChildren(DashboardData data, UserPermissions perms) {
    final actions = _actions(perms);
    final banner = _refreshError();
    final openCoolers = data.openCoolers.where((o) => o.isOpen).toList();
    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _coolerSection(data, perms, wide: true),
        if (openCoolers.length > 1) ...[
          const SizedBox(height: 20),
          OpenCoolersCard(
            coolers: openCoolers,
            currentId: data.currentCooler?.id,
            onSelect: (o) => _setCooler(o.id),
          ),
        ],
      ],
    );
    final right = RecentOperationsTable(items: data.recent);
    return [
      PageHeader(
        title: 'لوحة التحكم',
        subtitle: '${periodLabel(_period)} · ${periodRangeText(data.period)}',
        actions: [_filters(), _refreshButton()],
      ),
      if (banner != null) ...[const SizedBox(height: 14), banner],
      if (actions.isNotEmpty) ...[const SizedBox(height: 20), QuickActionsBar(actions: actions)],
      const SizedBox(height: 22),
      SectionHeader(_summaryTitle(data), style: UiText.cardTitle),
      const SizedBox(height: 10),
      ResponsiveGrid(
        minTileWidth: 190,
        maxColumns: 6,
        spacing: 14,
        children: [...seasonKpiTiles(data.kpis), ...moneyKpiTiles(data.kpis)],
      ),
      const SizedBox(height: 22),
      LayoutBuilder(builder: (context, c) {
        if (c.maxWidth < 900) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, const SizedBox(height: 20), right],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: left),
            const SizedBox(width: 20),
            Expanded(flex: 8, child: right),
          ],
        );
      }),
    ];
  }
}
