import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/request_id.dart';
import '../../core/format/numbers.dart';
import '../../core/models/dashboard.dart';
import '../../core/models/records.dart';
import '../../core/models/user.dart';
import '../../core/sync/data_changes.dart';
import '../../core/sync/outbox.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'cooler_format.dart';
import 'cooler_widgets.dart';

/// تفاصيل براد: الملخص، عمليات الشراء، التعبئة المرتبطة، والإجراءات (إضافة شراء، تقفيل، إعادة فتح، تقرير).
///
/// تُعاد قراءة البراد عند كل `changes.bump()` وعند إرسال عملية لهذا البراد من قائمة «بانتظار المزامنة».
class CoolerDetailsScreen extends StatefulWidget {
  const CoolerDetailsScreen({super.key, required this.coolerId});

  final String coolerId;

  @override
  State<CoolerDetailsScreen> createState() => _CoolerDetailsScreenState();
}

enum _PurchaseAction { edit, cancel, pay }

class _CoolerDetailsScreenState extends State<CoolerDetailsScreen> {
  CoolerDetail? _detail;
  Object? _error;
  bool _loading = false;
  int _request = 0;

  DataChanges? _changes;
  Outbox? _outbox;
  StreamSubscription<OutboxEntry>? _sentSub;

  final _cancelRequest = SubmissionRequestId();
  final _reopenRequest = SubmissionRequestId();

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
      _sentSub = scope.outbox.sent.listen((e) {
        if (e.coolerId == widget.coolerId) _onChanged();
      });
    }
    if (_detail == null && !_loading && _error == null) unawaited(_load());
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
      final detail = await api.getCooler(widget.coolerId);
      if (!mounted || request != _request) return;
      setState(() {
        _detail = detail;
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

  // ------------------------------------------------------------------ الإجراءات

  void _snack(String message) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _reopen(CoolerSummary c) async {
    final scope = AppScope.of(context);
    final ok = await showReasonDialog(
      context,
      title: 'إعادة فتح ${c.title}؟',
      message: 'يعود البراد مفتوحًا لإضافة المشتريات وتعديلها وإلغائها. تبقى أرقام التقفيل السابقة محفوظة، '
          'وتُستبدل عند التقفيل التالي. يُسجَّل السبب في سجل التعديلات.',
      confirmLabel: 'إعادة فتح البراد',
      fieldLabel: 'سبب إعادة الفتح',
      hint: 'مثل: نسينا تسجيل شراء من مزارع',
      icon: Icons.lock_open_outlined,
      onSubmit: (reason) async {
        await scope.api.reopenCooler(
          id: c.id,
          reason: reason,
          requestId: _reopenRequest.idFor({'id': c.id, 'reason': reason}),
        );
        _reopenRequest.reset();
      },
    );
    if (!ok || !mounted) return;
    _snack('أُعيد فتح ${c.title}.');
    scope.changes.bump();
  }

  Future<void> _cancelPurchase(Purchase p) async {
    final scope = AppScope.of(context);
    final paidNote = p.paidPiasters > 0
        ? '\nعليها دفعات بقيمة ${formatMoney(p.paidPiasters)} ج.م، فيجب إلغاء الدفعات أولًا.'
        : '';
    final ok = await showReasonDialog(
      context,
      title: 'إلغاء عملية الشراء؟',
      message: 'شراء «${p.farmerName}» بقيمة ${formatMoney(p.valuePiasters)} ج.م. لا تُحذف العملية؛ تبقى ظاهرة «ملغاة» '
          'مع السبب وتُستبعد من الإجماليات.$paidNote',
      confirmLabel: 'إلغاء العملية',
      fieldLabel: 'سبب الإلغاء',
      hint: 'مثل: سُجّلت مرتين بالخطأ',
      destructive: true,
      icon: Icons.block,
      onSubmit: (reason) async {
        await scope.api.cancelPurchase(
          id: p.id,
          reason: reason,
          requestId: _cancelRequest.idFor({'id': p.id, 'reason': reason}),
        );
        _cancelRequest.reset();
      },
    );
    if (!ok || !mounted) return;
    _snack('أُلغيت عملية شراء «${p.farmerName}».');
    scope.changes.bump();
  }

  void _onPurchaseAction(Purchase p, _PurchaseAction a) {
    switch (a) {
      case _PurchaseAction.edit:
        unawaited(AppRoutes.editPurchase(context, p));
      case _PurchaseAction.cancel:
        unawaited(_cancelPurchase(p));
      case _PurchaseAction.pay:
        unawaited(AppRoutes.recordPayment(context, targetType: PaymentTarget.purchase, targetId: p.id));
    }
  }

  List<_PurchaseAction> _actionsFor(Purchase p, CoolerSummary c, AppUser? user) => [
        if (canChangePurchase(p, coolerOpen: c.isOpen, user: user)) _PurchaseAction.edit,
        if (canPayPurchase(p, user: user)) _PurchaseAction.pay,
        if (canChangePurchase(p, coolerOpen: c.isOpen, user: user)) _PurchaseAction.cancel,
      ];

  // ------------------------------------------------------------------ البناء

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final wide = isWideLayout(context);
    final c = detail?.cooler;
    Widget body;
    if (detail == null) {
      body = _error != null
          ? ErrorView.fromError(_error!, onRetry: _load, title: 'تعذّر تحميل البراد')
          : const LoadingSkeleton(tiles: 6, lines: 5);
    } else {
      body = _content(detail, wide);
    }
    return Scaffold(
      backgroundColor: AppColors.ivory,
      appBar: coolerAppBar(
        c?.title ?? 'تفاصيل البراد',
        subtitle: c == null ? null : (c.isOpen ? 'مفتوح' : 'مقفّل'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _content(CoolerDetail detail, bool wide) {
    final scope = AppScope.of(context);
    final user = scope.auth.user;
    final perms = permissionsOf(user);
    final c = detail.cooler;
    final pending = scope.outbox.pendingForCooler(c.id);

    final top = <Widget>[
      if (_error != null)
        InlineBanner(
          kind: BannerKind.error,
          title: 'تعذّر تحديث البراد',
          message: '${errorMessage(_error!)} المعروض الآن آخر بيانات وصلت.',
          actionLabel: _error is ApiException && (_error! as ApiException).requiresLogin ? null : 'إعادة المحاولة',
          onAction: _load,
        ),
      if (pending > 0) PendingSyncBanner(count: pending, onOpen: () => AppRoutes.openPendingSync(context)),
      if (!c.isOpen)
        const InlineBanner(
          kind: BannerKind.info,
          icon: Icons.lock_outline,
          message: 'البراد مقفّل — لا يمكن إضافة أو تعديل المشتريات، والدفعات مسموحة',
        ),
    ];

    final header = _HeaderCard(cooler: c, actions: _coolerActions(c, perms, wide));
    final kpis = CoolerKpiGrid(cooler: c, wide: wide);
    final snapshot = _snapshotCard(c);
    final purchases = _purchasesSection(detail, user, wide);
    final packaging = _packagingSection(detail, perms);

    final List<Widget> children;
    if (wide) {
      children = [
        ...top,
        header,
        kpis,
        LayoutBuilder(builder: (context, box) {
          final side = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [packaging, if (snapshot != null) ...[const SizedBox(height: 16), snapshot]],
          );
          if (box.maxWidth < 1100) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [purchases, const SizedBox(height: 16), side],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 8, child: purchases),
              const SizedBox(width: 16),
              Expanded(flex: 4, child: side),
            ],
          );
        }),
      ];
    } else {
      children = [...top, header, kpis, ?snapshot, purchases, packaging];
    }

    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: wide ? const EdgeInsets.fromLTRB(32, 16, 32, 40) : const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        ResponsiveCenter(
          maxWidth: wide ? 1400 : 720,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: wide ? 16 : 14),
                children[i],
              ],
            ],
          ),
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
          child: wide ? list : RefreshIndicator(color: AppColors.pomegranate, onRefresh: _load, child: list),
        ),
      ],
    );
  }

  /// أزرار البراد حسب حالته وصلاحيات المستخدم. «تقرير البراد» قراءة فقط فيظهر للجميع.
  List<Widget> _coolerActions(CoolerSummary c, UserPermissions p, bool wide) {
    final add = c.isOpen && p.recordPurchases
        ? AppButton(
            label: 'إضافة شراء من مزارع',
            icon: Icons.add,
            height: wide ? 48 : 52,
            expand: !wide,
            onPressed: () => AppRoutes.addPurchase(context, coolerId: c.id),
          )
        : null;
    final close = c.isOpen && p.closeCoolers
        ? AppButton(
            label: 'تقفيل البراد',
            icon: Icons.lock_outline,
            variant: AppButtonVariant.success,
            height: 48,
            expand: !wide,
            onPressed: () => AppRoutes.closeCooler(context, c.id),
          )
        : null;
    final reopen = !c.isOpen && p.reopenCoolers
        ? AppButton(
            label: 'إعادة فتح البراد',
            icon: Icons.lock_open_outlined,
            variant: AppButtonVariant.secondary,
            height: 48,
            expand: !wide,
            onPressed: () => _reopen(c),
          )
        : null;
    final report = AppButton(
      label: 'تقرير البراد',
      icon: Icons.assessment_outlined,
      variant: AppButtonVariant.secondary,
      height: 48,
      expand: !wide,
      onPressed: () => AppRoutes.openCoolerReport(context, coolerId: c.id),
    );
    if (wide) return [?add, ?close, ?reopen, report];
    final secondary = [?close, ?reopen, report];
    return [
      ?add,
      Row(
        children: [
          for (var i = 0; i < secondary.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: secondary[i]),
          ],
        ],
      ),
    ];
  }

  // ------------------------------------------------------------------ لقطة التقفيل

  Widget? _snapshotCard(CoolerSummary c) {
    final s = c.closeSnapshot;
    if (c.isOpen || s == null) return null;
    final rows = <(String, int, int)>[
      ('قيمة الرمان', s.valuePiasters, c.valuePiasters),
      ('المدفوع', s.paidPiasters, c.paidPiasters),
      ('المتبقي للمزارعين', s.remainingPiasters, c.remainingPiasters),
      ('التعبئة المعتمدة', s.packagingPiasters, c.packagingApprovedPiasters),
      ('إجمالي تكلفة البراد', s.totalCostPiasters, c.totalCostPiasters),
    ];
    final countsDiffer = s.purchases != c.purchases || s.boxes != c.boxes || s.weightGrams != c.weightGrams;
    if (!countsDiffer && rows.every((r) => r.$2 == r.$3)) return null;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader('أرقام التقفيل مقابل الآن'),
          const SizedBox(height: 4),
          const Text(
            'تغيّرت الأرقام بعد التقفيل بسبب دفعات لاحقة أو تكلفة تعبئة متأخرة. أرقام التقفيل محفوظة كما كانت.',
            style: UiText.small,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(child: SizedBox.shrink()),
              SizedBox(width: 104, child: Text('عند التقفيل', textAlign: TextAlign.end, style: UiText.small)),
              const SizedBox(width: 8),
              SizedBox(width: 104, child: Text('الآن', textAlign: TextAlign.end, style: UiText.small)),
            ],
          ),
          for (final r in rows)
            Container(
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: UiColors.divider))),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(child: Text(r.$1, style: UiText.label)),
                  SizedBox(
                    width: 104,
                    child: Text(formatMoney(r.$2), textAlign: TextAlign.end, style: UiText.number(size: 14)),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 104,
                    child: Text(
                      formatMoney(r.$3),
                      textAlign: TextAlign.end,
                      style: UiText.number(size: 14, color: r.$2 == r.$3 ? AppColors.ink : AppColors.info),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ عمليات الشراء

  Widget _purchasesSection(CoolerDetail detail, AppUser? user, bool wide) {
    final c = detail.cooler;
    final list = detail.purchases;
    final cancelled = list.where((p) => !p.active).length;
    final header = SectionHeader(
      'عمليات الشراء (${list.length - cancelled})',
      style: UiText.cardTitle,
      subtitle: cancelled > 0 ? '$cancelled ملغاة لا تدخل في الإجماليات' : null,
    );
    if (list.isEmpty) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: 10),
            Text(
              c.isOpen ? 'لم تُسجَّل مشتريات في هذا البراد بعد.' : 'لا توجد مشتريات مسجلة في هذا البراد.',
              style: UiText.muted,
            ),
          ],
        ),
      );
    }
    if (wide) {
      return _PurchasesTable(
        header: header,
        purchases: list,
        actionsFor: (p) => _actionsFor(p, c, user),
        onAction: _onPurchaseAction,
      );
    }
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: header),
          const SizedBox(height: 6),
          for (final p in list)
            _PurchaseTile(purchase: p, actions: _actionsFor(p, c, user), onAction: (a) => _onPurchaseAction(p, a)),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ التعبئة

  Widget _packagingSection(CoolerDetail detail, UserPermissions perms) {
    final c = detail.cooler;
    final list = detail.packaging;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader('مشتريات التعبئة المرتبطة', style: UiText.cardTitle),
          const SizedBox(height: 6),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('لا توجد مشتريات تعبئة مرتبطة بهذا البراد.', style: UiText.muted),
            ),
          for (final k in list) _PackagingRow(packaging: k, onTap: () => AppRoutes.openPackaging(context, packagingId: k.id)),
          if (perms.packaging) ...[
            const SizedBox(height: 10),
            AppButton(
              label: 'إضافة مشتريات تعبئة',
              icon: Icons.inventory_2_outlined,
              variant: AppButtonVariant.secondary,
              height: 48,
              expand: true,
              onPressed: () => AppRoutes.openPackaging(context, coolerId: c.id),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================ الرأس

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.cooler, required this.actions});

  final CoolerSummary cooler;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = cooler;
    final wide = isWideLayout(context);
    final info = [openedLine(c), closedLine(c), vehicleLine(c)].where((s) => s.isNotEmpty).toList();
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Semantics(
                header: true,
                child: Text(
                  c.title,
                  style: const TextStyle(fontFamily: AppFonts.display, fontSize: 22, fontWeight: FontWeight.w700, height: 1.35),
                ),
              ),
            ),
            const SizedBox(width: 10),
            StatusChip(c.isOpen ? StatusKind.open : StatusKind.closed),
          ],
        ),
        for (final l in info) Text(l, style: UiText.muted),
        if (c.notes != null) ...[
          const SizedBox(height: 4),
          Text(c.notes!, style: const TextStyle(fontSize: 13.5, color: AppColors.inkSecondary, height: 1.5)),
        ],
      ],
    );
    return AppCard(
      borderColor: c.isOpen ? UiColors.currentBorder : UiColors.cardBorder,
      borderWidth: c.isOpen ? 1.5 : 1,
      padding: EdgeInsets.all(wide ? 18 : 16),
      child: wide
          ? Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                ConstrainedBox(constraints: const BoxConstraints(minWidth: 280), child: title),
                Wrap(spacing: 10, runSpacing: 10, children: actions),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                title,
                for (final a in actions) ...[const SizedBox(height: 10), a],
              ],
            ),
    );
  }
}

