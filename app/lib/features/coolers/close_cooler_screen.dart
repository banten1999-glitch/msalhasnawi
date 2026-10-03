import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/request_id.dart';
import '../../core/format/numbers.dart';
import '../../core/models/dashboard.dart';
import '../../core/models/records.dart';
import '../../core/sync/data_changes.dart';
import '../../core/sync/outbox.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'cooler_format.dart';
import 'cooler_widgets.dart';

/// مراجعة ما قبل التقفيل ثم coolers.close (مع عدد العمليات بانتظار المزامنة).
///
/// التقفيل ممنوع ما دامت على هذا الجهاز عمليات لهذا البراد لم تصل إلى الملف (الخادم يرفضه أيضًا).
class CloseCoolerScreen extends StatefulWidget {
  const CloseCoolerScreen({super.key, required this.coolerId});

  final String coolerId;

  @override
  State<CloseCoolerScreen> createState() => _CloseCoolerScreenState();
}

class _CloseCoolerScreenState extends State<CloseCoolerScreen> {
  CoolerDetail? _detail;
  Object? _error;
  bool _loading = false;
  int _request = 0;

  bool _closing = false;
  String? _closeError;
  final _closeRequest = SubmissionRequestId();

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
    if (mounted && !_closing) unawaited(_load());
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

