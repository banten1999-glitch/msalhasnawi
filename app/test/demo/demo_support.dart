import 'package:flutter_test/flutter_test.dart';
import 'package:rumman_calculator/core/api/api_exception.dart';
import 'package:rumman_calculator/core/api/demo_backend_api.dart';
import 'package:rumman_calculator/core/models/records.dart';

/// 2 أكتوبر 2026 الساعة 10:58 ص: أوقات التصميم كما هي، وكل ما يُحفظ في الاختبار يحمل هذا الوقت.
final demoNow = DateTime(2026, 10, 2, 10, 58);

/// خادم تجريبي بلا تأخير، مسجّل الدخول بالمدير الأساسي (US-0001).
Future<DemoBackendApi> signedInDemo() async {
  final api = DemoBackendApi(latency: Duration.zero, clock: () => demoNow);
  api.session = (await api.login('demo')).session;
  return api;
}

/// يتوقع ApiException بالكود، واختياريًا الحقل وصلاحية details.permission وجزءًا من الرسالة.
Matcher throwsApi(ApiErrorCode code, {String? field, String? permission, String? message}) {
  var m = isA<ApiException>().having((e) => e.code, 'code', code);
  if (field != null) m = m.having((e) => e.field, 'field', field);
  if (permission != null) m = m.having((e) => e.details['permission'], 'details.permission', permission);
  if (message != null) m = m.having((e) => e.message, 'message', contains(message));
  return throwsA(m);
}

/// شراء جديد بقيم افتراضية: 50 صندوق × 11 كغ × 15 ج.م/كغ في البراد 14 من «الحاج محمود عبد العال».
PurchaseInput buy({
  String coolerId = 'CL-0014',
  String? farmerId = 'FR-0004',
  String? newFarmerName,
  int boxes = 50,
  int avgWeightGrams = 11000,
  int pricePerKgPiasters = 1500,
  WeightMethod weightMethod = WeightMethod.direct,
  List<int> sampleWeightsGrams = const [],
  int? tareGrams,
  String? occurredAt,
  PaymentModeInput payment = const PaymentModeInput(mode: PaymentMode.none),
}) =>
    PurchaseInput(
      coolerId: coolerId,
      farmerId: newFarmerName == null ? farmerId : null,
      newFarmerName: newFarmerName,
      boxes: boxes,
      avgWeightGrams: avgWeightGrams,
      weightMethod: weightMethod,
      sampleWeightsGrams: sampleWeightsGrams,
      tareGrams: tareGrams,
      pricePerKgPiasters: pricePerKgPiasters,
      occurredAt: occurredAt,
      payment: payment,
    );

/// الوقت كما يكتبه الخادم التجريبي: 2026-10-02T10:58:00+03:00 (بإزاحة الجهاز).
String isoLocal(DateTime t) {
  final o = t.timeZoneOffset;
  final m = o.inMinutes.abs();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)}T${two(t.hour)}:${two(t.minute)}:${two(t.second)}'
      '${o.isNegative ? '-' : '+'}${two(m ~/ 60)}:${two(m % 60)}';
}
