import 'package:flutter/material.dart';

import '../shell/placeholder_screen.dart';

/// قسم «التقارير»: حسب البراد، المزارع، المورد، والفترة. تصدير PDF وCSV وطباعة ومشاركة.
///
/// يُعرض داخل الواجهة الرئيسية (دون Scaffold): على الهاتف يأتي الشريط العلوي من HomeShell، وعلى الشاشات
/// العريضة يعرض القسم PageHeader بنفسه مثل لوحة التحكم.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) => const SectionPlaceholder(title: 'التقارير', icon: Icons.assessment_outlined);
}
