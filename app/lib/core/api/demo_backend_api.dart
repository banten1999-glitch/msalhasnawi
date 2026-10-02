import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'api_exception.dart';
import 'backend_actions.dart';
import 'backend_api.dart';

/// خادم تجريبي يعمل في الذاكرة بالكامل (--dart-define=DEMO=true).
///
/// البيانات مطابقة للتصميم المعتمد: البراد 14 «شحنة دمياط» والبراد 13 «شحنة الإسكندرية» مفتوحان،
/// والبراد 12 «شحنة بورسعيد» مقفّل. كل الأرقام تُحسب من السجلات كما يحسبها الخادم الحقيقي،
/// وتُرد بنفس صيغة docs/API.md. لا يتصل بالإنترنت ولا بأي ملف.
class DemoBackendApi extends BackendApi with BackendActions {
  DemoBackendApi({this.latency = const Duration(milliseconds: 300), DateTime Function()? clock})
      : _clock = clock ?? DateTime.now {
    final now = _clock().toLocal();
    final designNow = DateTime(now.year, now.month, now.day, 10, 58);
    // بعد 10:58 ص تظهر أوقات التصميم كما هي (فُتح اليوم 06:40 ص)؛ قبلها تُزاح حتى لا تكون في المستقبل.
    _ref = now.isBefore(designNow) ? now : designNow;
    _seed();
  }

  /// تأخير مصطنع يشبه الشبكة.
  final Duration latency;
  final DateTime Function() _clock;

  /// «لحظة التصميم» (اليوم 10:58 ص، أو الآن إن كان أبكر). كل الأوقات محسوبة منها.
  late final DateTime _ref;

  @override
  String? session;

  static const demoSession = 'demo-session';
  static const _bootstrapId = 'US-0001';

  final _coolers = <_Cooler>[];
  final _farmers = <_Farmer>[];
  final _purchases = <_Purchase>[];
  final _payments = <_Payment>[];
  final _packaging = <_Packaging>[];
  final _users = <_User>[];
  final _replays = <String, String>{};
  late Map<String, dynamic> _settings;
  late _Sheet _sheet;
  int _dataVersion = 1;

  // ===================================================================================== الإرسال

  @override
  Future<Map<String, dynamic>> call(
    String action, {
    Map<String, dynamic> payload = const {},
    bool mutation = false,
    String? requestId,
  }) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    // نسخة مستقلة من المدخلات حتى لا يؤثر تعديلها لاحقًا على البيانات.
    final p = (jsonDecode(jsonEncode(payload)) as Map).cast<String, dynamic>();

    if (action == 'auth.login') return _login(p);
    if (action == 'auth.logout') return {};
    if (session == null || session!.trim().isEmpty) {
      throw const ApiException(
        ApiErrorCode.authRequired,
        'يجب تسجيل الدخول أولًا. سجّل الدخول بحساب Google ثم أعد المحاولة.',
      );
    }

