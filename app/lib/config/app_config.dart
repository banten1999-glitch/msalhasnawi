/// إعدادات التشغيل التي تُمرَّر عند البناء:
///
///   flutter run --dart-define=API_URL=https://script.google.com/macros/s/XXXX/exec
///   flutter run --dart-define=DEMO=true      (وضع تجريبي ببيانات ثابتة، للتطوير فقط)
abstract final class AppConfig {
  static const apiUrl = String.fromEnvironment('API_URL');
  static const demoMode = bool.fromEnvironment('DEMO');
  static const appVersion = '1.0.0';

  static bool get isConfigured => demoMode || apiUrl.isNotEmpty;
}
