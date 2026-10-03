import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumman_calculator/core/api/api_exception.dart';
import 'package:rumman_calculator/core/sync/data_changes.dart';
import 'package:rumman_calculator/features/coolers/cooler_details_screen.dart';
import 'package:rumman_calculator/features/coolers/coolers_screen.dart';
import 'package:rumman_calculator/features/coolers/create_cooler_sheet.dart';
import 'package:rumman_calculator/ui/labeled_field.dart';

import '../../support/fake_auth_controller.dart';
import '../../support/fake_backend_api.dart';
import '../../support/sample_data.dart';
import '../../support/test_app.dart';
import 'coolers_test_support.dart';

Widget _screen() => const Scaffold(body: CoolersScreen());

Map<String, dynamic> _cooler15() => {
      ...cooler14Json(),
      'id': 'CL-0015',
      'no': 15,
      'name': 'شحنة طنطا',
      'carNo': 'ط ن ط 1234',
      'driver': null,
      'farmers': 0,
      'purchases': 0,
      'boxes': 0,
      'weightGrams': 0,
      'valuePiasters': 0,
      'paidPiasters': 0,
      'remainingPiasters': 0,
      'packagingApprovedPiasters': 0,
      'totalCostPiasters': 0,
      'avgPricePerKgPiasters': 0,
    };