  Future<void> _confirmAndClose(CoolerSummary c) async {
    if (_closing) return;
    final scope = AppScope.of(context);
    if (scope.outbox.pendingForCooler(c.id) > 0) return;
    final ok = await showConfirmDialog(
      context,
      title: 'تقفيل ${c.title}؟',
      message: 'تُحفظ أرقام البراد كما هي الآن. بعد التقفيل لا يمكن إضافة مشتريات رمان إليه أو تعديلها أو '
          'إلغاؤها، وتبقى الدفعات مسموحة.',
      confirmLabel: 'تقفيل البراد',
      icon: Icons.lock_outline,
    );
    if (!ok || !mounted) return;

    final pending = scope.outbox.pendingForCooler(c.id);
    if (pending > 0) {
      setState(() => _closeError = 'وصلت ${pendingLabel(pending)} لهذا البراد أثناء التأكيد. انتظر المزامنة ثم أعد التقفيل.');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final requestId = _closeRequest.idFor({'id': c.id, 'expectedVersion': c.version, 'clientPendingCount': pending});
    setState(() {
      _closing = true;
      _closeError = null;
    });
    try {
      final closed = await scope.api.closeCooler(
        id: c.id,
        expectedVersion: c.version,
        clientPendingCount: pending,
        requestId: requestId,
      );
      _closeRequest.reset();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('تم تقفيل ${closed.title} وحُفظت أرقامه.')));
      scope.changes.bump();
      if (mounted) navigator.pop();
    } catch (e) {
      if (!mounted) return;
      final reload = e is ApiException && (e.code == ApiErrorCode.conflict || e.code == ApiErrorCode.coolerClosed);
      setState(() {
        _closing = false;
        _closeError = e is ApiException && e.code == ApiErrorCode.conflict
            ? 'تغيّرت بيانات البراد منذ فتح هذه الصفحة (أُضيفت عمليات أو عُدّلت). راجع الأرقام المحدّثة ثم أعد التقفيل.'
            : errorMessage(e);
      });
      if (reload) unawaited(_load());
    }
  }

  // ------------------------------------------------------------------ البناء

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    Widget body;
    if (detail == null) {
      body = _error != null
          ? ErrorView.fromError(_error!, onRetry: _load, title: 'تعذّر تحميل البراد')
          : const LoadingSkeleton(tiles: 6, lines: 3);
    } else if (!detail.cooler.isOpen && !_closing) {
      body = EmptyState(
        icon: Icons.lock_outline,
        iconColor: AppColors.inkSecondary,
        title: '${detail.cooler.title} مقفّل بالفعل',
        message: closedLine(detail.cooler).isEmpty ? 'لا حاجة لتقفيله مرة أخرى.' : '${closedLine(detail.cooler)}.',
        actionLabel: 'رجوع',
        onAction: () => Navigator.of(context).maybePop(),
      );
    } else {
      body = _content(detail);
    }
    return Scaffold(
      backgroundColor: AppColors.ivory,
      appBar: coolerAppBar('تقفيل البراد', subtitle: detail?.cooler.title),
      body: body,
    );
  }

  Widget _content(CoolerDetail detail) {
    final scope = AppScope.of(context);
    final wide = isWideLayout(context);
    final c = detail.cooler;
    final canClose = permissionsOf(scope.auth.user).closeCoolers;
    final pending = scope.outbox.pendingForCooler(c.id);
    final drafts = detail.packaging.where((k) => k.status == PackagingStatus.draft).toList();
    final unpaid = detail.purchases.where((p) => p.active && p.remainingPiasters > 0).length;

    final warnings = <Widget>[
      if (!canClose)
        const InlineBanner(
          kind: BannerKind.error,
          title: 'لا تملك صلاحية تقفيل البرادات',
          message: 'اطلب صلاحية «تقفيل البرادات» من المدير، أو اطلب منه تقفيل البراد.',
        ),
      if (pending > 0)
        PendingSyncBanner(
          count: pending,
          kind: BannerKind.error,
          message: 'لهذا البراد على هذا الجهاز عمليات لم تصل إلى الملف بعد، فلا يمكن تقفيله حتى لا تُحفظ أرقام ناقصة. '
              'اتصل بالإنترنت وانتظر حتى تُرسل كلها، ثم قفّل البراد.',
          onOpen: () => AppRoutes.openPendingSync(context),
        ),
      if (c.purchases == 0)
        const InlineBanner(
          kind: BannerKind.warning,
          message: 'لا توجد عمليات شراء فعّالة في هذا البراد. تأكد أنك تقفّل البراد الصحيح.',
        ),
      if (drafts.isNotEmpty)
        InlineBanner(
          kind: BannerKind.warning,
          title: drafts.length == 1
              ? 'مسودة تعبئة غير معتمدة (${drafts.first.no})'
              : '${formatCount(drafts.length)} مسودات تعبئة غير معتمدة',
          message: 'لا تُحسب المسودات في تكلفة البراد عند التقفيل. اعتمدها أولًا إن أردت احتسابها؛ وإن اعتُمدت بعد '
              'التقفيل تُسجَّل «تكلفة متأخرة».',
        ),
      if (c.remainingPiasters > 0)
        InlineBanner(
          kind: BannerKind.info,
          title: 'متبقٍ للمزارعين ${formatMoney(c.remainingPiasters)} ج.م',
          message: 'في ${operationsLabel(unpaid)} لم تُدفع بالكامل. للعلم فقط: التقفيل لا يمنع تسجيل الدفعات لاحقًا.',
        ),
    ];

    final review = AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader('الأرقام التي تُحفظ عند التقفيل', style: UiText.cardTitle, subtitle: openedLine(c)),
          const SizedBox(height: 12),
          CoolerKpiGrid(cooler: c, wide: wide),
          const SizedBox(height: 12),
          const Text(
            'بعد التقفيل: لا يمكن إضافة مشتريات رمان أو تعديلها أو إلغاؤها، وتبقى الدفعات وتكلفة التعبئة المتأخرة '
            'مسموحة. إعادة الفتح للمدير فقط وبسبب مكتوب.',
            style: UiText.small,
          ),
        ],
      ),
    );

    final blocked = !canClose || pending > 0;
    final buttons = Row(
      children: [
        Expanded(
          child: AppButton(
            label: 'رجوع',
            variant: AppButtonVariant.secondary,
            onPressed: _closing ? null : () => Navigator.of(context).maybePop(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: AppButton(
            label: 'تقفيل البراد',
            icon: Icons.lock_outline,
            variant: AppButtonVariant.success,
            busy: _closing,
            busyLabel: 'جارٍ التقفيل',
            onPressed: blocked || _loading ? null : () => _confirmAndClose(c),
          ),
        ),
      ],
    );

    final children = <Widget>[
      if (_error != null)
        InlineBanner(
          kind: BannerKind.error,
          title: 'تعذّر تحديث البراد',
          message: '${errorMessage(_error!)} راجع الأرقام بعد التحديث قبل التقفيل.',
          actionLabel: 'إعادة المحاولة',
          onAction: _load,
        ),
      ...warnings,
      review,
      if (_closeError != null) InlineBanner(kind: BannerKind.error, title: 'لم يُقفَّل البراد', message: _closeError!),
      if (blocked && canClose) const Text('زر التقفيل معطّل حتى تصل كل العمليات بانتظار المزامنة.', style: UiText.small),
      buttons,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 3,
          child: _loading ? const LinearProgressIndicator(minHeight: 3, color: AppColors.pomegranate) : null,
        ),
        Expanded(
          child: ListView(
            padding: wide ? const EdgeInsets.fromLTRB(32, 16, 32, 40) : const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              ResponsiveCenter(
                maxWidth: 960,
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
          ),
        ),
      ],
    );
  }
}
