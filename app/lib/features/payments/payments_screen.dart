import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../core/format/numbers.dart';
import '../../core/models/records.dart';
import '../../core/models/user.dart';
import '../../core/sync/data_changes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../farmers/filter_menu_button.dart';
import '../farmers/text_search.dart';
import '../shell/shell_scope.dart';
import '../shell/shell_section.dart';
import 'cancel_payment_dialog.dart';
import 'payments_logic.dart';

enum _Tab {
  payments('الدفعات'),
  dues('المستحقات');

  const _Tab(this.label);
  final String label;
}

/// فلتر نوع المستفيد (null لا يصلح قيمة في PopupMenuButton).
enum _PayeeFilter {
  all('الكل', null),
  farmers('مزارعون', PayeeType.farmer),
  suppliers('موردون', PayeeType.supplier);

  const _PayeeFilter(this.label, this.type);
  final String label;
  final PayeeType? type;
}

typedef _Notice = ({BannerKind kind, String message});

/// عدد الدفعات المعروضة في كل صفحة من القائمة.
const _pageSize = 100;

/// «دفعة واحدة»، «دفعتان»، «3 دفعات»، «11 دفعة».
String _paymentsCount(int n) {
  if (n == 0) return 'لا دفعات';
  if (n == 1) return 'دفعة واحدة';
  if (n == 2) return 'دفعتان';
  final mod = n % 100;
  if (mod >= 3 && mod <= 10) return '${formatCount(n)} دفعات';
  return '${formatCount(n)} دفعة';
}

