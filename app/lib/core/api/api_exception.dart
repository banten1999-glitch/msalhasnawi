/// أكواد الأخطاء القادمة من الخادم (docs/API.md §2) مع أكواد خاصة بالتطبيق.
enum ApiErrorCode {
  authRequired('AUTH_REQUIRED'),
  authInvalidToken('AUTH_INVALID_TOKEN'),
  authExpired('AUTH_EXPIRED'),
  sessionStale('SESSION_STALE'),
  notAllowed('NOT_ALLOWED'),
  forbidden('FORBIDDEN'),
  validation('VALIDATION'),
  notFound('NOT_FOUND'),
  conflict('CONFLICT'),
  coolerClosed('COOLER_CLOSED'),
  lockTimeout('LOCK_TIMEOUT'),
  sheetNotConfigured('SHEET_NOT_CONFIGURED'),
  sheetUnreachable('SHEET_UNREACHABLE'),
  sheetSchema('SHEET_SCHEMA'),
  unknownAction('UNKNOWN_ACTION'),
  internal('INTERNAL'),

  /// لا يوجد اتصال أو انتهت مهلة الطلب (خاص بالتطبيق).
  network('NETWORK'),

  /// رد غير مفهوم من الخادم (خاص بالتطبيق).
  badResponse('BAD_RESPONSE');

  const ApiErrorCode(this.wire);
  final String wire;

  static ApiErrorCode fromWire(String? value) =>
      ApiErrorCode.values.firstWhere((c) => c.wire == value, orElse: () => ApiErrorCode.internal);
}

class ApiException implements Exception {
  const ApiException(this.code, this.message, {this.field, this.details = const {}});

  factory ApiException.fromJson(Map<String, dynamic> json) => ApiException(
        ApiErrorCode.fromWire(json['code'] as String?),
        (json['message'] as String?) ?? 'حدث خطأ غير متوقع في الخادم.',
        field: json['field'] as String?,
        details: (json['details'] as Map?)?.cast<String, dynamic>() ?? const {},
      );

  final ApiErrorCode code;

  /// رسالة عربية جاهزة للعرض.
  final String message;

  /// اسم الحقل في الطلب عند أخطاء التحقق.
  final String? field;
  final Map<String, dynamic> details;

  /// يجب إعادة تسجيل الدخول.
  bool get requiresLogin => const {
        ApiErrorCode.authRequired,
        ApiErrorCode.authExpired,
        ApiErrorCode.sessionStale,
      }.contains(code);

  /// آمن لإعادة المحاولة بنفس requestId.
  bool get isRetryable => const {ApiErrorCode.network, ApiErrorCode.lockTimeout}.contains(code);

  @override
  String toString() => 'ApiException(${code.wire}, $message${field == null ? '' : ', field: $field'})';
}
