import 'package:flutter_test/flutter_test.dart';
import 'package:offline_shop_manager/main.dart';

void main() {
  test('money uses English digits and comma grouping', () {
    expect(money.format(12500), '12,500');
    expect(money.format(1234.5), '1,234.5');
  });

  test('Afghan Solar Hijri date uses Afghan month names', () {
    expect(afghanDate(DateTime(2026, 3, 21), withTime: false), '01 حمل 1405');
    expect(afghanDate(DateTime(2026, 11, 21), withTime: false), '30 عقرب 1405');
    expect(afghanDate(DateTime(2025, 3, 20), withTime: false), '30 حوت 1403');
  });
  test('weight units convert to grams using the configured seer', () {
    expect(gramsPerUnit('کیلوگرم', 7000), 1000);
    expect(gramsPerUnit('سیر', 7000), 7000);
    expect(gramsPerUnit('گرم', 7000), 1);
  });
  test('small-weight quick quantities retain precision', () {
    final ten = quantityPresets('کیلوگرم', 7000).firstWhere((x) => x['label'] == '۱۰ گرم');
    expect((ten['value'] as double), closeTo(0.01, 0.0000001));
    expect(quantityPresets('سیر', 7000).firstWhere((x) => x['label'] == '۱۰ گرم')['value'], closeTo(10/7000, 0.0000001));
  });
  test('carton prices are correctly converted to per-piece prices', () {
    expect(cartonPiecePrice(120, 12), 10);
    expect(cartonPiecePrice(150, 10), 15);
    expect(cartonPiecePrice(100, 0), 0);
  });
}