/// قسم «المدفوعات»: كل الدفعات مع الفلاتر، والمستحقات المتبقية للمزارعين والموردين.
///
/// يُعرض داخل الواجهة الرئيسية (دون Scaffold): على الهاتف يأتي الشريط العلوي من HomeShell، وعلى الشاشات
/// العريضة يعرض القسم PageHeader بنفسه مثل لوحة التحكم.
class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  _Tab _tab = _Tab.payments;

  List<Payment>? _payments;
  PaymentsSummary _summary = PaymentsSummary.from(payments: const [], purchases: const [], packaging: const []);
  List<PayeeDues> _dues = const [];
  Object? _error;
  bool _loading = false;
  int _request = 0;
  bool _started = false;
  DataChanges? _changes;
  _Notice? _notice;

  // ------------------------------------------------------------------ فلاتر «الدفعات»
  final _search = TextEditingController();
  String _query = '';
  _PayeeFilter _payee = _PayeeFilter.all;

  /// '' = كل البرادات، [noCoolerFilter] = دون براد.
  String _cooler = '';
  PaymentStatusFilter _status = PaymentStatusFilter.all;
  int _limit = _pageSize;

  // ------------------------------------------------------------------ فلاتر «المستحقات»
  final _duesSearch = TextEditingController();
  String _duesQuery = '';
  _PayeeFilter _duesPayee = _PayeeFilter.all;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final changes = AppScope.of(context).changes;
    if (!identical(changes, _changes)) {
      _changes?.removeListener(_onDataChanged);
      _changes = changes..addListener(_onDataChanged);
    }
    if (_started) return;
    _started = true;
    unawaited(_load());
  }

  @override
  void dispose() {
    _changes?.removeListener(_onDataChanged);
    _search.dispose();
    _duesSearch.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) unawaited(_load());
  }

  /// الدفعات + المشتريات + التعبئة المعتمدة معًا (المستحقات والمؤشرات تُحسب منها مرة واحدة).
  Future<void> _load() async {
    final api = AppScope.of(context).api;
    final request = ++_request;
    setState(() => _loading = true);
    final paymentsF = settle(api.listPayments());
    final purchasesF = settle(api.listPurchases());
    final packagingF = settle(api.listPackaging(status: 'approved'));
    final (payments, e1) = await paymentsF;
    final (purchases, e2) = await purchasesF;
    final (packaging, e3) = await packagingF;
    if (!mounted || request != _request) return;
    final error = e1 ?? e2 ?? e3;
    setState(() {
      _loading = false;
      if (error != null) {
        if (_payments == null) {
          _error = error;
        } else {
          _notice = (
            kind: BannerKind.error,
            message: 'تعذّر تحديث البيانات: ${errorMessage(error)} المعروض الآن آخر بيانات وصلت.',
          );
        }
        return;
      }
      _error = null;
      _payments = payments;
      _summary = PaymentsSummary.from(payments: payments!, purchases: purchases!, packaging: packaging!);
      _dues = groupDues(purchases: purchases, packaging: packaging);
    });
  }

  // ------------------------------------------------------------------ الإجراءات

  void _record({PayableOperation? target}) => unawaited(
        AppRoutes.recordPayment(context, targetType: target?.targetType, targetId: target?.targetId),
      );

  Future<void> _cancel(Payment p) async {
    final result = await showCancelPaymentDialog(context, p);
    if (result == null || !mounted) return;
    setState(() {
      _payments = [for (final x in _payments ?? const <Payment>[]) x.id == result.payment.id ? result.payment : x];
      _notice = (
        kind: BannerKind.success,
        message: 'أُلغيت الدفعة ${p.no}، وعاد مبلغها ${formatMoney(p.amountPiasters)} ج.م إلى المتبقي.',
      );
    });
  }

  void _resetFilters() => setState(() {
        _search.clear();
        _query = '';
        _payee = _PayeeFilter.all;
        _cooler = '';
        _status = PaymentStatusFilter.all;
        _limit = _pageSize;
      });

  // ------------------------------------------------------------------ البناء

  @override
  Widget build(BuildContext context) {
    final perms = AppScope.of(context).auth.user?.permissions ?? const UserPermissions();
    final canRecord = perms.recordPayments;
    final wide = isWideLayout(context);
    final payments = _payments;

    if (payments == null) {
      if (_error != null) return _errorView(_error!, perms);
      return const LoadingSkeleton(tiles: 3, lines: 6, showHeaderCard: false);
    }

    final header = <Widget>[
      if (wide) ...[_pageHeader(canRecord), const SizedBox(height: 16)],
      _kpis(wide),
      const SizedBox(height: 16),
      _tabsRow(wide, canRecord),
      const SizedBox(height: 12),
      ...(_tab == _Tab.payments ? _paymentFilters(payments, wide) : _duesFilters(wide)),
      if (_notice != null) ...[
        const SizedBox(height: 12),
        InlineBanner(kind: _notice!.kind, message: _notice!.message),
      ],
      const SizedBox(height: 12),
    ];

    final List<Widget> items;
    if (_tab == _Tab.payments) {
      final filtered = [
        for (final p in payments)
          if (paymentMatches(p, payee: _payee.type, cooler: _cooler, status: _status, query: _query)) p,
      ];
      final shown = filtered.take(_limit).toList();
      header.add(_paymentsCountLine(filtered));
      header.add(const SizedBox(height: 10));
      items = [
        if (payments.isEmpty)
          _EmptyCard(
            title: 'لا توجد دفعات بعد',
            message: canRecord
                ? 'سجّل أول دفعة من زر «تسجيل دفعة»، أو مع عملية الشراء نفسها.'
                : 'لم تُسجَّل أي دفعة بعد.',
          )
        else if (filtered.isEmpty)
          _EmptyCard(
            title: 'لا توجد دفعات تطابق الفلاتر',
            message: 'غيّر البحث أو الفلاتر لعرض دفعات أخرى.',
            actionLabel: 'مسح الفلاتر',
            onAction: _resetFilters,
          )
        else if (wide)
          _PaymentsTable(payments: shown, canCancel: canRecord, onCancel: _cancel)
        else
          for (final p in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PaymentTile(payment: p, onCancel: canRecord && p.active ? () => _cancel(p) : null),
            ),
        if (filtered.length > shown.length)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: AppButton(
              label: 'عرض المزيد (${formatCount(filtered.length - shown.length)} أخرى)',
              icon: Icons.expand_more,
              variant: AppButtonVariant.secondary,
              onPressed: () => setState(() => _limit += _pageSize),
            ),
          ),
      ];
    } else {
      final groups = [
        for (final g in _dues)
          if ((_duesPayee.type == null || g.payeeType == _duesPayee.type) &&
              matchesAllWords([g.payeeName, for (final o in g.operations) '${o.title} ${o.details}'], _duesQuery))
            g,
      ];
      items = [
        if (_dues.isEmpty)
          const _EmptyCard(
            title: 'لا توجد مستحقات',
            message: 'كل عمليات شراء الرمان ومشتريات التعبئة المعتمدة مدفوعة بالكامل.',
          )
        else if (groups.isEmpty)
          const _EmptyCard(title: 'لا توجد مستحقات تطابق البحث', message: 'غيّر البحث أو نوع المستفيد.')
        else
          for (final g in groups)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DuesGroup(dues: g, wide: wide, onRecord: canRecord ? (o) => _record(target: o) : null),
            ),
      ];
    }

    final all = [...header, ...items];
    final list = ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: wide ? const EdgeInsets.fromLTRB(32, 24, 32, 40) : const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: all.length,
      itemBuilder: (context, i) => ResponsiveCenter(maxWidth: wide ? 1400 : 720, child: all[i]),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 3,
          child: _loading ? const LinearProgressIndicator(minHeight: 3, color: AppColors.pomegranate) : null,
        ),
        Expanded(
          child: wide ? list : RefreshIndicator(color: AppColors.pomegranate, onRefresh: _load, child: list),
        ),
      ],
    );
  }

  Widget _errorView(Object error, UserPermissions perms) {
    final shell = ShellScope.maybeOf(context);
    final canOpenSettings = perms.manageSettings && (shell?.canOpen(ShellSection.settings) ?? false);
    return ErrorView.fromError(
      error,
      title: 'تعذّر تحميل المدفوعات',
      onRetry: _load,
      onOpenSheetSettings: canOpenSettings ? () => shell!.select(ShellSection.settings) : null,
    );
  }

  Widget _addButton({double height = 48}) => AppButton(
        label: 'تسجيل دفعة',
        icon: Icons.add_card_outlined,
        height: height,
        onPressed: () => _record(),
      );

  Widget _pageHeader(bool canRecord) => PageHeader(
        title: 'المدفوعات',
        subtitle: 'كل الدفعات للمزارعين والموردين، والمبالغ المتبقية لهم.',
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
          if (canRecord) _addButton(),
        ],
      );

  Widget _kpis(bool wide) {
    final s = _summary;
    final paid = KpiTile(
      label: 'إجمالي المدفوع',
      value: formatMoney(s.paidPiasters),
      unit: kCurrencySymbol,
      accent: KpiAccent.paid,
      note: 'الدفعات الفعّالة فقط · ${_paymentsCount(s.activeCount)}',
      valueSize: wide ? 22 : 20,
    );
    final farmers = KpiTile(
      label: 'متبقي للمزارعين',
      value: formatMoney(s.remainingFarmersPiasters),
      unit: kCurrencySymbol,
      accent: KpiAccent.remaining,
      valueSize: wide ? 22 : 17,
    );
    final suppliers = KpiTile(
      label: 'متبقي للموردين',
      value: formatMoney(s.remainingSuppliersPiasters),
      unit: kCurrencySymbol,
      accent: KpiAccent.remaining,
      note: wide ? 'مشتريات التعبئة المعتمدة' : null,
      valueSize: wide ? 22 : 17,
    );
    if (wide) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: paid),
            const SizedBox(width: 14),
            Expanded(child: farmers),
            const SizedBox(width: 14),
            Expanded(child: suppliers),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        paid,
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Expanded(child: farmers), const SizedBox(width: 10), Expanded(child: suppliers)],
          ),
        ),
      ],
    );
  }

  Widget _tabsRow(bool wide, bool canRecord) {
    final tabs = PillTabs(
      labels: [for (final t in _Tab.values) t.label],
      selected: _tab.index,
      onSelected: (i) => setState(() => _tab = _Tab.values[i]),
    );
    if (wide || !canRecord) return Align(alignment: AlignmentDirectional.centerStart, child: tabs);
    return Row(children: [Expanded(child: tabs), const SizedBox(width: 8), _addButton()]);
  }

  List<Widget> _paymentFilters(List<Payment> payments, bool wide) {
    final coolers = <String, int?>{};
    var withoutCooler = false;
    for (final p in payments) {
      if (p.coolerId == null) {
        withoutCooler = true;
      } else {
        coolers[p.coolerId!] = p.coolerNo;
      }
    }
    final coolerIds = coolers.keys.toList()..sort((a, b) => (coolers[b] ?? 0).compareTo(coolers[a] ?? 0));
    String coolerName(String id) => coolers[id] == null ? id : 'براد ${coolers[id]}';
    final coolerOptions = <(String, String)>[
      ('', 'الكل'),
      for (final id in coolerIds) (id, coolerName(id)),
      if (withoutCooler) (noCoolerFilter, 'دون براد'),
    ];
    final coolerLabel = switch (_cooler) {
      '' => 'الكل',
      noCoolerFilter => 'دون براد',
      final id => coolerName(id),
    };
    final search = SearchField(
      controller: _search,
      hint: 'ابحث بالمستفيد أو رقم الدفعة أو المبلغ',
      onChanged: (v) => setState(() {
        _query = v;
        _limit = _pageSize;
      }),
    );
    final filters = [
      FilterMenuButton<_PayeeFilter>(
        icon: Icons.people_outline,
        label: 'المستفيد: ${_payee.label}',
        tooltip: 'نوع المستفيد',
        options: [for (final f in _PayeeFilter.values) (f, f.label)],
        selected: _payee,
        onSelected: (v) => setState(() {
          _payee = v;
          _limit = _pageSize;
        }),
      ),
      FilterMenuButton<String>(
        icon: Icons.local_shipping_outlined,
        label: 'البراد: $coolerLabel',
        tooltip: 'اختيار البراد',
        options: coolerOptions,
        selected: _cooler,
        onSelected: (v) => setState(() {
          _cooler = v;
          _limit = _pageSize;
        }),
      ),
      FilterMenuButton<PaymentStatusFilter>(
        icon: Icons.filter_list,
        label: 'الحالة: ${_status.label}',
        tooltip: 'حالة الدفعة',
        options: [for (final s in PaymentStatusFilter.values) (s, s.label)],
        selected: _status,
        onSelected: (v) => setState(() {
          _status = v;
          _limit = _pageSize;
        }),
      ),
    ];
    if (wide) {
      return [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [SizedBox(width: 380, child: search), ...filters],
        ),
      ];
    }
    return [search, const SizedBox(height: 10), Wrap(spacing: 8, runSpacing: 8, children: filters)];
  }

  List<Widget> _duesFilters(bool wide) {
    final search = SearchField(
      controller: _duesSearch,
      hint: 'ابحث بالمزارع أو المورد أو البراد',
      onChanged: (v) => setState(() => _duesQuery = v),
    );
    final payee = FilterMenuButton<_PayeeFilter>(
      icon: Icons.people_outline,
      label: 'المستفيد: ${_duesPayee.label}',
      tooltip: 'نوع المستفيد',
      options: [for (final f in _PayeeFilter.values) (f, f.label)],
      selected: _duesPayee,
      onSelected: (v) => setState(() => _duesPayee = v),
    );
    if (wide) {
      return [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [SizedBox(width: 380, child: search), payee],
        ),
      ];
    }
    return [search, const SizedBox(height: 10), Align(alignment: AlignmentDirectional.centerStart, child: payee)];
  }

  Widget _paymentsCountLine(List<Payment> filtered) {
    final total = filtered.fold<int>(0, (s, p) => p.active ? s + p.amountPiasters : s);
    final cancelled = filtered.where((p) => !p.active).length;
    return Wrap(
      spacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(_paymentsCount(filtered.length), style: UiText.label),
        if (cancelled > 0) Text('(منها $cancelled ملغاة)', style: UiText.small),
        const Text('·', style: UiText.label),
        const Text('مجموع الفعّالة', style: UiText.label),
        MoneyText(total, fontSize: 14, unitFontSize: 12, color: AppColors.leaf),
      ],
    );
  }
}

