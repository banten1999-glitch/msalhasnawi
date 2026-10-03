/// إعدادات التشغيل.
///
/// عنوان الخادم المنشور مضمّن افتراضيًا، فيكفي `flutter build apk` أو `flutter build web` دون إضافات.
/// للتغيير عند البناء:
///   flutter run --dart-define=API_URL=https://script.google.com/macros/s/XXXX/exec
///   flutter run --dart-define=API_URL=          (دون خادم: تظهر شاشة «إعداد الخادم مطلوب»)
///   flutter run --dart-define=DEMO=true         (وضع تجريبي ببيانات ثابتة، للتطوير فقط)
abstract final class AppConfig {
  /// رابط Apps Script المنشور (Web app ← /exec). ليس سرًا: الحماية كلها في الخادم.
  static const deployedApiUrl =
      'https://script.google.com/macros/s/AKfycbwEbgR1ESfSuV0p-ZcTldEfs8qGWx0U8F_0IDbLE-q5G_1M6_e5VJvql1gQDYmnGjUQ/exec';

  static const apiUrl = String.fromEnvironment('API_URL', defaultValue: deployedApiUrl);
  static const demoMode = bool.fromEnvironment('DEMO');
  static const appVersion = '1.0.0';

  static bool get isConfigured => demoMode || apiUrl.isNotEmpty;
}
