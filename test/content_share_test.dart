import 'dart:async';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:clipboard/core/services/content_share_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _FakeGateway implements ShareGateway {
  ShareGatewayStatus status = ShareGatewayStatus.success;
  Object? error;
  Completer<void>? hold;
  final calls = <({String? text, List<ShareFile> files})>[];

  @override
  Future<ShareGatewayStatus> share({
    String? text,
    String? title,
    List<ShareFile> files = const [],
    Rect? origin,
  }) async {
    calls.add((text: text, files: files));
    if (hold != null) await hold!.future;
    if (error != null) throw error!;
    return status;
  }
}

void main() {
  late Directory dir;
  late _FakeGateway gateway;
  late ContentShareService service;

  String make(String name) {
    final f = File(p.join(dir.path, name))..writeAsBytesSync([1, 2, 3]);
    return f.path;
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('clipboard_share_');
    gateway = _FakeGateway();
    service = ContentShareService(gateway: gateway);
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('text only is shared as text', () async {
    final r = await service.shareContent(text: 'Bonjour', localMediaPaths: []);
    expect(r.outcome, ShareOutcome.success);
    expect(gateway.calls.single.text, 'Bonjour');
    expect(gateway.calls.single.files, isEmpty);
  });

  test('empty text and no media does not open the share sheet', () async {
    final r = await service.shareContent(text: '  \n ', localMediaPaths: []);
    expect(r.outcome, ShareOutcome.noContent);
    expect(gateway.calls, isEmpty);
  });

  test('one image + text', () async {
    final img = make('a.jpg');
    final r = await service.shareContent(text: 'Hi', localMediaPaths: [img]);
    expect(r.outcome, ShareOutcome.success);
    final call = gateway.calls.single;
    expect(call.text, 'Hi');
    expect(call.files.single.mimeType, 'image/jpeg');
    expect(call.files.single.name, 'a.jpg');
  });

  test('several images + text', () async {
    final imgs = [make('a.jpg'), make('b.png'), make('c.webp')];
    final r = await service.shareContent(text: 'Hi', localMediaPaths: imgs);
    expect(r.outcome, ShareOutcome.success);
    expect(gateway.calls.single.files.map((f) => f.path), imgs);
  });

  test('one video + text', () async {
    final vid = make('v.mp4');
    final r = await service.shareContent(text: 'Hi', localMediaPaths: [vid]);
    expect(r.outcome, ShareOutcome.success);
    expect(gateway.calls.single.files.single.mimeType, 'video/mp4');
  });

  test('missing file among valid ones is skipped and reported', () async {
    final a = make('a.jpg');
    final b = make('b.jpg');
    final r = await service.shareContent(
      text: 'Hi',
      localMediaPaths: [a, p.join(dir.path, 'ghost.jpg'), b],
    );
    expect(r.outcome, ShareOutcome.success);
    expect(r.skipped, 1);
    expect(gateway.calls.single.files.map((f) => f.path), [a, b]);
  });

  test('all files missing: no share sheet', () async {
    final r = await service.shareContent(
      text: 'Hi',
      localMediaPaths: [p.join(dir.path, 'x.jpg'), ''],
    );
    expect(r.outcome, ShareOutcome.noValidFiles);
    expect(r.skipped, 2);
    expect(gateway.calls, isEmpty);
  });

  test('empty media list with text behaves as text only', () async {
    final r = await service.shareContent(text: 'Hi', localMediaPaths: []);
    expect(r.outcome, ShareOutcome.success);
    expect(gateway.calls.single.files, isEmpty);
  });

  group('classifyMedia', () {
    test('images only', () {
      final c = classifyMedia(['a.JPG', 'b.heic', 'c.avif']);
      expect(c.images.length, 3);
      expect(c.videos, isEmpty);
    });

    test('videos only', () {
      final c = classifyMedia(['a.mp4', 'b.mov', 'c.webm', 'd.m4v']);
      expect(c.videos.length, 4);
      expect(c.images, isEmpty);
    });

    test('mixed and unsupported', () {
      final c = classifyMedia(['a.jpg', 'b.mp4', 'c.pdf']);
      expect(c.images, ['a.jpg']);
      expect(c.videos, ['b.mp4']);
      expect(c.unsupported, 1);
    });
  });

  test('mixed media asks for a choice and does not share', () async {
    final img = make('a.jpg');
    final vid = make('v.mp4');
    final r = await service.shareContent(
      text: 'Hi',
      localMediaPaths: [img, vid],
    );
    expect(r.outcome, ShareOutcome.mixedMediaNeedsChoice);
    expect(r.images, [img]);
    expect(r.videos, [vid]);
    expect(gateway.calls, isEmpty);
  });

  test('text keeps line breaks, emoji, hashtags and links untouched', () async {
    const text =
        '🔥 Promo !\n\n#soldes #mada\n+261 34 00 000 00\nhttps://x.mg/a?b=1\n';
    expect(buildShareText(text), text);
    await service.shareContent(text: text, localMediaPaths: []);
    expect(gateway.calls.single.text, text);
  });

  test('dismissed share is reported as dismissed', () async {
    gateway.status = ShareGatewayStatus.dismissed;
    final r = await service.shareContent(text: 'Hi', localMediaPaths: []);
    expect(r.outcome, ShareOutcome.dismissed);
  });

  test('plugin exception becomes failure', () async {
    gateway.error = StateError('boom');
    final r = await service.shareContent(text: 'Hi', localMediaPaths: []);
    expect(r.outcome, ShareOutcome.failure);
    // Service stays usable afterwards.
    gateway.error = null;
    final again = await service.shareContent(text: 'Hi', localMediaPaths: []);
    expect(again.outcome, ShareOutcome.success);
  });

  test('a second call while one is in flight is rejected', () async {
    gateway.hold = Completer<void>();
    final first = service.shareContent(text: 'Hi', localMediaPaths: []);
    final second = await service.shareContent(text: 'Hi', localMediaPaths: []);
    expect(second.outcome, ShareOutcome.busy);
    gateway.hold!.complete();
    expect((await first).outcome, ShareOutcome.success);
    expect(gateway.calls.length, 1);
  });
}
