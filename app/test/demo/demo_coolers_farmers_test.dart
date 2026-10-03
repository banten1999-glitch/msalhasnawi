import 'package:flutter_test/flutter_test.dart';
import 'package:rumman_calculator/core/api/api_exception.dart';
import 'package:rumman_calculator/core/api/demo_backend_api.dart';
import 'package:rumman_calculator/core/models/records.dart';
import 'package:rumman_calculator/core/models/user.dart';

import 'demo_support.dart';

void main() {
  late DemoBackendApi api;

  setUp(() async => api = await signedInDemo());

  group('coolers', () {
    test('coolers.create: الرقم التالي ومفتوح، ويصبح البراد الحالي', () async {
      final c = await api.createCooler(name: 'شحنة المنصورة', carNo: 'م ن ص 1234', driver: 'وائل شوقي');
      expect(c.id, 'CL-0015');
      expect(c.no, 15);
      expect(c.isOpen, isTrue);
      expect(c.openedBy, 'محمد الحسناوي');
      expect(c.openedAt, isoLocal(demoNow));
      expect(c.version, 1);
      expect(c.purchases, 0);
      expect(c.valuePiasters, 0);
      expect(c.closeSnapshot, isNull);

      expect((await api.listCoolers()).map((c) => c.no), [15, 14, 13, 12]);
      final d = await api.dashboard();
      expect(d.currentCooler!.id, 'CL-0015');
      expect(d.openCoolers.map((c) => c.no), [15, 14, 13]);
      expect(d.kpis.openCoolers, 3);

      await expectLater(api.createCooler(name: 'x' * 81), throwsApi(ApiErrorCode.validation, field: 'name'));
      api.switchUser('US-0004');
      await expectLater(api.createCooler(name: 'y'), throwsApi(ApiErrorCode.forbidden, permission: 'recordPurchases'));
    });

    test('coolers.create بنفس requestId ⇒ براد واحد، حتى بعد انتهاء ذاكرة الطلبات', () async {
      final a = await api.createCooler(name: 'شحنة', requestId: 'cooler-1');
      final b = await api.createCooler(name: 'شحنة', requestId: 'cooler-1');
      api.forgetRequestCache();
      final c = await api.call('coolers.create', payload: {'name': 'شحنة'}, mutation: true, requestId: 'cooler-1');
      expect(b.id, a.id);
      expect(c['replayed'], isTrue);
      expect((c['cooler'] as Map)['id'], a.id);
      expect(await api.listCoolers(), hasLength(4));
    });

    test('التقفيل: لقطة بالأرقام الحية (مزارعون مميزون)، ثم القواعد بعد التقفيل', () async {
      final c = await api.createCooler(name: 'شحنة المنصورة');
      await api.createPurchase(buy(
          coolerId: c.id, farmerId: 'FR-0001', payment: const PaymentModeInput(mode: PaymentMode.full)));
      final second = await api.createPurchase(buy(
        coolerId: c.id,
        farmerId: 'FR-0002',
        boxes: 40,
        avgWeightGrams: 10000,
        pricePerKgPiasters: 1600,
        payment: const PaymentModeInput(mode: PaymentMode.partial, amountPiasters: 300000),
      ));
      await api.createPurchase(buy(coolerId: c.id, farmerId: 'FR-0001', boxes: 10, avgWeightGrams: 12000));
      final pk = await api.savePackaging(PackagingDraftInput(
        supplier: 'الوادي للتغليف',
        coolerId: c.id,
        items: const [PackagingItem(name: 'الصناديق', quantity: 100, unit: 'قطعة', unitPricePiasters: 1800)],
      ));
      await api.approvePackaging(id: pk.packaging.id, expectedVersion: 1);

      await expectLater(
        api.closeCooler(id: c.id, expectedVersion: 1, clientPendingCount: 2),
        throwsA(isA<ApiException>()
            .having((e) => e.field, 'field', 'clientPendingCount')
            .having((e) => e.details['pending'], 'pending', 2)
            .having((e) => e.message, 'message', contains('بانتظار المزامنة'))),
      );
      await expectLater(
        api.closeCooler(id: c.id, expectedVersion: 5, clientPendingCount: 0),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', ApiErrorCode.conflict)
            .having((e) => e.details['currentVersion'], 'currentVersion', 1)),
      );

      final closed = await api.closeCooler(id: c.id, expectedVersion: 1, clientPendingCount: 0);
      expect(closed.isOpen, isFalse);
      expect(closed.closedAt, isoLocal(demoNow));
      expect(closed.closedBy, 'محمد الحسناوي');
      expect(closed.version, 2);
      final s = closed.closeSnapshot!;
      expect(s.farmers, 2);
      expect(s.purchases, 3);
      expect(s.boxes, 100);
      expect(s.weightGrams, 550000 + 400000 + 120000);
      expect(s.valuePiasters, 825000 + 640000 + 180000);
      expect(s.paidPiasters, 825000 + 300000);
      expect(s.remainingPiasters, 520000);
      expect(s.packagingPiasters, 180000);
      expect(s.totalCostPiasters, 1645000 + 180000);
      expect(closed.avgPricePerKgPiasters, 1537);

      await expectLater(api.closeCooler(id: c.id, expectedVersion: 2, clientPendingCount: 0),
          throwsApi(ApiErrorCode.coolerClosed, message: 'مقفّل بالفعل'));
      await expectLater(api.createPurchase(buy(coolerId: c.id)), throwsApi(ApiErrorCode.coolerClosed, field: 'coolerId'));
      await expectLater(
        api.cancelPurchase(id: second.purchase.id, reason: 'x'),
        throwsApi(ApiErrorCode.coolerClosed),
      );

      // الدفع مسموح بعد التقفيل، والأرقام الحية تتغير بينما اللقطة ثابتة.
      await api.createPayment(targetType: PaymentTarget.purchase, targetId: second.purchase.id, amountPiasters: 340000);
      final late = await api.savePackaging(PackagingDraftInput(
        coolerId: c.id,
        items: const [PackagingItem(name: 'السترتش', quantity: 2, unit: 'لفة', unitPricePiasters: 21000)],
      ));
      expect((await api.approvePackaging(id: late.packaging.id, expectedVersion: 1)).packaging.late, isTrue);
      final live = (await api.getCooler(c.id)).cooler;
      expect(live.paidPiasters, 825000 + 300000 + 340000);
      expect(live.packagingApprovedPiasters, 180000 + 42000);
      expect(live.packagingLatePiasters, 42000);
      expect(live.closeSnapshot!.paidPiasters, 825000 + 300000);
      expect(live.closeSnapshot!.packagingPiasters, 180000);

      final dash = await api.dashboard();
      expect(dash.kpis.closedCoolers, 2);
      expect(dash.currentCooler!.id, 'CL-0014');
    });

    test('إعادة الفتح: للمدير فقط وبسبب، وتبقى اللقطة، والتقفيل التالي يستبدلها', () async {
      await expectLater(api.reopenCooler(id: 'CL-0012', reason: '  '), throwsApi(ApiErrorCode.validation, field: 'reason'));
      api.switchUser('US-0002'); // كريم يقفّل لكن لا يعيد الفتح
      await expectLater(api.reopenCooler(id: 'CL-0012', reason: 'تصحيح وزن'),
          throwsApi(ApiErrorCode.forbidden, permission: 'reopenCoolers'));
      api.switchUser('US-0001');

      final reopened = await api.reopenCooler(id: 'CL-0012', reason: 'تصحيح وزن');
      expect(reopened.isOpen, isTrue);
      expect(reopened.version, 5);
      expect(reopened.closeSnapshot!.purchases, 14);
      expect(reopened.closeSnapshot!.paidPiasters, 7528550);
      await expectLater(api.reopenCooler(id: 'CL-0012', reason: 'مرة أخرى'),
          throwsApi(ApiErrorCode.validation, field: 'id', message: 'مفتوح بالفعل'));

      final p = await api.createPurchase(buy(coolerId: 'CL-0012'));
      expect(p.purchase.coolerNo, 12);
      expect((await api.dashboard()).kpis.openCoolers, 3);

      api.switchUser('US-0002');
      final closed = await api.closeCooler(id: 'CL-0012', expectedVersion: 5, clientPendingCount: 0);
      expect(closed.closedBy, 'كريم عبد الله');
      expect(closed.closeSnapshot!.purchases, 15);
      expect(closed.closeSnapshot!.valuePiasters, 9601400 + 825000);
      expect(closed.closeSnapshot!.paidPiasters, 8854850);
      expect(closed.closeSnapshot!.packagingPiasters, 1497000);

      api.switchUser('US-0003'); // يوسف: دون «تقفيل البرادات»
      await expectLater(api.closeCooler(id: 'CL-0014', expectedVersion: 1, clientPendingCount: 0),
          throwsApi(ApiErrorCode.forbidden, permission: 'closeCoolers'));
    });

    test('القائمة حسب الحالة والتفاصيل مع الملغاة', () async {
      expect((await api.listCoolers(status: 'open')).map((c) => c.no), [14, 13]);
      expect((await api.listCoolers(status: 'closed')).map((c) => c.no), [12]);
      await expectLater(api.listCoolers(status: 'late'), throwsApi(ApiErrorCode.validation, field: 'status'));
      await expectLater(api.getCooler('CL-0099'), throwsApi(ApiErrorCode.notFound, field: 'id'));
      final d = await api.getCooler('CL-0014');
      expect(d.purchases.map((p) => p.id), ['PU-0023', 'PU-0022', 'PU-0021', 'PU-0020', 'PU-0019', 'PU-0018']);
    });
  });

  group('farmers', () {
    test('farmers.create: رقم تالٍ، وهاتف بأرقام عربية، والاسم المكرر بعد التطبيع ⇒ VALIDATION', () async {
      final f = await api.createFarmer(name: 'رضا الجمال', phone: '٠١٠٠١٢٣٤٥٦٧', village: 'الزرقا');
      expect(f.id, 'FR-0014');
      expect(f.no, 14);
      expect(f.phone, '01001234567');
      expect(f.village, 'الزرقا');
      expect(f.active, isTrue);
      expect(f.version, 1);
      expect((await api.listFarmers(query: '0100123')).map((f) => f.id), ['FR-0014']);

      await expectLater(
        api.createFarmer(name: 'سعيد ابو زيد'),
        throwsA(isA<ApiException>()
            .having((e) => e.field, 'field', 'name')
            .having((e) => (e.details['existing'] as Map)['id'], 'existing.id', 'FR-0001')
            .having((e) => e.message, 'message', contains('أكّد أنه شخص مختلف'))),
      );
      final twin = await api.createFarmer(name: 'سعيد ابو زيد', allowDuplicate: true);
      expect(twin.id, 'FR-0015');

      await expectLater(api.createFarmer(name: 'x', phone: 'abc'), throwsApi(ApiErrorCode.validation, field: 'phone'));
      await expectLater(api.createFarmer(name: ' '), throwsApi(ApiErrorCode.validation, field: 'name'));
    });

    test('farmers.create بنفس requestId ⇒ مزارع واحد', () async {
      final a = await api.createFarmer(name: 'مزارع جديد', requestId: 'farmer-1');
      final b = await api.createFarmer(name: 'مزارع جديد', requestId: 'farmer-1');
      api.forgetRequestCache();
      final c = await api.call('farmers.create', payload: {'name': 'مزارع جديد'}, mutation: true, requestId: 'farmer-1');
      expect(b.id, a.id);
      expect(c['replayed'], isTrue);
      expect((await api.listFarmers(query: 'مزارع جديد')), hasLength(1));
    });

    test('farmers.update: الإصدار والإيقاف والتكرار', () async {
      final f = (await api.listFarmers(query: 'جمال الصاوي')).single;
      final renamed = await api.updateFarmer(id: f.id, expectedVersion: f.version, name: 'جمال الصاوي الكبير', phone: '0109');
      expect(renamed.name, 'جمال الصاوي الكبير');
      expect(renamed.version, 2);
      await expectLater(
        api.updateFarmer(id: f.id, expectedVersion: 1, village: 'السرو'),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', ApiErrorCode.conflict)
            .having((e) => e.details['currentVersion'], 'currentVersion', 2)),
      );
      final same = await api.updateFarmer(id: f.id, expectedVersion: 2, name: 'جمال الصاوي الكبير');
      expect(same.version, 2);
      await expectLater(api.updateFarmer(id: f.id, expectedVersion: 2, name: 'حسن البدري'),
          throwsApi(ApiErrorCode.validation, field: 'name'));

      final stopped = await api.updateFarmer(id: f.id, expectedVersion: 2, active: false);
      expect(stopped.active, isFalse);
      expect((await api.listFarmers()).map((x) => x.id), isNot(contains(f.id)));
      expect((await api.listFarmers(includeInactive: true)).map((x) => x.id), contains(f.id));
      await expectLater(api.createPurchase(buy(farmerId: f.id)), throwsApi(ApiErrorCode.validation, field: 'farmerId'));
      await expectLater(api.updateFarmer(id: 'FR-9999', expectedVersion: 1, name: 'x'), throwsApi(ApiErrorCode.notFound));
    });

    test('farmers.list: بحث مطبّع بالاسم أو القرية أو الرقم، والموقوفون مخفيون', () async {
      expect((await api.listFarmers(query: 'ابراهيم')).map((f) => f.name), ['إبراهيم الدسوقي']);
      expect((await api.listFarmers(query: 'فارسكور')).map((f) => f.no), [2, 8]);
      expect((await api.listFarmers(query: '3')).map((f) => f.name), ['حسن البدري']);
      expect(await api.listFarmers(), hasLength(12));
      expect(await api.listFarmers(includeInactive: true), hasLength(13));
    });

    test('الصلاحيات: المشاهد لا يضيف، والمعطّل لا يدخل', () async {
      api.switchUser('US-0004');
      expect(await api.listFarmers(), hasLength(12));
      await expectLater(api.createFarmer(name: 'x'), throwsApi(ApiErrorCode.forbidden, permission: 'addFarmers'));
      await expectLater(api.listUsers(), throwsApi(ApiErrorCode.forbidden, permission: 'manageUsers'));

      api.switchUser('US-0005'); // معطّل
      await expectLater(
        api.me(),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', ApiErrorCode.notAllowed)
            .having((e) => e.details['reason'], 'reason', 'disabled')),
      );
      await expectLater(api.dashboard(), throwsApi(ApiErrorCode.notAllowed));
      await expectLater(api.login('x'), throwsApi(ApiErrorCode.notAllowed));
    });

    test('ربط ملف آخر للمدير الأساسي فقط', () async {
      final admin = await api.addUser(email: 'admin2@example.com', name: 'مدير ثانٍ', role: UserRole.admin);
      api.switchUser(admin.id);
      await expectLater(
        api.sheetConnect('1AbCdEfGhIjKlMnOpQrStUvWxYz0123456789'),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', ApiErrorCode.forbidden)
            .having((e) => e.details['reason'], 'reason', 'bootstrap_only')),
      );
      expect((await api.sheetStatus()).configured, isTrue);
    });
  });
}
