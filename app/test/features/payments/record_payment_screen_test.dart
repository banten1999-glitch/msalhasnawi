import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumman_calculator/app/routes.dart';
import 'package:rumman_calculator/core/api/api_exception.dart';
import 'package:rumman_calculator/core/models/records.dart';
import 'package:rumman_calculator/core/sync/data_changes.dart';
import 'package:rumman_calculator/core/sync/outbox.dart';
import 'package:rumman_calculator/features/payments/record_payment_screen.dart';

import '../../support/fake_auth_controller.dart';
import '../../support/fake_backend_api.dart';
import '../../support/sample_data.dart';
import '../../support/test_app.dart';
import '../farmers/farmer_test_data.dart';
import 'payment_test_data.dart';

/// صفحة تفتح «تسجيل دفعة» عبر AppRoutes كما تفعل الأقسام الأخرى، فيظهر إشعار الحفظ عليها بعد الرجوع.
Widget _host({PaymentTarget? type, String? id}) => Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => AppRoutes.recordPayment(context, targetType: type, targetId: id),
            child: const Text('فتح الدفعة'),
          ),
        ),
      ),
    );

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('فتح الدفعة'));
  await tester.pumpAndSettle();
}

Finder _amount() => fieldLabeled('المبلغ (ج.م)');

Finder _save() => find.text('حفظ الدفعة');

const _offline = ApiException(
  ApiErrorCode.network,
  'لا يوجد اتصال بالإنترنت. تحقق من الشبكة ثم أعد المحاولة؛ لن تُسجَّل العملية مرتين.',
);

