import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumman_calculator/core/api/api_exception.dart';
import 'package:rumman_calculator/core/sync/data_changes.dart';
import 'package:rumman_calculator/core/sync/outbox.dart';
import 'package:rumman_calculator/features/coolers/close_cooler_screen.dart';

import '../../support/fake_backend_api.dart';
import '../../support/sample_data.dart';
import '../../support/test_app.dart';
import 'coolers_test_support.dart';

FakeBackendApi _api() {
  final api = coolersApi();
  api.handlers['coolers.get'] = (_) => coolerDetailJson(
        cooler: {...cooler14Json(), 'version': 7},
        packaging: [packagingJson(), packagingJson(id: 'PK-0006', no: 'P-0006', status: 'draft', total: 120000)],
      );
  api.handlers['coolers.close'] = (p) => {
        'cooler': {...cooler14Json(), 'status': 'closed', 'closedAt': '2026-10-02T18:10:00+03:00', 'version': 8},
      };
  return api;
}

Finder _closeButton() => find.widgetWithText(FilledButton, 'تقفيل البراد');

void main() {
  setUpAll(loadAppFonts);

  for (final size in [phoneSize, wideSize]) {
    final where = size == phoneSize ? 'الهاتف' : 'الشاشة العريضة';

    testWidgets('المراجعة ثم التأكيد يرسل coolers.close بالإصدار وعدد المعلّق صفر ($where)', (tester) async {
      final api = _api();
      final changes = DataChanges();
      var bumps = 0;
      changes.addListener(() => bumps++);
      await pumpPage(tester, const CloseCoolerScreen(coolerId: 'CL-0014'), api: api, size: size, changes: changes);

      expect(find.text('الأرقام التي تُحفظ عند التقفيل'), findsOneWidget);
      expect(findRichText('40,839.40 ج.م'), findsOneWidget);
      expect(findRichText('45,339.40 ج.م'), findsOneWidget);
      expect(find.text('مسودة تعبئة غير معتمدة (P-0006)'), findsOneWidget);
      expect(find.text('متبقٍ للمزارعين 17,525.40 ج.م'), findsOneWidget);
      expect(find.textContaining('في عملية واحدة لم تُدفع بالكامل'), findsOneWidget);

      await tapVisible(tester, _closeButton());
      expect(find.text('تقفيل براد 14 · شحنة دمياط؟'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('تقفيل البراد')));
      await tester.pumpAndSettle();

      final call = api.callsOf('coolers.close').single;
      expect(call.payload, {'id': 'CL-0014', 'expectedVersion': 7, 'clientPendingCount': 0});
      expect(call.requestId, isNotNull);
      expect(bumps, 1);
      expect(find.text('تم تقفيل براد 14 · شحنة دمياط وحُفظت أرقامه.'), findsOneWidget);
      expect(find.text('الصفحة السابقة'), findsOneWidget);
    });
  }

  testWidgets('عمليات بانتظار المزامنة لهذا البراد تمنع التقفيل مع الشرح والرابط', (tester) async {
    final api = _api();
    api.errors['purchases.create'] = const ApiException(ApiErrorCode.network, 'لا يوجد اتصال');
    final outbox = Outbox(api: api, storage: MemoryOutboxStorage(), retryInterval: const Duration(hours: 1));
    await outbox.bindUser(sampleAdmin().email);
    for (final id in ['r-1', 'r-2']) {
      await outbox.submit(
        action: 'purchases.create',
        payload: {'coolerId': 'CL-0014', 'boxes': 50},
        requestId: id,
        label: 'شراء · حسن · 50 صندوق',
        coolerId: 'CL-0014',
      );
    }
    await pumpPage(tester, const CloseCoolerScreen(coolerId: 'CL-0014'), api: api, outbox: outbox);

    expect(find.text('عمليتان بانتظار المزامنة'), findsOneWidget);
    expect(find.textContaining('فلا يمكن تقفيله حتى لا تُحفظ أرقام ناقصة'), findsOneWidget);
    expect(find.text('عرض'), findsOneWidget);
    expect(tester.widget<FilledButton>(_closeButton()).onPressed, isNull);
    await tester.tap(_closeButton(), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(api.count('coolers.close'), 0);

    await tester.pumpWidget(const SizedBox());
    outbox.dispose();
  });

  testWidgets('CONFLICT: رسالة لمراجعة الأرقام المحدّثة وإعادة تحميل البراد', (tester) async {
    final api = _api();
    api.errors['coolers.close'] = const ApiException(ApiErrorCode.conflict, 'عدّل شخص آخر هذا البراد.');
    await pumpPage(tester, const CloseCoolerScreen(coolerId: 'CL-0014'), api: api);
    await tapVisible(tester, _closeButton());
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('تقفيل البراد')));
    await tester.pumpAndSettle();

    expect(find.text('لم يُقفَّل البراد'), findsOneWidget);
    expect(find.textContaining('راجع الأرقام المحدّثة ثم أعد التقفيل'), findsOneWidget);
    expect(api.count('coolers.get'), 2);
  });

  testWidgets('بلا صلاحية التقفيل: الزر معطّل مع الشرح', (tester) async {
    final api = _api();
    await pumpPage(tester, const CloseCoolerScreen(coolerId: 'CL-0014'), api: api, user: sampleViewer());
    expect(find.text('لا تملك صلاحية تقفيل البرادات'), findsOneWidget);
    expect(tester.widget<FilledButton>(_closeButton()).onPressed, isNull);
  });

  testWidgets('براد مقفّل بالفعل', (tester) async {
    final api = _api();
    api.handlers['coolers.get'] = (_) => coolerDetailJson(cooler: cooler12Json());
    await pumpPage(tester, const CloseCoolerScreen(coolerId: 'CL-0012'), api: api);
    expect(find.text('براد 12 · شحنة بورسعيد مقفّل بالفعل'), findsOneWidget);
    expect(_closeButton(), findsNothing);
  });
}
