import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumman_calculator/core/api/api_exception.dart';
import 'package:rumman_calculator/core/models/records.dart';
import 'package:rumman_calculator/core/sync/data_changes.dart';
import 'package:rumman_calculator/core/sync/outbox.dart';
import 'package:rumman_calculator/features/coolers/purchase_form_screen.dart';
import 'package:rumman_calculator/ui/labeled_field.dart';

import '../../support/fake_backend_api.dart';
import '../../support/sample_data.dart';
import '../../support/test_app.dart';
import 'coolers_test_support.dart';

const _avgLabel = 'المتوسط الصافي (كغ)';
const _boxesLabel = 'عدد الصناديق';
const _priceLabel = 'سعر الكيلو (ج.م)';

Future<void> _openForm(
  WidgetTester tester,
  FakeBackendApi api, {
  Size size = phoneSize,
  DataChanges? changes,
  Outbox? outbox,
}) =>
    pumpPage(
      tester,
      const PurchaseFormScreen(coolerId: 'CL-0014'),
      api: api,
      size: size,
      changes: changes,
      outbox: outbox,
    );

Future<void> _pickFarmer(WidgetTester tester, String query, String name) async {
  await tester.enterText(fieldIn('المزارع'), query);
  await tester.pumpAndSettle();
  await tapVisible(tester, find.text(name));
}

Future<void> _fillBasics(WidgetTester tester, {String boxes = '50', String avg = '11', String price = '15'}) async {
  await typeInto(tester, _boxesLabel, boxes);
  await typeInto(tester, _avgLabel, avg);
  await typeInto(tester, _priceLabel, price);
  await tester.pumpAndSettle();
}

