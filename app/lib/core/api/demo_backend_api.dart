import 'dart:convert';
import 'dart:math' as math;

import 'package:uuid/uuid.dart';

import 'api_exception.dart';
import 'backend_actions.dart';
import 'backend_api.dart';

/// خادم تجريبي يعمل في الذاكرة بالكامل (--dart-define=DEMO=true).
///
/// البيانات مطابقة للتصميم المعتمد: البراد 14 «شحنة دمياط» والبراد 13 «شحنة الإسكندرية» مفتوحان،
/// والبراد 12 «شحنة بورسعيد» مقفّل. كل إجراءات العقد (القراءة والحفظ) تتبع قواعد الخادم الحقيقي
/// (backend/src/*.gs): الصلاحيات، والتحقق ورسائله العربية، والإصدارات، وعدم التكرار، وتُرد بنفس صيغة
/// docs/API.md. كل الأرقام تُحسب من السجلات بعد كل حفظ. لا يتصل بالإنترنت ولا بأي ملف.
class DemoBackendApi extends BackendApi with BackendActions {
  DemoBackendApi({this.latency = const Duration(milliseconds: 300), DateTime Function()? clock})
      : _clock = clock ?? DateTime.now {
    final now = _clock().toLocal();
    final designNow = DateTime(now.year, now.month, now.day, 10, 58);
    // بعد 10:58 ص تظهر أوقات التصميم كما هي (فُتح اليوم 06:40 ص)؛ قبلها تُزاح حتى لا تكون في المستقبل.
    _ref = now.isBefore(designNow) ? now : designNow;
    _reqNow = now;
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
  final _items = <_Item>[];
  final _itemTypes = <_ItemType>[];
  final _users = <_User>[];
  final _replays = <String, String>{};
  late Map<String, dynamic> _settings;
  late _Sheet _sheet;
  int _dataVersion = 1;
  String _userId = _bootstrapId;

  /// وقت الطلب الجاري (rqNow_ في الخادم): كل ما يُكتب في طلب واحد يحمل الوقت نفسه.
  late DateTime _reqNow;

  /// requestId الطلب الجاري، يُحفظ في «مفتاح عدم التكرار» للسجلات المنشأة (العقد §7).
  String _requestId = '';

  /// رقم يزيد مع كل عملية حفظ ناجحة (للاختبارات والتشخيص).
  int get dataVersion => _dataVersion;

  /// يبدّل المستخدم الحالي في الوضع التجريبي (US-0001 … US-0005) لعرض الصلاحيات واختبارها.
  /// كل الطلبات التالية تُنفَّذ باسمه وبصلاحياته، والدخول يعيده هو.
  void switchUser(String userId) {
    if (!_users.any((u) => u.id == userId)) throw ArgumentError.value(userId, 'userId', 'لا يوجد مستخدم بهذا المعرّف');
    _userId = userId;
  }

  /// يمسح النتائج المحفوظة للطلبات (مثل انتهاء ذاكرة CacheService بعد 6 ساعات). بعدها يُكشف تكرار الإنشاء
  /// من «مفتاح عدم التكرار» في السجل نفسه، فيعود السجل الأول مع replayed: true.
  void forgetRequestCache() => _replays.clear();

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
    final p = _clone(payload);
    _reqNow = _now();

    final spec = _actions[action];
    if (spec == null) {
      throw ApiException(
        ApiErrorCode.unknownAction,
        'الإجراء «${action.length > 60 ? action.substring(0, 60) : action}» غير معروف للخادم. '
        'حدّث التطبيق إلى آخر إصدار ثم أعد المحاولة.',
        field: 'action',
        details: {'action': action},
      );
    }
    if (!spec.auth) return _clone(spec.fn(p));
    if (session == null || session!.trim().isEmpty) {
      throw const ApiException(
        ApiErrorCode.authRequired,
        'يجب تسجيل الدخول أولًا. سجّل الدخول بحساب Google ثم أعد المحاولة.',
      );
    }
    if (!spec.write) {
      _verifyUser();
      if (spec.perm != null) _require(spec.perm!);
      return _clone(spec.fn(p));
    }

    // مثل HttpBackendApi: requestId جديد لكل عملية حفظ ما لم يُمرَّر واحد لإعادة المحاولة.
    final id = (requestId ?? (mutation ? const Uuid().v4() : '')).trim();
    if (id.isEmpty) {
      throw const ApiException(
        ApiErrorCode.validation,
        'معرّف الطلب (requestId) مطلوب لكل عملية حفظ حتى لا تتكرر. حدّث التطبيق ثم أعد المحاولة.',
        field: 'requestId',
      );
    }
    if (id.length > 128 || !RegExp(r'^[A-Za-z0-9._:-]+$').hasMatch(id)) {
      throw const ApiException(
        ApiErrorCode.validation,
        'معرّف الطلب (requestId) غير صالح. يجب أن يكون UUID. حدّث التطبيق ثم أعد المحاولة.',
        field: 'requestId',
      );
    }
    // النتيجة المحفوظة تُعاد لصاحبها فقط (Main.gs): مستخدم آخر بالمعرّف نفسه يمر بالفحوص كاملة.
    final cacheKey = '${_currentUser.id}|${_currentUser.email}|$id';
    final cached = _replays[cacheKey];
    if (cached != null) return _decode(cached);
    _verifyUser();
    if (spec.perm != null) _require(spec.perm!);
    _requestId = id;
    // كل إجراء يتحقق من كل المدخلات قبل أي كتابة، فالخطأ لا يترك أثرًا ولا يُحفظ.
    final text = jsonEncode(spec.fn(p));
    _dataVersion++;
    _sheet.bumpWrite(_iso(_reqNow));
    _replays[cacheKey] = text;
    return _decode(text);
  }

  static Map<String, dynamic> _decode(String text) => (jsonDecode(text) as Map).cast<String, dynamic>();

  static Map<String, dynamic> _clone(Map<String, dynamic> m) => _decode(jsonEncode(m));

