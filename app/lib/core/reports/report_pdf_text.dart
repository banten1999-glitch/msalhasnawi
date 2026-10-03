/// نص عربي صحيح في PDF.
///
/// مكتبة pdf تشكّل العربية وترتبها جيدًا (خوارزمية الاتجاه الثنائي في bidi_utils)، لكنها في وضع
/// pw.TextDirection.rtl تضع كل كلمة بعرض حبرها (right − left) بدل عرضها الفعلي (advanceWidth)، فتأكل الحروف
/// ذات الذيل إلى اليسار (مثل «ر» الأخيرة) المسافة التالية: «تقرير البراد» تظهر «تقريرالبراد».
///
/// الحل هنا: نقسم النص إلى أسطر بأنفسنا بترتيبه المنطقي (من اليمين)، ثم نحوّل كل سطر إلى ترتيبه المرئي
/// المشكَّل بالدالة نفسها التي تستخدمها المكتبة، ونرسمه كنص من اليسار لليمين، فتُقاس الكلمات والمسافات
/// بعرضها الفعلي كما في أي نص لاتيني.
library;

import 'package:pdf/widgets.dart' as pw;
// الدالة نفسها التي يستخدمها pw.Text للنص العربي (pdf 3.13). ليست جزءًا من الواجهة العامة للمكتبة؛ إن تغيّر
// مسارها بعد ترقية pdf يفشل البناء فورًا (ولا يتغير شيء بصمت).
// ignore: implementation_imports
import 'package:pdf/src/pdf/font/bidi_utils.dart' as pdf_bidi;

/// يجهّز النص للخط ومحرك PDF: المسافات غير القابلة للكسر وأسطر النص تصبح مسافة عادية، وتُحذف علامات
/// الاتجاه والمحارف الخفية التي لا يحتويها الخط.
String pdfSafeText(String s) => s
    .replaceAll(RegExp('[   \t\r\n]'), ' ')
    .replaceAll(RegExp('[​-‏‪-‮⁦-⁩﻿]'), '')
    .replaceAll(RegExp(' {2,}'), ' ')
    .trim();

/// الترتيب المرئي (من اليسار لليمين) المشكَّل لسطر منطقي واحد بلا أسطر جديدة.
///
/// logicalToVisual يعكس ترتيب الكلمات في آخر خطوة ليناسب تخطيط rtl في المكتبة؛ نعيده هنا لأننا نرسم ltr.
String visualLine(String logical) {
  if (logical.isEmpty) return '';
  return pdf_bidi.logicalToVisual(logical).split(' ').reversed.join(' ');
}

/// نص عربي (أو مختلط) بمسافات صحيحة، يلتف على عدة أسطر بالترتيب الصحيح من اليمين.
///
/// [align]: محاذاة كل سطر داخل عرض الفقرة (right = بداية السطر العربي).
pw.Widget rtlText(String text, {required pw.TextStyle style, pw.TextAlign align = pw.TextAlign.right, int? maxLines}) {
  final logical = pdfSafeText(text);
  return pw.LayoutBuilder(builder: (context, constraints) {
    final resolved = pw.Theme.of(context).defaultTextStyle.merge(style);
    final font = resolved.font!.getFont(context);
    final size = resolved.fontSize!;
    double width(String visual) => visual.isEmpty ? 0 : font.stringMetrics(visual).advanceWidth * size;

    final maxWidth = constraints != null && constraints.hasBoundedWidth ? constraints.maxWidth : double.infinity;
    final space = width(' ');
    final lines = <String>[];
    var current = <String>[];
    var used = 0.0;
    for (final word in logical.split(' ')) {
      if (word.isEmpty) continue;
      final w = width(visualLine(word));
      if (current.isNotEmpty && used + space + w > maxWidth + 0.01) {
        lines.add(current.join(' '));
        current = [word];
        used = w;
      } else {
        used += (current.isEmpty ? 0 : space) + w;
        current.add(word);
      }
    }
    if (current.isNotEmpty) lines.add(current.join(' '));
    if (maxLines != null && lines.length > maxLines) lines.removeRange(maxLines, lines.length);

    pw.Widget line(String l) =>
        pw.Text(visualLine(l), style: style, textDirection: pw.TextDirection.ltr, textAlign: align);
    if (lines.length <= 1) return line(lines.isEmpty ? '' : lines.first);
    return pw.Column(
      // داخل صفحة rtl: start = اليمين.
      crossAxisAlignment: switch (align) {
        pw.TextAlign.left => pw.CrossAxisAlignment.end,
        pw.TextAlign.center => pw.CrossAxisAlignment.center,
        _ => pw.CrossAxisAlignment.start,
      },
      children: [for (final l in lines) line(l)],
    );
  });
}
