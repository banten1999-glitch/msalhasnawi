import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumman_calculator/core/api/api_exception.dart';
import 'package:rumman_calculator/core/api/backend_api.dart';
import 'package:rumman_calculator/core/api/demo_backend_api.dart';
import 'package:rumman_calculator/core/auth/google_auth_controller.dart';
import 'package:rumman_calculator/core/auth/session_store.dart';
import 'package:rumman_calculator/core/sync/outbox.dart';
import 'package:rumman_calculator/features/auth/auth_gate.dart';
import 'package:rumman_calculator/features/auth/login_screen.dart';
import 'package:rumman_calculator/features/auth/not_allowed_screen.dart';
import 'package:rumman_calculator/features/dashboard/dashboard_screen.dart';
import 'package:rumman_calculator/features/shell/home_shell.dart';
import 'package:rumman_calculator/main.dart';
import 'package:rumman_calculator/screens/splash_screen.dart';

import 'support/auth_fakes.dart';

/// المسار الكامل عبر RummanApp الحقيقي: البداية ← AuthGate ← الدخول ← HomeShell ← الخروج.
void main() {
  late FakeGoogleSignIn google;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    google = FakeGoogleSignIn();
  });

  Future<GoogleAuthController> pumpApp(WidgetTester tester, BackendApi api, {bool demo = false}) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final auth = GoogleAuthController(
      api: api,
      google: google,
      store: SessionStore(namespace: demo ? 'demo' : 'live'),
      demo: demo,
      configured: true,
    );
    addTearDown(auth.dispose);
    await tester.pumpWidget(RummanApp(api: api, auth: auth, outbox: Outbox(api: api, storage: MemoryOutboxStorage())));
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(AuthGate), findsNothing);
    await tester.pump(const Duration(milliseconds: 3100));
    await tester.pumpAndSettle();
    expect(find.byType(AuthGate), findsOneWidget);
    return auth;
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final f = find.text(text).last;
    await tester.ensureVisible(f);
    await tester.tap(f);
  }

  testWidgets('تجريبي: البداية ← الدخول ← لوحة التحكم ← تسجيل الخروج ← الدخول', (tester) async {
    final auth = await pumpApp(tester, DemoBackendApi(latency: Duration.zero), demo: true);

    expect(find.byType(LoginScreen), findsOneWidget);
    await tapText(tester, 'دخول تجريبي');
    await tester.pumpAndSettle();

    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.text('لوحة التحكم'), findsWidgets);
    expect(find.text('البراد الجاري تحميله'), findsOneWidget);
    expect(find.textContaining('40,839.40', findRichText: true), findsWidgets);
    expect(google.signInCalls, 0);

    await tester.tap(find.byTooltip('فتح القائمة'));
    await tester.pumpAndSettle();
    await tapText(tester, 'تسجيل الخروج');
    await tester.pumpAndSettle();
    expect(find.text('تسجيل الخروج؟'), findsOneWidget);
    await tapText(tester, 'تسجيل الخروج');
    await tester.pumpAndSettle();

    expect(find.byType(HomeShell), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(auth.user, isNull);
  });

  testWidgets('حساب غير مضاف: شاشة «غير مصرح له» دون أي بيانات', (tester) async {
    final api = ScriptedBackendApi({
      'auth.login': (_) => throw const ApiException(
            ApiErrorCode.notAllowed,
            'هذا الحساب غير موجود في قائمة المستخدمين.',
            details: {'email': 'ali.kamal@example.com', 'reason': 'not_listed'},
          ),
    });
    await pumpApp(tester, api);

    expect(find.byType(LoginScreen), findsOneWidget);
    await tapText(tester, 'المتابعة باستخدام Google');
    await tester.pumpAndSettle();

    expect(find.byType(NotAllowedScreen), findsOneWidget);
    expect(find.text('ali.kamal@example.com'), findsOneWidget);
    expect(find.byType(HomeShell), findsNothing);
    expect(api.actions, ['auth.login']);
  });
}