  /// جدول الإجراءات مثل mainActions_ في Main.gs: الصلاحية المطلوبة، وهل يغيّر البيانات.
  late final Map<String, _Action> _actions = {
    'auth.login': _Action(_login, auth: false),
    'auth.logout': _Action((_) => {}, auth: false),
    'auth.me': _Action((_) => {'user': _userJson(_currentUser)}),

    'dashboard.get': _Action(_dashboard, perm: 'viewData'),
    'coolers.list': _Action(_coolersList, perm: 'viewData'),
    'coolers.get': _Action(_coolersGet, perm: 'viewData'),
    'farmers.list': _Action(_farmersList, perm: 'viewData'),
    'purchases.list': _Action(_purchasesList, perm: 'viewData'),
    'payments.list': _Action(_paymentsList, perm: 'viewData'),
    'packaging.list': _Action(_packagingList, perm: 'viewData'),
    'packaging.get': _Action(_packagingGet, perm: 'viewData'),
    'itemTypes.list': _Action(_itemTypesList, perm: 'viewData'),
    'settings.get': _Action((_) => Map<String, dynamic>.of(_settings), perm: 'viewData'),

    'coolers.create': _Action(_coolersCreate, perm: 'recordPurchases', write: true),
    'coolers.close': _Action(_coolersClose, perm: 'closeCoolers', write: true),
    'coolers.reopen': _Action(_coolersReopen, perm: 'reopenCoolers', write: true),
    'farmers.create': _Action(_farmersCreate, perm: 'addFarmers', write: true),
    'farmers.update': _Action(_farmersUpdate, perm: 'addFarmers', write: true),
    'purchases.create': _Action(_purchasesCreate, perm: 'recordPurchases', write: true),
    'purchases.update': _Action(_purchasesUpdate, perm: 'recordPurchases', write: true),
    'purchases.cancel': _Action(_purchasesCancel, perm: 'recordPurchases', write: true),
    'payments.create': _Action(_paymentsCreate, perm: 'recordPayments', write: true),
    'payments.cancel': _Action(_paymentsCancel, perm: 'recordPayments', write: true),
    'packaging.save': _Action(_packagingSave, perm: 'packaging', write: true),
    'packaging.approve': _Action(_packagingApprove, perm: 'packaging', write: true),
    'packaging.cancel': _Action(_packagingCancel, perm: 'packaging', write: true),
    'itemTypes.save': _Action(_itemTypesSave, perm: 'manageSettings', write: true),
    'users.list': _Action((_) => {'users': [for (final u in _users) _userJson(u)]}, perm: 'manageUsers'),
    'users.add': _Action(_usersAdd, perm: 'manageUsers', write: true),
    'users.update': _Action(_usersUpdate, perm: 'manageUsers', write: true),
    'settings.update': _Action(_settingsUpdate, perm: 'manageSettings', write: true),
    'sheet.status': _Action((_) => _sheetStatusJson(), perm: 'manageSettings'),
    'sheet.repair': _Action(_sheetRepair, perm: 'manageSettings', write: true),
    'sheet.connect': _Action(_sheetConnect, perm: 'manageSettings', write: true),
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

  static final _dateRe = RegExp(
    r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})(?:(?:T|\s+)(\d{1,2}):(\d{2})(?::(\d{2})(?:[.,]\d+)?)?)?\s*(Z|[+-]\d{2}(?::?\d{2})?)?$',
    caseSensitive: false,
  );

  /// مثل parseDateText_: ISO مع إزاحة، أو "yyyy-MM-dd HH:mm"، أو "yyyy-MM-dd". بلا إزاحة ⇒ بتوقيت الجهاز.
  static DateTime? _parseDateText(String text) {
    final m = _dateRe.firstMatch(_latinDigits(text).trim());
    if (m == null) return null;
    int g(int i) => m.group(i) == null ? 0 : int.parse(m.group(i)!);
    final y = g(1), mo = g(2), d = g(3), h = g(4), mi = g(5), se = g(6);
    if (y < 1900 || y > 2200 || mo < 1 || mo > 12 || d < 1 || d > 31 || h > 23 || mi > 59 || se > 59) return null;
    final check = DateTime.utc(y, mo, d);
    if (check.day != d || check.month != mo) return null;
    final zone = m.group(7);
    if (zone == null) return DateTime(y, mo, d, h, mi, se);
    final off = _offsetMinutes(zone.toUpperCase());
    if (off == null) return null;
    return DateTime.utc(y, mo, d, h, mi, se).subtract(Duration(minutes: off)).toLocal();
  }

  static int? _offsetMinutes(String s) {
    if (s == 'Z') return 0;
    final m = RegExp(r'^([+-])(\d{2}):?(\d{2})?$').firstMatch(s);
    if (m == null) return null;
    final v = int.parse(m.group(2)!) * 60 + (m.group(3) == null ? 0 : int.parse(m.group(3)!));
    if (v > 14 * 60) return null;
    return m.group(1) == '-' ? -v : v;
  }

  static bool _isDateOnly(String s) => RegExp(r'^\d{4}-\d{1,2}-\d{1,2}$').hasMatch(_latinDigits(s).trim());

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
    String emailOf(String name) => _users.firstWhere((u) => u.name == name).email;

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
        createdBy: owner,
      ));
    }

    _coolers.addAll([
      _Cooler(
        id: 'CL-0012', no: 12, name: 'شحنة بورسعيد', carNo: 'ط ب ع 4528', driver: 'رضا السعدني',
        openedAt: _at(3, 6, 15), openedBy: owner, open: false, closedAt: _at(2, 17, 30), closedBy: karim, version: 4,
        // لقطة «عند التقفيل»: دُفع بعدها 7,943.00 + 5,320.00 للمزارعين، واعتُمدت تعبئة متأخرة 455.00.
        snapshot: const {
          'farmers': 9, 'purchases': 14, 'boxes': 588, 'weightGrams': 6391400,
          'valuePiasters': 9601400, 'paidPiasters': 7528550, 'remainingPiasters': 2072850,
          'packagingPiasters': 1451500, 'totalCostPiasters': 11052900,
        },
      ),
      _Cooler(
        id: 'CL-0013', no: 13, name: 'شحنة الإسكندرية', carNo: 'س د م 2194', driver: 'خالد فرج',
        openedAt: _at(1, 15, 20), openedBy: karim,
      ),
      _Cooler(
        id: 'CL-0014', no: 14, name: 'شحنة دمياط', carNo: 'ن ق ر 7316', driver: 'سامي عطية',
        openedAt: _at(0, 6, 40), openedBy: owner,
      ),
    ]);

    // (البراد، المزارع، الوقت، الصناديق، متوسط الصندوق بالجرام، سعر الكيلو بالقرش، المسجِّل)
    void buy(String cooler, int farmer, DateTime at, int boxes, int avg, int price, String by,
        {List<int>? sample, int? tare}) {
      _purchases.add(_Purchase(
        id: _seq('PU', _purchases.length + 1),
        coolerId: cooler,
        farmerId: _seq('FR', farmer),
        at: at,
        boxes: boxes,
        avg: avg,
        price: price,
        samples: sample,
        tare: tare,
        createdAt: at,
        createdBy: by,
        createdByEmail: emailOf(by),
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

    // أصناف التعبئة الافتراضية (sheets/build_sheet.py) بوحداتها.
    const types = [
      ('الصناديق', 'قطعة'),
      ('الباليتات', 'قطعة'),
      ('الشمبر', 'رزمة'),
      ('جزاري «ورق الفاصل»', 'رزمة'),
      ('المناديل', 'كرتونة'),
      ('غطاء باليت', 'قطعة'),
      ('الملصقات', 'رول'),
      ('جهاز تجسس', 'قطعة'),
      ('السترتش', 'لفة'),
    ];
    for (var i = 0; i < types.length; i++) {
      _itemTypes.add(_ItemType(_seq('IT', i + 1), types[i].$1, types[i].$2, i + 1, true));
    }

    // (البراد، الوقت، المورد، الفاتورة، الحالة، المسجِّل، الأصناف: (الصنف، الكمية، سعر الوحدة بالقرش))
    // الكمية أو السعر null = لم يُكتب بعد (ليس صفرًا)، فالصنف «غير مكتمل».
    void pack(String cooler, DateTime at, String supplier, String invoice, String status, String by,
        List<(String, int?, int?)> items, {bool late = false, String notes = ''}) {
      final n = _packaging.length + 1;
      final pk = _Packaging(
        id: _seq('PK', n),
        no: _seq('P', n),
        supplier: supplier,
        invoiceNo: invoice,
        coolerId: cooler,
        at: at,
        status: status,
        late: late,
        notes: notes,
        createdAt: at,
        createdBy: by,
        createdByEmail: emailOf(by),
        // إنشاء المسودة = الإصدار 1، والاعتماد يرفعه إلى 2.
        version: status == 'approved' ? 2 : 1,
      );
      _packaging.add(pk);
      for (final (name, quantity, price) in items) {
        _items.add(_Item(
          id: _seq('PD', _items.length + 1),
          packagingId: pk.id,
          name: name,
          unit: _itemTypes.firstWhere((t) => t.name == name).unit,
          quantity: quantity,
          price: price,
        ));
      }
    }

    pack('CL-0012', _at(3, 6, 50), 'الوادي للتغليف', '1187', 'approved', karim, const [
      ('الصناديق', 600, 1800),
      ('الباليتات', 13, 14500),
      ('السترتش', 4, 21000),
      ('الملصقات', 6, 16500),
    ]);
    pack('CL-0012', _at(1, 11, 15), 'مؤسسة النيل للكرتون', '552', 'approved', karim, const [('غطاء باليت', 13, 3500)],
        late: true, notes: 'أغطية الباليتات وصلت بعد تقفيل البراد.');
    pack('CL-0014', _at(0, 7, 30), 'مؤسسة النيل للكرتون', '561', 'approved', owner, const [
      ('الصناديق', 200, 1800),
      ('الشمبر', 4, 9500),
      ('جزاري «ورق الفاصل»', 4, 13000),
    ]);
    pack('CL-0014', _at(0, 9, 50), 'الوادي للتغليف', '', 'draft', karim, const [
      ('الباليتات', 12, 14500),
      ('غطاء باليت', 12, null),
      ('السترتش', 4, 21000),
      ('الملصقات', null, null),
    ], notes: 'سعر غطاء الباليت وكمية الملصقات لم يُحددا بعد.');

    // (العملية، المبلغ، الطريقة، الوقت، المسجِّل) — بترتيب الوقت لتتسلسل الأرقام.
    void pay(String target, int? amount, String method, DateTime at, String by) {
      final n = _payments.length + 1;
      final isPurchase = target.startsWith('PU-');
      final purchase = isPurchase ? _purchases.firstWhere((x) => x.id == target) : null;
      final pk = isPurchase ? null : _packaging.firstWhere((x) => x.id == target);
      _payments.add(_Payment(
        id: _seq('PY', n),
        no: _seq('D', n),
        targetType: isPurchase ? 'purchase' : 'packaging',
        targetId: target,
        payeeType: isPurchase ? 'farmer' : 'supplier',
        payeeId: purchase?.farmerId ?? '',
        payeeName: purchase != null ? _farmer(purchase.farmerId)!.name : pk!.supplier,
        coolerId: purchase?.coolerId ?? pk!.coolerId,
        amount: amount ?? purchase!.valuePiasters,
        method: method,
        at: at,
        createdAt: at,
        createdBy: by,
        createdByEmail: emailOf(by),
      ));
      // دفعة لاحقة (لا مع الشراء نفسه) تحدّث أعمدة المدفوع في صف العملية، فيزيد إصدارها (العقد §7).
      if (purchase != null && !at.isAtSameMomentAs(purchase.at)) {
        purchase
          ..version += 1
          ..updatedAt = at
          ..updatedBy = by;
      }
      if (pk != null) pk.version += 1;
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
        _SheetCheck('coolers', 'البرادات', 0),
        _SheetCheck('farmers', 'المزارعون', 0),
        _SheetCheck('purchases', 'مشتريات الرمان', 0),
        _SheetCheck('packaging', 'مشتريات التعبئة', 0, missing: const ['رقم الفاتورة']),
        _SheetCheck('packaging_items', 'تفاصيل التعبئة', 0),
        _SheetCheck('payments', 'المدفوعات', 0),
        _SheetCheck('users', 'المستخدمون', 0),
        _SheetCheck('settings', 'الإعدادات', 8),
        _SheetCheck('item_types', 'أصناف التعبئة', 0),
        _SheetCheck('audit', 'سجل التعديلات', 0, exists: false, missing: const [
          'المعرّف', 'التاريخ والوقت', 'المستخدم', 'الإجراء', 'نوع السجل', 'معرّف السجل',
          'الوصف', 'القيم السابقة', 'القيم الجديدة', 'السبب',
        ]),
      ],
    );
  }

  static String _seq(String prefix, int n) => '$prefix-${n.toString().padLeft(4, '0')}';

  /// المعرّف التالي: البادئة + (أكبر رقم مستخدم + 1)، مثل stNextId_.
  static String _nextId(String prefix, Iterable<String> ids) {
    final re = RegExp('^$prefix-?(\\d+)\$', caseSensitive: false);
    var max = 0;
    for (final id in ids) {
      final m = re.firstMatch(id);
      if (m != null) max = math.max(max, int.parse(m.group(1)!));
    }
    return _seq(prefix, max + 1);
  }

  _Farmer? _farmer(String id) => _farmers.where((f) => f.id == id).firstOrNull;
  _Cooler? _cooler(String id) => _coolers.where((c) => c.id == id).firstOrNull;
  _Packaging? _pack(String id) => _packaging.where((x) => x.id == id).firstOrNull;
  _Purchase? _purchase(String id) => _purchases.where((x) => x.id == id).firstOrNull;

  String _farmerName(String id) => _farmer(id)?.name ?? '';

  int _paidFor(String targetId) =>
      _payments.where((x) => x.active && x.targetId == targetId).fold(0, (s, x) => s + x.amount);

  int _activeCount(String targetId) => _payments.where((x) => x.active && x.targetId == targetId).length;

  int get _emptyBoxGrams => (_settings['emptyBoxGrams'] as num?)?.toInt() ?? 1900;

  /// أصناف شراء التعبئة غير المحذوفة بترتيب إضافتها.
  List<_Item> _pkItems(String packagingId) => [
        for (final i in _items)
          if (i.packagingId == packagingId && !i.removed) i,
      ];

  ({int count, int incomplete, int total}) _pkTotals(String packagingId) {
    var count = 0, incomplete = 0, total = 0;
    for (final i in _pkItems(packagingId)) {
      count++;
      if (i.complete) {
        total += i.total!;
      } else {
        incomplete++;
      }
    }
    return (count: count, incomplete: incomplete, total: total);
  }

  // ===================================================================================== الأرقام

  /// round_half_up(n / d) لأعداد صحيحة (d > 0)، مثل roundHalfUpDiv_.
  static int _roundDiv(int n, int d) {
    if (n < 0) return -_roundDiv(-n, d);
    final r = n % d;
    final q = n ~/ d;
    return 2 * r >= d ? q + 1 : q;
  }

  /// valuePiasters = round_half_up(totalWeightGrams × pricePerKgPiasters / 1000)
  static int _value(int totalWeightGrams, int pricePerKgPiasters) =>
      _roundDiv(totalWeightGrams * pricePerKgPiasters, 1000);

  /// round_half_up(value × 1000 / weight)
  static int _avgPrice(int value, int weight) => weight > 0 ? _roundDiv(value * 1000, weight) : 0;

  /// round(mean(samples) − tare) بأعداد صحيحة.
  static int _sampleNet(List<int> samples, int tare) =>
      _roundDiv(samples.fold(0, (s, x) => s + x) - tare * samples.length, samples.length);

  static String _payStatus(int value, int paid) => paid <= 0 ? 'unpaid' : (paid >= value ? 'paid' : 'partial');

  /// 12400 → "12.4"
  static String _gramsText(int grams) {
    final g = grams.abs();
    final frac = (g % 1000).toString().padLeft(3, '0').replaceFirst(RegExp(r'0+$'), '');
    return '${grams < 0 ? '-' : ''}${g ~/ 1000}${frac.isEmpty ? '' : '.$frac'}';
  }

  /// 550000 → "550 كغ"
  static String _fmtKg(int grams) => '${_gramsText(grams)} كغ';

  /// 825000 → "8,250.00 ج.م"
  static String _fmtMoney(int piasters) {
    final a = piasters.abs();
    final whole = (a ~/ 100).toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    return '${piasters < 0 ? '-' : ''}$whole.${_two(a % 100)} ج.م';
  }

  // ===================================================================================== النصوص

  /// يحوّل الأرقام العربية-الهندية والفارسية إلى أرقام لاتينية.
  static String _latinDigits(String s) => s.replaceAllMapped(RegExp('[\u0660-\u0669\u06F0-\u06F9]'), (m) {
        final c = m[0]!.codeUnitAt(0);
        return '${c >= 0x06F0 ? c - 0x06F0 : c - 0x0660}';
      });

  /// تطبيع للمقارنة والبحث مثل normText_: بلا تشكيل أو تطويل، توحيد الألف والياء والتاء المربوطة.
  static String _norm(Object? s) => _latinDigits(s?.toString() ?? '')
      .replaceAll(RegExp('[\u064B-\u065F\u0670\u0640\u200B-\u200F\u202A-\u202E]'), '')
      .replaceAll(RegExp('[\u0622\u0623\u0625\u0671]'), '\u0627')
      .replaceAll('\u0649', '\u064A')
      .replaceAll('\u0629', '\u0647')
      .replaceAll('\u0624', '\u0648')
      .replaceAll('\u0626', '\u064A')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toLowerCase();

  // ===================================================================================== الدخول والصلاحيات

  _User get _currentUser => _users.firstWhere((u) => u.id == _userId);

  /// الاسم المعروض لمن يسجّل (labelName_ من «الاسم (البريد)»).
  String get _meName => _currentUser.name.trim().isEmpty ? _currentUser.email : _currentUser.name;

  Map<String, dynamic> _login(Map<String, dynamic> p) {
    _inStr(p['idToken'], 'idToken', 'رمز الدخول من Google',
        required: true, max: 8192, hint: 'سجّل الدخول بحساب Google مرة أخرى.');
    _verifyUser();
    return {
      'session': demoSession,
      'expiresAt': _iso(_now().add(const Duration(days: 7))),
      'user': _userJson(_currentUser),
    };
  }

  /// مثل authVerifySession_: المستخدم المعطّل لا يدخل (إلا المدير الأساسي).
  void _verifyUser() {
    final u = _currentUser;
    if (u.isBootstrap || u.active) return;
    throw ApiException(
      ApiErrorCode.notAllowed,
      'الحساب ${u.email} معطّل: خانة «الحالة» في صفحة «المستخدمون» ليست «نشط». '
      'اطلب من المدير تفعيله (اختيار «نشط») ثم سجّل الدخول مرة أخرى.',
      details: {'email': u.email, 'reason': 'disabled'},
    );
  }

  static const _permLabels = {
    'addFarmers': 'إضافة المزارعين',
    'recordPurchases': 'تسجيل المشتريات',
    'editOthers': 'تعديل عمليات الآخرين',
    'recordPayments': 'تسجيل المدفوعات',
    'packaging': 'مشتريات التعبئة',
    'closeCoolers': 'تقفيل البرادات',
    'reopenCoolers': 'إعادة فتح البرادات',
    'manageUsers': 'إدارة المستخدمين',
    'manageSettings': 'إدارة الإعدادات وملف البيانات',
    'viewData': 'عرض البيانات',
  };

  /// مثل requirePermission: FORBIDDEN مع details.permission.
  void _require(String key) {
    if (_perms(_currentUser)[key] == true) return;
    throw ApiException(
      ApiErrorCode.forbidden,
      'ليس لديك صلاحية «${_permLabels[key] ?? key}». اطلب من المدير منحك هذه الصلاحية.',
      details: {'permission': key},
    );
  }

  /// الإجراءات التي تمس عملية شراء: من أنشأها، أو من يملك «تعديل عمليات الآخرين».
  void _requireOwnerOrEditOthers(_Purchase x) {
    if (x.createdByEmail.isNotEmpty && x.createdByEmail.toLowerCase() == _currentUser.email.toLowerCase()) return;
    _require('editOthers');
  }

  // ===================================================================================== المستخدمون

  static const _roles = {'admin': 'مدير', 'entry': 'موظف إدخال', 'viewer': 'مشاهدة فقط'};
  static const _permKeys = ['addFarmers', 'recordPurchases', 'editOthers', 'recordPayments', 'packaging', 'closeCoolers'];

  Map<String, bool> _perms(_User u) {
    final admin = u.role == 'admin';
    final entry = u.role == 'entry';
    return {
      for (final k in _permKeys) k: admin || (entry && (u.perms[k] ?? false)),
      'reopenCoolers': admin,
      'manageUsers': admin,
      'manageSettings': admin,
      'viewData': true,
    };
  }

  Map<String, dynamic> _userJson(_User u) => {
        'id': u.id,
        'email': u.email,
        'name': u.name,
        'role': u.role,
        'status': u.active ? 'active' : 'disabled',
        'isBootstrap': u.isBootstrap,
        'version': u.version,
        'permissions': _perms(u),
      };

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
    return {'user': _userJson(user)};
  }

  Map<String, dynamic> _usersUpdate(Map<String, dynamic> p) {
    final id = _str(p, 'id', 'المستخدم', required: true, max: 64, hint: 'اختره من القائمة ثم أعد المحاولة.');
    final expected = p['expectedVersion'];
    if (expected is! num || expected < 1) {
      _invalid('expectedVersion', '«رقم الإصدار» مطلوب. حدّث البيانات ثم أعد الحفظ.');
    }
    final user = _users.where((u) => u.id == id).firstOrNull;
    if (user == null) _notFound('id', 'المستخدم', id);
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
    return {'user': _userJson(user)};
  }

  // ===================================================================================== التحقق من المدخلات (Util.gs)

  static Never _invalid(String field, String message, [Map<String, dynamic> details = const {}]) =>
      throw ApiException(ApiErrorCode.validation, message, field: field, details: details);

  static Never _notFound(String field, String thing, String id) => throw ApiException(
        ApiErrorCode.notFound,
        'لم يتم العثور على $thing بالمعرّف «$id». حدّث البيانات واختره من القائمة مرة أخرى.',
        field: field,
        details: {'id': id},
      );

  static Never _conflict(String thing, int currentVersion, Map<String, dynamic> current,
          {String verb = 'الحفظ', Map<String, dynamic> extra = const {}}) =>
      throw ApiException(
        ApiErrorCode.conflict,
        'عدّل مستخدم آخر $thing بعد أن فتحته. راجع البيانات الحالية ثم أعد $verb.',
        field: 'expectedVersion',
        details: {'currentVersion': currentVersion, 'current': current, ...extra},
      );

  static bool _present(Object? v) => !(v == null || (v is String && v.trim().isEmpty));

  /// نص اختياري أو مطلوب (inStr_). يعيد '' إن كان غائبًا وغير مطلوب.
  static String _inStr(Object? v, String field, String label,
      {bool required = false, int max = 200, bool multiline = false, String? hint}) {
    if (!_present(v)) {
      if (required) _invalid(field, '«$label» مطلوب. ${hint ?? 'اكتبه ثم أعد المحاولة.'}');
      return '';
    }
    if (v is! String && v is! num) _invalid(field, '«$label» يجب أن يكون نصًا. صحّحه ثم أعد المحاولة.');
    final raw = v.toString();
    final s = multiline ? raw.replaceAll(RegExp(r'\r\n?'), '\n').trim() : raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.length > max) _invalid(field, '«$label» أطول من المسموح ($max حرفًا). اختصره ثم أعد المحاولة.', {'max': max});
    return s;
  }

  static String _str(Map<String, dynamic> p, String field, String label,
          {bool required = false, int max = 200, bool multiline = false, String? hint}) =>
      _inStr(p[field], field, label, required: required, max: max, multiline: multiline, hint: hint);

  /// عدد صحيح (inInt_): يقبل أرقامًا عربية في النص. يعيد null إن كان غائبًا وغير مطلوب.
  static int? _inInt(Object? v, String field, String label,
      {bool required = false, int? min, int? max, String Function(int)? fmt, String? hint}) {
    if (!_present(v)) {
      if (required) _invalid(field, '«$label» مطلوب. ${hint ?? 'اكتب القيمة ثم أعد المحاولة.'}');
      return null;
    }
    int? n;
    if (v is int) {
      n = v;
    } else if (v is double) {
      n = v.isFinite && v == v.truncateToDouble() ? v.toInt() : null;
    } else if (v is String) {
      final s = _latinDigits(v).trim();
      if (RegExp(r'^[+-]?\d+$').hasMatch(s)) n = int.tryParse(s);
    }
    if (n == null) _invalid(field, '«$label» يجب أن يكون رقمًا صحيحًا. صحّح القيمة ثم أعد المحاولة.');
    final f = fmt ?? (int x) => '$x';
    if ((min != null && n < min) || (max != null && n > max)) {
      final String msg;
      if (min != null && max != null) {
        msg = '«$label» يجب أن يكون بين ${f(min)} و${f(max)}.';
      } else if (min != null) {
        msg = '«$label» يجب ألا يقل عن ${f(min)}.';
      } else {
        msg = '«$label» يجب ألا يزيد على ${f(max!)}.';
      }
      _invalid(field, '$msg صحّح القيمة ثم أعد المحاولة.', {'min': min, 'max': max});
    }
    return n;
  }

  /// قيمة من قائمة (inEnum_). choices: {قيمة API: وصف عربي}.
  static String? _inEnum(Object? v, String field, String label, Map<String, String> choices, {bool required = false}) {
    final list = choices.values.map((v) => '«$v»').join(' أو ');
    if (!_present(v)) {
      if (required) _invalid(field, '«$label» مطلوب. اختر $list.');
      return null;
    }
    final s = v.toString().trim();
    if (!choices.containsKey(s)) _invalid(field, 'قيمة «$label» غير صحيحة. اختر $list.', {'allowed': choices.keys.toList()});
    return s;
  }

  static String? _enum(Map<String, dynamic> p, String field, String label, Map<String, String> choices,
          {bool required = false}) =>
      _inEnum(p[field], field, label, choices, required: required);

  /// قيمة منطقية (inBool_)؛ الغائبة → [def].
  static bool _inBool(Object? v, String field, String label, bool def) {
    if (v == null || v == '') return def;
    if (v is bool) return v;
    if (v == 'true' || v == 1 || v == '1') return true;
    if (v == 'false' || v == 0 || v == '0') return false;
    _invalid(field, '«$label» يجب أن يكون نعم أو لا. صحّحه ثم أعد المحاولة.');
  }

  /// تاريخ ووقت (inTime_). الغائب → null.
  static DateTime? _inTime(Object? v, String field, String label) {
    if (!_present(v)) return null;
    final d = v is String ? _parseDateText(v) : null;
    if (d == null) {
      _invalid(field, '«$label» بتنسيق غير صحيح. أرسل التاريخ والوقت مثل 2026-10-02T06:40:00+03:00.');
    }
    return d;
  }

  static int _expectedVersion(Map<String, dynamic> p) => _inInt(p['expectedVersion'], 'expectedVersion', 'رقم الإصدار',
      required: true, min: 1, max: 1000000000, hint: 'حدّث البيانات ثم أعد الحفظ.')!;

  static String _id(Map<String, dynamic> p, String field, String label) =>
      _str(p, field, label, required: true, max: 64, hint: 'اختره من القائمة ثم أعد المحاولة.');

  /// سبب مطلوب للإلغاء أو إعادة الفتح. [purpose] مثل «لإلغاء الدفعة».
  static String _reason(Map<String, dynamic> p, String purpose) => _str(p, 'reason', 'السبب',
      required: true, max: 500, multiline: true, hint: 'اكتب سببًا واضحًا $purpose ثم أعد المحاولة.');

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
    return Map<String, dynamic>.of(_settings);
  }

  /// حالة الملف بعدد الصفوف الحالي في كل صفحة.
  Map<String, dynamic> _sheetStatusJson() {
    final rows = {
      'coolers': _coolers.length,
      'farmers': _farmers.length,
      'purchases': _purchases.length,
      'packaging': _packaging.length,
      'packaging_items': _items.length,
      'payments': _payments.length,
      'users': _users.length,
      'item_types': _itemTypes.length,
    };
    for (final c in _sheet.checks) {
      final n = rows[c.key];
      if (n != null && c.exists) c.rows = n;
    }
    return _sheet.toJson(_iso(_now()));
  }

  Map<String, dynamic> _sheetRepair(Map<String, dynamic> _) {
    for (final c in _sheet.checks) {
      if (!c.exists) c.rows = c.key == 'audit' ? 1 : 0;
      c
        ..exists = true
        ..missing = const [];
    }
    return _sheetStatusJson();
  }

  Map<String, dynamic> _sheetConnect(Map<String, dynamic> p) {
    // قبل قراءة الحمولة، حتى لا يُكشف حساب الربط لغير المدير الأساسي (SheetAdmin.gs).
    if (!_currentUser.isBootstrap) {
      throw const ApiException(
        ApiErrorCode.forbidden,
        'ربط ملف بيانات آخر متاح للمدير الأساسي (صاحب الحساب) فقط، لأنه ينقل كل العمليات الجديدة إلى ذلك الملف. '
        'اطلب من المدير الأساسي ربط الملف إن لزم.',
        details: {'permission': 'manageSettings', 'reason': 'bootstrap_only'},
      );
    }
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
    return {
      ..._sheetStatusJson(),
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

  // ===================================================================================== صيغ الرد

  Map<String, dynamic> _coolerJson(_Cooler c) {
    final purchases = _purchases.where((x) => x.active && x.coolerId == c.id).toList();
    final value = purchases.fold(0, (s, x) => s + x.valuePiasters);
    final weight = purchases.fold(0, (s, x) => s + x.totalWeightGrams);
    final paid = purchases.fold(0, (s, x) => s + _paidFor(x.id));
    var packaging = 0, late = 0;
    for (final x in _packaging.where((x) => x.coolerId == c.id && x.status == 'approved')) {
      final total = _pkTotals(x.id).total;
      packaging += total;
      if (x.late) late += total;
    }
    return {
      'id': c.id,
      'no': c.no,
      'name': c.name,
      'status': c.open ? 'open' : 'closed',
      'carNo': c.carNo,
      'driver': c.driver,
      'notes': c.notes,
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
      'closeSnapshot': c.snapshot == null ? null : Map<String, dynamic>.of(c.snapshot!),
    };
  }

  Map<String, dynamic> _farmerJson(_Farmer f) => {
        'id': f.id,
        'no': f.no,
        'name': f.name,
        'phone': f.phone,
        'village': f.village,
        'notes': f.notes,
        'status': f.active ? 'active' : 'inactive',
        'version': f.version,
      };

  Map<String, dynamic> _purchaseJson(_Purchase x) {
    final paid = _paidFor(x.id);
    final value = x.valuePiasters;
    return {
      'id': x.id,
      'coolerId': x.coolerId,
      'coolerNo': _cooler(x.coolerId)?.no,
      'farmerId': x.farmerId,
      'farmerName': _farmerName(x.farmerId),
      'occurredAt': _iso(x.at),
      'boxes': x.boxes,
      'avgWeightGrams': x.avg,
      'weightMethod': x.isSample ? 'sample' : 'direct',
      'sampleWeightsGrams': x.samples ?? const <int>[],
      'tareGrams': x.isSample ? x.tare : null,
      'totalWeightGrams': x.totalWeightGrams,
      'pricePerKgPiasters': x.price,
      'valuePiasters': value,
      'paidPiasters': paid,
      'remainingPiasters': x.active ? value - paid : 0,
      'payStatus': _payStatus(value, paid),
      'status': x.active ? 'active' : 'cancelled',
      'cancelReason': x.cancelReason,
      'notes': x.notes,
      'createdAt': _iso(x.createdAt),
      'createdBy': x.createdBy,
      'createdByEmail': x.createdByEmail,
      'updatedAt': _iso(x.updatedAt),
      'updatedBy': x.updatedBy,
      'version': x.version,
    };
  }

  Map<String, dynamic> _paymentJson(_Payment x) => {
        'id': x.id,
        'no': x.no,
        'payeeType': x.payeeType,
        'payeeName': x.payeeName,
        'payeeId': x.payeeId,
        'targetType': x.targetType,
        'targetId': x.targetId,
        'coolerId': x.coolerId,
        'coolerNo': x.coolerId.isEmpty ? null : _cooler(x.coolerId)?.no,
        'amountPiasters': x.amount,
        'method': x.method,
        'paidAt': _iso(x.at),
        'status': x.active ? 'active' : 'cancelled',
        'cancelReason': x.cancelReason,
        'notes': x.notes,
        'createdAt': _iso(x.createdAt),
        'createdBy': x.createdBy,
        'createdByEmail': x.createdByEmail,
        'version': x.version,
      };

  Map<String, dynamic> _packagingJson(_Packaging x) {
    final t = _pkTotals(x.id);
    final paid = _paidFor(x.id);
    return {
      'id': x.id,
      'no': x.no,
      'supplier': x.supplier,
      'invoiceNo': x.invoiceNo,
      'occurredAt': _iso(x.at),
      'coolerId': x.coolerId,
      'coolerNo': x.coolerId.isEmpty ? null : _cooler(x.coolerId)?.no,
      'status': x.status,
      'itemsCount': t.count,
      'incompleteCount': t.incomplete,
      'completeTotalPiasters': t.total,
      'paidPiasters': paid,
      'remainingPiasters': x.status == 'approved' ? t.total - paid : 0,
      'late': x.late,
      'notes': x.notes,
      'createdAt': _iso(x.createdAt),
      'createdBy': x.createdBy,
      'createdByEmail': x.createdByEmail,
      'version': x.version,
    };
  }

  Map<String, dynamic> _itemJson(_Item i) => {
        'id': i.id,
        'name': i.name,
        'quantity': i.quantity,
        'unit': i.unit,
        'unitPricePiasters': i.price,
        'totalPiasters': i.total,
        'status': i.status,
        'notes': i.notes,
        'version': i.version,
      };

  List<Map<String, dynamic>> _itemsJson(String packagingId) => [for (final i in _pkItems(packagingId)) _itemJson(i)];

  /// {packaging, items} كما ترجعها packaging.get وsave وapprove.
  Map<String, dynamic> _bundle(_Packaging x) => {'packaging': _packagingJson(x), 'items': _itemsJson(x.id)};

  Map<String, dynamic> _itemTypeJson(_ItemType t) =>
      {'id': t.id, 'name': t.name, 'unit': t.unit, 'order': t.order, 'active': t.active};

  /// العملية المرتبطة بدفعة (Purchase أو PackagingSummary) أو null.
  Map<String, dynamic>? _targetJson(String type, String id) {
    if (type == 'packaging') {
      final x = _pack(id);
      return x == null ? null : _packagingJson(x);
    }
    final x = _purchase(id);
    return x == null ? null : _purchaseJson(x);
  }

  /// ترتيب تنازلي بالوقت ثم بالمعرّف (dmByTimeDesc_).
  static int _byTimeDesc(DateTime a, String ia, DateTime b, String ib) {
    final t = b.compareTo(a);
    return t != 0 ? t : ib.compareTo(ia);
  }

  // ===================================================================================== لوحة التحكم

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
    if (coolerId.isNotEmpty) _mustCooler(coolerId, 'coolerId');
    final range = _range(period);
    bool inScope(String cid) => coolerId.isEmpty || cid == coolerId;

    // البرادات (لا تتأثر بالفترة)، الأحدث رقمًا أولًا.
    final coolers = _coolers.where((c) => inScope(c.id)).toList()..sort((a, b) => b.no.compareTo(a.no));
    var purchases = 0, boxes = 0, weight = 0, value = 0, packagingApproved = 0;
    // المتبقي = ما بقي على عمليات الفترة بعد كل دفعاتها (مثل الخادم، docs/API.md §6)، فلا يكون سالبًا.
    var remainingFarmers = 0, remainingSuppliers = 0, records = 0;
    final farmers = <String>{};
    final recent = <({DateTime at, DateTime created, Map<String, dynamic> json})>[];

    for (final x in _purchases.where((x) => inScope(x.coolerId) && _inRange(x.at, range))) {
      records++;
      final paid = _paidFor(x.id);
      final status = x.active ? _payStatus(x.valuePiasters, paid) : 'cancelled';
      recent.add((at: x.at, created: x.createdAt, json: {
        'type': 'purchase',
        'id': x.id,
        'title': _farmerName(x.farmerId).isEmpty ? 'مزارع' : _farmerName(x.farmerId),
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
      remainingFarmers += x.valuePiasters - paid;
      farmers.add(x.farmerId);
    }

    for (final x in _packaging.where((x) => inScope(x.coolerId) && _inRange(x.at, range))) {
      records++;
      final total = _pkTotals(x.id).total;
      recent.add((at: x.at, created: x.createdAt, json: {
        'type': 'packaging',
        'id': x.id,
        'title': x.supplier.isEmpty ? 'شراء تعبئة ${x.no}' : x.supplier,
        'subtitle': _subtitle('تعبئة', x.coolerId, x.createdBy),
        'coolerNo': x.coolerId.isEmpty ? null : _cooler(x.coolerId)?.no,
        'at': _iso(x.at),
        'amountPiasters': total,
        'status': x.status,
        'statusLabel': _statusLabels[x.status],
      }));
      if (x.status == 'approved') {
        packagingApproved += total;
        remainingSuppliers += total - _paidFor(x.id);
      }
    }

    var paid = 0;
    for (final x in _payments.where((x) => inScope(x.coolerId) && _inRange(x.at, range))) {
      records++;
      final status = x.active ? 'active' : 'cancelled';
      recent.add((at: x.at, created: x.createdAt, json: {
        'type': 'payment',
        'id': x.id,
        'title': x.payeeName.isNotEmpty ? x.payeeName : (x.payeeType == 'supplier' ? 'مورد' : 'مزارع'),
        'subtitle': _subtitle('دفعة', x.coolerId, x.createdBy),
        'coolerNo': x.coolerId.isEmpty ? null : _cooler(x.coolerId)?.no,
        'at': _iso(x.at),
        'amountPiasters': x.amount,
        'status': status,
        'statusLabel': _statusLabels[status],
      }));
      if (!x.active) continue;
      paid += x.amount;
    }

    recent.sort((a, b) {
      final t = b.at.compareTo(a.at);
      if (t != 0) return t;
      final c = b.created.compareTo(a.created);
      return c != 0 ? c : (b.json['id'] as String).compareTo(a.json['id'] as String);
    });

    // البراد الحالي = المحدد، وإلا المفتوح الأحدث فتحًا.
    final open = coolers.where((c) => c.open).toList();
    _Cooler? current;
    if (coolerId.isNotEmpty) {
      current = coolers.first;
    } else if (open.isNotEmpty) {
      final byOpening = open.toList()
        ..sort((a, b) {
          final t = b.openedAt.compareTo(a.openedAt);
          return t != 0 ? t : b.no.compareTo(a.no);
        });
      current = byOpening.first;
    }

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
        'openCoolers': open.length,
        'distinctFarmers': farmers.length,
        'purchases': purchases,
        'boxes': boxes,
        'weightGrams': weight,
        'purchaseValuePiasters': value,
        'packagingApprovedPiasters': packagingApproved,
        'paidPiasters': paid,
        'remainingPiasters': remainingFarmers + remainingSuppliers,
        'remainingFarmersPiasters': remainingFarmers,
        'remainingSuppliersPiasters': remainingSuppliers,
        'avgPricePerKgPiasters': _avgPrice(value, weight),
      },
      'currentCooler': current == null ? null : _coolerJson(current),
      'openCoolers': [for (final c in open) _coolerJson(c)],
      'recent': [for (final r in recent.take(10)) r.json],
    };
  }

  // ===================================================================================== البرادات

  _Cooler _mustCooler(String id, String field) => _cooler(id) ?? _notFound(field, 'البراد', id);

  static ApiException _coolerClosed(_Cooler c, [String? message]) => ApiException(
        ApiErrorCode.coolerClosed,
        message ??
            'البراد رقم ${c.no} مقفّل، فلا يمكن إضافة مشتريات رمان إليه أو تعديلها أو إلغاؤها. '
                'اطلب من المدير إعادة فتحه إن لزم التعديل.',
        field: 'coolerId',
        details: {'coolerId': c.id, 'coolerNo': c.no},
      );

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

  Map<String, dynamic> _coolersGet(Map<String, dynamic> p) {
    final c = _mustCooler(_id(p, 'id', 'البراد'), 'id');
    final purchases = _purchases.where((x) => x.coolerId == c.id).toList()
      ..sort((a, b) => _byTimeDesc(a.at, a.id, b.at, b.id));
    final packaging = _packaging.where((x) => x.coolerId == c.id).toList()
      ..sort((a, b) => _byTimeDesc(a.at, a.id, b.at, b.id));
    return {
      'cooler': _coolerJson(c),
      'purchases': [for (final x in purchases) _purchaseJson(x)],
      'packaging': [for (final x in packaging) _packagingJson(x)],
    };
  }

  /// coolers.create: رقم البراد = الأكبر + 1، والحالة مفتوح. idempotent على requestId.
  Map<String, dynamic> _coolersCreate(Map<String, dynamic> p) {
    final replay = _coolers.where((c) => c.key.isNotEmpty && c.key == _requestId).firstOrNull;
    if (replay != null) return {'cooler': _coolerJson(replay), 'replayed': true};
    final name = _str(p, 'name', 'اسم البراد / الوصف', max: 80);
    final carNo = _str(p, 'carNo', 'رقم السيارة', max: 30);
    final driver = _str(p, 'driver', 'اسم السائق', max: 80);
    final notes = _str(p, 'notes', 'الملاحظات', max: 1000, multiline: true);
    final c = _Cooler(
      id: _nextId('CL', _coolers.map((c) => c.id)),
      no: _coolers.fold(0, (m, c) => math.max(m, c.no)) + 1,
      name: name,
      carNo: carNo,
      driver: driver,
      notes: notes,
      openedAt: _reqNow,
      openedBy: _meName,
      key: _requestId,
    );
    _coolers.add(c);
    return {'cooler': _coolerJson(c)};
  }

  /// coolers.close: يكتب لقطة «عند التقفيل» من الأرقام الحية.
  Map<String, dynamic> _coolersClose(Map<String, dynamic> p) {
    final id = _id(p, 'id', 'البراد');
    // مطلوب: بدونه لا نعرف إن كان على الجهاز عمليات لم تُرسل بعد.
    final pending = _inInt(p['clientPendingCount'], 'clientPendingCount', 'عدد العمليات بانتظار المزامنة',
        required: true,
        min: 0,
        max: 100000,
        hint: 'حدّث التطبيق، وانتظر حتى تُرسل كل العمليات بانتظار المزامنة، ثم أعد التقفيل.')!;
    if (pending > 0) {
      _invalid('clientPendingCount',
          'توجد $pending عمليات بانتظار المزامنة على هذا الجهاز. انتظر حتى تُرسل كلها (أو اتصل بالإنترنت) ثم أعد التقفيل.',
          {'pending': pending});
    }
    final c = _mustCooler(id, 'id');
    if (!c.open) throw _coolerClosed(c, 'البراد رقم ${c.no} مقفّل بالفعل. لا حاجة لتقفيله مرة أخرى.');
    final expected = _expectedVersion(p);
    if (c.version != expected) _conflict('هذا البراد', c.version, _coolerJson(c));

    final live = _coolerJson(c);
    c
      ..open = false
      ..closedAt = _reqNow
      ..closedBy = _meName
      ..snapshot = {
        'farmers': live['farmers'],
        'purchases': live['purchases'],
        'boxes': live['boxes'],
        'weightGrams': live['weightGrams'],
        'valuePiasters': live['valuePiasters'],
        'paidPiasters': live['paidPiasters'],
        'remainingPiasters': live['remainingPiasters'],
        'packagingPiasters': live['packagingApprovedPiasters'],
        'totalCostPiasters': live['totalCostPiasters'],
      }
      ..version += 1;
    return {'cooler': _coolerJson(c)};
  }

  /// coolers.reopen: للمدير فقط، بسبب. تبقى اللقطة (ووقت آخر تقفيل ومن قفّله كما في الصفحة).
  Map<String, dynamic> _coolersReopen(Map<String, dynamic> p) {
    final id = _id(p, 'id', 'البراد');
    _reason(p, 'لإعادة فتح البراد');
    final c = _mustCooler(id, 'id');
    if (c.open) _invalid('id', 'البراد رقم ${c.no} مفتوح بالفعل. لا حاجة لإعادة فتحه.');
    if (_present(p['expectedVersion'])) {
      final expected = _expectedVersion(p);
      if (c.version != expected) _conflict('هذا البراد', c.version, _coolerJson(c));
    }
    c
      ..open = true
      ..version += 1;
    return {'cooler': _coolerJson(c)};
  }

  // ===================================================================================== المزارعون

  Map<String, dynamic> _farmersList(Map<String, dynamic> p) {
    final includeInactive = _inBool(p['includeInactive'], 'includeInactive', 'إظهار الموقوفين', false);
    final q = _norm(p['query']);
    final qDigits = q.replaceAll(RegExp(r'\D'), '');
    final list = _farmers.where((f) {
      if (!includeInactive && !f.active) return false;
      if (q.isEmpty) return true;
      if (_norm(f.name).contains(q) || _norm(f.village).contains(q)) return true;
      if (qDigits.isNotEmpty && qDigits == q && f.phone.replaceAll(RegExp(r'\D'), '').contains(qDigits)) return true;
      return '${f.no}' == q;
    }).toList()
      ..sort((a, b) => a.no.compareTo(b.no));
    return {'farmers': [for (final f in list) _farmerJson(f)]};
  }

  /// رقم هاتف اختياري: أرقام مع + ومسافات وشرطات وأقواس، حتى 20 رقمًا.
  static String _phoneIn(Object? v, String field) {
    final raw = _inStr(v, field, 'رقم الهاتف', max: 30);
    if (raw.isEmpty) return '';
    final s = _latinDigits(raw).replaceAll(RegExp(r'\s+'), ' ').trim();
    final digits = s.replaceAll(RegExp(r'\D'), '');
    if (!RegExp(r'^\+?[\d\s\-()]+$').hasMatch(s) || digits.isEmpty || digits.length > 20) {
      _invalid(field, 'رقم الهاتف «$raw» غير صحيح. اكتب الأرقام فقط مثل 01001234567.');
    }
    return s;
  }

  /// مزارع بنفس الاسم بعد التطبيع (أو null).
  _Farmer? _duplicateFarmer(String name, {String? excludeId, bool activeOnly = false}) {
    final want = _norm(name);
    if (want.isEmpty) return null;
    return _farmers
        .where((f) => f.id != excludeId && (!activeOnly || f.active) && _norm(f.name) == want)
        .firstOrNull;
  }

  Never _duplicateError(String field, _Farmer dup) => _invalid(
        field,
        'يوجد مزارع مسجل بالاسم «${dup.name}» (رقم ${dup.no}). اختره من القائمة، أو أكّد أنه شخص مختلف لإضافته باسم مكرر.',
        {'existing': _farmerJson(dup)},
      );

  _Farmer _appendFarmer({required String name, String phone = '', String village = '', String notes = '', String key = ''}) {
    final f = _Farmer(
      id: _nextId('FR', _farmers.map((f) => f.id)),
      no: _farmers.fold(0, (m, f) => math.max(m, f.no)) + 1,
      name: name,
      phone: phone,
      village: village,
      notes: notes,
      createdAt: _reqNow,
      createdBy: _meName,
      key: key,
    );
    _farmers.add(f);
    return f;
  }

  Map<String, dynamic> _farmersCreate(Map<String, dynamic> p) {
    final replay = _farmers.where((f) => f.key.isNotEmpty && f.key == _requestId).firstOrNull;
    if (replay != null) return {'farmer': _farmerJson(replay), 'replayed': true};
    final name = _str(p, 'name', 'الاسم', required: true, max: 80, hint: 'اكتب اسم المزارع ثم أعد المحاولة.');
    final phone = _phoneIn(p['phone'], 'phone');
    final village = _str(p, 'village', 'القرية / المنطقة', max: 80);
    final notes = _str(p, 'notes', 'الملاحظات', max: 1000, multiline: true);
    final allowDuplicate = _inBool(p['allowDuplicate'], 'allowDuplicate', 'السماح بالاسم المكرر', false);
    final dup = _duplicateFarmer(name);
    if (dup != null && !allowDuplicate) _duplicateError('name', dup);
    final f = _appendFarmer(name: name, phone: phone, village: village, notes: notes, key: _requestId);
    return {'farmer': _farmerJson(f)};
  }

  Map<String, dynamic> _farmersUpdate(Map<String, dynamic> p) {
    final id = _id(p, 'id', 'المزارع');
    final expected = _expectedVersion(p);
    final f = _farmer(id) ?? _notFound('id', 'المزارع', id);
    if (f.version != expected) _conflict('بيانات هذا المزارع', f.version, _farmerJson(f));

    var name = f.name, phone = f.phone, village = f.village, notes = f.notes;
    var active = f.active;
    if (p.containsKey('name')) {
      name = _str(p, 'name', 'الاسم', required: true, max: 80, hint: 'اكتب اسم المزارع ثم أعد المحاولة.');
      final allowDuplicate = _inBool(p['allowDuplicate'], 'allowDuplicate', 'السماح بالاسم المكرر', false);
      final dup = _duplicateFarmer(name, excludeId: id);
      if (dup != null && !allowDuplicate) _duplicateError('name', dup);
    }
    if (p.containsKey('phone')) phone = _phoneIn(p['phone'], 'phone');
    if (p.containsKey('village')) village = _str(p, 'village', 'القرية / المنطقة', max: 80);
    if (p.containsKey('notes')) notes = _str(p, 'notes', 'الملاحظات', max: 1000, multiline: true);
    if (p.containsKey('status')) {
      active = _enum(p, 'status', 'حالة المزارع', const {'active': 'نشط', 'inactive': 'موقوف'}, required: true) == 'active';
    }
    if (name == f.name && phone == f.phone && village == f.village && notes == f.notes && active == f.active) {
      return {'farmer': _farmerJson(f)};
    }
    f
      ..name = name
      ..phone = phone
      ..village = village
      ..notes = notes
      ..active = active
      ..version += 1;
    return {'farmer': _farmerJson(f)};
  }

  // ===================================================================================== مشتريات الرمان

  static const _weightMethods = {'direct': 'مباشر', 'sample': 'عينة'};
  static const _payMethods = {'cash': 'نقدًا', 'bank': 'تحويل بنكي', 'wallet': 'محفظة إلكترونية'};
  static const _payModes = {'full': 'دفع كامل', 'partial': 'دفع جزئي', 'none': 'بدون دفع'};
  static const _targetTypes = {'purchase': 'شراء رمان', 'packaging': 'شراء تعبئة'};
  static const _amountMax = 1000000000000;

  _Purchase _mustPurchase(String id, String field) => _purchase(id) ?? _notFound(field, 'عملية الشراء', id);

  /// المزارع المختار (موجود ونشط).
  _Farmer _activeFarmer(String id, String field) {
    final f = _farmer(id) ?? _notFound(field, 'المزارع', id);
    if (!f.active) {
      _invalid(field, 'المزارع «${f.name}» موقوف. اختر مزارعًا آخر، أو اطلب تفعيله من صفحة المزارعين.');
    }
    return f;
  }

  static int _boxesIn(Object? v) =>
      _inInt(v, 'boxes', 'عدد الصناديق', required: true, min: 1, max: 100000)!;

  static int _avgIn(Object? v) =>
      _inInt(v, 'avgWeightGrams', 'متوسط الوزن الصافي للصندوق', required: true, min: 1, max: 60000, fmt: _fmtKg)!;

  static int _priceIn(Object? v) =>
      _inInt(v, 'pricePerKgPiasters', 'سعر الكيلو', required: true, min: 1, max: 100000, fmt: _fmtMoney)!;

  static int? _tareIn(Object? v) => _inInt(v, 'tareGrams', 'وزن الصندوق الفارغ', min: 0, max: 60000, fmt: _fmtKg);

  /// أوزان العينة: 1 إلى 200 وزن صحيح بالغرام، كل وزن > 0.
  static List<int> _samplesIn(Object? v) {
    const field = 'sampleWeightsGrams';
    if (v is! List || v.isEmpty) {
      _invalid(field, '«أوزان العينة» مطلوبة عند اختيار طريقة العينة. أدخل وزن صندوق واحد على الأقل.');
    }
    if (v.length > 200) _invalid(field, '«أوزان العينة» أكثر من 200 وزنًا. قلّل عدد الصناديق في العينة.', {'max': 200});
    return [
      for (var i = 0; i < v.length; i++)
        _inInt(v[i], field, 'وزن الصندوق رقم ${i + 1} في العينة', required: true, min: 1, max: 100000, fmt: _fmtKg)!,
    ];
  }

  /// متوسط الوزن = round(متوسط العينة − الفارغ) بفرق غرام واحد على الأكثر.
  static void _checkSample(int avg, List<int> samples, int tare) {
    final expected = _sampleNet(samples, tare);
    if (expected <= 0) {
      _invalid('sampleWeightsGrams',
          'متوسط أوزان العينة (${_fmtKg(_sampleNet(samples, 0))}) لا يزيد على وزن الصندوق الفارغ (${_fmtKg(tare)}). '
          'راجع أوزان العينة أو وزن الصندوق الفارغ.');
    }
    if ((avg - expected).abs() > 1) {
      _invalid('avgWeightGrams',
          '«متوسط الوزن الصافي للصندوق» (${_fmtKg(avg)}) لا يطابق العينة. المتوسط الصافي المحسوب من العينة هو '
          '${_fmtKg(expected)}. أعد حساب المتوسط ثم احفظ.',
          {'expectedGrams': expected});
    }
  }

  /// كل كتابة على صف العملية تزيد «الإصدار» وتضع «آخر تعديل/عدّلها» (العقد §7).
  void _touchPurchase(_Purchase x) {
    x
      ..version += 1
      ..updatedAt = _reqNow
      ..updatedBy = _meName;
  }

  Map<String, dynamic> _purchasesList(Map<String, dynamic> p) {
    final coolerId = _str(p, 'coolerId', 'البراد', max: 64);
    final farmerId = _str(p, 'farmerId', 'المزارع', max: 64);
    final range = _rangeIn(p['from'], p['to']);
    final includeCancelled = _inBool(p['includeCancelled'], 'includeCancelled', 'إظهار العمليات الملغاة', false);
    final list = _purchases.where((x) {
      if (coolerId.isNotEmpty && x.coolerId != coolerId) return false;
      if (farmerId.isNotEmpty && x.farmerId != farmerId) return false;
      if (!includeCancelled && !x.active) return false;
      return _inRange(x.at, range);
    }).toList()
      ..sort((a, b) => _byTimeDesc(a.at, a.id, b.at, b.id));
    return {'purchases': [for (final x in list) _purchaseJson(x)]};
  }

  /// from/to: تاريخ ووقت ISO أو تاريخ فقط (yyyy-MM-dd ⇒ بداية اليوم / نهايته).
  static ({DateTime? from, DateTime? to}) _rangeIn(Object? from, Object? to) {
    DateTime? parse(Object? v, String field, String label, bool end) {
      if (!_present(v)) return null;
      final s = v is String ? v : '';
      final d = _parseDateText(s);
      if (d == null) {
        _invalid(field, '«$label» بتنسيق غير صحيح. أرسل التاريخ مثل 2026-10-02 أو 2026-10-02T06:40:00+03:00.');
      }
      if (!_isDateOnly(s)) return d;
      return end ? DateTime(d.year, d.month, d.day + 1).subtract(const Duration(milliseconds: 1)) : d;
    }

    final range = (from: parse(from, 'from', 'من تاريخ', false), to: parse(to, 'to', 'إلى تاريخ', true));
    if (range.from != null && range.to != null && range.from!.isAfter(range.to!)) {
      _invalid('to', '«إلى تاريخ» قبل «من تاريخ». صحّح الفترة ثم أعد المحاولة.');
    }
    return range;
  }

  /// purchases.create — يتحقق من كل شيء أولًا، ثم يكتب: المزارع الجديد (إن وُجد) ← الشراء ← الدفعة.
  Map<String, dynamic> _purchasesCreate(Map<String, dynamic> p) {
    final replay = _purchases.where((x) => x.key.isNotEmpty && x.key == _requestId).firstOrNull;
    if (replay != null) return _purchaseReplay(replay);

    // شكل الطلب والصلاحيات الإضافية
    final hasFarmerId = _present(p['farmerId']);
    final hasNewName = _present(p['newFarmerName']);
    if (hasFarmerId && hasNewName) {
      _invalid('farmerId', 'اختر مزارعًا من القائمة أو اكتب اسم مزارع جديد، وليس الاثنين معًا.');
    }
    if (!hasFarmerId && !hasNewName) _invalid('farmerId', '«المزارع» مطلوب. اختره من القائمة أو اكتب اسم مزارع جديد.');
    final pay = p['payment'];
    if (pay is! Map) {
      _invalid('payment', '«الدفع مع الشراء» مطلوب. اختر «دفع كامل» أو «دفع جزئي» أو «بدون دفع» ثم أعد المحاولة.');
    }
    final mode = _inEnum(pay['mode'], 'payment.mode', 'طريقة الدفع مع الشراء', _payModes, required: true)!;
    if (hasNewName) _require('addFarmers');
    if (mode != 'none') _require('recordPayments');

    // البراد
    final cooler = _mustCooler(_id(p, 'coolerId', 'البراد'), 'coolerId');
    if (!cooler.open) throw _coolerClosed(cooler);

    // المزارع
    _Farmer? farmer;
    var newFarmerName = '';
    if (hasFarmerId) {
      farmer = _activeFarmer(_id(p, 'farmerId', 'المزارع'), 'farmerId');
    } else {
      newFarmerName = _str(p, 'newFarmerName', 'اسم المزارع الجديد', required: true, max: 80);
      final dup = _duplicateFarmer(newFarmerName, activeOnly: true);
      if (dup != null) {
        _invalid(
            'newFarmerName',
            'يوجد مزارع مسجل بالاسم «${dup.name}» (رقم ${dup.no}). اختره من القائمة بدل إضافته مرة أخرى.',
            {'existing': _farmerJson(dup)});
      }
    }

    // الوزن والسعر
    final boxes = _boxesIn(p['boxes']);
    final avg = _avgIn(p['avgWeightGrams']);
    final method = _enum(p, 'weightMethod', 'طريقة حساب الوزن', _weightMethods, required: true)!;
    List<int>? samples;
    int? tare;
    if (method == 'sample') {
      samples = _samplesIn(p['sampleWeightsGrams']);
      tare = _tareIn(p['tareGrams']) ?? _emptyBoxGrams;
      _checkSample(avg, samples, tare);
    }
    final price = _priceIn(p['pricePerKgPiasters']);
    final occurredAt = _inTime(p['occurredAt'], 'occurredAt', 'تاريخ ووقت العملية') ?? _reqNow;
    final notes = _str(p, 'notes', 'الملاحظات', max: 1000, multiline: true);
    final value = _value(boxes * avg, price);

    // الدفع
    var amount = 0;
    var payMethod = 'cash';
    if (mode != 'none') {
      if (value <= 0) {
        _invalid('payment.mode', 'قيمة العملية صفر، فلا يمكن تسجيل دفعة معها. راجع الأرقام أو اختر «بدون دفع».');
      }
      payMethod = _inEnum(pay['method'], 'payment.method', 'طريقة الدفع', _payMethods) ?? 'cash';
      if (mode == 'full') {
        amount = value;
      } else {
        amount = _inInt(pay['amountPiasters'], 'payment.amountPiasters', 'المبلغ المدفوع',
            required: true, min: 1, max: _amountMax, fmt: _fmtMoney)!;
        if (amount >= value) {
          _invalid('payment.amountPiasters',
              '«المبلغ المدفوع» (${_fmtMoney(amount)}) يجب أن يكون أقل من قيمة العملية (${_fmtMoney(value)}) '
              'في الدفع الجزئي. اختر «دفع كامل» إن دُفعت القيمة كلها.',
              {'valuePiasters': value});
        }
      }
    }

    // الكتابة
    _Farmer? createdFarmer;
    if (farmer == null) {
      createdFarmer = _appendFarmer(name: newFarmerName);
      farmer = createdFarmer;
    }
    final purchase = _Purchase(
      id: _nextId('PU', _purchases.map((x) => x.id)),
      coolerId: cooler.id,
      farmerId: farmer.id,
      at: occurredAt,
      boxes: boxes,
      avg: avg,
      price: price,
      samples: samples,
      tare: tare,
      notes: notes,
      createdAt: _reqNow,
      createdBy: _meName,
      createdByEmail: _currentUser.email,
      key: _requestId,
      createdFarmerId: createdFarmer?.id,
    );
    _purchases.add(purchase);
    _Payment? payment;
    if (mode != 'none') {
      // الدفعة الأولى تحمل وقت العملية نفسه (paidAt = occurredAt).
      payment = _appendPayment(
        payeeType: 'farmer',
        payeeName: farmer.name,
        payeeId: farmer.id,
        targetType: 'purchase',
        targetId: purchase.id,
        coolerId: cooler.id,
        amount: amount,
        method: payMethod,
        paidAt: occurredAt,
        notes: '',
      );
    }
    return {
      'purchase': _purchaseJson(purchase),
      'payment': payment == null ? null : _paymentJson(payment),
      'farmer': createdFarmer == null ? null : _farmerJson(createdFarmer),
      'replayed': false,
    };
  }

  /// نتيجة purchases.create المحفوظة (نفس requestId).
  Map<String, dynamic> _purchaseReplay(_Purchase x) {
    final payment = _payments.where((y) => y.key == _requestId && y.targetId == x.id).firstOrNull;
    final farmer = x.createdFarmerId == null ? null : _farmer(x.createdFarmerId!);
    return {
      'purchase': _purchaseJson(x),
      'payment': payment == null ? null : _paymentJson(payment),
      'farmer': farmer == null ? null : _farmerJson(farmer),
      'replayed': true,
    };
  }

  /// purchases.update {id, expectedVersion, changes}
  Map<String, dynamic> _purchasesUpdate(Map<String, dynamic> p) {
    final id = _id(p, 'id', 'عملية الشراء');
    final x = _mustPurchase(id, 'id');
    _requireOwnerOrEditOthers(x);
    final cooler = _cooler(x.coolerId);
    if (cooler != null && !cooler.open) throw _coolerClosed(cooler);
    if (!x.active) _invalid('id', 'عملية الشراء $id ملغاة، فلا يمكن تعديلها. سجّل عملية جديدة إن لزم.');
    final expected = _expectedVersion(p);
    if (x.version != expected) _conflict('عملية الشراء هذه', x.version, _purchaseJson(x));

    final ch = p['changes'];
    if (ch is! Map) _invalid('changes', '«التغييرات» مطلوبة. أرسل الحقول التي تريد تعديلها.');
    final c = ch.cast<String, dynamic>();
    bool has(String k) => c.containsKey(k);
    final curMethod = x.isSample ? 'sample' : 'direct';

    final boxes = has('boxes') ? _boxesIn(c['boxes']) : x.boxes;
    final avg = has('avgWeightGrams') ? _avgIn(c['avgWeightGrams']) : x.avg;
    final price = has('pricePerKgPiasters') ? _priceIn(c['pricePerKgPiasters']) : x.price;
    final method = has('weightMethod')
        ? _inEnum(c['weightMethod'], 'weightMethod', 'طريقة حساب الوزن', _weightMethods, required: true)!
        : curMethod;
    var samples = const <int>[];
    int? tare;
    if (method == 'sample') {
      samples = has('sampleWeightsGrams') ? _samplesIn(c['sampleWeightsGrams']) : (x.samples ?? const <int>[]);
      if (samples.isEmpty) _samplesIn(samples);
      tare = has('tareGrams') ? (_tareIn(c['tareGrams']) ?? _emptyBoxGrams) : (x.tare ?? _emptyBoxGrams);
      if (has('avgWeightGrams') || has('sampleWeightsGrams') || has('tareGrams') || has('weightMethod')) {
        _checkSample(avg, samples, tare);
      }
    }

    _Farmer? farmer;
    if (has('farmerId')) {
      final fid = _inStr(c['farmerId'], 'farmerId', 'المزارع',
          required: true, max: 64, hint: 'اختره من القائمة ثم أعد المحاولة.');
      if (fid != x.farmerId) {
        farmer = _activeFarmer(fid, 'farmerId');
        if (_activeCount(id) > 0) {
          _invalid('farmerId', 'لا يمكن تغيير المزارع لعملية عليها دفعات مسجلة باسم المزارع الحالي. '
              'ألغِ الدفعات أولًا، ثم غيّر المزارع وسجّل الدفعات من جديد.');
        }
      }
    }
    final occurredAt = has('occurredAt') ? _inTime(c['occurredAt'], 'occurredAt', 'تاريخ ووقت العملية') : null;
    final notes = has('notes') ? _inStr(c['notes'], 'notes', 'الملاحظات', max: 1000, multiline: true) : null;

    final value = _value(boxes * avg, price);
    final paid = _paidFor(id);
    if (value < paid) {
      final field = const ['pricePerKgPiasters', 'avgWeightGrams', 'boxes'].where(has).firstOrNull ?? 'boxes';
      _invalid(field, 'القيمة الجديدة للعملية (${_fmtMoney(value)}) أقل من المدفوع فعلًا (${_fmtMoney(paid)}). '
          'ألغِ دفعة أولًا أو صحّح الأرقام.', {'valuePiasters': value, 'paidPiasters': paid});
    }

    final sampleChanged = method == 'sample' && (tare != x.tare || !_sameInts(samples, x.samples ?? const []));
    final changed = boxes != x.boxes ||
        avg != x.avg ||
        price != x.price ||
        method != curMethod ||
        sampleChanged ||
        farmer != null ||
        (occurredAt != null && !occurredAt.isAtSameMomentAs(x.at)) ||
        (notes != null && notes != x.notes);
    if (!changed) return {'purchase': _purchaseJson(x)};
    x
      ..boxes = boxes
      ..avg = avg
      ..price = price
      ..samples = method == 'sample' ? samples : null
      ..tare = method == 'sample' ? tare : null;
    if (farmer != null) x.farmerId = farmer.id;
    if (occurredAt != null) x.at = occurredAt;
    if (notes != null) x.notes = notes;
    _touchPurchase(x);
    return {'purchase': _purchaseJson(x)};
  }

  static bool _sameInts(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// purchases.cancel {id, reason} — مرفوض ما دامت على العملية دفعات فعّالة.
  Map<String, dynamic> _purchasesCancel(Map<String, dynamic> p) {
    final id = _id(p, 'id', 'عملية الشراء');
    final reason = _reason(p, 'لإلغاء عملية الشراء');
    final x = _mustPurchase(id, 'id');
    _requireOwnerOrEditOthers(x);
    final cooler = _cooler(x.coolerId);
    if (cooler != null && !cooler.open) throw _coolerClosed(cooler);
    if (!x.active) _invalid('id', 'عملية الشراء $id ملغاة بالفعل. لا حاجة لإلغائها مرة أخرى.');
    if (_present(p['expectedVersion'])) {
      final expected = _expectedVersion(p);
      if (x.version != expected) _conflict('عملية الشراء هذه', x.version, _purchaseJson(x));
    }
    final count = _activeCount(id);
    if (count > 0) {
      _invalid(
          'id',
          'على عملية الشراء $id $count دفعة فعّالة بمبلغ ${_fmtMoney(_paidFor(id))}. ألغِ الدفعات أولًا ثم ألغِ العملية.',
          {'activePayments': count});
    }
    x
      ..active = false
      ..cancelReason = reason;
    _touchPurchase(x);
    return {'purchase': _purchaseJson(x)};
  }

  // ===================================================================================== المدفوعات

  _Payment _appendPayment({
    required String payeeType,
    required String payeeName,
    required String payeeId,
    required String targetType,
    required String targetId,
    required String coolerId,
    required int amount,
    required String method,
    required DateTime paidAt,
    required String notes,
  }) {
    final x = _Payment(
      id: _nextId('PY', _payments.map((x) => x.id)),
      no: _nextId('D', _payments.map((x) => x.no)),
      targetType: targetType,
      targetId: targetId,
      payeeType: payeeType,
      payeeId: payeeId,
      payeeName: payeeName,
      coolerId: coolerId,
      amount: amount,
      method: method,
      at: paidAt,
      notes: notes,
      createdAt: _reqNow,
      createdBy: _meName,
      createdByEmail: _currentUser.email,
      key: _requestId,
    );
    _payments.add(x);
    return x;
  }

  /// بعد تسجيل دفعة أو إلغائها تتغير أعمدة المدفوع/المتبقي في صف العملية، فيزيد إصدارها.
  void _touchTarget(String type, String id) {
    if (type == 'packaging') {
      _pack(id)?.version += 1;
      return;
    }
    final x = _purchase(id);
    if (x != null) _touchPurchase(x);
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
      ..sort((a, b) => _byTimeDesc(a.at, a.id, b.at, b.id));
    return {'payments': [for (final x in list) _paymentJson(x)]};
  }

  /// payments.create — مسموح على البرادات المقفّلة. المبلغ ≤ المتبقي. التعبئة يجب أن تكون معتمدة.
  Map<String, dynamic> _paymentsCreate(Map<String, dynamic> p) {
    final replay = _payments.where((x) => x.key.isNotEmpty && x.key == _requestId).firstOrNull;
    if (replay != null) {
      return {
        'payment': _paymentJson(replay),
        'target': _targetJson(replay.targetType, replay.targetId),
        'replayed': true,
      };
    }
    final targetType = _enum(p, 'targetType', 'نوع العملية', _targetTypes, required: true)!;
    final targetId = _id(p, 'targetId', targetType == 'purchase' ? 'عملية شراء الرمان' : 'شراء التعبئة');
    final amount = _inInt(p['amountPiasters'], 'amountPiasters', 'المبلغ',
        required: true, min: 1, max: _amountMax, fmt: _fmtMoney)!;
    final method = _enum(p, 'method', 'طريقة الدفع', _payMethods, required: true)!;
    final paidAt = _inTime(p['paidAt'], 'paidAt', 'تاريخ الدفعة') ?? _reqNow;
    final notes = _str(p, 'notes', 'الملاحظات', max: 1000, multiline: true);

    final int total;
    final String payeeType, payeeName, payeeId, coolerId;
    if (targetType == 'purchase') {
      final x = _purchase(targetId) ?? _notFound('targetId', 'عملية الشراء', targetId);
      if (!x.active) {
        _invalid('targetId', 'عملية الشراء $targetId ملغاة، فلا يمكن الدفع لها. حدّث البيانات واختر عملية شراء فعّالة.');
      }
      total = x.valuePiasters;
      payeeType = 'farmer';
      payeeName = _farmerName(x.farmerId);
      payeeId = x.farmerId;
      coolerId = x.coolerId;
    } else {
      final x = _pack(targetId) ?? _notFound('targetId', 'شراء التعبئة', targetId);
      if (x.status != 'approved') {
        _invalid('targetId', 'شراء التعبئة ${x.no} '
            '${x.status == 'draft' ? 'ما زال مسودة. اعتمده أولًا ثم سجّل الدفعة.' : 'ملغى، فلا يمكن الدفع له.'}');
      }
      total = _pkTotals(x.id).total;
      payeeType = 'supplier';
      payeeName = x.supplier;
      payeeId = '';
      coolerId = x.coolerId;
    }
    final remaining = total - _paidFor(targetId);
    if (remaining <= 0) {
      _invalid('amountPiasters', 'هذه العملية مدفوعة بالكامل (${_fmtMoney(total)}). لا يوجد مبلغ متبقٍ للدفع.',
          {'remainingPiasters': math.max(remaining, 0)});
    }
    if (amount > remaining) {
      _invalid('amountPiasters', '«المبلغ» (${_fmtMoney(amount)}) أكبر من المتبقي (${_fmtMoney(remaining)}). '
          'اكتب مبلغًا لا يزيد على المتبقي.', {'remainingPiasters': remaining});
    }

    final x = _appendPayment(
      payeeType: payeeType,
      payeeName: payeeName,
      payeeId: payeeId,
      targetType: targetType,
      targetId: targetId,
      coolerId: coolerId,
      amount: amount,
      method: method,
      paidAt: paidAt,
      notes: notes,
    );
    _touchTarget(targetType, targetId);
    return {'payment': _paymentJson(x), 'target': _targetJson(targetType, targetId), 'replayed': false};
  }

  /// payments.cancel {id, reason}
  Map<String, dynamic> _paymentsCancel(Map<String, dynamic> p) {
    final id = _id(p, 'id', 'الدفعة');
    final reason = _reason(p, 'لإلغاء الدفعة');
    final x = _payments.where((x) => x.id == id).firstOrNull ?? _notFound('id', 'الدفعة', id);
    if (!x.active) _invalid('id', 'الدفعة ${x.no} ملغاة بالفعل. لا حاجة لإلغائها مرة أخرى.');
    if (_present(p['expectedVersion'])) {
      final expected = _expectedVersion(p);
      if (x.version != expected) _conflict('هذه الدفعة', x.version, _paymentJson(x));
    }
    x
      ..active = false
      ..cancelReason = reason
      ..version += 1;
    _touchTarget(x.targetType, x.targetId);
    return {'payment': _paymentJson(x), 'target': _targetJson(x.targetType, x.targetId)};
  }

  // ===================================================================================== التعبئة والتغليف

  static const _units = ['قطعة', 'رزمة', 'لفة', 'رول', 'كرتونة', 'كغ'];

  _Packaging _mustPackaging(String id, String field) => _pack(id) ?? _notFound(field, 'شراء التعبئة', id);

  static String _pkLabel(_Packaging x) =>
      'شراء التعبئة ${x.no}${x.supplier.isEmpty ? '' : ' من «${x.supplier}»'}';

  Map<String, dynamic> _packagingList(Map<String, dynamic> p) {
    final status = _enum(p, 'status', 'حالة شراء التعبئة',
            const {'draft': 'مسودة', 'approved': 'معتمد', 'cancelled': 'ملغى', 'all': 'الكل'}) ??
        'all';
    final coolerId = _str(p, 'coolerId', 'البراد', max: 64);
    final list = _packaging.where((x) {
      if (coolerId.isNotEmpty && x.coolerId != coolerId) return false;
      return status == 'all' || x.status == status;
    }).toList()
      ..sort((a, b) => _byTimeDesc(a.at, a.id, b.at, b.id));
    return {'packaging': [for (final x in list) _packagingJson(x)]};
  }

  Map<String, dynamic> _packagingGet(Map<String, dynamic> p) =>
      _bundle(_mustPackaging(_id(p, 'id', 'شراء التعبئة'), 'id'));

  /// يتحقق من قائمة الأصناف كاملة قبل أي كتابة (packagingItemsIn_).
  List<({String id, String name, String unit, int? quantity, int? price, String notes})> _itemsIn(
      Object? items, String packagingId) {
    if (items is! List) _invalid('items', '«الأصناف» مطلوبة كقائمة. أضف الأصناف ثم احفظ.');
    if (items.length > 200) {
      _invalid('items', 'عدد الأصناف أكثر من 200. قسّم الشراء إلى أكثر من فاتورة.', {'max': 200});
    }
    final seen = <String>{};
    final out = <({String id, String name, String unit, int? quantity, int? price, String notes})>[];
    for (var i = 0; i < items.length; i++) {
      final f = 'items[$i]';
      final n = i + 1;
      final raw = items[i];
      if (raw is! Map) _invalid(f, 'الصنف رقم $n غير صالح. احذفه وأضفه من جديد.', {'index': i});
      final x = raw.cast<String, dynamic>();
      var id = '';
      if (_present(x['id'])) {
        id = _inStr(x['id'], '$f.id', 'معرّف الصنف رقم $n', max: 64);
        final rec = _items.where((it) => it.id == id).firstOrNull;
        if (rec == null || packagingId.isEmpty || rec.packagingId != packagingId) {
          _invalid('$f.id', 'الصنف رقم $n لا يتبع هذا الشراء. حدّث البيانات ثم أعد الحفظ.', {'index': i, 'id': id});
        }
        if (!seen.add(id)) _invalid('$f.id', 'الصنف رقم $n مكرر في القائمة. احذف التكرار ثم احفظ.', {'index': i, 'id': id});
      }
      final name = _inStr(x['name'], '$f.name', 'اسم الصنف رقم $n', required: true, max: 80);
      final unit =
          _inStr(x['unit'], '$f.unit', 'وحدة الصنف رقم $n', required: true, max: 20, hint: 'اختر الوحدة من القائمة.');
      if (!_units.contains(unit)) {
        _invalid('$f.unit', 'وحدة الصنف رقم $n («$unit») غير معروفة. اختر واحدة من: ${_units.join('، ')}.',
            {'index': i, 'allowed': _units});
      }
      // الفارغ يبقى null (ليس صفرًا)، فيصبح الصنف «غير مكتمل».
      final quantity = _inInt(x['quantity'], '$f.quantity', 'كمية الصنف رقم $n', min: 1, max: 10000000);
      final price = _inInt(x['unitPricePiasters'], '$f.unitPricePiasters', 'سعر الوحدة للصنف رقم $n',
          min: 1, max: 100000000, fmt: _fmtMoney);
      final notes = _inStr(x['notes'], '$f.notes', 'ملاحظات الصنف رقم $n', max: 500, multiline: true);
      out.add((id: id, name: name, unit: unit, quantity: quantity, price: price, notes: notes));
    }
    return out;
  }

  _Item _newItem(String packagingId, ({String id, String name, String unit, int? quantity, int? price, String notes}) x) {
    final item = _Item(
      id: _nextId('PD', _items.map((i) => i.id)),
      packagingId: packagingId,
      name: x.name,
      unit: x.unit,
      quantity: x.quantity,
      price: x.price,
      notes: x.notes,
    );
    _items.add(item);
    return item;
  }

  /// packaging.save — ينشئ مسودة أو يعدّلها. القائمة كاملة دائمًا: ما لم يُرسل من أصناف المسودة يصبح «محذوف».
  Map<String, dynamic> _packagingSave(Map<String, dynamic> p) {
    final id = _str(p, 'id', 'شراء التعبئة', max: 64);
    _Packaging? rec;
    if (id.isEmpty) {
      final replay = _packaging.where((x) => x.key.isNotEmpty && x.key == _requestId).firstOrNull;
      if (replay != null) return {..._bundle(replay), 'replayed': true};
    } else {
      rec = _mustPackaging(id, 'id');
      if (rec.status == 'approved') {
        _invalid('id', '${_pkLabel(rec)} معتمد، فلا يمكن تعديله. ألغِه وسجّل شراءً جديدًا إن لزم التصحيح.');
      }
      if (rec.status != 'draft') _invalid('id', '${_pkLabel(rec)} ملغى، فلا يمكن تعديله. سجّل شراءً جديدًا.');
      final expected = _expectedVersion(p);
      if (rec.version != expected) {
        _conflict(_pkLabel(rec), rec.version, _packagingJson(rec), extra: {'items': _itemsJson(rec.id)});
      }
    }

    // الحقول الغائبة تبقى كما هي؛ المرسلة فارغة تُمسح.
    final supplier = p.containsKey('supplier') ? _str(p, 'supplier', 'اسم المورد', max: 80) : (rec?.supplier ?? '');
    final invoiceNo = p.containsKey('invoiceNo') ? _str(p, 'invoiceNo', 'رقم الفاتورة', max: 40) : (rec?.invoiceNo ?? '');
    final notes =
        p.containsKey('notes') ? _str(p, 'notes', 'الملاحظات', max: 1000, multiline: true) : (rec?.notes ?? '');
    var coolerId = rec?.coolerId ?? '';
    if (p.containsKey('coolerId')) {
      coolerId = _str(p, 'coolerId', 'البراد', max: 64);
      if (coolerId.isNotEmpty) _mustCooler(coolerId, 'coolerId');
    }
    final occurredAt = _inTime(p['occurredAt'], 'occurredAt', 'تاريخ ووقت الشراء') ?? rec?.at ?? _reqNow;
    final items = _itemsIn(p['items'], id);

    // الكتابة
    if (rec == null) {
      final x = _Packaging(
        id: _nextId('PK', _packaging.map((x) => x.id)),
        no: _nextId('P', _packaging.map((x) => x.no)),
        supplier: supplier,
        invoiceNo: invoiceNo,
        coolerId: coolerId,
        at: occurredAt,
        notes: notes,
        createdAt: _reqNow,
        createdBy: _meName,
        createdByEmail: _currentUser.email,
        key: _requestId,
      );
      _packaging.add(x);
      for (final item in items) {
        _newItem(x.id, item);
      }
      return {..._bundle(x), 'replayed': false};
    }

    // تعديل مسودة قائمة
    final listed = {for (final x in items) if (x.id.isNotEmpty) x.id};
    var touched = false;
    for (final r in _pkItems(rec.id)) {
      if (listed.contains(r.id)) continue;
      r
        ..removed = true
        ..version += 1;
      touched = true;
    }
    for (final x in items) {
      if (x.id.isEmpty) continue;
      final r = _items.firstWhere((i) => i.id == x.id);
      if (!r.removed && r.name == x.name && r.unit == x.unit && r.quantity == x.quantity && r.price == x.price &&
          r.notes == x.notes) {
        continue;
      }
      r
        ..name = x.name
        ..unit = x.unit
        ..quantity = x.quantity
        ..price = x.price
        ..notes = x.notes
        ..removed = false
        ..version += 1;
      touched = true;
    }
    for (final x in items) {
      if (x.id.isNotEmpty) continue;
      _newItem(rec.id, x);
      touched = true;
    }
    final headerChanged = rec.supplier != supplier ||
        rec.invoiceNo != invoiceNo ||
        !rec.at.isAtSameMomentAs(occurredAt) ||
        rec.coolerId != coolerId ||
        rec.notes != notes;
    if (!headerChanged && !touched) return {..._bundle(rec), 'replayed': false};
    rec
      ..supplier = supplier
      ..invoiceNo = invoiceNo
      ..at = occurredAt
      ..coolerId = coolerId
      ..notes = notes
      ..version += 1;
    return {..._bundle(rec), 'replayed': false};
  }

  /// packaging.approve — صنف واحد على الأقل وكل الأصناف مكتملة. «تكلفة متأخرة» إن كان البراد مقفّلًا.
  Map<String, dynamic> _packagingApprove(Map<String, dynamic> p) {
    final id = _id(p, 'id', 'شراء التعبئة');
    final x = _mustPackaging(id, 'id');
    if (x.status == 'approved') _invalid('id', '${_pkLabel(x)} معتمد بالفعل. لا حاجة لاعتماده مرة أخرى.');
    if (x.status == 'cancelled') _invalid('id', '${_pkLabel(x)} ملغى، فلا يمكن اعتماده. سجّل شراءً جديدًا.');
    final expected = _expectedVersion(p);
    if (x.version != expected) {
      _conflict(_pkLabel(x), x.version, _packagingJson(x), verb: 'الاعتماد', extra: {'items': _itemsJson(x.id)});
    }
    final t = _pkTotals(id);
    if (t.count == 0) {
      _invalid('items', 'لا يمكن اعتماد ${_pkLabel(x)} بدون أصناف. أضف صنفًا واحدًا على الأقل ثم اعتمد.');
    }
    if (t.incomplete > 0) {
      final bad = _pkItems(id).where((i) => !i.complete).toList();
      _invalid(
          'items',
          'لا يمكن الاعتماد: ${t.incomplete} صنف غير مكتمل (${bad.map((i) => i.name).join('، ')}). '
              'أكمل الكمية والسعر لكل صنف ثم اعتمد.',
          {'incomplete': [for (final i in bad) i.id]});
    }
    final cooler = x.coolerId.isEmpty ? null : _cooler(x.coolerId);
    x
      ..status = 'approved'
      ..late = cooler != null && !cooler.open
      ..version += 1;
    return _bundle(x);
  }

  /// packaging.cancel {id, reason} — مرفوض ما دامت عليه دفعات فعّالة.
  Map<String, dynamic> _packagingCancel(Map<String, dynamic> p) {
    final id = _id(p, 'id', 'شراء التعبئة');
    final reason = _reason(p, 'لإلغاء شراء التعبئة');
    final x = _mustPackaging(id, 'id');
    if (x.status == 'cancelled') _invalid('id', '${_pkLabel(x)} ملغى بالفعل. لا حاجة لإلغائه مرة أخرى.');
    if (_present(p['expectedVersion'])) {
      final expected = _expectedVersion(p);
      if (x.version != expected) _conflict(_pkLabel(x), x.version, _packagingJson(x));
    }
    final count = _activeCount(id);
    if (count > 0) {
      _invalid(
          'id',
          'على ${_pkLabel(x)} $count دفعة فعّالة بمبلغ ${_fmtMoney(_paidFor(id))}. ألغِ الدفعات أولًا ثم ألغِ الشراء.',
          {'activePayments': count});
    }
    final line = 'سبب الإلغاء: $reason';
    x
      ..status = 'cancelled'
      ..notes = x.notes.isEmpty ? line : '${x.notes}\n$line'
      ..version += 1;
    return {'packaging': _packagingJson(x)};
  }

  // ===================================================================================== أصناف التعبئة

  Map<String, dynamic> _itemTypesList(Map<String, dynamic> _) {
    final list = _itemTypes.toList()
      ..sort((a, b) {
        final o = a.order.compareTo(b.order);
        return o != 0 ? o : a.name.compareTo(b.name);
      });
    return {'itemTypes': [for (final t in list) _itemTypeJson(t)]};
  }

  /// itemTypes.save {id?, name, unit, order?, active?} — الصفحة بلا إصدار، فلا expectedVersion.
  Map<String, dynamic> _itemTypesSave(Map<String, dynamic> p) {
    final id = _str(p, 'id', 'الصنف', max: 64);
    final rec = id.isEmpty ? null : _itemTypes.where((t) => t.id == id).firstOrNull;
    if (id.isNotEmpty && rec == null) _notFound('id', 'صنف التعبئة', id);
    final name = _str(p, 'name', 'اسم الصنف', required: true, max: 60);
    final unit = _str(p, 'unit', 'الوحدة الافتراضية', required: true, max: 20, hint: 'اختر الوحدة من القائمة.');
    if (!_units.contains(unit)) {
      _invalid('unit', 'الوحدة «$unit» غير معروفة. اختر واحدة من: ${_units.join('، ')}.', {'allowed': _units});
    }
    final want = _norm(name);
    final dup = _itemTypes.where((t) => !identical(t, rec) && _norm(t.name) == want).firstOrNull;
    if (dup != null) {
      final hint = dup.active ? '' : ' (غير نشط، يمكنك تفعيله بدل إضافته)';
      _invalid('name', 'يوجد صنف بالاسم «${dup.name}» بالفعل$hint. اختر اسمًا مختلفًا.', {'existing': _itemTypeJson(dup)});
    }
    final order = _inInt(p['order'], 'order', 'الترتيب', min: 1, max: 100000) ??
        rec?.order ??
        _itemTypes.fold(0, (m, t) => math.max(m, t.order)) + 1;
    final active = _inBool(p['active'], 'active', 'نشط', rec?.active ?? true);
    if (rec == null) {
      final t = _ItemType(_nextId('IT', _itemTypes.map((t) => t.id)), name, unit, order, active);
      _itemTypes.add(t);
      return {'itemType': _itemTypeJson(t)};
    }
    rec
      ..name = name
      ..unit = unit
      ..order = order
      ..active = active;
    return {'itemType': _itemTypeJson(rec)};
  }
}

// ===================================================================================== السجلات

class _Action {
  _Action(this.fn, {this.perm, this.write = false, this.auth = true});

  final Map<String, dynamic> Function(Map<String, dynamic>) fn;

  /// الصلاحية المطلوبة (null = أي جلسة نشطة).
  final String? perm;

  /// إجراء يغيّر البيانات: يتطلب requestId وتُحفظ نتيجته.
  final bool write;

  /// false = لا يتطلب جلسة (الدخول والخروج).
  final bool auth;
}

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
  _Farmer({
    required this.id,
    required this.no,
    required this.name,
    required this.createdAt,
    required this.createdBy,
    this.phone = '',
    this.village = '',
    this.notes = '',
    this.active = true,
    this.key = '',
  });

  final String id;
  final int no;
  String name;
  String phone;
  String village;
  String notes;
  bool active;
  final DateTime createdAt;
  final String createdBy;
  int version = 1;

  /// «مفتاح عدم التكرار» (requestId الإنشاء).
  final String key;
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
    this.notes = '',
    this.open = true,
    this.closedAt,
    this.closedBy = '',
    this.snapshot,
    this.version = 1,
    this.key = '',
  });

  final String id;
  final int no;
  final String name;
  final String carNo;
  final String driver;
  final String notes;
  final DateTime openedAt;
  final String openedBy;
  bool open;

  /// وقت آخر تقفيل ومن قفّله (يبقيان بعد إعادة الفتح كما في الصفحة).
  DateTime? closedAt;
  String closedBy;

  /// أرقام «عند التقفيل» (null لبراد لم يُقفَّل قط).
  Map<String, dynamic>? snapshot;
  int version;
  final String key;
}

