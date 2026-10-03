import 'package:flutter_test/flutter_test.dart';
import 'package:rumman_calculator/core/reports/report_pdf_text.dart';

void main() {
  test('نص بلا حروف عربية يبقى كما هو (الإشارات في مكانها)', () {
    expect(visualLine('+1,000.00'), '+1,000.00');
    expect(visualLine('-50.00'), '-50.00');
    expect(visualLine('P-0001'), 'P-0001');
    expect(visualLine('2026-10-02'), '2026-10-02');
  });

  test('ترتيب الكلمات العربية مرئيًا من اليسار: آخر كلمة منطقية أولًا', () {
    final words = visualLine('تقرير البراد').split(' ');
    expect(words, [visualLine('البراد'), visualLine('تقرير')]);
    // الرقم بعد الكلمة العربية يظهر على يسارها.
    expect(visualLine('براد 14').split(' '), ['14', visualLine('براد')]);
    // مشكَّلة بأشكال العرض (لا حروف أساسية منفصلة في الكلمة الموصولة).
    expect(visualLine('تقرير'), isNot('تقرير'));
  });

  test('تقسيم الأسطر بالترتيب المنطقي، والكلمات المربوطة بمسافة غير قابلة للكسر لا تُفصل', () {
    double measure(String s) => s.length.toDouble();
    expect(breakRtlLines('2026-10-02 · 06:40\u00A0ص', 13, measure), ['2026-10-02 ·', '06:40\u00A0ص']);
    expect(breakRtlLines('أ ب ج د', 3, measure), ['أ ب', 'ج د']);
    expect(breakRtlLines('كلمة', double.infinity, measure), ['كلمة']);
    expect(breakRtlLines('', 10, measure), isEmpty);
  });

  test('تنظيف النص: أسطر جديدة ومسافات خاصة وعلامات اتجاه', () {
    expect(pdfSafeText('سطر\nثانٍ'), 'سطر ثانٍ');
    expect(pdfSafeText('06:40\u00A0ص'), '06:40 ص');
    expect(pdfSafeText('06:40\u00A0ص', keepNbsp: true), '06:40\u00A0ص');
    expect(pdfSafeText('\u200Fنص\u200E  مزدوج '), 'نص مزدوج');
  });
}
