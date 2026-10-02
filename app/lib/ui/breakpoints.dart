import 'package:flutter/widgets.dart';

/// من هذا العرض فأكثر تظهر القائمة الجانبية مثبتة بدل القائمة المنزلقة، وتتحول الصفحات إلى تخطيط الشاشات العريضة.
const double kWideBreakpoint = 1000;

/// هل الشاشة عريضة (حاسوب أو جهاز لوحي أفقي كبير)؟
bool isWideLayout(BuildContext context) => MediaQuery.sizeOf(context).width >= kWideBreakpoint;
