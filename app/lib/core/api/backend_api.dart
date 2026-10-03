import '../models/dashboard.dart';
import '../models/settings.dart';
import '../models/sheet_status.dart';
import '../models/user.dart';

/// واجهة الخادم (docs/API.md). التنفيذ الحقيقي HttpBackendApi، والتجريبي DemoBackendApi.
///
/// كل الدوال ترمي [ApiException] عند الفشل.
abstract class BackendApi {
  /// توكن الجلسة الحالي (يضبطه AuthController بعد الدخول أو الاستعادة).
  String? get session;
  set session(String? value);

  // ---------------------------------------------------------------- عام

  /// يرسل أي إجراء ويعيد `data`. للإجراءات التي تغيّر البيانات مرّر [mutation]
  /// ليُرفق requestId؛ مرّر [requestId] نفسه عند إعادة المحاولة حتى لا يتكرر السجل.
  Future<Map<String, dynamic>> call(
    String action, {
    Map<String, dynamic> payload = const {},
    bool mutation = false,
    String? requestId,
  });

  // ---------------------------------------------------------------- الدخول

  /// يتحقق الخادم من ID token لدى Google ومن قائمة المستخدمين، ويعيد جلسة.
  Future<LoginResult> login(String idToken);

  Future<AppUser> me();

  // ---------------------------------------------------------------- القراءة

  Future<DashboardData> dashboard({String period = 'season', String? coolerId});

  Future<BusinessSettings> settings();

  // ---------------------------------------------------------------- الإدارة
  //
  // دوال الحفظ تقبل [requestId] اختياريًا: النموذج يمرر المعرّف نفسه عند إعادة إرسال الحمولة نفسها بعد
  // فشل (SubmissionRequestId)، فلا تُسجَّل العملية مرتين. null ⇒ معرّف جديد.

  Future<SheetStatus> sheetStatus();

  Future<SheetStatus> sheetRepair({String? requestId});

  /// يربط ملفًا آخر (رابط أو معرّف). يعيد الحالة مع [SheetStatus.warning]. للمدير الأساسي فقط.
  Future<SheetStatus> sheetConnect(String spreadsheet, {String? requestId});

  Future<List<AppUser>> listUsers();

  Future<AppUser> addUser({
    required String email,
    required String name,
    required UserRole role,
    UserPermissions? permissions,
    String? requestId,
  });

  Future<AppUser> updateUser({
    required String id,
    required int expectedVersion,
    String? name,
    UserRole? role,
    bool? active,
    UserPermissions? permissions,
    String? requestId,
  });
}
