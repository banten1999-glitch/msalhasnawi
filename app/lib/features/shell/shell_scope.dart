import 'package:flutter/widgets.dart';

import 'shell_section.dart';

/// يتيح للشاشات داخل الواجهة الرئيسية الانتقال إلى قسم آخر (مثل فتح إعدادات الملف من لوحة التحكم).
class ShellScope extends InheritedWidget {
  const ShellScope({
    super.key,
    required this.section,
    required this.visibleSections,
    required this.onSelect,
    required super.child,
  });

  final ShellSection section;
  final List<ShellSection> visibleSections;
  final ValueChanged<ShellSection> onSelect;

  bool canOpen(ShellSection s) => visibleSections.contains(s);

  void select(ShellSection s) {
    if (canOpen(s)) onSelect(s);
  }

  /// null خارج الواجهة الرئيسية (مثلًا في الاختبارات).
  static ShellScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ShellScope>();

  @override
  bool updateShouldNotify(ShellScope oldWidget) =>
      section != oldWidget.section || visibleSections.length != oldWidget.visibleSections.length;
}