// ============================================================================ عمليات الشراء

String _measureLine(Purchase p) =>
    '${formatCount(p.boxes)} صندوق × ${kgExact(p.avgWeightGrams)} كغ = ${kgExact(p.totalWeightGrams)} كغ'
    ' · ${formatMoney(p.pricePerKgPiasters)} ج.م/كغ';

String _byLine(Purchase p) => [whenText(p.occurredAt), if (p.createdBy != null) p.createdBy!].where((s) => s.isNotEmpty).join(' · ');

Widget _payChip(Purchase p, {bool dense = true}) {
  if (!p.active) return StatusChip(StatusKind.cancelled, label: 'ملغاة', dense: dense);
  return switch (p.payStatus) {
    PayStatus.paid => StatusChip(StatusKind.paid, dense: dense),
    PayStatus.partial => StatusChip(StatusKind.partial, dense: dense),
    PayStatus.unpaid => StatusChip(StatusKind.unpaid, dense: dense),
  };
}

String _actionLabel(_PurchaseAction a) => switch (a) {
      _PurchaseAction.edit => 'تعديل العملية',
      _PurchaseAction.cancel => 'إلغاء العملية',
      _PurchaseAction.pay => 'تسجيل دفعة',
    };

IconData _actionIcon(_PurchaseAction a) => switch (a) {
      _PurchaseAction.edit => Icons.edit_outlined,
      _PurchaseAction.cancel => Icons.block,
      _PurchaseAction.pay => Icons.payments_outlined,
    };

