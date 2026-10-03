import 'package:flutter_test/flutter_test.dart';
import 'package:rumman_calculator/core/api/api_exception.dart';
import 'package:rumman_calculator/core/api/demo_backend_api.dart';
import 'package:rumman_calculator/core/models/records.dart';
import 'package:rumman_calculator/core/models/user.dart';

import 'demo_support.dart';

void main() {
  late DemoBackendApi api;

  setUp(() async => api = await signedInDemo());

  group('purchases.create', () {
    test('50 صندوق × 11 كغ × 15 ج.م/كغ = 550 كغ و8,250.00 ج.م، وأرقام البراد واللوحة تتحدث', () async {
      final before = await api.getCooler('CL-0014');
      final r = await api.createPurchase(buy());
      final p = r.purchase;
      expect(p.id, 'PU-0024');
      expect(p.coolerNo, 14);
      expect(p.farmerName, 'الحاج محمود عبد العال');
      expect(p.totalWeightGrams, 550000);
      expect(p.valuePiasters, 825000);
      expect(p.paidPiasters, 0);
      expect(p.remainingPiasters, 825000);
      expect(p.payStatus, PayStatus.unpaid);
      expect(p.weightMethod, WeightMethod.direct);
      expect(p.tareGrams, isNull);
      expect(p.active, isTrue);
      expect(p.version, 1);
      expect(p.createdBy, 'محمد الحسناوي');
      expect(p.createdByEmail, 'hasnawi.owner@gmail.com');
      expect(p.occurredAt, isoLocal(demoNow));
      expect(r.payment, isNull);
      expect(r.farmer, isNull);
      expect(r.replayed, isFalse);

      final after = (await api.getCooler('CL-0014')).cooler;
      expect(after.purchases, before.cooler.purchases + 1);
      expect(after.boxes, before.cooler.boxes + 50);
      expect(after.weightGrams, before.cooler.weightGrams + 550000);
      expect(after.valuePiasters, before.cooler.valuePiasters + 825000);
      expect(after.remainingPiasters, before.cooler.remainingPiasters + 825000);
      expect(after.farmers, before.cooler.farmers, reason: 'المزارع اشترى منه البراد من قبل');
      final k = (await api.dashboard()).kpis;
      expect(k.purchases, 24);
      expect(k.purchaseValuePiasters, 4083940 + 1831200 + 9601400 + 825000);
      expect((await api.dashboard()).recent.first.id, 'PU-0024');
    });

    test('دفع كامل: دفعة بقيمة العملية نفسها وفي وقتها (paidAt = occurredAt)', () async {
      final r = await api.createPurchase(buy(
        occurredAt: '2026-10-02T09:00:00+03:00',
        payment: const PaymentModeInput(mode: PaymentMode.full, method: PaymentMethod.bank),
      ));
      final pay = r.payment!;
      expect(pay.amountPiasters, 825000);
      expect(pay.amountPiasters, r.purchase.valuePiasters);
      expect(pay.paidAt, r.purchase.occurredAt);
      expect(DateTime.parse(pay.paidAt).isAtSameMomentAs(DateTime.parse('2026-10-02T09:00:00+03:00')), isTrue);
      expect(pay.method, PaymentMethod.bank);
      expect(pay.payeeType, PayeeType.farmer);
      expect(pay.payeeId, 'FR-0004');
      expect(pay.payeeName, 'الحاج محمود عبد العال');
      expect(pay.targetType, PaymentTarget.purchase);
      expect(pay.targetId, r.purchase.id);
      expect(pay.coolerNo, 14);
      expect(pay.no, 'D-0023');
      expect(r.purchase.paidPiasters, 825000);
      expect(r.purchase.remainingPiasters, 0);
      expect(r.purchase.payStatus, PayStatus.paid);
      expect(r.purchase.version, 1, reason: 'الدفعة مع الشراء تُكتب في صف العملية نفسه');
    });

    test('دفع جزئي: أقل من القيمة، وإلا VALIDATION دون أي سجل', () async {
      final r = await api.createPurchase(
          buy(payment: const PaymentModeInput(mode: PaymentMode.partial, amountPiasters: 300000)));
      expect(r.payment!.amountPiasters, 300000);
      expect(r.purchase.paidPiasters, 300000);
      expect(r.purchase.remainingPiasters, 525000);
      expect(r.purchase.payStatus, PayStatus.partial);

      final count = (await api.listPurchases()).length;
      await expectLater(
        api.createPurchase(buy(payment: const PaymentModeInput(mode: PaymentMode.partial, amountPiasters: 825000))),
        throwsApi(ApiErrorCode.validation, field: 'payment.amountPiasters', message: 'أقل من قيمة العملية'),
      );
      await expectLater(
        api.createPurchase(buy(payment: const PaymentModeInput(mode: PaymentMode.partial))),
        throwsApi(ApiErrorCode.validation, field: 'payment.amountPiasters'),
      );
      expect((await api.listPurchases()).length, count);
    });

    test('إعادة الإرسال بنفس requestId ⇒ سجل واحد ودفعة واحدة، حتى بعد انتهاء ذاكرة الطلبات', () async {
      final input = buy(payment: const PaymentModeInput(mode: PaymentMode.full));
      final a = await api.createPurchase(input, requestId: 'buy-1');
      final b = await api.createPurchase(input, requestId: 'buy-1');
      expect(b.purchase.id, a.purchase.id);
      expect(b.payment!.id, a.payment!.id);

      // بعد انتهاء ذاكرة الطلبات (6 ساعات في الخادم) يُكشف التكرار من «مفتاح عدم التكرار» في الصف.
      api.forgetRequestCache();
      final c = await api.createPurchase(input, requestId: 'buy-1');
      expect(c.replayed, isTrue);
      expect(c.purchase.id, a.purchase.id);
      expect(c.payment!.id, a.payment!.id);

      expect((await api.listPurchases(coolerId: 'CL-0014')).where((p) => p.id == a.purchase.id), hasLength(1));
      expect(await api.listPayments(targetId: a.purchase.id), hasLength(1));
      expect((await api.listPurchases()).length, 23 + 1);

      // معرّف جديد = عملية جديدة.
      final d = await api.createPurchase(input, requestId: 'buy-2');
      expect(d.purchase.id, isNot(a.purchase.id));
    });

    test('مزارع جديد مع الشراء (newFarmerName)، والتكرار يعيده نفسه', () async {
      final r = await api.createPurchase(buy(newFarmerName: 'رضا الجمال'), requestId: 'new-farmer');
      expect(r.farmer, isNotNull);
      expect(r.farmer!.id, 'FR-0014');
      expect(r.farmer!.no, 14);
      expect(r.farmer!.name, 'رضا الجمال');
      expect(r.purchase.farmerId, 'FR-0014');
      expect(r.purchase.farmerName, 'رضا الجمال');
      expect((await api.listFarmers(query: 'رضا')).map((f) => f.id), ['FR-0014']);

      api.forgetRequestCache();
      final again = await api.createPurchase(buy(newFarmerName: 'رضا الجمال'), requestId: 'new-farmer');
      expect(again.replayed, isTrue);
      expect(again.farmer!.id, 'FR-0014');
      expect((await api.listFarmers()).where((f) => f.name == 'رضا الجمال'), hasLength(1));
    });

    test('newFarmerName المكرر (بعد التطبيع) أو مع farmerId ⇒ VALIDATION', () async {
      await expectLater(
        api.createPurchase(buy(newFarmerName: 'سعيد ابو زيد')),
        throwsApi(ApiErrorCode.validation, field: 'newFarmerName', message: 'سعيد أبو زيد'),
      );
      await expectLater(
        api.call('purchases.create',
            payload: {...buy().toJson(), 'newFarmerName': 'اسم جديد'}, mutation: true),
        throwsApi(ApiErrorCode.validation, field: 'farmerId', message: 'وليس الاثنين معًا'),
      );
      await expectLater(
        api.call('purchases.create', payload: {...buy().toJson()}..remove('payment'), mutation: true),
        throwsApi(ApiErrorCode.validation, field: 'payment'),
      );
    });

    test('الصلاحيات: newFarmerName يحتاج addFarmers، والدفع يحتاج recordPayments', () async {
      final clerk = await api.addUser(
        email: 'weigh@example.com',
        name: 'موظف وزن',
        role: UserRole.entry,
        permissions: const UserPermissions(recordPurchases: true),
      );
      api.switchUser(clerk.id);
      await expectLater(
        api.createPurchase(buy(newFarmerName: 'مزارع جديد')),
        throwsApi(ApiErrorCode.forbidden, permission: 'addFarmers'),
      );
      await expectLater(
        api.createPurchase(buy(payment: const PaymentModeInput(mode: PaymentMode.full))),
        throwsApi(ApiErrorCode.forbidden, permission: 'recordPayments'),
      );
      final ok = await api.createPurchase(buy());
      expect(ok.purchase.createdBy, 'موظف وزن');

      api.switchUser('US-0004'); // سلمى: مشاهدة فقط
      await expectLater(api.createPurchase(buy()), throwsApi(ApiErrorCode.forbidden, permission: 'recordPurchases'));
    });

    test('طريقة العينة: المتوسط = round(متوسط العينة − الفارغ) ±1 غ، والفارغ الافتراضي من الإعدادات', () async {
      const samples = [12400, 12900, 12100];
      // (37400 − 3 × 1900) ÷ 3 = 10566.67 ⇒ 10567
      for (final avg in const [10566, 10567, 10568]) {
        final r = await api.createPurchase(buy(
          boxes: 20,
          avgWeightGrams: avg,
          weightMethod: WeightMethod.sample,
          sampleWeightsGrams: samples,
        ));
        expect(r.purchase.weightMethod, WeightMethod.sample);
        expect(r.purchase.sampleWeightsGrams, samples);
        expect(r.purchase.tareGrams, 1900);
        expect(r.purchase.totalWeightGrams, 20 * avg);
      }
      await expectLater(
        api.createPurchase(buy(avgWeightGrams: 10569, weightMethod: WeightMethod.sample, sampleWeightsGrams: samples)),
        throwsA(isA<ApiException>()
            .having((e) => e.field, 'field', 'avgWeightGrams')
            .having((e) => e.details['expectedGrams'], 'expectedGrams', 10567)
            .having((e) => e.message, 'message', contains('10.567 كغ'))),
      );
      // فارغ صريح = 0 ⇒ 12467
      final zero = await api.createPurchase(buy(
          avgWeightGrams: 12467, weightMethod: WeightMethod.sample, sampleWeightsGrams: samples, tareGrams: 0));
      expect(zero.purchase.tareGrams, 0);
      // تغيير «وزن الصندوق الفارغ» في الإعدادات يغيّر الافتراضي: (37400 − 6000) ÷ 3 ⇒ 10467
      await api.updateSettings({'emptyBoxGrams': 2000});
      final custom = await api.createPurchase(
          buy(avgWeightGrams: 10467, weightMethod: WeightMethod.sample, sampleWeightsGrams: samples));
      expect(custom.purchase.tareGrams, 2000);

      await expectLater(
        api.createPurchase(buy(weightMethod: WeightMethod.sample)),
        throwsApi(ApiErrorCode.validation, field: 'sampleWeightsGrams'),
      );
      await expectLater(
        api.createPurchase(buy(weightMethod: WeightMethod.sample, sampleWeightsGrams: const [1500, 1800])),
        throwsApi(ApiErrorCode.validation, field: 'sampleWeightsGrams', message: 'لا يزيد على وزن الصندوق الفارغ'),
      );
    });

    test('حدود التحقق ورسائلها العربية مع الحقل الصحيح', () async {
      await expectLater(api.createPurchase(buy(boxes: 0)),
          throwsApi(ApiErrorCode.validation, field: 'boxes', message: '«عدد الصناديق» يجب أن يكون بين 1 و100000'));
      await expectLater(api.createPurchase(buy(boxes: 100001)), throwsApi(ApiErrorCode.validation, field: 'boxes'));
      await expectLater(api.createPurchase(buy(avgWeightGrams: 60001)),
          throwsApi(ApiErrorCode.validation, field: 'avgWeightGrams', message: 'و60 كغ'));
      await expectLater(api.createPurchase(buy(pricePerKgPiasters: 0)),
          throwsApi(ApiErrorCode.validation, field: 'pricePerKgPiasters', message: '1,000.00 ج.م'));
      await expectLater(api.createPurchase(buy(occurredAt: 'أمس')),
          throwsApi(ApiErrorCode.validation, field: 'occurredAt'));
      await expectLater(
        api.call('purchases.create', payload: {...buy().toJson(), 'boxes': 'خمسون'}, mutation: true),
        throwsApi(ApiErrorCode.validation, field: 'boxes', message: 'رقمًا صحيحًا'),
      );
      // الأرقام العربية في النص مقبولة كما في الخادم.
      final arabic = await api.call('purchases.create', payload: {...buy().toJson(), 'boxes': '٥٠'}, mutation: true);
      expect((arabic['purchase'] as Map)['boxes'], 50);
    });

    test('براد مقفّل ⇒ COOLER_CLOSED، ومزارع موقوف ⇒ VALIDATION، ومعرّف مجهول ⇒ NOT_FOUND', () async {
      await expectLater(
        api.createPurchase(buy(coolerId: 'CL-0012')),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', ApiErrorCode.coolerClosed)
            .having((e) => e.field, 'field', 'coolerId')
            .having((e) => e.details['coolerNo'], 'coolerNo', 12)),
      );
      await expectLater(api.createPurchase(buy(farmerId: 'FR-0013')),
          throwsApi(ApiErrorCode.validation, field: 'farmerId', message: 'موقوف'));
      await expectLater(api.createPurchase(buy(coolerId: 'CL-9999')), throwsApi(ApiErrorCode.notFound, field: 'coolerId'));
      await expectLater(api.createPurchase(buy(farmerId: 'FR-9999')), throwsApi(ApiErrorCode.notFound, field: 'farmerId'));
    });
  });

  group('purchases.update', () {
    test('تعديل الصناديق يعيد الحساب ويرفع الإصدار، والإصدار القديم ⇒ CONFLICT', () async {
      final created = (await api.createPurchase(buy())).purchase;
      final updated = await api.updatePurchase(id: created.id, expectedVersion: 1, changes: {'boxes': 60});
      expect(updated.boxes, 60);
      expect(updated.totalWeightGrams, 660000);
      expect(updated.valuePiasters, 990000);
      expect(updated.version, 2);
      expect(updated.updatedBy, 'محمد الحسناوي');

      await expectLater(
        api.updatePurchase(id: created.id, expectedVersion: 1, changes: {'boxes': 70}),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', ApiErrorCode.conflict)
            .having((e) => e.field, 'field', 'expectedVersion')
            .having((e) => e.details['currentVersion'], 'currentVersion', 2)
            .having((e) => (e.details['current'] as Map)['boxes'], 'current.boxes', 60)),
      );

      // دون تغيير فعلي لا يرتفع الإصدار.
      final same = await api.updatePurchase(id: created.id, expectedVersion: 2, changes: {'boxes': 60});
      expect(same.version, 2);
    });

    test('القيمة الجديدة أقل من المدفوع ⇒ VALIDATION على الحقل المعدّل', () async {
      final p = (await api.createPurchase(
              buy(payment: const PaymentModeInput(mode: PaymentMode.partial, amountPiasters: 800000))))
          .purchase;
      await expectLater(
        api.updatePurchase(id: p.id, expectedVersion: p.version, changes: {'boxes': 40}),
        throwsA(isA<ApiException>()
            .having((e) => e.field, 'field', 'boxes')
            .having((e) => e.details['paidPiasters'], 'paidPiasters', 800000)
            .having((e) => e.details['valuePiasters'], 'valuePiasters', 660000)),
      );
      await expectLater(
        api.updatePurchase(id: p.id, expectedVersion: p.version, changes: {'boxes': 49, 'pricePerKgPiasters': 1400}),
        throwsApi(ApiErrorCode.validation, field: 'pricePerKgPiasters'),
      );
    });

    test('تعديل عملية مستخدم آخر يحتاج editOthers، وعمليته هو مسموحة', () async {
      api.switchUser('US-0002'); // كريم: دون «تعديل عمليات الآخرين»
      final owners = await api.listPurchases(coolerId: 'CL-0014');
      final ownerPurchase = owners.firstWhere((p) => p.createdBy == 'محمد الحسناوي' && p.id == 'PU-0020');
      await expectLater(
        api.updatePurchase(id: ownerPurchase.id, expectedVersion: ownerPurchase.version, changes: {'notes': 'x'}),
        throwsApi(ApiErrorCode.forbidden, permission: 'editOthers'),
      );
      final mine = owners.firstWhere((p) => p.id == 'PU-0021');
      expect(mine.createdBy, 'كريم عبد الله');
      final edited = await api.updatePurchase(id: mine.id, expectedVersion: mine.version, changes: {'notes': 'وزن مؤكد'});
      expect(edited.notes, 'وزن مؤكد');
      expect(edited.updatedBy, 'كريم عبد الله');
    });

    test('براد مقفّل ⇒ COOLER_CLOSED، وتغيير المزارع مع دفعات ⇒ VALIDATION', () async {
      await expectLater(
        api.updatePurchase(id: 'PU-0012', expectedVersion: 1, changes: {'boxes': 30}),
        throwsApi(ApiErrorCode.coolerClosed, field: 'coolerId'),
      );
      final partial = (await api.listPurchases(coolerId: 'CL-0014')).firstWhere((p) => p.id == 'PU-0019');
      await expectLater(
        api.updatePurchase(id: partial.id, expectedVersion: partial.version, changes: {'farmerId': 'FR-0005'}),
        throwsApi(ApiErrorCode.validation, field: 'farmerId', message: 'ألغِ الدفعات أولًا'),
      );
      await expectLater(
        api.updatePurchase(id: 'PU-9999', expectedVersion: 1, changes: {'boxes': 1}),
        throwsApi(ApiErrorCode.notFound, field: 'id'),
      );
    });

    test('التحويل إلى العينة يتحقق من المتوسط', () async {
      final p = (await api.createPurchase(buy(avgWeightGrams: 10567))).purchase;
      await expectLater(
        api.updatePurchase(id: p.id, expectedVersion: 1, changes: {'weightMethod': 'sample'}),
        throwsApi(ApiErrorCode.validation, field: 'sampleWeightsGrams'),
      );
      final s = await api.updatePurchase(id: p.id, expectedVersion: 1, changes: {
        'weightMethod': 'sample',
        'sampleWeightsGrams': [12400, 12900, 12100],
      });
      expect(s.weightMethod, WeightMethod.sample);
      expect(s.tareGrams, 1900);
      expect(s.version, 2);
      final back = await api.updatePurchase(id: p.id, expectedVersion: 2, changes: {'weightMethod': 'direct'});
      expect(back.weightMethod, WeightMethod.direct);
      expect(back.sampleWeightsGrams, isEmpty);
      expect(back.tareGrams, isNull);
    });
  });

  group('purchases.cancel', () {
    test('مرفوض مع دفعات فعّالة؛ بعد إلغاء الدفعة يُلغى ويخرج من المجاميع', () async {
      final before = (await api.getCooler('CL-0014')).cooler;
      final target = (await api.listPurchases(coolerId: 'CL-0014')).firstWhere((p) => p.id == 'PU-0023');
      expect(target.paidPiasters, 200000);
      await expectLater(
        api.cancelPurchase(id: target.id, reason: 'خطأ في الوزن'),
        throwsA(isA<ApiException>()
            .having((e) => e.field, 'field', 'id')
            .having((e) => e.details['activePayments'], 'activePayments', 1)
            .having((e) => e.message, 'message', contains('ألغِ الدفعات أولًا'))),
      );

      final payment = (await api.listPayments(targetId: target.id)).single;
      final cancelledPay = await api.cancelPayment(id: payment.id, reason: 'سُجلت بالخطأ');
      expect(cancelledPay.payment.active, isFalse);
      expect(cancelledPay.payment.cancelReason, 'سُجلت بالخطأ');
      expect(cancelledPay.purchase!.paidPiasters, 0);
      expect(cancelledPay.purchase!.payStatus, PayStatus.unpaid);
      expect(cancelledPay.purchase!.version, target.version + 1);

      final cancelled = await api.cancelPurchase(id: target.id, reason: 'خطأ في الوزن');
      expect(cancelled.active, isFalse);
      expect(cancelled.cancelReason, 'خطأ في الوزن');
      expect(cancelled.remainingPiasters, 0);

      expect((await api.listPurchases(coolerId: 'CL-0014')).map((p) => p.id), isNot(contains(target.id)));
      expect((await api.listPurchases(coolerId: 'CL-0014', includeCancelled: true)).map((p) => p.id), contains(target.id));
      final after = (await api.getCooler('CL-0014')).cooler;
      expect(after.purchases, before.purchases - 1);
      expect(after.valuePiasters, before.valuePiasters - 441000);
      expect(after.paidPiasters, before.paidPiasters - 200000);
      expect(after.farmers, before.farmers, reason: 'حسن البدري له عملية أخرى فعّالة في البراد');
      final recent = (await api.dashboard()).recent.firstWhere((a) => a.id == target.id);
      expect(recent.status, 'cancelled');
      expect(recent.statusLabel, 'ملغاة');

      await expectLater(api.cancelPurchase(id: target.id, reason: 'مرة أخرى'),
          throwsApi(ApiErrorCode.validation, field: 'id', message: 'ملغاة بالفعل'));
      await expectLater(
        api.createPayment(targetType: PaymentTarget.purchase, targetId: target.id, amountPiasters: 100),
        throwsApi(ApiErrorCode.validation, field: 'targetId', message: 'ملغاة'),
      );
    });

    test('السبب مطلوب، والبراد المقفّل ⇒ COOLER_CLOSED', () async {
      final p = (await api.createPurchase(buy())).purchase;
      await expectLater(api.cancelPurchase(id: p.id, reason: '  '),
          throwsApi(ApiErrorCode.validation, field: 'reason', message: '«السبب» مطلوب'));
      await expectLater(api.cancelPurchase(id: 'PU-0012', reason: 'تجربة'), throwsApi(ApiErrorCode.coolerClosed));
      final ok = await api.cancelPurchase(id: p.id, reason: 'تجربة');
      expect(ok.version, 2);
    });
  });

  group('purchases.list', () {
    test('التصفية بالبراد والمزارع والفترة، والأحدث أولًا', () async {
      final hassan = await api.listPurchases(farmerId: 'FR-0003');
      expect(hassan.map((p) => p.id), ['PU-0023', 'PU-0020', 'PU-0013', 'PU-0004']);
      expect(await api.listPurchases(coolerId: 'CL-0013'), hasLength(3));
      expect(await api.listPurchases(from: '2026-10-02', to: '2026-10-02'), hasLength(6));
      expect(await api.listPurchases(from: '2026-10-01', to: '2026-10-01'), hasLength(3));
      expect(await api.listPurchases(from: '2026-10-02T09:00:00', coolerId: 'CL-0014'), hasLength(3));
      await expectLater(api.listPurchases(from: '2026-10-03', to: '2026-10-01'), throwsApi(ApiErrorCode.validation, field: 'to'));
      await expectLater(api.listPurchases(from: 'أمس'), throwsApi(ApiErrorCode.validation, field: 'from'));
    });
  });
}
