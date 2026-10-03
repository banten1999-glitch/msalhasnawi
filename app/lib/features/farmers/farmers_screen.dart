import 'package:flutter/material.dart';

import '../shell/placeholder_screen.dart';

/// قسم «المزارعون»: بحث، إضافة، تعديل، إيقاف، وفتح كشف حساب المزارع.
///
/// يُعرض داخل الواجهة الرئيسية (دون Scaffold): على الهاتف يأتي الشريط العلوي من HomeShell، وعلى الشاشات
/// العريضة يعرض القسم PageHeader بنفسه مثل لوحة التحكم.
class FarmersScreen extends StatelessWidget {
  const FarmersScreen({super.key});

  @override
  Widget build(BuildContext context) => const SectionPlaceholder(title: 'المزارعون', icon: Icons.groups_outlined);
}
