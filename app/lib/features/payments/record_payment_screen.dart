import 'package:flutter/material.dart';

import '../shell/placeholder_screen.dart';
import '../../core/models/records.dart';

/// تسجيل دفعة لعملية شراء رمان أو شراء تعبئة. دون [targetId] يختار المستخدم المستفيد ثم العملية.
class RecordPaymentScreen extends StatelessWidget {
  const RecordPaymentScreen({super.key, this.targetType, this.targetId});

  final PaymentTarget? targetType;
  final String? targetId;

  @override
  Widget build(BuildContext context) => const PlaceholderPage(title: 'تسجيل دفعة', icon: Icons.payments_outlined);
}
