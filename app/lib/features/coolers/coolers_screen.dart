import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../core/api/api_exception.dart';
import '../../core/format/numbers.dart';
import '../../core/models/dashboard.dart';
import '../../core/sync/data_changes.dart';
import '../../core/sync/outbox.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'cooler_format.dart';
import 'cooler_widgets.dart';

/// فلتر قائمة البرادات.
enum CoolerFilter {
  open('المفتوحة'),
  closed('المقفّلة'),
  all('الكل');

  const CoolerFilter(this.label);
  final String label;

  bool matches(CoolerSummary c) => switch (this) {
        CoolerFilter.open => c.isOpen,
        CoolerFilter.closed => !c.isOpen,
        CoolerFilter.all => true,
      };
}

/// قسم «البرادات وشراء الرمان»: قائمة البرادات (مفتوحة/مقفّلة) وإنشاء براد.
///
/// يُعرض داخل الواجهة الرئيسية (دون Scaffold): على الهاتف يأتي الشريط العلوي من HomeShell، وعلى الشاشات
/// العريضة يعرض القسم PageHeader بنفسه مثل لوحة التحكم.
///
/// تُقرأ كل البرادات مرة واحدة (coolers.list status: all) ويُفلتر محليًا، فتظهر الأعداد على التبويبات
/// ويكون التبديل بينها فوريًا.
class CoolersScreen extends StatefulWidget {
  const CoolersScreen({super.key});

  @override
  State<CoolersScreen> createState() => _CoolersScreenState();
}

class _CoolersScreenState extends State<CoolersScreen> {
  List<CoolerSummary>? _coolers;
  Object? _error;
  bool _loading = false;
  int _request = 0;

  /// null = لم يختر المستخدم بعد: «المفتوحة» إن وُجد براد مفتوح، وإلا «الكل».
  CoolerFilter? _filter;