// ============================================================================ عناصر القائمة

(IconData, Color, Color) _payeeStyle(PayeeType t) => t == PayeeType.farmer
    ? (Icons.scale_outlined, AppColors.pomegranateLight, AppColors.pomegranate)
    : (Icons.inventory_2_outlined, AppColors.leafLight, AppColors.leaf);

Widget _paymentStatus(Payment p, {bool dense = true}) => p.active
    ? StatusChip(StatusKind.active, label: 'فعّالة', dense: dense)
    : StatusChip(StatusKind.cancelled, label: 'ملغاة', dense: dense);

/// «D-0012 · نقدًا · 2 أكتوبر 2026 · 10:42 ص»
String _paymentMeta(Payment p) =>
    [p.no, p.method.label, formatArabicDateTime(p.paidAt)].where((s) => s.isNotEmpty).join(' · ');

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment, required this.onCancel});

  final Payment payment;

  /// null = لا يملك صلاحية الإلغاء أو الدفعة ملغاة.
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final p = payment;
    final (icon, bg, fg) = _payeeStyle(p.payeeType);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: p.active ? bg : UiColors.greyBg, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: 22, color: p.active ? fg : AppColors.inkMuted, semanticLabel: p.payeeType.label),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.payeeName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, height: 1.4)),
                    Text('${p.payeeType.label} · ${paymentOperationLabel(p)}', style: UiText.small),
                    Text(_paymentMeta(p), style: UiText.small),
                    if (p.createdBy != null) Text('سجّلها ${p.createdBy}', style: UiText.small),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  MoneyText(
                    p.amountPiasters,
                    fontSize: 16,
                    unitFontSize: 11.5,
                    strike: !p.active,
                    color: p.active ? AppColors.ink : AppColors.inkMuted,
                  ),
                  const SizedBox(height: 4),
                  _paymentStatus(p),
                ],
              ),
            ],
          ),
          if (!p.active) ...[
            const SizedBox(height: 8),
            _CancelReason(reason: p.cancelReason),
          ],
          if (p.notes != null) ...[
            const SizedBox(height: 6),
            Text('ملاحظات: ${p.notes}', style: UiText.small),
          ],
          if (onCancel != null)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.block, size: 18),
                label: const Text('إلغاء الدفعة'),
                style: TextButton.styleFrom(foregroundColor: AppColors.error, minimumSize: const Size(48, 48)),
              ),
            ),
        ],
      ),
    );
  }
}

