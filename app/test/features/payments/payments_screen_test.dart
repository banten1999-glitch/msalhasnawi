import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumman_calculator/core/api/api_exception.dart';
import 'package:rumman_calculator/core/models/records.dart';
import 'package:rumman_calculator/core/sync/data_changes.dart';
import 'package:rumman_calculator/features/payments/cancel_payment_dialog.dart';
import 'package:rumman_calculator/features/payments/payments_screen.dart';
import 'package:rumman_calculator/features/payments/record_payment_screen.dart';

import '../../support/fake_auth_controller.dart';
import '../../support/fake_backend_api.dart';
import '../../support/sample_data.dart';
import '../../support/test_app.dart';
import '../farmers/farmer_test_data.dart';
import 'payment_test_data.dart';

Widget _screen() => const Scaffold(body: PaymentsScreen());

Finder _searchField() => find.byType(TextField).first;

/// القائمة الرأسية للصفحة (غير شريط التبويبات الأفقي).
Finder _mainScroll() =>
    find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;

Future<void> _pickFilter(WidgetTester tester, String button, String option) async {
  await tapVisible(tester, find.text(button));
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('الهاتف: المؤشرات وكل الدفعات، والملغاة بسببها', (tester) async {
    final api = FakeBackendApi();
    installPayments(api);
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController());

    expect(api.callsOf('payments.list').single.payload, isEmpty);
    expect(api.callsOf('purchases.list').single.payload, isEmpty);
    expect(api.callsOf('packaging.list').single.payload, {'status': 'approved'});

    // المؤشرات
    expect(find.text('إجمالي المدفوع'), findsOneWidget);
    expect(findRichText('12,675.00 ج.م'), findsNWidgets(2)); // المؤشر + «مجموع الفعّالة» تحت الفلاتر
    expect(find.text('الدفعات الفعّالة فقط · 4 دفعات'), findsOneWidget);
    expect(find.text('متبقي للمزارعين'), findsOneWidget);
    expect(findRichText('5,000.00 ج.م'), findsOneWidget);
    expect(find.text('متبقي للموردين'), findsOneWidget);
    expect(findRichText('3,500.00 ج.م'), findsOneWidget);

    // الدفعات
    expect(find.text('5 دفعات'), findsOneWidget);
    expect(find.text('(منها 1 ملغاة)'), findsOneWidget);
    expect(find.text('الدفعات'), findsOneWidget);
    expect(find.text('المستحقات'), findsOneWidget);
    expect(find.text('مزارع · شراء رمان · براد 14'), findsWidgets);
    expect(find.text('D-0005 · نقدًا · 2 أكتوبر 2026 · 11:05\u00A0ص'), findsOneWidget);
    expect(find.text('سجّلها كريم عبد الله'), findsWidgets);
    expect(find.text('ملغاة'), findsOneWidget);
    expect(find.text('سبب الإلغاء: سُجّلت مرتين بالخطأ'), findsOneWidget);
    expect(find.text('تسجيل دفعة'), findsOneWidget);
    // الملغاة لا تُلغى مرة أخرى.
    await tester.scrollUntilVisible(find.text('D-0001 · نقدًا · 1 أكتوبر 2026 · 10:00\u00A0ص'), 200);
    expect(find.text('إلغاء الدفعة'), findsWidgets);
  });

  testWidgets('الفلاتر: نوع المستفيد، البراد، الحالة، والبحث بالرقم والمبلغ بأرقام عربية', (tester) async {
    final api = FakeBackendApi();
    installPayments(api);
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController());

    await _pickFilter(tester, 'المستفيد: الكل', 'موردون');
    expect(find.text('دفعة واحدة'), findsOneWidget);
    expect(find.text('الوادي للتغليف'), findsOneWidget);
    expect(find.text('مورد · شراء تعبئة · براد 14'), findsOneWidget);
    await _pickFilter(tester, 'المستفيد: موردون', 'الكل');

    await _pickFilter(tester, 'الحالة: الكل', 'ملغاة');
    expect(find.text('دفعة واحدة'), findsOneWidget);
    expect(find.text('سبب الإلغاء: سُجّلت مرتين بالخطأ'), findsOneWidget);
    await _pickFilter(tester, 'الحالة: ملغاة', 'فعّالة');
    expect(find.text('4 دفعات'), findsOneWidget);
    expect(find.text('سبب الإلغاء: سُجّلت مرتين بالخطأ'), findsNothing);
    await _pickFilter(tester, 'الحالة: فعّالة', 'الكل');

    await _pickFilter(tester, 'البراد: الكل', 'براد 13');
    expect(find.text('دفعتان'), findsOneWidget);
    expect(find.text('أحمد الشافعى'), findsOneWidget);
    await _pickFilter(tester, 'البراد: براد 13', 'الكل');

    await tester.enterText(_searchField(), 'D-0003');
    await tester.pumpAndSettle();
    expect(find.text('دفعة واحدة'), findsOneWidget);
    expect(find.text('أحمد الشافعى'), findsOneWidget);

    await tester.enterText(_searchField(), '٤١٢٥');
    await tester.pumpAndSettle();
    expect(find.text('أحمد الشافعى'), findsOneWidget);

    await tester.enterText(_searchField(), 'لا شيء يطابق');
    await tester.pumpAndSettle();
    expect(find.text('لا توجد دفعات تطابق الفلاتر'), findsOneWidget);
    await tapVisible(tester, find.text('مسح الفلاتر'));
    expect(find.text('5 دفعات'), findsOneWidget);
  });

  testWidgets('المستحقات مجمّعة حسب المستفيد، و«تسجيل دفعة» يفتح الدفعة لتلك العملية', (tester) async {
    final api = FakeBackendApi();
    installPayments(api);
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController());

    await tapVisible(tester, find.text('المستحقات'));
    // حسن: عمليتان بمتبقٍ 5,000.00 (الأقدم أولًا). الوادي: عمليتان بمتبقٍ 3,500.00. أحمد ومطبعة النيل لا يظهران.
    expect(find.text('حسن البدري'), findsOneWidget);
    expect(find.text('مزارع · عمليتان · القيمة 11,550.00 · المدفوع 6,550.00'), findsOneWidget);
    expect(find.text('الوادي للتغليف'), findsOneWidget);
    expect(find.text('أحمد الشافعى'), findsNothing);
    expect(find.text('مطبعة النيل'), findsNothing);
    expect(find.text('شراء رمان · براد 13'), findsOneWidget);
    expect(find.text('شراء رمان · براد 14'), findsOneWidget);
    final hassanTop = tester.getTopLeft(find.text('حسن البدري')).dy;
    expect(hassanTop, lessThan(tester.getTopLeft(find.text('الوادي للتغليف')).dy));
    expect(
      tester.getTopLeft(find.text('شراء رمان · براد 13')).dy,
      lessThan(tester.getTopLeft(find.text('شراء رمان · براد 14')).dy),
    );

    await tapVisible(tester, find.text('الوادي للتغليف'));
    await tester.scrollUntilVisible(find.text('شراء تعبئة P-0005'), 200, scrollable: _mainScroll());
    expect(find.text('2 أكتوبر 2026 · 1 عنصر'), findsOneWidget);

    // فلتر المستفيد في المستحقات.
    await tester.scrollUntilVisible(find.text('المستفيد: الكل'), -200, scrollable: _mainScroll());
    await _pickFilter(tester, 'المستفيد: الكل', 'مزارعون');
    expect(find.text('الوادي للتغليف'), findsNothing);

    await tapVisible(tester, find.text('تسجيل دفعة').at(1));
    final page = tester.widget<RecordPaymentScreen>(find.byType(RecordPaymentScreen));
    expect(page.targetType, PaymentTarget.purchase);
    expect(page.targetId, 'PU-0002');
  });

  testWidgets('إلغاء الدفعة يتطلب سببًا ثم يرسل payments.cancel ويعرضها ملغاة', (tester) async {
    final api = FakeBackendApi();
    installPayments(api);
    api.handlers['payments.cancel'] = (p) => {
          'payment': paymentJson(
            id: 'PY-0004',
            no: 'D-0004',
            payeeType: 'supplier',
            payeeName: 'الوادي للتغليف',
            targetType: 'packaging',
            targetId: 'PK-0004',
            amountPiasters: 200000,
            status: 'cancelled',
            cancelReason: p['reason'] as String,
          ),
          'target': packagingJson(id: 'PK-0004', no: 'P-0004', totalPiasters: 450000),
        };
    final changes = DataChanges();
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController(), changes: changes);

    await _pickFilter(tester, 'المستفيد: الكل', 'موردون');
    await tapVisible(tester, find.text('إلغاء الدفعة'));
    expect(find.text('إلغاء الدفعة D-0004؟'), findsOneWidget);
    expect(find.text('الوادي للتغليف · 2,000.00 ج.م · شراء تعبئة · براد 14'), findsOneWidget);

    final confirm = find.descendant(of: find.byType(CancelPaymentDialog), matching: find.text('إلغاء الدفعة'));
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(find.text('اكتب سبب إلغاء الدفعة، مثل: سُجّلت مرتين بالخطأ.'), findsOneWidget);
    expect(api.count('payments.cancel'), 0);

    await tester.enterText(
      find.descendant(of: find.byType(CancelPaymentDialog), matching: find.byType(TextField)),
      '  المورد أعاد المبلغ ',
    );
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    final call = api.callsOf('payments.cancel').single;
    expect(call.payload, {'id': 'PY-0004', 'reason': 'المورد أعاد المبلغ'});
    expect(call.requestId, isNotNull);
    expect(find.byType(CancelPaymentDialog), findsNothing);
    expect(changes.revision, 1);
    expect(find.text('أُلغيت الدفعة D-0004، وعاد مبلغها 2,000.00 ج.م إلى المتبقي.'), findsOneWidget);
    // التحديث بعد الإلغاء يعيد التحميل.
    expect(api.count('payments.list'), 2);
  });

  testWidgets('رفض الخادم للإلغاء يبقي النافذة مفتوحة مع الرسالة', (tester) async {
    final api = FakeBackendApi();
    installPayments(api);
    api.errors['payments.cancel'] = const ApiException(ApiErrorCode.forbidden, 'لا تملك صلاحية «تسجيل المدفوعات».');
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController());

    await _pickFilter(tester, 'المستفيد: الكل', 'موردون');
    await tapVisible(tester, find.text('إلغاء الدفعة'));
    await tester.enterText(
      find.descendant(of: find.byType(CancelPaymentDialog), matching: find.byType(TextField)),
      'خطأ',
    );
    await tester.tap(find.descendant(of: find.byType(CancelPaymentDialog), matching: find.text('إلغاء الدفعة')));
    await tester.pumpAndSettle();
    expect(find.byType(CancelPaymentDialog), findsOneWidget);
    expect(find.text('لا تملك صلاحية «تسجيل المدفوعات».'), findsOneWidget);
  });

  testWidgets('«مشاهدة فقط» يرى القوائم دون تسجيل أو إلغاء', (tester) async {
    final api = FakeBackendApi();
    installPayments(api);
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController(user: sampleViewer()));

    expect(find.text('إجمالي المدفوع'), findsOneWidget);
    expect(find.text('تسجيل دفعة'), findsNothing);
    expect(find.text('إلغاء الدفعة'), findsNothing);

    await tapVisible(tester, find.text('المستحقات'));
    expect(find.text('حسن البدري'), findsOneWidget);
    expect(find.text('تسجيل دفعة'), findsNothing);
  });

  testWidgets('زر «تسجيل دفعة» يفتح الصفحة دون عملية محددة', (tester) async {
    final api = FakeBackendApi();
    installPayments(api);
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController(user: sampleEntry()));

    await tapVisible(tester, find.text('تسجيل دفعة'));
    final page = tester.widget<RecordPaymentScreen>(find.byType(RecordPaymentScreen));
    expect(page.targetId, isNull);
    expect(page.targetType, isNull);
  });

  testWidgets('الشاشة العريضة: جدول الدفعات والمستحقات دون فيض', (tester) async {
    final api = FakeBackendApi();
    installPayments(api);
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController(), size: wideSize);

    expect(find.text('المدفوعات'), findsOneWidget);
    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('D-0003'), findsOneWidget);
    expect(find.text('4,125.00'), findsOneWidget);
    expect(find.text('محفظة إلكترونية'), findsOneWidget);
    expect(find.text('سبب الإلغاء: سُجّلت مرتين بالخطأ'), findsOneWidget);
    expect(find.text('إلغاء الدفعة'), findsNWidgets(4));

    await tapVisible(tester, find.text('المستحقات'));
    expect(find.byType(DataTable), findsNothing);
    expect(find.text('تسجيل دفعة'), findsNWidgets(5)); // زر الصفحة + 4 عمليات
  });

  testWidgets('الحالات: خطأ التحميل ثم لا دفعات ولا مستحقات', (tester) async {
    final api = FakeBackendApi();
    installPayments(api, payments: const [], purchases: const [], packaging: const []);
    api.errors['packaging.list'] = const ApiException(ApiErrorCode.network, 'تعذّر الاتصال بالخادم.');
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController());
    expect(find.text('تعذّر تحميل المدفوعات'), findsOneWidget);

    api.errors.clear();
    await tapVisible(tester, find.text('إعادة المحاولة'));
    expect(find.text('لا توجد دفعات بعد'), findsOneWidget);
    await tapVisible(tester, find.text('المستحقات'));
    expect(find.text('لا توجد مستحقات'), findsOneWidget);
  });
}
