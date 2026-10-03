import 'package:flutter/material.dart';

import '../shell/placeholder_screen.dart';

/// العمليات المحفوظة على الجهاز ولم تصل إلى الملف بعد: حالة كل عملية، إعادة المحاولة، والحذف بعد تأكيد.
class PendingSyncScreen extends StatelessWidget {
  const PendingSyncScreen({super.key});



  @override
  Widget build(BuildContext context) => const PlaceholderPage(title: 'بانتظار المزامنة', icon: Icons.cloud_upload_outlined);
}
