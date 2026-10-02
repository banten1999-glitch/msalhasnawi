import 'package:flutter/material.dart';

import '../../core/models/user.dart';

/// أقسام الواجهة الرئيسية بترتيب القائمة.
enum ShellSection {
  dashboard('لوحة التحكم', Icons.space_dashboard_outlined),
  coolers('البرادات وشراء الرمان', Icons.local_shipping_outlined),
  farmers('المزارعون', Icons.groups_outlined),
  packaging('مشتريات التعبئة والتغليف', Icons.inventory_2_outlined),
  payments('المدفوعات', Icons.payments_outlined),
  reports('التقارير', Icons.assessment_outlined),
  settings('الإعدادات', Icons.tune);

  const ShellSection(this.label, this.icon);

  final String label;
  final IconData icon;

  /// الأقسام التي اكتملت وتقرأ من الخادم. البقية تعرض صفحة «قيد التنفيذ».
  bool get isBuilt => this == dashboard || this == settings;

  /// الإعدادات تظهر فقط لمن يملك إدارة الإعدادات أو إدارة المستخدمين. الخادم يتحقق مرة أخرى مع كل طلب.
  bool isVisibleFor(AppUser? user) {
    if (this != settings) return true;
    final p = user?.permissions;
    return p != null && (p.manageSettings || p.manageUsers);
  }

  static List<ShellSection> visibleFor(AppUser? user) => [
        for (final s in ShellSection.values)
          if (s.isVisibleFor(user)) s,
      ];
}

/// وصف قصير للدور تحت اسم المستخدم.
String roleDescription(AppUser user) => switch (user.role) {
      UserRole.admin => 'مدير · كل الصلاحيات',
      UserRole.entry => 'موظف إدخال',
      UserRole.viewer => 'مشاهدة فقط',
    };