class _CancelReason extends StatelessWidget {
  const _CancelReason({required this.reason, this.compact = false});

  final String? reason;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = 'سبب الإلغاء: ${reason ?? 'غير مذكور'}';
    if (compact) return Text(text, style: UiText.small.copyWith(color: UiColors.greyFg));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: UiColors.greyBg, borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: const TextStyle(fontSize: 12.5, color: UiColors.greyFg, height: 1.45)),
    );
  }
}

/// جدول الدفعات (الشاشات العريضة).
class _PaymentsTable extends StatelessWidget {
  const _PaymentsTable({required this.payments, required this.canCancel, required this.onCancel});

  final List<Payment> payments;
  final bool canCancel;
  final ValueChanged<Payment> onCancel;

  @override
  Widget build(BuildContext context) {
    const head = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.inkMuted);
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      clip: true,
      child: LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: c.maxWidth),
            child: DataTable(
              headingRowColor: const WidgetStatePropertyAll(UiColors.tableHead),
              headingRowHeight: 44,
              dataRowMinHeight: 52,
              dataRowMaxHeight: double.infinity,
              horizontalMargin: 18,
              columnSpacing: 18,
              headingTextStyle: head,
              columns: [
                const DataColumn(label: Text('رقم')),
                const DataColumn(label: Text('المستفيد')),
                const DataColumn(label: Text('العملية')),
                const DataColumn(label: Text('المبلغ (ج.م)'), numeric: true),
                const DataColumn(label: Text('الطريقة')),
                const DataColumn(label: Text('تاريخ الدفع')),
                const DataColumn(label: Text('سجّلها')),
                const DataColumn(label: Text('الحالة')),
                if (canCancel) const DataColumn(label: Text('')),
              ],
              rows: [
                for (final p in payments)
                  DataRow(cells: [
                    DataCell(Text(p.no)),
                    DataCell(Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.payeeName, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(p.payeeType.label, style: UiText.small),
                      ],
                    )),
                    DataCell(Text(paymentOperationLabel(p))),
                    DataCell(NumberText(
                      formatMoney(p.amountPiasters),
                      fontSize: 14.5,
                      strike: !p.active,
                      color: p.active ? AppColors.ink : AppColors.inkMuted,
                    )),
                    DataCell(Text(p.method.label)),
                    DataCell(Text(formatArabicDateTime(p.paidAt))),
                    DataCell(Text(p.createdBy ?? '—')),
                    DataCell(Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _paymentStatus(p, dense: false),
                          if (!p.active)
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 220),
                              child: _CancelReason(reason: p.cancelReason, compact: true),
                            ),
                        ],
                      ),
                    )),
                    if (canCancel)
                      DataCell(p.active
                          ? TextButton(
                              onPressed: () => onCancel(p),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.error,
                                minimumSize: const Size(48, 48),
                              ),
                              child: const Text('إلغاء الدفعة'),
                            )
                          : const SizedBox.shrink()),
                  ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// مستحقات مستفيد واحد: العنوان بإجمالي المتبقي، ثم كل عملية مع «تسجيل دفعة».