  DataChanges? _changes;
  Outbox? _outbox;
  StreamSubscription<OutboxEntry>? _sentSub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = AppScope.of(context);
    if (!identical(_changes, scope.changes)) {
      _changes?.removeListener(_onChanged);
      _changes = scope.changes..addListener(_onChanged);
    }
    if (!identical(_outbox, scope.outbox)) {
      _outbox?.removeListener(_onOutbox);
      unawaited(_sentSub?.cancel());
      _outbox = scope.outbox..addListener(_onOutbox);
      _sentSub = scope.outbox.sent.listen((_) => _onChanged());
    }
    if (_coolers == null && !_loading && _error == null) unawaited(_load());
  }

  @override
  void dispose() {
    _changes?.removeListener(_onChanged);
    _outbox?.removeListener(_onOutbox);
    unawaited(_sentSub?.cancel());
    super.dispose();
  }

  void _onChanged() {
    if (mounted) unawaited(_load());
  }

  void _onOutbox() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final api = AppScope.of(context).api;
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await api.listCoolers(status: 'all');
      if (!mounted || request != _request) return;
      setState(() {
        _coolers = list;
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

  Future<void> _create() async {
    final cooler = await AppRoutes.createCooler(context);
    if (cooler == null || !mounted) return;
    setState(() => _filter = CoolerFilter.open);
    await AppRoutes.openCooler(context, cooler.id);
  }

  CoolerFilter _effectiveFilter(List<CoolerSummary> list) =>
      _filter ?? (list.any((c) => c.isOpen) ? CoolerFilter.open : CoolerFilter.all);

  // ------------------------------------------------------------------ البناء

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final perms = permissionsOf(scope.auth.user);
    final wide = isWideLayout(context);
    final list = _coolers;

    if (list == null) {
      if (_error != null) return ErrorView.fromError(_error!, onRetry: _load, title: 'تعذّر تحميل البرادات');
      return const LoadingSkeleton(tiles: 4, lines: 4);
    }

    final canCreate = perms.recordPurchases;
    if (list.isEmpty) {
      return _withHeader(
        wide,
        list,
        canCreate,
        Expanded(
          child: _scrollable(
            wide,
            EmptyState(
              icon: Icons.local_shipping_outlined,
              title: 'لا توجد برادات بعد',
              message: canCreate
                  ? 'أنشئ أول براد، ثم سجّل فيه مشتريات الرمان من المزارعين. يأخذ البراد رقمًا تلقائيًا ووقت فتح.'
                  : 'لم يُفتح أي براد بعد. ستظهر البرادات هنا عندما يبدأ الفريق التسجيل.',
              actionLabel: canCreate ? 'إنشاء براد' : null,
              actionIcon: Icons.add,
              onAction: canCreate ? _create : null,
            ),
          ),
        ),
      );
    }

    final filter = _effectiveFilter(list);
    final shown = list.where(filter.matches).toList();
    final outbox = scope.outbox;

    final cards = <Widget>[
      for (final c in shown)
        _CoolerCard(
          cooler: c,
          pending: outbox.pendingForCooler(c.id),
          onTap: () => AppRoutes.openCooler(context, c.id),
        ),
    ];

    final body = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: wide ? const EdgeInsets.fromLTRB(32, 8, 32, 40) : const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        ResponsiveCenter(
          maxWidth: wide ? 1400 : 720,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_refreshBanner() case final banner?) ...[banner, const SizedBox(height: 12)],
              if (shown.isEmpty)
                _FilterEmpty(filter: filter, onCreate: canCreate && filter != CoolerFilter.closed ? _create : null)
              else if (wide)
                ResponsiveGrid(minTileWidth: 400, maxColumns: 3, spacing: 16, children: cards)
              else
                for (var i = 0; i < cards.length; i++) ...[if (i > 0) const SizedBox(height: 12), cards[i]],
            ],
          ),
        ),
      ],
    );

    return _withHeader(wide, list, canCreate, Expanded(child: _scrollable(wide, body)));
  }

  /// الرأس (العنوان على الشاشات العريضة، والتبويبات وزر الإنشاء) ثم المحتوى.
  Widget _withHeader(bool wide, List<CoolerSummary> list, bool canCreate, Widget content) {
    final openCount = list.where((c) => c.isOpen).length;
    final closedCount = list.length - openCount;
    final filter = _effectiveFilter(list);
    final tabs = list.isEmpty
        ? null
        : PillTabs(
            labels: [
              '${CoolerFilter.open.label} ($openCount)',
              '${CoolerFilter.closed.label} ($closedCount)',
              '${CoolerFilter.all.label} (${list.length})',
            ],
            selected: filter.index,
            onSelected: (i) => setState(() => _filter = CoolerFilter.values[i]),
          );
    final createButton = canCreate && list.isNotEmpty
        ? AppButton(label: 'إنشاء براد', icon: Icons.add, height: 48, onPressed: _create, expand: !wide)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 3,
          child: _loading ? const LinearProgressIndicator(minHeight: 3, color: AppColors.pomegranate) : null,
        ),
        Padding(
          padding: wide ? const EdgeInsets.fromLTRB(32, 20, 32, 4) : const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: ResponsiveCenter(
            maxWidth: wide ? 1400 : 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (wide) ...[
                  PageHeader(
                    title: 'البرادات وشراء الرمان',
                    subtitle: list.isEmpty ? null : '$openCount مفتوحة · $closedCount مقفّلة',
                    actions: [
                      AppButton(
                        label: 'تحديث',
                        icon: Icons.refresh,
                        height: 48,
                        variant: AppButtonVariant.secondary,
                        busy: _loading,
                        busyLabel: 'جارٍ التحديث',
                        onPressed: _load,
                      ),
                      ?createButton,
                    ],
                  ),
                  if (tabs != null) ...[const SizedBox(height: 14), tabs],
                ] else ...[
                  ?tabs,
                  if (createButton != null) ...[const SizedBox(height: 8), createButton],
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        content,
      ],
    );
  }

  Widget _scrollable(bool wide, Widget child) {
    if (wide) return child;
    final scrollable = child is ScrollView
        ? child
        : LayoutBuilder(
            builder: (context, c) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(constraints: BoxConstraints(minHeight: c.maxHeight), child: child),
            ),
          );
    return RefreshIndicator(color: AppColors.pomegranate, onRefresh: _load, child: scrollable);
  }

  Widget? _refreshBanner() {
    final e = _error;
    if (e == null || _coolers == null) return null;
    return InlineBanner(
      kind: BannerKind.error,
      title: 'تعذّر تحديث البرادات',
      message: '${errorMessage(e)} المعروض الآن آخر بيانات وصلت.',
      actionLabel: e is ApiException && e.requiresLogin ? null : 'إعادة المحاولة',
      onAction: _load,
    );
  }
}