    final handler = _readers[action] ?? _writers[action];
    if (handler == null) {
      throw ApiException(
        ApiErrorCode.unknownAction,
        'الإجراء «$action» غير متاح في الوضع التجريبي. جرّبه مع الخادم الحقيقي.',
        field: 'action',
        details: {'action': action},
      );
    }
    final isWrite = _writers.containsKey(action);
    if (isWrite) {
      // مثل HttpBackendApi: requestId جديد لكل عملية حفظ ما لم يُمرَّر واحد لإعادة المحاولة.
      final id = (requestId ?? (mutation ? const Uuid().v4() : '')).trim();
      if (id.isEmpty) {
        throw const ApiException(
          ApiErrorCode.validation,
          'معرّف الطلب (requestId) مطلوب لكل عملية حفظ حتى لا تتكرر. حدّث التطبيق ثم أعد المحاولة.',
          field: 'requestId',
        );
      }
      final cached = _replays[id];
      if (cached != null) return (jsonDecode(cached) as Map).cast<String, dynamic>();
      final result = handler(p);
      _dataVersion++;
      _replays[id] = jsonEncode(result);
      return (jsonDecode(_replays[id]!) as Map).cast<String, dynamic>();
    }
    return (jsonDecode(jsonEncode(handler(p))) as Map).cast<String, dynamic>();
  }

  late final Map<String, Map<String, dynamic> Function(Map<String, dynamic>)> _readers = {
    'auth.me': (_) => {'user': _userJson(_currentUser)},
    'dashboard.get': _dashboard,
    'coolers.list': _coolersList,
    'coolers.get': _coolersGet,
    'farmers.list': _farmersList,
    'purchases.list': _purchasesList,
    'payments.list': _paymentsList,
    'packaging.list': _packagingList,
    'itemTypes.list': (_) => {'itemTypes': _itemTypes},
    'settings.get': (_) => Map<String, dynamic>.of(_settings),
    'users.list': (_) => {'users': [for (final u in _users) _userJson(u)]},
    'sheet.status': (_) => _sheet.toJson(_iso(_now())),
  };

  late final Map<String, Map<String, dynamic> Function(Map<String, dynamic>)> _writers = {
    'users.add': _usersAdd,
    'users.update': _usersUpdate,
    'settings.update': _settingsUpdate,
    'sheet.repair': _sheetRepair,
    'sheet.connect': _sheetConnect,
  };

  // ===================================================================================== الوقت

  DateTime _now() => _clock().toLocal();

  /// وقت من التصميم: [days] أيام قبل «اليوم» عند الساعة h:m، مُزاحًا لينتهي «اليوم 10:58» عند لحظة البدء.
  DateTime _at(int days, int h, int m) => _ref.subtract(Duration(minutes: days * 1440 + (10 * 60 + 58) - (h * 60 + m)));

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// ISO بتوقيت الجهاز مع الإزاحة: 2026-10-02T06:40:00+03:00
  static String _iso(DateTime t) {
    final l = t.toLocal();
    final off = l.timeZoneOffset;
    final sign = off.isNegative ? '-' : '+';
    final mins = off.inMinutes.abs();
    return '${l.year.toString().padLeft(4, '0')}-${_two(l.month)}-${_two(l.day)}T'
        '${_two(l.hour)}:${_two(l.minute)}:${_two(l.second)}$sign${_two(mins ~/ 60)}:${_two(mins % 60)}';
  }

  static String _day(DateTime t) => '${t.year.toString().padLeft(4, '0')}-${_two(t.month)}-${_two(t.day)}';

  // ===================================================================================== البيانات

  void _seed() {
    const owner = 'محمد الحسناوي';
    const karim = 'كريم عبد الله';
    const youssef = 'يوسف ناصر';

    _users.addAll([
      _User('US-0001', 'hasnawi.owner@gmail.com', owner, 'admin', true, 3, isBootstrap: true),
      _User('US-0002', 'karim.abdallah.eg@gmail.com', karim, 'entry', true, 5, perms: const {
        'addFarmers': true, 'recordPurchases': true, 'editOthers': false,
        'recordPayments': true, 'packaging': true, 'closeCoolers': true,
      }),
      _User('US-0003', 'youssef.nasser.farm@gmail.com', youssef, 'entry', true, 2, perms: const {
        'addFarmers': true, 'recordPurchases': true, 'editOthers': false,
        'recordPayments': true, 'packaging': false, 'closeCoolers': false,
      }),
      _User('US-0004', 'salma.fouad.acc@gmail.com', 'سلمى فؤاد', 'viewer', true, 1),
      _User('US-0005', 'ahmed.samir.weigh@gmail.com', 'أحمد سمير', 'entry', false, 4, perms: const {
        'addFarmers': false, 'recordPurchases': true, 'editOthers': false,
        'recordPayments': false, 'packaging': false, 'closeCoolers': false,
      }),
    ]);

    const farmerNames = [
      ('سعيد أبو زيد', 'كفر سعد'),
      ('محمود السيد رزق', 'فارسكور'),
      ('حسن البدري', 'الزرقا'),
      ('الحاج محمود عبد العال', 'كفر البطيخ'),
      ('عبد الرحمن الشافعي', 'السرو'),
      ('إبراهيم الدسوقي', 'الروضة'),
      ('فتحي عبد الحميد', 'ميت أبو غالب'),
      ('جمال الصاوي', 'فارسكور'),
      ('رمضان أبو العلا', 'كفر سعد'),
      ('عادل منصور', 'الزرقا'),
      ('طه الجندي', 'السرو'),
      ('ناصر الحلواني', 'كفر البطيخ'),
      ('مصطفى قنديل', 'الروضة'),
    ];
    for (var i = 0; i < farmerNames.length; i++) {
      _farmers.add(_Farmer(
        id: _seq('FR', i + 1),
        no: i + 1,
        name: farmerNames[i].$1,
        village: farmerNames[i].$2,
        active: i != 12,
        createdAt: _at(40 - i, 9, 0),
      ));
    }

    _coolers.addAll([
      _Cooler(
        id: 'CL-0012', no: 12, name: 'شحنة بورسعيد', carNo: 'ط ب ع 4528', driver: 'رضا السعدني',
        openedAt: _at(3, 6, 15), openedBy: owner, closedAt: _at(2, 17, 30), closedBy: karim, version: 4,
        // لقطة «عند التقفيل»: دُفع بعدها 7,943.00 + 5,320.00 للمزارعين، واعتُمدت تعبئة متأخرة 455.00.
        snapshot: const {
          'farmers': 9, 'purchases': 14, 'boxes': 588, 'weightGrams': 6391400,
          'valuePiasters': 9601400, 'paidPiasters': 7528550, 'remainingPiasters': 2072850,
          'packagingPiasters': 1451500, 'totalCostPiasters': 11052900,
        },
      ),
      _Cooler(
        id: 'CL-0013', no: 13, name: 'شحنة الإسكندرية', carNo: 'س د م 2194', driver: 'خالد فرج',
        openedAt: _at(1, 15, 20), openedBy: karim, version: 1,
      ),
      _Cooler(
        id: 'CL-0014', no: 14, name: 'شحنة دمياط', carNo: 'ن ق ر 7316', driver: 'سامي عطية',
        openedAt: _at(0, 6, 40), openedBy: owner, version: 1,
      ),
    ]);

    // (البراد، المزارع، الوقت، الصناديق، متوسط الصندوق بالجرام، سعر الكيلو بالقرش، المسجِّل)
    void buy(String cooler, int farmer, DateTime at, int boxes, int avg, int price, String by,
        {List<int>? sample, int tare = 0}) {
      _purchases.add(_Purchase(
        id: _seq('PU', _purchases.length + 1),
        coolerId: cooler,
        farmerId: _seq('FR', farmer),
        at: at,
        boxes: boxes,
        avgWeightGrams: avg,
        pricePerKgPiasters: price,
        createdBy: by,
        sampleWeightsGrams: sample,
        tareGrams: tare,
      ));
    }

    // البراد 12 — شحنة بورسعيد (14 عملية، 9 مزارعين)
    buy('CL-0012', 8, _at(3, 7, 5), 39, 11400, 1425, owner);
    buy('CL-0012', 9, _at(3, 7, 40), 38, 10900, 1400, karim);
    buy('CL-0012', 10, _at(3, 8, 25), 34, 10300, 1625, youssef);
    buy('CL-0012', 3, _at(3, 9, 10), 46, 10800, 1425, karim);
    buy('CL-0012', 6, _at(3, 10, 30), 45, 10200, 1475, owner);
    buy('CL-0012', 11, _at(3, 12, 5), 35, 10500, 1550, youssef);
    buy('CL-0012', 12, _at(3, 14, 20), 44, 10200, 1500, karim);
    buy('CL-0012', 7, _at(2, 7, 15), 43, 10800, 1625, owner);
    buy('CL-0012', 2, _at(2, 8, 0), 47, 10400, 1625, karim);
    buy('CL-0012', 8, _at(2, 9, 35), 44, 11800, 1425, youssef);
    buy('CL-0012', 9, _at(2, 11, 0), 41, 11400, 1475, karim);
    buy('CL-0012', 10, _at(2, 12, 45), 35, 11300, 1600, youssef);
    buy('CL-0012', 3, _at(2, 14, 10), 41, 10000, 1575, karim);
    buy('CL-0012', 6, _at(2, 16, 0), 56, 11875, 1405, owner, sample: const [13800, 13700, 13900, 13700], tare: 1900);
    // البراد 13 — شحنة الإسكندرية (3 عمليات)
    buy('CL-0013', 6, _at(1, 15, 45), 40, 10900, 1500, karim);
    buy('CL-0013', 7, _at(1, 16, 30), 36, 10800, 1500, youssef);
    buy('CL-0013', 1, _at(1, 17, 20), 36, 11000, 1500, karim);
    // البراد 14 — شحنة دمياط (6 عمليات، 5 مزارعين)
    buy('CL-0014', 1, _at(0, 7, 10), 75, 11000, 1400, karim);
    buy('CL-0014', 2, _at(0, 8, 5), 48, 10650, 1575, youssef);
    buy('CL-0014', 3, _at(0, 8, 40), 32, 10000, 1625, owner);
    buy('CL-0014', 4, _at(0, 9, 31), 24, 11000, 1350, karim);
    buy('CL-0014', 5, _at(0, 10, 15), 42, 12000, 1600, youssef);
    buy('CL-0014', 3, _at(0, 10, 42), 28, 10500, 1500, owner);

    _packaging.addAll([
      _Packaging(
        id: 'PK-0001', no: 'P-0001', supplier: 'الوادي للتغليف', invoiceNo: '1187', coolerId: 'CL-0012',
        at: _at(3, 6, 50), status: 'approved', itemsCount: 4, completeTotal: 1451500, createdBy: karim,
      ),
      _Packaging(
        id: 'PK-0002', no: 'P-0002', supplier: 'مؤسسة النيل للكرتون', invoiceNo: '552', coolerId: 'CL-0012',
        at: _at(1, 11, 15), status: 'approved', itemsCount: 1, completeTotal: 45500, late: true, createdBy: karim,
        notes: 'شريط لاصق إضافي وصل بعد تقفيل البراد.',
      ),
      _Packaging(
        id: 'PK-0003', no: 'P-0003', supplier: 'مؤسسة النيل للكرتون', invoiceNo: '561', coolerId: 'CL-0014',
        at: _at(0, 7, 30), status: 'approved', itemsCount: 3, completeTotal: 450000, createdBy: owner,
      ),
      _Packaging(
        id: 'PK-0004', no: 'P-0004', supplier: 'الوادي للتغليف', invoiceNo: '', coolerId: 'CL-0014',
        at: _at(0, 9, 50), status: 'draft', itemsCount: 3, incompleteCount: 1, completeTotal: 258000, createdBy: karim,
        notes: 'سعر الفلين لم يُحدد بعد.',
      ),
    ]);

    // (العملية، المبلغ، الطريقة، الوقت، المسجِّل) — بترتيب الوقت لتتسلسل الأرقام.
    void pay(String target, int? amount, String method, DateTime at, String by) {
      final n = _payments.length + 1;
      final isPurchase = target.startsWith('PU-');
      final purchase = isPurchase ? _purchases.firstWhere((x) => x.id == target) : null;
      final pack = isPurchase ? null : _packaging.firstWhere((x) => x.id == target);
      _payments.add(_Payment(
        id: _seq('PY', n),
        no: 'D-${n.toString().padLeft(4, '0')}',
        targetType: isPurchase ? 'purchase' : 'packaging',
        targetId: target,
        payeeType: isPurchase ? 'farmer' : 'supplier',
        payeeId: purchase?.farmerId ?? '',
        payeeName: purchase != null ? _farmer(purchase.farmerId).name : pack!.supplier,
        coolerId: purchase?.coolerId ?? pack!.coolerId,
        amount: amount ?? purchase!.valuePiasters,
        method: method,
        at: at,
        createdBy: by,
      ));
    }

    pay('PU-0001', null, 'cash', _at(3, 7, 5), owner);
    pay('PU-0002', null, 'cash', _at(3, 7, 40), karim);
    pay('PU-0003', null, 'wallet', _at(3, 8, 25), youssef);
    pay('PU-0004', null, 'cash', _at(3, 9, 10), karim);
    pay('PU-0005', null, 'bank', _at(3, 10, 30), owner);
    pay('PU-0006', null, 'cash', _at(3, 12, 5), youssef);
    pay('PU-0007', null, 'cash', _at(3, 14, 20), karim);
    pay('PU-0008', null, 'cash', _at(2, 7, 15), owner);
    pay('PU-0010', null, 'bank', _at(2, 9, 35), youssef);
    pay('PU-0011', null, 'cash', _at(2, 11, 0), karim);
    pay('PU-0014', null, 'bank', _at(2, 16, 0), owner);
    pay('PK-0001', 1451500, 'bank', _at(2, 18, 0), owner);
    pay('PU-0009', null, 'bank', _at(1, 10, 0), owner);
    pay('PU-0013', 532000, 'cash', _at(1, 12, 30), karim);
    pay('PU-0015', 600000, 'cash', _at(1, 15, 45), karim);
    pay('PU-0016', 400000, 'wallet', _at(1, 16, 30), youssef);
    pay('PK-0003', 300000, 'cash', _at(0, 7, 35), owner);
    pay('PU-0019', 305000, 'cash', _at(0, 8, 5), youssef);
    pay('PU-0020', null, 'cash', _at(0, 8, 40), owner);
    pay('PU-0018', 500000, 'cash', _at(0, 9, 5), karim);
    pay('PU-0022', null, 'bank', _at(0, 10, 15), youssef);
    pay('PU-0023', 200000, 'cash', _at(0, 10, 44), owner);

    // بداية الموسم: أول الشهر قبل شهرين (مثلًا 1 أغسطس عندما يكون اليوم 2 أكتوبر).
    final seasonStart = DateTime(_ref.year, _ref.month - 2, 1);
    _settings = {
      'businessName': 'حاسبة الحسناوي',
      'currency': 'جنيه مصري (EGP)',
      'currencySymbol': 'ج.م',
      'timezone': 'Africa/Cairo',
      'moneyDecimals': 2,
      'weightDecimals': 1,
      'emptyBoxGrams': 1900,
      'seasonStart': _day(seasonStart),
    };

    _sheet = _Sheet(
      spreadsheetId: '1hX9tQ2mB7rLk4ZpW8sN3yV6cJ0dF5gH9aE2uR7vQe4',
      title: 'حاسبة الرمان — موسم ${_ref.year}',
      connectedAs: 'hasnawi.owner@gmail.com',
      lastWriteAt: _iso(_at(0, 10, 44)),
      lastErrorAt: _iso(_at(1, 16, 12)),
      lastErrorMessage: 'تعذّرت الكتابة لأن خدمة Google لم تستجب في الوقت المحدد. '
          'أُعيدت المحاولة تلقائيًا ونجحت بعد دقيقة دون تكرار.',
      checks: [
        _SheetCheck('coolers', 'البرادات', _coolers.length),
        _SheetCheck('farmers', 'المزارعون', _farmers.length),
        _SheetCheck('purchases', 'مشتريات الرمان', _purchases.length),
        _SheetCheck('packaging', 'مشتريات التعبئة', _packaging.length, missing: const ['رقم الفاتورة']),
        _SheetCheck('packaging_items', 'تفاصيل التعبئة', 11),
        _SheetCheck('payments', 'المدفوعات', _payments.length),
        _SheetCheck('users', 'المستخدمون', _users.length),
        _SheetCheck('settings', 'الإعدادات', 8),
        _SheetCheck('item_types', 'أصناف التعبئة', _itemTypes.length),
        _SheetCheck('audit', 'سجل التعديلات', 0, exists: false, missing: const [
          'المعرّف', 'التاريخ والوقت', 'المستخدم', 'الإجراء', 'نوع السجل', 'معرّف السجل',
          'الوصف', 'القيم السابقة', 'القيم الجديدة', 'السبب',
        ]),
      ],
    );
  }

  static String _seq(String prefix, int n) => '$prefix-${n.toString().padLeft(4, '0')}';

  static const _itemTypes = [
    {'id': 'IT-0001', 'name': 'كرتون', 'unit': 'قطعة', 'order': 1, 'active': true},
    {'id': 'IT-0002', 'name': 'فلين', 'unit': 'لوح', 'order': 2, 'active': true},
    {'id': 'IT-0003', 'name': 'شريط لاصق', 'unit': 'لفة', 'order': 3, 'active': true},
    {'id': 'IT-0004', 'name': 'ورق تغليف', 'unit': 'كغ', 'order': 4, 'active': true},
    {'id': 'IT-0005', 'name': 'شبك', 'unit': 'قطعة', 'order': 5, 'active': true},
    {'id': 'IT-0006', 'name': 'ملصقات', 'unit': 'قطعة', 'order': 6, 'active': false},
  ];

  _Farmer _farmer(String id) => _farmers.firstWhere((f) => f.id == id);
  _Cooler? _cooler(String id) => _coolers.where((c) => c.id == id).firstOrNull;

  int _paidFor(String targetId) =>
      _payments.where((x) => x.active && x.targetId == targetId).fold(0, (s, x) => s + x.amount);

  // ===================================================================================== الدخول

  _User get _currentUser => _users.firstWhere((u) => u.id == _bootstrapId);

  Map<String, dynamic> _login(Map<String, dynamic> p) {
    final token = p['idToken'];
    if (token is! String || token.trim().isEmpty) {
      throw const ApiException(
        ApiErrorCode.validation,
        '«رمز الدخول من Google» مطلوب. سجّل الدخول بحساب Google مرة أخرى.',
        field: 'idToken',
      );
    }
    return {
      'session': demoSession,
      'expiresAt': _iso(_now().add(const Duration(days: 7))),
      'user': _userJson(_currentUser),
    };
  }

  // ===================================================================================== المستخدمون

  static const _roles = {'admin': 'مدير', 'entry': 'موظف إدخال', 'viewer': 'مشاهدة فقط'};
  static const _permKeys = ['addFarmers', 'recordPurchases', 'editOthers', 'recordPayments', 'packaging', 'closeCoolers'];

  Map<String, dynamic> _userJson(_User u) {
    final admin = u.role == 'admin';
    final entry = u.role == 'entry';
    return {
      'id': u.id,
      'email': u.email,
      'name': u.name,
      'role': u.role,
      'status': u.active ? 'active' : 'disabled',
      'isBootstrap': u.isBootstrap,
      'version': u.version,
      'permissions': {
        for (final k in _permKeys) k: admin || (entry && (u.perms[k] ?? false)),
        'reopenCoolers': admin,
        'manageUsers': admin,
        'manageSettings': admin,
        'viewData': true,
      },
    };
  }

  static Never _invalid(String field, String message, [Map<String, dynamic> details = const {}]) =>
      throw ApiException(ApiErrorCode.validation, message, field: field, details: details);

  static String _str(Map<String, dynamic> p, String field, String label, {bool required = false, int max = 200, String? hint}) {
    final v = p[field];
    if (v == null || (v is String && v.trim().isEmpty)) {
      if (required) _invalid(field, '«$label» مطلوب. ${hint ?? 'اكتبه ثم أعد المحاولة.'}');
      return '';
    }
    if (v is! String && v is! num) _invalid(field, '«$label» يجب أن يكون نصًا. صحّحه ثم أعد المحاولة.');
    final s = v.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.length > max) _invalid(field, '«$label» أطول من المسموح ($max حرفًا). اختصره ثم أعد المحاولة.', {'max': max});
    return s;
  }

  static String? _enum(Map<String, dynamic> p, String field, String label, Map<String, String> choices, {bool required = false}) {
    final list = choices.values.map((v) => '«$v»').join(' أو ');
    final v = p[field];
    if (v == null || (v is String && v.trim().isEmpty)) {
      if (required) _invalid(field, '«$label» مطلوب. اختر $list.');
      return null;
    }
    final s = v.toString().trim();
    if (!choices.containsKey(s)) _invalid(field, 'قيمة «$label» غير صحيحة. اختر $list.', {'allowed': choices.keys.toList()});
    return s;
  }

  Map<String, bool> _permsFor(Object? input, String role, _User? existing) {
    if (input != null && input is! Map) {
      _invalid('permissions', '«الصلاحيات» يجب أن تكون قائمة اختيارات نعم/لا. حدّث التطبيق ثم أعد المحاولة.');
    }
    final m = (input as Map?)?.cast<String, dynamic>() ?? const {};
    return {
      for (final k in _permKeys)
        k: switch (role) {
          'admin' => true,
          'viewer' => false,
          _ => m[k] is bool ? m[k] as bool : (existing?.perms[k] ?? false),
        },
    };
  }

  bool _isActiveAdmin(_User u) => u.isBootstrap || (u.role == 'admin' && u.active);

  Map<String, dynamic> _usersAdd(Map<String, dynamic> p) {
    final email = _str(p, 'email', 'البريد الإلكتروني', required: true, max: 120, hint: 'اكتب بريد Gmail مثل name@gmail.com.')
        .replaceAll(RegExp(r'\s+'), '')
        .toLowerCase();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _invalid('email', 'البريد «$email» غير صحيح. اكتب بريد Gmail كاملًا مثل name@gmail.com.');
    }
    final existing = _users.where((u) => u.email == email).firstOrNull;
    if (existing != null) {
      _invalid('email', 'البريد «$email» مسجّل بالفعل لمستخدم آخر. ابحث عنه في القائمة وعدّله بدل إضافته مرة أخرى.',
          {'id': existing.id});
    }
    final name = _str(p, 'name', 'الاسم', required: true, max: 80);
    final role = _enum(p, 'role', 'الدور', _roles, required: true)!;
    final user = _User(_seq('US', _users.length + 1), email, name, role, true, 1, perms: _permsFor(p['permissions'], role, null));
    _users.add(user);
    _sheet.bumpWrite(_iso(_now()));
    return {'user': _userJson(user)};
  }

  Map<String, dynamic> _usersUpdate(Map<String, dynamic> p) {
    final id = _str(p, 'id', 'المستخدم', required: true, max: 64, hint: 'اختره من القائمة ثم أعد المحاولة.');
    final expected = p['expectedVersion'];
    if (expected is! num || expected < 1) {
      _invalid('expectedVersion', '«رقم الإصدار» مطلوب. حدّث البيانات ثم أعد الحفظ.');
    }
    final user = _users.where((u) => u.id == id).firstOrNull;
    if (user == null) {
      throw ApiException(
        ApiErrorCode.notFound,
        'لم يتم العثور على المستخدم بالمعرّف «$id». حدّث البيانات واختره من القائمة مرة أخرى.',
        field: 'id',
        details: {'id': id},
      );
    }
    if (user.version != expected.toInt()) {
      throw ApiException(
        ApiErrorCode.conflict,
        'عدّل مستخدم آخر بيانات هذا المستخدم بعد أن فتحتها. راجع البيانات الحالية ثم أعد الحفظ.',
        field: 'expectedVersion',
        details: {'currentVersion': user.version, 'current': _userJson(user)},
      );
    }

    var name = user.name;
    var role = user.role;
    var active = user.active;
    if (p.containsKey('name')) name = _str(p, 'name', 'الاسم', required: true, max: 80);
    if (p.containsKey('role')) {
      role = _enum(p, 'role', 'الدور', _roles, required: true)!;
      if (user.isBootstrap && role != 'admin') {
        _invalid('role', 'لا يمكن تغيير دور المدير الأساسي (${user.email}). يمكن تغييره فقط من إعدادات الخادم.');
      }
    }
    if (p.containsKey('status')) {
      active = _enum(p, 'status', 'الحالة', const {'active': 'نشط', 'disabled': 'معطّل'}, required: true) == 'active';
      if (user.isBootstrap && !active) {
        _invalid('status', 'لا يمكن تعطيل المدير الأساسي (${user.email}). يمكن تغييره فقط من إعدادات الخادم.');
      }
    }
    final perms = p.containsKey('role') || p.containsKey('permissions')
        ? _permsFor(p['permissions'], role, user)
        : Map<String, bool>.of(user.perms);

    final adminsAfter = _users.where((u) {
      if (u.id != user.id) return _isActiveAdmin(u);
      return u.isBootstrap || (role == 'admin' && active);
    }).length;
    if (adminsAfter < 1) {
      _invalid(p.containsKey('status') && !active ? 'status' : 'role',
          'لا يمكن حفظ التغيير لأن «${user.name}» هو آخر مدير نشط. أضف مديرًا آخر أو فعّله أولًا.');
    }

    final changed = name != user.name ||
        role != user.role ||
        active != user.active ||
        _permKeys.any((k) => (perms[k] ?? false) != (user.perms[k] ?? false));
    if (!changed) return {'user': _userJson(user)};
    user
      ..name = name
      ..role = role
      ..active = active
      ..perms = perms
      ..version += 1;
    _sheet.bumpWrite(_iso(_now()));
    return {'user': _userJson(user)};
  }

  // ===================================================================================== الإعدادات والملف

  Map<String, dynamic> _settingsUpdate(Map<String, dynamic> p) {
    final next = Map<String, dynamic>.of(_settings);
    if (p.containsKey('businessName')) next['businessName'] = _str(p, 'businessName', 'اسم النشاط', required: true, max: 80);
    if (p.containsKey('currencySymbol')) next['currencySymbol'] = _str(p, 'currencySymbol', 'رمز العملة', required: true, max: 10);
    if (p.containsKey('timezone')) {
      final tz = _str(p, 'timezone', 'المنطقة الزمنية', required: true, max: 60);
      if (!RegExp(r'^(?:UTC|GMT|[A-Za-z]+(?:/[A-Za-z0-9_+\-]+){1,2})$').hasMatch(tz)) {
        _invalid('timezone', 'المنطقة الزمنية «$tz» غير معروفة. اكتبها مثل Africa/Cairo.');
      }
      next['timezone'] = tz;
    }
    void intField(String key, String label, int min, int max) {
      if (!p.containsKey(key)) return;
      final v = p[key];
      if (v is! num || v != v.roundToDouble() || v < min || v > max) {
        _invalid(key, '«$label» يجب أن يكون عددًا صحيحًا من $min إلى $max. صحّحه ثم أعد المحاولة.');
      }
      next[key] = v.toInt();
    }

    intField('moneyDecimals', 'منازل المبالغ', 0, 3);
    intField('weightDecimals', 'منازل الأوزان', 0, 3);
    intField('emptyBoxGrams', 'وزن الصندوق الفارغ', 0, 10000);
    if (p.containsKey('seasonStart')) {
      final v = p['seasonStart'];
      if (v == null || (v is String && v.trim().isEmpty)) {
        next['seasonStart'] = null;
      } else if (v is! String || DateTime.tryParse(v.trim()) == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v.trim())) {
        _invalid('seasonStart', '«بداية الموسم» يجب أن تكون تاريخًا مثل 2026-08-01. صحّحها ثم أعد المحاولة.');
      } else {
        next['seasonStart'] = v.trim();
      }
    }
    _settings = next;
    _sheet.bumpWrite(_iso(_now()));
    return Map<String, dynamic>.of(_settings);
  }

  Map<String, dynamic> _sheetRepair(Map<String, dynamic> _) {
    for (final c in _sheet.checks) {
      if (!c.exists) c.rows = c.key == 'audit' ? 1 : 0;
      c
        ..exists = true
        ..missing = const [];
    }
    _sheet.bumpWrite(_iso(_now()));
    return _sheet.toJson(_iso(_now()));
  }

  Map<String, dynamic> _sheetConnect(Map<String, dynamic> p) {
    final raw = _str(p, 'spreadsheet', 'رابط ملف Google Sheets أو معرّفه',
        required: true, max: 500, hint: 'انسخ رابط الملف من شريط العنوان في المتصفح والصقه هنا.');
    final id = _parseSpreadsheetId(raw);
    if (id.isEmpty) {
      _invalid('spreadsheet',
          'الرابط «${raw.length > 80 ? raw.substring(0, 80) : raw}» ليس رابط ملف Google Sheets. انسخ الرابط كاملًا من شريط العنوان '
          '(يبدأ بـ https://docs.google.com/spreadsheets/d/) والصقه هنا.');
    }
    final previous = _sheet.spreadsheetId;
    _sheet
      ..spreadsheetId = id
      ..title = 'ملف حاسبة الرمان (تجريبي)';
    _sheet.bumpWrite(_iso(_now()));
    return {
      ..._sheet.toJson(_iso(_now())),
      'warning': 'البيانات القديمة لا تُنقل تلقائيًا إلى الملف الجديد. المستخدمون والبرادات والعمليات المسجلة في الملف السابق تبقى فيه. '
          'إن كان الملف الجديد فارغًا فاضغط «إصلاح الملف» لإنشاء الصفحات، ثم أضف المستخدمين من جديد.',
      'previousSpreadsheetId': previous,
    };
  }

  static String _parseSpreadsheetId(String raw) {
    final s = raw.trim();
    final m = RegExp(r'/spreadsheets/(?:u/\d+/)?d/([A-Za-z0-9_-]{20,})').firstMatch(s);
    if (m != null) return m.group(1)!;
    final q = RegExp(r'[?&]id=([A-Za-z0-9_-]{20,})').firstMatch(s);
    if (q != null) return q.group(1)!;
    if (RegExp(r'^[A-Za-z0-9_-]{20,}$').hasMatch(s)) return s;
    return '';
  }

  // ===================================================================================== القراءة

  Map<String, dynamic> _coolerJson(_Cooler c) {
    final purchases = _purchases.where((x) => x.active && x.coolerId == c.id).toList();
    final value = purchases.fold(0, (s, x) => s + x.valuePiasters);
    final weight = purchases.fold(0, (s, x) => s + x.totalWeightGrams);
    final paid = purchases.fold(0, (s, x) => s + _paidFor(x.id));
    final approved = _packaging.where((x) => x.coolerId == c.id && x.status == 'approved');
    final packaging = approved.fold(0, (s, x) => s + x.completeTotal);
    final late = approved.where((x) => x.late).fold(0, (s, x) => s + x.completeTotal);
    return {
      'id': c.id,
      'no': c.no,
      'name': c.name,
      'status': c.open ? 'open' : 'closed',
      'carNo': c.carNo,
      'driver': c.driver,
      'notes': '',
      'openedAt': _iso(c.openedAt),
      'openedBy': c.openedBy,
      'closedAt': c.closedAt == null ? null : _iso(c.closedAt!),
      'closedBy': c.closedBy,
      'farmers': purchases.map((x) => x.farmerId).toSet().length,
      'purchases': purchases.length,
      'boxes': purchases.fold(0, (s, x) => s + x.boxes),
      'weightGrams': weight,
      'valuePiasters': value,
      'paidPiasters': paid,
      'remainingPiasters': value - paid,
      'packagingApprovedPiasters': packaging,
      'packagingLatePiasters': late,
      'totalCostPiasters': value + packaging,
      'avgPricePerKgPiasters': _avgPrice(value, weight),
      'version': c.version,
      'closeSnapshot': c.snapshot,
    };
  }

  /// round_half_up(value × 1000 / weight)
  static int _avgPrice(int value, int weight) => weight > 0 ? (value * 1000 * 2 + weight) ~/ (weight * 2) : 0;

  Map<String, dynamic> _purchaseJson(_Purchase x) {
    final paid = _paidFor(x.id);
    final cooler = _cooler(x.coolerId)!;
    return {
      'id': x.id,
      'coolerId': x.coolerId,
      'coolerNo': cooler.no,
      'farmerId': x.farmerId,
      'farmerName': _farmer(x.farmerId).name,
      'occurredAt': _iso(x.at),
      'boxes': x.boxes,
      'avgWeightGrams': x.avgWeightGrams,
      'weightMethod': x.sampleWeightsGrams == null ? 'direct' : 'sample',
      'sampleWeightsGrams': x.sampleWeightsGrams ?? const <int>[],
      'tareGrams': x.sampleWeightsGrams == null ? null : x.tareGrams,
      'totalWeightGrams': x.totalWeightGrams,
      'pricePerKgPiasters': x.pricePerKgPiasters,
      'valuePiasters': x.valuePiasters,
      'paidPiasters': paid,
      'remainingPiasters': x.valuePiasters - paid,
      'payStatus': _payStatus(x.valuePiasters, paid),
      'status': 'active',
      'cancelReason': '',
      'notes': '',
      'createdAt': _iso(x.at),
      'createdBy': x.createdBy,
      'updatedAt': '',
      'updatedBy': '',
      'version': 1,
    };
  }

  static String _payStatus(int value, int paid) => paid <= 0 ? 'unpaid' : (paid >= value ? 'paid' : 'partial');

  Map<String, dynamic> _paymentJson(_Payment x) => {
        'id': x.id,
        'no': x.no,
        'payeeType': x.payeeType,
        'payeeName': x.payeeName,
        'payeeId': x.payeeId,
        'targetType': x.targetType,
        'targetId': x.targetId,
        'coolerId': x.coolerId,
        'coolerNo': _cooler(x.coolerId)?.no,
        'amountPiasters': x.amount,
        'method': x.method,
        'paidAt': _iso(x.at),
        'status': x.active ? 'active' : 'cancelled',
        'cancelReason': '',
        'notes': '',
        'createdAt': _iso(x.at),
        'createdBy': x.createdBy,
        'version': 1,
      };

  Map<String, dynamic> _packagingJson(_Packaging x) {
    final paid = x.status == 'approved' ? _paidFor(x.id) : 0;
    return {
      'id': x.id,
      'no': x.no,
      'supplier': x.supplier,
      'invoiceNo': x.invoiceNo,
      'occurredAt': _iso(x.at),
      'coolerId': x.coolerId,
      'coolerNo': _cooler(x.coolerId)?.no,
      'status': x.status,
      'itemsCount': x.itemsCount,
      'incompleteCount': x.incompleteCount,
      'completeTotalPiasters': x.completeTotal,
      'paidPiasters': paid,
      'remainingPiasters': x.status == 'approved' ? x.completeTotal - paid : 0,
      'late': x.late,
      'notes': x.notes,
      'createdAt': _iso(x.at),
      'createdBy': x.createdBy,
      'version': 1,
    };
  }

  static const _periods = {
    'season': 'هذا الموسم',
    'today': 'اليوم',
    'week': 'آخر 7 أيام',
    'month': 'هذا الشهر',
    'all': 'كل الفترات',
  };

  static const _statusLabels = {
    'paid': 'مدفوع',
    'partial': 'جزئي',
    'unpaid': 'غير مدفوع',
    'cancelled': 'ملغاة',
    'active': 'فعّالة',
    'draft': 'مسودة',
    'approved': 'معتمد',
  };

  ({DateTime? from, DateTime? to}) _range(String key) {
    final now = _now();
    final startToday = DateTime(now.year, now.month, now.day);
    final endToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
    switch (key) {
      case 'all':
        return (from: null, to: null);
      case 'today':
        return (from: startToday, to: endToday);
      case 'week':
        return (from: DateTime(now.year, now.month, now.day - 6), to: endToday);
      case 'month':
        return (from: DateTime(now.year, now.month, 1), to: endToday);
      default:
        final s = DateTime.tryParse((_settings['seasonStart'] as String?) ?? '');
        return (from: s == null ? null : DateTime(s.year, s.month, s.day), to: endToday);
    }
  }

  static bool _inRange(DateTime t, ({DateTime? from, DateTime? to}) r) =>
      (r.from == null || !t.isBefore(r.from!)) && (r.to == null || !t.isAfter(r.to!));

  String _subtitle(String kind, String coolerId, String by) {
    final no = _cooler(coolerId)?.no;
    return [kind, if (no != null) 'براد $no', if (by.isNotEmpty) by].join(' · ');
  }

  Map<String, dynamic> _dashboard(Map<String, dynamic> p) {
    final period = _enum(p, 'period', 'الفترة', _periods) ?? 'season';
    final coolerId = _str(p, 'coolerId', 'البراد', max: 64);
    if (coolerId.isNotEmpty && _cooler(coolerId) == null) {
      throw ApiException(
        ApiErrorCode.notFound,
        'لم يتم العثور على البراد بالمعرّف «$coolerId». حدّث البيانات واختره من القائمة مرة أخرى.',
        field: 'coolerId',
        details: {'id': coolerId},
      );
    }
    final range = _range(period);
    bool inScope(String cid) => coolerId.isEmpty || cid == coolerId;

    final coolers = _coolers.where((c) => inScope(c.id)).toList();
    var purchases = 0, boxes = 0, weight = 0, value = 0, packagingApproved = 0;
    var paidFarmers = 0, paidSuppliers = 0, records = 0;
    final farmers = <String>{};
    final recent = <({DateTime at, Map<String, dynamic> json})>[];

    for (final x in _purchases.where((x) => inScope(x.coolerId) && _inRange(x.at, range))) {
      records++;
      final paid = _paidFor(x.id);
      final status = x.active ? _payStatus(x.valuePiasters, paid) : 'cancelled';
      recent.add((at: x.at, json: {
        'type': 'purchase',
        'id': x.id,
        'title': _farmer(x.farmerId).name,
        'subtitle': _subtitle('شراء', x.coolerId, x.createdBy),
        'coolerNo': _cooler(x.coolerId)?.no,
        'at': _iso(x.at),
        'amountPiasters': x.valuePiasters,
        'status': status,
        'statusLabel': _statusLabels[status],
      }));
      if (!x.active) continue;
      purchases++;
      boxes += x.boxes;
      weight += x.totalWeightGrams;
      value += x.valuePiasters;
      farmers.add(x.farmerId);
    }

    for (final x in _packaging.where((x) => inScope(x.coolerId) && _inRange(x.at, range))) {
      records++;
      recent.add((at: x.at, json: {
        'type': 'packaging',
        'id': x.id,
        'title': x.supplier.isEmpty ? 'شراء تعبئة ${x.no}' : x.supplier,
        'subtitle': _subtitle('تعبئة', x.coolerId, x.createdBy),
        'coolerNo': _cooler(x.coolerId)?.no,
        'at': _iso(x.at),
        'amountPiasters': x.completeTotal,
        'status': x.status,
        'statusLabel': _statusLabels[x.status],
      }));
      if (x.status == 'approved') packagingApproved += x.completeTotal;
    }

    var paid = 0;
    for (final x in _payments.where((x) => inScope(x.coolerId) && _inRange(x.at, range))) {
      records++;
      final status = x.active ? 'active' : 'cancelled';
      recent.add((at: x.at, json: {
        'type': 'payment',
        'id': x.id,
        'title': x.payeeName,
        'subtitle': _subtitle('دفعة', x.coolerId, x.createdBy),
        'coolerNo': _cooler(x.coolerId)?.no,
        'at': _iso(x.at),
        'amountPiasters': x.amount,
        'status': status,
        'statusLabel': _statusLabels[status],
      }));
      if (!x.active) continue;
      paid += x.amount;
      if (x.targetType == 'packaging') {
        paidSuppliers += x.amount;
      } else {
        paidFarmers += x.amount;
      }
    }

    recent.sort((a, b) {
      final t = b.at.compareTo(a.at);
      return t != 0 ? t : (b.json['id'] as String).compareTo(a.json['id'] as String);
    });

    final open = coolers.where((c) => c.open).toList()..sort((a, b) => b.openedAt.compareTo(a.openedAt));
    final current = coolerId.isNotEmpty ? coolers.first : (open.isEmpty ? null : open.first);

    return {
      'period': {
        'key': period,
        'label': _periods[period],
        'from': range.from == null ? null : _iso(range.from!),
        'to': range.to == null ? null : _iso(range.to!),
      },
      'empty': records == 0,
      'kpis': {
        'closedCoolers': coolers.where((c) => !c.open).length,
        'openCoolers': coolers.where((c) => c.open).length,
        'distinctFarmers': farmers.length,
        'purchases': purchases,
        'boxes': boxes,
        'weightGrams': weight,
        'purchaseValuePiasters': value,
        'packagingApprovedPiasters': packagingApproved,
        'paidPiasters': paid,
        'remainingPiasters': value + packagingApproved - paid,
        'remainingFarmersPiasters': value - paidFarmers,
        'remainingSuppliersPiasters': packagingApproved - paidSuppliers,
        'avgPricePerKgPiasters': _avgPrice(value, weight),
      },
      'currentCooler': current == null ? null : _coolerJson(current),
      'openCoolers': [for (final c in open) _coolerJson(c)],
      'recent': [for (final r in recent.take(10)) r.json],
    };
  }

  Map<String, dynamic> _coolersList(Map<String, dynamic> p) {
    final status = _enum(p, 'status', 'حالة البراد', const {'open': 'مفتوح', 'closed': 'مقفّل', 'all': 'الكل'}) ?? 'all';
    final list = _coolers.toList()..sort((a, b) => b.no.compareTo(a.no));
    return {
      'coolers': [
        for (final c in list)
          if (status == 'all' || (status == 'open') == c.open) _coolerJson(c),
      ],
    };
  }

  _Cooler _mustCooler(Map<String, dynamic> p, String field) {
    final id = _str(p, field, 'البراد', required: true, max: 64, hint: 'اختره من القائمة ثم أعد المحاولة.');
    final c = _cooler(id);
    if (c == null) {
      throw ApiException(
        ApiErrorCode.notFound,
        'لم يتم العثور على البراد بالمعرّف «$id». حدّث البيانات واختره من القائمة مرة أخرى.',
        field: field,
        details: {'id': id},
      );
    }
    return c;
  }

  Map<String, dynamic> _coolersGet(Map<String, dynamic> p) {
    final c = _mustCooler(p, 'id');
    final purchases = _purchases.where((x) => x.coolerId == c.id).toList()..sort((a, b) => b.at.compareTo(a.at));
    final packaging = _packaging.where((x) => x.coolerId == c.id).toList()..sort((a, b) => b.at.compareTo(a.at));
    return {
      'cooler': _coolerJson(c),
      'purchases': [for (final x in purchases) _purchaseJson(x)],
      'packaging': [for (final x in packaging) _packagingJson(x)],
    };
  }

  Map<String, dynamic> _farmersList(Map<String, dynamic> p) {
    final query = _str(p, 'query', 'البحث', max: 80);
    final includeInactive = p['includeInactive'] == true;
    return {
      'farmers': [
        for (final f in _farmers)
          if ((includeInactive || f.active) &&
              (query.isEmpty || f.name.contains(query) || f.village.contains(query) || f.no.toString() == query))
            {
              'id': f.id,
              'no': f.no,
              'name': f.name,
              'phone': '',
              'village': f.village,
              'notes': '',
              'status': f.active ? 'active' : 'inactive',
              'version': 1,
            },
      ],
    };
  }

  Map<String, dynamic> _purchasesList(Map<String, dynamic> p) {
    final coolerId = _str(p, 'coolerId', 'البراد', max: 64);
    final farmerId = _str(p, 'farmerId', 'المزارع', max: 64);
    final from = DateTime.tryParse(_str(p, 'from', 'من تاريخ', max: 40));
    final to = DateTime.tryParse(_str(p, 'to', 'إلى تاريخ', max: 40));
    final list = _purchases.where((x) {
      if (coolerId.isNotEmpty && x.coolerId != coolerId) return false;
      if (farmerId.isNotEmpty && x.farmerId != farmerId) return false;
      if (from != null && x.at.isBefore(from)) return false;
      if (to != null && x.at.isAfter(to)) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.at.compareTo(a.at));
    return {'purchases': [for (final x in list) _purchaseJson(x)]};
  }

  Map<String, dynamic> _paymentsList(Map<String, dynamic> p) {
    final targetId = _str(p, 'targetId', 'العملية', max: 64);
    final payeeId = _str(p, 'payeeId', 'المستفيد', max: 64);
    final coolerId = _str(p, 'coolerId', 'البراد', max: 64);
    final list = _payments.where((x) {
      if (targetId.isNotEmpty && x.targetId != targetId) return false;
      if (payeeId.isNotEmpty && x.payeeId != payeeId) return false;
      if (coolerId.isNotEmpty && x.coolerId != coolerId) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.at.compareTo(a.at));
    return {'payments': [for (final x in list) _paymentJson(x)]};
  }

  Map<String, dynamic> _packagingList(Map<String, dynamic> p) {
    final status = _enum(p, 'status', 'حالة الشراء', const {'draft': 'مسودة', 'approved': 'معتمد', 'cancelled': 'ملغى'});
    final coolerId = _str(p, 'coolerId', 'البراد', max: 64);
    final list = _packaging.where((x) {
      if (status != null && x.status != status) return false;
      if (coolerId.isNotEmpty && x.coolerId != coolerId) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.at.compareTo(a.at));
    return {'packaging': [for (final x in list) _packagingJson(x)]};
  }

  /// رقم يزيد مع كل عملية حفظ ناجحة (للاختبارات والتشخيص).
  int get dataVersion => _dataVersion;
}

// ===================================================================================== السجلات

class _User {
  _User(this.id, this.email, this.name, this.role, this.active, this.version,
      {this.isBootstrap = false, Map<String, bool> perms = const {}})
      : perms = Map<String, bool>.of(perms);

  final String id;
  final String email;
  String name;
  String role;
  bool active;
  int version;
  final bool isBootstrap;
  Map<String, bool> perms;
}

class _Farmer {
  const _Farmer({
    required this.id,
    required this.no,
    required this.name,
    required this.village,
    required this.active,
    required this.createdAt,
  });

  final String id;
  final int no;
  final String name;
  final String village;
  final bool active;
  final DateTime createdAt;
}

class _Cooler {
  _Cooler({
    required this.id,
    required this.no,
    required this.name,
    required this.carNo,
    required this.driver,
    required this.openedAt,
    required this.openedBy,
    this.closedAt,
    this.closedBy,
    this.snapshot,
    this.version = 1,
  });

  final String id;
  final int no;
  final String name;
  final String carNo;
  final String driver;
  final DateTime openedAt;
  final String openedBy;
  final DateTime? closedAt;
  final String? closedBy;
  final Map<String, dynamic>? snapshot;
  final int version;

  bool get open => closedAt == null;
}

class _Purchase {
  _Purchase({
    required this.id,
    required this.coolerId,
    required this.farmerId,
    required this.at,
    required this.boxes,
    required this.avgWeightGrams,
    required this.pricePerKgPiasters,
    required this.createdBy,
    this.sampleWeightsGrams,
    this.tareGrams = 0,
  });

  final String id;
  final String coolerId;
  final String farmerId;
  final DateTime at;
  final int boxes;
  final int avgWeightGrams;
  final int pricePerKgPiasters;
  final String createdBy;
  final List<int>? sampleWeightsGrams;
  final int tareGrams;
  final bool active = true;

  int get totalWeightGrams => boxes * avgWeightGrams;

  /// round_half_up(totalWeightGrams × pricePerKgPiasters / 1000)
  int get valuePiasters => (totalWeightGrams * pricePerKgPiasters + 500) ~/ 1000;
}

class _Payment {
  _Payment({
    required this.id,
    required this.no,
    required this.targetType,
    required this.targetId,
    required this.payeeType,
    required this.payeeId,
    required this.payeeName,
    required this.coolerId,
    required this.amount,
    required this.method,
    required this.at,
    required this.createdBy,
  });

  final String id;
  final String no;
  final String targetType;
  final String targetId;
  final String payeeType;
  final String payeeId;
  final String payeeName;
  final String coolerId;
  final int amount;
  final String method;
  final DateTime at;
  final String createdBy;
  final bool active = true;
}

class _Packaging {
  _Packaging({
    required this.id,
    required this.no,
    required this.supplier,
    required this.invoiceNo,
    required this.coolerId,
    required this.at,
    required this.status,
    required this.itemsCount,
    required this.completeTotal,
    required this.createdBy,
    this.incompleteCount = 0,
    this.late = false,
    this.notes = '',
  });

  final String id;
  final String no;
  final String supplier;
  final String invoiceNo;
  final String coolerId;
  final DateTime at;
  final String status;
  final int itemsCount;
  final int incompleteCount;
  final int completeTotal;
  final bool late;
  final String notes;
  final String createdBy;
}

class _SheetCheck {
  _SheetCheck(this.key, this.title, this.rows, {this.exists = true, this.missing = const []});

  final String key;
  final String title;
  int rows;
  bool exists;
  List<String> missing;

  Map<String, dynamic> toJson() => {
        'key': key,
        'title': title,
        'exists': exists,
        'rows': rows,
        'missingColumns': missing,
        'extraColumns': const <String>[],
      };
}

class _Sheet {
  _Sheet({
    required this.spreadsheetId,
    required this.title,
    required this.connectedAs,
    required this.lastWriteAt,
    required this.lastErrorAt,
    required this.lastErrorMessage,
    required this.checks,
  });

  String spreadsheetId;
  String title;
  final String connectedAs;
  String lastWriteAt;
  final String lastErrorAt;
  final String lastErrorMessage;
  final List<_SheetCheck> checks;

  void bumpWrite(String at) => lastWriteAt = at;

  Map<String, dynamic> toJson(String checkedAt) => {
        'configured': true,
        'spreadsheetId': spreadsheetId,
        'source': 'bound',
        'title': title,
        'url': 'https://docs.google.com/spreadsheets/d/$spreadsheetId/edit',
        'connectedAs': connectedAs,
        'timezone': 'Africa/Cairo',
        'ok': checks.every((c) => c.exists && c.missing.isEmpty),
        'sheets': [for (final c in checks) c.toJson()],
        'lastWriteAt': lastWriteAt,
        'lastError': {'at': lastErrorAt, 'message': lastErrorMessage},
        'checkedAt': checkedAt,
      };
}
