import 'package:flutter_test/flutter_test.dart';
import 'package:manet_mobile/models/phone_game.dart';

void main() {
  test('a bare host becomes an https page', () {
    expect(normalizePhoneGameUrl(' jackbox.tv '), 'https://jackbox.tv');
    expect(normalizePhoneGameUrl('https://jackbox.tv/?code=ABCD'),
        'https://jackbox.tv/?code=ABCD');
  });

  test('anything that is not a web page is refused', () {
    expect(normalizePhoneGameUrl(null), isNull);
    expect(normalizePhoneGameUrl(''), isNull);
    expect(normalizePhoneGameUrl('javascript:alert(1)'), isNull);
    expect(normalizePhoneGameUrl('file:///etc/passwd'), isNull);
  });
}
