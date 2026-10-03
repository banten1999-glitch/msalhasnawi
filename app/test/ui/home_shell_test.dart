import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumman_calculator/core/models/user.dart';
import 'package:rumman_calculator/features/dashboard/dashboard_screen.dart';
import 'package:rumman_calculator/features/farmers/farmers_screen.dart';
import 'package:rumman_calculator/features/settings/settings_screen.dart';
import 'package:rumman_calculator/features/shell/home_shell.dart';
import 'package:rumman_calculator/features/shell/placeholder_screen.dart';

import '../support/fake_auth_controller.dart';
import '../support/fake_backend_api.dart';
import '../support/sample_data.dart';
import '../support/test_app.dart';

const _sections = [
  'لوحة التحكم',
  'البرادات وشراء الرمان',
  'المزارعون',
  'مشتريات التعبئة والتغليف',
  'المدفوعات',
  'التقارير',
  'الإعدادات',
];

Future<void> _openDrawer(WidgetTester tester) async {
  await tester.tap(find.byTooltip('فتح القائمة'));
  await tester.pumpAndSettle();
}

Finder _inDrawer(Finder f) => find.descendant(of: find.byType(Drawer), matching: f);

void main() {
  setUpAll(loadAppFonts);

  testWidgets('القائمة على الهاتف: الشعار والمستخدم والأقسام بالترتيب والخروج وحالة الاتصال', (tester) async {
    await pumpTestApp(tester, const HomeShell(), api: FakeBackendApi(), auth: FakeAuthController());

    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.byType(Drawer), findsNothing);
    await _openDrawer(tester);

    expect(find.byType(Drawer), findsOneWidget);
    expect(_inDrawer(find.text('حاسبة الرمان')), findsOneWidget);
    expect(_inDrawer(find.text('محمد الحسناوي')), findsOneWidget);
    expect(_inDrawer(find.text('مدير · كل الصلاحيات')), findsOneWidget);
    for (final s in _sections) {
      expect(_inDrawer(find.text(s)), findsOneWidget, reason: s);
    }
    expect(_inDrawer(find.text('تسجيل الخروج')), findsOneWidget);
    expect(_inDrawer(find.text('متصل بالملف المركزي')), findsOneWidget);

    // الترتيب من الأعلى للأسفل.
    final ys = [for (final s in [..._sections, 'تسجيل الخروج']) tester.getTopLeft(_inDrawer(find.text(s))).dy];
    expect(ys, [...ys]..sort());

    // القائمة على يمين الشاشة (RTL).
    expect(tester.getTopRight(find.byType(Drawer)).dx, phoneSize.width);
  });

  testWidgets('الإعدادات لا تظهر لموظف إدخال بلا صلاحية إدارة', (tester) async {
    await pumpTestApp(tester, const HomeShell(), api: FakeBackendApi(), auth: FakeAuthController(user: sampleEntry()));
    await _openDrawer(tester);
    expect(_inDrawer(find.text('كريم عبد الله')), findsOneWidget);
    expect(_inDrawer(find.text('موظف إدخال')), findsOneWidget);
    expect(_inDrawer(find.text('المدفوعات')), findsOneWidget);
    expect(_inDrawer(find.text('الإعدادات')), findsNothing);
  });

  testWidgets('الإعدادات تظهر لمن يملك إدارة المستخدمين فقط، وتفتح تبويب المستخدمين', (tester) async {
    final usersOnly = AppUser(
      id: 'US-0009',
      email: 'hr@gmail.com',
      name: 'مسؤول المستخدمين',
      role: UserRole.entry,
      active: true,
      version: 1,
      permissions: const UserPermissions(manageUsers: true),
    );
    await pumpTestApp(tester, const HomeShell(), api: FakeBackendApi(), auth: FakeAuthController(user: usersOnly));
    await _openDrawer(tester);
    await tester.tap(_inDrawer(find.text('الإعدادات')));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Google Sheets'), findsNothing);
    expect(find.text('إضافة مستخدم'), findsOneWidget);
  });

  testWidgets('اختيار قسم من القائمة يفتحه ويميّزه', (tester) async {
    final api = FakeBackendApi()
      ..handlers['farmers.list'] = ((_) => {'farmers': <Object>[]})
      ..handlers['purchases.list'] = ((_) => {'purchases': <Object>[]});
    await pumpTestApp(tester, const HomeShell(), api: api, auth: FakeAuthController());
    await _openDrawer(tester);
    await tester.tap(_inDrawer(find.text('المزارعون')));
    await tester.pumpAndSettle();

    expect(find.byType(Drawer), findsNothing);
    expect(find.byType(FarmersScreen), findsOneWidget);
    expect(find.text(kNotBuiltYetMessage), findsNothing);
    // العنوان في الشريط العلوي.
    expect(find.descendant(of: find.byType(AppBar), matching: find.text('المزارعون')), findsOneWidget);

    // القسم النشط مميز في القائمة (لونًا ولقارئ الشاشة).
    final semantics = tester.ensureSemantics();
    await _openDrawer(tester);
    expect(tester.getSemantics(_inDrawer(find.text('المزارعون'))), isSemantics(isSelected: true, isButton: true));
    expect(tester.getSemantics(_inDrawer(find.text('لوحة التحكم'))), isSemantics(isSelected: false));
    final activeText = tester.widget<Text>(_inDrawer(find.text('المزارعون')));
    expect(activeText.style?.color, const Color(0xFFA00B1E));
    semantics.dispose();

    await tester.tap(_inDrawer(find.text('لوحة التحكم')));
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets('تسجيل الخروج يطلب تأكيدًا ثم يستدعي signOut', (tester) async {
    final auth = FakeAuthController();
    await pumpTestApp(tester, const HomeShell(), api: FakeBackendApi(), auth: auth);
    await _openDrawer(tester);
    await tester.tap(_inDrawer(find.text('تسجيل الخروج')));
    await tester.pumpAndSettle();

    expect(find.text('تسجيل الخروج؟'), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(auth.signOutCalls, 0);

    await _openDrawer(tester);
    await tester.tap(_inDrawer(find.text('تسجيل الخروج')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('تسجيل الخروج')));
    await tester.pumpAndSettle();
    expect(auth.signOutCalls, 1);
  });

  testWidgets('بلا اتصال: شريط «لا يوجد اتصال» وملاحظة في القائمة', (tester) async {
    final auth = FakeAuthController(offline: true);
    await pumpTestApp(tester, const HomeShell(), api: FakeBackendApi(), auth: auth);
    expect(find.text('لا يوجد اتصال — تعرض آخر بيانات محفوظة'), findsOneWidget);
    await _openDrawer(tester);
    expect(_inDrawer(find.text('لا يوجد اتصال')), findsOneWidget);

    auth.offline = false;
    await tester.pumpAndSettle();
    expect(find.text('لا يوجد اتصال — تعرض آخر بيانات محفوظة'), findsNothing);
  });

  testWidgets('الشاشة العريضة: قائمة مثبتة بدل القائمة المنزلقة', (tester) async {
    await pumpTestApp(tester, const HomeShell(), api: FakeBackendApi(), auth: FakeAuthController(), size: wideSize);

    expect(find.byTooltip('فتح القائمة'), findsNothing);
    expect(find.byType(Drawer), findsNothing);
    for (final s in _sections) {
      expect(find.text(s), findsWidgets, reason: s);
    }
    // القائمة على يمين الشاشة.
    expect(tester.getTopRight(find.text('البرادات وشراء الرمان')).dx, greaterThan(wideSize.width - 272));

    await tester.tap(find.text('الإعدادات'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('للمدير فقط'), findsOneWidget);
  });
}