class _Purchase {
  _Purchase({
    required this.id,
    required this.coolerId,
    required this.farmerId,
    required this.at,
    required this.boxes,
    required this.avg,
    required this.price,
    required this.createdAt,
    required this.createdBy,
    required this.createdByEmail,
    this.samples,
    this.tare,
    this.notes = '',
    this.key = '',
    this.createdFarmerId,
  })  : updatedAt = createdAt,
        updatedBy = createdBy;

  final String id;
  final String coolerId;
  String farmerId;

  /// وقت العملية (occurredAt).
  DateTime at;
  int boxes;

  /// متوسط الوزن الصافي للصندوق بالجرام.
  int avg;

  /// سعر الكيلو بالقرش.
  int price;

  /// أوزان العينة بالجرام؛ null = إدخال المتوسط مباشرة.
  List<int>? samples;
  int? tare;
  String notes;
  bool active = true;
  String cancelReason = '';
  final DateTime createdAt;
  final String createdBy;
  final String createdByEmail;
  DateTime updatedAt;
  String updatedBy;
  int version = 1;
  final String key;

  /// المزارع الذي أُنشئ مع العملية نفسها (newFarmerName)، لإعادته عند تكرار الطلب.
  final String? createdFarmerId;

  bool get isSample => samples != null;

