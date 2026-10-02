import 'api_exception.dart';
import 'backend_actions.dart';
import 'backend_api.dart';

/// خادم بديل عندما لا يُضبط API_URL ولا الوضع التجريبي: كل طلب يرمي SHEET_NOT_CONFIGURED.
///
/// التطبيق يعرض في هذه الحالة شاشة «إعداد الخادم مطلوب» ولا يرسل أي طلب.
class UnconfiguredBackendApi extends BackendApi with BackendActions {
  @override
  String? session;

  static const message = 'لم يُضبط عنوان الخادم (API_URL) في هذه النسخة من التطبيق. '
      'أعد بناء التطبيق مع \u2066--dart-define=API_URL=…/\u2060exec\u2069 كما في الملف \u2066backend/\u2060DEPLOY.md\u2069.';

  @override
  Future<Map<String, dynamic>> call(
    String action, {
    Map<String, dynamic> payload = const {},
    bool mutation = false,
    String? requestId,
  }) async {
    throw const ApiException(ApiErrorCode.sheetNotConfigured, message, details: {'reason': 'api_url_missing'});
  }
}
