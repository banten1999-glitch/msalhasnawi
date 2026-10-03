import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/backend_api.dart';
import '../../core/api/request_id.dart';
import '../../core/format/numbers.dart';
import '../../core/models/records.dart';
import '../../core/models/user.dart';
import '../../core/sync/outbox.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../farmers/filter_menu_button.dart';
import '../farmers/text_search.dart';
import 'payments_logic.dart';

/// تسجيل دفعة لعملية شراء رمان أو شراء تعبئة. دون [targetId] يختار المستخدم المستفيد ثم العملية.
///
/// الحفظ عبر قائمة «بانتظار المزامنة» (outbox): دون اتصال تُحفظ الدفعة على الجهاز وتُرسل لاحقًا بالمعرّف نفسه.
class RecordPaymentScreen extends StatefulWidget {
  const RecordPaymentScreen({super.key, this.targetType, this.targetId});

  final PaymentTarget? targetType;
  final String? targetId;

  @override
  State<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends State<RecordPaymentScreen> {
  bool get _fixed => (widget.targetId ?? '').isNotEmpty;

  bool _started = false;
  bool _loading = true;
  Object? _loadError;

  // ------------------------------------------------------------------ اختيار العملية (دون هدف محدد)
  PayeeType _payeeType = PayeeType.farmer;
  List<PayeeDues> _farmerDues = const [];
  List<PayableOperation> _packagingOps = const [];
  PayeeDues? _farmer;
  final _pickSearch = TextEditingController();
  String _pickQuery = '';

  // ------------------------------------------------------------------ العملية المختارة
  PayableOperation? _target;

  /// سبب يمنع الدفع لهذه العملية (مسودة، ملغاة، مدفوعة بالكامل).
  String? _targetProblem;

  // ------------------------------------------------------------------ النموذج
  final _amount = TextEditingController();
  PaymentMethod _method = PaymentMethod.cash;
  DateTime? _paidAt;
  final _notes = TextEditingController();
  String? _amountError;
  String? _methodError;
  String? _paidAtError;
  String? _notesError;
  String? _error;
  bool _saving = false;
  bool _done = false;

  /// requestId للدفعة: يُعاد مع الحمولة نفسها عند إعادة المحاولة، فلا تُسجَّل مرتين.
  final _request = SubmissionRequestId();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // دون صلاحية لا داعي لتحميل شيء: تظهر رسالة الصلاحية فقط.
    if (AppScope.of(context).auth.user?.permissions.recordPayments ?? false) {
      unawaited(_load());
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _pickSearch.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ التحميل

  Future<void> _load() async {
    final api = AppScope.of(context).api;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      if (_fixed) {
        await _loadTarget(api);
      } else {
        final purchasesF = settle(api.listPurchases());
        final packagingF = settle(api.listPackaging(status: 'approved'));
        final (purchases, purchasesError) = await purchasesF;
        final (packaging, packagingError) = await packagingF;
        if (purchasesError != null) throw purchasesError;
        if (packagingError != null) throw packagingError;
        final dues = groupDues(purchases: purchases!, packaging: packaging!);
        _farmerDues = [for (final d in dues) if (d.payeeType == PayeeType.farmer) d];
        _packagingOps = [
          for (final d in dues)
            if (d.payeeType == PayeeType.supplier) ...d.operations,
        ]..sort((a, b) => b.remainingPiasters.compareTo(a.remainingPiasters));
      }
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e;
      });
    }
  }

  /// العملية المحددة مسبقًا: الشراء من purchases.list (لا يوجد purchases.get)، والتعبئة من packaging.get.
  Future<void> _loadTarget(BackendApi api) async {
    final id = widget.targetId!;
    final type = widget.targetType ?? (id.startsWith('PK-') ? PaymentTarget.packaging : PaymentTarget.purchase);
    if (type == PaymentTarget.purchase) {
      final all = await api.listPurchases(includeCancelled: true);
      final p = all.where((x) => x.id == id).firstOrNull;
      if (p == null) {
        throw ApiException(
          ApiErrorCode.notFound,
          'لم نجد عملية الشراء $id في الملف. حدّث البيانات واختر العملية من القائمة من جديد.',
        );
      }
      _target = PayableOperation.purchase(p);
      _targetProblem = !p.active
          ? 'عملية الشراء هذه ملغاة${p.cancelReason == null ? '' : ' (${p.cancelReason})'}، فلا يمكن الدفع لها.'
          : (p.remainingPiasters <= 0 ? 'هذه العملية مدفوعة بالكامل. لا يوجد مبلغ متبقٍ للدفع.' : null);
    } else {
      final k = (await api.getPackaging(id)).packaging;
      _target = PayableOperation.packaging(k);
      _targetProblem = switch (k.status) {
        PackagingStatus.draft => 'شراء التعبئة ${k.no} ما زال مسودة. اعتمده أولًا ثم سجّل الدفعة.',
        PackagingStatus.cancelled => 'شراء التعبئة ${k.no} ملغى، فلا يمكن الدفع له.',
        PackagingStatus.approved =>
          k.remainingPiasters <= 0 ? 'شراء التعبئة ${k.no} مدفوع بالكامل. لا يوجد مبلغ متبقٍ للدفع.' : null,
      };
    }
  }

  // ------------------------------------------------------------------ الاختيار

  void _choosePayeeType(PayeeType t) => setState(() {
        _payeeType = t;
        _farmer = null;
        _target = null;
        _pickSearch.clear();
        _pickQuery = '';
        _clearFormErrors();
      });

  void _chooseFarmer(PayeeDues d) => setState(() {
        _farmer = d;
        _pickSearch.clear();
        _pickQuery = '';
        // مزارع له عملية واحدة: تُختار مباشرة.
        _target = d.operations.length == 1 ? d.operations.single : null;
        _clearFormErrors();
      });

  void _chooseTarget(PayableOperation o) => setState(() {
        _target = o;
        _clearFormErrors();
      });

  void _changeTarget() => setState(() {
        _target = null;
        if ((_farmer?.operations.length ?? 0) <= 1) _farmer = null;
        _clearFormErrors();
      });

  // ------------------------------------------------------------------ الحفظ

  /// مجموع دفعات هذه العملية المحفوظة على الجهاز ولم تصل بعد.
  int _pendingFor(Outbox outbox, String targetId) => outbox.entries
      .where((e) => e.action == 'payments.create' && e.payload['targetId'] == targetId)
      .fold(0, (s, e) => s + ((e.payload['amountPiasters'] as num?)?.toInt() ?? 0));

  int _maxAmount(PayableOperation t) {
    final max = t.remainingPiasters - _pendingFor(AppScope.of(context).outbox, t.targetId);
    return max < 0 ? 0 : max;
  }

  String? _amountProblem(String text, int max, {required bool submit}) {
    final t = text.trim();
    if (t.isEmpty) return submit ? 'اكتب مبلغ الدفعة بالجنيه، مثل 1500 أو 1500.50.' : null;
    final v = parseToMinor(t, 2);
    if (v == null) return 'المبلغ «$t» غير صحيح. اكتب أرقامًا فقط مثل 1500 أو 1500.50.';
    if (v <= 0) return 'المبلغ يجب أن يكون أكبر من صفر.';
    if (v > max) {
      return '«المبلغ» (${formatMoney(v)} ج.م) أكبر من المتبقي (${formatMoney(max)} ج.م). '
          'اكتب مبلغًا لا يزيد على المتبقي.';
    }
    return null;
  }

  void _fillRemaining(int max) {
    _amount.text = editableMoney(max);
    _amount.selection = TextSelection.collapsed(offset: _amount.text.length);
    setState(() => _amountError = null);
  }

  void _clearFormErrors() {
    _amountError = null;
    _methodError = null;
    _paidAtError = null;
    _notesError = null;
    _error = null;
  }

  Future<void> _submit() async {
    final t = _target;
    if (_saving || _done || t == null || _targetProblem != null) return;
    final scope = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final max = _maxAmount(t);
    setState(() {
      _clearFormErrors();
      _amountError = _amountProblem(_amount.text, max, submit: true);
    });
    if (_amountError != null) return;

    final amount = parseToMinor(_amount.text, 2)!;
    final notes = _notes.text.trim();
    final payload = <String, dynamic>{
      'targetType': t.targetType.wire,
      'targetId': t.targetId,
      'amountPiasters': amount,
      'method': _method.wire,
      if (_paidAt != null) 'paidAt': toWallClockText(_paidAt!),
      if (notes.isNotEmpty) 'notes': notes,
    };
    setState(() => _saving = true);
    try {
      final outcome = await scope.outbox.submit(
        action: 'payments.create',
        payload: payload,
        requestId: _request.idFor(payload),
        label: 'دفعة · ${t.payeeName} · ${formatMoney(amount)} ج.م',
        coolerId: t.targetType == PaymentTarget.purchase ? t.coolerId : null,
      );
      _request.reset();
      scope.changes.bump();
      final message = switch (outcome) {
        SubmitSent(:final data) => _sentMessage(data),
        SubmitQueued() => 'حُفظت على الجهاز — بانتظار المزامنة',
      };
      if (!mounted) return;
      setState(() {
        _saving = false;
        _done = true;
      });
      messenger.showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
      await navigator.maybePop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _applyError(e, t);
      });
    }
  }

  static String _sentMessage(Map<String, dynamic> data) {
    final payment = data['payment'];
    final no = payment is Map ? payment['no'] : null;
    return no is String && no.isNotEmpty ? 'تم الحفظ في الملف · الدفعة $no' : 'تم الحفظ في الملف';
  }

  void _applyError(Object e, PayableOperation t) {
    if (e is! ApiException || e.code != ApiErrorCode.validation) {
      _error = errorMessage(e);
      return;
    }
    switch (e.field) {
      case 'amountPiasters':
        _amountError = e.message;
        final remaining = e.details['remainingPiasters'];
        if (remaining is num) _target = t.withRemaining(remaining.toInt());
      case 'method':
        _methodError = e.message;
      case 'paidAt':
        _paidAtError = e.message;
      case 'notes':
        _notesError = e.message;
      default:
        _error = e.message;
    }
  }

  // ------------------------------------------------------------------ البناء

  @override
  Widget build(BuildContext context) {
    final perms = AppScope.of(context).auth.user?.permissions ?? const UserPermissions();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.ivory,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        toolbarHeight: 64,
        title: const Text('تسجيل دفعة', style: UiText.pageTitle),
      ),
      body: _body(perms),
    );
  }

  Widget _body(UserPermissions perms) {
    if (!perms.recordPayments) {
      return const ErrorView(
        title: 'لا تملك صلاحية تسجيل الدفعات',
        message: 'اطلب من المدير منحك صلاحية «تسجيل المدفوعات» إن كنت تحتاجها.',
      );
    }
    if (_loading) return const LoadingSkeleton(tiles: 0, lines: 6);
    if (_loadError != null) {
      return ErrorView.fromError(_loadError!, onRetry: _load, title: 'تعذّر تحميل بيانات الدفعة');
    }
    final wide = isWideLayout(context);
    final t = _target;
    const gap = SizedBox(height: 14);
    return ListView(
      padding: wide ? const EdgeInsets.fromLTRB(32, 24, 32, 40) : const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        ResponsiveCenter(
          maxWidth: 680,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_fixed && t == null) _pickerCard(),
              if (t != null) ...[
                _TargetSummary(
                  target: t,
                  pendingPiasters: _pendingFor(AppScope.of(context).outbox, t.targetId),
                  onChange: _fixed || _saving || _done ? null : _changeTarget,
                ),
                if (_targetProblem != null) ...[
                  gap,
                  InlineBanner(kind: BannerKind.warning, message: _targetProblem!),
                ] else ...[
                  gap,
                  _formCard(t),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ الاختيار

  Widget _pickerCard() {
    final farmer = _farmer;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('لمن الدفعة؟', style: UiText.cardTitle),
          const SizedBox(height: 10),
          SegmentedChoice<PayeeType>(
            semanticLabel: 'نوع المستفيد',
            options: const [SegmentOption(PayeeType.farmer, 'مزارع'), SegmentOption(PayeeType.supplier, 'مورد تعبئة')],
            value: _payeeType,
            onChanged: _choosePayeeType,
          ),
          const SizedBox(height: 14),
          if (_payeeType == PayeeType.farmer && farmer == null) ..._farmerList(),
          if (_payeeType == PayeeType.farmer && farmer != null) ..._farmerOperations(farmer),
          if (_payeeType == PayeeType.supplier) ..._packagingList(),
        ],
      ),
    );
  }

  Widget _searchField(String hint) => SearchField(
        controller: _pickSearch,
        hint: hint,
        onChanged: (v) => setState(() => _pickQuery = v),
      );

  List<Widget> _farmerList() {
    final list = [for (final d in _farmerDues) if (matchesAllWords([d.payeeName], _pickQuery)) d];
    return [
      _searchField('ابحث عن المزارع بالاسم'),
      const SizedBox(height: 8),
      if (_farmerDues.isEmpty)
        const _PickEmpty('لا توجد مستحقات للمزارعين الآن. كل عمليات الشراء مدفوعة بالكامل.')
      else if (list.isEmpty)
        _PickEmpty('لا يوجد مزارع له مستحقات يطابق «${_pickQuery.trim()}».')
      else
        for (final d in list)
          _PickRow(
            title: d.payeeName,
            subtitle: operationsLabel(d.operations.length),
            remaining: d.remainingPiasters,
            onTap: () => _chooseFarmer(d),
          ),
    ];
  }

  List<Widget> _farmerOperations(PayeeDues farmer) {
    return [
      Row(
        children: [
          const Icon(Icons.person_outline, color: AppColors.inkSecondary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(farmer.payeeName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
          TextButton(
            onPressed: () => setState(() => _farmer = null),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: const Text('تغيير المزارع'),
          ),
        ],
      ),
      const SizedBox(height: 4),
      const Text('اختر عملية الشراء', style: UiText.fieldLabel),
      const SizedBox(height: 4),
      for (final o in farmer.operations)
        _PickRow(
          title: o.title,
          subtitle: [formatArabicDate(o.occurredAt), o.details].where((s) => s.isNotEmpty).join(' · '),
          remaining: o.remainingPiasters,
          onTap: () => _chooseTarget(o),
        ),
    ];
  }

  List<Widget> _packagingList() {
    final list = [
      for (final o in _packagingOps)
        if (matchesAllWords([o.payeeName, o.title, o.details], _pickQuery)) o,
    ];
    return [
      const _Note(icon: Icons.info_outline, text: 'تُسجَّل الدفعات لمشتريات التعبئة المعتمدة فقط.'),
      const SizedBox(height: 10),
      _searchField('ابحث بالمورد أو رقم الشراء أو الفاتورة'),
      const SizedBox(height: 8),
      if (_packagingOps.isEmpty)
        const _PickEmpty('لا توجد مشتريات تعبئة معتمدة لها مبلغ متبقٍ.')
      else if (list.isEmpty)
        _PickEmpty('لا يوجد شراء تعبئة يطابق «${_pickQuery.trim()}».')
      else
        for (final o in list)
          _PickRow(
            title: o.payeeName,
            subtitle: [o.title, o.details].where((s) => s.isNotEmpty).join(' · '),
            remaining: o.remainingPiasters,
            onTap: () => _chooseTarget(o),
          ),
    ];
  }

  // ------------------------------------------------------------------ النموذج

  Widget _formCard(PayableOperation t) {
    final max = _maxAmount(t);
    final busy = _saving || _done;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('بيانات الدفعة', style: UiText.cardTitle),
          const SizedBox(height: 12),
          LabeledField(
            label: 'المبلغ (ج.م)',
            child: TextField(
              controller: _amount,
              enabled: !busy,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩۰-۹.,٫٬]'))],
              textInputAction: TextInputAction.done,
              style: UiText.number(size: 18),
              onChanged: (v) => setState(() => _amountError = _amountProblem(v, max, submit: false)),
              decoration: uiInputDecoration(
                hint: 'مثل 1500 أو 1500.50',
                errorText: _amountError,
                helperText: 'المتبقي ${formatMoney(max)} ج.م · يقبل الأرقام العربية واللاتينية',
                suffixIcon: const Padding(
                  padding: EdgeInsetsDirectional.only(end: 12, top: 14),
                  child: Text('ج.م', style: UiText.muted),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.done_all, size: 18, color: AppColors.leaf),
                label: const Text('كامل المتبقي'),
                materialTapTargetSize: MaterialTapTargetSize.padded,
                backgroundColor: AppColors.leafLight,
                side: const BorderSide(color: UiColors.paidBorder),
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.leaf),
                onPressed: busy || max <= 0 ? null : () => _fillRemaining(max),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LabeledField(
            label: 'طريقة الدفع',
            errorText: _methodError,
            child: SegmentedChoice<PaymentMethod>(
              semanticLabel: 'طريقة الدفع',
              hasError: _methodError != null,
              options: [for (final m in PaymentMethod.values) SegmentOption(m, m.label)],
              value: _method,
              onChanged: busy ? null : (m) => setState(() => _method = m),
            ),
          ),
          const SizedBox(height: 14),
          LabeledField(
            label: 'تاريخ الدفع',
            child: DateTimeField(
              value: _paidAt,
              enabled: !busy,
              errorText: _paidAtError,
              onChanged: (v) => setState(() {
                _paidAt = v;
                _paidAtError = null;
              }),
            ),
          ),
          const SizedBox(height: 14),
          LabeledField(
            label: 'ملاحظات (اختياري)',
            child: TextField(
              controller: _notes,
              enabled: !busy,
              maxLength: 1000,
              minLines: 1,
              maxLines: 3,
              onChanged: (_) {
                if (_notesError != null) setState(() => _notesError = null);
              },
              decoration: uiInputDecoration(hint: 'مثل: سلّمها كريم يدًا بيد', errorText: _notesError)
                  .copyWith(counterText: ''),
            ),
          ),
          const SizedBox(height: 10),
          const _Note(
            icon: Icons.lock_open_outlined,
            text: 'يمكن تسجيل الدفعة حتى لو كان البراد مقفّلًا. دون اتصال تُحفظ على الجهاز وتُرسل تلقائيًا.',
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            InlineBanner(kind: BannerKind.error, message: _error!),
          ],
          const SizedBox(height: 16),
          AppButton(
            label: 'حفظ الدفعة',
            icon: Icons.check,
            busy: _saving,
            busyLabel: 'جارٍ الحفظ',
            expand: true,
            onPressed: _done || max <= 0 ? null : _submit,
          ),
        ],
      ),
    );
  }
}

