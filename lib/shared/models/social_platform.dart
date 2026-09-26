import 'package:meta/meta.dart';

/// A social network an asset or post can target (Facebook, Instagram, ...).
///
/// Named `SocialPlatform` rather than `Platform` to avoid colliding with
/// `dart:io`'s `Platform`.
@immutable
class SocialPlatform {
  const SocialPlatform({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  @override
  bool operator ==(Object other) => other is SocialPlatform && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
