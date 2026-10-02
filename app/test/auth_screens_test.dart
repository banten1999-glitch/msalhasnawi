import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumman_calculator/app/app_scope.dart';
import 'package:rumman_calculator/core/api/api_exception.dart';
import 'package:rumman_calculator/core/api/backend_api.dart';
import 'package:rumman_calculator/core/api/demo_backend_api.dart';
import 'package:rumman_calculator/core/auth/auth_controller.dart';
import 'package:rumman_calculator/core/auth/google_auth_controller.dart';
import 'package:rumman_calculator/core/auth/google_sign_in_service.dart';
import 'package:rumman_calculator/core/auth/session_store.dart';
import 'package:rumman_calculator/features/auth/auth_gate.dart';
import 'package:rumman_calculator/features/auth/auth_status_screens.dart';
import 'package:rumman_calculator/features/auth/login_screen.dart';
import 'package:rumman_calculator/features/auth/not_allowed_screen.dart';
import 'package:rumman_calculator/features/auth/setup_required_screen.dart';
import 'package:rumman_calculator/theme/app_theme.dart';

import 'support/auth_fakes.dart';

Map<String, dynamic> _login() => {'session': 'S', 'expiresAt': '', 'user': userJson()};

Widget _app(BackendApi api, AuthController auth) => AppScope(
      api: api,
      auth: auth,
      child: MaterialApp(
        theme: buildAppTheme(),
        locale: const Locale('ar', 'EG'),
        supportedLocales: const [Locale('ar', 'EG')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: AuthGate(homeBuilder: (_) => const _FakeHome()),
      ),
    );

class _FakeHome extends StatelessWidget {
  const _FakeHome();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () => AppScope.of(context).auth.signOut(message: 'خرجت.'),
                      child: const Text('خروج من صفحة داخلية'),
                    ),
                  ),
                ),
              ),
            ),
            child: const Text('الواجهة الرئيسية'),
          ),
        ),
      );
}

