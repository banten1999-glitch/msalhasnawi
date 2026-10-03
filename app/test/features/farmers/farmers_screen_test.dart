import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumman_calculator/core/api/api_exception.dart';
import 'package:rumman_calculator/core/sync/data_changes.dart';
import 'package:rumman_calculator/features/farmers/farmer_edit_sheet.dart';
import 'package:rumman_calculator/features/farmers/farmers_screen.dart';
import 'package:rumman_calculator/features/reports/farmer_statement_screen.dart';

import '../../support/fake_auth_controller.dart';
import '../../support/fake_backend_api.dart';
import '../../support/sample_data.dart';
import '../../support/test_app.dart';
import 'farmer_test_data.dart';

Widget _screen() => const Scaffold(body: FarmersScreen());

Finder _searchField() => find.byType(TextField).first;

void main() {
  setUpAll(loadAppFonts);

  testWidgets('الهاتف: كل مزارع برقمه وقريته وهاتفه وأرقام موسمه والمتبقي بارزًا', (tester) async {
    final api = FakeBackendApi();
    installFarmers(api);
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController());

    // تحميل واحد للمزارعين النشطين ومرة واحدة للمشتريات (لا طلب لكل مزارع).
    expect(api.callsOf('farmers.list').single.payload, isEmpty);
    expect(api.callsOf('purchases.list').single.payload, isEmpty);

    expect(find.text('حسن البدري'), findsOneWidget);
    expect(find.text('رقم 1'), findsOneWidget);
    expect(find.text('بني عدي'), findsOneWidget);
    final phone = tester.widget<Text>(find.text('01001234567'));
    expect(phone.textDirection, TextDirection.ltr);
    expect(find.text('عمليتان · 770 كغ'), findsOneWidget);
    expect(find.text('القيمة 11,550.00 · المدفوع 6,550.00'), findsOneWidget);
    expect(find.text('المتبقي'), findsOneWidget);
    expect(findRichText('5,000.00 ج.م'), findsNWidgets(2)); // البطاقة + الملخص
    expect(find.text('لا متبقي'), findsOneWidget); // أحمد مدفوع بالكامل
    expect(find.text('لا عمليات شراء هذا الموسم.'), findsOneWidget); // محمود
    expect(find.text('3 مزارعين'), findsOneWidget);
    // الموقوف لا يظهر افتراضيًا.
    expect(find.text('رمضان حسانين'), findsNothing);
    expect(find.text('إضافة مزارع'), findsOneWidget);
  });

  testWidgets('البحث يتسامح مع الهمزات والياء والأرقام العربية، وبرقم المزارع', (tester) async {
    final api = FakeBackendApi();
    installFarmers(api);
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController());

    await tester.enterText(_searchField(), 'احمد الشافعي');
    await tester.pumpAndSettle();
    expect(find.text('أحمد الشافعى'), findsOneWidget);
    expect(find.text('حسن البدري'), findsNothing);
    expect(find.text('مزارع واحد يطابق البحث'), findsOneWidget);

    await tester.enterText(_searchField(), 'محمود العال');
    await tester.pumpAndSettle();
    expect(find.text('الحاج محمود عبد العال'), findsOneWidget);
    expect(find.text('أحمد الشافعى'), findsNothing);

    // جزء من الهاتف بأرقام عربية.
    await tester.enterText(_searchField(), '٠١٠٠١٢');
    await tester.pumpAndSettle();
    expect(find.text('حسن البدري'), findsOneWidget);
    expect(find.text('أحمد الشافعى'), findsNothing);

    // رقم المزارع بالضبط.
    await tester.enterText(_searchField(), '٣');
    await tester.pumpAndSettle();
    expect(find.text('الحاج محمود عبد العال'), findsOneWidget);
    expect(find.text('حسن البدري'), findsNothing);

    // القرية.
    await tester.enterText(_searchField(), 'منفلوط');
    await tester.pumpAndSettle();
    expect(find.text('أحمد الشافعى'), findsOneWidget);

    await tester.enterText(_searchField(), 'سعيد');
    await tester.pumpAndSettle();
    expect(find.text('لا يوجد مزارع يطابق «سعيد».'), findsOneWidget);
    expect(find.text('إضافة مزارع جديد'), findsOneWidget);

    // البحث محلي: لا طلبات إضافية.
    expect(api.count('farmers.list'), 1);
  });

  testWidgets('«إضافة مزارع جديد» من نتيجة بحث فارغة يملأ الاسم ويضيفه للقائمة', (tester) async {
    final api = FakeBackendApi();
    installFarmers(api);
    api.handlers['farmers.create'] = (p) => {'farmer': farmerJson('FR-0005', 5, p['name'] as String)};
    final changes = DataChanges();
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController(), changes: changes);

    await tester.enterText(_searchField(), 'سعيد أبو زيد');
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('إضافة مزارع جديد'));
    expect(find.byType(FarmerEditor), findsOneWidget);
    expect(find.descendant(of: find.byType(FarmerEditor), matching: find.text('سعيد أبو زيد')), findsOneWidget);

    await tapVisible(tester, find.text('إضافة المزارع'));
    expect(api.callsOf('farmers.create').single.payload, {'name': 'سعيد أبو زيد'});
    expect(changes.revision, 1);
    expect(find.text('أُضيف المزارع «سعيد أبو زيد» برقم 5.'), findsOneWidget);
    // التغيير يعيد تحميل القائمة.
    expect(api.count('farmers.list'), 2);
  });

  testWidgets('إظهار الموقوفين يعيد الطلب مع includeInactive ويعرض شارة «موقوف»', (tester) async {
    final api = FakeBackendApi();
    installFarmers(api);
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController());

    await tapVisible(tester, find.text('إظهار الموقوفين'));
    expect(api.callsOf('farmers.list').last.payload, {'includeInactive': true});
    expect(find.text('رمضان حسانين'), findsOneWidget);
    expect(find.text('موقوف'), findsOneWidget);
    expect(find.text('4 مزارعين'), findsOneWidget);
  });

  testWidgets('إيقاف مزارع بعد التأكيد يرسل الحالة مع expectedVersion', (tester) async {
    final api = FakeBackendApi();
    final farmers = sampleFarmersJson();
    installFarmers(api, farmers: farmers);
    api.handlers['farmers.update'] = (p) {
      farmers[0] = {...farmers[0], 'status': 'inactive', 'version': 3};
      return {'farmer': farmers[0]};
    };
    final changes = DataChanges();
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController(), changes: changes);

    await tapVisible(tester, find.byTooltip('إجراءات حسن البدري'));
    await tapVisible(tester, find.text('إيقاف المزارع'));
    expect(find.text('إيقاف المزارع؟'), findsOneWidget);
    await tapVisible(tester, find.text('إيقاف المزارع').last);

    final call = api.callsOf('farmers.update').single;
    expect(call.payload, {'id': 'FR-0001', 'expectedVersion': 2, 'status': 'inactive'});
    expect(call.requestId, isNotNull);
    expect(changes.revision, 1);
    expect(find.text('حسن البدري'), findsNothing);
    expect(find.textContaining('أُوقف «حسن البدري»'), findsOneWidget);
  });

  testWidgets('تعارض الإصدار عند الإيقاف يعرض رسالة التحديث', (tester) async {
    final api = FakeBackendApi();
    installFarmers(api);
    api.errors['farmers.update'] = const ApiException(
      ApiErrorCode.conflict,
      'عدّل مستخدم آخر بيانات هذا المزارع بعد أن فتحته.',
      field: 'expectedVersion',
    );
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController());

    await tapVisible(tester, find.byTooltip('إجراءات حسن البدري'));
    await tapVisible(tester, find.text('إيقاف المزارع'));
    await tapVisible(tester, find.text('إيقاف المزارع').last);
    expect(find.text('عدّل شخص آخر هذا السجل، حدّث وأعد المحاولة.'), findsOneWidget);
    await tapVisible(tester, find.text('تحديث'));
    expect(api.count('farmers.list'), 2);
  });

  testWidgets('الضغط على المزارع يفتح كشف حسابه', (tester) async {
    final api = FakeBackendApi();
    installFarmers(api);
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController());

    await tester.tap(find.text('أحمد الشافعى'));
    await tester.pumpAndSettle();
    final statement = tester.widget<FarmerStatementScreen>(find.byType(FarmerStatementScreen));
    expect(statement.farmerId, 'FR-0002');
  });

  testWidgets('«مشاهدة فقط» يرى القائمة دون إضافة أو قائمة إجراءات', (tester) async {
    final api = FakeBackendApi();
    installFarmers(api);
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController(user: sampleViewer()));

    expect(find.text('حسن البدري'), findsOneWidget);
    expect(find.text('إضافة مزارع'), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);

    await tester.enterText(_searchField(), 'سعيد');
    await tester.pumpAndSettle();
    expect(find.text('إضافة مزارع جديد'), findsNothing);
  });

  testWidgets('الشاشة العريضة: جدول بكل الأعمدة دون فيض', (tester) async {
    final api = FakeBackendApi();
    installFarmers(api);
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController(), size: wideSize);

    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('المزارعون'), findsOneWidget);
    expect(find.text('المتبقي (ج.م)'), findsOneWidget);
    expect(find.text('حسن البدري'), findsOneWidget);
    expect(find.text('5,000.00'), findsOneWidget);
    expect(find.text('11,550.00'), findsOneWidget);
    expect(find.text('إضافة مزارع'), findsOneWidget);

    // إضافة على الشاشة العريضة تفتح نافذة لا لوحة سفلية.
    await tapVisible(tester, find.text('إضافة مزارع'));
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(FarmerEditor), findsOneWidget);
  });

  testWidgets('الحالات: خطأ التحميل، تعذّر أرقام الموسم، ولا مزارعين', (tester) async {
    final api = FakeBackendApi();
    installFarmers(api);
    api.errors['farmers.list'] = const ApiException(ApiErrorCode.network, 'تعذّر الاتصال بالخادم.');
    api.errors['purchases.list'] = const ApiException(ApiErrorCode.network, 'انقطع الاتصال.');
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController());
    expect(find.text('تعذّر تحميل المزارعين'), findsOneWidget);
    expect(find.text('تعذّر الاتصال بالخادم.'), findsOneWidget);

    // المزارعون وصلوا والمشتريات لا: القائمة تظهر دون أرقام، مع تنبيه.
    api.errors.remove('farmers.list');
    await tapVisible(tester, find.text('إعادة المحاولة'));
    expect(find.text('حسن البدري'), findsOneWidget);
    expect(find.text('تعذّر تحميل أرقام الموسم'), findsOneWidget);
    expect(find.text('عمليتان · 770 كغ'), findsNothing);

    installFarmers(api, farmers: const []);
    api.errors.clear();
    await tester.pumpWidget(const SizedBox());
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController());
    expect(find.text('لا يوجد مزارعون بعد'), findsOneWidget);
  });

  testWidgets('حفظ في مكان آخر (changes.bump) يعيد تحميل القائمة', (tester) async {
    final api = FakeBackendApi();
    installFarmers(api);
    final changes = DataChanges();
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController(), changes: changes);
    expect(api.count('farmers.list'), 1);

    changes.bump();
    await tester.pumpAndSettle();
    expect(api.count('farmers.list'), 2);
    expect(api.count('purchases.list'), 2);
  });
}
