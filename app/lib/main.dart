import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/app_scope.dart';
import 'config/app_config.dart';
import 'core/api/backend_api.dart';
import 'core/api/demo_backend_api.dart';
import 'core/api/http_backend_api.dart';
import 'core/api/unconfigured_backend_api.dart';
import 'core/auth/auth_controller.dart';
import 'core/auth/google_auth_controller.dart';
import 'core/auth/google_sign_in_service.dart';
import 'core/auth/session_store.dart';
import 'features/auth/auth_gate.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RummanApp());
}

/// الخادم حسب إعدادات البناء: تجريبي، أو حقيقي (API_URL)، أو بديل يرفض كل طلب.
BackendApi createBackendApi() {
  if (AppConfig.demoMode) return DemoBackendApi();
  if (AppConfig.apiUrl.isNotEmpty) return HttpBackendApi(apiUrl: AppConfig.apiUrl);
  return UnconfiguredBackendApi();
}

class RummanApp extends StatefulWidget {
  /// [api] و[auth] للاختبارات؛ في التطبيق يُنشآن من إعدادات البناء.
  const RummanApp({super.key, this.api, this.auth, this.homeBuilder});

  final BackendApi? api;
  final AuthController? auth;

  /// للاختبارات: بديل الواجهة الرئيسية بعد الدخول.
  final WidgetBuilder? homeBuilder;

  @override
  State<RummanApp> createState() => _RummanAppState();
}

class _RummanAppState extends State<RummanApp> {
  late final BackendApi _api = widget.api ?? createBackendApi();
  late final bool _ownsAuth = widget.auth == null;
  late final AuthController _auth = widget.auth ??
      GoogleAuthController(
        api: _api,
        google: PluginGoogleSignInService(),
        store: SessionStore(namespace: AppConfig.demoMode ? 'demo' : 'live'),
      );

  @override
  void initState() {
    super.initState();
    // تُستعاد الجلسة أثناء شاشة البداية (3 ثوانٍ).
    unawaited(_auth.restore());
  }

  @override
  void dispose() {
    if (_ownsAuth) _auth.dispose();
    final api = _api;
    if (widget.api == null && api is HttpBackendApi) api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      api: _api,
      auth: _auth,
      child: MaterialApp(
        title: 'حاسبة الرمان',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        locale: const Locale('ar', 'EG'),
        supportedLocales: const [Locale('ar', 'EG'), Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: SplashScreen(nextBuilder: (_) => AuthGate(homeBuilder: widget.homeBuilder)),
      ),
    );
  }
}
