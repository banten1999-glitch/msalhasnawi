import 'package:flutter/material.dart';

import '../../core/models/records.dart';
import '../shell/placeholder_screen.dart';

/// يضيف مزارعًا ([farmer] == null) أو يعدّله، ويعيد السجل المحفوظ أو null.
Future<Farmer?> showFarmerEditSheet(BuildContext context, {Farmer? farmer, String? initialName}) async {
  await openPlaceholderPage(context, title: farmer == null ? 'إضافة مزارع' : 'تعديل مزارع', icon: Icons.person_add_alt);
  return null;
}