// ============================================================================ عناصر مساعدة

/// ملخص العملية المختارة: المستفيد، البراد، القيمة، المدفوع، المتبقي.
class _TargetSummary extends StatelessWidget {
  const _TargetSummary({required this.target, required this.pendingPiasters, required this.onChange});

  final PayableOperation target;

  /// دفعات هذه العملية المحفوظة على الجهاز «بانتظار المزامنة».
  final int pendingPiasters;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final t = target;
    final farmer = t.payeeType == PayeeType.farmer;
    final date = formatArabicDate(t.occurredAt);
    final max = (t.remainingPiasters - pendingPiasters).clamp(0, t.remainingPiasters);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: farmer ? AppColors.pomegranateLight : AppColors.leafLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  farmer ? Icons.scale_outlined : Icons.inventory_2_outlined,
                  color: farmer ? AppColors.pomegranate : AppColors.leaf,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.payeeName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, height: 1.4)),
                    Text('${t.payeeType.label} · ${t.title}', style: UiText.small),
                    if (t.details.isNotEmpty) Text(t.details, style: UiText.small),
                    if (date.isNotEmpty) Text(date, style: UiText.small),
                  ],
                ),
              ),
              if (onChange != null)
                TextButton(
                  onPressed: onChange,
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  child: const Text('تغيير'),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _Figure(label: 'القيمة', piasters: t.valuePiasters)),
              Expanded(child: _Figure(label: 'المدفوع', piasters: t.paidPiasters, color: AppColors.leaf)),
              Expanded(child: _Figure(label: 'المتبقي', piasters: t.remainingPiasters, color: AppColors.amber)),
            ],
          ),
          const SizedBox(height: 10),
          PaidProgressBar(paid: t.paidPiasters, total: t.valuePiasters),
          if (pendingPiasters > 0) ...[
            const SizedBox(height: 12),
            InlineBanner(
              kind: BannerKind.info,
              message: 'على هذا الجهاز دفعات لهذه العملية بانتظار المزامنة بمبلغ ${formatMoney(pendingPiasters)} ج.م، '
                  'فالحد الأقصى الآن ${formatMoney(max)} ج.م.',
            ),
          ],
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.piasters, this.color = AppColors.ink});

  final String label;
  final int piasters;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label (ج.م)', style: UiText.small.copyWith(color: color == AppColors.ink ? null : color)),
        NumberText(formatMoney(piasters), fontSize: 15.5, color: color),
      ],
    );
  }
}

/// صف قابل للاختيار في قائمة المستفيدين أو العمليات.
class _PickRow extends StatelessWidget {
  const _PickRow({required this.title, required this.subtitle, required this.remaining, required this.onTap});

  final String title;
  final String subtitle;
  final int remaining;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: UiColors.divider))),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, height: 1.4)),
                    if (subtitle.isNotEmpty) Text(subtitle, style: UiText.small),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('المتبقي', style: UiText.small.copyWith(color: AppColors.amber)),
                  MoneyText(remaining, fontSize: 15, color: AppColors.amber, unitFontSize: 11.5),
                ],
              ),
              const Icon(Icons.chevron_right, color: AppColors.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickEmpty extends StatelessWidget {
  const _PickEmpty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(text, style: UiText.muted));
}

/// ملاحظة صغيرة بأيقونة.
class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: AppColors.ivory, borderRadius: BorderRadius.circular(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 16, color: AppColors.inkSecondary)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12.5, color: AppColors.inkSecondary, height: 1.5)),
          ),
        ],
      ),
    );
  }
}
