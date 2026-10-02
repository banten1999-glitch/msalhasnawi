import '../../core/models/user.dart';

/// قواعد الخادم الخاصة بالمديرين (docs/API.md §6 users.update)، تُعرض مسبقًا للتوضيح فقط؛ الخادم يفرضها.

/// مدير نشط بحسب الخادم: المدير الأساسي دائمًا، أو مدير حالته نشط.
bool isActiveAdmin(AppUser u) => u.isBootstrap || (u.role == UserRole.admin && u.active);

/// هل هذا آخر مدير نشط في القائمة؟
bool isLastActiveAdmin(AppUser u, List<AppUser> all) {
  if (!isActiveAdmin(u)) return false;
  return all.where(isActiveAdmin).every((x) => x.id == u.id);
}

/// سبب منع تعطيل المستخدم أو تغيير دوره، أو null إن لم يوجد.
String? lockedReason(AppUser u, List<AppUser> all) {
  if (u.isBootstrap) {
    return 'المدير الأساسي المحدد في إعدادات الخادم، لذا لا يمكن تعطيله أو تغيير دوره.';
  }
  if (isLastActiveAdmin(u, all)) {
    return 'آخر مدير نشط، لذا لا يمكن تعطيله أو تغيير دوره. أضف مديرًا آخر أولًا.';
  }
  return null;
}

/// الصلاحيات الست القابلة للتعديل لموظف الإدخال، بأسمائها في التطبيق.
const editablePermissions = <(String, String)>[
  ('addFarmers', 'إضافة المزارعين'),
  ('recordPurchases', 'تسجيل مشتريات الرمان'),
  ('editOthers', 'تعديل عمليات سجّلها غيره'),
  ('recordPayments', 'تسجيل المدفوعات'),
  ('packaging', 'مشتريات التعبئة والتغليف'),
  ('closeCoolers', 'تقفيل البرادات'),
];

bool permissionValue(UserPermissions p, String key) => switch (key) {
      'addFarmers' => p.addFarmers,
      'recordPurchases' => p.recordPurchases,
      'editOthers' => p.editOthers,
      'recordPayments' => p.recordPayments,
      'packaging' => p.packaging,
      'closeCoolers' => p.closeCoolers,
      _ => false,
    };

UserPermissions withPermission(UserPermissions p, String key, bool v) => switch (key) {
      'addFarmers' => p.copyWith(addFarmers: v),
      'recordPurchases' => p.copyWith(recordPurchases: v),
      'editOthers' => p.copyWith(editOthers: v),
      'recordPayments' => p.copyWith(recordPayments: v),
      'packaging' => p.copyWith(packaging: v),
      'closeCoolers' => p.copyWith(closeCoolers: v),
      _ => p,
    };

bool samePermissions(UserPermissions a, UserPermissions b) =>
    editablePermissions.every((e) => permissionValue(a, e.$1) == permissionValue(b, e.$1));

/// شكل مقبول لبريد إلكتروني (نفس قاعدة الخادم).
final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
