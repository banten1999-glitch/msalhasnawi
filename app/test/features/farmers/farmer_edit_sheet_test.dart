import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumman_calculator/core/api/api_exception.dart';
import 'package:rumman_calculator/core/models/records.dart';
import 'package:rumman_calculator/core/sync/data_changes.dart';
import 'package:rumman_calculator/features/farmers/farmer_edit_sheet.dart';
import 'package:rumman_calculator/features/farmers/text_search.dart';

import '../../support/fake_auth_controller.dart';
import '../../support/fake_backend_api.dart';
import '../../support/test_app.dart';
import 'farmer_test_data.dart';

/// يفتح النموذج من زر، ويحفظ ما يعيده في [result].
class _Opener {
  Farmer? result;
  bool closed = false;

  Widget host({Farmer? farmer, String? initialName}) => Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async {
                result = await showFarmerEditSheet(context, farmer: farmer, initialName: initialName);
                closed = true;
              },
              child: const Text('فتح النموذج'),
            ),
          ),
        ),
      );
}

const _duplicateMessage =
    'يوجد مزارع مسجل بالاسم «حسن البدري» (رقم 1). اختره من القائمة، أو أكّد أنه شخص مختلف لإضافته باسم مكرر.';

Farmer _hassan() => Farmer.fromJson(
      farmerJson('FR-0001', 1, 'حسن البدري', phone: '01001234567', village: 'بني عدي', notes: 'يفضّل النقدي', version: 3),
    );