void main() {
  setUpAll(loadAppFonts);

  testWidgets('عملية شراء محددة: ملخص المستفيد والبراد والقيمة والمدفوع والمتبقي', (tester) async {
    final api = FakeBackendApi();
    installPayments(api);
    await pumpTestApp(tester, _host(type: PaymentTarget.purchase, id: 'PU-0001'), api: api, auth: FakeAuthController());
    await _open(tester);

    // لا يوجد purchases.get: تُقرأ من القائمة مع الملغاة لتمييزها.
    expect(api.callsOf('purchases.list').single.payload, {'includeCancelled': true});
    expect(find.text('تسجيل دفعة'), findsOneWidget);
    expect(find.text('حسن البدري'), findsOneWidget);
    expect(find.text('مزارع · شراء رمان · براد 14'), findsOneWidget);
    expect(find.text('8,250.00'), findsOneWidget);
    expect(find.text('5,000.00'), findsOneWidget);
    expect(find.text('3,250.00'), findsOneWidget);
    expect(find.text('المتبقي 3,250.00 ج.م · يقبل الأرقام العربية واللاتينية'), findsOneWidget);
    expect(find.textContaining('يمكن تسجيل الدفعة حتى لو كان البراد مقفّلًا'), findsOneWidget);
    // العملية محددة مسبقًا: لا «تغيير».
    expect(find.text('تغيير'), findsNothing);
    expect(find.text('الآن (وقت الحفظ)'), findsOneWidget);
  });

  testWidgets('مبلغ أكبر من المتبقي يُمنع قبل الإرسال', (tester) async {
    final api = FakeBackendApi();
    installPayments(api);
    await pumpTestApp(tester, _host(type: PaymentTarget.purchase, id: 'PU-0001'), api: api, auth: FakeAuthController());
    await _open(tester);

    await tester.enterText(_amount(), '3250.01');
    await tester.pumpAndSettle();
    const error = '«المبلغ» (3,250.01 ج.م) أكبر من المتبقي (3,250.00 ج.م). اكتب مبلغًا لا يزيد على المتبقي.';
    expect(find.text(error), findsOneWidget);
    await tapVisible(tester, _save());
    expect(find.text(error), findsOneWidget);

    await tester.enterText(_amount(), '0');
    await tapVisible(tester, _save());
    expect(find.text('المبلغ يجب أن يكون أكبر من صفر.'), findsOneWidget);

    await tester.enterText(_amount(), '');
    await tapVisible(tester, _save());
    expect(find.text('اكتب مبلغ الدفعة بالجنيه، مثل 1500 أو 1500.50.'), findsOneWidget);

    await tester.enterText(_amount(), '12,5');
    await tapVisible(tester, _save());
    expect(find.text('المبلغ «12,5» غير صحيح. اكتب أرقامًا فقط مثل 1500 أو 1500.50.'), findsOneWidget);

    expect(api.count('payments.create'), 0);
  });

  testWidgets('«كامل المتبقي» ثم الحفظ: تُرسل الدفعة وتظهر «تم الحفظ في الملف» ويُغلق النموذج', (tester) async {
    final api = FakeBackendApi();
    installPayments(api);
    api.handlers['payments.create'] = (p) => createdPayment(p);
    final changes = DataChanges();
    await pumpTestApp(
      tester,
      _host(type: PaymentTarget.purchase, id: 'PU-0001'),
      api: api,
      auth: FakeAuthController(),
      changes: changes,
    );
    await _open(tester);

    await tapVisible(tester, find.text('كامل المتبقي'));
    expect(tester.widget<TextField>(_amount()).controller!.text, '3250');
    await tapVisible(tester, _save());

    final call = api.callsOf('payments.create').single;
    expect(call.payload, {
      'targetType': 'purchase',
      'targetId': 'PU-0001',
      'amountPiasters': 325000,
      'method': 'cash',
    });
    expect(call.requestId, isNotNull);
    expect(changes.revision, 1);
    expect(find.byType(RecordPaymentScreen), findsNothing);
    expect(find.text('تم الحفظ في الملف · الدفعة D-0006'), findsOneWidget);
  });

  testWidgets('أرقام عربية بعلامة عشرية عربية، وطريقة الدفع والملاحظات في الحمولة', (tester) async {
    final api = FakeBackendApi();
    installPayments(api);
    api.handlers['payments.create'] = (p) => createdPayment(p);
    await pumpTestApp(tester, _host(type: PaymentTarget.purchase, id: 'PU-0001'), api: api, auth: FakeAuthController());
    await _open(tester);

    await tester.enterText(_amount(), '١٥٠٠٫٥');
    await tapVisible(tester, find.text('تحويل بنكي'));
    await tester.enterText(fieldLabeled('ملاحظات (اختياري)'), '  حوالة على حساب ابنه ');
    await tapVisible(tester, _save());

    expect(api.callsOf('payments.create').single.payload, {
      'targetType': 'purchase',
      'targetId': 'PU-0001',
      'amountPiasters': 150050,
      'method': 'bank',
      'notes': 'حوالة على حساب ابنه',
    });
  });

  testWidgets('الضغط المزدوج على «حفظ الدفعة» يرسل payments.create مرة واحدة', (tester) async {
    final api = FakeBackendApi()..delay = const Duration(milliseconds: 300);
    installPayments(api);
    api.handlers['payments.create'] = (p) => createdPayment(p);
    await pumpTestApp(tester, _host(type: PaymentTarget.purchase, id: 'PU-0001'), api: api, auth: FakeAuthController());
    await _open(tester);

    await tester.enterText(_amount(), '1000');
    await tester.pumpAndSettle();
    await tester.ensureVisible(_save());
    await tester.pumpAndSettle();
    await tester.tap(_save());
    await tester.tap(_save(), warnIfMissed: false);
    await tester.pump();
    expect(find.text('جارٍ الحفظ'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(api.count('payments.create'), 1);
  });

  testWidgets('دون اتصال: تُحفظ على الجهاز «بانتظار المزامنة» بالمعرّف نفسه والبراد المرتبط', (tester) async {
    final api = FakeBackendApi();
    installPayments(api);
    api.errors['payments.create'] = _offline;
    final outbox = Outbox(api: api, storage: MemoryOutboxStorage(), retryInterval: const Duration(hours: 1));
    await outbox.bindUser(sampleAdmin().email);
    final changes = DataChanges();
    await pumpTestApp(
      tester,
      _host(type: PaymentTarget.purchase, id: 'PU-0001'),
      api: api,
      auth: FakeAuthController(),
      outbox: outbox,
      changes: changes,
    );
    await _open(tester);

    await tester.enterText(_amount(), '2000');
    await tapVisible(tester, _save());

    expect(find.text('حُفظت على الجهاز — بانتظار المزامنة'), findsOneWidget);
    expect(find.byType(RecordPaymentScreen), findsNothing);
    expect(changes.revision, 1);
    final entry = outbox.entries.single;
    expect(entry.action, 'payments.create');
    expect(entry.requestId, api.callsOf('payments.create').single.requestId);
    expect(entry.label, 'دفعة · حسن البدري · 2,000.00 ج.م');
    expect(entry.coolerId, 'CL-0014');
    expect(entry.payload['amountPiasters'], 200000);

    // فتح الصفحة مرة أخرى لنفس العملية: الحد الأقصى ينقص بالدفعة المعلّقة.
    await _open(tester);
    expect(find.textContaining('بانتظار المزامنة بمبلغ 2,000.00 ج.م، فالحد الأقصى الآن 1,250.00 ج.م'), findsOneWidget);
    await tester.enterText(_amount(), '1300');
    await tester.pumpAndSettle();
    expect(find.textContaining('أكبر من المتبقي (1,250.00 ج.م)'), findsOneWidget);

    outbox.dispose();
  });

  testWidgets('دون قائمة مزامنة مربوطة: خطأ الاتصال يظهر وتبقى البيانات، وإعادة المحاولة بالمعرّف نفسه', (tester) async {
    final api = FakeBackendApi();
    installPayments(api);
    api.errors['payments.create'] = _offline;
    await pumpTestApp(tester, _host(type: PaymentTarget.purchase, id: 'PU-0001'), api: api, auth: FakeAuthController());
    await _open(tester);

    await tester.enterText(_amount(), '2000');
    await tapVisible(tester, _save());
    expect(find.text(_offline.message), findsOneWidget);
    expect(tester.widget<TextField>(_amount()).controller!.text, '2000');

    api.errors.remove('payments.create');
    api.handlers['payments.create'] = (p) => createdPayment(p);
    await tapVisible(tester, _save());
    final calls = api.callsOf('payments.create');
    expect(calls, hasLength(2));
    expect(calls[1].requestId, calls[0].requestId);
  });

  testWidgets('رفض الخادم بحقل يظهر تحت الحقل، ويحدّث المتبقي من الرد', (tester) async {
    final api = FakeBackendApi();
    installPayments(api);
    api.errors['payments.create'] = const ApiException(
      ApiErrorCode.validation,
      '«المبلغ» (3,000.00 ج.م) أكبر من المتبقي (1,000.00 ج.م). اكتب مبلغًا لا يزيد على المتبقي.',
      field: 'amountPiasters',
      details: {'remainingPiasters': 100000},
    );
    await pumpTestApp(tester, _host(type: PaymentTarget.purchase, id: 'PU-0001'), api: api, auth: FakeAuthController());
    await _open(tester);

    await tester.enterText(_amount(), '3000');
    await tapVisible(tester, _save());
    expect(
      find.text('«المبلغ» (3,000.00 ج.م) أكبر من المتبقي (1,000.00 ج.م). اكتب مبلغًا لا يزيد على المتبقي.'),
      findsOneWidget,
    );
    expect(find.text('1,000.00'), findsOneWidget); // المتبقي في الملخص بعد التحديث
    expect(find.text('7,250.00'), findsOneWidget); // المدفوع بعد التحديث

    api.errors['payments.create'] = const ApiException(
      ApiErrorCode.validation,
      '«تاريخ الدفعة» بتنسيق غير صحيح.',
      field: 'paidAt',
    );
    await tester.enterText(_amount(), '500');
    await tapVisible(tester, _save());
    expect(find.text('«تاريخ الدفعة» بتنسيق غير صحيح.'), findsOneWidget);
  });

  testWidgets('دون عملية محددة: اختيار المزارع بالبحث ثم عملية الشراء', (tester) async {
    final api = FakeBackendApi();
    installPayments(api);
    api.handlers['payments.create'] = (p) => createdPayment(p);
    await pumpTestApp(tester, _host(), api: api, auth: FakeAuthController());
    await _open(tester);

    expect(api.callsOf('purchases.list').single.payload, isEmpty);
    expect(api.callsOf('packaging.list').single.payload, {'status': 'approved'});
    expect(find.text('لمن الدفعة؟'), findsOneWidget);
    // أحمد مدفوع بالكامل فلا يظهر.
    expect(find.text('أحمد الشافعى'), findsNothing);
    await tester.enterText(find.byType(TextField).first, 'حسن البدرى');
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('حسن البدري'));

    expect(find.text('اختر عملية الشراء'), findsOneWidget);
    expect(find.text('شراء رمان · براد 13'), findsOneWidget);
    await tapVisible(tester, find.text('شراء رمان · براد 13'));

    expect(find.text('1,750.00'), findsOneWidget); // المتبقي
    await tapVisible(tester, find.text('كامل المتبقي'));
    await tapVisible(tester, _save());
    expect(api.callsOf('payments.create').single.payload, {
      'targetType': 'purchase',
      'targetId': 'PU-0002',
      'amountPiasters': 175000,
      'method': 'cash',
    });
  });

  testWidgets('دون عملية محددة: مورد تعبئة → شراء تعبئة معتمد، و«تغيير» يعيد القائمة', (tester) async {
    final api = FakeBackendApi();
    installPayments(api);
    api.errors['payments.create'] = _offline;
    final outbox = Outbox(api: api, storage: MemoryOutboxStorage(), retryInterval: const Duration(hours: 1));
    await outbox.bindUser(sampleAdmin().email);
    await pumpTestApp(tester, _host(), api: api, auth: FakeAuthController(), outbox: outbox);
    await _open(tester);

    await tapVisible(tester, find.text('مورد تعبئة'));
    expect(find.text('تُسجَّل الدفعات لمشتريات التعبئة المعتمدة فقط.'), findsOneWidget);
    expect(find.text('مطبعة النيل'), findsNothing); // مدفوع بالكامل
    expect(find.text('شراء تعبئة P-0004 · براد 14 · فاتورة 77 · 3 عناصر'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'P-0005');
    await tester.pumpAndSettle();
    expect(find.textContaining('P-0004'), findsNothing);
    await tapVisible(tester, find.text('الوادي للتغليف'));
    expect(find.text('مورد · شراء تعبئة P-0005'), findsOneWidget);

    await tapVisible(tester, find.text('تغيير'));
    expect(find.text('لمن الدفعة؟'), findsOneWidget);
    await tapVisible(tester, find.text('الوادي للتغليف').first);

    await tester.enterText(_amount(), '250');
    await tapVisible(tester, _save());
    final entry = outbox.entries.single;
    expect(entry.payload['targetType'], 'packaging');
    // شراء التعبئة لا يمنع تقفيل البراد: لا براد مرتبط في قائمة المزامنة.
    expect(entry.coolerId, isNull);
    outbox.dispose();
  });

  testWidgets('شراء تعبئة مسودة لا يقبل دفعات', (tester) async {
    final api = FakeBackendApi();
    installPayments(api, packaging: [
      packagingJson(id: 'PK-0007', no: 'P-0007', supplier: 'الوادي للتغليف', status: 'draft', totalPiasters: 50000),
    ]);
    await pumpTestApp(tester, _host(type: PaymentTarget.packaging, id: 'PK-0007'), api: api, auth: FakeAuthController());
    await _open(tester);

    expect(api.callsOf('packaging.get').single.payload, {'id': 'PK-0007'});
    expect(find.text('شراء التعبئة P-0007 ما زال مسودة. اعتمده أولًا ثم سجّل الدفعة.'), findsOneWidget);
    expect(_save(), findsNothing);
  });

  testWidgets('عملية شراء ملغاة أو مدفوعة بالكامل لا تقبل دفعات', (tester) async {
    final api = FakeBackendApi();
    installPayments(api, purchases: [
      ...paymentPurchasesJson(),
      {
        ...purchaseJson(id: 'PU-0009', farmerId: 'FR-0001', farmerName: 'حسن البدري', valuePiasters: 10000),
        'status': 'cancelled',
        'cancelReason': 'وزن خاطئ',
      },
    ]);
    await pumpTestApp(tester, _host(id: 'PU-0009'), api: api, auth: FakeAuthController());
    await _open(tester);
    expect(find.text('عملية الشراء هذه ملغاة (وزن خاطئ)، فلا يمكن الدفع لها.'), findsOneWidget);
    expect(_save(), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await pumpTestApp(tester, _host(id: 'PU-0003'), api: api, auth: FakeAuthController());
    await _open(tester);
    expect(find.text('هذه العملية مدفوعة بالكامل. لا يوجد مبلغ متبقٍ للدفع.'), findsOneWidget);
  });

  testWidgets('«مشاهدة فقط» لا يرى نموذج الدفعة', (tester) async {
    final api = FakeBackendApi();
    installPayments(api);
    await pumpTestApp(tester, _host(id: 'PU-0001'), api: api, auth: FakeAuthController(user: sampleViewer()));
    await _open(tester);

    expect(find.text('لا تملك صلاحية تسجيل الدفعات'), findsOneWidget);
    expect(_save(), findsNothing);
    expect(api.count('purchases.list'), 0);
  });

  testWidgets('الهاتف والشاشة العريضة دون فيض', (tester) async {
    for (final size in [phoneSize, wideSize]) {
      final api = FakeBackendApi();
      installPayments(api);
      await pumpTestApp(tester, _host(id: 'PK-0004'), api: api, auth: FakeAuthController(), size: size);
      await _open(tester);
      expect(find.text('الوادي للتغليف'), findsOneWidget);
      expect(find.text('مورد · شراء تعبئة P-0004 · براد 14'), findsOneWidget);
      expect(_save(), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      await pumpTestApp(tester, _host(), api: api, auth: FakeAuthController(), size: size);
      await _open(tester);
      expect(find.text('لمن الدفعة؟'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });
}
