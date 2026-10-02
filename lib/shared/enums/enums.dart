/// UI-level enumerations shared across features.
library;

/// Presentation mode for content collections.
enum ViewMode { grid, list }

/// Which space the app is showing: the local content library, or the
/// reseller space (reseller.poma-original.com) rendered full-screen.
enum AppMode { clipboard, reseller }

/// Sort orders available in the browser.
enum SortOption {
  nameAsc,
  nameDesc,
  newest,
  oldest,
  sizeAsc,
  sizeDesc,
}
