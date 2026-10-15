import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:influencor/features/fees/data/madagascar_tariffs.dart';
import 'package:influencor/features/fees/domain/mobile_money_fees.dart';

void main() {
  test('tariffs survive a JSON round trip', () {
    for (final t in madagascarTariffs) {
      final back =
          OperatorTariff.tryFromJson(jsonDecode(jsonEncode(t.toJson())))!;
      expect(back.name, t.name);
      expect(back.official, t.official);
      expect(back.withdraw.length, t.withdraw.length);
      expect(back.transfer.length, t.transfer.length);
      expect(back.transferOther?.length, t.transferOther?.length);
      expect(back.transferApp?.length, t.transferApp?.length);
      expect(back.withdraw.last.fee, t.withdraw.last.fee);
    }
  });

  test('invalid data is ignored, empty optional grids become null', () {
    expect(OperatorTariff.tryFromJson({'name': ''}), isNull);
    expect(FeeBracket.tryFromJson({'min': 10, 'max': 5, 'fee': 1}), isNull);
    final t = OperatorTariff.tryFromJson({
      'name': 'X',
      'withdraw': [
        {'min': 1, 'max': 9, 'fee': 0},
        {'min': 'a'},
      ],
      'transfer': [],
      'transferOther': [],
    })!;
    expect(t.withdraw.length, 1);
    expect(t.transferOther, isNull);
  });

  test('a custom operator is usable by the optimizer', () {
    const custom = OperatorTariff(
      name: 'Mine',
      withdraw: [FeeBracket(100, 1000, 10), FeeBracket(1001, 5000, 50)],
      transfer: [FeeBracket(100, 5000, 20)],
    );
    final p = const FeeOptimizer().plan(custom, FeeKind.withdraw, 1500)!;
    expect(p.amount, 1500);
    expect(p.totalFee, lessThanOrEqualTo(50));
  });
}