  int get totalWeightGrams => boxes * avg;

  int get valuePiasters => DemoBackendApi._value(totalWeightGrams, price);
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
    required this.createdAt,
    required this.createdBy,
    required this.createdByEmail,
    this.notes = '',
    this.key = '',
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

  /// وقت الدفعة (paidAt).
  final DateTime at;
  final String notes;
  final DateTime createdAt;
  final String createdBy;
  final String createdByEmail;
  final String key;
  bool active = true;
  String cancelReason = '';
  int version = 1;
}

class _Packaging {
  _Packaging({
    required this.id,
    required this.no,
    required this.supplier,
    required this.invoiceNo,
    required this.coolerId,
    required this.at,
    required this.createdAt,
    required this.createdBy,
    required this.createdByEmail,
    this.status = 'draft',
    this.late = false,
    this.notes = '',
    this.version = 1,
    this.key = '',
  });

  final String id;
  final String no;
  String supplier;
  String invoiceNo;
  String coolerId;

  /// وقت الشراء (occurredAt).
  DateTime at;

  /// draft | approved | cancelled
  String status;

  /// «تكلفة متأخرة»: اعتُمد بعد تقفيل البراد المرتبط.
  bool late;
  String notes;
  final DateTime createdAt;
  final String createdBy;
  final String createdByEmail;
  int version;
  final String key;
}

class _Item {
  _Item({
    required this.id,
    required this.packagingId,
    required this.name,
    required this.unit,
    this.quantity,
    this.price,
    this.notes = '',
  });

  final String id;
  final String packagingId;
  String name;
  String unit;

  /// null = لم تُكتب بعد (ليست صفرًا).
  int? quantity;

  /// سعر الوحدة بالقرش؛ null = لم يُسعَّر بعد.
  int? price;
  String notes;
  bool removed = false;
  int version = 1;

  bool get complete => quantity != null && price != null;

  int? get total => complete ? quantity! * price! : null;

  String get status => removed ? 'removed' : (complete ? 'complete' : 'incomplete');
}

class _ItemType {
  _ItemType(this.id, this.name, this.unit, this.order, this.active);

  final String id;
  String name;
  String unit;
  int order;
  bool active;
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
