/// معرّفات OAuth لتسجيل الدخول بحساب Google.
///
/// هذه معرّفات عامة وليست أسرارًا؛ يجوز وضعها داخل التطبيق.
/// لا يوضع أي «Client secret» أو مفتاح خدمة داخل التطبيق أبدًا.
abstract final class GoogleAuthConfig {
  /// عميل الويب: يُستخدم لتسجيل الدخول على الويب، ويُمرَّر كـ serverClientId
  /// على Android وiPhone حتى يحصل التطبيق على ID token يتحقق منه الخادم.
  static const webClientId = '833981951758-668sjormn0kp8lm4e8c0ioltdr0ctip8.apps.googleusercontent.com';

  /// عميل iPhone (مرتبط بمعرّف الحزمة com.alhasnawi.rummanCalculator).
  static const iosClientId = '833981951758-pb57t33tr66q4b8c3r9tsd3gnbs4doi5.apps.googleusercontent.com';

  /// عميل Android (مرتبط باسم الحزمة com.alhasnawi.rumman_calculator وبصمة SHA-1 لمفتاح التوقيع).
  /// لا يُمرَّر في الكود؛ Google تتعرف عليه من اسم الحزمة والبصمة.
  static const androidClientId = '833981951758-c4f37gpodur13gg933ka3hi14359alg1.apps.googleusercontent.com';

  /// كل المعرّفات التي يقبلها الخادم كـ audience عند التحقق من ID token.
  static const allowedAudiences = [webClientId, iosClientId, androidClientId];
}
