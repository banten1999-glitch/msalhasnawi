import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumman_calculator/core/api/api_exception.dart';
import 'package:rumman_calculator/core/sync/data_changes.dart';
import 'package:rumman_calculator/core/sync/outbox.dart';
import 'package:rumman_calculator/features/coolers/cooler_details_screen.dart';
import 'package:rumman_calculator/features/coolers/purchase_form_screen.dart';

import '../../support/fake_backend_api.dart';
import '../../support/sample_data.dart';
import '../../support/test_app.dart';
import 'coolers_test_support.dart';

Map<String, dynamic> _closed14({Map<String, dynamic>? snapshot}) => {
      ...cooler14Json(),
      'status': 'closed',
      'closedAt': '2026-10-02T18:10:00+03:00',
      'closedBy': 'كريم عبد الله',
      'closeSnapshot': snapshot,
    };

FakeBackendApi _api({Map<String, dynamic>? cooler}) {
  final api = coolersApi();
  api.handlers['coolers.get'] = (_) => coolerDetailJson(
        cooler: cooler,
        packaging: [packagingJson(), packagingJson(id: 'PK-0006', no: 'P-0006', status: 'draft', total: 120000)],
      );
  return api;
}

Finder _inDialog(Finder f) => find.descendant(of: find.byType(AlertDialog), matching: f);

