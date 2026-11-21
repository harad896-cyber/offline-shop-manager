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
}