void main() {
  setUpAll(loadAppFonts);

  for (final size in [phoneSize, wideSize]) {
    final where = size == phoneSize ? 'الهاتف' : 'الشاشة العريضة';

    testWidgets('قائمة البرادات: التبويبات بأعدادها والبطاقات وفتح البراد ($where)', (tester) async {
      final api = coolersApi();
      await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController(), size: size);

      expect(api.callsOf('coolers.list').single.payload, {'status': 'all'});
      expect(find.text('المفتوحة (2)'), findsOneWidget);
      expect(find.text('المقفّلة (1)'), findsOneWidget);
      expect(find.text('الكل (3)'), findsOneWidget);
      // «المفتوحة» افتراضيًا ما دام هناك براد مفتوح.
      expect(find.text('براد 14 · شحنة دمياط'), findsOneWidget);
      expect(find.text('براد 13 · شحنة الإسكندرية'), findsOneWidget);
      expect(find.text('براد 12 · شحنة بورسعيد'), findsNothing);
      expect(findRichText('40,839.40 ج.م'), findsOneWidget);
      expect(findRichText('مدفوع 23,314.00'), findsOneWidget);
      expect(findRichText('متبقي 17,525.40'), findsOneWidget);
      expect(find.text('إجمالي تكلفة البراد'), findsNWidgets(2));
      expect(find.text('إنشاء براد'), findsOneWidget);

      await tapVisible(tester, find.text('المقفّلة (1)'));
      expect(find.text('براد 12 · شحنة بورسعيد'), findsOneWidget);
      expect(find.text('براد 14 · شحنة دمياط'), findsNothing);
      expect(find.textContaining('قُفّل'), findsOneWidget);

      await tapVisible(tester, find.text('براد 12 · شحنة بورسعيد'));
      expect(find.byType(CoolerDetailsScreen), findsOneWidget);
      expect(api.callsOf('coolers.get').single.payload, {'id': 'CL-0012'});
    });

    testWidgets('إنشاء براد: يرسل coolers.create مرة واحدة ويفتح البراد الجديد ($where)', (tester) async {
      final api = coolersApi();
      final changes = DataChanges();
      api.handlers['coolers.create'] = (p) => {'cooler': _cooler15()};
      await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController(), size: size, changes: changes);

      await tapVisible(tester, find.text('إنشاء براد'));
      expect(find.byType(CreateCoolerForm), findsOneWidget);
      expect(find.byType(size == wideSize ? Dialog : BottomSheet), findsOneWidget);
      await tester.enterText(fieldIn('اسم البراد / الوصف (اختياري)'), '  شحنة طنطا ');
      await tester.enterText(fieldIn('رقم السيارة (اختياري)'), 'ط ن ط 1234');

      api.delay = const Duration(milliseconds: 300);
      final at = tester.getCenter(find.widgetWithText(FilledButton, 'إنشاء البراد'));
      await tester.tapAt(at);
      await tester.pump(const Duration(milliseconds: 10));
      await tester.tapAt(at);
      await tester.pump(const Duration(milliseconds: 10));
      expect(find.text('جارٍ الإنشاء'), findsOneWidget);
      await tester.pumpAndSettle();
      api.delay = Duration.zero;

      final call = api.callsOf('coolers.create').single;
      expect(call.payload, {'name': 'شحنة طنطا', 'carNo': 'ط ن ط 1234'});
      expect(call.requestId, isNotNull);
      expect(find.byType(CreateCoolerForm), findsNothing);
      expect(find.text('تم إنشاء براد 15 · شحنة طنطا وفتحه لتسجيل المشتريات.'), findsOneWidget);
      expect(find.byType(CoolerDetailsScreen), findsOneWidget);
      // الإنشاء يُعلن تغيّر البيانات فتُعاد قراءة القائمة.
      expect(api.count('coolers.list'), 2);
    });
  }

  testWidgets('إنشاء براد: خطأ الحقل تحته، وخطأ الاتصال في الأعلى مع بقاء البيانات', (tester) async {
    final api = coolersApi();
    api.errors['coolers.create'] = const ApiException(
      ApiErrorCode.validation,
      '«رقم السيارة» أطول من المسموح (30 حرفًا). اختصره ثم أعد المحاولة.',
      field: 'carNo',
    );
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController());
    await tapVisible(tester, find.text('إنشاء براد'));
    await tester.enterText(fieldIn('رقم السيارة (اختياري)'), 'ن ق ر 7316');
    await tapVisible(tester, find.text('إنشاء البراد'));
    expect(
      find.descendant(
        of: find.widgetWithText(LabeledField, 'رقم السيارة (اختياري)'),
        matching: find.text('«رقم السيارة» أطول من المسموح (30 حرفًا). اختصره ثم أعد المحاولة.'),
      ),
      findsOneWidget,
    );

    api.errors['coolers.create'] = const ApiException(ApiErrorCode.network, 'لا يوجد اتصال بالإنترنت.');
    await tester.enterText(fieldIn('رقم السيارة (اختياري)'), 'ن ق ر 731');
    await tapVisible(tester, find.text('إنشاء البراد'));
    expect(find.text('لم يُنشأ البراد'), findsOneWidget);
    expect(find.text('لا يوجد اتصال بالإنترنت.'), findsOneWidget);
    expect(find.byType(CreateCoolerForm), findsOneWidget);

    // إعادة المحاولة بالحمولة نفسها تستخدم المعرّف نفسه.
    await tapVisible(tester, find.text('إنشاء البراد'));
    final ids = api.callsOf('coolers.create').skip(1).map((c) => c.requestId).toSet();
    expect(ids, hasLength(1));
  });

  testWidgets('«مشاهدة فقط» لا يرى «إنشاء براد»', (tester) async {
    final api = coolersApi();
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController(user: sampleViewer()));
    expect(find.text('براد 14 · شحنة دمياط'), findsOneWidget);
    expect(find.text('إنشاء براد'), findsNothing);
  });

  testWidgets('لا برادات: حالة فارغة مع «إنشاء براد»', (tester) async {
    final api = coolersApi()..coolers = [];
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController(), size: wideSize);
    expect(find.text('لا توجد برادات بعد'), findsOneWidget);
    expect(find.text('إنشاء براد'), findsOneWidget);
  });

  testWidgets('كل البرادات مقفّلة: يبدأ بتبويب «الكل»، و«المفتوحة» تشرح وتعرض الإنشاء', (tester) async {
    final api = coolersApi()..coolers = [cooler12Json()];
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController());
    expect(find.text('براد 12 · شحنة بورسعيد'), findsOneWidget);
    await tapVisible(tester, find.text('المفتوحة (0)'));
    expect(find.text('لا يوجد براد مفتوح الآن'), findsOneWidget);
    expect(find.text('إنشاء براد'), findsNWidgets(2));
  });

  testWidgets('خطأ التحميل ثم «إعادة المحاولة»، وإعادة القراءة عند تغيّر البيانات', (tester) async {
    final api = coolersApi()..coolersError = const ApiException(ApiErrorCode.network, 'لا يوجد اتصال بالإنترنت.');
    final changes = DataChanges();
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController(), changes: changes);
    expect(find.text('تعذّر تحميل البرادات'), findsOneWidget);

    api.coolersError = null;
    await tapVisible(tester, find.text('إعادة المحاولة'));
    expect(find.text('براد 14 · شحنة دمياط'), findsOneWidget);
    expect(api.count('coolers.list'), 2);

    changes.bump();
    await tester.pumpAndSettle();
    expect(api.count('coolers.list'), 3);
  });
}
