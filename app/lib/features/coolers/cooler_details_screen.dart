import 'package:flutter/material.dart';

import '../shell/placeholder_screen.dart';

/// تفاصيل براد: الملخص، عمليات الشراء، التعبئة المرتبطة، والإجراءات (إضافة شراء، تقفيل، إعادة فتح، تقرير).
class CoolerDetailsScreen extends StatelessWidget {
  const CoolerDetailsScreen({super.key, required this.coolerId});

  final String coolerId;

  @override
  Widget build(BuildContext context) => const PlaceholderPage(title: 'تفاصيل البراد', icon: Icons.local_shipping_outlined);
}
