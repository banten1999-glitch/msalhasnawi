import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../config/google_auth_config.dart';
import 'google_web_button.dart';

/// المنصة من ناحية تسجيل الدخول بـ Google.
enum GooglePlatform { android, ios, web, other }

GooglePlatform currentGooglePlatform() {
  if (kIsWeb) return GooglePlatform.web;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => GooglePlatform.android,
    TargetPlatform.iOS => GooglePlatform.ios,
    _ => GooglePlatform.other,
  };
}

/// معرّفات العميل لكل منصة:
/// * الويب: clientId = عميل الويب، وserverClientId غير مدعوم (null).
/// * iPhone: clientId = عميل iOS، وserverClientId = عميل الويب ليحمل ID token جمهورًا يقبله الخادم.
/// * Android: clientId = null (يُعرف من اسم الحزمة وبصمة SHA-1)، وserverClientId = عميل الويب.
({String? clientId, String? serverClientId}) googleClientIdsFor(GooglePlatform platform) => switch (platform) {
      GooglePlatform.web => (clientId: GoogleAuthConfig.webClientId, serverClientId: null),
      GooglePlatform.ios => (clientId: GoogleAuthConfig.iosClientId, serverClientId: GoogleAuthConfig.webClientId),
      GooglePlatform.android || GooglePlatform.other => (clientId: null, serverClientId: GoogleAuthConfig.webClientId),
    };

/// فشل تسجيل الدخول لدى Google برسالة عربية جاهزة للعرض.
class GoogleSignInFailure implements Exception {
  const GoogleSignInFailure(this.message, {this.quiet = false, this.code, this.technical});

  /// يترجم أكواد google_sign_in إلى رسائل تقول ما حدث وكيف يُصلح.
  factory GoogleSignInFailure.fromException(GoogleSignInException e, GooglePlatform platform, {String? webOrigin}) {
    final technical = '${e.code.name}: ${e.description ?? ''}';
    switch (e.code) {
      case GoogleSignInExceptionCode.canceled:
        return GoogleSignInFailure('ألغيت تسجيل الدخول.', quiet: true, code: e.code.name, technical: technical);
      case GoogleSignInExceptionCode.interrupted:
        return GoogleSignInFailure(
          'انقطع تسجيل الدخول بحساب Google قبل اكتماله. اضغط «المتابعة باستخدام Google» مرة أخرى.',
          code: e.code.name,
          technical: technical,
        );
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return GoogleSignInFailure(
          configurationMessage(platform, webOrigin: webOrigin),
          code: e.code.name,
          technical: technical,
        );
      case GoogleSignInExceptionCode.uiUnavailable:
        return GoogleSignInFailure(
          platform == GooglePlatform.web
              ? 'تعذّر فتح نافذة Google. اسمح بالنوافذ المنبثقة لهذا الموقع ثم أعد المحاولة.'
              : 'تعذّر فتح نافذة Google على هذا الجهاز. أغلق التطبيق وافتحه من جديد ثم أعد المحاولة.',
          code: e.code.name,
          technical: technical,
        );
      case GoogleSignInExceptionCode.userMismatch:
        return GoogleSignInFailure(
          'الحساب المختار في Google لا يطابق الحساب المسجّل حاليًا. اضغط «المتابعة باستخدام Google» مرة أخرى واختر الحساب الصحيح.',
          code: e.code.name,
          technical: technical,
        );
      case GoogleSignInExceptionCode.unknownError:
        final noAccount = (e.description ?? '').toLowerCase().contains('no credential');
        return GoogleSignInFailure(
          noAccount
              ? 'لا يوجد حساب Google على هذا الجهاز. أضف حسابك من إعدادات الجهاز ثم أعد المحاولة.'
              : 'تعذّر تسجيل الدخول بحساب Google. تحقق من اتصال الإنترنت ثم أعد المحاولة.',
          code: e.code.name,
          technical: technical,
        );
    }
  }

  /// رسالة عربية واضحة.
  final String message;

  /// ألغاه المستخدم بنفسه: لا تُعرض رسالة.
  final bool quiet;

  /// كود google_sign_in (للتشخيص).
  final String? code;

