import 'package:flutter_test/flutter_test.dart';
import 'package:offline_shop_manager/main.dart';

void main() {
  test('Persian and Arabic digits are accepted when entering amounts', () {
    expect(parseNum('۱۲٬۵۰۰'), 12500);
    expect(parseNum('١٢,٥٠٠'), 12500);
  });
}
