import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// ينزّل [bytes] باسم [fileName] عبر رابط مؤقت (Blob + عنصر a مخفي) فيظهر في تنزيلات المتصفح.
Future<bool> downloadBytes(Uint8List bytes, {required String fileName, required String mimeType}) async {
  final blob = web.Blob(<JSAny>[bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  // يُحرَّر الرابط بعد أن يبدأ المتصفح التنزيل.
  Timer(const Duration(minutes: 1), () => web.URL.revokeObjectURL(url));
  return true;
}
