import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// النص الثابت لكل قسم أو إجراء لم يُبنَ بعد.
const kNotBuiltYetMessage = 'هذا القسم قيد التنفيذ في المرحلة التالية';

/// صفحة صادقة لقسم لم يكتمل: لا تعرض أي بيانات مصطنعة.
class SectionPlaceholder extends StatelessWidget {
  const SectionPlaceholder({super.key, required this.title, required this.icon, this.onBack, this.backLabel});

  final String title;
  final IconData icon;
  final VoidCallback? onBack;
  final String? backLabel;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: icon,
      iconColor: AppColors.inkSecondary,
      title: title,
      message: kNotBuiltYetMessage,
      actionLabel: onBack == null ? null : (backLabel ?? 'العودة إلى لوحة التحكم'),
      // سهم الرجوع ينعكس تلقائيًا في الاتجاه من اليمين لليسار.
      actionIcon: backLabel == null ? Icons.space_dashboard_outlined : Icons.arrow_back,
      onAction: onBack,
      footer: const InlineBanner(
        kind: BannerKind.info,
        message: 'لا تُعرض هنا أي أرقام حتى يكتمل القسم ويقرأ بياناته من الملف المركزي.',
      ),
    );
  }
}

/// يفتح صفحة «قيد التنفيذ» فوق الشاشة الحالية لإجراء لم يُبنَ بعد (إضافة شراء، تسجيل دفعة...).
Future<void> openPlaceholderPage(BuildContext context, {required String title, required IconData icon}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => PlaceholderPage(title: title, icon: icon)),
  );
}

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.ivory,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        toolbarHeight: 64,
        title: Text(title, style: UiText.pageTitle),
      ),
      body: SectionPlaceholder(
        title: title,
        icon: icon,
        backLabel: 'رجوع',
        onBack: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}
