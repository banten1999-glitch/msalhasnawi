import 'package:flutter/material.dart';

import '../shell/placeholder_screen.dart';

/// قسم «مشتريات التعبئة والتغليف»: المسودات والمعتمدة والملغاة.
///
/// يُعرض داخل الواجهة الرئيسية (دون Scaffold): على الهاتف يأتي الشريط العلوي من HomeShell، وعلى الشاشات
/// العريضة يعرض القسم PageHeader بنفسه مثل لوحة التحكم.
class PackagingScreen extends StatelessWidget {
  const PackagingScreen({super.key});

  @override
  Widget build(BuildContext context) => const SectionPlaceholder(title: 'مشتريات التعبئة والتغليف', icon: Icons.inventory_2_outlined);
}