class _DuesGroup extends StatelessWidget {
  const _DuesGroup({required this.dues, required this.wide, required this.onRecord});

  final PayeeDues dues;
  final bool wide;

  /// null = لا يملك صلاحية تسجيل الدفعات.
  final ValueChanged<PayableOperation>? onRecord;

  @override
  Widget build(BuildContext context) {
    final d = dues;
    final (icon, bg, fg) = _payeeStyle(d.payeeType);
    return AppCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, size: 22, color: fg, semanticLabel: d.payeeType.label),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.payeeName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, height: 1.4)),
                      Text(
                        '${d.payeeType.label} · ${operationsLabel(d.operations.length)} · '
                        'القيمة ${formatMoney(d.valuePiasters)} · المدفوع ${formatMoney(d.paidPiasters)}',
                        style: UiText.small,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('المتبقي', style: UiText.small.copyWith(color: AppColors.amber, fontWeight: FontWeight.w600)),
                    MoneyText(d.remainingPiasters, fontSize: 17, color: AppColors.amber, unitFontSize: 12),
                  ],
                ),
              ],
            ),
          ),
          for (final o in d.operations) _DueRow(operation: o, wide: wide, onRecord: onRecord),
        ],
      ),
    );
  }
}

class _DueRow extends StatelessWidget {
  const _DueRow({required this.operation, required this.wide, required this.onRecord});

