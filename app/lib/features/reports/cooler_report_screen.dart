import 'package:flutter/material.dart';

import '../shell/placeholder_screen.dart';

/// تقرير براد مفصّل. [coolerId] == null ⇒ يختار المستخدم البراد (الحالي افتراضيًا).
class CoolerReportScreen extends StatelessWidget {
  const CoolerReportScreen({super.key, this.coolerId});

  final String? coolerId;

  @override
  Widget build(BuildContext context) => const PlaceholderPage(title: 'تقرير البراد', icon: Icons.assessment_outlined);
}
