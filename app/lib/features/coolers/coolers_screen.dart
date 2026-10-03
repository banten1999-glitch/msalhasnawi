import 'package:flutter/material.dart';

import '../shell/placeholder_screen.dart';

/// قسم «البرادات وشراء الرمان»: قائمة البرادات (مفتوحة/مقفّلة) وإنشاء براد.
///
/// يُعرض داخل الواجهة الرئيسية (دون Scaffold): على الهاتف يأتي الشريط العلوي من HomeShell، وعلى الشاشات
/// العريضة يعرض القسم PageHeader بنفسه مثل لوحة التحكم.
class CoolersScreen extends StatelessWidget {
  const CoolersScreen({super.key});

  @override
  Widget build(BuildContext context) => const SectionPlaceholder(title: 'البرادات وشراء الرمان', icon: Icons.local_shipping_outlined);
}