  final PayableOperation operation;
  final bool wide;
  final ValueChanged<PayableOperation>? onRecord;

  @override
  Widget build(BuildContext context) {
    final o = operation;
    final date = formatArabicDate(o.occurredAt);
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(o.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, height: 1.4)),
        Text([date, o.details].where((s) => s.isNotEmpty).join(' · '), style: UiText.small),
        Text('القيمة ${formatMoney(o.valuePiasters)} · المدفوع ${formatMoney(o.paidPiasters)}', style: UiText.small),
      ],
    );
    final remaining = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('المتبقي', style: UiText.small.copyWith(color: AppColors.amber)),
        MoneyText(o.remainingPiasters, fontSize: 15, color: AppColors.amber, unitFontSize: 11.5),
      ],
    );
    final button = onRecord == null
        ? null
        : AppButton(
            label: 'تسجيل دفعة',
            icon: Icons.add_card_outlined,
            height: 48,
            variant: AppButtonVariant.secondary,
            onPressed: () => onRecord!(o),
          );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: const BoxDecoration(
        color: UiColors.tableHead,
        border: Border(top: BorderSide(color: UiColors.divider)),
      ),
      child: wide
          ? Row(
              children: [
                Expanded(child: info),
                SizedBox(width: 160, child: PaidProgressBar(paid: o.paidPiasters, total: o.valuePiasters)),
                const SizedBox(width: 16),
                remaining,
                if (button != null) ...[const SizedBox(width: 16), button],
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Expanded(child: info), const SizedBox(width: 8), remaining],
                ),
                const SizedBox(height: 8),
                PaidProgressBar(paid: o.paidPiasters, total: o.valuePiasters),
                if (button != null) ...[
                  const SizedBox(height: 8),
                  Align(alignment: AlignmentDirectional.centerEnd, child: button),
                ],
              ],
            ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.title, required this.message, this.actionLabel, this.onAction});

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: UiText.cardTitle),
          const SizedBox(height: 4),
          Text(message, style: UiText.muted),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            AppButton(label: actionLabel!, variant: AppButtonVariant.secondary, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}
