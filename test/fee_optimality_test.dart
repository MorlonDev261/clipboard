import 'package:flutter_test/flutter_test.dart';
import 'package:influencor/features/fees/data/madagascar_tariffs.dart';
import 'package:influencor/features/fees/domain/mobile_money_fees.dart';

/// Reference solution: classic DP over every exact amount. Slow but
/// obviously correct; the optimizer must match it.
List<int> _bruteForce(List<FeeBracket> brackets, int upTo) {
  const inf = 1 << 40;
  final g = List<int>.filled(upTo + 1, inf)..[0] = 0;
  for (var a = 1; a <= upTo; a++) {
    var best = inf;
    for (final b in brackets) {
      final lo = b.min, hi = b.max < a ? b.max : a;
      for (var x = lo; x <= hi; x++) {
        final rest = g[a - x];
        if (rest < inf && rest + b.fee < best) best = rest + b.fee;
      }
    }
    g[a] = best;
  }
  return g;
}

void main() {
  unlimitedTests();
  const optimizer = FeeOptimizer();
  const limit = 12000;

  for (final t in madagascarTariffs) {
    for (final kind in FeeKind.values) {
      test('${t.name} $kind matches brute force up to $limit Ar', () {
        final brackets = t.bracketsFor(kind);
        final ref = _bruteForce(brackets, limit);
        for (var a = 100; a <= limit; a += 97) {
          final plan = optimizer.plan(t, kind, a);
          final expected = ref[a] >= (1 << 40) ? null : ref[a];
          expect(plan?.totalFee, expected, reason: '${t.name} $kind $a');
        }
      });
    }
  }
}

void unlimitedTests() {
  group('no upper limit', () {
    final orange =
        madagascarTariffs.firstWhere((t) => t.name == 'Orange Money');

    test('huge amounts are split into grouped operations that add up', () {
      const optimizer = FeeOptimizer();
      for (final a in [
        130000000,
        999999999,
        12345678901,
        1000000000000,
        999999999999999,
      ]) {
        final sw = Stopwatch()..start();
        for (final kind in FeeKind.values) {
          final p = optimizer.plan(orange, kind, a)!;
          expect(p.amount, a, reason: '$kind $a');
          expect(p.directFee, isNull);
          expect(p.parts.length, lessThan(30));
          // Fees must be a sane fraction: well under 1 % of the amount.
          expect(p.totalFee * 100, lessThan(a));
        }
        expect(sw.elapsedMilliseconds, lessThan(3000), reason: '$a');
      }
    });

    test('bulk path matches brute force on a small tariff', () {
      const small = OperatorTariff(
        name: 'Small',
        withdraw: [
          FeeBracket(100, 500, 10),
          FeeBracket(501, 1000, 15),
          FeeBracket(1001, 3000, 30),
        ],
        transfer: [FeeBracket(100, 3000, 20)],
      );
      // maxParts: 2 forces everything above 6 000 through the bulk path.
      const optimizer = FeeOptimizer(maxParts: 2);
      final ref = _bruteForce(small.withdraw, 12000);
      var checked = 0;
      for (var a = 6001; a <= 12000; a += 37) {
        final p = optimizer.plan(small, FeeKind.withdraw, a)!;
        expect(p.amount, a);
        expect(p.totalFee, ref[a], reason: 'amount $a');
        checked++;
      }
      expect(checked, greaterThan(100));
    });
  });
}
