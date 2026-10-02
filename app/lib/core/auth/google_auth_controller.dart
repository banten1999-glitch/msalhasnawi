import 'dart:async';

import '../../config/app_config.dart';
import '../api/api_exception.dart';
import '../api/backend_api.dart';
import '../api/http_backend_api.dart';
import '../models/user.dart';
import 'auth_controller.dart';
import 'google_sign_in_service.dart';
import 'session_store.dart';

/// حالة الدخول الفعلية: Google ← ID token ← الخادم (auth.login) ← جلسة محفوظة على الجهاز.
///
/// نجاح الدخول لدى Google وحده لا يكفي: الخادم يتحقق من التوكن ومن قائمة المستخدمين في الملف،
/// ولا تُعرض أي بيانات قبل [AuthStatus.signedIn].
class GoogleAuthController extends AuthController {
  GoogleAuthController({
    required this._api,
    required this._google,
    required this._store,
    bool? demo,
    bool? configured,
    DateTime Function()? clock,
  })  : _demo = demo ?? AppConfig.demoMode,
        _configured = configured ?? AppConfig.isConfigured,
        _clock = clock ?? DateTime.now {
    final api = _api;
    if (api is HttpBackendApi) {
      api.onSessionExpired = handleSessionExpired;
      api.onNotAllowed = handleAccessRevoked;
      api.onServerReachable = handleServerReachable;
    }
    if (usesRenderedWebButton) {
      _webTokens = _google.idTokens.listen(_onWebIdToken, onError: _onWebError);
    }
  }

  final BackendApi _api;
  final GoogleSignInService _google;
  final SessionStore _store;
  final bool _demo;
  final bool _configured;
  final DateTime Function() _clock;
  StreamSubscription<String>? _webTokens;

  /// رسالة الخروج الإجباري عند انتهاء الجلسة.
  static const sessionExpiredMessage = 'انتهت الجلسة. سجّل الدخول من جديد.';

  /// ID token من Google صالح ساعة واحدة؛ نعيد استخدامه لـ «إعادة المحاولة» خلال 50 دقيقة فقط.
  static const _idTokenReuseWindow = Duration(minutes: 50);

  AuthStatus _status = AuthStatus.initializing;
  AppUser? _user;
  String? _message;
  String? _notAllowedEmail;
  String? _notAllowedReason;
  bool _offline = false;
  bool _disposed = false;
  String? _lastIdToken;
  DateTime? _lastIdTokenAt;

  /// يزيد مع كل تغيير في الحالة حتى تُهمل نتائج العمليات القديمة (مثل استعادة انتهت بعد الخروج).
  int _epoch = 0;

  @override
  AuthStatus get status => _status;

  @override
  AppUser? get user => _user;

  @override
  String? get message => _message;

  @override
  String? get notAllowedEmail => _notAllowedEmail;

  /// سبب الرفض من الخادم: `not_listed` (غير مضاف) أو `disabled` (معطّل).
  String? get notAllowedReason => _notAllowedReason;

  @override
  bool get offline => _offline;

  @override
  bool get isDemo => _demo;

  @override
  bool get usesRenderedWebButton => !_demo && _google.usesRenderedButton;

  /// زر Google المرسوم (الويب فقط).
  GoogleSignInService get google => _google;

  void _set(
    AuthStatus status, {
    AppUser? user,
    String? message,
    String? notAllowedEmail,
    String? notAllowedReason,
    bool offline = false,
  }) {
    _status = status;
    _user = user;
    _message = message;
    _notAllowedEmail = notAllowedEmail;
    _notAllowedReason = notAllowedReason;
    _offline = offline;
    _epoch++;
    if (!_disposed) notifyListeners();
  }

  // ===================================================================================== الاستعادة

  @override
  Future<void> restore() async {
    if (!_configured) {
      _set(AuthStatus.notConfigured);
      return;
    }
    _set(AuthStatus.initializing);
    final epoch = _epoch;
    final saved = await _store.read();
    if (epoch != _epoch) return;
    if (saved == null) {
      _api.session = null;
      _set(AuthStatus.signedOut);
      return;
    }
    _api.session = saved.token;
    try {
      final user = await _api.me();
      if (epoch != _epoch) return;
      await _store.saveUser(user);
      if (epoch != _epoch) return;
      _set(AuthStatus.signedIn, user: user);
    } on ApiException catch (e) {
      if (epoch != _epoch) return;
      if (e.requiresLogin) {
        await _clearLocal();
        if (epoch != _epoch) return;
        _set(AuthStatus.signedOut, message: _expiredMessage(e));
      } else if (e.code == ApiErrorCode.notAllowed) {
        await _clearLocal();
        if (epoch != _epoch) return;
        _set(
          AuthStatus.notAllowed,
          message: e.message,
          notAllowedEmail: _detailsEmail(e) ?? saved.user?.email,
          notAllowedReason: e.details['reason'] as String?,
        );
      } else if (e.code == ApiErrorCode.network && saved.user != null) {
        _set(AuthStatus.signedIn, user: saved.user, offline: true);
      } else {
        _set(AuthStatus.error, message: e.message);
      }
    }
  }

  // ===================================================================================== الدخول