void main() {
  setUpAll(loadAppFonts);

  for (final size in [phoneSize, wideSize]) {
    final where = size == phoneSize ? 'الهاتف' : 'الشاشة العريضة';

    testWidgets('يعرض الملخص والمؤشرات والعمليات والتعبئة وأزرار المدير ($where)', (tester) async {
      final api = _api();
      await pumpPage(tester, const CoolerDetailsScreen(coolerId: 'CL-0014'), api: api, size: size);

      expect(api.callsOf('coolers.get').single.payload, {'id': 'CL-0014'});
      expect(find.text('براد 14 · شحنة دمياط'), findsWidgets);
      expect(find.text('مفتوح'), findsWidgets);
      expect(find.text('ن ق ر 7316 · سامي عطية'), findsOneWidget);

      // المؤشرات
      expect(find.text('مزارعون مختلفون'), findsOneWidget);
      expect(findRichText('2,718.2 كغ'), findsOneWidget);
      expect(findRichText('40,839.40 ج.م'), findsOneWidget);
      expect(findRichText('45,339.40 ج.م'), findsOneWidget); // إجمالي تكلفة البراد
      expect(findRichText('15.02 ج.م/كغ'), findsOneWidget);

      // العمليات: الملغاة ظاهرة بسببها ومستبعدة من العدد.
      expect(find.text('عمليات الشراء (2)'), findsOneWidget);
      expect(find.text('1 ملغاة لا تدخل في الإجماليات'), findsOneWidget);
      expect(find.text('حسن البدري'), findsOneWidget);
      expect(find.text('ملغاة — السبب: سُجّلت مرتين بالخطأ'), findsOneWidget);
      expect(find.text('جزئي'), findsNothing);
      expect(find.text('دفع جزئي'), findsOneWidget);
      expect(find.text('مدفوع'), findsOneWidget);
      expect(find.text('متبقي 6,250.00'), findsOneWidget);

      // التعبئة
      expect(find.text('P-0004 · الوادي للتغليف'), findsOneWidget);
      expect(find.text('مسودة'), findsOneWidget);
      expect(find.text('إضافة مشتريات تعبئة'), findsOneWidget);

      // الإجراءات
      expect(find.text('إضافة شراء من مزارع'), findsOneWidget);
      expect(find.text('تقفيل البراد'), findsOneWidget);
      expect(find.text('تقرير البراد'), findsOneWidget);
      expect(find.text('إعادة فتح البراد'), findsNothing);
      expect(find.byTooltip('إجراءات شراء حسن البدري'), findsOneWidget);
      expect(find.byTooltip('إجراءات شراء سعيد أبو زيد'), findsNothing);
    });

    testWidgets('«مشاهدة فقط» لا يرى أي زر إجراء ($where)', (tester) async {
      final api = _api(cooler: _closed14());
      await pumpPage(tester, const CoolerDetailsScreen(coolerId: 'CL-0014'), api: api, size: size, user: sampleViewer());

      expect(find.text('حسن البدري'), findsOneWidget);
      for (final label in [
        'إضافة شراء من مزارع',
        'تقفيل البراد',
        'إعادة فتح البراد',
        'إضافة مشتريات تعبئة',
      ]) {
        expect(find.text(label), findsNothing, reason: label);
      }
      expect(find.byIcon(Icons.more_vert), findsNothing);
      // التقرير قراءة فقط.
      expect(find.text('تقرير البراد'), findsOneWidget);
    });
  }

  testWidgets('البراد المقفّل: شريط التنبيه، ولقطة التقفيل مقابل الآن، وإعادة الفتح تتطلب سببًا', (tester) async {
    final snapshot = {
      'farmers': 5,
      'purchases': 6,
      'boxes': 249,
      'weightGrams': 2718200,
      'valuePiasters': 4083940,
      'paidPiasters': 2000000,
      'remainingPiasters': 2083940,
      'packagingPiasters': 450000,
      'totalCostPiasters': 4533940,
    };
    final api = _api(cooler: _closed14(snapshot: snapshot));
    api.handlers['coolers.reopen'] = (p) => {'cooler': cooler14Json()};
    final changes = DataChanges();
    await pumpPage(tester, const CoolerDetailsScreen(coolerId: 'CL-0014'), api: api, changes: changes);

    expect(find.text('البراد مقفّل — لا يمكن إضافة أو تعديل المشتريات، والدفعات مسموحة'), findsOneWidget);
    expect(find.text('إضافة شراء من مزارع'), findsNothing);
    expect(find.text('تقفيل البراد'), findsNothing);
    expect(find.text('أرقام التقفيل مقابل الآن'), findsOneWidget);
    expect(find.text('20,000.00'), findsOneWidget); // المدفوع عند التقفيل
    expect(find.text('23,314.00'), findsOneWidget); // المدفوع الآن

    // تسجيل دفعة مسموح في البراد المقفّل، والتعديل والإلغاء لا.
    await tapVisible(tester, find.byTooltip('إجراءات شراء حسن البدري'));
    expect(find.text('تسجيل دفعة'), findsOneWidget);
    expect(find.text('تعديل العملية'), findsNothing);
    expect(find.text('إلغاء العملية'), findsNothing);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('إعادة فتح البراد'));
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(_inDialog(find.text('إعادة فتح البراد')));
    await tester.pumpAndSettle();
    expect(find.text('«سبب إعادة الفتح» مطلوب. اكتب سببًا واضحًا ثم أعد المحاولة.'), findsOneWidget);
    expect(api.count('coolers.reopen'), 0);

    await tester.enterText(_inDialog(find.byType(TextField)), 'نسينا تسجيل شراء من مزارع');
    await tester.tap(_inDialog(find.text('إعادة فتح البراد')));
    await tester.pumpAndSettle();
    final call = api.callsOf('coolers.reopen').single;
    expect(call.payload, {'id': 'CL-0014', 'reason': 'نسينا تسجيل شراء من مزارع'});
    expect(call.requestId, isNotNull);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('أُعيد فتح براد 14 · شحنة دمياط.'), findsOneWidget);
    expect(api.count('coolers.get'), 2);
  });

  testWidgets('إلغاء عملية عليها دفعات: رسالة الخادم تظهر في النافذة', (tester) async {
    final api = _api();
    api.errors['purchases.cancel'] = const ApiException(
      ApiErrorCode.validation,
      'على عملية الشراء PU-0023 1 دفعة فعّالة بمبلغ 2,000.00 ج.م. ألغِ الدفعات أولًا ثم ألغِ العملية.',
      field: 'id',
    );
    await pumpPage(tester, const CoolerDetailsScreen(coolerId: 'CL-0014'), api: api);

    await tapVisible(tester, find.byTooltip('إجراءات شراء حسن البدري'));
    await tapVisible(tester, find.text('إلغاء العملية'));
    expect(find.textContaining('فيجب إلغاء الدفعات أولًا'), findsOneWidget);
    await tester.enterText(_inDialog(find.byType(TextField)), 'خطأ في الوزن');
    await tester.tap(_inDialog(find.text('إلغاء العملية')));
    await tester.pumpAndSettle();

    expect(api.callsOf('purchases.cancel').single.payload, {'id': 'PU-0023', 'reason': 'خطأ في الوزن'});
    expect(
      find.text('على عملية الشراء PU-0023 1 دفعة فعّالة بمبلغ 2,000.00 ج.م. ألغِ الدفعات أولًا ثم ألغِ العملية.'),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('موظف الإدخال يعدّل عمليته فقط ما لم يملك «تعديل عمليات الآخرين»', (tester) async {
    final api = _api();
    await pumpPage(tester, const CoolerDetailsScreen(coolerId: 'CL-0014'), api: api, user: sampleEntry());

    // عملية المدير: دفعة فقط.
    await tapVisible(tester, find.byTooltip('إجراءات شراء حسن البدري'));
    expect(find.text('تسجيل دفعة'), findsOneWidget);
    expect(find.text('تعديل العملية'), findsNothing);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    // عمليته هو (مدفوعة بالكامل): تعديل وإلغاء دون دفعة.
    await tapVisible(tester, find.byTooltip('إجراءات شراء عبد الرحمن الشافعي'));
    expect(find.text('تعديل العملية'), findsOneWidget);
    expect(find.text('إلغاء العملية'), findsOneWidget);
    expect(find.text('تسجيل دفعة'), findsNothing);
    await tapVisible(tester, find.text('تعديل العملية'));
    expect(find.byType(PurchaseFormScreen), findsOneWidget);
    expect(find.text('تعديل عملية شراء'), findsOneWidget);
  });

  testWidgets('عمليات بانتظار المزامنة لهذا البراد تظهر في شريط، ويُعاد التحميل بعد إرسالها', (tester) async {
    final api = _api();
    api.errors['purchases.create'] = const ApiException(ApiErrorCode.network, 'لا يوجد اتصال');
    final outbox = Outbox(api: api, storage: MemoryOutboxStorage(), retryInterval: const Duration(hours: 1));
    await outbox.bindUser(sampleAdmin().email);
    await outbox.submit(
      action: 'purchases.create',
      payload: {'coolerId': 'CL-0014', 'boxes': 50},
      requestId: 'r-1',
      label: 'شراء · حسن · 50 صندوق',
      coolerId: 'CL-0014',
    );
    await pumpPage(tester, const CoolerDetailsScreen(coolerId: 'CL-0014'), api: api, outbox: outbox);

    expect(find.text('عملية واحدة بانتظار المزامنة'), findsOneWidget);
    expect(find.text('عرض'), findsOneWidget);
    expect(api.count('coolers.get'), 1);

    api.errors.remove('purchases.create');
    api.handlers['purchases.create'] = (_) => {'purchase': purchaseJson(id: 'PU-0040')};
    await outbox.flush();
    await tester.pumpAndSettle();
    expect(find.text('عملية واحدة بانتظار المزامنة'), findsNothing);
    expect(api.count('coolers.get'), 2);

    await tester.pumpWidget(const SizedBox());
    outbox.dispose();
  });

  testWidgets('خطأ التحميل يعرض «إعادة المحاولة»', (tester) async {
    final api = _api();
    api.errors['coolers.get'] = const ApiException(ApiErrorCode.network, 'لا يوجد اتصال بالإنترنت.');
    await pumpPage(tester, const CoolerDetailsScreen(coolerId: 'CL-0014'), api: api);
    expect(find.text('تعذّر تحميل البراد'), findsOneWidget);
    api.errors.remove('coolers.get');
    await tapVisible(tester, find.text('إعادة المحاولة'));
    expect(find.text('حسن البدري'), findsOneWidget);
  });
}
