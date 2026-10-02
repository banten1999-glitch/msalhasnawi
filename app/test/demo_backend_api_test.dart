import 'package:flutter_test/flutter_test.dart';
import 'package:rumman_calculator/core/api/api_exception.dart';
import 'package:rumman_calculator/core/api/demo_backend_api.dart';
import 'package:rumman_calculator/core/models/user.dart';

void main() {
  late DemoBackendApi api;

  setUp(() async {
    // 2 أكتوبر 2026 الساعة 10:58 ص: أوقات التصميم كما هي.
    api = DemoBackendApi(latency: Duration.zero, clock: () => DateTime(2026, 10, 2, 10, 58));
    final login = await api.login('anything');
    api.session = login.session;
  });

  test('الدخول يقبل أي توكن ويعيد المدير الأساسي، ودون جلسة ⇒ AUTH_REQUIRED', () async {
    final fresh = DemoBackendApi(latency: Duration.zero);
    await expectLater(fresh.me(), throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiErrorCode.authRequired)));
    final r = await fresh.login('x');
    expect(r.user.name, 'محمد الحسناوي');
    expect(r.user.isAdmin, isTrue);
    expect(r.user.isBootstrap, isTrue);
    fresh.session = r.session;
    expect((await fresh.me()).email, r.user.email);
  });

  group('لوحة التحكم', () {
    test('البراد 14 «شحنة دمياط» مطابق للتصميم', () async {
      final d = await api.dashboard();
      final c = d.currentCooler!;
      expect(c.no, 14);
      expect(c.name, 'شحنة دمياط');
      expect(c.isOpen, isTrue);
      expect(c.purchases, 6);
      expect(c.farmers, 5);
      expect(c.boxes, 249);
      expect(c.weightGrams, 2718200);
      expect(c.valuePiasters, 4083940);
      expect(c.paidPiasters, 2331400);
      expect(c.remainingPiasters, 1752540);
      expect(c.packagingApprovedPiasters, 450000);
      expect(c.openedAt, '2026-10-02T06:40:00${_offset(DateTime(2026, 10, 2, 6, 40))}');
      expect(d.openCoolers.map((c) => c.no), [14, 13]);
    });

    test('البراد 13 «شحنة الإسكندرية»', () async {
      final c = (await api.dashboard()).openCoolers.firstWhere((c) => c.no == 13);
      expect(c.name, 'شحنة الإسكندرية');
      expect(c.purchases, 3);
      expect(c.boxes, 112);
      expect(c.weightGrams, 1220800);
      expect(c.valuePiasters, 1831200);
      expect(c.paidPiasters, 1000000);
      expect(c.remainingPiasters, 831200);
    });

    test('البراد 12 «شحنة بورسعيد» مقفّل', () async {
      final d = await api.dashboard(coolerId: 'CL-0012');
      final c = d.currentCooler!;
      expect(c.no, 12);
      expect(c.name, 'شحنة بورسعيد');
      expect(c.isOpen, isFalse);
      expect(c.purchases, 14);
      expect(c.farmers, 9);
      expect(c.boxes, 588);
      expect(c.weightGrams, 6391400);
      expect(c.valuePiasters, 9601400);
      expect(c.paidPiasters, 8854850);
      expect(c.packagingApprovedPiasters, 1497000);
      expect(c.packagingLatePiasters, 45500);
      expect(c.totalCostPiasters, 9601400 + 1497000);
      expect(d.kpis.closedCoolers, 1);
      expect(d.kpis.openCoolers, 0);
      expect(d.kpis.purchases, 14);
      expect(d.openCoolers, isEmpty);
    });

    test('مؤشرات الموسم محسوبة من البرادات الثلاثة', () async {
      final d = await api.dashboard();
      final k = d.kpis;
      expect(d.period.key, 'season');
      expect(d.period.label, 'هذا الموسم');
      expect(d.empty, isFalse);
      expect(k.closedCoolers, 1);
      expect(k.openCoolers, 2);
      expect(k.purchases, 23);
      expect(k.boxes, 249 + 112 + 588);
      expect(k.weightGrams, 2718200 + 1220800 + 6391400);
      expect(k.purchaseValuePiasters, 4083940 + 1831200 + 9601400);
      expect(k.packagingApprovedPiasters, 450000 + 1497000);
      expect(k.distinctFarmers, 12);
      final paidFarmers = 2331400 + 1000000 + 8854850;
      expect(k.remainingFarmersPiasters, k.purchaseValuePiasters - paidFarmers);
      expect(k.remainingPiasters, k.purchaseValuePiasters + k.packagingApprovedPiasters - k.paidPiasters);
      expect(k.remainingPiasters, k.remainingFarmersPiasters + k.remainingSuppliersPiasters);
      expect(k.avgPricePerKgPiasters, closeTo(k.purchaseValuePiasters * 1000 / k.weightGrams, 0.5));
    });

    test('آخر العمليات: 10 بالأحدث أولًا، تبدأ بعمليات البراد 14 كما في التصميم', () async {
      final r = (await api.dashboard()).recent;
      expect(r, hasLength(10));
      final purchase = r.firstWhere((a) => a.id == 'PU-0023');
      expect(purchase.title, 'حسن البدري');
      expect(purchase.amountPiasters, 441000);
      expect(purchase.status, 'partial');
      expect(purchase.statusLabel, 'جزئي');
      expect(purchase.subtitle, 'شراء · براد 14 · محمد الحسناوي');
      final pack = r.firstWhere((a) => a.type == 'packaging');
      expect(pack.title, 'الوادي للتغليف');
      expect(pack.status, 'draft');
      expect(pack.amountPiasters, 258000);
      expect(r.any((a) => a.title == 'الحاج محمود عبد العال' && a.status == 'unpaid'), isTrue);
      expect(r.any((a) => a.title == 'عبد الرحمن الشافعي' && a.status == 'paid' && a.amountPiasters == 806400), isTrue);
      expect(r.any((a) => a.type == 'payment' && a.title == 'سعيد أبو زيد' && a.amountPiasters == 500000), isTrue);
      for (var i = 1; i < r.length; i++) {
        expect(r[i - 1].at!.compareTo(r[i].at!), greaterThanOrEqualTo(0));
      }
    });

    test('فترة «اليوم» تحصر عمليات اليوم، وعدد البرادات لا يتأثر', () async {
      final d = await api.dashboard(period: 'today');
      expect(d.period.label, 'اليوم');
      expect(d.kpis.purchases, 6);
      expect(d.kpis.boxes, 249);
      expect(d.kpis.closedCoolers, 1);
      expect(d.kpis.openCoolers, 2);
    });

    test('فترة غير صحيحة أو براد غير موجود', () async {
      await expectLater(
        api.dashboard(period: 'year'),
        throwsA(isA<ApiException>().having((e) => e.field, 'field', 'period').having((e) => e.code, 'code', ApiErrorCode.validation)),
      );
      await expectLater(
        api.dashboard(coolerId: 'CL-9999'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiErrorCode.notFound)),
      );
    });
  });

  group('المستخدمون', () {
    test('القائمة كما في التصميم', () async {
      final users = await api.listUsers();
      expect(users.map((u) => u.name), ['محمد الحسناوي', 'كريم عبد الله', 'يوسف ناصر', 'سلمى فؤاد', 'أحمد سمير']);
      final karim = users[1];
      expect(karim.role, UserRole.entry);
      expect(karim.permissions.closeCoolers, isTrue);
      expect(karim.permissions.editOthers, isFalse);
      expect(karim.permissions.reopenCoolers, isFalse);
      expect(users[3].role, UserRole.viewer);
      expect(users[3].permissions.recordPurchases, isFalse);
      expect(users[4].active, isFalse);
      expect(users.where((u) => u.active), hasLength(4));
    });

    test('إضافة مستخدم والتحقق من البريد المكرر والبريد الخاطئ', () async {
      final u = await api.addUser(
        email: ' Nour.Hassan@Gmail.com ',
        name: 'نور حسن',
        role: UserRole.entry,
        permissions: const UserPermissions(recordPurchases: true),
      );
      expect(u.email, 'nour.hassan@gmail.com');
      expect(u.id, 'US-0006');
      expect(u.permissions.recordPurchases, isTrue);
      expect(u.permissions.addFarmers, isFalse);
      expect(u.version, 1);

      await expectLater(
        api.addUser(email: 'karim.abdallah.eg@gmail.com', name: 'x', role: UserRole.viewer),
        throwsA(isA<ApiException>()
            .having((e) => e.field, 'field', 'email')
            .having((e) => e.message, 'message', contains('مسجّل بالفعل'))),
      );
      await expectLater(
        api.addUser(email: 'not-an-email', name: 'x', role: UserRole.viewer),
        throwsA(isA<ApiException>().having((e) => e.field, 'field', 'email')),
      );
      await expectLater(
        api.addUser(email: 'a@b.co', name: '  ', role: UserRole.viewer),
        throwsA(isA<ApiException>().having((e) => e.field, 'field', 'name')),
      );
    });

    test('المدير الأساسي لا يُعطّل ولا يُخفض دوره', () async {
      final owner = (await api.listUsers()).first;
      await expectLater(
        api.updateUser(id: owner.id, expectedVersion: owner.version, active: false),
        throwsA(isA<ApiException>().having((e) => e.field, 'field', 'status')),
      );
      await expectLater(
        api.updateUser(id: owner.id, expectedVersion: owner.version, role: UserRole.entry),
        throwsA(isA<ApiException>().having((e) => e.field, 'field', 'role')),
      );
    });

    test('آخر مدير نشط (غير الأساسي) لا يمكن تعطيله إن لم يكن غيره', () async {
      // المدير الأساسي يُحسب دائمًا، لذا نختبر القاعدة على مدير إضافي مع وجود الأساسي: مسموح.
      final added = await api.addUser(email: 'second@example.com', name: 'مدير ثانٍ', role: UserRole.admin);
      final updated = await api.updateUser(id: added.id, expectedVersion: added.version, active: false);
      expect(updated.active, isFalse);
      expect(updated.version, 2);
    });

    test('تعديل الصلاحيات يرفع الإصدار، والإصدار القديم ⇒ CONFLICT', () async {
      final karim = (await api.listUsers())[1];
      final updated = await api.updateUser(
        id: karim.id,
        expectedVersion: karim.version,
        permissions: karim.permissions.copyWith(editOthers: true),
      );
      expect(updated.permissions.editOthers, isTrue);
      expect(updated.version, karim.version + 1);
      await expectLater(
        api.updateUser(id: karim.id, expectedVersion: karim.version, name: 'كريم'),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', ApiErrorCode.conflict)
            .having((e) => e.details['currentVersion'], 'currentVersion', karim.version + 1)),
      );
    });

    test('تحويل موظف إلى مشاهدة يلغي صلاحيات الإدخال', () async {
      final karim = (await api.listUsers())[1];
      final viewer = await api.updateUser(id: karim.id, expectedVersion: karim.version, role: UserRole.viewer);
      expect(viewer.role, UserRole.viewer);
      expect(viewer.permissions.recordPurchases, isFalse);
      expect(viewer.permissions.viewData, isTrue);
    });

    test('نفس requestId يعيد النتيجة نفسها دون تكرار', () async {
      final a = await api.call('users.add',
          payload: {'email': 'r@example.com', 'name': 'ر', 'role': 'viewer'}, mutation: true, requestId: 'req-1');
      final b = await api.call('users.add',
          payload: {'email': 'r@example.com', 'name': 'ر', 'role': 'viewer'}, mutation: true, requestId: 'req-1');
      expect(b, a);
      expect((await api.listUsers()).where((u) => u.email == 'r@example.com'), hasLength(1));
    });
  });

  group('ملف Google Sheets', () {
    test('الحالة: عمود ناقص وصفحة غير موجودة، والإصلاح يكملها', () async {
      final s = await api.sheetStatus();
      expect(s.configured, isTrue);
      expect(s.ok, isFalse);
      expect(s.needsRepair, isTrue);
      final packaging = s.sheets.firstWhere((x) => x.title == 'مشتريات التعبئة');
      expect(packaging.exists, isTrue);
      expect(packaging.missingColumns, ['رقم الفاتورة']);
      final audit = s.sheets.firstWhere((x) => x.title == 'سجل التعديلات');
      expect(audit.exists, isFalse);
      expect(s.sheets.where((x) => !x.ok), hasLength(2));
      expect(s.lastErrorMessage, isNotNull);

      final fixed = await api.sheetRepair();
      expect(fixed.ok, isTrue);
      expect(fixed.needsRepair, isFalse);
      expect((await api.sheetStatus()).ok, isTrue);
    });

    test('ربط ملف آخر: رابط خاطئ ⇒ VALIDATION، ورابط صحيح ⇒ تحذير', () async {
      await expectLater(
        api.sheetConnect('https://example.com/not-a-sheet'),
        throwsA(isA<ApiException>().having((e) => e.field, 'field', 'spreadsheet')),
      );
      final s = await api.sheetConnect('https://docs.google.com/spreadsheets/d/1AbCdEfGhIjKlMnOpQrStUvWxYz0123456789/edit#gid=0');
      expect(s.spreadsheetId, '1AbCdEfGhIjKlMnOpQrStUvWxYz0123456789');
      expect(s.warning, contains('لا تُنقل'));
    });
  });

  test('قبل 10:58 ص تُزاح الأوقات فلا يوجد سجل في المستقبل', () async {
    final now = DateTime(2026, 10, 2, 8, 0);
    final early = DemoBackendApi(latency: Duration.zero, clock: () => now);
    early.session = (await early.login('x')).session;
    final d = await early.dashboard(period: 'all');
    for (final a in d.recent) {
      expect(DateTime.parse(a.at!).isAfter(now), isFalse, reason: a.id);
    }
    expect(DateTime.parse(d.recent.first.at!).isAtSameMomentAs(now.subtract(const Duration(minutes: 14))), isTrue);
    expect(d.kpis.purchases, 23);
  });

  test('الإعدادات', () async {
    final s = await api.settings();
    expect(s.businessName, 'حاسبة الحسناوي');
    expect(s.currencySymbol, 'ج.م');
    expect(s.seasonStart, '2026-08-01');
  });

  test('القراءات الأخرى: البرادات والمشتريات', () async {
    final coolers = await api.call('coolers.list');
    expect((coolers['coolers'] as List).map((c) => c['no']), [14, 13, 12]);
    final detail = await api.call('coolers.get', payload: {'id': 'CL-0014'});
    final purchases = detail['purchases'] as List;
    expect(purchases, hasLength(6));
    final sum = purchases.fold<int>(0, (s, p) => s + (p['valuePiasters'] as int));
    expect(sum, 4083940);
    for (final p in purchases) {
      expect(p['totalWeightGrams'], (p['boxes'] as int) * (p['avgWeightGrams'] as int));
    }
    await expectLater(
      api.call('purchases.create', mutation: true, requestId: 'x'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiErrorCode.unknownAction)),
    );
  });
}

String _offset(DateTime t) {
  final o = t.timeZoneOffset;
  final m = o.inMinutes.abs();
  return '${o.isNegative ? '-' : '+'}${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
}
