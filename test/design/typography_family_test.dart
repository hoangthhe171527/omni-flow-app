import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/tokens/tokens.dart';

void main() {
  test('toàn app dùng Be Vietnam Pro', () {
    expect(OmniType.family, 'Be Vietnam Pro');
    expect(OmniType.displayLg.fontFamily, 'Be Vietnam Pro');
  });
}
