import 'package:flutter_test/flutter_test.dart';
import 'package:rumman_calculator/core/format/numbers.dart';

void main() {
  group('normalizeDigits', () {
    test('يحوّل الأرقام العربية والفارسية والفاصلة العشرية العربية', () {
      expect(normalizeDigits('١٢٣٤٥٦٧٨٩٠'), '1234567890');
      expect(normalizeDigits('۱۲۳'), '123');
      expect(normalizeDigits('١٠٫٦'), '10.6');
    });

    test('يحذف فواصل الآلاف والمسافات', () {
      expect(normalizeDigits('٨٬٢٥٠٫٠٠'), '8250.00');
      expect(normalizeDigits(' 1,234 '), '1234');
    });
  });

  group('parseToMinor', () {
    test('أعداد صحيحة وعشرية بأرقام لاتينية وعربية', () {
      expect(parseToMinor('15', 2), 1500);
      expect(parseToMinor('١٥', 2), 1500);
      expect(parseToMinor('١٠٫٦', 3), 10600);
      expect(parseToMinor('10.6', 3), 10600);
      expect(parseToMinor('.5', 2), 50);
      expect(parseToMinor('7.', 2), 700);
      expect(parseToMinor('0', 2), 0);
    });

    test('تقريب النصف للأعلى عند زيادة المنازل', () {
      expect(parseToMinor('0.125', 2), 13);
      expect(parseToMinor('0.124', 2), 12);
      expect(parseToMinor('12.3455', 3), 12346);
    });

    test('نص فارغ أو غير صالح أو سالب يعيد null', () {
      expect(parseToMinor('', 2), isNull);
      expect(parseToMinor('   ', 2), isNull);
      expect(parseToMinor('abc', 2), isNull);
      expect(parseToMinor('-5', 2), isNull);
      expect(parseToMinor('1.2.3', 2), isNull);
    });

    test('لا تقريب عشري: 0.1 + 0.2 تبقى دقيقة', () {
      expect(parseToMinor('0.1', 2)! + parseToMinor('0.2', 2)!, parseToMinor('0.3', 2));
    });
  });

  group('مثال 50 صندوقًا × 11 كغ × 15 ج.م', () {
    int value(int weightGrams, int pricePerKgPiasters) => (weightGrams * pricePerKgPiasters + 500) ~/ 1000;

    test('بأرقام لاتينية', () {
      final boxes = parseToMinor('50', 0)!;
      final avgGrams = parseToMinor('11', 3)!;
      final price = parseToMinor('15', 2)!;
      expect(boxes, 50);
      expect(avgGrams, 11000);
      expect(price, 1500);
      final weight = boxes * avgGrams;
      expect(weight, 550000);
      expect(value(weight, price), 825000);
      expect(formatWeight(weight), '550');
      expect(formatMoney(value(weight, price)), '8,250.00');
    });

    test('بأرقام عربية', () {
      final weight = parseToMinor('٥٠', 0)! * parseToMinor('١١', 3)!;
      expect(formatMoney(value(weight, parseToMinor('١٥', 2)!)), '8,250.00');
    });
  });

  group('التنسيق', () {
    test('formatMoney', () {
      expect(formatMoney(4083940), '40,839.40');
      expect(formatMoney(0), '0.00');
      expect(formatMoney(5), '0.05');
      expect(formatMoney(-150), '-1.50');
      expect(formatMoney(117648240), '1,176,482.40');
      expect(formatMoney(825049, decimals: 0), '8,250');
      expect(formatMoney(825050, decimals: 0), '8,251');
    });

    test('formatWeight منزلة واحدة دون أصفار زائدة', () {
      expect(formatWeight(2718200), '2,718.2');
      expect(formatWeight(78315600), '78,315.6');
      expect(formatWeight(550000), '550');
      expect(formatWeight(10650, decimals: 3), '10.65');
    });

    test('formatCount', () {
      expect(formatCount(7142), '7,142');
      expect(formatCount(12), '12');
    });

    test('formatLocalTimestamp يعرض وقت العمل كما هو', () {
      expect(formatLocalTimestamp('2026-10-02T06:40:00+03:00'), '2026-10-02 · 06:40\u00A0ص');
      expect(formatLocalTimestamp('2026-10-02T16:12:00+03:00', withDate: false), '04:12\u00A0م');
      expect(formatLocalTimestamp('2026-10-02T00:05:00+03:00', withDate: false), '12:05\u00A0ص');
      expect(formatLocalTimestamp(null), '');
    });
  });
}
