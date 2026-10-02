/// زر Google المرسوم بمكتبة Google Identity Services (للويب فقط).
///
/// الاستيراد الشرطي يضمن أن نسخ Android وiPhone لا تستورد أي كود خاص بالمتصفح.
library;

export 'google_web_button_stub.dart' if (dart.library.js_interop) 'google_web_button_web.dart';
