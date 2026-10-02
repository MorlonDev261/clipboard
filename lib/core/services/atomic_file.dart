import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Writes [content] so that a crash or a full disk can never leave a half-written
/// file behind: the data goes to a sibling temp file first, then replaces the
/// target with a single rename.
Future<void> writeStringAtomic(File target, String content) async {
  await target.parent.create(recursive: true);
  final tmp = File('${target.path}.tmp');
  await tmp.writeAsString(content, encoding: utf8, flush: true);
  await tmp.rename(target.path);
}

/// Runs async critical sections one at a time. The JSON stores do
/// read → modify → write; without this, two quick taps (favorite + tag) read the
/// same snapshot and the second write silently drops the first change.
class AsyncMutex {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    // Keep the chain alive even when [action] throws.
    _tail = result.then<void>((_) {}, onError: (_) {});
    return result;
  }
}
