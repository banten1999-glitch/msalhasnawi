import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/auth/auth_controller.dart';
import '../shell/home_shell.dart';
import 'auth_status_screens.dart';
import 'login_screen.dart';
import 'not_allowed_screen.dart';
import 'setup_required_screen.dart';

/// يختار الشاشة حسب حالة الدخول. لا تظهر الواجهة الرئيسية (وأي بيانات) إلا بعد [AuthStatus.signedIn].
///
/// عند الخروج (يدويًا أو لانتهاء الجلسة) تُغلق كل الشاشات المفتوحة فوقه حتى لا يبقى شيء من البيانات ظاهرًا.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.homeBuilder});

  /// للاختبارات: بديل HomeShell.
  final WidgetBuilder? homeBuilder;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

enum _Screen { loading, setup, login, notAllowed, error, home }

class _AuthGateState extends State<AuthGate> {
  AuthController? _auth;
  AuthStatus? _last;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = AppScope.of(context).auth;
    if (!identical(auth, _auth)) {
      _auth?.removeListener(_onAuthChanged);
      _auth = auth..addListener(_onAuthChanged);
      _last = auth.status;
    }
  }

  void _onAuthChanged() {
    final status = _auth!.status;
    if (_last == AuthStatus.signedIn && status != AuthStatus.signedIn && mounted) {
      Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
    }
    _last = status;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _auth?.removeListener(_onAuthChanged);
    super.dispose();
  }

  _Screen _screenFor(AuthController auth) => switch (auth.status) {
        AuthStatus.initializing => _Screen.loading,
        AuthStatus.notConfigured => _Screen.setup,
        AuthStatus.signedOut => _Screen.login,
        // أثناء «إعادة المحاولة» من شاشة الرفض تبقى الشاشة نفسها مع مؤشر الانتظار.
        AuthStatus.signingIn => auth.notAllowedEmail != null ? _Screen.notAllowed : _Screen.login,
        AuthStatus.notAllowed => _Screen.notAllowed,
        AuthStatus.error => _Screen.error,
        AuthStatus.signedIn => _Screen.home,
      };

  @override
  Widget build(BuildContext context) {
    final auth = _auth ?? AppScope.of(context).auth;
    final screen = _screenFor(auth);
    final Widget child = switch (screen) {
      _Screen.loading => const AuthLoadingScreen(),
      _Screen.setup => const SetupRequiredScreen(),
      _Screen.login => const LoginScreen(),
      _Screen.notAllowed => const NotAllowedScreen(),
      _Screen.error => const AuthErrorScreen(),
      _Screen.home => widget.homeBuilder?.call(context) ?? const HomeShell(),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: KeyedSubtree(key: ValueKey(screen), child: child),
    );
  }
}
