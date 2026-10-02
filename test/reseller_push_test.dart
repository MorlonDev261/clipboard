import 'package:clipboard/features/reseller/data/reseller_config.dart';
import 'package:clipboard/features/reseller/data/reseller_push.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ResellerPush.linkFromData (notification tap)', () {
    test('a relative path opens on the reseller host', () {
      final uri = ResellerPush.linkFromData({'actionUrl': '/orders/42?x=1'});
      expect(
          uri.toString(), 'https://reseller.poma-original.com/orders/42?x=1');
    });

    test('an absolute link on a trusted host is kept', () {
      final uri = ResellerPush.linkFromData(
          {'actionUrl': 'https://poma-original.com/details/iphone'});
      expect(uri?.host, 'poma-original.com');
    });

    test('foreign hosts, other schemes and junk are ignored', () {
      for (final bad in [
        'https://evil.example/orders',
        'http://reseller.poma-original.com/orders',
        'javascript:alert(1)',
        'https://poma-original.com.evil.example/',
        '',
        '   ',
      ]) {
        expect(ResellerPush.linkFromData({'actionUrl': bad}), isNull,
            reason: bad);
      }
      expect(ResellerPush.linkFromData({'actionUrl': 42}), isNull);
      expect(ResellerPush.linkFromData({}), isNull);
      expect(ResellerPush.linkFromData(null), isNull);
      expect(
          ResellerPush.linkFromData({'actionUrl': '/${'a' * 3000}'}), isNull);
    });
  });

  group('ResellerConfig.pushRequest (injected script)', () {
    test('targets the native-push endpoint with the session cookie', () {
      final js =
          ResellerConfig.pushRequest('nonce1', 'POST', 'tok-123', 'android');
      expect(js, contains("fetch('/api/push/native'"));
      expect(js, contains("credentials: 'include'"));
      expect(js, contains("method: 'POST'"));
      expect(js, contains("platform: 'android'"));
      expect(js, contains("n: 'nonce1'"));
      expect(js, contains('"tok-123"'));
    });

    test('a hostile token cannot break out of the script string', () {
      const hostile = '"});alert(1);//\\';
      final js = ResellerConfig.pushRequest('n', 'DELETE', hostile, 'android');
      // JSON-encoded: the quote and backslash are escaped, never raw.
      expect(js, contains(r'"\"});alert(1);//\\"'));
      expect(js, isNot(contains('token: "});alert(1)')));
    });
  });
}
