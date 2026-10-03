import 'package:flutter_test/flutter_test.dart';
import 'package:rumman_calculator/core/api/request_id.dart';

void main() {
  group('SubmissionRequestId (F6: إعادة المحاولة بنفس requestId)', () {
    test('الحمولة نفسها بعد فشل ⇒ المعرّف نفسه؛ حمولة مختلفة أو بعد النجاح ⇒ معرّف جديد', () {
      var n = 0;
      final r = SubmissionRequestId(newId: () => 'id-${++n}');
      expect(r.pending, isNull);
      final a = r.idFor({'email': 'a@gmail.com', 'name': 'أ', 'role': 'entry'});
      expect(a, 'id-1');
      // إعادة الإرسال بعد خطأ شبكة: نفس الحمولة (حتى بترتيب إنشاء مماثل) ⇒ نفس المعرّف.
      expect(r.idFor({'email': 'a@gmail.com', 'name': 'أ', 'role': 'entry'}), 'id-1');
      expect(r.pending, 'id-1');
      // المستخدم عدّل البيانات ⇒ عملية مختلفة.
      expect(r.idFor({'email': 'a@gmail.com', 'name': 'أحمد', 'role': 'entry'}), 'id-2');
      // نجحت ⇒ الإرسال التالي (حتى بالحمولة نفسها) عملية جديدة.
      r.reset();
      expect(r.pending, isNull);
      expect(r.idFor({'email': 'a@gmail.com', 'name': 'أحمد', 'role': 'entry'}), 'id-3');
    });

    test('المعرّف الافتراضي UUID v4', () {
      final id = SubmissionRequestId().idFor('x');
      expect(id, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    });
  });
}
