import 'package:flutter/material.dart';

import '../shell/placeholder_screen.dart';

/// مراجعة ما قبل التقفيل ثم coolers.close (مع عدد العمليات بانتظار المزامنة).
class CloseCoolerScreen extends StatelessWidget {
  const CloseCoolerScreen({super.key, required this.coolerId});

  final String coolerId;

  @override
  Widget build(BuildContext context) => const PlaceholderPage(title: 'تقفيل البراد', icon: Icons.lock_outline);
}
