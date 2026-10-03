import 'package:flutter/material.dart';

import '../shell/placeholder_screen.dart';
import '../../core/models/records.dart';

/// نموذج شراء من مزارع. [purchase] != null ⇒ تعديل عملية موجودة؛ وإلا إضافة جديدة في [coolerId] (أو البراد المفتوح الحالي).
class PurchaseFormScreen extends StatelessWidget {
  const PurchaseFormScreen({super.key, this.coolerId, this.purchase});

  final String? coolerId;
  final Purchase? purchase;

  @override
  Widget build(BuildContext context) => const PlaceholderPage(title: 'شراء من مزارع', icon: Icons.scale_outlined);
}