Future<void> _tapSave(WidgetTester tester, [String label = 'حفظ']) async {
  final f = find.widgetWithText(FilledButton, label).hitTestable();
  await tester.tap(f.evaluate().isEmpty ? find.text(label).last : f.first);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  for (final size in [phoneSize, wideSize]) {
    final where = size == phoneSize ? 'الهاتف' : 'الشاشة العريضة';

    testWidgets('الحساب الحي: 50 صندوق × 11 كغ × 15 ج.م = 550 كغ و8,250.00 ج.م ($where)', (tester) async {
      final api = coolersApi();
      await _openForm(tester, api, size: size);

      // البراد المطلوب مختار، والقيمة فارغة قبل الكتابة.
      expect(find.text('براد 14 · شحنة دمياط'), findsWidgets);
      expect(find.text('تظهر القيمة فور كتابة عدد الصناديق ومتوسط الوزن وسعر الكيلو.'), findsOneWidget);

      await _fillBasics(tester);
      expect(findRichText('550 كغ'), findsWidgets);
      expect(findRichText('8,250.00 ج.م'), findsWidgets);
      expect(find.text('50 صندوق × 11 كغ'), findsOneWidget);
      expect(find.text('550 كغ × 15.00 ج.م/كغ'), findsOneWidget);
      // «لم يُدفع بعد» افتراضيًا: المتبقي = القيمة.
      expect(findRichText('المتبقي للمزارع بعد هذه العملية: 8,250.00 ج.م'), findsOneWidget);
    });

    testWidgets('الحفظ يرسل purchases.create بالأرقام الصحيحة ويعود ($where)', (tester) async {
      final api = coolersApi();
      final changes = DataChanges();
      var bumps = 0;
      changes.addListener(() => bumps++);
      await _openForm(tester, api, size: size, changes: changes);

      await _pickFarmer(tester, 'حسن', 'حسن البدري');
      await _fillBasics(tester);
      await _tapSave(tester);

      final call = api.callsOf('purchases.create').single;
      expect(call.payload, {
        'coolerId': 'CL-0014',
        'farmerId': 'FR-0001',
        'boxes': 50,
        'avgWeightGrams': 11000,
        'weightMethod': 'direct',
        'pricePerKgPiasters': 1500,
        'payment': {'mode': 'none'},
      });
      expect(call.requestId, isNotNull);
      expect(bumps, 1);
      expect(find.text('تم الحفظ في الملف'), findsOneWidget);
      expect(find.text('الصفحة السابقة'), findsOneWidget);
    });
  }

  testWidgets('الأرقام العربية مقبولة: «٥٠» صندوق × «١١» كغ × «١٥» ج.م', (tester) async {
    final api = coolersApi();
    await _openForm(tester, api);
    await _pickFarmer(tester, 'حسن', 'حسن البدري');
    await _fillBasics(tester, boxes: '٥٠', avg: '١٠٫٥', price: '١٥٫٢٥');

    // 50 × 10.5 = 525 كغ؛ 525 × 15.25 = 8,006.25
    expect(findRichText('525 كغ'), findsWidgets);
    expect(findRichText('8,006.25 ج.م'), findsWidgets);

    await _tapSave(tester);
    final p = api.callsOf('purchases.create').single.payload;
    expect(p['boxes'], 50);
    expect(p['avgWeightGrams'], 10500);
    expect(p['pricePerKgPiasters'], 1525);
  });

  testWidgets('حساب المتوسط من عينة: round(متوسط القائم − الفارغ) ويُرسل مع العينة', (tester) async {
    final api = coolersApi();
    await _openForm(tester, api);
    await _pickFarmer(tester, 'حسن', 'حسن البدري');
    await typeInto(tester, _boxesLabel, '50');
    await tapVisible(tester, find.text('حساب من عينة'));

    // الفارغ الافتراضي من الإعدادات (1.9 كغ).
    expect(find.text('الافتراضي من الإعدادات: 1.9 كغ.'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'وزن الصندوق 1 (كغ)'), '12.9');
    await tester.pump();
    await tapVisible(tester, find.text('إضافة وزن صندوق'));
    await tester.enterText(find.widgetWithText(TextField, 'وزن الصندوق 2 (كغ)'), '١٣٫١');
    await tester.pumpAndSettle();

    // (12.9 + 13.1) / 2 − 1.9 = 11.1 كغ
    expect(findRichText('11.1 كغ'), findsWidgets);
    expect(find.text('متوسط القائم 13 كغ من 2 صناديق − الفارغ 1.9 كغ'), findsOneWidget);
    await typeInto(tester, _priceLabel, '15');
    await tester.pumpAndSettle();
    // 50 × 11.1 = 555 كغ × 15 = 8,325.00
    expect(findRichText('555 كغ'), findsWidgets);
    expect(findRichText('8,325.00 ج.م'), findsWidgets);

    // تغيير الفارغ يعيد الحساب فورًا: 13 − 2 = 11
    await typeInto(tester, 'وزن الصندوق الفارغ (كغ)', '2');
    await tester.pumpAndSettle();
    expect(findRichText('8,250.00 ج.م'), findsWidgets);

    await _tapSave(tester);
    final p = api.callsOf('purchases.create').single.payload;
    expect(p['weightMethod'], 'sample');
    expect(p['sampleWeightsGrams'], [12900, 13100]);
    expect(p['tareGrams'], 2000);
    expect(p['avgWeightGrams'], 11000);
  });

  testWidgets('الدفع الجزئي: المبلغ مطلوب وأقل من القيمة، ولا يُرسل شيء قبل التصحيح', (tester) async {
    final api = coolersApi();
    await _openForm(tester, api);
    await _pickFarmer(tester, 'حسن', 'حسن البدري');
    await _fillBasics(tester);

    await tapVisible(tester, find.text('دفع جزئي'));
    await _tapSave(tester);
    expect(find.text('«المبلغ المدفوع» مطلوب في الدفع الجزئي. اكتب المبلغ المدفوع الآن.'), findsOneWidget);
    expect(api.count('purchases.create'), 0);

    await typeInto(tester, 'المبلغ المدفوع الآن (ج.م)', '8250');
    await tester.pumpAndSettle();
    expect(
      find.textContaining('يجب أن يكون أقل من قيمة العملية (8,250.00 ج.م) في الدفع الجزئي'),
      findsOneWidget,
    );
    await _tapSave(tester);
    expect(api.count('purchases.create'), 0);

    await typeInto(tester, 'المبلغ المدفوع الآن (ج.م)', '5000');
    await tester.pumpAndSettle();
    expect(findRichText('المتبقي للمزارع بعد هذه العملية: 3,250.00 ج.م'), findsOneWidget);
    await tapVisible(tester, find.text('تحويل بنكي'));
    await _tapSave(tester);
    expect(api.callsOf('purchases.create').single.payload['payment'], {
      'mode': 'partial',
      'amountPiasters': 500000,
      'method': 'bank',
    });
  });

  testWidgets('الحقول المطلوبة تظهر أخطاؤها عند الحفظ', (tester) async {
    final api = coolersApi();
    await _openForm(tester, api);
    await _tapSave(tester);
    expect(find.text('«المزارع» مطلوب. اكتب اسمه أو رقمه واختره من القائمة.'), findsOneWidget);
    expect(find.text('«عدد الصناديق» مطلوب. اكتب عدد الصناديق، مثل 50.'), findsOneWidget);
    expect(api.count('purchases.create'), 0);

    // حدود الخادم: الصناديق 1…100000، والكسور مرفوضة.
    await typeInto(tester, _boxesLabel, '100001');
    expect(find.text('«عدد الصناديق» يجب أن يكون بين 1 و100,000.'), findsOneWidget);
    await typeInto(tester, _boxesLabel, '50.5');
    expect(find.text('«عدد الصناديق» يجب أن يكون رقمًا صحيحًا دون كسور، مثل 50.'), findsOneWidget);
    await typeInto(tester, _avgLabel, '61');
    expect(find.text('«متوسط الوزن الصافي للصندوق» يجب أن يكون بين 0.001 و60 كغ.'), findsOneWidget);
    await typeInto(tester, _priceLabel, '1000.01');
    expect(find.text('«سعر الكيلو» يجب أن يكون بين 0.01 و1,000.00 ج.م.'), findsOneWidget);
  });

  testWidgets('الضغط مرتين بسرعة يرسل purchases.create مرة واحدة', (tester) async {
    final api = coolersApi();
    await _openForm(tester, api);
    await _pickFarmer(tester, 'حسن', 'حسن البدري');
    await _fillBasics(tester);

    api.delay = const Duration(milliseconds: 400);
    final at = tester.getCenter(find.widgetWithText(FilledButton, 'حفظ'));
    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 10));
    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.text('جارٍ الحفظ'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(api.count('purchases.create'), 1);
  });

  testWidgets('دون اتصال: تُحفظ على الجهاز «بانتظار المزامنة» ويُعامل النموذج كمحفوظ', (tester) async {
    final api = coolersApi();
    api.errors['purchases.create'] = const ApiException(ApiErrorCode.network, 'لا يوجد اتصال بالإنترنت.');
    final outbox = Outbox(api: api, storage: MemoryOutboxStorage(), retryInterval: const Duration(hours: 1));
    await outbox.bindUser(sampleAdmin().email);
    final changes = DataChanges();
    var bumps = 0;
    changes.addListener(() => bumps++);
    await _openForm(tester, api, outbox: outbox, changes: changes);

    await _pickFarmer(tester, 'حسن', 'حسن البدري');
    await _fillBasics(tester);
    await _tapSave(tester);

    expect(find.text('حُفظت على الجهاز — بانتظار المزامنة'), findsOneWidget);
    expect(find.text('الصفحة السابقة'), findsOneWidget);
    expect(bumps, 1);
    expect(outbox.pendingCount, 1);
    expect(outbox.pendingForCooler('CL-0014'), 1);
    final entry = outbox.entries.single;
    expect(entry.label, 'شراء · حسن البدري · 50 صندوق');
    expect(entry.requestId, api.callsOf('purchases.create').single.requestId);

    await tester.pumpWidget(const SizedBox());
    outbox.dispose();
  });

  testWidgets('دون قائمة مزامنة مربوطة: خطأ الاتصال يظهر وتبقى البيانات بالمعرّف نفسه لإعادة المحاولة', (tester) async {
    final api = coolersApi();
    api.errors['purchases.create'] = const ApiException(ApiErrorCode.network, 'لا يوجد اتصال بالإنترنت.');
    await _openForm(tester, api);
    await _pickFarmer(tester, 'حسن', 'حسن البدري');
    await _fillBasics(tester);
    await _tapSave(tester);

    expect(find.text('لم تُحفظ العملية'), findsOneWidget);
    expect(find.text('لا يوجد اتصال بالإنترنت.'), findsOneWidget);
    expect(find.text('تم الحفظ في الملف'), findsNothing);

    api.errors.remove('purchases.create');
    await _tapSave(tester);
    final ids = api.callsOf('purchases.create').map((c) => c.requestId).toSet();
    expect(ids, hasLength(1));
    expect(find.text('تم الحفظ في الملف'), findsOneWidget);
  });

  testWidgets('«حفظ وإضافة مزارع آخر» يُبقي البراد والسعر ويمسح المزارع والصناديق', (tester) async {
    final api = coolersApi();
    await _openForm(tester, api);
    await _pickFarmer(tester, 'حسن', 'حسن البدري');
    await _fillBasics(tester);
    await typeInto(tester, 'ملاحظات (اختياري)', 'صناديق بلاستيك');
    await tapVisible(tester, find.text('دفع جزئي'));
    await typeInto(tester, 'المبلغ المدفوع الآن (ج.م)', '1000');
    await tapVisible(tester, find.text('محفظة إلكترونية'));
    await _tapSave(tester, 'حفظ وإضافة مزارع آخر');

    expect(api.count('purchases.create'), 1);
    expect(find.text('تم الحفظ في الملف'), findsOneWidget);
    // ما زلنا في النموذج نفسه.
    expect(find.text('الصفحة السابقة'), findsNothing);
    TextField tf(String label) => tester.widget<TextField>(fieldIn(label));
    expect(tf(_boxesLabel).controller!.text, '');
    expect(tf(_avgLabel).controller!.text, '');
    expect(tf(_priceLabel).controller!.text, '15');
    expect(tf('ملاحظات (اختياري)').controller!.text, '');
    expect(tf('المبلغ المدفوع الآن (ج.م)').controller!.text, '');
    expect(find.text('حسن البدري'), findsNothing);
    expect(tf('المزارع').focusNode!.hasFocus, isTrue);
    expect(find.text('براد 14 · شحنة دمياط'), findsWidgets);

    // العملية الثانية: البراد والسعر وطريقة الدفع محفوظة.
    await _pickFarmer(tester, 'سعيد', 'سعيد أبو زيد');
    await typeInto(tester, _boxesLabel, '20');
    await typeInto(tester, _avgLabel, '10');
    await typeInto(tester, 'المبلغ المدفوع الآن (ج.م)', '500');
    await _tapSave(tester);
    final second = api.callsOf('purchases.create').last;
    expect(second.payload['farmerId'], 'FR-0004');
    expect(second.payload['coolerId'], 'CL-0014');
    expect(second.payload['pricePerKgPiasters'], 1500);
    expect(second.payload['payment'], {'mode': 'partial', 'amountPiasters': 50000, 'method': 'wallet'});
    expect(second.requestId, isNot(api.callsOf('purchases.create').first.requestId));
  });

  testWidgets('مزارع جديد: يُرسل newFarmerName ويظهر تنبيه الأسماء المشابهة', (tester) async {
    final api = coolersApi();
    await _openForm(tester, api);
    await tester.enterText(fieldIn('المزارع'), 'حسن البدرى عطية');
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('مزارع جديد: «حسن البدرى عطية»'));

    expect(find.text('أسماء مشابهة مسجلة بالفعل. إن كان المزارع أحدهم فاختره بدل إضافته مرة أخرى:'), findsOneWidget);
    expect(find.text('حسن البدري · رقم 1 · كفر سعد'), findsOneWidget);

    await _fillBasics(tester);
    await _tapSave(tester);
    final p = api.callsOf('purchases.create').single.payload;
    expect(p['newFarmerName'], 'حسن البدرى عطية');
    expect(p.containsKey('farmerId'), isFalse);
  });

  testWidgets('الاسم المطابق تمامًا لا يُعرض كمزارع جديد بل يُختار', (tester) async {
    final api = coolersApi();
    await _openForm(tester, api);
    await tester.enterText(fieldIn('المزارع'), 'حسن البدرى');
    await tester.pumpAndSettle();
    expect(find.textContaining('مزارع جديد'), findsNothing);
    await _fillBasics(tester);
    await _tapSave(tester);
    expect(api.callsOf('purchases.create').single.payload['farmerId'], 'FR-0001');
  });

  testWidgets('خطأ تحقق من الخادم يظهر تحت الحقل المعني', (tester) async {
    final api = coolersApi();
    api.errors['purchases.create'] = const ApiException(
      ApiErrorCode.validation,
      '«سعر الكيلو» يجب أن يكون بين 0.01 و1,000.00 ج.م. صحّح القيمة ثم أعد المحاولة.',
      field: 'pricePerKgPiasters',
    );
    await _openForm(tester, api);
    await _pickFarmer(tester, 'حسن', 'حسن البدري');
    await _fillBasics(tester);
    await _tapSave(tester);

    final error = find.text('«سعر الكيلو» يجب أن يكون بين 0.01 و1,000.00 ج.م. صحّح القيمة ثم أعد المحاولة.');
    expect(error, findsOneWidget);
    expect(find.descendant(of: find.widgetWithText(LabeledField, _priceLabel), matching: error), findsOneWidget);
    // تعديل الحقل يمسح خطأ الخادم.
    await typeInto(tester, _priceLabel, '14');
    await tester.pumpAndSettle();
    expect(error, findsNothing);
  });

  testWidgets('لا يوجد براد مفتوح: شرح وزر «إنشاء براد»', (tester) async {
    final api = coolersApi()..coolers = [cooler12Json()];
    await pumpPage(tester, const PurchaseFormScreen(), api: api);
    expect(find.text('لا يوجد براد مفتوح'), findsOneWidget);
    expect(find.text('إنشاء براد'), findsOneWidget);
    expect(find.text('حفظ'), findsNothing);
  });

  testWidgets('بلا براد محدد يُختار أحدث براد مفتوح، ويمكن تغييره من القائمة', (tester) async {
    final api = coolersApi();
    await pumpPage(tester, const PurchaseFormScreen(), api: api);
    expect(find.text('براد 14 · شحنة دمياط'), findsWidgets);
    await tapVisible(tester, find.text('براد 14 · شحنة دمياط').first);
    await tapVisible(tester, find.text('براد 13 · شحنة الإسكندرية').last);
    await _pickFarmer(tester, 'حسن', 'حسن البدري');
    await _fillBasics(tester);
    await _tapSave(tester);
    expect(api.callsOf('purchases.create').single.payload['coolerId'], 'CL-0013');
  });

  group('تعديل عملية', () {
    Purchase purchase({String coolerId = 'CL-0014', int paid = 0}) =>
        Purchase.fromJson(purchaseJson(coolerId: coolerId, paid: paid, notes: 'قديمة', version: 3));

    testWidgets('يُعبأ النموذج ويرسل الحقول المعدّلة فقط', (tester) async {
      final api = coolersApi();
      final p = purchase();
      api.handlers['coolers.get'] = (_) => coolerDetailJson(purchases: [purchaseJson(notes: 'قديمة', version: 3)]);
      api.handlers['purchases.update'] = (_) => {'purchase': purchaseJson(boxes: 52, version: 4)};
      await pumpPage(tester, PurchaseFormScreen(coolerId: p.coolerId, purchase: p), api: api);

      expect(find.text('تعديل عملية شراء'), findsOneWidget);
      expect(find.text('حسن البدري'), findsOneWidget);
      expect(find.text('الدفع مع الشراء'), findsNothing);
      expect(find.text('لا تغييرات للحفظ'), findsOneWidget);

      await typeInto(tester, _boxesLabel, '52');
      await tester.pumpAndSettle();
      expect(findRichText('8,580.00 ج.م'), findsWidgets);
      await _tapSave(tester, 'حفظ التعديل');

      final call = api.callsOf('purchases.update').single;
      expect(call.payload, {
        'id': 'PU-0030',
        'expectedVersion': 3,
        'changes': {'boxes': 52},
      });
      expect(find.text('تم حفظ التعديل في الملف'), findsOneWidget);
    });

    testWidgets('CONFLICT: رسالة لتحديث البيانات مع تحميل النسخة الحالية', (tester) async {
      final api = coolersApi();
      final p = purchase();
      api.handlers['coolers.get'] = (_) => coolerDetailJson(purchases: [purchaseJson(notes: 'قديمة', version: 3)]);
      api.errors['purchases.update'] = ApiException(
        ApiErrorCode.conflict,
        'عدّل شخص آخر عملية الشراء هذه.',
        details: {'currentVersion': 4, 'current': purchaseJson(boxes: 60, version: 4)},
      );
      await pumpPage(tester, PurchaseFormScreen(coolerId: p.coolerId, purchase: p), api: api);
      await typeInto(tester, _boxesLabel, '52');
      await _tapSave(tester, 'حفظ التعديل');

      expect(find.text('عدّل شخص آخر هذه العملية بعد فتحها. حدّث البيانات، راجعها، ثم أعد المحاولة.'), findsOneWidget);
      await tapVisible(tester, find.text('تحميل النسخة الحالية'));
      expect(tester.widget<TextField>(fieldIn(_boxesLabel)).controller!.text, '60');
    });

    testWidgets('براد مقفّل: النموذج للقراءة فقط دون زر حفظ', (tester) async {
      final api = coolersApi();
      final p = purchase(coolerId: 'CL-0012');
      await pumpPage(tester, PurchaseFormScreen(coolerId: p.coolerId, purchase: p), api: api);
      expect(
        find.text('البراد مقفّل — لا يمكن تعديل مشترياته. اطلب من المدير إعادة فتحه إن لزم التعديل.'),
        findsOneWidget,
      );
      expect(find.text('حفظ التعديل'), findsNothing);
      expect(tester.widget<TextField>(fieldIn(_boxesLabel)).enabled, isFalse);
    });
  });
}