class _PurchaseMenu extends StatelessWidget {
  const _PurchaseMenu({required this.purchase, required this.actions, required this.onSelected});

  final Purchase purchase;
  final List<_PurchaseAction> actions;
  final ValueChanged<_PurchaseAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_PurchaseAction>(
      tooltip: 'إجراءات شراء ${purchase.farmerName}',
      icon: const Icon(Icons.more_vert, color: AppColors.inkSecondary),
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final a in actions)
          PopupMenuItem<_PurchaseAction>(
            value: a,
            height: 48,
            child: Row(
              children: [
                Icon(_actionIcon(a), size: 20, color: a == _PurchaseAction.cancel ? AppColors.error : AppColors.ink),
                const SizedBox(width: 10),
                Text(
                  _actionLabel(a),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: a == _PurchaseAction.cancel ? AppColors.error : AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// عملية شراء في القائمة (الهاتف).
class _PurchaseTile extends StatelessWidget {
  const _PurchaseTile({required this.purchase, required this.actions, required this.onAction});

  final Purchase purchase;
  final List<_PurchaseAction> actions;
  final ValueChanged<_PurchaseAction> onAction;

  @override
  Widget build(BuildContext context) {
    final p = purchase;
    final muted = !p.active;
    return Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: UiColors.divider))),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.farmerName,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    height: 1.4,
                    color: muted ? AppColors.inkMuted : AppColors.ink,
                  ),
                ),
                Text(_measureLine(p), style: UiText.small),
                if (_byLine(p).isNotEmpty) Text(_byLine(p), style: UiText.small),
                if (!p.active)
                  Text(
                    p.cancelReason == null ? 'ملغاة' : 'ملغاة — السبب: ${p.cancelReason}',
                    style: const TextStyle(fontSize: 12.5, color: UiColors.errorInk, height: 1.45),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              MoneyText(p.valuePiasters, fontSize: 15, unitFontSize: 11.5, strike: muted, color: muted ? AppColors.inkMuted : AppColors.ink),
              const SizedBox(height: 4),
              _payChip(p),
              if (p.active && p.remainingPiasters > 0 && p.payStatus != PayStatus.paid)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'متبقي ${formatMoney(p.remainingPiasters)}',
                    style: UiText.number(size: 12.5, color: AppColors.amber, weight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          if (actions.isNotEmpty)
            _PurchaseMenu(purchase: p, actions: actions, onSelected: onAction)
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// جدول عمليات الشراء (الشاشات العريضة).
class _PurchasesTable extends StatelessWidget {
  const _PurchasesTable({required this.header, required this.purchases, required this.actionsFor, required this.onAction});

  final Widget header;
  final List<Purchase> purchases;
  final List<_PurchaseAction> Function(Purchase) actionsFor;
  final void Function(Purchase, _PurchaseAction) onAction;

  @override
  Widget build(BuildContext context) {
    const head = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.inkMuted);
    TextStyle cell(Purchase p) => TextStyle(fontSize: 13.5, color: p.active ? AppColors.ink : AppColors.inkMuted);
    return AppCard(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(18, 0, 18, 10), child: header),
          LayoutBuilder(
            builder: (context, c) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: c.maxWidth),
                child: DataTable(
                  headingRowColor: const WidgetStatePropertyAll(UiColors.tableHead),
                  headingRowHeight: 44,
                  dataRowMinHeight: 56,
                  dataRowMaxHeight: 76,
                  horizontalMargin: 18,
                  columnSpacing: 18,
                  headingTextStyle: head,
                  columns: const [
                    DataColumn(label: Text('المزارع')),
                    DataColumn(label: Text('الصناديق'), numeric: true),
                    DataColumn(label: Text('متوسط الصندوق (كغ)'), numeric: true),
                    DataColumn(label: Text('الوزن (كغ)'), numeric: true),
                    DataColumn(label: Text('سعر الكيلو'), numeric: true),
                    DataColumn(label: Text('القيمة (ج.م)'), numeric: true),
                    DataColumn(label: Text('الدفع')),
                    DataColumn(label: Text('الوقت · بواسطة')),
                    DataColumn(label: SizedBox(width: 48)),
                  ],
                  rows: [
                    for (final p in purchases)
                      DataRow(cells: [
                        DataCell(Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(p.farmerName, style: cell(p).copyWith(fontWeight: FontWeight.w700)),
                            if (!p.active)
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 220),
                                child: Text(
                                  p.cancelReason == null ? 'ملغاة' : 'ملغاة — السبب: ${p.cancelReason}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: UiColors.errorInk),
                                ),
                              ),
                          ],
                        )),
                        DataCell(Text(formatCount(p.boxes), style: cell(p))),
                        DataCell(Text(kgExact(p.avgWeightGrams), style: cell(p))),
                        DataCell(Text(kgExact(p.totalWeightGrams), style: cell(p))),
                        DataCell(Text(formatMoney(p.pricePerKgPiasters), style: cell(p))),
                        DataCell(NumberText(
                          formatMoney(p.valuePiasters),
                          fontSize: 14,
                          strike: !p.active,
                          color: p.active ? AppColors.ink : AppColors.inkMuted,
                        )),
                        DataCell(Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _payChip(p, dense: false),
                            if (p.active && p.payStatus != PayStatus.paid && p.remainingPiasters > 0)
                              Text(
                                'متبقي ${formatMoney(p.remainingPiasters)}',
                                style: UiText.number(size: 12, color: AppColors.amber, weight: FontWeight.w600),
                              ),
                          ],
                        )),
                        DataCell(Text(_byLine(p), style: cell(p).copyWith(fontSize: 12.5))),
                        DataCell(actionsFor(p).isEmpty
                            ? const SizedBox(width: 48)
                            : _PurchaseMenu(
                                purchase: p,
                                actions: actionsFor(p),
                                onSelected: (a) => onAction(p, a),
                              )),
                      ]),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================ التعبئة

class _PackagingRow extends StatelessWidget {
  const _PackagingRow({required this.packaging, required this.onTap});

  final PackagingSummary packaging;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = packaging;
    final title = [k.no, if (k.supplier != null) k.supplier!].join(' · ');
    final sub = [
      if (k.occurredAt != null) formatArabicDate(k.occurredAt),
      '${formatCount(k.itemsCount)} عنصر',
      if (k.incompleteCount > 0) '${formatCount(k.incompleteCount)} غير مكتمل',
    ].join(' · ');
    final cancelled = k.status == PackagingStatus.cancelled;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: UiColors.divider))),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4)),
                  Text(sub, style: UiText.small),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      StatusChip.fromStatus(k.status.wire, label: k.status.label, dense: true),
                      if (k.late) const StatusChip(StatusKind.late, dense: true),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            MoneyText(
              k.completeTotalPiasters,
              fontSize: 15,
              unitFontSize: 11.5,
              strike: cancelled,
              color: cancelled || k.status == PackagingStatus.draft ? AppColors.inkMuted : AppColors.ink,
            ),
            const SizedBox(width: 4),
            // ينعكس تلقائيًا ليشير إلى الأمام (اليسار) في العربية.
            const Icon(Icons.chevron_right, color: AppColors.inkMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
