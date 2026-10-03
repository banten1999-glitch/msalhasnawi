enum UserRole {
  admin('admin', 'مدير'),
  entry('entry', 'موظف إدخال'),
  viewer('viewer', 'مشاهدة فقط');

  const UserRole(this.wire, this.label);
  final String wire;
  final String label;

  static UserRole fromWire(String? v) => UserRole.values.firstWhere((r) => r.wire == v, orElse: () => UserRole.viewer);
}

class UserPermissions {
  const UserPermissions({
    this.addFarmers = false,
    this.recordPurchases = false,
    this.editOthers = false,
    this.recordPayments = false,
    this.packaging = false,
    this.closeCoolers = false,
    this.reopenCoolers = false,
    this.manageUsers = false,
    this.manageSettings = false,
    this.viewData = true,
  });

  factory UserPermissions.fromJson(Map<String, dynamic> j) => UserPermissions(
        addFarmers: j['addFarmers'] == true,
        recordPurchases: j['recordPurchases'] == true,
        editOthers: j['editOthers'] == true,
        recordPayments: j['recordPayments'] == true,
        packaging: j['packaging'] == true,
        closeCoolers: j['closeCoolers'] == true,
        reopenCoolers: j['reopenCoolers'] == true,
        manageUsers: j['manageUsers'] == true,
        manageSettings: j['manageSettings'] == true,
        viewData: j['viewData'] != false,
      );

  final bool addFarmers;
  final bool recordPurchases;
  final bool editOthers;
  final bool recordPayments;
  final bool packaging;
  final bool closeCoolers;
  final bool reopenCoolers;
  final bool manageUsers;
  final bool manageSettings;
  final bool viewData;

  /// الصلاحيات القابلة للتعديل لموظف الإدخال (أعمدة صفحة المستخدمين).
  Map<String, dynamic> toEditableJson() => {
        'addFarmers': addFarmers,
        'recordPurchases': recordPurchases,
        'editOthers': editOthers,
        'recordPayments': recordPayments,
        'packaging': packaging,
        'closeCoolers': closeCoolers,
      };

  UserPermissions copyWith({
    bool? addFarmers,
    bool? recordPurchases,
    bool? editOthers,
    bool? recordPayments,
    bool? packaging,
    bool? closeCoolers,
  }) =>
      UserPermissions(
        addFarmers: addFarmers ?? this.addFarmers,
        recordPurchases: recordPurchases ?? this.recordPurchases,
        editOthers: editOthers ?? this.editOthers,
        recordPayments: recordPayments ?? this.recordPayments,
        packaging: packaging ?? this.packaging,
        closeCoolers: closeCoolers ?? this.closeCoolers,
        reopenCoolers: reopenCoolers,
        manageUsers: manageUsers,
        manageSettings: manageSettings,
        viewData: viewData,
      );
}

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.active,
    required this.permissions,
    required this.version,
    this.isBootstrap = false,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        email: j['email'] as String,
        name: (j['name'] as String?)?.trim().isNotEmpty == true ? j['name'] as String : j['email'] as String,
        role: UserRole.fromWire(j['role'] as String?),
        active: j['status'] == 'active',
        permissions: UserPermissions.fromJson((j['permissions'] as Map?)?.cast<String, dynamic>() ?? const {}),
        version: (j['version'] as num?)?.toInt() ?? 1,
        isBootstrap: j['isBootstrap'] == true,
      );

  final String id;
  final String email;
  final String name;
  final UserRole role;
  final bool active;
  final UserPermissions permissions;
  final int version;

  /// حساب المدير الأساسي المحدد في إعدادات الخادم؛ لا يمكن تعطيله.
  final bool isBootstrap;

  bool get isAdmin => role == UserRole.admin;

  /// حرفان لصورة الحساب: أول حرف من الاسم الأول وأول حرف من اسم العائلة.
  ///
  /// تُتجاهل «ال» في أول اسم العائلة (محمد الحسناوي ← م ح)، ويُعامل الاسم المركّب مثل «عبد الله»
  /// كاسم واحد (كريم عبد الله ← ك ع).
  String get initials => initialsOf(name);

  static const _compoundPrefixes = {'عبد', 'أبو', 'ابو', 'أبي', 'ابي', 'بن', 'ابن', 'آل'};

  static String initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '؟';
    String first(String s) => String.fromCharCode(s.runes.first);
    if (parts.length == 1) return first(parts.first);
    var family = parts.last;
    if (parts.length >= 3 && _compoundPrefixes.contains(parts[parts.length - 2])) {
      family = parts[parts.length - 2];
    } else if (family.startsWith('ال') && family.runes.length > 3) {
      family = family.substring(2);
    }
    return '${first(parts.first)} ${first(family)}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'role': role.wire,
        'status': active ? 'active' : 'disabled',
        'isBootstrap': isBootstrap,
        'version': version,
        'permissions': {
          ...permissions.toEditableJson(),
          'reopenCoolers': permissions.reopenCoolers,
          'manageUsers': permissions.manageUsers,
          'manageSettings': permissions.manageSettings,
          'viewData': permissions.viewData,
        },
      };
}

class LoginResult {
  const LoginResult({required this.session, required this.expiresAt, required this.user});

  factory LoginResult.fromJson(Map<String, dynamic> j) => LoginResult(
        session: j['session'] as String,
        expiresAt: j['expiresAt'] as String? ?? '',
        user: AppUser.fromJson((j['user'] as Map).cast<String, dynamic>()),
      );

  final String session;
  final String expiresAt;
  final AppUser user;
}
