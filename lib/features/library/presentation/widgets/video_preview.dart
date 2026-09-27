import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Inline video player for the preview screen, backed by media_kit (libmpv),
/// so it works on every platform — including Windows and Linux, which the
/// official video_player plugin does not support.
class VideoPreview extends StatefulWidget {
  const VideoPreview({required this.path, super.key});

  final String path;

  @override
  State<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<VideoPreview> {
  late final Player _player = Player();
  late final VideoController _controller = VideoController(_player);

  @override
  void initState() {
    super.initState();
    // Load the file but wait for the user to press play.
    _player.open(Media(widget.path), play: false);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fill the available space (the parent Center passes loose constraints);
    // BoxFit.contain keeps the aspect ratio with letterboxing.
    return SizedBox.expand(
      child: Video(
        controller: _controller,
        fit: BoxFit.contain,
      ),
    );
  }
}
