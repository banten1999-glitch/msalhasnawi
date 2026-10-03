import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/request_id.dart';
import '../../core/format/numbers.dart';
import '../../core/models/dashboard.dart';
import '../../core/models/records.dart';
import '../../core/models/settings.dart';
import '../../core/models/user.dart';
import '../../core/sync/outbox.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'cooler_format.dart';
import 'cooler_widgets.dart';
import 'purchase_form_parts.dart';

/// نموذج شراء من مزارع. [purchase] != null ⇒ تعديل عملية موجودة؛ وإلا إضافة جديدة في [coolerId] (أو البراد المفتوح الحالي).
///
/// الحساب حي أثناء الكتابة بأعداد صحيحة كما في الخادم (docs/API.md §5). الإضافة تمر عبر قائمة «بانتظار
/// المزامنة» (outbox.submit) فتُحفظ على الجهاز إن انقطع الاتصال، والتعديل يرسل الحقول المعدّلة فقط.
class PurchaseFormScreen extends StatefulWidget {
  const PurchaseFormScreen({super.key, this.coolerId, this.purchase});

  final String? coolerId;
  final Purchase? purchase;

  @override
  State<PurchaseFormScreen> createState() => _PurchaseFormScreenState();
}

/// تقييم النموذج: الأرقام الصالحة (بالقرش والجرام) والأخطاء تحت الحقول.
class _Eval {
  final errors = <String, String>{};
  final sampleRowErrors = <String?>[];
  int? boxes;

  /// متوسط الوزن الصافي المعتمد (مباشرة أو من العينة) ضمن الحدود.
  int? avg;
  List<int> samples = const [];
  int tare = 0;
  int? grossMean;
  int? sampleNet;
  int? price;
  int? weight;
  int? value;

  /// المدفوع مع العملية (كامل = القيمة، جزئي = المبلغ، بدون = 0).
  int? amount;
}

/// ترتيب الأقسام للتمرير إلى أول خطأ.
const _sectionOrder = ['coolerId', 'farmer', 'boxes', 'weight', 'price', 'notes', 'payment'];

String _sectionOf(String key) => switch (key) {
      'avgWeightGrams' || 'weightMethod' || 'sampleWeightsGrams' || 'tareGrams' || 'sampleRows' => 'weight',
      'pricePerKgPiasters' || 'occurredAt' || 'value' => 'price',
      'payment.mode' || 'payment.amountPiasters' => 'payment',
      _ => key,
    };

/// حقل الخادم (docs/API.md §6) ← مفتاح الخطأ في النموذج. '' ⇒ يُعرض أعلى النموذج.
String _keyForField(String? field) => switch (field) {
      'farmerId' || 'newFarmerName' => 'farmer',
      'payment' || 'payment.mode' || 'payment.method' => 'payment.mode',
      'payment.amountPiasters' => 'payment.amountPiasters',
      'coolerId' ||
      'boxes' ||
      'avgWeightGrams' ||
      'weightMethod' ||
      'sampleWeightsGrams' ||
      'tareGrams' ||
      'pricePerKgPiasters' ||
      'occurredAt' ||
      'notes' =>
        field!,
      _ => '',
    };

class _PurchaseFormScreenState extends State<PurchaseFormScreen> {
  bool get _editing => widget.purchase != null;

  // ------------------------------------------------------------------ البيانات المحمّلة
  bool _started = false;
  bool _loading = true;
  Object? _loadError;
  List<CoolerSummary> _openCoolers = const [];
  CoolerSummary? _editCooler;
  String? _coolerNotice;
  List<Farmer>? _farmers;
  Object? _farmersError;
  BusinessSettings _settings = const BusinessSettings();

  /// النسخة التي يُعدَّل عليها (من الخادم عند الفتح).
  Purchase? _base;

  // ------------------------------------------------------------------ الحقول
  String? _coolerId;
  Farmer? _farmer;
  String? _newFarmerName;
  final _farmerQuery = TextEditingController();
  final _farmerFocus = FocusNode();
  final _boxes = TextEditingController();
  WeightMethod _method = WeightMethod.direct;
  final _avg = TextEditingController();
  final _samples = <TextEditingController>[TextEditingController()];
  final _sampleFocus = <FocusNode>[FocusNode()];
  final _tare = TextEditingController();
  bool _tareTouched = false;
  final _price = TextEditingController();
  DateTime? _occurredAt;
  final _notes = TextEditingController();
  PaymentMode _payMode = PaymentMode.none;
  final _payAmount = TextEditingController();
  PaymentMethod _payMethod = PaymentMethod.cash;

  // ------------------------------------------------------------------ الحفظ
  bool _saving = false;
  bool _savingAnother = false;

  /// بعد أول محاولة حفظ تظهر أخطاء «مطلوب» أيضًا.
  bool _submitted = false;
  final _serverErrors = <String, String>{};
  String? _formError;
  Purchase? _conflictCurrent;

  /// العملية لا تُعدَّل (براد مقفّل، عملية ملغاة، أو لا صلاحية) مع السبب.
  String? _readOnlyReason;

  /// سبب منع الحفظ (null ⇒ النموذج قابل للحفظ).
  String? get _lockReason {
    if (_readOnlyReason != null) return _readOnlyReason;
    if (!_editing && !permissionsOf(AppScope.of(context).auth.user).recordPurchases) {
      return 'لا تملك صلاحية تسجيل المشتريات. اطلبها من المدير إن كنت تحتاجها.';
    }
    return null;
  }
  final _request = SubmissionRequestId();

