import 'dart:typed_data';

/// على غير الويب لا يوجد تنزيل من المتصفح: يعيد false، والتطبيق يستخدم نافذة المشاركة بدلًا منه.
Future<bool> downloadBytes(Uint8List bytes, {required String fileName, required String mimeType}) async => false;