  /// تفاصيل تقنية بالإنجليزية للسجلات فقط.
  final String? technical;

  static const _appId = '\u2066com.hasnawi.mysheetapp\u2069';

  /// خطأ الإعداد: يخبر مالك التطبيق ماذا يراجع في Google Cloud Console لكل منصة.
  static String configurationMessage(GooglePlatform platform, {String? webOrigin}) => switch (platform) {
        GooglePlatform.android => 'تسجيل الدخول بحساب Google غير مضبوط لهذه النسخة من تطبيق Android. '
            'على مالك التطبيق التأكد في Google Cloud Console أن عميل Android مسجّل باسم الحزمة $_appId '
            'وببصمة SHA-1 لمفتاح التوقيع المستخدم في هذه النسخة (نسخة التطوير ونسخة المتجر لكل منهما بصمة).',
        GooglePlatform.ios => 'تسجيل الدخول بحساب Google غير مضبوط لهذه النسخة من تطبيق iPhone. '
            'على مالك التطبيق التأكد في Google Cloud Console أن عميل iOS مسجّل بمعرّف الحزمة (Bundle ID) $_appId، '
            'وأن رابط العودة (REVERSED_CLIENT_ID) مضاف إلى \u2066Info.plist\u2069.',
        GooglePlatform.web => 'تسجيل الدخول بحساب Google غير مضبوط لهذا الموقع. '
            'على مالك التطبيق إضافة عنوان الموقع${webOrigin == null || webOrigin.isEmpty ? '' : ' ($webOrigin)'} '
            'إلى «أصول JavaScript المصرح بها» (Authorized JavaScript origins) لعميل الويب في Google Cloud Console.',
        GooglePlatform.other => 'تسجيل الدخول بحساب Google غير متاح على هذا النظام. '
            'استخدم التطبيق على Android أو iPhone أو من المتصفح.',
      };

  @override
  String toString() => 'GoogleSignInFailure(${code ?? '-'}, $message${technical == null ? '' : ' | $technical'})';
}

/// واجهة تسجيل الدخول بـ Google التي يعتمد عليها GoogleAuthController (تُستبدل بنسخة وهمية في الاختبارات).
abstract class GoogleSignInService {
  /// true على الويب: الدخول يتم فقط بزر Google المرسوم ([buildButton]) ويصل ID token عبر [idTokens].
  bool get usesRenderedButton;

  /// دخول تفاعلي (Android وiPhone) يعيد ID token. يرمي [GoogleSignInFailure].
  Future<String> signIn();

  /// ID tokens من زر الويب. الأخطاء تصل كـ [GoogleSignInFailure].
  Stream<String> get idTokens;

  /// زر Google المرسوم (الويب فقط).
  Widget buildButton({double minimumWidth = 320});

  /// يخرج من Google حتى يظهر اختيار الحساب في المرة القادمة. لا يرمي.
  Future<void> signOut();
}

/// التنفيذ الحقيقي فوق google_sign_in 7.x.
class PluginGoogleSignInService implements GoogleSignInService {
  PluginGoogleSignInService({GooglePlatform? platform}) : platform = platform ?? currentGooglePlatform();

  final GooglePlatform platform;
  Future<void>? _init;
  Stream<String>? _idTokens;

  @override
  bool get usesRenderedButton => platform == GooglePlatform.web;

  String? get _webOrigin {
    if (platform != GooglePlatform.web) return null;
    try {
      return Uri.base.origin;
    } catch (_) {
      return null;
    }
  }

  /// initialize يجب أن يُستدعى مرة واحدة فقط طوال عمر التطبيق.
  Future<void> ensureInitialized() => _init ??= _initialize();

  Future<void> _initialize() {
    final ids = googleClientIdsFor(platform);
    return GoogleSignIn.instance.initialize(clientId: ids.clientId, serverClientId: ids.serverClientId);
  }

