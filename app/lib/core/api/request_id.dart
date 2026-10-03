import 'dart:convert';

import 'package:uuid/uuid.dart';

/// معرّف طلب جديد (UUID v4) لعملية حفظ.
String newRequestId() => const Uuid().v4();

/// requestId لإرسال واحد من نموذج حفظ (docs/API.md §2 و§7).
///
/// ما دام المستخدم يعيد إرسال الحمولة نفسها بعد فشل (انقطاع الشبكة، انتهاء المهلة، LOCK_TIMEOUT…)
/// يُرسل المعرّف نفسه، فإن كانت المحاولة الأولى قد حُفظت في الخادم أعاد نتيجتها بدل تسجيل العملية
/// مرتين أو الرد بخطأ «مسجّل بالفعل». أي تغيير في الحمولة يبدأ معرّفًا جديدًا، وكذلك [reset] بعد النجاح.
class SubmissionRequestId {
  SubmissionRequestId({String Function()? newId}) : _newId = newId ?? newRequestId;

  final String Function() _newId;
  String? _id;
  String? _fingerprint;

  /// المعرّف الذي يُرسل مع [payload] (خريطة أو قيم قابلة لـ JSON).
  String idFor(Object? payload) {
    final fingerprint = jsonEncode(payload);
    if (_id == null || fingerprint != _fingerprint) {
      _id = _newId();
      _fingerprint = fingerprint;
    }
    return _id!;
  }

  /// المعرّف المعلّق من محاولة لم تنجح بعد (للاختبارات والتشخيص).
  String? get pending => _id;

  /// يُستدعى بعد نجاح الحفظ: الإرسال التالي عملية جديدة بمعرّف جديد.
  void reset() {
    _id = null;
    _fingerprint = null;
  }
}