  final _scroll = ScrollController();
  final _barKey = GlobalKey();
  final _sectionKeys = {for (final s in _sectionOrder) s: GlobalKey()};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _tare.text = kgInput(_settings.emptyBoxGrams);
    unawaited(_load());
  }

  @override
  void dispose() {
    for (final c in [_farmerQuery, _boxes, _avg, _tare, _price, _notes, _payAmount, ..._samples]) {
      c.dispose();
    }
    for (final f in [_farmerFocus, ..._sampleFocus]) {
      f.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ التحميل

  Future<void> _load() async {
    final api = AppScope.of(context).api;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    unawaited(_loadFarmers());
    unawaited(_loadSettings());
    try {
      if (_editing) {
        final p = widget.purchase!;
        final detail = await api.getCooler(p.coolerId);
        if (!mounted) return;
        final fresh = detail.purchases.where((x) => x.id == p.id).firstOrNull ?? p;
        setState(() {
          _editCooler = detail.cooler;
          _prefill(fresh);
          _loading = false;
        });
      } else {
        final list = await api.listCoolers(status: 'open');
        if (!mounted) return;
        setState(() {
          _setOpenCoolers(list);
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadFarmers() async {
    final api = AppScope.of(context).api;
    if (_farmersError != null) setState(() => _farmersError = null);
    try {
      final list = await api.listFarmers();
      if (!mounted) return;
      setState(() {
        _farmers = list.where((f) => f.active).toList();
        // في التعديل: استبدال المزارع المؤقت (الاسم فقط) ببياناته الكاملة.
        final f = _farmer;
        if (f != null) _farmer = _farmers!.where((x) => x.id == f.id).firstOrNull ?? f;
      });
    } catch (e) {
      if (mounted) setState(() => _farmersError = e);
    }
  }

  Future<void> _loadSettings() async {
    try {
      final s = await AppScope.of(context).api.settings();
      if (!mounted) return;
      setState(() {
        _settings = s;
        if (!_tareTouched) _tare.text = kgInput(s.emptyBoxGrams);
      });
    } catch (_) {
      // يبقى الافتراضي (1.9 كغ) والحقل قابلًا للتعديل.
    }
  }

  Future<void> _reloadCoolers() async {
    try {
      final list = await AppScope.of(context).api.listCoolers(status: 'open');
      if (mounted) setState(() => _setOpenCoolers(list));
    } catch (_) {
      // تبقى القائمة الحالية.
    }
  }

  static int _newestFirst(CoolerSummary a, CoolerSummary b) {
    final t = (b.openedAt ?? '').compareTo(a.openedAt ?? '');
    return t != 0 ? t : b.no.compareTo(a.no);
  }

  /// البراد المطلوب إن كان مفتوحًا، وإلا أحدث براد مفتوح.
  void _setOpenCoolers(List<CoolerSummary> list) {
    final open = list.where((c) => c.isOpen).toList()..sort(_newestFirst);
    _openCoolers = open;
    if (_coolerId != null && open.any((c) => c.id == _coolerId)) return;
    final wanted = _coolerId ?? widget.coolerId;
    if (wanted != null && open.any((c) => c.id == wanted)) {
      _coolerId = wanted;
      _coolerNotice = null;
      return;
    }
    _coolerId = open.firstOrNull?.id;
    _coolerNotice = wanted != null && open.isNotEmpty
        ? 'البراد المطلوب مقفّل أو غير موجود، فاخترنا ${open.first.title}. يمكنك تغييره.'
        : null;
  }

  CoolerSummary? get _selectedCooler =>
      _editing ? _editCooler : _openCoolers.where((c) => c.id == _coolerId).firstOrNull;

  void _prefill(Purchase p) {
    _base = p;
    _conflictCurrent = null;
    _coolerId = p.coolerId;
    _farmer = _farmers?.where((f) => f.id == p.farmerId).firstOrNull ??
        Farmer(id: p.farmerId, no: 0, name: p.farmerName);
    _newFarmerName = null;
    _farmerQuery.clear();
    _boxes.text = '${p.boxes}';
    _method = p.weightMethod;
    _avg.text = kgInput(p.avgWeightGrams);
    if (p.weightMethod == WeightMethod.sample && p.sampleWeightsGrams.isNotEmpty) {
      _setSampleRows([for (final g in p.sampleWeightsGrams) kgInput(g)]);
    }
    if (p.tareGrams != null) {
      _tare.text = kgInput(p.tareGrams!);
      _tareTouched = true;
    }
    _price.text = moneyInput(p.pricePerKgPiasters);
    _occurredAt = parseWallClock(p.occurredAt);
    _notes.text = p.notes ?? '';
    _serverErrors.clear();
    _formError = null;
    _submitted = false;

    final user = AppScope.of(context).auth.user;
    final open = _editCooler?.isOpen ?? true;
    if (!open) {
      _readOnlyReason = 'البراد مقفّل — لا يمكن تعديل مشترياته. اطلب من المدير إعادة فتحه إن لزم التعديل.';
    } else if (!p.active) {
      _readOnlyReason = 'هذه العملية ملغاة، فلا يمكن تعديلها. سجّل عملية جديدة إن لزم.';
    } else if (!canChangePurchase(p, coolerOpen: true, user: user)) {
      _readOnlyReason = permissionsOf(user).recordPurchases
          ? 'هذه العملية سجّلها مستخدم آخر، وتعديلها يحتاج صلاحية «تعديل عمليات الآخرين».'
          : 'لا تملك صلاحية تسجيل المشتريات أو تعديلها.';
    } else {
      _readOnlyReason = null;
    }
  }

  /// يستبدل صفوف العينة بالقيم المعطاة (المتحكمات القديمة تُحرَّر بعد الإطار).
  void _setSampleRows(List<String> values) {
    final old = [..._samples];
    final oldFocus = [..._sampleFocus];
    _samples
      ..clear()
      ..addAll([for (final v in values.isEmpty ? [''] : values) TextEditingController(text: v)]);
    _sampleFocus
      ..clear()
      ..addAll([for (var i = 0; i < _samples.length; i++) FocusNode()]);
    _disposeLater(old, oldFocus);
  }

  void _disposeLater(List<TextEditingController> controllers, List<FocusNode> nodes) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in controllers) {
        c.dispose();
      }
      for (final f in nodes) {
        f.dispose();
      }
    });
  }

  // ------------------------------------------------------------------ التقييم

  String _rangeKg(int minG, int maxG) => 'بين ${kgExact(minG)} و${kgExact(maxG)} كغ';

  _Eval _evaluate({required bool all}) {
    final e = _Eval();
    final err = e.errors;

    if (!_editing && _coolerId == null && all) err['coolerId'] = 'اختر البراد الذي تُحمَّل فيه الصناديق.';

    if (_farmer == null && _newFarmerName == null && all) {
      err['farmer'] = _farmerQuery.text.trim().isEmpty
          ? '«المزارع» مطلوب. اكتب اسمه أو رقمه واختره من القائمة.'
          : 'اختر المزارع من القائمة تحت الحقل، أو اضغط «مزارع جديد» لإضافته.';
    }

    final b = parseAmount(_boxes.text, 0);
    if (b.empty) {
      if (all) err['boxes'] = '«عدد الصناديق» مطلوب. اكتب عدد الصناديق، مثل 50.';
    } else if (b.invalid) {
      err['boxes'] = '«عدد الصناديق» يجب أن يكون رقمًا صحيحًا دون كسور، مثل 50.';
    } else if (b.value! < 1 || b.value! > PurchaseLimits.boxesMax) {
      err['boxes'] = '«عدد الصناديق» يجب أن يكون بين 1 و${formatCount(PurchaseLimits.boxesMax)}.';
    } else {
      e.boxes = b.value;
    }

    if (_method == WeightMethod.direct) {
      final a = parseAmount(_avg.text, 3);
      if (a.empty) {
        if (all) err['avgWeightGrams'] = '«متوسط الوزن الصافي للصندوق» مطلوب. اكتبه بالكيلو، مثل 11 أو 10.6.';
      } else if (a.invalid) {
        err['avgWeightGrams'] = a.tooManyDecimals
            ? '«متوسط الوزن الصافي للصندوق» يقبل حتى 3 منازل عشرية (مثل 10.625).'
            : '«متوسط الوزن الصافي للصندوق» رقم غير صحيح. اكتبه بالكيلو، مثل 11 أو 10.6.';
      } else if (a.value! < 1 || a.value! > PurchaseLimits.avgWeightMaxGrams) {
        err['avgWeightGrams'] =
            '«متوسط الوزن الصافي للصندوق» يجب أن يكون ${_rangeKg(1, PurchaseLimits.avgWeightMaxGrams)}.';
      } else {
        e.avg = a.value;
      }
    } else {
      _evaluateSample(e, all: all);
    }

    final p = parseAmount(_price.text, 2);
    if (p.empty) {
      if (all) err['pricePerKgPiasters'] = '«سعر الكيلو» مطلوب. اكتبه بالجنيه، مثل 15 أو 14.75.';
    } else if (p.invalid) {
      err['pricePerKgPiasters'] = p.tooManyDecimals
          ? '«سعر الكيلو» يقبل قرشين على الأكثر (منزلتان عشريتان)، مثل 14.75.'
          : '«سعر الكيلو» رقم غير صحيح. اكتبه بالجنيه، مثل 15 أو 14.75.';
    } else if (p.value! < 1 || p.value! > PurchaseLimits.priceMaxPiasters) {
      err['pricePerKgPiasters'] =
          '«سعر الكيلو» يجب أن يكون بين ${formatMoney(1)} و${formatMoney(PurchaseLimits.priceMaxPiasters)} ج.م.';
    } else {
      e.price = p.value;
    }

    if (e.boxes != null && e.avg != null) {
      e.weight = purchaseWeightGrams(e.boxes!, e.avg!);
      if (e.price != null) e.value = purchaseValuePiasters(e.weight!, e.price!);
    }

    if (_editing) {
      final paid = _base?.paidPiasters ?? 0;
      if (e.value != null && e.value! < paid) {
        err['value'] = 'القيمة الجديدة (${formatMoney(e.value!)} ج.م) أقل من المدفوع فعلًا (${formatMoney(paid)} ج.م). '
            'ألغِ دفعة أولًا أو صحّح الأرقام.';
      }
    } else {
      switch (_effectivePayMode) {
        case PaymentMode.none:
          e.amount = 0;
        case PaymentMode.full:
          e.amount = e.value;
        case PaymentMode.partial:
          final m = parseAmount(_payAmount.text, 2);
          if (m.empty) {
            if (all) err['payment.amountPiasters'] = '«المبلغ المدفوع» مطلوب في الدفع الجزئي. اكتب المبلغ المدفوع الآن.';
          } else if (m.invalid) {
            err['payment.amountPiasters'] = '«المبلغ المدفوع» رقم غير صحيح. اكتبه بالجنيه، مثل 2000 أو 1500.50.';
          } else if (m.value! <= 0) {
            err['payment.amountPiasters'] = '«المبلغ المدفوع» يجب أن يكون أكبر من صفر.';
          } else if (e.value != null && m.value! >= e.value!) {
            err['payment.amountPiasters'] = '«المبلغ المدفوع» (${formatMoney(m.value!)} ج.م) يجب أن يكون أقل من قيمة '
                'العملية (${formatMoney(e.value!)} ج.م) في الدفع الجزئي. اختر «مدفوع بالكامل» إن دُفعت القيمة كلها.';
          } else {
            e.amount = m.value;
          }
      }
    }

    if (_notes.text.trim().length > PurchaseLimits.notesMax) {
      err['notes'] = '«الملاحظات» أطول من المسموح (${PurchaseLimits.notesMax} حرف). اختصرها.';
    }
    return e;
  }

  void _evaluateSample(_Eval e, {required bool all}) {
    final err = e.errors;
    var tare = _settings.emptyBoxGrams;
    final t = parseAmount(_tare.text, 3);
    if (t.invalid) {
      err['tareGrams'] = '«وزن الصندوق الفارغ» رقم غير صحيح. اكتبه بالكيلو، مثل 1.9.';
    } else if (!t.empty) {
      if (t.value! > PurchaseLimits.tareMaxGrams) {
        err['tareGrams'] = '«وزن الصندوق الفارغ» يجب أن يكون ${_rangeKg(0, PurchaseLimits.tareMaxGrams)}.';
      } else {
        tare = t.value!;
      }
    }
    e.tare = tare;

    final samples = <int>[];
    var rowsInvalid = false;
    for (var i = 0; i < _samples.length; i++) {
      final s = parseAmount(_samples[i].text, 3);
      String? rowError;
      if (s.empty) {
        rowError = null;
      } else if (s.invalid) {
        rowError = s.tooManyDecimals ? 'حتى 3 منازل عشرية.' : 'رقم غير صحيح. اكتب الوزن بالكيلو، مثل 12.9.';
      } else if (s.value! < 1 || s.value! > PurchaseLimits.sampleWeightMaxGrams) {
        rowError = 'الوزن يجب أن يكون ${_rangeKg(1, PurchaseLimits.sampleWeightMaxGrams)}.';
      } else {
        samples.add(s.value!);
      }
      e.sampleRowErrors.add(rowError);
      if (rowError != null) rowsInvalid = true;
    }
    e.samples = samples;
    if (rowsInvalid) err['sampleRows'] = 'صحّح أوزان العينة المعلّمة بالأحمر.';

    if (samples.isEmpty) {
      if (all && !rowsInvalid) err['sampleWeightsGrams'] = '«أوزان العينة» مطلوبة. أدخل وزن صندوق واحد على الأقل.';
      return;
    }
    if (samples.length > PurchaseLimits.sampleMaxCount) {
      err['sampleWeightsGrams'] = '«أوزان العينة» أكثر من ${PurchaseLimits.sampleMaxCount} وزنًا. قلّل صناديق العينة.';
      return;
    }
    e.grossMean = roundHalfUpDiv(samples.fold<int>(0, (a, b) => a + b), samples.length);
    if (err.containsKey('tareGrams')) return;
    final net = sampleNetAverageGrams(samples, tare);
    e.sampleNet = net;
    if (net <= 0) {
      err['sampleWeightsGrams'] = 'متوسط أوزان العينة (${kgExact(e.grossMean!)} كغ) لا يزيد على وزن الصندوق الفارغ '
          '(${kgExact(tare)} كغ). راجع أوزان العينة أو وزن الصندوق الفارغ.';
    } else if (net > PurchaseLimits.avgWeightMaxGrams) {
      err['sampleWeightsGrams'] = 'المتوسط الصافي من العينة (${kgExact(net)} كغ) أكبر من الحد '
          '(${kgExact(PurchaseLimits.avgWeightMaxGrams)} كغ). راجع الأوزان.';
    } else if (!rowsInvalid) {
      e.avg = net;
    }
  }

  PaymentMode get _effectivePayMode =>
      permissionsOf(AppScope.of(context).auth.user).recordPayments ? _payMode : PaymentMode.none;

  String? _err(_Eval e, String key) => _serverErrors[key] ?? e.errors[key];

  /// يُستدعى عند تعديل حقل: يمسح خطأ الخادم عنه ويعيد الحساب.
  void _edited(List<String> keys) {
    setState(() {
      for (final k in keys) {
        _serverErrors.remove(k);
      }
    });
  }

  // ------------------------------------------------------------------ تعديلات العملية

  Map<String, dynamic> _changesFor(_Eval e) {
    final b = _base!;
    final ch = <String, dynamic>{};
    final f = _farmer;
    if (f != null && f.id != b.farmerId) ch['farmerId'] = f.id;
    if (e.boxes != null && e.boxes != b.boxes) ch['boxes'] = e.boxes;
    if (_method != b.weightMethod) ch['weightMethod'] = _method.wire;
    if (e.avg != null && e.avg != b.avgWeightGrams) ch['avgWeightGrams'] = e.avg;
    if (_method == WeightMethod.sample) {
      if (!listEquals(e.samples, b.sampleWeightsGrams)) ch['sampleWeightsGrams'] = e.samples;
      if (e.tare != b.tareGrams) ch['tareGrams'] = e.tare;
    }
    if (e.price != null && e.price != b.pricePerKgPiasters) ch['pricePerKgPiasters'] = e.price;
    final original = parseWallClock(b.occurredAt);
    if (_occurredAt != original) ch['occurredAt'] = toWallClockText(_occurredAt ?? DateTime.now());
    final notes = _notes.text.trim();
    if (notes != (b.notes ?? '').trim()) ch['notes'] = notes;
    return ch;
  }

  // ------------------------------------------------------------------ الحفظ

  /// نص مكتوب في البحث يطابق اسم مزارع واحد تمامًا ⇒ يُختار تلقائيًا.
  void _resolveTypedFarmer() {
    if (_farmer != null || _newFarmerName != null) return;
    final q = _farmerQuery.text.trim();
    if (q.isEmpty) return;
    final exact = (_farmers ?? const <Farmer>[]).where((f) => sameName(f.name, q)).toList();
    if (exact.length == 1) _farmer = exact.single;
  }

  Future<void> _save({bool another = false}) async {
    if (_saving || _lockReason != null) return;
    _resolveTypedFarmer();
    final e = _evaluate(all: true);
    if (e.errors.isNotEmpty) {
      setState(() {
        _submitted = true;
        _formError = null;
      });
      _scrollToFirstError({...e.errors.keys, ..._serverErrors.keys});
      return;
    }
    if (_editing) return _saveEdit(e);

    final scope = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final mode = _effectivePayMode;
    final input = PurchaseInput(
      coolerId: _coolerId!,
      farmerId: _farmer?.id,
      newFarmerName: _farmer == null ? _newFarmerName : null,
      boxes: e.boxes!,
      avgWeightGrams: e.avg!,
      weightMethod: _method,
      sampleWeightsGrams: _method == WeightMethod.sample ? e.samples : const [],
      tareGrams: _method == WeightMethod.sample ? e.tare : null,
      pricePerKgPiasters: e.price!,
      occurredAt: _occurredAt == null ? null : toWallClockText(_occurredAt!),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      payment: PaymentModeInput(
        mode: mode,
        amountPiasters: mode == PaymentMode.partial ? e.amount : null,
        method: _payMethod,
      ),
    );
    final payload = input.toJson();
    final requestId = _request.idFor(payload);
    final farmerName = _farmer?.name ?? _newFarmerName!;
    setState(() {
      _saving = true;
      _savingAnother = another;
      _submitted = true;
      _formError = null;
      _serverErrors.clear();
    });
    try {
      final outcome = await scope.outbox.submit(
        action: 'purchases.create',
        payload: payload,
        requestId: requestId,
        label: 'شراء · $farmerName · ${e.boxes} صندوق',
        coolerId: input.coolerId,
      );
      _request.reset();
      if (outcome is SubmitSent) _absorbResult(outcome.data);
      scope.changes.bump();
      final queued = outcome is SubmitQueued;
      // عند البقاء في النموذج تطفو الرسالة فوق الشريط السفلي حتى لا تغطي أزرار الحفظ.
      final bar = another ? _barKey.currentContext?.findRenderObject() : null;
      final barHeight = bar is RenderBox && bar.hasSize ? bar.size.height : null;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(queued ? 'حُفظت على الجهاز — بانتظار المزامنة' : 'تم الحفظ في الملف'),
          behavior: barHeight == null ? null : SnackBarBehavior.floating,
          margin: barHeight == null ? null : EdgeInsets.fromLTRB(16, 0, 16, barHeight + 8),
          action: queued
              ? SnackBarAction(label: 'عرض', onPressed: () => AppRoutes.openPendingSync(navigator.context))
              : null,
        ));
      if (!mounted) return;
      if (another) {
        setState(() {
          _saving = false;
          _resetForNext();
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_scroll.hasClients) _scroll.jumpTo(0);
          _farmerFocus.requestFocus();
        });
      } else {
        navigator.pop();
      }
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _applyError(err);
      });
      _scrollToFirstError(_serverErrors.keys);
    }
  }

  Future<void> _saveEdit(_Eval e) async {
    final b = _base!;
    final changes = _changesFor(e);
    if (changes.isEmpty) return;
    final scope = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final requestId = _request.idFor({'id': b.id, 'expectedVersion': b.version, 'changes': changes});
    setState(() {
      _saving = true;
      _submitted = true;
      _formError = null;
      _serverErrors.clear();
    });
    try {
      await scope.api.updatePurchase(id: b.id, expectedVersion: b.version, changes: changes, requestId: requestId);
      _request.reset();
      scope.changes.bump();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('تم حفظ التعديل في الملف')));
      if (mounted) navigator.pop();
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _applyError(err);
      });
      _scrollToFirstError(_serverErrors.keys);
    }
  }

  /// يضيف المزارع الجديد (إن أُنشئ مع العملية) إلى القائمة ليُختار مباشرة في العملية التالية.
  void _absorbResult(Map<String, dynamic> data) {
    try {
      final f = PurchaseResult.fromJson(data).farmer;
      if (f != null && _farmers != null && !_farmers!.any((x) => x.id == f.id)) {
        _farmers = [..._farmers!, f];
      }
    } catch (_) {
      // الرد ناقص: لا يؤثر على الحفظ نفسه.
    }
  }

  void _applyError(Object err) {
    if (err is ApiException) {
      if (err.code == ApiErrorCode.validation) {
        final key = _keyForField(err.field);
        final existing = err.details['existing'];
        if (existing is Map) {
          try {
            final f = Farmer.fromJson(existing.cast<String, dynamic>());
            if (_farmers != null && !_farmers!.any((x) => x.id == f.id)) _farmers = [..._farmers!, f];
          } catch (_) {}
        }
        if (key.isNotEmpty) {
          _serverErrors[key] = err.message;
          return;
        }
      }
      if (err.code == ApiErrorCode.coolerClosed) {
        if (_editing) {
          _readOnlyReason = err.message;
        } else {
          _formError = err.message;
          unawaited(_reloadCoolers());
        }
        return;
      }
      if (err.code == ApiErrorCode.conflict) {
        final current = err.details['current'];
        try {
          _conflictCurrent = current is Map ? Purchase.fromJson(current.cast<String, dynamic>()) : null;
        } catch (_) {
          _conflictCurrent = null;
        }
        _formError = 'عدّل شخص آخر هذه العملية بعد فتحها. حدّث البيانات، راجعها، ثم أعد المحاولة.';
        return;
      }
    }
    _formError = errorMessage(err);
  }

  /// «حفظ وإضافة مزارع آخر»: يبقى البراد والسعر والوقت وطريقة الوزن والفارغ وطريقة الدفع.
  void _resetForNext() {
    _farmer = null;
    _newFarmerName = null;
    _farmerQuery.clear();
    _boxes.clear();
    _avg.clear();
    _setSampleRows(const []);
    _notes.clear();
    _payAmount.clear();
    _submitted = false;
    _serverErrors.clear();
    _formError = null;
  }

  void _scrollToFirstError(Iterable<String> keys) {
    final sections = keys.map(_sectionOf).toSet();
    final first = _sectionOrder.where(sections.contains).firstOrNull;
    if (first == null) {
      if (_scroll.hasClients) {
        unawaited(_scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut));
      }
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _sectionKeys[first]?.currentContext;
      if (ctx != null && ctx.mounted) {
        unawaited(Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 250), alignment: 0.05));
      }
    });
  }

  // ------------------------------------------------------------------ أحداث الحقول

  void _selectFarmer(Farmer f) {
    setState(() {
      _farmer = f;
      _newFarmerName = null;
      _farmerQuery.clear();
      _serverErrors.remove('farmer');
    });
  }

  void _newFarmer(String name) {
    final n = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (n.isEmpty) return;
    setState(() {
      _farmer = null;
      _newFarmerName = n;
      _farmerQuery.clear();
      _serverErrors.remove('farmer');
    });
  }

  void _clearFarmer() {
    setState(() {
      _farmer = null;
      _newFarmerName = null;
      _serverErrors.remove('farmer');
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _farmerFocus.requestFocus();
    });
  }

  void _setMethod(WeightMethod m) {
    setState(() {
      _method = m;
      for (final k in ['weightMethod', 'avgWeightGrams', 'sampleWeightsGrams', 'tareGrams']) {
        _serverErrors.remove(k);
      }
      if (m == WeightMethod.sample && _tare.text.trim().isEmpty) _tare.text = kgInput(_settings.emptyBoxGrams);
    });
  }

  void _addSample() {
    if (_samples.length >= PurchaseLimits.sampleMaxCount) return;
    final node = FocusNode();
    setState(() {
      _samples.add(TextEditingController());
      _sampleFocus.add(node);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) node.requestFocus();
    });
  }

  void _removeSample(int i) {
    if (_samples.length == 1) {
      _samples.first.clear();
      _edited(['sampleWeightsGrams', 'avgWeightGrams']);
      return;
    }
    final c = _samples.removeAt(i);
    final f = _sampleFocus.removeAt(i);
    _disposeLater([c], [f]);
    _edited(['sampleWeightsGrams', 'avgWeightGrams']);
  }

  void _sampleSubmitted(int i) {
    if (i == _samples.length - 1) {
      if (_samples[i].text.trim().isNotEmpty) _addSample();
    } else {
      _sampleFocus[i + 1].requestFocus();
    }
  }

  Future<void> _pickCooler() async {
    final id = await showAdaptiveSheet<String>(
      context,
      CoolerChoiceList(coolers: _openCoolers, selectedId: _coolerId),
      maxWidth: 480,
    );
    if (id == null || !mounted) return;
    setState(() {
      _coolerId = id;
      _coolerNotice = null;
      _serverErrors.remove('coolerId');
    });
  }

  Future<void> _createCooler() async {
    final c = await AppRoutes.createCooler(context);
    if (c == null || !mounted) return;
    setState(() {
      _openCoolers = [c, ..._openCoolers.where((x) => x.id != c.id)];
      _coolerId = c.id;
      _coolerNotice = null;
    });
  }

  // ------------------------------------------------------------------ البناء

  @override
  Widget build(BuildContext context) {
    final title = _editing ? 'تعديل عملية شراء' : 'شراء من مزارع';
    Widget body;
    if (_loading) {
      body = const LoadingSkeleton(tiles: 0, lines: 6);
    } else if (_loadError != null) {
      body = ErrorView.fromError(
        _loadError!,
        onRetry: _load,
        title: _editing ? 'تعذّر تحميل العملية' : 'تعذّر تحميل البرادات المفتوحة',
      );
    } else if (!_editing && _openCoolers.isEmpty) {
      body = _noOpenCooler();
    } else {
      body = _form();
    }
    return Scaffold(
      backgroundColor: AppColors.ivory,
      appBar: coolerAppBar(title, subtitle: _selectedCooler?.title),
      body: body,
    );
  }

  Widget _noOpenCooler() {
    final canCreate = permissionsOf(AppScope.of(context).auth.user).recordPurchases;
    return EmptyState(
      icon: Icons.local_shipping_outlined,
      title: 'لا يوجد براد مفتوح',
      message: canCreate
          ? 'تُسجَّل مشتريات الرمان داخل براد مفتوح. أنشئ برادًا جديدًا، ثم أكمل تسجيل الشراء هنا.'
          : 'تُسجَّل مشتريات الرمان داخل براد مفتوح، ولا يوجد براد مفتوح الآن. اطلب من المسؤول فتح براد.',
      actionLabel: canCreate ? 'إنشاء براد' : null,
      actionIcon: Icons.add,
      onAction: canCreate ? _createCooler : null,
    );
  }

  Widget _form() {
    final wide = isWideLayout(context);
    final user = AppScope.of(context).auth.user;
    final perms = permissionsOf(user);
    final e = _evaluate(all: _submitted);
    final readOnly = _lockReason != null;
    final enabled = !_saving && !readOnly;
    final buttons = readOnly ? const <Widget>[] : _buttons(e, wide: wide);

    final sections = <Widget>[
      ..._banners(),
      _section('البراد والمزارع', [_coolerField(e), _farmerField(e, perms, enabled)]),
      _section('الصناديق والوزن', [_boxesField(e, enabled), ..._weightFields(e, enabled)], key: _sectionKeys['boxes']),
      _section('السعر والوقت', [_priceField(e, enabled), _dateField(e, enabled), _notesField(e, enabled)],
          key: _sectionKeys['price']),
      if (!wide) _totals(e),
      if (!_editing) _paymentSection(e, perms, enabled) else _editPaymentsNote(),
    ];

    if (wide) {
      return ResponsiveCenter(
        maxWidth: 1180,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(32, 16, 12, 40),
                children: [Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _spaced(sections))],
              ),
            ),
            SizedBox(
              width: 380,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 16, 32, 40),
                children: [
                  _totals(e),
                  for (final b in buttons) ...[const SizedBox(height: 10), b],
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              ResponsiveCenter(
                maxWidth: 720,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _spaced(sections)),
              ),
            ],
          ),
        ),
        if (!readOnly)
          PurchaseBottomBar(key: _barKey, weightGrams: e.weight, valuePiasters: e.value, buttons: buttons),
      ],
    );
  }

  List<Widget> _spaced(List<Widget> items) => [
        for (var i = 0; i < items.length; i++) ...[if (i > 0) const SizedBox(height: 14), items[i]],
      ];

  List<Widget> _banners() {
    final out = <Widget>[];
    final lock = _lockReason;
    if (lock != null) out.add(InlineBanner(kind: BannerKind.warning, icon: Icons.lock_outline, message: lock));
    if (_coolerNotice != null) out.add(InlineBanner(kind: BannerKind.info, message: _coolerNotice!));
    if (_formError != null) {
      out.add(InlineBanner(
        kind: BannerKind.error,
        title: _editing ? 'لم يُحفظ التعديل' : 'لم تُحفظ العملية',
        message: _formError!,
        actionLabel: _conflictCurrent != null ? 'تحميل النسخة الحالية' : null,
        onAction: _conflictCurrent == null ? null : () => setState(() => _prefill(_conflictCurrent!)),
      ));
    }
    return out;
  }

  Widget _section(String title, List<Widget> children, {Key? key}) => AppCard(
        key: key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(title),
            for (final c in children) ...[const SizedBox(height: 14), c],
          ],
        ),
      );

  Widget _coolerField(_Eval e) {
    final c = _selectedCooler;
    final canPick = !_editing && _openCoolers.length > 1 && !_saving && _lockReason == null;
    return KeyedSubtree(
      key: _sectionKeys['coolerId'],
      child: LabeledField(
        label: 'البراد',
        child: PickerField(
          text: c?.title ?? 'اختر البراد',
          subtitle: c == null ? null : [openedLine(c), operationsLabel(c.purchases)].where((s) => s.isNotEmpty).join(' · '),
          onTap: canPick ? _pickCooler : null,
          errorText: _err(e, 'coolerId'),
          trailing: canPick || c == null
              ? null
              : Padding(
                  padding: const EdgeInsetsDirectional.only(end: 10),
                  child: Center(
                    widthFactor: 1,
                    child: StatusChip(c.isOpen ? StatusKind.open : StatusKind.closed, dense: true),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _farmerField(_Eval e, UserPermissions perms, bool enabled) {
    return KeyedSubtree(
      key: _sectionKeys['farmer'],
      child: LabeledField(
        label: 'المزارع',
        child: PurchaseFarmerField(
          query: _farmerQuery,
          focusNode: _farmerFocus,
          farmers: _farmers,
          farmersError: _farmersError,
          onRetryFarmers: _loadFarmers,
          selected: _farmer,
          newName: _newFarmerName,
          canAddNew: !_editing && perms.addFarmers,
          enabled: enabled,
          errorText: _err(e, 'farmer'),
          onQueryChanged: (_) => _edited(['farmer']),
          onSelect: _selectFarmer,
          onNew: _newFarmer,
          onClear: _clearFarmer,
        ),
      ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String unit,
    required String? error,
    required bool enabled,
    required List<String> keys,
    bool decimal = true,
    String? helper,
  }) {
    return LabeledField(
      label: label,
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: decimal ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.number,
        inputFormatters: [decimal ? decimalInputFormatter : integerInputFormatter],
        textInputAction: TextInputAction.next,
        onChanged: (_) => _edited(keys),
        style: UiText.number(size: 17, weight: FontWeight.w600),
        decoration: uiInputDecoration(hint: hint, errorText: error, helperText: helper, suffixIcon: unitSuffix(unit)),
      ),
    );
  }

  Widget _boxesField(_Eval e, bool enabled) => _numberField(
        controller: _boxes,
        label: 'عدد الصناديق',
        hint: 'مثل 50',
        unit: 'صندوق',
        error: _err(e, 'boxes'),
        enabled: enabled,
        keys: const ['boxes'],
        decimal: false,
      );

  List<Widget> _weightFields(_Eval e, bool enabled) {
    final methodError = _err(e, 'weightMethod');
    return [
      KeyedSubtree(
        key: _sectionKeys['weight'],
        child: LabeledField(
          label: 'متوسط الوزن الصافي للصندوق',
          errorText: methodError,
          child: SegmentedChoice<WeightMethod>(
            semanticLabel: 'طريقة حساب الوزن',
            hasError: methodError != null,
            options: [for (final m in WeightMethod.values) SegmentOption(m, m.label)],
            value: _method,
            onChanged: enabled ? _setMethod : null,
          ),
        ),
      ),
      if (_method == WeightMethod.direct)
        _numberField(
          controller: _avg,
          label: 'المتوسط الصافي (كغ)',
          hint: 'مثل 11 أو 10.6',
          unit: 'كغ',
          error: _err(e, 'avgWeightGrams'),
          enabled: enabled,
          keys: const ['avgWeightGrams'],
          helper: 'وزن الرمان في الصندوق دون وزن الصندوق الفارغ.',
        )
      else ...[
        LabeledField(
          label: 'أوزان صناديق العينة (القائم بالكيلو)',
          child: SampleWeightsEditor(
            controllers: _samples,
            focusNodes: _sampleFocus,
            rowErrors: e.sampleRowErrors,
            enabled: enabled,
            onAdd: _addSample,
            onRemove: _removeSample,
            onChanged: (_) => _edited(['sampleWeightsGrams', 'avgWeightGrams']),
            onSubmittedRow: _sampleSubmitted,
            errorText: _serverErrors['sampleWeightsGrams'] ?? e.errors['sampleWeightsGrams'],
          ),
        ),
        _numberField(
          controller: _tare,
          label: 'وزن الصندوق الفارغ (كغ)',
          hint: 'مثل 1.9',
          unit: 'كغ',
          error: _err(e, 'tareGrams'),
          enabled: enabled,
          keys: const ['tareGrams', 'avgWeightGrams'],
          helper: 'الافتراضي من الإعدادات: ${kgExact(_settings.emptyBoxGrams)} كغ.',
        ),
        SampleSummary(
          count: e.samples.length,
          grossMeanGrams: e.grossMean,
          tareGrams: e.tare,
          netGrams: e.sampleNet,
        ),
        if (_serverErrors['avgWeightGrams'] != null) FieldError(_serverErrors['avgWeightGrams']!),
      ],
    ];
  }

  Widget _priceField(_Eval e, bool enabled) => _numberField(
        controller: _price,
        label: 'سعر الكيلو (ج.م)',
        hint: 'مثل 15 أو 14.75',
        unit: 'ج.م/كغ',
        error: _err(e, 'pricePerKgPiasters'),
        enabled: enabled,
        keys: const ['pricePerKgPiasters'],
      );

  Widget _dateField(_Eval e, bool enabled) => LabeledField(
        label: 'تاريخ ووقت العملية',
        child: DateTimeField(
          value: _occurredAt,
          enabled: enabled,
          errorText: _err(e, 'occurredAt'),
          onChanged: (v) => setState(() {
            _occurredAt = v;
            _serverErrors.remove('occurredAt');
          }),
        ),
      );

  Widget _notesField(_Eval e, bool enabled) => KeyedSubtree(
        key: _sectionKeys['notes'],
        child: LabeledField(
          label: 'ملاحظات (اختياري)',
          child: TextField(
            controller: _notes,
            enabled: enabled,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.newline,
            onChanged: (_) => _edited(['notes']),
            decoration: uiInputDecoration(hint: 'أي معلومة عن العملية', errorText: _err(e, 'notes')),
          ),
        ),
      );

  Widget _totals(_Eval e) => PurchaseTotalsCard(
        boxes: e.boxes,
        avgGrams: e.avg,
        weightGrams: e.weight,
        pricePiasters: e.price,
        valuePiasters: e.value,
        paymentMode: _editing ? null : _effectivePayMode,
        paidNowPiasters: _editing ? null : e.amount,
        alreadyPaidPiasters: _editing ? _base?.paidPiasters : null,
        valueError: e.errors['value'],
      );

  Widget _paymentSection(_Eval e, UserPermissions perms, bool enabled) {
    final canPay = perms.recordPayments;
    final mode = _effectivePayMode;
    final modeError = _err(e, 'payment.mode');
    return _section(
      'الدفع مع الشراء',
      key: _sectionKeys['payment'],
      [
        SegmentedChoice<PaymentMode>(
          semanticLabel: 'الدفع مع الشراء',
          hasError: modeError != null,
          options: [for (final m in PaymentMode.values) SegmentOption(m, m.label)],
          value: mode,
          onChanged: canPay && enabled
              ? (m) => setState(() {
                    _payMode = m;
                    _serverErrors.remove('payment.mode');
                    _serverErrors.remove('payment.amountPiasters');
                  })
              : null,
        ),
        if (modeError != null) FieldError(modeError),
        if (!canPay)
          const Text(
            'تسجيل الدفعات يحتاج صلاحية «تسجيل المدفوعات»، فتُحفظ العملية «لم يُدفع بعد».',
            style: UiText.small,
          ),
        if (mode == PaymentMode.partial)
          _numberField(
            controller: _payAmount,
            label: 'المبلغ المدفوع الآن (ج.م)',
            hint: 'أقل من قيمة العملية',
            unit: 'ج.م',
            error: _err(e, 'payment.amountPiasters'),
            enabled: enabled,
            keys: const ['payment.amountPiasters'],
          ),
        if (mode != PaymentMode.none)
          LabeledField(
            label: 'طريقة الدفع',
            child: SegmentedChoice<PaymentMethod>(
              semanticLabel: 'طريقة الدفع',
              options: [for (final m in PaymentMethod.values) SegmentOption(m, m.label)],
              value: _payMethod,
              onChanged: enabled ? (m) => setState(() => _payMethod = m) : null,
            ),
          ),
        if (e.value != null && e.amount != null)
          Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'المتبقي للمزارع بعد هذه العملية: '),
              TextSpan(
                text: '${formatMoney(e.value! - e.amount!)} ج.م',
                style: UiText.number(size: 15, color: AppColors.amber),
              ),
            ]),
            style: const TextStyle(fontSize: 14, color: AppColors.ink),
          ),
      ],
    );
  }

  Widget _editPaymentsNote() {
    final b = _base;
    if (b == null) return const SizedBox.shrink();
    return InlineBanner(
      kind: BannerKind.info,
      icon: Icons.payments_outlined,
      message: b.paidPiasters > 0
          ? 'دُفع من هذه العملية ${formatMoney(b.paidPiasters)} ج.م. الدفعات تُسجَّل وتُلغى من «تسجيل دفعة»، '
              'والقيمة الجديدة لا يمكن أن تقل عن المدفوع.'
          : 'لم تُسجَّل دفعات على هذه العملية. سجّل الدفعات من «تسجيل دفعة» في تفاصيل البراد.',
    );
  }

  List<Widget> _buttons(_Eval e, {required bool wide}) {
    if (_editing) {
      final noChanges = _base != null && e.errors.isEmpty && _serverErrors.isEmpty && _changesFor(e).isEmpty;
      return [
        AppButton(
          label: noChanges ? 'لا تغييرات للحفظ' : 'حفظ التعديل',
          icon: Icons.check,
          busy: _saving,
          busyLabel: 'جارٍ الحفظ',
          expand: true,
          onPressed: _saving || noChanges ? null : () => _save(),
        ),
      ];
    }
    return [
      AppButton(
        label: 'حفظ',
        icon: Icons.check,
        busy: _saving && !_savingAnother,
        busyLabel: 'جارٍ الحفظ',
        expand: true,
        onPressed: _saving ? null : () => _save(),
      ),
      AppButton(
        label: 'حفظ وإضافة مزارع آخر',
        variant: AppButtonVariant.secondary,
        foreground: AppColors.pomegranate,
        borderColor: AppColors.pomegranate,
        busy: _saving && _savingAnother,
        busyLabel: 'جارٍ الحفظ',
        expand: true,
        onPressed: _saving ? null : () => _save(another: true),
      ),
    ];
  }
}
