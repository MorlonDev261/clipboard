import 'package:meta/meta.dart';

/// A free-form label that can be attached to any asset.
@immutable
class Tag {
  const Tag({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) => other is Tag && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
