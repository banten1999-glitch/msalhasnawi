import 'package:flutter_test/flutter_test.dart';
import 'package:rumman_calculator/core/api/api_exception.dart';
import 'package:rumman_calculator/core/api/demo_backend_api.dart';
import 'package:rumman_calculator/core/models/records.dart';

import 'demo_support.dart';

void main() {
  late DemoBackendApi api;

  setUp(() async => api = await signedInDemo());

  group('payments.create / payments.cancel', () {
    test('المدفوع والمتبقي وحالة الدفع محسوبة من الدفعات الفعّالة فقط', () async {
      // PU-0021: 24 × 11 كغ × 13.50 = 3,564.00 ج.م، غير مدفوعة.
      final start = (await api.listPurchases(coolerId: 'CL-0014')).firstWhere((p) => p.id == 'PU-0021');
      expect(start.valuePiasters, 356400);
      expect(start.payStatus, PayStatus.unpaid);
      final coolerBefore = (await api.getCooler('CL-0014')).cooler;

      final first = await api.createPayment(
          targetType: PaymentTarget.purchase, targetId: 'PU-0021', amountPiasters: 100000, method: PaymentMethod.wallet);
      expect(first.payment.amountPiasters, 100000);
      expect(first.payment.payeeName, 'الحاج محمود عبد العال');
      expect(first.payment.payeeId, 'FR-0004');
      expect(first.payment.coolerNo, 14);
      expect(first.payment.paidAt, isoLocal(demoNow));
      expect(first.purchase!.paidPiasters, 100000);
      expect(first.purchase!.remainingPiasters, 256400);
      expect(first.purchase!.payStatus, PayStatus.partial);
      expect(first.purchase!.version, start.version + 1, reason: 'تحديث أعمدة المدفوع يرفع إصدار العملية');

      await expectLater(
        api.createPayment(targetType: PaymentTarget.purchase, targetId: 'PU-0021', amountPiasters: 256401),
        throwsA(isA<ApiException>()
            .having((e) => e.field, 'field', 'amountPiasters')
            .having((e) => e.details['remainingPiasters'], 'remainingPiasters', 256400)
            .having((e) => e.message, 'message', contains('2,564.00 ج.م'))),
      );
      final second = await api.createPayment(
          targetType: PaymentTarget.purchase, targetId: 'PU-0021', amountPiasters: 256400, paidAt: '2026-10-02T10:30:00');
      expect(second.purchase!.payStatus, PayStatus.paid);
      expect(second.purchase!.remainingPiasters, 0);
      expect(DateTime.parse(second.payment.paidAt).isAtSameMomentAs(DateTime(2026, 10, 2, 10, 30)), isTrue);
      await expectLater(
        api.createPayment(targetType: PaymentTarget.purchase, targetId: 'PU-0021', amountPiasters: 1),
        throwsA(isA<ApiException>()
            .having((e) => e.field, 'field', 'amountPiasters')
            .having((e) => e.details['remainingPiasters'], 'remainingPiasters', 0)
            .having((e) => e.message, 'message', contains('مدفوعة بالكامل'))),
      );

      final cancelled = await api.cancelPayment(id: first.payment.id, reason: 'مبلغ خاطئ');
      expect(cancelled.payment.active, isFalse);
      expect(cancelled.payment.version, 2);
      expect(cancelled.purchase!.paidPiasters, 256400);
      expect(cancelled.purchase!.payStatus, PayStatus.partial);
      await expectLater(api.cancelPayment(id: first.payment.id, reason: 'مرة أخرى'),
          throwsApi(ApiErrorCode.validation, field: 'id', message: 'ملغاة بالفعل'));
      await expectLater(api.cancelPayment(id: second.payment.id, reason: ''), throwsApi(ApiErrorCode.validation, field: 'reason'));

      final listed = await api.listPayments(targetId: 'PU-0021');
      expect(listed, hasLength(2), reason: 'القائمة تضم الملغاة');
      expect(listed.where((p) => p.active).map((p) => p.amountPiasters), [256400]);
      final coolerAfter = (await api.getCooler('CL-0014')).cooler;
      expect(coolerAfter.paidPiasters, coolerBefore.paidPiasters + 256400);
      expect(coolerAfter.remainingPiasters, coolerBefore.remainingPiasters - 256400);
    });

    test('الدفع مسموح على براد مقفّل، ولا يغيّر لقطة التقفيل', () async {
      final before = (await api.getCooler('CL-0012')).cooler;
      expect(before.isOpen, isFalse);
      final r = await api.createPayment(targetType: PaymentTarget.purchase, targetId: 'PU-0012', amountPiasters: 632800);
      expect(r.payment.coolerNo, 12);
      expect(r.purchase!.payStatus, PayStatus.paid);
      final after = (await api.getCooler('CL-0012')).cooler;
      expect(after.paidPiasters, 8854850 + 632800);
      expect(after.closeSnapshot!.paidPiasters, before.closeSnapshot!.paidPiasters);
      expect(after.closeSnapshot!.paidPiasters, 7528550);
    });

    test('دفعات التعبئة: المعتمد فقط، والمستفيد هو المورد', () async {
      await expectLater(
        api.createPayment(targetType: PaymentTarget.packaging, targetId: 'PK-0004', amountPiasters: 1000),
        throwsApi(ApiErrorCode.validation, field: 'targetId', message: 'ما زال مسودة'),
      );
      final r = await api.createPayment(targetType: PaymentTarget.packaging, targetId: 'PK-0003', amountPiasters: 150000);
      expect(r.payment.payeeType, PayeeType.supplier);
      expect(r.payment.payeeName, 'مؤسسة النيل للكرتون');
      expect(r.payment.payeeId, isNull);
      expect(r.packaging!.paidPiasters, 450000);
      expect(r.packaging!.remainingPiasters, 0);
      await expectLater(
        api.createPayment(targetType: PaymentTarget.packaging, targetId: 'PK-0003', amountPiasters: 1),
        throwsApi(ApiErrorCode.validation, field: 'amountPiasters'),
      );
      await expectLater(
        api.createPayment(targetType: PaymentTarget.packaging, targetId: 'PK-9999', amountPiasters: 1),
        throwsApi(ApiErrorCode.notFound, field: 'targetId'),
      );
      await expectLater(
        api.createPayment(targetType: PaymentTarget.purchase, targetId: 'PU-0021', amountPiasters: 0),
        throwsApi(ApiErrorCode.validation, field: 'amountPiasters'),
      );
      expect((await api.dashboard()).kpis.remainingSuppliersPiasters, 45500, reason: 'تبقى التعبئة المتأخرة للبراد 12');
    });

    test('نفس requestId ⇒ دفعة واحدة، حتى بعد انتهاء ذاكرة الطلبات', () async {
      Future<PaymentResult> pay() => api.createPayment(
          targetType: PaymentTarget.purchase, targetId: 'PU-0021', amountPiasters: 1000, requestId: 'pay-1');
      final a = await pay();
      final b = await pay();
      api.forgetRequestCache();
      final c = await api.call('payments.create',
          payload: {'targetType': 'purchase', 'targetId': 'PU-0021', 'amountPiasters': 1000, 'method': 'cash'},
          mutation: true,
          requestId: 'pay-1');
      expect(b.payment.id, a.payment.id);
      expect(c['replayed'], isTrue);
      expect((c['payment'] as Map)['id'], a.payment.id);
      expect(await api.listPayments(targetId: 'PU-0021'), hasLength(1));
    });

    test('التصفية بالعملية والمستفيد والبراد، والصلاحية recordPayments', () async {
      expect((await api.listPayments(payeeId: 'FR-0001')).map((p) => p.targetId), ['PU-0018']);
      expect(await api.listPayments(coolerId: 'CL-0013'), hasLength(2));
      expect((await api.listPayments(targetId: 'PK-0001')).single.amountPiasters, 1451500);
      final all = await api.listPayments();
      expect(all, hasLength(22));
      expect(all.first.id, 'PY-0022');

      api.switchUser('US-0004'); // مشاهدة فقط
      await expectLater(
        api.createPayment(targetType: PaymentTarget.purchase, targetId: 'PU-0021', amountPiasters: 100),
        throwsApi(ApiErrorCode.forbidden, permission: 'recordPayments'),
      );
    });
  });

  group('التعبئة والتغليف', () {
    test('بيانات البداية: أصناف التعبئة التسعة، ومسودة ناقصة، ومعتمد عليه دفعة جزئية', () async {
      final types = await api.listItemTypes();
      expect(types.map((t) => t.name), [
        'الصناديق', 'الباليتات', 'الشمبر', 'جزاري «ورق الفاصل»', 'المناديل', 'غطاء باليت', 'الملصقات', 'جهاز تجسس',
        'السترتش',
      ]);
      expect(types.map((t) => t.unit), ['قطعة', 'قطعة', 'رزمة', 'رزمة', 'كرتونة', 'قطعة', 'رول', 'قطعة', 'لفة']);

      final draft = await api.getPackaging('PK-0004');
      expect(draft.packaging.status, PackagingStatus.draft);
      expect(draft.packaging.itemsCount, 4);
      expect(draft.packaging.incompleteCount, 2);
      expect(draft.packaging.completeTotalPiasters, 258000);
      final cover = draft.items.firstWhere((i) => i.name == 'غطاء باليت');
      expect(cover.quantity, 12);
      expect(cover.unitPricePiasters, isNull);
      expect(cover.totalPiasters, isNull);
      expect(cover.status, PackagingItemStatus.incomplete);
      final labels = draft.items.firstWhere((i) => i.name == 'الملصقات');
      expect(labels.quantity, isNull);
      expect(labels.unit, 'رول');

      final partial = await api.getPackaging('PK-0003');
      expect(partial.packaging.status, PackagingStatus.approved);
      expect(partial.packaging.completeTotalPiasters, 450000);
      expect(partial.packaging.paidPiasters, 300000);
      expect(partial.packaging.remainingPiasters, 150000);
      expect(partial.items.fold<int>(0, (s, i) => s + i.totalPiasters!), 450000);

      final first = await api.getPackaging('PK-0001');
      expect(first.items, hasLength(4));
      expect(first.packaging.completeTotalPiasters, 1451500);
      expect(first.packaging.remainingPiasters, 0);
      expect((await api.getPackaging('PK-0002')).packaging.late, isTrue);
    });

    test('شراء تدريجي: مسودة بخانات فارغة ← إكمال وحذف وإضافة ← اعتماد ← دفعة ← إلغاء', () async {
      final cooler = (await api.getCooler('CL-0014')).cooler;
      final draft = await api.savePackaging(const PackagingDraftInput(
        supplier: 'الوادي للتغليف',
        coolerId: 'CL-0014',
        items: [
          PackagingItem(name: 'الصناديق', quantity: 100, unit: 'قطعة'),
          PackagingItem(name: 'السترتش', unit: 'لفة', unitPricePiasters: 21000),
          PackagingItem(name: 'الباليتات', quantity: 10, unit: 'قطعة', unitPricePiasters: 14500),
        ],
      ));
      final pk = draft.packaging;
      expect(pk.id, 'PK-0005');
      expect(pk.no, 'P-0005');
      expect(pk.status, PackagingStatus.draft);
      expect(pk.itemsCount, 3);
      expect(pk.incompleteCount, 2);
      expect(pk.completeTotalPiasters, 145000);
      expect(pk.version, 1);
      expect(draft.items[0].quantity, 100);
      expect(draft.items[0].unitPricePiasters, isNull, reason: 'السعر الفارغ يبقى فارغًا، لا صفرًا');
      expect(draft.items[1].quantity, isNull);
      expect(draft.items.map((i) => i.status),
          [PackagingItemStatus.incomplete, PackagingItemStatus.incomplete, PackagingItemStatus.complete]);

      await expectLater(
        api.approvePackaging(id: pk.id, expectedVersion: 1),
        throwsA(isA<ApiException>()
            .having((e) => e.field, 'field', 'items')
            .having((e) => e.details['incomplete'], 'incomplete', [draft.items[0].id, draft.items[1].id])
            .having((e) => e.message, 'message', contains('2 صنف غير مكتمل'))),
      );

      // الإكمال: القائمة كاملة؛ الباليتات غير مرسلة ⇒ «محذوف»، والمناديل صنف جديد.
      final filled = await api.savePackaging(PackagingDraftInput(
        id: pk.id,
        expectedVersion: 1,
        invoiceNo: 'V-131',
        items: [
          PackagingItem(id: draft.items[0].id, name: 'الصناديق', quantity: 100, unit: 'قطعة', unitPricePiasters: 1800),
          PackagingItem(id: draft.items[1].id, name: 'السترتش', quantity: 4, unit: 'لفة', unitPricePiasters: 21000),
          const PackagingItem(name: 'المناديل', quantity: 5, unit: 'كرتونة', unitPricePiasters: 6000),
        ],
      ));
      expect(filled.packaging.version, 2);
      expect(filled.packaging.invoiceNo, 'V-131');
      expect(filled.packaging.supplier, 'الوادي للتغليف', reason: 'الحقل غير المرسل يبقى كما هو');
      expect(filled.packaging.itemsCount, 3);
      expect(filled.packaging.incompleteCount, 0);
      expect(filled.packaging.completeTotalPiasters, 180000 + 84000 + 30000);
      expect(filled.items.map((i) => i.name), ['الصناديق', 'السترتش', 'المناديل']);
      expect(filled.items.every((i) => i.status == PackagingItemStatus.complete), isTrue);
      expect((await api.getPackaging(pk.id)).items.map((i) => i.id), isNot(contains(draft.items[2].id)));

      await expectLater(
        api.savePackaging(PackagingDraftInput(id: pk.id, expectedVersion: 1, items: filled.items)),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', ApiErrorCode.conflict)
            .having((e) => e.details['currentVersion'], 'currentVersion', 2)
            .having((e) => (e.details['items'] as List).length, 'items', 3)),
      );
      await expectLater(api.approvePackaging(id: pk.id, expectedVersion: 1), throwsApi(ApiErrorCode.conflict));

      final approved = await api.approvePackaging(id: pk.id, expectedVersion: 2);
      expect(approved.packaging.status, PackagingStatus.approved);
      expect(approved.packaging.late, isFalse);
      expect(approved.packaging.version, 3);
      expect(approved.packaging.remainingPiasters, 294000);
      expect((await api.getCooler('CL-0014')).cooler.packagingApprovedPiasters, cooler.packagingApprovedPiasters + 294000);
      expect((await api.dashboard()).kpis.packagingApprovedPiasters, 450000 + 1497000 + 294000);

      await expectLater(
        api.savePackaging(PackagingDraftInput(id: pk.id, expectedVersion: 3, items: filled.items)),
        throwsApi(ApiErrorCode.validation, field: 'id', message: 'معتمد'),
      );
      await expectLater(api.approvePackaging(id: pk.id, expectedVersion: 3),
          throwsApi(ApiErrorCode.validation, field: 'id', message: 'معتمد بالفعل'));

      final pay = await api.createPayment(targetType: PaymentTarget.packaging, targetId: pk.id, amountPiasters: 100000);
      expect(pay.packaging!.paidPiasters, 100000);
      expect(pay.packaging!.version, 4);
      await expectLater(
        api.cancelPackaging(id: pk.id, reason: 'فاتورة مكررة'),
        throwsA(isA<ApiException>()
            .having((e) => e.field, 'field', 'id')
            .having((e) => e.details['activePayments'], 'activePayments', 1)),
      );
      await api.cancelPayment(id: pay.payment.id, reason: 'فاتورة مكررة');
      final cancelled = await api.cancelPackaging(id: pk.id, reason: 'فاتورة مكررة');
      expect(cancelled.status, PackagingStatus.cancelled);
      expect(cancelled.remainingPiasters, 0);
      expect(cancelled.notes, contains('سبب الإلغاء: فاتورة مكررة'));
      expect((await api.getCooler('CL-0014')).cooler.packagingApprovedPiasters, cooler.packagingApprovedPiasters);
      await expectLater(api.cancelPackaging(id: pk.id, reason: 'x'), throwsApi(ApiErrorCode.validation, field: 'id'));
      await expectLater(
        api.createPayment(targetType: PaymentTarget.packaging, targetId: pk.id, amountPiasters: 1),
        throwsApi(ApiErrorCode.validation, field: 'targetId', message: 'ملغى'),
      );
    });

    test('الاعتماد على براد مقفّل ⇒ تكلفة متأخرة', () async {
      final d = await api.savePackaging(const PackagingDraftInput(
        supplier: 'الوادي للتغليف',
        coolerId: 'CL-0012',
        items: [PackagingItem(name: 'جهاز تجسس', quantity: 1, unit: 'قطعة', unitPricePiasters: 35000)],
      ));
      final a = await api.approvePackaging(id: d.packaging.id, expectedVersion: d.packaging.version);
      expect(a.packaging.late, isTrue);
      final c = (await api.getCooler('CL-0012')).cooler;
      expect(c.packagingLatePiasters, 45500 + 35000);
      expect(c.closeSnapshot!.packagingPiasters, 1451500);
    });

    test('لا اعتماد بدون أصناف، والتحقق من كل صنف بحقله', () async {
      final empty = await api.savePackaging(const PackagingDraftInput(supplier: 'مورد', items: []));
      expect(empty.packaging.coolerId, isNull);
      expect(empty.packaging.coolerNo, isNull);
      await expectLater(api.approvePackaging(id: empty.packaging.id, expectedVersion: 1),
          throwsApi(ApiErrorCode.validation, field: 'items', message: 'بدون أصناف'));

      await expectLater(
        api.savePackaging(const PackagingDraftInput(items: [PackagingItem(name: 'الصناديق', unit: 'علبة')])),
        throwsApi(ApiErrorCode.validation, field: 'items[0].unit', message: 'غير معروفة'),
      );
      await expectLater(
        api.savePackaging(const PackagingDraftInput(items: [
          PackagingItem(name: 'الصناديق', unit: 'قطعة'),
          PackagingItem(name: 'الباليتات', unit: 'قطعة', quantity: 0),
        ])),
        throwsApi(ApiErrorCode.validation, field: 'items[1].quantity'),
      );
      await expectLater(
        api.savePackaging(const PackagingDraftInput(items: [PackagingItem(name: ' ', unit: 'قطعة')])),
        throwsApi(ApiErrorCode.validation, field: 'items[0].name'),
      );
      // صنف من شراء آخر لا يُقبل في هذه المسودة.
      await expectLater(
        api.savePackaging(const PackagingDraftInput(
            id: 'PK-0004', expectedVersion: 1, items: [PackagingItem(id: 'PD-0001', name: 'الصناديق', unit: 'قطعة')])),
        throwsApi(ApiErrorCode.validation, field: 'items[0].id', message: 'لا يتبع هذا الشراء'),
      );
      await expectLater(
        api.savePackaging(const PackagingDraftInput(coolerId: 'CL-9999', items: [])),
        throwsApi(ApiErrorCode.notFound, field: 'coolerId'),
      );
      expect(await api.listPackaging(), hasLength(5), reason: 'الأخطاء لا تترك سجلات');
    });

    test('الإنشاء بنفس requestId ⇒ مسودة واحدة', () async {
      const input = PackagingDraftInput(supplier: 'مورد', items: [PackagingItem(name: 'الصناديق', unit: 'قطعة')]);
      final a = await api.savePackaging(input, requestId: 'pk-1');
      final b = await api.savePackaging(input, requestId: 'pk-1');
      api.forgetRequestCache();
      final c = await api.call('packaging.save', payload: input.toJson(), mutation: true, requestId: 'pk-1');
      expect(b.packaging.id, a.packaging.id);
      expect(c['replayed'], isTrue);
      expect((c['packaging'] as Map)['id'], a.packaging.id);
      expect(await api.listPackaging(), hasLength(5));
    });

    test('القائمة بالحالة والبراد، والصلاحية packaging', () async {
      expect((await api.listPackaging(status: 'draft')).map((p) => p.id), ['PK-0004']);
      expect((await api.listPackaging(coolerId: 'CL-0012')).map((p) => p.id), ['PK-0002', 'PK-0001']);
      expect((await api.listPackaging(status: 'approved', coolerId: 'CL-0014')).map((p) => p.id), ['PK-0003']);
      expect(await api.listPackaging(status: 'all'), hasLength(4));
      await expectLater(api.listPackaging(status: 'open'), throwsApi(ApiErrorCode.validation, field: 'status'));
      await expectLater(api.getPackaging('PK-9999'), throwsApi(ApiErrorCode.notFound, field: 'id'));
      final detail = await api.getCooler('CL-0014');
      expect(detail.packaging.map((p) => p.id), ['PK-0004', 'PK-0003']);

      api.switchUser('US-0003'); // يوسف: دون «مشتريات التعبئة»
      expect(await api.listPackaging(), hasLength(4), reason: 'القراءة تحتاج عرض البيانات فقط');
      await expectLater(
        api.savePackaging(const PackagingDraftInput(items: [])),
        throwsApi(ApiErrorCode.forbidden, permission: 'packaging'),
      );
    });
  });

  group('itemTypes.save', () {
    test('إضافة وتعديل، والاسم المكرر أو الوحدة المجهولة ⇒ VALIDATION', () async {
      final t = await api.saveItemType(name: 'شريط لاصق', unit: 'لفة');
      expect(t.id, 'IT-0010');
      expect(t.order, 10);
      expect(t.active, isTrue);
      expect((await api.listItemTypes()).last.name, 'شريط لاصق');

      await expectLater(api.saveItemType(name: '  الصناديق ', unit: 'قطعة'),
          throwsApi(ApiErrorCode.validation, field: 'name', message: 'يوجد صنف بالاسم «الصناديق»'));
      await expectLater(api.saveItemType(name: 'فلين', unit: 'لوح'), throwsApi(ApiErrorCode.validation, field: 'unit'));
      await expectLater(api.saveItemType(id: 'IT-9999', name: 'x', unit: 'قطعة'), throwsApi(ApiErrorCode.notFound, field: 'id'));

      final off = await api.saveItemType(id: 'IT-0005', name: 'المناديل', unit: 'كرتونة', active: false, order: 20);
      expect(off.active, isFalse);
      expect(off.order, 20);
      final list = await api.listItemTypes();
      expect(list.last.id, 'IT-0005');
      expect(list, hasLength(10));

      api.switchUser('US-0002');
      await expectLater(api.saveItemType(name: 'جديد', unit: 'قطعة'),
          throwsApi(ApiErrorCode.forbidden, permission: 'manageSettings'));
    });
  });
}
