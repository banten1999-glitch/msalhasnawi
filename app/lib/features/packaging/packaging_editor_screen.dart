import 'package:flutter/material.dart';

import '../shell/placeholder_screen.dart';

/// محرر شراء تعبئة: [packagingId] == null ⇒ مسودة جديدة (مرتبطة بـ [coolerId] إن وُجد). يعرض المعتمد/الملغى للقراءة فقط.
class PackagingEditorScreen extends StatelessWidget {
  const PackagingEditorScreen({super.key, this.packagingId, this.coolerId});

  final String? packagingId;
  final String? coolerId;

  @override
  Widget build(BuildContext context) => const PlaceholderPage(title: 'شراء تعبئة', icon: Icons.inventory_2_outlined);
}
