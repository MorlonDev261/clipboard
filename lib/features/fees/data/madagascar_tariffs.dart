import '../domain/mobile_money_fees.dart';

/// Madagascar mobile-money tariffs (Ar, taxes included).
///
/// Sources:
/// - MVola: official grid, https://mvola.mg/tarifs/ (individuals, "Cash
///   Point" withdrawals, transfers to MVola / to other operators).
/// - Orange Money: official grid PLAN_TARIFS_ORANGE_MONEY_MAJ_1_A4.pdf on
///   orange.mg (in force since 1 February 2025). Includes the "Appli −50 %"
///   channel for Orange → Orange transfers.
/// - Airtel Money: NO public grid could be retrieved (the terms only say the
///   tariff is published in agencies / on the site). The values below are an
///   estimate: the Orange grid, because MVola and Orange withdrawals are
///   identical. Flagged with `official: false` so the UI warns about it.
///
/// Third-party calculators (momocalc.com) and one blog quoting a flat 5 %
/// Orange transfer fee contradict the official grids and were NOT used.
List<FeeBracket> _steps(int firstMin, List<int> upperBounds, List<int> fees) {
  assert(upperBounds.length == fees.length);
  final out = <FeeBracket>[];
  var min = firstMin;
  for (var i = 0; i < fees.length; i++) {
    out.add(FeeBracket(min, upperBounds[i], fees[i]));
    min = upperBounds[i] + 1;
  }
  return out;
}

const _m = 1000000;

// Upper bounds shared by the Orange grid (19 rows, up to 10 M).
const _orangeEdges = [
  1000, 5000, 10000, 20000, 25000, 50000, 100000, 250000, 500000, //
  1 * _m, 2 * _m, 3 * _m, 4 * _m, 5 * _m, 6 * _m, 7 * _m, 8 * _m, 9 * _m,
  10 * _m,
];

const _withdrawFees = [
  100, 150, 275, 550, 650, 1300, 1900, 3400, 4700, 8800, //
  14700, 19600, 24500, 29400, 34300, 39200, 44100, 49000, 53900,
];

final _orangeWithdraw = _steps(200, _orangeEdges, _withdrawFees);

final _orangeToOrange = _steps(200, _orangeEdges, const [
  65, 65, 150, 250, 250, 500, 1000, 1900, 1900, 3200, //
  3800, 5000, 6300, 7500, 9400, 10700, 12500, 14400, 15700,
]);

final _orangeToOrangeApp = _steps(200, _orangeEdges, const [
  35, 35, 75, 125, 125, 250, 500, 950, 950, 1600, //
  1900, 2500, 3150, 3750, 4700, 5350, 6250, 7200, 7850,
]);

// Orange → other operators: only up to 5 M.
final _orangeToOther = _steps(200, _orangeEdges.sublist(0, 14), const [
  140, 140, 300, 500, 500, 900, 1400, 3000, 4500, 7200, //
  11500, 14000, 17600, 18600,
]);

// MVola withdrawal (Cash Point), up to 20 M.
final _mvolaWithdraw = _steps(
  100,
  [
    ..._orangeEdges,
    ...[for (var i = 11; i <= 20; i++) i * _m]
  ],
  [
    ..._withdrawFees,
    59000,
    64000,
    69000,
    74000,
    79000,
    84000,
    89000,
    94000,
    98000,
    100000,
  ],
);

// MVola → MVola, up to 20 M.
final _mvolaTransfer = _steps(
  100,
  [
    1000, 5000, 10000, 25000, 50000, 100000, 250000, 500000, //
    for (var i = 1; i <= 20; i++) i * _m,
  ],
  [
    70, 70, 150, 250, 500, 1000, 1900, 1900, //
    3200, 3800, 5000, 6300, 7500, 9400, 10700, 12500, 14400, 15700,
    17500, 18800, 20000, 21300, 23200, 25000, 26300, 28200, 30000, 31300,
  ],
);

// MVola → other operators, up to 5 M. The grid lists 100 Ar as the first
// row but its footnote says such transfers start at 300 Ar; the footnote is
// the safer reading.
final _mvolaToOther = _steps(
  300,
  [
    1000, 5000, 10000, 25000, 50000, 100000, 250000, 500000, //
    1 * _m, 2 * _m, 3 * _m, 4 * _m, 5 * _m,
  ],
  [
    200,
    250,
    500,
    1000,
    1500,
    2000,
    3500,
    5000,
    8500,
    12000,
    14500,
    19500,
    24000
  ],
);

final madagascarTariffs = <OperatorTariff>[
  OperatorTariff(
    name: 'MVola',
    withdraw: _mvolaWithdraw,
    transfer: _mvolaTransfer,
    transferOther: _mvolaToOther,
    official: true,
  ),
  OperatorTariff(
    name: 'Orange Money',
    withdraw: _orangeWithdraw,
    transfer: _orangeToOrange,
    transferApp: _orangeToOrangeApp,
    transferOther: _orangeToOther,
    official: true,
  ),
  OperatorTariff(
    name: 'Airtel Money',
    withdraw: _orangeWithdraw,
    transfer: _orangeToOrange,
    transferOther: _orangeToOther,
    official: false,
  ),
];