void main() {
  setUpAll(loadAppFonts);

  testWidgets('إضافة: الاسم مطلوب، والحفظ يرسل الحقول المكتوبة فقط ويعيد المزارع', (tester) async {
    final api = FakeBackendApi();
    api.handlers['farmers.create'] = (p) => {'farmer': farmerJson('FR-0009', 9, p['name'] as String, phone: '01000000000')};
    final changes = DataChanges();
    final opener = _Opener();
    await pumpTestApp(tester, opener.host(), api: api, auth: FakeAuthController(), changes: changes);
    await tester.tap(find.text('فتح النموذج'));
    await tester.pumpAndSettle();

    expect(find.text('إضافة مزارع'), findsOneWidget);
    final save = find.widgetWithText(FilledButton, 'إضافة المزارع');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await tester.enterText(fieldLabeled('اسم المزارع'), '  سعيد أبو زيد ');
    // أرقام عربية في الهاتف تُرسل لاتينية.
    await tester.enterText(fieldLabeled('رقم الهاتف (اختياري)'), '٠١٠٠٠٠٠٠٠٠٠');
    await tapVisible(tester, save);

    final call = api.callsOf('farmers.create').single;
    expect(call.payload, {'name': 'سعيد أبو زيد', 'phone': '01000000000'});
    expect(call.requestId, isNotNull);
    expect(opener.result?.id, 'FR-0009');
    expect(opener.closed, isTrue);
    expect(changes.revision, 1);
  });

  testWidgets('رقم هاتف غير صحيح يُرفض قبل الإرسال', (tester) async {
    final api = FakeBackendApi();
    final opener = _Opener();
    await pumpTestApp(tester, opener.host(initialName: 'سعيد'), api: api, auth: FakeAuthController());
    await tester.tap(find.text('فتح النموذج'));
    await tester.pumpAndSettle();

    await tester.enterText(fieldLabeled('رقم الهاتف (اختياري)'), '0100-(12');
    await tester.enterText(fieldLabeled('رقم الهاتف (اختياري)'), '++0100');
    await tapVisible(tester, find.text('إضافة المزارع'));
    expect(find.text('رقم الهاتف «++0100» غير صحيح. اكتب الأرقام فقط مثل 01001234567.'), findsOneWidget);
    expect(api.count('farmers.create'), 0);
  });

  testWidgets('اسم مكرر: رسالة الخادم تحت الاسم ثم «إضافة رغم ذلك» بـ allowDuplicate ومعرّف جديد', (tester) async {
    final api = FakeBackendApi();
    api.handlers['farmers.create'] = (p) {
      if (p['allowDuplicate'] != true) {
        throw ApiException(
          ApiErrorCode.validation,
          _duplicateMessage,
          field: 'name',
          details: {'existing': farmerJson('FR-0001', 1, 'حسن البدري')},
        );
      }
      return {'farmer': farmerJson('FR-0010', 10, p['name'] as String)};
    };
    final changes = DataChanges();
    final opener = _Opener();
    await pumpTestApp(tester, opener.host(initialName: 'حسن البدري'), api: api, auth: FakeAuthController(), changes: changes);
    await tester.tap(find.text('فتح النموذج'));
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('إضافة المزارع'));
    expect(find.text(_duplicateMessage), findsOneWidget);
    expect(find.text('إضافة رغم ذلك'), findsOneWidget);
    expect(changes.revision, 0);
    expect(opener.closed, isFalse);

    await tapVisible(tester, find.text('إضافة رغم ذلك'));
    final calls = api.callsOf('farmers.create');
    expect(calls, hasLength(2));
    expect(calls[0].payload, {'name': 'حسن البدري'});
    expect(calls[1].payload, {'name': 'حسن البدري', 'allowDuplicate': true});
    expect(calls[1].requestId, isNot(calls[0].requestId));
    expect(opener.result?.id, 'FR-0010');
    expect(changes.revision, 1);
  });

  testWidgets('تغيير الاسم بعد رفض التكرار يخفي «إضافة رغم ذلك»', (tester) async {
    final api = FakeBackendApi();
    api.errors['farmers.create'] = const ApiException(ApiErrorCode.validation, _duplicateMessage, field: 'name');
    final opener = _Opener();
    await pumpTestApp(tester, opener.host(initialName: 'حسن البدري'), api: api, auth: FakeAuthController());
    await tester.tap(find.text('فتح النموذج'));
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('إضافة المزارع'));
    expect(find.text('إضافة رغم ذلك'), findsOneWidget);
    await tester.enterText(fieldLabeled('اسم المزارع'), 'حسن البدري الصغير');
    await tester.pumpAndSettle();
    expect(find.text('إضافة رغم ذلك'), findsNothing);
    expect(find.text(_duplicateMessage), findsNothing);
  });

  testWidgets('إعادة المحاولة بعد خطأ شبكة ترسل requestId نفسه', (tester) async {
    final api = FakeBackendApi();
    api.errors['farmers.create'] = const ApiException(ApiErrorCode.network, 'انقطع الاتصال بالخادم.');
    final opener = _Opener();
    await pumpTestApp(tester, opener.host(initialName: 'سعيد'), api: api, auth: FakeAuthController());
    await tester.tap(find.text('فتح النموذج'));
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('إضافة المزارع'));
    expect(find.text('انقطع الاتصال بالخادم.'), findsOneWidget);
    api.errors.remove('farmers.create');
    api.handlers['farmers.create'] = (p) => {'farmer': farmerJson('FR-0011', 11, 'سعيد')};
    await tapVisible(tester, find.text('إضافة المزارع'));
    final calls = api.callsOf('farmers.create');
    expect(calls, hasLength(2));
    expect(calls[1].requestId, calls[0].requestId);
    expect(opener.result?.id, 'FR-0011');
  });

  testWidgets('تعديل: يرسل الحقول المعدّلة فقط مع expectedVersion، والمسح نص فارغ', (tester) async {
    final api = FakeBackendApi();
    api.handlers['farmers.update'] = (p) => {
          'farmer': farmerJson('FR-0001', 1, 'حسن البدري', village: 'منفلوط', notes: 'يفضّل النقدي', version: 4),
        };
    final changes = DataChanges();
    final opener = _Opener();
    await pumpTestApp(tester, opener.host(farmer: _hassan()), api: api, auth: FakeAuthController(), changes: changes);
    await tester.tap(find.text('فتح النموذج'));
    await tester.pumpAndSettle();

    expect(find.text('تعديل بيانات المزارع'), findsOneWidget);
    expect(find.text('مزارع رقم 1'), findsOneWidget);
    final save = find.widgetWithText(FilledButton, 'حفظ التغييرات');
    expect(tester.widget<FilledButton>(save).onPressed, isNull); // لا تغيير بعد

    await tester.enterText(fieldLabeled('القرية / المنطقة (اختياري)'), ' منفلوط ');
    await tester.enterText(fieldLabeled('رقم الهاتف (اختياري)'), '');
    await tapVisible(tester, save);

    final call = api.callsOf('farmers.update').single;
    expect(call.payload, {'id': 'FR-0001', 'expectedVersion': 3, 'phone': '', 'village': 'منفلوط'});
    expect(opener.result?.version, 4);
    expect(changes.revision, 1);
  });

  testWidgets('تعديل: تعارض الإصدار يعرض الرسالة، و«تحديث البيانات» يدمج السجل الحالي', (tester) async {
    final api = FakeBackendApi();
    var conflict = true;
    api.handlers['farmers.update'] = (p) {
      if (conflict) {
        conflict = false;
        throw ApiException(
          ApiErrorCode.conflict,
          'عدّل مستخدم آخر بيانات هذا المزارع بعد أن فتحته.',
          field: 'expectedVersion',
          details: {
            'currentVersion': 5,
            'current': farmerJson('FR-0001', 1, 'حسن البدري', phone: '01222222222', village: 'بني عدي', version: 5),
          },
        );
      }
      return {'farmer': farmerJson('FR-0001', 1, 'حسن البدري', phone: '01222222222', village: 'ديروط', version: 6)};
    };
    final opener = _Opener();
    await pumpTestApp(tester, opener.host(farmer: _hassan()), api: api, auth: FakeAuthController());
    await tester.tap(find.text('فتح النموذج'));
    await tester.pumpAndSettle();

    await tester.enterText(fieldLabeled('القرية / المنطقة (اختياري)'), 'ديروط');
    await tapVisible(tester, find.text('حفظ التغييرات'));
    expect(find.text('عدّل شخص آخر هذا السجل، حدّث وأعد المحاولة.'), findsOneWidget);

    await tapVisible(tester, find.text('تحديث البيانات'));
    // الهاتف أخذ قيمة الخادم الجديدة، والقرية بقيت كما كتبها المستخدم.
    expect(find.text('01222222222'), findsOneWidget);
    expect(find.text('ديروط'), findsOneWidget);
    expect(find.text('حُدّثت البيانات من الملف. راجع الحقول ثم احفظ مرة أخرى.'), findsOneWidget);

    await tapVisible(tester, find.text('حفظ التغييرات'));
    final calls = api.callsOf('farmers.update');
    expect(calls, hasLength(2));
    expect(calls[1].payload, {'id': 'FR-0001', 'expectedVersion': 5, 'village': 'ديروط'});
    expect(calls[1].requestId, isNot(calls[0].requestId));
    expect(opener.result?.version, 6);
  });

  testWidgets('تعديل الاسم إلى اسم مكرر: «حفظ رغم ذلك» يرسل allowDuplicate', (tester) async {
    final api = FakeBackendApi();
    api.handlers['farmers.update'] = (p) {
      if (p['allowDuplicate'] != true) {
        throw const ApiException(ApiErrorCode.validation, _duplicateMessage, field: 'name');
      }
      return {'farmer': farmerJson('FR-0002', 2, 'حسن البدري', version: 2)};
    };
    final opener = _Opener();
    final ahmed = Farmer.fromJson(farmerJson('FR-0002', 2, 'أحمد الشافعى'));
    await pumpTestApp(tester, opener.host(farmer: ahmed), api: api, auth: FakeAuthController());
    await tester.tap(find.text('فتح النموذج'));
    await tester.pumpAndSettle();

    await tester.enterText(fieldLabeled('اسم المزارع'), 'حسن البدري');
    await tapVisible(tester, find.text('حفظ التغييرات'));
    await tapVisible(tester, find.text('حفظ رغم ذلك'));
    final calls = api.callsOf('farmers.update');
    expect(calls[1].payload, {'id': 'FR-0002', 'expectedVersion': 1, 'name': 'حسن البدري', 'allowDuplicate': true});
    expect(opener.result?.name, 'حسن البدري');
  });

  testWidgets('الضغط المزدوج على الحفظ يرسل طلبًا واحدًا', (tester) async {
    final api = FakeBackendApi()..delay = const Duration(milliseconds: 300);
    api.handlers['farmers.create'] = (p) => {'farmer': farmerJson('FR-0012', 12, 'سعيد')};
    final opener = _Opener();
    await pumpTestApp(tester, opener.host(initialName: 'سعيد'), api: api, auth: FakeAuthController());
    await tester.tap(find.text('فتح النموذج'));
    await tester.pumpAndSettle();

    final save = find.text('إضافة المزارع');
    await tester.tap(save);
    await tester.tap(save, warnIfMissed: false);
    await tester.pump();
    expect(find.text('جارٍ الحفظ'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(api.count('farmers.create'), 1);
  });

  testWidgets('الهاتف والشاشة العريضة دون فيض', (tester) async {
    for (final size in [phoneSize, wideSize]) {
      final api = FakeBackendApi();
      final opener = _Opener();
      await pumpTestApp(tester, opener.host(farmer: _hassan()), api: api, auth: FakeAuthController(), size: size);
      await tester.tap(find.text('فتح النموذج'));
      await tester.pumpAndSettle();
      expect(find.byType(FarmerEditor), findsOneWidget);
      expect(find.byType(Dialog), size == wideSize ? findsOneWidget : findsNothing);
      await tester.tap(find.byTooltip('إغلاق'));
      await tester.pumpAndSettle();
      expect(opener.closed, isTrue);
      expect(opener.result, isNull);
    }
  });

  test('normalizeArabic يطابق تطبيع الخادم، وnormalizePhone يقبل الأرقام العربية', () {
    expect(normalizeArabic('  أحمدُ   الشافعى '), 'احمد الشافعي');
    expect(normalizeArabic('فاطمة مؤمن هانئ'), 'فاطمه مومن هاني');
    expect(normalizeArabic('إبراهيم آل ـعـلي'), 'ابراهيم ال علي');
    expect(normalizeArabic('٠١٢۳'), '0123');
    expect(normalizePhone('٠١٠ ١٢٣-٤٥٦٧'), '010 123-4567');
    expect(normalizePhone(''), '');
    expect(normalizePhone('abc'), isNull);
    expect(normalizePhone('1' * 21), isNull);
  });
}
