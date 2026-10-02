import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumman_calculator/core/api/api_exception.dart';
import 'package:rumman_calculator/core/models/user.dart';
import 'package:rumman_calculator/features/settings/settings_screen.dart';
import 'package:rumman_calculator/features/settings/user_edit_sheet.dart';
import 'package:rumman_calculator/ui/app_button.dart';

import '../support/fake_auth_controller.dart';
import '../support/fake_backend_api.dart';
import '../support/sample_data.dart';
import '../support/test_app.dart';

Widget _screen() => const Scaffold(body: SettingsScreen(initialTab: SettingsTab.users));

Finder _field(String label) => find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
      matching: find.byType(TextField),
    );

Future<void> _tapVisible(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Finder _inEditor(Finder f) => find.descendant(of: find.byType(UserEditor), matching: f);

void main() {
  setUpAll(loadAppFonts);

  testWidgets('قائمة المستخدمين: الأدوار والحالات و«(أنت)» وقاعدة المدير الأساسي', (tester) async {
    final api = FakeBackendApi();
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController());

    expect(api.count('users.list'), 1);
    expect(find.text('المستخدمون (5)'), findsOneWidget);
    expect(find.text('4 نشط · 1 معطّل'), findsOneWidget);
    expect(findRichText('محمد الحسناوي (أنت)'), findsOneWidget);
    expect(findRichText('كريم عبد الله (أنت)'), findsNothing);
    expect(find.text('karim.abdallah.eg@gmail.com'), findsOneWidget);
    expect(find.text('معطّل'), findsOneWidget);
    expect(find.text('مشاهدة فقط'), findsWidgets);
    expect(find.text('المدير الأساسي المحدد في إعدادات الخادم، لذا لا يمكن تعطيله أو تغيير دوره.'), findsOneWidget);
    expect(find.text('يتحقق الخادم من هذه الصلاحيات مع كل طلب قراءة أو حفظ. إخفاء الأزرار في التطبيق للتوضيح فقط.'),
        findsOneWidget);
  });

  testWidgets('آخر مدير نشط (غير الأساسي) تظهر عليه القاعدة', (tester) async {
    final onlyAdmin = makeUser('US-0001', 'boss@gmail.com', 'المدير الوحيد', UserRole.admin);
    final api = FakeBackendApi(users: [onlyAdmin, sampleEntry()]);
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController(user: onlyAdmin));

    expect(find.text('آخر مدير نشط، لذا لا يمكن تعطيله أو تغيير دوره. أضف مديرًا آخر أولًا.'), findsOneWidget);
  });

  testWidgets('إضافة مستخدم: التحقق من البريد والاسم قبل الإرسال', (tester) async {
    final api = FakeBackendApi();
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController());

    // فارغ
    await _tapVisible(tester, find.text('إضافة إلى القائمة المسموح بها'));
    expect(find.text('اكتب بريد Gmail للمستخدم الجديد، مثل name@gmail.com.'), findsOneWidget);
    expect(find.text('اكتب اسم المستخدم كما سيظهر في السجلات، مثل كريم عبد الله.'), findsOneWidget);

    // غير صحيح
    await tester.enterText(_field('بريد Gmail'), 'karim.gmail.com');
    await tester.enterText(_field('الاسم'), 'كريم');
    await _tapVisible(tester, find.text('إضافة إلى القائمة المسموح بها'));
    expect(find.text('البريد «karim.gmail.com» غير صحيح. اكتب بريد Gmail كاملًا مثل name@gmail.com.'), findsOneWidget);

    // مكرر (بحروف كبيرة ومسافات)
    await tester.enterText(_field('بريد Gmail'), ' Karim.Abdallah.EG@gmail.com ');
    await _tapVisible(tester, find.text('إضافة إلى القائمة المسموح بها'));
    expect(find.textContaining('موجود في القائمة بالفعل'), findsOneWidget);

    expect(api.count('users.add'), 0);
  });

  testWidgets('إضافة مستخدم صحيح ترسل البريد والاسم والدور وتضيفه للقائمة', (tester) async {
    final api = FakeBackendApi();
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController());

    await tester.enterText(_field('بريد Gmail'), ' Nour.Hassan@Gmail.com');
    await tester.enterText(_field('الاسم'), 'نور حسن');
    await _tapVisible(tester, find.text('مشاهدة فقط').first);
    await _tapVisible(tester, find.text('إضافة إلى القائمة المسموح بها'));

    expect(api.callsOf('users.add').single.payload, {'email': 'nour.hassan@gmail.com', 'name': 'نور حسن', 'role': 'viewer'});
    expect(find.text('المستخدمون (6)'), findsOneWidget);
    expect(find.text('nour.hassan@gmail.com'), findsOneWidget);
    expect(find.textContaining('أُضيف نور حسن'), findsOneWidget);
  });

  testWidgets('رفض الخادم للبريد يظهر تحت حقل البريد', (tester) async {
    final api = FakeBackendApi()
      ..addUserError = const ApiException(
        ApiErrorCode.validation,
        'البريد «x@y.co» مسجّل بالفعل لمستخدم آخر. ابحث عنه في القائمة وعدّله بدل إضافته مرة أخرى.',
        field: 'email',
      );
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController());

    await tester.enterText(_field('بريد Gmail'), 'x@y.co');
    await tester.enterText(_field('الاسم'), 'س');
    await _tapVisible(tester, find.text('إضافة إلى القائمة المسموح بها'));
    expect(api.count('users.add'), 1);
    final emailField = tester.widget<TextField>(_field('بريد Gmail'));
    expect(emailField.decoration?.errorText, contains('مسجّل بالفعل لمستخدم آخر'));
  });

  testWidgets('تعديل الصلاحيات: ست صلاحيات لموظف الإدخال وإعادة الفتح مقفلة للمدير', (tester) async {
    final api = FakeBackendApi();
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController());

    await _tapVisible(tester, find.text('كريم عبد الله'));
    expect(find.byType(UserEditor), findsOneWidget);
    for (final label in const [
      'إضافة المزارعين',
      'تسجيل مشتريات الرمان',
      'تعديل عمليات سجّلها غيره',
      'تسجيل المدفوعات',
      'مشتريات التعبئة والتغليف',
      'تقفيل البرادات',
    ]) {
      expect(_inEditor(find.text(label)), findsOneWidget, reason: label);
    }
    expect(_inEditor(find.text('إعادة فتح البرادات')), findsOneWidget);
    expect(_inEditor(find.text('للمدير فقط')), findsOneWidget);
    expect(_inEditor(find.text('يتحقق الخادم من هذه الصلاحيات مع كل طلب قراءة أو حفظ. إخفاء الأزرار في التطبيق للتوضيح فقط.')),
        findsOneWidget);

    // لا تغيير ⇒ الحفظ معطّل.
    AppButton save() => tester.widget<AppButton>(
          find.ancestor(of: _inEditor(find.text('حفظ التغييرات')), matching: find.byType(AppButton)),
        );
    expect(save().onPressed, isNull);

    // منح «تعديل عمليات سجّلها غيره» ثم الحفظ.
    await _tapVisible(tester, _inEditor(find.text('تعديل عمليات سجّلها غيره')));
    expect(save().onPressed, isNotNull);
    await _tapVisible(tester, _inEditor(find.text('حفظ التغييرات')));

    final payload = api.callsOf('users.update').single.payload;
    expect(payload['id'], 'US-0002');
    expect(payload['expectedVersion'], 5);
    expect((payload['permissions'] as Map)['editOthers'], isTrue);
    expect((payload['permissions'] as Map)['closeCoolers'], isTrue);
    expect(payload.containsKey('role'), isFalse);
    expect(find.byType(UserEditor), findsNothing);
    expect(find.text('حُفظت تغييرات كريم عبد الله.'), findsOneWidget);
  });

  testWidgets('خطأ «آخر مدير نشط» من الخادم يظهر بجانب مفتاح الحالة', (tester) async {
    final me = makeUser('US-0001', 'boss@gmail.com', 'مدير أول', UserRole.admin);
    final other = makeUser('US-0006', 'nadia.admin@gmail.com', 'نادية فؤاد', UserRole.admin, version: 2);
    const message = 'لا يمكن حفظ التغيير لأن «نادية فؤاد» هو آخر مدير نشط. أضف مديرًا آخر أو فعّله أولًا.';
    final api = FakeBackendApi(users: [me, other])
      ..updateUserError = const ApiException(ApiErrorCode.validation, message, field: 'status');
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController(user: me));

    // في القائمة مديران نشطان، فلا قفل مسبق؛ الخادم هو من يرفض.
    await _tapVisible(tester, find.text('نادية فؤاد'));
    await _tapVisible(tester, _inEditor(find.text('الحساب نشط')));
    await _tapVisible(tester, _inEditor(find.text('حفظ التغييرات')));

    expect(api.callsOf('users.update').single.payload, {'id': 'US-0006', 'expectedVersion': 2, 'status': 'disabled'});
    expect(find.byType(UserEditor), findsOneWidget);
    expect(_inEditor(find.text(message)), findsOneWidget);

    // الرسالة تحت مفتاح «الحساب نشط» مباشرة.
    final switchBottom = tester.getBottomLeft(_inEditor(find.text('التعطيل يمنع الدخول فورًا دون حذف سجله'))).dy;
    final errorTop = tester.getTopLeft(_inEditor(find.text(message))).dy;
    final nextPermTop = tester.getTopLeft(_inEditor(find.text('إضافة المزارعين'))).dy;
    expect(errorTop, greaterThan(switchBottom));
    expect(errorTop, lessThan(nextPermTop));
  });

  testWidgets('خطأ الدور من الخادم يظهر تحت اختيار الدور، وتعارض الإصدار يعرض البيانات الحالية', (tester) async {
    final api = FakeBackendApi()
      ..updateUserError = const ApiException(
        ApiErrorCode.validation,
        'قيمة «الدور» غير صحيحة. اختر «مدير» أو «موظف إدخال» أو «مشاهدة فقط».',
        field: 'role',
      );
    await pumpTestApp(tester, _screen(), api: api, auth: FakeAuthController());

    await _tapVisible(tester, find.text('يوسف ناصر'));
    await _tapVisible(tester, _inEditor(find.text('مشاهدة فقط')));
    await _tapVisible(tester, _inEditor(find.text('حفظ التغييرات')));
    expect(_inEditor(find.textContaining('قيمة «الدور» غير صحيحة')), findsOneWidget);

    final fresh = makeUser('US-0003', 'youssef.nasser.farm@gmail.com', 'يوسف ناصر الدين', UserRole.entry, version: 7);
    api.updateUserError = ApiException(
      ApiErrorCode.conflict,
      'عدّل مستخدم آخر بيانات هذا المستخدم بعد أن فتحتها. راجع البيانات الحالية ثم أعد الحفظ.',
      field: 'expectedVersion',
      details: {'currentVersion': 7, 'current': fresh.toJson()},
    );
    await _tapVisible(tester, _inEditor(find.text('حفظ التغييرات')));
    expect(_inEditor(find.textContaining('عدّل مستخدم آخر بيانات هذا المستخدم')), findsOneWidget);
    await _tapVisible(tester, _inEditor(find.text('عرض البيانات الحالية')));
    expect(_inEditor(find.text('يوسف ناصر الدين')), findsOneWidget);
  });

  testWidgets('تعديل حسابي يحدّث بيانات الدخول عبر auth.updateUser', (tester) async {
    final api = FakeBackendApi();
    final auth = FakeAuthController();
    await pumpTestApp(tester, _screen(), api: api, auth: auth);

    await _tapVisible(tester, findRichText('محمد الحسناوي (أنت)'));
    expect(_inEditor(find.text('هذا حسابك')), findsOneWidget);
    // المدير الأساسي: الدور والحالة مقفلان.
    expect(_inEditor(find.text('المدير الأساسي المحدد في إعدادات الخادم، لذا لا يمكن تعطيله أو تغيير دوره.')),
        findsOneWidget);
    final activeSwitch = tester.widget<SwitchListTile>(
      find.ancestor(of: _inEditor(find.text('الحساب نشط')), matching: find.byType(SwitchListTile)),
    );
    expect(activeSwitch.onChanged, isNull);

    await tester.enterText(_inEditor(find.byType(TextField)), 'محمد الحسناوي الكبير');
    await tester.pumpAndSettle(); // يكتمل تمرير المؤشر إلى الحقل قبل النزول إلى زر الحفظ.
    await _tapVisible(tester, _inEditor(find.text('حفظ التغييرات')));

    expect(api.callsOf('users.update').single.payload, {'id': 'US-0001', 'expectedVersion': 3, 'name': 'محمد الحسناوي الكبير'});
    expect(auth.updatedUsers.single.name, 'محمد الحسناوي الكبير');
    expect(auth.user?.version, 4);
  });
}
