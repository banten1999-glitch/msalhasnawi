import 'package:flutter/material.dart';

import '../shell/placeholder_screen.dart';

/// قسم «المدفوعات»: كل الدفعات مع الفلاتر، والمستحقات المتبقية للمزارعين والموردين.
///
/// يُعرض داخل الواجهة الرئيسية (دون Scaffold): على الهاتف يأتي الشريط العلوي من HomeShell، وعلى الشاشات
/// العريضة يعرض القسم PageHeader بنفسه مثل لوحة التحكم.
class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) => const SectionPlaceholder(title: 'المدفوعات', icon: Icons.payments_outlined);
}
