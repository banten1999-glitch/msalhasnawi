import 'package:flutter/material.dart';

import '../../core/models/dashboard.dart';
import '../shell/placeholder_screen.dart';

/// ينشئ برادًا جديدًا (coolers.create) ويعيده، أو null إن أُلغي.
Future<CoolerSummary?> showCreateCoolerSheet(BuildContext context) async {
  await openPlaceholderPage(context, title: 'إنشاء براد', icon: Icons.local_shipping_outlined);
  return null;
}
