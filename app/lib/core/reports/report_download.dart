/// تنزيل ملف من المتصفح (للويب فقط).
///
/// الاستيراد الشرطي يضمن أن نسخ Android وiPhone واختبارات Dart لا تستورد أي كود خاص بالمتصفح.
library;

export 'report_download_stub.dart' if (dart.library.js_interop) 'report_download_web.dart';
