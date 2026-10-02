import 'package:flutter/foundation.dart';

import '../models/user.dart';

enum AuthStatus {
  /// يستعيد الجلسة المحفوظة.
  initializing,

  /// لم يُضبط عنوان الخادم (API_URL).
  notConfigured,
  signedOut,
  signingIn,
  signedIn,

  /// دخل لدى Google لكن بريده غير مصرح له أو معطّل.
  notAllowed,
  error,
}

/// حالة الدخول التي تعتمد عليها الشاشات. التنفيذ في google_auth_controller.dart.
abstract class AuthController extends ChangeNotifier {
  AuthStatus get status;

  /// المستخدم الحالي عند [AuthStatus.signedIn].
  AppUser? get user;

  /// رسالة عربية عند [AuthStatus.error] أو بعد خروج إجباري (مثل انتهاء الجلسة).
  String? get message;

  /// البريد المرفوض عند [AuthStatus.notAllowed].
  String? get notAllowedEmail;

  /// true إذا كان الدخول من بيانات محفوظة ولم يُؤكَّد مع الخادم بعد (لا اتصال).
  bool get offline;

  /// true في وضع التجربة (--dart-define=DEMO=true).
  bool get isDemo;

  /// على الويب يجب استخدام زر Google المرسوم من مكتبته، لا زر خاص بالتطبيق.
  bool get usesRenderedWebButton;

  /// يستعيد الجلسة المحفوظة ويتحقق منها مع الخادم.
  Future<void> restore();

  /// يبدأ الدخول التفاعلي بحساب Google (Android وiPhone، أو الدخول التجريبي).
  Future<void> signIn();

  /// يرسل ID token من Google إلى الخادم (يُستدعى أيضًا من زر الويب).
  Future<void> signInWithIdToken(String idToken);

  /// يحذف الجلسة من الجهاز ويخرج من Google. [message] تُعرض في شاشة الدخول.
  Future<void> signOut({String? message});

  /// يحدّث بيانات المستخدم بعد تعديلها (مثلًا من شاشة المستخدمين).
  void updateUser(AppUser user);
}
