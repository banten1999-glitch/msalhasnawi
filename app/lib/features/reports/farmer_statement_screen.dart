import 'package:flutter/material.dart';

import '../shell/placeholder_screen.dart';

/// كشف حساب مزارع: كل عمليات الشراء والدفعات والمتبقي، مع التصدير.
class FarmerStatementScreen extends StatelessWidget {
  const FarmerStatementScreen({super.key, required this.farmerId});

  final String farmerId;

  @override
  Widget build(BuildContext context) => const PlaceholderPage(title: 'كشف حساب المزارع', icon: Icons.receipt_long_outlined);
}
