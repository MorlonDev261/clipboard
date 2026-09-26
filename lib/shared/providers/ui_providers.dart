import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../enums/enums.dart';

/// Whether content collections are shown as a grid or a list.
/// Persisting this to settings is a later milestone.
final viewModeProvider = StateProvider<ViewMode>((ref) => ViewMode.grid);

/// Active sort order for folder / search content.
final sortOptionProvider = StateProvider<SortOption>((ref) => SortOption.newest);
