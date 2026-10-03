import 'package:rumman_calculator/core/api/api_exception.dart';
import 'package:rumman_calculator/core/api/backend_api.dart';
import 'package:rumman_calculator/core/models/dashboard.dart';
import 'package:rumman_calculator/core/models/settings.dart';
import 'package:rumman_calculator/core/models/sheet_status.dart';
import 'package:rumman_calculator/core/models/user.dart';

import 'sample_data.dart';

/// استدعاء مسجّل في [FakeBackendApi].
class FakeCall {
  FakeCall(this.action, this.payload, {this.requestId});
  final String action;
  final Map<String, dynamic> payload;

  /// requestId الذي مرّره التطبيق (null ⇒ يولّد الخادم الحقيقي معرّفًا جديدًا).
  final String? requestId;

  @override
  String toString() => 'FakeCall($action, $payload${requestId == null ? '' : ', requestId: $requestId'})';
}

/// خادم وهمي للاختبارات: يعيد بيانات معدّة مسبقًا ويسجّل كل استدعاء.
///
/// لإظهار خطأ اضبط الحقل *Error المناسب (يُرمى في كل استدعاء حتى يُمسح).
class FakeBackendApi implements BackendApi {
  FakeBackendApi({
    DashboardData? dashboardData,
    List<Map<String, dynamic>>? coolers,
    SheetStatus? sheetStatus,
    List<AppUser>? users,
    BusinessSettings? settings,
  })  : dashboardData = dashboardData ?? sampleDashboard(),
        coolers = coolers ?? sampleCoolersJson(),
        sheetStatusResult = sheetStatus ?? sampleSheetStatus(),
        users = users ?? sampleUsers(),
        settingsResult = settings ?? const BusinessSettings(seasonStart: '2026-08-01');

  @override
  String? session = 'test-session';

  final calls = <FakeCall>[];

  /// يؤخر كل رد (لاختبار حالة التحميل).
  Duration delay = Duration.zero;

  // ------------------------------------------------------------------ لوحة التحكم
  DashboardData dashboardData;
  Object? dashboardError;

  /// بديل اختياري حسب الفترة والبراد.
  DashboardData Function(String period, String? coolerId)? dashboardHandler;

  // ------------------------------------------------------------------ البرادات
  List<Map<String, dynamic>> coolers;
  Object? coolersError;

  // ------------------------------------------------------------------ الملف
  SheetStatus sheetStatusResult;
  Object? sheetStatusError;
  SheetStatus? sheetRepairResult;
  Object? sheetRepairError;
  SheetStatus Function(String spreadsheet)? sheetConnectHandler;
  Object? sheetConnectError;

  // ------------------------------------------------------------------ المستخدمون
  List<AppUser> users;
  Object? listUsersError;
  Object? addUserError;
  Object? updateUserError;

  // ------------------------------------------------------------------ الإعدادات
  BusinessSettings settingsResult;
  Object? settingsError;

  int count(String action) => calls.where((c) => c.action == action).length;
  List<FakeCall> callsOf(String action) => calls.where((c) => c.action == action).toList();

  Future<void> _record(String action, [Map<String, dynamic> payload = const {}, String? requestId]) async {
    calls.add(FakeCall(action, Map<String, dynamic>.of(payload), requestId: requestId));
    if (delay > Duration.zero) await Future<void>.delayed(delay);
  }

  static Never _throw(Object e) => throw e;

  @override
  Future<Map<String, dynamic>> call(
    String action, {
    Map<String, dynamic> payload = const {},
    bool mutation = false,
    String? requestId,
  }) async {
    await _record(action, payload, requestId);
    if (action == 'coolers.list') {
      if (coolersError != null) _throw(coolersError!);
      return {'coolers': coolers};
    }
    throw ApiException(ApiErrorCode.unknownAction, 'الإجراء «$action» غير معرّف في الخادم الوهمي.');
  }

  @override
  Future<LoginResult> login(String idToken) async {
    await _record('auth.login');
    throw const ApiException(ApiErrorCode.unknownAction, 'غير مستخدم في هذه الاختبارات.');
  }

  @override
  Future<AppUser> me() async {
    await _record('auth.me');
    return users.first;
  }

  @override
  Future<DashboardData> dashboard({String period = 'season', String? coolerId}) async {
    await _record('dashboard.get', {'period': period, 'coolerId': ?coolerId});
    if (dashboardError != null) _throw(dashboardError!);
    return dashboardHandler?.call(period, coolerId) ?? dashboardData;
  }

  @override
  Future<BusinessSettings> settings() async {
    await _record('settings.get');
    if (settingsError != null) _throw(settingsError!);
    return settingsResult;
  }

  @override
  Future<SheetStatus> sheetStatus() async {
    await _record('sheet.status');
    if (sheetStatusError != null) _throw(sheetStatusError!);
    return sheetStatusResult;
  }

  @override
  Future<SheetStatus> sheetRepair({String? requestId}) async {
    await _record('sheet.repair', const {}, requestId);
    if (sheetRepairError != null) _throw(sheetRepairError!);
    final repaired = sheetRepairResult ?? repairedSheetStatus();
    sheetStatusResult = repaired;
    return repaired;
  }

  @override
  Future<SheetStatus> sheetConnect(String spreadsheet, {String? requestId}) async {
    await _record('sheet.connect', {'spreadsheet': spreadsheet}, requestId);
    if (sheetConnectError != null) _throw(sheetConnectError!);
    final result = sheetConnectHandler?.call(spreadsheet) ?? connectedSheetStatus(spreadsheet);
    sheetStatusResult = result;
    return result;
  }

  @override
  Future<List<AppUser>> listUsers() async {
    await _record('users.list');
    if (listUsersError != null) _throw(listUsersError!);
    return List.of(users);
  }

  @override
  Future<AppUser> addUser({
    required String email,
    required String name,
    required UserRole role,
    UserPermissions? permissions,
    String? requestId,
  }) async {
    await _record('users.add', {'email': email, 'name': name, 'role': role.wire}, requestId);
    if (addUserError != null) _throw(addUserError!);
    final user = AppUser(
      id: 'US-${(users.length + 1).toString().padLeft(4, '0')}',
      email: email,
      name: name,
      role: role,
      active: true,
      permissions: permissionsForRole(role),
      version: 1,
    );
    users = [...users, user];
    return user;
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
    await _record('users.update', {
      'id': id,
      'expectedVersion': expectedVersion,
      'name': ?name,
      if (role != null) 'role': role.wire,
      if (active != null) 'status': active ? 'active' : 'disabled',
      if (permissions != null) 'permissions': permissions.toEditableJson(),
    }, requestId);
    if (updateUserError != null) _throw(updateUserError!);
    final old = users.firstWhere((u) => u.id == id);
    final nextRole = role ?? old.role;
    final updated = AppUser(
      id: old.id,
      email: old.email,
      name: name ?? old.name,
      role: nextRole,
      active: active ?? old.active,
      permissions: nextRole == UserRole.entry ? (permissions ?? old.permissions) : permissionsForRole(nextRole),
      version: old.version + 1,
      isBootstrap: old.isBootstrap,
    );
    users = [for (final u in users) u.id == id ? updated : u];
    return updated;
  }
}
