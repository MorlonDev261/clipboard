import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/services/atomic_file.dart';
import '../domain/mobile_money_fees.dart';

/// Persists the user's edited tariffs in the app support directory. When no
/// file exists the built-in Madagascar grids are used.
class TariffStore {
  static const _fileName = 'fee_tariffs.json';

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, _fileName));
  }

  /// Saved tariffs, or null when the user never changed anything.
  Future<List<OperatorTariff>?> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final data = jsonDecode(await file.readAsString(encoding: utf8));
      final list = data is Map ? data['tariffs'] : null;
      if (list is! List) return null;
      final tariffs = [
        for (final raw in list)
          if (OperatorTariff.tryFromJson(raw) case final t?) t,
      ];
      return tariffs.isEmpty ? null : tariffs;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(List<OperatorTariff> tariffs) async {
    final file = await _file();
    await writeStringAtomic(
      file,
      const JsonEncoder.withIndent('  ').convert({
        'version': 1,
        'tariffs': [for (final t in tariffs) t.toJson()],
      }),
    );
  }

  Future<void> reset() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
  }
}
