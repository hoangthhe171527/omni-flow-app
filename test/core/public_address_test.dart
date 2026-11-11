import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/net/public_address.dart';

void main() {
  group('parseIpLiteral đọc mọi cách viết IPv4 của inet_aton', () {
    final cases = <String, List<int>>{
      '127.0.0.1': [127, 0, 0, 1],
      '2130706433': [127, 0, 0, 1],
      '127.1': [127, 0, 0, 1],
      '0x7f.0.0.1': [127, 0, 0, 1],
      '0x7f000001': [127, 0, 0, 1],
      '0177.0.0.1': [127, 0, 0, 1],
      '10.1': [10, 0, 0, 1],
      '192.168.257': [192, 168, 1, 1],
      '8.8.8.8': [8, 8, 8, 8],
    };
    cases.forEach((host, bytes) {
      test(host, () => expect(parseIpLiteral(host), bytes));
    });

    test('không phải IP', () {
      expect(parseIpLiteral('example.com'), isNull);
      expect(parseIpLiteral('256.1.1.1'), isNull);
      expect(parseIpLiteral('1.2.3.4.5'), isNull);
    });
  });

  group('isPublicHostLiteral', () {
    for (final host in [
      'localhost',
      'localhost.',
      'LOCALHOST',
      'foo.localhost',
      'printer.local',
      'metadata.google.internal',
      'router',
      'nas.lan',
      'x.home.arpa',
      '127.0.0.1',
      '2130706433',
      '127.1',
      '0x7f.0.0.1',
      '0.0.0.0',
      '10.0.0.1',
      '100.64.0.1',
      '169.254.169.254',
      '172.16.0.1',
      '192.168.1.1',
      '224.0.0.1',
      '255.255.255.255',
      '::1',
      '[::1]',
      '::',
      'fe80::1',
      'fd00::1',
      'ff02::1',
      '::ffff:127.0.0.1',
      '::ffff:7f00:1',
      '64:ff9b::a00:1',
      '2002:c0a8:101::1',
      '0x',
      '1.2.3.4.5',
      '',
    ]) {
      test('chặn "$host"', () => expect(isPublicHostLiteral(host), isFalse));
    }

    for (final host in [
      'example.com',
      'zalo.me',
      'cdn.sunriseieco.vn',
      '8.8.8.8',
      '93.184.216.34',
      '2606:4700::1111',
      '::ffff:8.8.8.8',
    ]) {
      test('cho "$host"', () => expect(isPublicHostLiteral(host), isTrue));
    }
  });
}
