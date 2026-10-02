import 'package:flutter/widgets.dart';

/// على غير الويب لا يوجد زر مرسوم؛ التطبيق يعرض زره الخاص ويستدعي authenticate().
Widget renderGoogleWebButton({required double minimumWidth}) => const SizedBox.shrink();
