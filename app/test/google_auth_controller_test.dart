import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart' show GoogleSignInException, GoogleSignInExceptionCode;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rumman_calculator/core/api/api_exception.dart';
import 'package:rumman_calculator/core/api/demo_backend_api.dart';
import 'package:rumman_calculator/core/api/http_backend_api.dart';
import 'package:rumman_calculator/core/auth/auth_controller.dart';
import 'package:rumman_calculator/core/auth/google_auth_controller.dart';
import 'package:rumman_calculator/core/auth/google_sign_in_service.dart';
import 'package:rumman_calculator/core/auth/session_store.dart';
import 'package:rumman_calculator/core/models/user.dart';

import 'support/auth_fakes.dart';

const _tokenKey = 'rumman.live.session';
const _userKey = 'rumman.live.user';

Map<String, dynamic> _login({String session = 'SESSION-NEW', Map<String, dynamic>? user}) => {
      'session': session,
      'expiresAt': '2026-10-09T10:58:00+03:00',
      'user': user ?? userJson(),
    };

ApiException _err(ApiErrorCode code, [String message = 'رسالة', Map<String, dynamic> details = const {}]) =>
    ApiException(code, message, details: details);

void main() {
  late Map<String, String> storage;
  late SessionStore store;
  late FakeGoogleSignIn google;

  void seedStorage({String? token, Map<String, dynamic>? user}) {
    storage = {
      _tokenKey: ?token,
      if (user != null) _userKey: jsonEncode(user),
    };
    FlutterSecureStorage.setMockInitialValues(storage);
  }

  Future<Map<String, String>> readAll() => const FlutterSecureStorage().readAll();

  GoogleAuthController controller(
    ScriptedBackendApi api, {
    bool demo = false,
    bool configured = true,
    FakeGoogleSignIn? g,
    DateTime Function()? clock,
  }) =>
      GoogleAuthController(
        api: api,
        google: g ?? google,
        store: store,
        demo: demo,
        configured: configured,
        clock: clock,
      );

  setUp(() {
    seedStorage();
    store = SessionStore();
    google = FakeGoogleSignIn();
  });

  group('restore', () {
    test('دون API_URL ⇒ notConfigured ولا يُرسل أي طلب', () async {
      final api = ScriptedBackendApi();
      final auth = controller(api, configured: false);
      await auth.restore();
      expect(auth.status, AuthStatus.notConfigured);
      expect(api.calls, isEmpty);
    });

    test('لا جلسة محفوظة ⇒ signedOut', () async {
      final api = ScriptedBackendApi();
      final auth = controller(api);
      expect(auth.status, AuthStatus.initializing);
      await auth.restore();
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.message, isNull);
      expect(api.calls, isEmpty);
    });

    test('جلسة محفوظة صالحة ⇒ auth.me ثم signedIn مع حفظ المستخدم', () async {
      seedStorage(token: 'SAVED', user: userJson(name: 'اسم قديم'));
      final api = ScriptedBackendApi({'auth.me': (_) => {'user': userJson(name: 'محمد الحسناوي', version: 2)}});
      final auth = controller(api);
      final states = <AuthStatus>[];
      auth.addListener(() => states.add(auth.status));

      await auth.restore();

      expect(api.calls.single.action, 'auth.me');
      expect(api.calls.single.session, 'SAVED');
      expect(api.session, 'SAVED');
      expect(auth.status, AuthStatus.signedIn);
      expect(auth.user!.name, 'محمد الحسناوي');
      expect(auth.offline, isFalse);
      expect(states, [AuthStatus.initializing, AuthStatus.signedIn]);
      final saved = jsonDecode((await readAll())[_userKey]!) as Map<String, dynamic>;
      expect(saved['version'], 2);
    });

    for (final code in [ApiErrorCode.authExpired, ApiErrorCode.authRequired, ApiErrorCode.sessionStale]) {
      test('${code.wire} ⇒ تُحذف الجلسة وsignedOut مع رسالة', () async {
        seedStorage(token: 'OLD', user: userJson());
        final api = ScriptedBackendApi({'auth.me': (_) => throw _err(code, 'تغيّرت بيانات حسابك أو صلاحياتك.')});
        final auth = controller(api);
        await auth.restore();
        expect(auth.status, AuthStatus.signedOut);
        expect(api.session, isNull);
        expect(await readAll(), isEmpty);
        expect(
          auth.message,
          code == ApiErrorCode.sessionStale ? 'تغيّرت بيانات حسابك أو صلاحياتك.' : GoogleAuthController.sessionExpiredMessage,
        );
      });
    }

    test('لا اتصال مع مستخدم محفوظ ⇒ signedIn دون اتصال', () async {
      seedStorage(token: 'SAVED', user: userJson(name: 'كريم'));
      final api = ScriptedBackendApi({'auth.me': (_) => throw _err(ApiErrorCode.network, 'لا اتصال')});
      final auth = controller(api);
      await auth.restore();
      expect(auth.status, AuthStatus.signedIn);
      expect(auth.offline, isTrue);
      expect(auth.user!.name, 'كريم');
      expect(api.session, 'SAVED');
      expect((await readAll())[_tokenKey], 'SAVED', reason: 'لا تُحذف الجلسة عند انقطاع الاتصال');
    });

    test('لا اتصال دون مستخدم محفوظ ⇒ error', () async {
      seedStorage(token: 'SAVED');
      final api = ScriptedBackendApi({'auth.me': (_) => throw _err(ApiErrorCode.network, 'تعذّر الاتصال بالخادم.')});
      final auth = controller(api);
      await auth.restore();
      expect(auth.status, AuthStatus.error);
      expect(auth.message, 'تعذّر الاتصال بالخادم.');
    });

    test('خطأ آخر (مثل ملف ناقص) ⇒ error بالرسالة دون حذف الجلسة', () async {
      seedStorage(token: 'SAVED', user: userJson());
      final api = ScriptedBackendApi({'auth.me': (_) => throw _err(ApiErrorCode.sheetSchema, 'ينقص الملف صفحة المستخدمين.')});
      final auth = controller(api);
      await auth.restore();
      expect(auth.status, AuthStatus.error);
      expect(auth.message, 'ينقص الملف صفحة المستخدمين.');
      expect((await readAll())[_tokenKey], 'SAVED');
    });

    test('NOT_ALLOWED (عُطّل الحساب) ⇒ notAllowed وحذف الجلسة', () async {
      seedStorage(token: 'SAVED', user: userJson(email: 'karim@example.com'));
      final api = ScriptedBackendApi({
        'auth.me': (_) => throw _err(ApiErrorCode.notAllowed, 'الحساب معطّل.', {'email': 'karim@example.com', 'reason': 'disabled'}),
      });
      final auth = controller(api);
      await auth.restore();
      expect(auth.status, AuthStatus.notAllowed);
      expect(auth.notAllowedEmail, 'karim@example.com');
      expect(auth.notAllowedReason, 'disabled');
      expect(await readAll(), isEmpty);
    });
  });

  group('signIn', () {
    test('Google ثم auth.login ⇒ signedIn وحفظ الجلسة', () async {
      final api = ScriptedBackendApi({'auth.login': (_) => _login()});
      final auth = controller(api);
      await auth.restore();
      final states = <AuthStatus>[];
      auth.addListener(() => states.add(auth.status));

      await auth.signIn();

      expect(google.signInCalls, 1);
      expect(api.calls.single.payload, {'idToken': 'google-id-token'});
      expect(auth.status, AuthStatus.signedIn);
      expect(auth.user!.email, 'owner@example.com');
      expect(api.session, 'SESSION-NEW');
      expect(states.first, AuthStatus.signingIn);
      expect(states.last, AuthStatus.signedIn);
      final all = await readAll();
      expect(all[_tokenKey], 'SESSION-NEW');
      expect(jsonDecode(all[_userKey]!)['email'], 'owner@example.com');
    });

    test('إلغاء المستخدم ⇒ signedOut دون رسالة ودون طلب للخادم', () async {
      google.next = const GoogleSignInFailure('ألغيت.', quiet: true, code: 'canceled');
      final api = ScriptedBackendApi();
      final auth = controller(api);
      await auth.restore();
      await auth.signIn();
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.message, isNull);
      expect(api.calls, isEmpty);
    });

    test('خطأ إعداد Google ⇒ signedOut مع الرسالة', () async {
      google.next = GoogleSignInFailure(GoogleSignInFailure.configurationMessage(GooglePlatform.android));
      final auth = controller(ScriptedBackendApi());
      await auth.restore();
      await auth.signIn();
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.message, contains('SHA-1'));
    });

    test('NOT_ALLOWED ⇒ notAllowed بالبريد من التفاصيل', () async {
      final api = ScriptedBackendApi({
        'auth.login': (_) => throw _err(ApiErrorCode.notAllowed, 'غير مسجّل.', {'email': 'ali@example.com', 'reason': 'not_listed'}),
      });
      final auth = controller(api);
      await auth.restore();
      await auth.signIn();
      expect(auth.status, AuthStatus.notAllowed);
      expect(auth.notAllowedEmail, 'ali@example.com');
      expect(auth.notAllowedReason, 'not_listed');
      expect(auth.user, isNull);
      expect(api.session, isNull);
      expect(await readAll(), isEmpty);
    });

    test('«إعادة المحاولة» بعد الرفض تعيد استخدام ID token دون فتح Google', () async {
      var allowed = false;
      final api = ScriptedBackendApi({
        'auth.login': (_) {
          if (!allowed) throw _err(ApiErrorCode.notAllowed, 'غير مسجّل.', {'email': 'ali@example.com'});
          return _login(user: userJson(id: 'US-0009', email: 'ali@example.com', role: 'entry'));
        },
      });
      final auth = controller(api);
      await auth.restore();
      await auth.signIn();
      expect(auth.status, AuthStatus.notAllowed);

      allowed = true;
      final retry = auth.signIn();
      expect(auth.status, AuthStatus.signingIn);
      expect(auth.notAllowedEmail, 'ali@example.com', reason: 'تبقى شاشة الرفض ظاهرة أثناء المحاولة');
      await retry;

      expect(google.signInCalls, 1);
      expect(api.calls.map((c) => c.payload['idToken']), ['google-id-token', 'google-id-token']);
      expect(auth.status, AuthStatus.signedIn);
      expect(auth.notAllowedEmail, isNull);
    });

    test('بعد انتهاء صلاحية ID token تعيد المحاولة فتح Google', () async {
      var now = DateTime(2026, 10, 2, 10);
      final api = ScriptedBackendApi({
        'auth.login': (_) => throw _err(ApiErrorCode.notAllowed, 'غير مسجّل.', {'email': 'ali@example.com'}),
      });
      final auth = controller(api, clock: () => now);
      await auth.restore();
      await auth.signIn();
      now = now.add(const Duration(hours: 1));
      await auth.signIn();
      expect(google.signInCalls, 2);
    });

    test('AUTH_INVALID_TOKEN ⇒ signedOut مع الرسالة وخروج من Google', () async {
      final api = ScriptedBackendApi({
        'auth.login': (_) => throw _err(ApiErrorCode.authInvalidToken, 'رفض الخادم رمز الدخول من Google.'),
      });
      final auth = controller(api);
      await auth.restore();
      await auth.signIn();
      await Future<void>.delayed(Duration.zero);
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.message, 'رفض الخادم رمز الدخول من Google.');
      expect(google.signOutCalls, 1);
    });

    test('خطأ شبكة أثناء الدخول ⇒ signedOut مع الرسالة', () async {
      final api = ScriptedBackendApi({'auth.login': (_) => throw _err(ApiErrorCode.network, 'تعذّر الاتصال بالخادم.')});
      final auth = controller(api);
      await auth.restore();
      await auth.signIn();
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.message, 'تعذّر الاتصال بالخادم.');
    });

    test('ضغطتان متتاليتان لا تفتحان Google مرتين', () async {
      google.pending = Completer<String>();
      final api = ScriptedBackendApi({'auth.login': (_) => _login()});
      final auth = controller(api);
      await auth.restore();
      final first = auth.signIn();
      await auth.signIn();
      google.pending!.complete('token-1');
      await first;
      expect(google.signInCalls, 1);
      expect(auth.status, AuthStatus.signedIn);
    });

    test('الوضع التجريبي: لا Google، وauth.login بـ demo', () async {
      final api = ScriptedBackendApi({'auth.login': (_) => _login(session: 'demo-session')});
      final auth = controller(api, demo: true);
      await auth.restore();
      await auth.signIn();
      expect(google.signInCalls, 0);
      expect(api.calls.single.payload, {'idToken': 'demo'});
      expect(auth.status, AuthStatus.signedIn);
      expect(auth.isDemo, isTrue);
      expect(auth.usesRenderedWebButton, isFalse);
    });

    test('الوضع التجريبي مع DemoBackendApi الحقيقي', () async {
      final auth = GoogleAuthController(
        api: DemoBackendApi(latency: Duration.zero),
        google: google,
        store: SessionStore(namespace: 'demo'),
        demo: true,
        configured: true,
      );
      await auth.restore();
      await auth.signIn();
      expect(auth.status, AuthStatus.signedIn);
      expect(auth.user!.name, 'محمد الحسناوي');
      expect(auth.user!.isAdmin, isTrue);
      expect((await readAll()).keys, containsAll(['rumman.demo.session', 'rumman.demo.user']));
    });
  });

  group('الويب (زر Google المرسوم)', () {
    test('ID token من الزر ⇒ auth.login ثم signedIn', () async {
      final web = FakeGoogleSignIn(usesRenderedButton: true);
      final api = ScriptedBackendApi({'auth.login': (_) => _login()});
      final auth = controller(api, g: web);
      expect(auth.usesRenderedWebButton, isTrue);
      await auth.restore();

      web.emitToken('web-token');
      await pumpEventQueue();

      expect(api.calls.single.payload, {'idToken': 'web-token'});
      expect(auth.status, AuthStatus.signedIn);
      auth.dispose();
    });

    test('خطأ من الزر ⇒ رسالة على شاشة الدخول، والإلغاء بلا رسالة', () async {
      final web = FakeGoogleSignIn(usesRenderedButton: true);
      final auth = controller(ScriptedBackendApi(), g: web);
      await auth.restore();

      web.emitError(const GoogleSignInFailure('ألغيت.', quiet: true));
      await pumpEventQueue();
      expect(auth.message, isNull);

      web.emitError(GoogleSignInFailure(GoogleSignInFailure.configurationMessage(GooglePlatform.web, webOrigin: 'https://x.web.app')));
      await pumpEventQueue();
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.message, contains('https://x.web.app'));
      auth.dispose();
    });

    test('signIn على الويب لا يفتح نافذة (الدخول من الزر فقط)', () async {
      final web = FakeGoogleSignIn(usesRenderedButton: true);
      final auth = controller(ScriptedBackendApi(), g: web);
      await auth.restore();
      await auth.signIn();
      expect(web.signInCalls, 0);
      expect(auth.status, AuthStatus.signedOut);
      auth.dispose();
    });

    test('توكن يصل وهو مسجّل دخول يُتجاهل', () async {
      final web = FakeGoogleSignIn(usesRenderedButton: true);
      seedStorage(token: 'SAVED', user: userJson());
      final api = ScriptedBackendApi({'auth.me': (_) => {'user': userJson()}, 'auth.login': (_) => _login()});
      final auth = controller(api, g: web);
      await auth.restore();
      web.emitToken('late-token');
      await pumpEventQueue();
      expect(api.actions, ['auth.me']);
      auth.dispose();
    });
  });

  group('signOut وأحداث الخادم', () {
    Future<GoogleAuthController> signedIn(ScriptedBackendApi api) async {
      seedStorage(token: 'SAVED', user: userJson());
      api.handlers['auth.me'] = (_) => {'user': userJson()};
      final auth = controller(api);
      await auth.restore();
      expect(auth.status, AuthStatus.signedIn);
      return auth;
    }

    test('signOut يحذف الجلسة ويخرج من Google ويحتفظ بالرسالة', () async {
      final api = ScriptedBackendApi();
      final auth = await signedIn(api);
      await auth.signOut(message: 'تم تسجيل الخروج.');
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.user, isNull);
      expect(auth.message, 'تم تسجيل الخروج.');
      expect(api.session, isNull);
      expect(await readAll(), isEmpty);
      expect(google.signOutCalls, 1);
    });

    test('updateUser يحدّث المستخدم الحالي فقط', () async {
      final auth = await signedIn(ScriptedBackendApi());
      var notified = 0;
      auth.addListener(() => notified++);
      auth.updateUser(AppUser.fromJson(userJson(id: 'US-0002', name: 'غيره')));
      expect(auth.user!.name, 'محمد الحسناوي');
      auth.updateUser(AppUser.fromJson(userJson(name: 'محمد ح.', version: 2)));
      expect(auth.user!.name, 'محمد ح.');
      expect(notified, 1);
    });

    test('انتهاء الجلسة أثناء الاستخدام (HttpBackendApi حقيقي) ⇒ خروج مع رسالة', () async {
      seedStorage(token: 'SAVED', user: userJson());
      var expired = false;
      final api = HttpBackendApi(
        apiUrl: 'https://script.google.com/macros/s/T/exec',
        web: true,
        client: MockClient((req) async {
          final action = (jsonDecode(req.body) as Map)['action'];
          if (action == 'auth.me') {
            return http.Response.bytes(utf8.encode(jsonEncode({'ok': true, 'data': {'user': userJson()}})), 200);
          }
          expect(expired, isTrue);
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'ok': false,
              'error': {'code': 'AUTH_EXPIRED', 'message': 'انتهت الجلسة. سجّل الدخول مرة أخرى.', 'field': null, 'details': {}},
            })),
            200,
          );
        }),
      );
      final auth = GoogleAuthController(api: api, google: google, store: store, demo: false, configured: true);
      await auth.restore();
      expect(auth.status, AuthStatus.signedIn);
      expect(auth.offline, isFalse);

      expired = true;
      await expectLater(api.dashboard(), throwsA(isA<ApiException>()));
      await pumpEventQueue();

      expect(auth.status, AuthStatus.signedOut);
      expect(auth.message, 'انتهت الجلسة. سجّل الدخول من جديد.');
      expect(api.session, isNull);
      expect(await readAll(), isEmpty);
      auth.dispose();
      expect(api.onSessionExpired, isNull);
    });

    test('تعطيل الحساب أثناء الاستخدام ⇒ notAllowed', () async {
      final auth = await signedIn(ScriptedBackendApi());
      auth.handleAccessRevoked(_err(ApiErrorCode.notAllowed, 'الحساب معطّل.', {'email': 'owner@example.com', 'reason': 'disabled'}));
      await pumpEventQueue();
      expect(auth.status, AuthStatus.notAllowed);
      expect(auth.notAllowedEmail, 'owner@example.com');
      expect(await readAll(), isEmpty);
    });

    test('أحداث الجلسة تُهمل إن لم يكن المستخدم داخلًا', () async {
      final auth = controller(ScriptedBackendApi());
      await auth.restore();
      auth.handleSessionExpired(_err(ApiErrorCode.authExpired));
      auth.handleAccessRevoked(_err(ApiErrorCode.notAllowed));
      await pumpEventQueue();
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.message, isNull);
    });

    test('أول رد من الخادم بعد الدخول دون اتصال يلغي «دون اتصال»', () async {
      seedStorage(token: 'SAVED', user: userJson());
      final api = ScriptedBackendApi({'auth.me': (_) => throw _err(ApiErrorCode.network)});
      final auth = controller(api);
      await auth.restore();
      expect(auth.offline, isTrue);
      auth.handleServerReachable();
      expect(auth.offline, isFalse);
      expect(auth.status, AuthStatus.signedIn);
    });

    test('الخروج أثناء الاستعادة يلغي نتيجتها', () async {
      seedStorage(token: 'SAVED', user: userJson());
      final gate = Completer<Map<String, dynamic>>();
      final api = ScriptedBackendApi({'auth.me': (_) => gate.future});
      final auth = controller(api);
      final restoring = auth.restore();
      await pumpEventQueue();
      await auth.signOut();
      gate.complete({'user': userJson()});
      await restoring;
      expect(auth.status, AuthStatus.signedOut);
    });
  });

  group('معرّفات Google لكل منصة', () {
    test('الويب: clientId للويب وserverClientId = null', () {
      final ids = googleClientIdsFor(GooglePlatform.web);
      expect(ids.clientId, contains('668sjormn0kp8lm4e8c0ioltdr0ctip8'));
      expect(ids.serverClientId, isNull);
    });

    test('iPhone: clientId لـ iOS وserverClientId للويب', () {
      final ids = googleClientIdsFor(GooglePlatform.ios);
      expect(ids.clientId, contains('pb57t33tr66q4b8c3r9tsd3gnbs4doi5'));
      expect(ids.serverClientId, contains('668sjormn0kp8lm4e8c0ioltdr0ctip8'));
    });

    test('Android: clientId = null وserverClientId للويب', () {
      final ids = googleClientIdsFor(GooglePlatform.android);
      expect(ids.clientId, isNull);
      expect(ids.serverClientId, contains('668sjormn0kp8lm4e8c0ioltdr0ctip8'));
    });
  });

  group('ترجمة أخطاء Google', () {
    GoogleSignInFailure t(GoogleSignInExceptionCode code, GooglePlatform p, {String? description}) =>
        GoogleSignInFailure.fromException(GoogleSignInException(code: code, description: description), p, webOrigin: 'https://app.example');

    test('الإلغاء صامت', () {
      expect(t(GoogleSignInExceptionCode.canceled, GooglePlatform.android).quiet, isTrue);
    });

    test('أخطاء الإعداد تذكر ما يجب فحصه لكل منصة', () {
      expect(t(GoogleSignInExceptionCode.clientConfigurationError, GooglePlatform.android).message,
          allOf(contains('com.hasnawi.mysheetapp'), contains('SHA-1')));
      expect(t(GoogleSignInExceptionCode.providerConfigurationError, GooglePlatform.ios).message,
          allOf(contains('com.hasnawi.mysheetapp'), contains('Bundle ID')));
      expect(t(GoogleSignInExceptionCode.clientConfigurationError, GooglePlatform.web).message,
          allOf(contains('https://app.example'), contains('JavaScript')));
    });

    test('بقية الأكواد رسائل عربية غير صامتة', () {
      for (final code in [
        GoogleSignInExceptionCode.interrupted,
        GoogleSignInExceptionCode.uiUnavailable,
        GoogleSignInExceptionCode.userMismatch,
        GoogleSignInExceptionCode.unknownError,
      ]) {
        final f = t(code, GooglePlatform.android);
        expect(f.quiet, isFalse, reason: code.name);
        expect(f.message, matches(RegExp(r'[؀-ۿ]')), reason: code.name);
      }
      expect(t(GoogleSignInExceptionCode.unknownError, GooglePlatform.android, description: 'No credential available').message,
          contains('لا يوجد حساب Google'));
    });
  });
}
