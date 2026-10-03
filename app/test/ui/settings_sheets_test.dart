import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumman_calculator/core/api/api_exception.dart';
import 'package:rumman_calculator/features/settings/change_sheet_dialog.dart';
import 'package:rumman_calculator/features/settings/settings_screen.dart';
import 'package:rumman_calculator/ui/app_button.dart';

import '../support/fake_auth_controller.dart';
import '../support/fake_backend_api.dart';
import '../support/sample_data.dart';
import '../support/test_app.dart';

Widget _screen() => const Scaffold(body: SettingsScreen());

Future<void> _tapVisible(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

AppButton _button(WidgetTester tester, String label) =>
    tester.widget<AppButton>(find.ancestor(of: find.text(label), matching: find.byType(AppButton)).first);

void main() {
  setUpAll(loadAppFonts);

  testWidgets('تبويب Google Sheets يعرض الاتصال والحساب المتصل والصفحات الناقصة', (tester) async {
    final api = FakeBackendApi();
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController());

    expect(find.text('Google Sheets'), findsOneWidget);
    expect(find.text('المستخدمون'), findsNWidgets(2)); // التبويب + صفحة «المستخدمون» في الملف
    expect(find.text('إعدادات العمل'), findsOneWidget);
    expect(api.count('sheet.status'), 1);

    expect(find.text('متصل'), findsOneWidget);
    expect(find.text('حاسبة الرمان — موسم 2026'), findsOneWidget);
    expect(find.text('https://docs.google.com/spreadsheets/d/$sampleSpreadsheetId/edit'), findsOneWidget);
    expect(find.text('الحساب المتصل بالملف'), findsOneWidget);
    expect(find.text('hasnawi.owner@gmail.com'), findsOneWidget);
    expect(find.textContaining('الموظفون لا يحتاجون أي وصول إلى الملف'), findsOneWidget);

    // عمود ناقص وصفحة غير موجودة.
    expect(find.text('عمود ناقص: «رقم الفاتورة»'), findsOneWidget);
    expect(find.text('ناقصة'), findsOneWidget);
    expect(find.text('سجل التعديلات'), findsOneWidget);
    expect(find.text('لا توجد صفحة بهذا الاسم'), findsOneWidget);
    expect(find.text('غير موجودة'), findsOneWidget);
    expect(find.text('سليمة'), findsNWidgets(5));

    // آخر نشاط.
    expect(find.textContaining('تعذّرت الكتابة لأن خدمة Google'), findsOneWidget);
    expect(find.text('يُنشئ الصفحات والأعمدة الناقصة فقط. لا تُحذف أو تُستبدل أي بيانات موجودة.'), findsOneWidget);
  });

  testWidgets('«فحص الأعمدة» يعيد قراءة الحالة ويبرز المشكلات', (tester) async {
    final api = FakeBackendApi();
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController());

    await tester.tap(find.text('فحص الأعمدة'));
    await tester.pumpAndSettle();
    expect(api.count('sheet.status'), 2);
    expect(find.text('ينقص الملف شيئان'), findsOneWidget);
    expect(find.textContaining('أعمدة «رقم الفاتورة» في «مشتريات التعبئة»؛ صفحة «سجل التعديلات»'), findsOneWidget);
  });

  testWidgets('«إصلاح الملف» يستدعي الإصلاح ويعرض الحالة الجديدة', (tester) async {
    final api = FakeBackendApi();
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController());

    await _tapVisible(tester, 'إصلاح الملف');

    expect(api.count('sheet.repair'), 1);
    expect(find.text('اكتمل الإصلاح'), findsOneWidget);
    expect(find.text('عمود ناقص: «رقم الفاتورة»'), findsNothing);
    expect(find.text('سليمة'), findsNWidgets(7));
  });

  testWidgets('فشل الإصلاح يعرض رسالة الخادم ويُبقي الحالة السابقة', (tester) async {
    final api = FakeBackendApi()
      ..sheetRepairError = const ApiException(
        ApiErrorCode.lockTimeout,
        'الملف مشغول بعملية حفظ أخرى. انتظر لحظات ثم أعد المحاولة.',
      );
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController());

    await _tapVisible(tester, 'إصلاح الملف');
    expect(find.text('تعذّر إصلاح الملف'), findsOneWidget);
    expect(find.text('الملف مشغول بعملية حفظ أخرى. انتظر لحظات ثم أعد المحاولة.'), findsOneWidget);
    expect(find.text('عمود ناقص: «رقم الفاتورة»'), findsOneWidget);
  });

  testWidgets('«تغيير الملف…» يطلب الرابط وتأكيدًا صريحًا ثم يعرض تنبيه الخادم', (tester) async {
    final api = FakeBackendApi();
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController());

    await _tapVisible(tester, 'تغيير الملف…');
    expect(find.byType(ChangeSheetDialog), findsOneWidget);
    expect(find.text('البيانات القديمة لا تُنقل تلقائيًا'), findsOneWidget);

    // بدون تأكيد لا يمكن الربط.
    expect(_button(tester, 'ربط الملف الجديد').onPressed, isNull);

    // رابط غير صالح: رسالة تحت الحقل دون استدعاء الخادم.
    await tester.enterText(find.byType(TextField), 'ملف الموسم');
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('ربط الملف الجديد'));
    await tester.pump();
    expect(find.textContaining('هذا ليس رابط ملف Google Sheets'), findsOneWidget);
    expect(api.count('sheet.connect'), 0);

    const url = 'https://docs.google.com/spreadsheets/d/NEWfileID_abcdefghijklmnop0123/edit';
    await tester.enterText(find.byType(TextField), url);
    await tester.tap(find.text('ربط الملف الجديد'));
    await tester.pumpAndSettle();

    expect(api.callsOf('sheet.connect').single.payload, {'spreadsheet': url});
    expect(find.byType(ChangeSheetDialog), findsNothing);
    expect(find.text('تم ربط الملف الجديد'), findsOneWidget);
    expect(find.text(connectWarning), findsOneWidget);
    expect(find.text('ملف الموسم الجديد'), findsOneWidget);
  });

  testWidgets('خطأ الخادم عند الربط يظهر تحت حقل الرابط', (tester) async {
    final api = FakeBackendApi()
      ..sheetConnectError = const ApiException(
        ApiErrorCode.sheetUnreachable,
        'تعذّر فتح الملف. تأكد أن الرابط صحيح وأن حساب الربط لديه صلاحية «محرر» على الملف، ثم أعد المحاولة.',
        field: 'spreadsheet',
      );
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController());

    await _tapVisible(tester, 'تغيير الملف…');
    await tester.enterText(find.byType(TextField), 'NEWfileID_abcdefghijklmnop0123');
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('ربط الملف الجديد'));
    await tester.pumpAndSettle();

    expect(find.byType(ChangeSheetDialog), findsOneWidget);
    expect(find.textContaining('تعذّر فتح الملف. تأكد أن الرابط صحيح'), findsOneWidget);
  });

  testWidgets('تبويب «إعدادات العمل» للعرض فقط', (tester) async {
    final api = FakeBackendApi();
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController());

    await tester.tap(find.text('إعدادات العمل'));
    await tester.pumpAndSettle();
    expect(api.count('settings.get'), 1);
    expect(find.text('حاسبة الحسناوي'), findsOneWidget);
    expect(find.text('Africa/Cairo'), findsOneWidget);
    expect(find.text('1.9 كغ'), findsOneWidget);
    expect(find.text('1 أغسطس 2026'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
}
