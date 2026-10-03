import '../models/dashboard.dart';
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
