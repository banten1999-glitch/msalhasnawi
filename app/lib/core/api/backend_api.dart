import '../models/dashboard.dart';
import '../models/records.dart';
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

  /// [status]: open | closed | all. الأحدث أولًا.
  Future<List<CoolerSummary>> listCoolers({String status = 'all'});

  Future<CoolerDetail> getCooler(String id);

  Future<List<Farmer>> listFarmers({String? query, bool includeInactive = false});

  Future<List<Purchase>> listPurchases({
    String? coolerId,
    String? farmerId,
    String? from,
    String? to,
    bool includeCancelled = false,
  });

  Future<List<Payment>> listPayments({String? targetId, String? payeeId, String? coolerId});

  /// [status]: draft | approved | cancelled (null = الكل).
  Future<List<PackagingSummary>> listPackaging({String? status, String? coolerId});

  Future<PackagingDetail> getPackaging(String id);

  Future<List<ItemType>> listItemTypes();

  // ---------------------------------------------------------------- الحفظ
  //
  // كل دوال الحفظ تقبل [requestId]: مرّر المعرّف نفسه عند إعادة إرسال الحمولة نفسها (SubmissionRequestId
  // أو قائمة «بانتظار المزامنة»)، فلا يتكرر السجل. null ⇒ معرّف جديد.

  Future<CoolerSummary> createCooler({String? name, String? carNo, String? driver, String? notes, String? requestId});

  /// [clientPendingCount]: عدد عمليات هذا البراد التي ما زالت في قائمة «بانتظار المزامنة» على هذا الجهاز.
  /// أكبر من صفر ⇒ يرفض الخادم التقفيل.
  Future<CoolerSummary> closeCooler({
    required String id,
    required int expectedVersion,
    required int clientPendingCount,
    String? requestId,
  });

  /// للمدير فقط. [reason] مطلوب.
  Future<CoolerSummary> reopenCooler({required String id, required String reason, String? requestId});

  Future<Farmer> createFarmer({
    required String name,
    String? phone,
    String? village,
    String? notes,
    bool allowDuplicate = false,
    String? requestId,
  });

  Future<Farmer> updateFarmer({
    required String id,
    required int expectedVersion,
    String? name,
    String? phone,
    String? village,
    String? notes,
    bool? active,
    String? requestId,
  });

  Future<PurchaseResult> createPurchase(PurchaseInput input, {String? requestId});

  /// [changes]: الحقول المعدّلة فقط بأسماء العقد (farmerId, boxes, avgWeightGrams, weightMethod,
  /// sampleWeightsGrams, tareGrams, pricePerKgPiasters, occurredAt, notes).
  Future<Purchase> updatePurchase({
    required String id,
    required int expectedVersion,
    required Map<String, dynamic> changes,
    String? requestId,
  });

  Future<Purchase> cancelPurchase({required String id, required String reason, String? requestId});

  Future<PaymentResult> createPayment({
    required PaymentTarget targetType,
    required String targetId,
    required int amountPiasters,
    PaymentMethod method = PaymentMethod.cash,
    String? paidAt,
    String? notes,
    String? requestId,
  });

  Future<PaymentResult> cancelPayment({required String id, required String reason, String? requestId});

  Future<PackagingDetail> savePackaging(PackagingDraftInput input, {String? requestId});

  Future<PackagingDetail> approvePackaging({required String id, required int expectedVersion, String? requestId});

  Future<PackagingSummary> cancelPackaging({required String id, required String reason, String? requestId});

  Future<ItemType> saveItemType({
    String? id,
    required String name,
    required String unit,
    int? order,
    bool? active,
    String? requestId,
  });

  /// الحقول المعدّلة فقط (businessName, currencySymbol, timezone, moneyDecimals, weightDecimals,
  /// emptyBoxGrams, seasonStart).
  Future<BusinessSettings> updateSettings(Map<String, dynamic> changes, {String? requestId});

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