  @override
  Future<void> signIn() async {
    if (_status == AuthStatus.signingIn || !_configured) return;
    if (_demo) {
      await signInWithIdToken('demo');
      return;
    }
    // «إعادة المحاولة» بعد الرفض: نفس الحساب، دون فتح Google من جديد ما دام التوكن صالحًا.
    final last = _lastIdToken;
    final lastAt = _lastIdTokenAt;
    if (_status == AuthStatus.notAllowed &&
        last != null &&
        lastAt != null &&
        _clock().difference(lastAt) < _idTokenReuseWindow) {
      await signInWithIdToken(last);
      return;
    }
    if (_google.usesRenderedButton) {
      // على الويب يبدأ الدخول من زر Google المرسوم فقط.
      _lastIdToken = null;
      _set(AuthStatus.signedOut);
      return;
    }
    _set(AuthStatus.signingIn, notAllowedEmail: _notAllowedEmail, notAllowedReason: _notAllowedReason);
    final epoch = _epoch;
    final String idToken;
    try {
      idToken = await _google.signIn();
    } on GoogleSignInFailure catch (f) {
      if (epoch != _epoch) return;
      _set(AuthStatus.signedOut, message: f.quiet ? null : f.message);
      return;
    }
    if (epoch != _epoch) return;
    await signInWithIdToken(idToken);
  }

  @override
  Future<void> signInWithIdToken(String idToken) async {
    if (!_configured) return;
    // يبقى البريد المرفوض ظاهرًا أثناء «إعادة المحاولة» حتى تبقى الشاشة نفسها.
    _set(AuthStatus.signingIn, notAllowedEmail: _notAllowedEmail, notAllowedReason: _notAllowedReason);
    final epoch = _epoch;
    _lastIdToken = idToken;
    _lastIdTokenAt = _clock();
    _api.session = null;
    try {
      final result = await _api.login(idToken);
      if (epoch != _epoch) return;
      _api.session = result.session;
      await _store.save(result.session, result.user);
      if (epoch != _epoch) return;
      _set(AuthStatus.signedIn, user: result.user);
    } on ApiException catch (e) {
      if (epoch != _epoch) return;
      if (e.code == ApiErrorCode.notAllowed) {
        _set(
          AuthStatus.notAllowed,
          message: e.message,
          notAllowedEmail: _detailsEmail(e),
          notAllowedReason: e.details['reason'] as String?,
        );
        return;
      }
      _lastIdToken = null;
      _set(AuthStatus.signedOut, message: e.message);
      if (e.code == ApiErrorCode.authInvalidToken) {
        // التوكن مرفوض: نخرج من Google حتى يُطلب توكن جديد في المحاولة القادمة.
        unawaited(_google.signOut());
      }
    }
  }

  // ===================================================================================== الخروج

  @override
  Future<void> signOut({String? message}) async {
    _lastIdToken = null;
    _lastIdTokenAt = null;
    await _clearLocal();
    _set(AuthStatus.signedOut, message: message);
    if (!_demo) await _google.signOut();
  }

  Future<void> _clearLocal() async {
    _api.session = null;
    await _store.clear();
  }

  @override
  void updateUser(AppUser user) {
    final current = _user;
    if (_status != AuthStatus.signedIn || current == null || current.id != user.id) return;
    _user = user;
    unawaited(_store.saveUser(user));
    if (!_disposed) notifyListeners();
  }

  // ===================================================================================== أحداث الخادم

  /// الخادم رفض الجلسة أثناء الاستخدام (انتهت، أو تغيّرت الصلاحيات): خروج مع رسالة.
  void handleSessionExpired(ApiException error) {
    if (_status != AuthStatus.signedIn) return;
    unawaited(signOut(message: _expiredMessage(error)));
  }

  /// عُطّل الحساب أو حُذف من القائمة أثناء الاستخدام: شاشة «غير مصرح له».
  void handleAccessRevoked(ApiException error) {
    if (_status != AuthStatus.signedIn) return;
    final email = _detailsEmail(error) ?? _user?.email;
    _lastIdToken = null;
    unawaited(_clearLocal());
    _set(
      AuthStatus.notAllowed,
      message: error.message,
      notAllowedEmail: email,
      notAllowedReason: error.details['reason'] as String?,
    );
    if (!_demo) unawaited(_google.signOut());
  }

  /// وصل رد من الخادم: الاتصال عاد.
  void handleServerReachable() {
    if (!_offline || _status != AuthStatus.signedIn) return;
    _offline = false;
    if (!_disposed) notifyListeners();
  }

  // ===================================================================================== الويب

  bool get _acceptsWebToken =>
      _status == AuthStatus.signedOut ||
      _status == AuthStatus.notAllowed ||
      _status == AuthStatus.error;

  void _onWebIdToken(String idToken) {
    if (!_acceptsWebToken) return;
    unawaited(signInWithIdToken(idToken));
  }

  void _onWebError(Object error) {
    if (!_acceptsWebToken) return;
    final failure = error is GoogleSignInFailure ? error : null;
    if (failure != null && failure.quiet) return;
    _set(
      AuthStatus.signedOut,
      message: failure?.message ?? 'تعذّر تسجيل الدخول بحساب Google. تحقق من اتصال الإنترنت ثم أعد المحاولة.',
    );
  }

  // ===================================================================================== مساعدات

  static String? _detailsEmail(ApiException e) {
    final v = e.details['email'];
    return v is String && v.isNotEmpty ? v : null;
  }

  static String _expiredMessage(ApiException e) =>
      e.code == ApiErrorCode.sessionStale && e.message.isNotEmpty ? e.message : sessionExpiredMessage;

  @override
  void dispose() {
    _disposed = true;
    unawaited(_webTokens?.cancel());
    final api = _api;
    if (api is HttpBackendApi) {
      api.onSessionExpired = null;
      api.onNotAllowed = null;
      api.onServerReachable = null;
    }
    super.dispose();
  }
}
