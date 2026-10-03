import '../models/dashboard.dart';
import '../models/records.dart';
import '../models/settings.dart';
import '../models/sheet_status.dart';
import '../models/user.dart';
import 'api_exception.dart';
import 'backend_api.dart';

/// تحويل دوال [BackendApi] المحددة إلى إجراءات العقد (docs/API.md §3 و§6) فوق [call].
///
/// يستخدمه الخادم الحقيقي والتجريبي معًا، فيمر الاثنان بنفس قراءة الـ JSON.
mixin BackendActions on BackendApi {
  @override
  Future<LoginResult> login(String idToken) async {
    final data = await call('auth.login', payload: {'idToken': idToken});
    return parseData(() => LoginResult.fromJson(data));
  }

  @override
  Future<AppUser> me() async {
    final data = await call('auth.me');
    return parseData(() => AppUser.fromJson(_map(data['user'])));
  }

  @override
  Future<DashboardData> dashboard({String period = 'season', String? coolerId}) async {
    final data = await call('dashboard.get', payload: {
      'period': period,
      if (coolerId != null && coolerId.isNotEmpty) 'coolerId': coolerId,
    });
    return parseData(() => DashboardData.fromJson(data));
  }

  @override
  Future<BusinessSettings> settings() async {
    final data = await call('settings.get');
    return parseData(() => BusinessSettings.fromJson(data));
  }

  @override
  Future<SheetStatus> sheetStatus() async {
    final data = await call('sheet.status');
    return parseData(() => SheetStatus.fromJson(data));
  }

  @override
  Future<SheetStatus> sheetRepair({String? requestId}) async {
    final data = await call('sheet.repair', mutation: true, requestId: requestId);
    return parseData(() => SheetStatus.fromJson(data));
  }

  @override
  Future<SheetStatus> sheetConnect(String spreadsheet, {String? requestId}) async {
    final data = await call(
      'sheet.connect',
      payload: {'spreadsheet': spreadsheet.trim()},
      mutation: true,
      requestId: requestId,
    );
    return parseData(() => SheetStatus.fromJson(data));
  }

  @override
  Future<List<AppUser>> listUsers() async {
    final data = await call('users.list');
    return parseData(() => [for (final u in (data['users'] as List?) ?? const []) AppUser.fromJson(_map(u))]);
  }

  @override
  Future<AppUser> addUser({
    required String email,
    required String name,
    required UserRole role,
    UserPermissions? permissions,
    String? requestId,
  }) async {
    final data = await call(
      'users.add',
      payload: {
        'email': email.trim(),
        'name': name.trim(),
        'role': role.wire,
        if (permissions != null) 'permissions': permissions.toEditableJson(),
      },
      mutation: true,
      requestId: requestId,
    );
    return parseData(() => AppUser.fromJson(_map(data['user'])));
  }

  @override
  Future<AppUser> updateUser({
    required String id,
    required int expectedVersion,
    String? name,
    UserRole? role,
    bool? active,
    UserPermissions? permissions,
    String? requestId,
  }) async {
    final data = await call(
      'users.update',
      payload: {
        'id': id,
        'expectedVersion': expectedVersion,
        if (name != null) 'name': name.trim(),
        if (role != null) 'role': role.wire,
        if (active != null) 'status': active ? 'active' : 'disabled',
        if (permissions != null) 'permissions': permissions.toEditableJson(),
      },
      mutation: true,
      requestId: requestId,
    );
    return parseData(() => AppUser.fromJson(_map(data['user'])));
  }

  // ---------------------------------------------------------------- القراءة: البرادات والعمليات

  @override
  Future<List<CoolerSummary>> listCoolers({String status = 'all'}) async {
    final data = await call('coolers.list', payload: {'status': status});
    return parseData(() => [for (final c in _items(data['coolers'])) CoolerSummary.fromJson(c)]);
  }

  @override
  Future<CoolerDetail> getCooler(String id) async {
    final data = await call('coolers.get', payload: {'id': id});
    return parseData(() => CoolerDetail.fromJson(data));
  }

  @override
  Future<List<Farmer>> listFarmers({String? query, bool includeInactive = false}) async {
    final data = await call('farmers.list', payload: {
      if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
      if (includeInactive) 'includeInactive': true,
    });
    return parseData(() => [for (final f in _items(data['farmers'])) Farmer.fromJson(f)]);
  }

  @override
  Future<List<Purchase>> listPurchases({
    String? coolerId,
    String? farmerId,
    String? from,
    String? to,
    bool includeCancelled = false,
  }) async {
    final data = await call('purchases.list', payload: {
      'coolerId': ?coolerId,
      'farmerId': ?farmerId,
      'from': ?from,
      'to': ?to,
      if (includeCancelled) 'includeCancelled': true,
    });
    return parseData(() => [for (final p in _items(data['purchases'])) Purchase.fromJson(p)]);
  }

  @override
  Future<List<Payment>> listPayments({String? targetId, String? payeeId, String? coolerId}) async {
    final data = await call('payments.list', payload: {
      'targetId': ?targetId,
      'payeeId': ?payeeId,
      'coolerId': ?coolerId,
    });
    return parseData(() => [for (final p in _items(data['payments'])) Payment.fromJson(p)]);
  }

  @override
  Future<List<PackagingSummary>> listPackaging({String? status, String? coolerId}) async {
    final data = await call('packaging.list', payload: {
      'status': ?status,
      'coolerId': ?coolerId,
    });
    return parseData(() => [for (final p in _items(data['packaging'])) PackagingSummary.fromJson(p)]);
  }

  @override
  Future<PackagingDetail> getPackaging(String id) async {
    final data = await call('packaging.get', payload: {'id': id});
    return parseData(() => PackagingDetail.fromJson(data));
  }

  @override
  Future<List<ItemType>> listItemTypes() async {
    final data = await call('itemTypes.list');
    return parseData(() => [for (final t in _items(data['itemTypes'])) ItemType.fromJson(t)]);
  }

  // ---------------------------------------------------------------- الحفظ: البرادات والعمليات

  @override
  Future<CoolerSummary> createCooler({String? name, String? carNo, String? driver, String? notes, String? requestId}) async {
    final data = await call(
      'coolers.create',
      payload: _clean({'name': name, 'carNo': carNo, 'driver': driver, 'notes': notes}),
      mutation: true,
      requestId: requestId,
    );
    return parseData(() => CoolerSummary.fromJson(_map(data['cooler'])));
  }

  @override
  Future<CoolerSummary> closeCooler({
    required String id,
    required int expectedVersion,
    required int clientPendingCount,
    String? requestId,
  }) async {
    final data = await call(
      'coolers.close',
      payload: {'id': id, 'expectedVersion': expectedVersion, 'clientPendingCount': clientPendingCount},
      mutation: true,
      requestId: requestId,
    );
    return parseData(() => CoolerSummary.fromJson(_map(data['cooler'])));
  }

  @override
  Future<CoolerSummary> reopenCooler({required String id, required String reason, String? requestId}) async {
    final data = await call(
      'coolers.reopen',
      payload: {'id': id, 'reason': reason.trim()},
      mutation: true,
      requestId: requestId,
    );
    return parseData(() => CoolerSummary.fromJson(_map(data['cooler'])));
  }

  @override
  Future<Farmer> createFarmer({
    required String name,
    String? phone,
    String? village,
    String? notes,
    bool allowDuplicate = false,
    String? requestId,
  }) async {
    final data = await call(
      'farmers.create',
      payload: {
        'name': name.trim(),
        ..._clean({'phone': phone, 'village': village, 'notes': notes}),
        if (allowDuplicate) 'allowDuplicate': true,
      },
      mutation: true,
      requestId: requestId,
    );
    return parseData(() => Farmer.fromJson(_map(data['farmer'])));
  }

  @override
  Future<Farmer> updateFarmer({
    required String id,
    required int expectedVersion,
    String? name,
    String? phone,
    String? village,
    String? notes,
    bool? active,
    String? requestId,
  }) async {
    final data = await call(
      'farmers.update',
      payload: {
        'id': id,
        'expectedVersion': expectedVersion,
        if (name != null) 'name': name.trim(),
        // نص فارغ = مسح الحقل، فلا نستخدم _clean هنا.
        if (phone != null) 'phone': phone.trim(),
        if (village != null) 'village': village.trim(),
        if (notes != null) 'notes': notes.trim(),
        if (active != null) 'status': active ? 'active' : 'inactive',
      },
      mutation: true,
      requestId: requestId,
    );
    return parseData(() => Farmer.fromJson(_map(data['farmer'])));
  }

  @override
  Future<PurchaseResult> createPurchase(PurchaseInput input, {String? requestId}) async {
    final data = await call('purchases.create', payload: input.toJson(), mutation: true, requestId: requestId);
    return parseData(() => PurchaseResult.fromJson(data));
  }

  @override
  Future<Purchase> updatePurchase({
    required String id,
    required int expectedVersion,
    required Map<String, dynamic> changes,
    String? requestId,
  }) async {
    final data = await call(
      'purchases.update',
      payload: {'id': id, 'expectedVersion': expectedVersion, 'changes': changes},
      mutation: true,
      requestId: requestId,
    );
    return parseData(() => Purchase.fromJson(_map(data['purchase'])));
  }

  @override
  Future<Purchase> cancelPurchase({required String id, required String reason, String? requestId}) async {
    final data = await call(
      'purchases.cancel',
      payload: {'id': id, 'reason': reason.trim()},
      mutation: true,
      requestId: requestId,
    );
    return parseData(() => Purchase.fromJson(_map(data['purchase'])));
  }

  @override
  Future<PaymentResult> createPayment({
    required PaymentTarget targetType,
    required String targetId,
    required int amountPiasters,
    PaymentMethod method = PaymentMethod.cash,
    String? paidAt,
    String? notes,
    String? requestId,
  }) async {
    final data = await call(
      'payments.create',
      payload: {
        'targetType': targetType.wire,
        'targetId': targetId,
        'amountPiasters': amountPiasters,
        'method': method.wire,
        ..._clean({'paidAt': paidAt, 'notes': notes}),
      },
      mutation: true,
      requestId: requestId,
    );
    return parseData(() => PaymentResult.fromJson(data));
  }

  @override
  Future<PaymentResult> cancelPayment({required String id, required String reason, String? requestId}) async {
    final data = await call(
      'payments.cancel',
      payload: {'id': id, 'reason': reason.trim()},
      mutation: true,
      requestId: requestId,
    );
    return parseData(() => PaymentResult.fromJson(data));
  }

  @override
  Future<PackagingDetail> savePackaging(PackagingDraftInput input, {String? requestId}) async {
    final data = await call('packaging.save', payload: input.toJson(), mutation: true, requestId: requestId);
    return parseData(() => PackagingDetail.fromJson(data));
  }

  @override
  Future<PackagingDetail> approvePackaging({required String id, required int expectedVersion, String? requestId}) async {
    final data = await call(
      'packaging.approve',
      payload: {'id': id, 'expectedVersion': expectedVersion},
      mutation: true,
      requestId: requestId,
    );
    return parseData(() => PackagingDetail.fromJson(data));
  }

  @override
  Future<PackagingSummary> cancelPackaging({required String id, required String reason, String? requestId}) async {
    final data = await call(
      'packaging.cancel',
      payload: {'id': id, 'reason': reason.trim()},
      mutation: true,
      requestId: requestId,
    );
    return parseData(() => PackagingSummary.fromJson(_map(data['packaging'])));
  }

  @override
  Future<ItemType> saveItemType({
    String? id,
    required String name,
    required String unit,
    int? order,
    bool? active,
    String? requestId,
  }) async {
    final data = await call(
      'itemTypes.save',
      payload: {
        'id': ?id,
        'name': name.trim(),
        'unit': unit.trim(),
        'order': ?order,
        'active': ?active,
      },
      mutation: true,
      requestId: requestId,
    );
    return parseData(() => ItemType.fromJson(_map(data['itemType'])));
  }

  @override
  Future<BusinessSettings> updateSettings(Map<String, dynamic> changes, {String? requestId}) async {
    final data = await call('settings.update', payload: changes, mutation: true, requestId: requestId);
    return parseData(() => BusinessSettings.fromJson(data));
  }

  /// يحوّل أي خطأ في شكل البيانات المستلمة إلى [ApiErrorCode.badResponse] برسالة عربية.
  T parseData<T>(T Function() parse) {
    try {
      return parse();
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        ApiErrorCode.badResponse,
        'وصل رد من الخادم لكن بياناته ناقصة أو بصيغة غير متوقعة. '
        'تأكد أن التطبيق والخادم على آخر إصدار، ثم أعد المحاولة.',
      );
    }
  }
}

Map<String, dynamic> _map(Object? v) => (v as Map).cast<String, dynamic>();

List<Map<String, dynamic>> _items(Object? v) => [for (final e in (v as List?) ?? const []) _map(e)];

/// يحذف الحقول الفارغة الاختيارية من حمولة إنشاء.
Map<String, dynamic> _clean(Map<String, String?> fields) => {
      for (final e in fields.entries)
        if (e.value != null && e.value!.trim().isNotEmpty) e.key: e.value!.trim(),
    };
