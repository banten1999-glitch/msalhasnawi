import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumman_calculator/core/api/api_exception.dart';
import 'package:rumman_calculator/features/dashboard/dashboard_screen.dart';
import 'package:rumman_calculator/features/shell/placeholder_screen.dart';

import '../support/fake_auth_controller.dart';
import '../support/fake_backend_api.dart';
import '../support/sample_data.dart';
import '../support/test_app.dart';

Widget _screen() => const Scaffold(body: DashboardScreen());

void main() {
  setUpAll(loadAppFonts);

  testWidgets('يعرض البراد الحالي ومؤشرات الموسم والحساب المالي من بيانات الخادم', (tester) async {
    final api = FakeBackendApi();
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController());

    // الطلب الأول: الموسم، كل البرادات. وقائمة البرادات للفلتر.
    expect(api.callsOf('dashboard.get').single.payload, {'period': 'season'});
    expect(api.callsOf('coolers.list').single.payload, {'status': 'all'});

    // البراد الحالي
    expect(find.text('البراد الجاري تحميله'), findsOneWidget);
    expect(find.text('براد 14 · شحنة دمياط'), findsOneWidget);
    expect(find.text('249'), findsOneWidget);
    expect(find.text('2,718.2'), findsOneWidget);
    expect(findRichText('40,839.40 ج.م'), findsOneWidget);
    expect(findRichText('مدفوع 23,314.00'), findsOneWidget);
    expect(findRichText('متبقي 17,525.40'), findsOneWidget);
    expect(find.text('براد 13 مفتوح أيضًا · 3 عمليات'), findsOneWidget);

    // مؤشرات الموسم
    expect(find.text('ملخص الموسم'), findsOneWidget);
    expect(find.text('1 أغسطس – 2 أكتوبر 2026'), findsOneWidget);
    expect(find.text('برادات مقفّلة ومحمّلة'), findsOneWidget);
    expect(findRichText('7,142'), findsOneWidget);
    expect(findRichText('78,315.6 كغ'), findsOneWidget);

    // الحساب المالي
    expect(findRichText('1,176,482.40'), findsOneWidget);
    expect(findRichText('112,640.00'), findsOneWidget);
    expect(findRichText('1,289,122.40'), findsOneWidget); // قيمة الرمان + التعبئة المعتمدة
    expect(findRichText('1,151,904.00'), findsOneWidget);
    expect(find.text('مجموع الدفعات المسجلة فقط'), findsOneWidget);
    expect(findRichText('137,218.40'), findsOneWidget);
    expect(find.text('للمزارعين 122,218.40 · للموردين 15,000.00'), findsOneWidget);
    expect(findRichText('15.02 ج.م/كغ'), findsOneWidget);

    // آخر العمليات بشاراتها
    expect(find.text('حسن البدري'), findsOneWidget);
    expect(find.text('جزئي'), findsOneWidget);
    expect(find.text('مسودة'), findsOneWidget);
    expect(find.text('ملغاة'), findsOneWidget);

    // أزرار المدير
    expect(find.text('إضافة شراء'), findsOneWidget);
    expect(find.text('إنشاء براد'), findsOneWidget);
    expect(find.text('تسجيل دفعة'), findsOneWidget);
  });

  testWidgets('تغيير الفترة والبراد يعيد طلب لوحة التحكم بالقيم الجديدة', (tester) async {
    final api = FakeBackendApi();
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController());

    await tester.tap(find.text('الفترة: هذا الموسم'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اليوم').last);
    await tester.pumpAndSettle();
    expect(api.callsOf('dashboard.get').last.payload, {'period': 'today'});
    expect(find.text('الفترة: اليوم'), findsOneWidget);
    expect(find.text('ملخص اليوم'), findsOneWidget);

    // «تبديل إلى براد 13» يختار البراد في الفلتر.
    await tester.ensureVisible(find.text('تبديل إلى براد 13'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تبديل إلى براد 13'));
    await tester.pumpAndSettle();
    expect(api.callsOf('dashboard.get').last.payload, {'period': 'today', 'coolerId': 'CL-0013'});
    expect(find.text('البراد: براد 13'), findsOneWidget);
  });

  testWidgets('حالة فارغة عند عدم وجود أي بيانات', (tester) async {
    final api = FakeBackendApi(dashboardData: emptyDashboard(), coolers: const []);
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController());

    expect(find.text('لا توجد بيانات بعد'), findsOneWidget);
    expect(find.text('إنشاء أول براد'), findsOneWidget);
    expect(find.text('ملخص الموسم'), findsNothing);

    await tester.tap(find.text('إنشاء أول براد'));
    await tester.pumpAndSettle();
    expect(find.byType(PlaceholderPage), findsOneWidget);
    expect(find.text(kNotBuiltYetMessage), findsOneWidget);
  });

  testWidgets('الحالة الفارغة لـ«مشاهدة فقط» بلا زر إنشاء', (tester) async {
    final api = FakeBackendApi(dashboardData: emptyDashboard(), coolers: const []);
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController(user: sampleViewer()));

    expect(find.text('لا توجد بيانات بعد'), findsOneWidget);
    expect(find.text('إنشاء أول براد'), findsNothing);
  });

  testWidgets('خطأ في التحميل يعرض رسالة عربية ثم «إعادة المحاولة» تعيد الطلب', (tester) async {
    final api = FakeBackendApi()
      ..dashboardError = const ApiException(
        ApiErrorCode.network,
        'تعذّر الاتصال بالخادم. تحقق من اتصال الإنترنت ثم أعد المحاولة.',
      );
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController());

    expect(find.text('تعذّر تحميل البيانات'), findsOneWidget);
    expect(find.text('تعذّر الاتصال بالخادم. تحقق من اتصال الإنترنت ثم أعد المحاولة.'), findsOneWidget);
    expect(find.text('2,718.2'), findsNothing);

    api.dashboardError = null;
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(api.count('dashboard.get'), 2);
    expect(find.text('2,718.2'), findsOneWidget);
    expect(findRichText('40,839.40'), findsOneWidget);
  });

  testWidgets('هيكل التحميل يظهر حتى يصل الرد', (tester) async {
    final api = FakeBackendApi()..delay = const Duration(milliseconds: 500);
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController(), settle: false);
    await tester.pump();
    expect(find.bySemanticsLabel('جارٍ تحميل البيانات'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('2,718.2'), findsOneWidget);
  });

  testWidgets('«مشاهدة فقط» لا يرى أزرار الإضافة والتسجيل', (tester) async {
    final api = FakeBackendApi();
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController(user: sampleViewer()));

    expect(find.text('2,718.2'), findsOneWidget);
    expect(find.text('إضافة شراء'), findsNothing);
    expect(find.text('إنشاء براد'), findsNothing);
    expect(find.text('شراء من مزارع'), findsNothing);
    expect(find.text('مشتريات تعبئة'), findsNothing);
    expect(find.text('تسجيل دفعة'), findsNothing);
    // القراءة تبقى متاحة.
    expect(find.text('فتح البراد'), findsOneWidget);
    expect(find.text('تقرير البراد'), findsOneWidget);
  });

  testWidgets('أزرار البراد تفتح صفحة «قيد التنفيذ» دون بيانات مصطنعة', (tester) async {
    final api = FakeBackendApi();
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController());

    await tester.tap(find.text('إضافة شراء'));
    await tester.pumpAndSettle();
    expect(find.text(kNotBuiltYetMessage), findsOneWidget);
    await tester.tap(find.text('رجوع'));
    await tester.pumpAndSettle();
    expect(find.text('البراد الجاري تحميله'), findsOneWidget);
  });

  testWidgets('الشاشة العريضة: شبكة المؤشرات وجدول آخر العمليات وزر التحديث', (tester) async {
    final api = FakeBackendApi();
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController(), size: wideSize);

    expect(find.text('لوحة التحكم'), findsOneWidget);
    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('البرادات المفتوحة'), findsOneWidget);
    expect(find.text('المدفوع فعليًا'), findsOneWidget);
    expect(findRichText('40,839.40'), findsWidgets);
    expect(find.text('إضافة شراء من مزارع'), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsNothing);

    await tester.tap(find.text('تحديث'));
    await tester.pumpAndSettle();
    expect(api.count('dashboard.get'), 2);
  });
}
