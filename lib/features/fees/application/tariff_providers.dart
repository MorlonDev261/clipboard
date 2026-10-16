import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/madagascar_tariffs.dart';
import '../data/tariff_store.dart';
import '../domain/mobile_money_fees.dart';

final tariffStoreProvider = Provider<TariffStore>((ref) => TariffStore());

/// The tariffs used by the fee calculator: the user's edited grids if any,
/// otherwise the built-in ones.
class TariffsController extends AsyncNotifier<List<OperatorTariff>> {
  @override
  Future<List<OperatorTariff>> build() async =>
      await ref.read(tariffStoreProvider).load() ?? madagascarTariffs;

  Future<void> save(List<OperatorTariff> tariffs) async {
    await ref.read(tariffStoreProvider).save(tariffs);
    state = AsyncData(tariffs);
  }

  Future<void> upsert(OperatorTariff tariff, {String? replacing}) {
    final list = [...state.value ?? madagascarTariffs];
    final i = list.indexWhere((t) => t.name == (replacing ?? tariff.name));
    if (i >= 0) {
      list[i] = tariff;
    } else {
      list.add(tariff);
    }
    return save(list);
  }

  Future<void> remove(String name) => save([
        for (final t in state.value ?? madagascarTariffs)
          if (t.name != name) t,
      ]);

  Future<void> resetToDefaults() async {
    await ref.read(tariffStoreProvider).reset();
    state = AsyncData(madagascarTariffs);
  }
}

final tariffsProvider =
    AsyncNotifierProvider<TariffsController, List<OperatorTariff>>(
        TariffsController.new);

/// Current tariffs (built-ins until the saved ones are loaded).
final currentTariffsProvider = Provider<List<OperatorTariff>>(
  (ref) => ref.watch(tariffsProvider).value ?? madagascarTariffs,
);