  GoogleSignInFailure _translate(Object error) {
    if (error is GoogleSignInFailure) return error;
    if (error is GoogleSignInException) {
      return GoogleSignInFailure.fromException(error, platform, webOrigin: _webOrigin);
    }
    if (platform == GooglePlatform.other) {
      return GoogleSignInFailure(GoogleSignInFailure.configurationMessage(platform), technical: '$error');
    }
    return GoogleSignInFailure(
      platform == GooglePlatform.web
          ? 'تعذّر تجهيز تسجيل الدخول بحساب Google. تحقق من اتصال الإنترنت ثم حدّث الصفحة.'
          : 'تعذّر تجهيز تسجيل الدخول بحساب Google. أغلق التطبيق وافتحه من جديد ثم أعد المحاولة.',
      technical: '$error',
    );
  }

  GoogleSignInFailure _missingIdToken() => GoogleSignInFailure(
        GoogleSignInFailure.configurationMessage(platform, webOrigin: _webOrigin),
        code: 'noIdToken',
        technical: 'Google returned no ID token (serverClientId/client configuration).',
      );

  @override
  Future<String> signIn() async {
    if (usesRenderedButton) {
      throw const GoogleSignInFailure('اضغط زر «المتابعة باستخدام Google» الظاهر في الصفحة.');
    }
    try {
      await ensureInitialized();
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null || token.isEmpty) throw _missingIdToken();
      return token;
    } catch (e) {
      throw _translate(e);
    }
  }

  @override
  Stream<String> get idTokens => _idTokens ??= GoogleSignIn.instance.authenticationEvents.transform(
        StreamTransformer<GoogleSignInAuthenticationEvent, String>.fromHandlers(
          handleData: (event, sink) {
            if (event is! GoogleSignInAuthenticationEventSignIn) return;
            final token = event.user.authentication.idToken;
            if (token == null || token.isEmpty) {
              sink.addError(_missingIdToken());
            } else {
              sink.add(token);
            }
          },
          handleError: (error, stack, sink) => sink.addError(_translate(error), stack),
        ),
      );

  @override
  Widget buildButton({double minimumWidth = 320}) => _RenderedGoogleButton(service: this, minimumWidth: minimumWidth);

  @override
  Future<void> signOut() async {
    // على الويب signOut ينتظر اكتمال initialize؛ إن لم يُرسم الزر أصلًا فلا يوجد ما نخرج منه.
    // على Android وiPhone نجهّز المكتبة إن لزم حتى يُنسى الحساب السابق (مثلًا بعد استعادة جلسة محفوظة).
    if (_init == null && (platform == GooglePlatform.web || platform == GooglePlatform.other)) return;
    try {
      await ensureInitialized().timeout(const Duration(seconds: 5));
      await GoogleSignIn.instance.signOut().timeout(const Duration(seconds: 5));
    } catch (_) {
      // الخروج من Google ليس شرطًا لحذف الجلسة من الجهاز.
    }
  }
}

/// يجهّز Google ثم يعرض الزر المرسوم مرة واحدة (لا يُعاد إنشاؤه مع كل بناء).
class _RenderedGoogleButton extends StatefulWidget {
  const _RenderedGoogleButton({required this.service, required this.minimumWidth});

  final PluginGoogleSignInService service;
  final double minimumWidth;

  @override
  State<_RenderedGoogleButton> createState() => _RenderedGoogleButtonState();
}

class _RenderedGoogleButtonState extends State<_RenderedGoogleButton> {
  late final Future<void> _ready = widget.service.ensureInitialized();
  Widget? _button;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => FutureBuilder<void>(
        future: _ready,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text(
              widget.service._translate(snapshot.error!).message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 14),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 44,
              child: Center(
                child: Text('جارٍ تجهيز زر Google…', style: TextStyle(fontSize: 14)),
              ),
            );
          }
          // مكان ثابت بعرض الزر: مكتبة Google ترسم الزر داخل iframe لا يُقاس حجمه دائمًا بدقة،
          // فبدون مقاس ثابت قد يُزاح الزر أو يُقص (خاصة مع اتجاه الصفحة من اليمين لليسار).
          final available = constraints.hasBoundedWidth ? constraints.maxWidth : widget.minimumWidth;
          // مكتبة Google تقبل عرضًا حتى 400 بكسل.
          final width = math.min(widget.minimumWidth, available).clamp(200.0, 400.0);
          _button ??= renderGoogleWebButton(minimumWidth: width);
          return SizedBox(width: width, height: 44, child: _button);
        },
      ),
    );
  }
}