void main() {
  late FakeGoogleSignIn google;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    google = FakeGoogleSignIn();
  });

  Future<GoogleAuthController> pumpApp(
    WidgetTester tester,
    BackendApi api, {
    bool demo = false,
    bool configured = true,
    FakeGoogleSignIn? g,
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final auth = GoogleAuthController(
      api: api,
      google: g ?? google,
      store: SessionStore(),
      demo: demo,
      configured: configured,
    );
    addTearDown(auth.dispose);
    await tester.pumpWidget(_app(api, auth));
    await tester.runAsync(auth.restore);
    await tester.pumpAndSettle();
    return auth;
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
  }

  testWidgets('شاشة الدخول كما في التصميم، والضغط على Google يدخل', (tester) async {
    final api = ScriptedBackendApi({'auth.login': (_) => _login()});
    await pumpApp(tester, api);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('حاسبة الرمان'), findsOneWidget);
    expect(find.text('المتابعة باستخدام Google'), findsOneWidget);
    expect(find.textContaining('الدخول متاح فقط للحسابات التي أضافها المدير'), findsOneWidget);
    expect(find.text('الإصدار 1.0.0'), findsOneWidget);
    expect(find.text('وضع تجريبي'), findsNothing);
    expect(find.text('دخول تجريبي'), findsNothing);

    await tapText(tester, 'المتابعة باستخدام Google');
    await tester.pumpAndSettle();

    expect(google.signInCalls, 1);
    expect(find.text('الواجهة الرئيسية'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('حالة الانتظار ثم شريط الخطأ برسالة الخادم', (tester) async {
    final gate = Completer<Map<String, dynamic>>();
    final api = ScriptedBackendApi({'auth.login': (_) => gate.future});
    await pumpApp(tester, api);

    await tapText(tester, 'المتابعة باستخدام Google');
    await tester.pump();
    expect(find.text('جارٍ تسجيل الدخول…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    gate.completeError(const ApiException(ApiErrorCode.network, 'تعذّر الاتصال بالخادم. تحقق من اتصال الإنترنت ثم أعد المحاولة.'));
    await tester.pumpAndSettle();
    expect(find.text('تعذّر الاتصال بالخادم. تحقق من اتصال الإنترنت ثم أعد المحاولة.'), findsOneWidget);
    expect(find.text('المتابعة باستخدام Google'), findsOneWidget);
  });

  testWidgets('الوضع التجريبي: شارة وزر «دخول تجريبي» يفتح الواجهة دون Google', (tester) async {
    final api = DemoBackendApi(latency: Duration.zero);
    await pumpApp(tester, api, demo: true);

    expect(find.text('وضع تجريبي'), findsOneWidget);
    expect(find.text('دخول تجريبي'), findsOneWidget);

    await tapText(tester, 'دخول تجريبي');
    await tester.pumpAndSettle();
    expect(google.signInCalls, 0);
    expect(find.text('الواجهة الرئيسية'), findsOneWidget);
  });

  testWidgets('على الويب يظهر زر Google المرسوم بدل زر التطبيق', (tester) async {
    final web = FakeGoogleSignIn(usesRenderedButton: true);
    await pumpApp(tester, ScriptedBackendApi(), g: web);
    expect(find.byKey(const ValueKey('fake-web-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('google-sign-in')), findsNothing);
  });

  testWidgets('حساب غير مصرح له: البريد والزران، و«الدخول بحساب آخر» يفتح Google من جديد', (tester) async {
    final api = ScriptedBackendApi({
      'auth.login': (_) => throw const ApiException(
            ApiErrorCode.notAllowed,
            'غير مسجّل.',
            details: {'email': 'ali.kamal@example.com', 'reason': 'not_listed'},
          ),
    });
    await pumpApp(tester, api);
    await tapText(tester, 'المتابعة باستخدام Google');
    await tester.pumpAndSettle();

    expect(find.byType(NotAllowedScreen), findsOneWidget);
    expect(find.text('هذا الحساب غير مصرح له'), findsOneWidget);
    expect(find.text('ali.kamal@example.com'), findsOneWidget);
    expect(find.textContaining('غير موجود في قائمة المستخدمين'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    expect(find.text('الدخول بحساب آخر'), findsOneWidget);

    await tapText(tester, 'الدخول بحساب آخر');
    await tester.pumpAndSettle();
    expect(google.signOutCalls, 1);
    expect(google.signInCalls, 2);
    expect(find.byType(NotAllowedScreen), findsOneWidget, reason: 'الحساب الجديد مرفوض أيضًا في هذا الاختبار');
  });

  testWidgets('دون API_URL تظهر شاشة إعداد الخادم', (tester) async {
    await pumpApp(tester, ScriptedBackendApi(), configured: false);
    expect(find.byType(SetupRequiredScreen), findsOneWidget);
    expect(find.text('إعداد الخادم مطلوب'), findsOneWidget);
    expect(find.text(SetupRequiredScreen.runCommand), findsOneWidget);
    expect(find.textContaining('DEPLOY.md'), findsOneWidget);
  });

  testWidgets('خطأ الاستعادة: رسالة وزر إعادة المحاولة', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'rumman.live.session': 'SAVED'});
    var fail = true;
    final api = ScriptedBackendApi({
      'auth.me': (_) {
        if (fail) throw const ApiException(ApiErrorCode.sheetUnreachable, 'تعذّر فتح ملف Google Sheets.');
        return {'user': userJson()};
      },
    });
    await pumpApp(tester, api);
    expect(find.byType(AuthErrorScreen), findsOneWidget);
    expect(find.text('تعذّر فتح ملف Google Sheets.'), findsOneWidget);

    fail = false;
    await tapText(tester, 'إعادة المحاولة');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pumpAndSettle();
    expect(find.text('الواجهة الرئيسية'), findsOneWidget);
  });

  testWidgets('الخروج من صفحة داخلية يغلقها ويعرض شاشة الدخول بالرسالة', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'rumman.live.session': 'SAVED'});
    final api = ScriptedBackendApi({'auth.me': (_) => {'user': userJson()}});
    await pumpApp(tester, api);

    await tapText(tester, 'الواجهة الرئيسية');
    await tester.pumpAndSettle();
    expect(find.text('خروج من صفحة داخلية'), findsOneWidget);

    await tapText(tester, 'خروج من صفحة داخلية');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pumpAndSettle();

    expect(find.text('خروج من صفحة داخلية'), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('خرجت.'), findsOneWidget);
  });

  testWidgets('رسالة خطأ إعداد Google تظهر على شاشة الدخول', (tester) async {
    google.next = GoogleSignInFailure(GoogleSignInFailure.configurationMessage(GooglePlatform.android));
    await pumpApp(tester, ScriptedBackendApi());
    await tapText(tester, 'المتابعة باستخدام Google');
    await tester.pumpAndSettle();
    expect(find.textContaining('SHA-1'), findsOneWidget);
  });
}