/// لا برادات في التبويب المختار.
class _FilterEmpty extends StatelessWidget {
  const _FilterEmpty({required this.filter, required this.onCreate});

  final CoolerFilter filter;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final (title, message) = switch (filter) {
      CoolerFilter.open => ('لا يوجد براد مفتوح الآن', 'افتح برادًا جديدًا لتسجيل مشتريات الرمان فيه.'),
      CoolerFilter.closed => ('لا توجد برادات مقفّلة بعد', 'تظهر هنا البرادات بعد تقفيلها وحفظ أرقامها.'),
      CoolerFilter.all => ('لا توجد برادات', ''),
    };
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: UiColors.beige, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.local_shipping_outlined, color: UiColors.label),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: UiText.cardTitle),
                    if (message.isNotEmpty) Text(message, style: UiText.muted),
                  ],
                ),
              ),
            ],
          ),
          if (onCreate != null) ...[
            const SizedBox(height: 14),
            AppButton(label: 'إنشاء براد', icon: Icons.add, onPressed: onCreate),
          ],
        ],
      ),
    );
  }
}

/// بطاقة براد في القائمة.
class _CoolerCard extends StatelessWidget {
  const _CoolerCard({required this.cooler, required this.pending, required this.onTap});

  final CoolerSummary cooler;
  final int pending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = cooler;
    final lines = [openedLine(c), closedLine(c), vehicleLine(c)].where((s) => s.isNotEmpty).toList();
    return AppCard(
      onTap: onTap,
      borderColor: c.isOpen ? UiColors.currentBorder : UiColors.cardBorder,
      borderWidth: c.isOpen ? 1.5 : 1,
      child: Semantics(
        button: true,
        label: 'فتح ${c.title}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.title,
                        style: const TextStyle(
                          fontFamily: AppFonts.display,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                      for (final l in lines) Text(l, style: UiText.small),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusChip(c.isOpen ? StatusKind.open : StatusKind.closed),
              ],
            ),
            const SizedBox(height: 12),
            CoolerStatsStrip(cooler: c),
            const SizedBox(height: 12),
            MoneyFigure(label: 'قيمة الرمان', piasters: c.valuePiasters, fontSize: 21),
            const SizedBox(height: 8),
            PaidProgressBar(paid: c.paidPiasters, total: c.valuePiasters),
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 4,
              children: [
                _amount('مدفوع', c.paidPiasters, AppColors.leaf),
                _amount('متبقي', c.remainingPiasters, AppColors.amber),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, thickness: 1, color: UiColors.divider),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: MoneyFigure(
                    label: 'تكلفة التعبئة المعتمدة',
                    piasters: c.packagingApprovedPiasters,
                    fontSize: 15,
                    note: c.packagingLatePiasters > 0
                        ? 'منها متأخرة\u00A0${formatMoney(c.packagingLatePiasters)}'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MoneyFigure(label: 'إجمالي تكلفة البراد', piasters: c.totalCostPiasters, fontSize: 15),
                ),
              ],
            ),
            if (pending > 0) ...[
              const SizedBox(height: 10),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: StatusChip(StatusKind.pending, label: pendingLabel(pending), dense: true),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _amount(String label, int piasters, Color color) => Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$label '),
            TextSpan(text: formatMoney(piasters), style: UiText.number(size: 14, color: color)),
          ],
        ),
        style: const TextStyle(fontSize: 13.5, color: AppColors.ink),
      );
}
