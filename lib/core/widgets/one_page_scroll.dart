import 'package:flutter/material.dart';

/// Paged views that move at most **one page per swipe**, however far or fast
/// the finger travels.
///
/// - [AppTabBarView]: drop-in for `TabBarView` inside a `DefaultTabController`.
/// - [OnePageScroll]: wraps any `PageView` (set `pageSnapping: false`).
///
/// `TabBarView` cannot be used for this: it stacks its own physics above any
/// custom one, so the page-snapping decision is out of our hands.

/// Tab pages with one-page-per-swipe scrolling, kept in sync with the
/// surrounding [TabBar] (tap a tab or swipe a page: both follow).
class AppTabBarView extends StatefulWidget {
  const AppTabBarView({super.key, required this.children, this.controller});

  final List<Widget> children;

  /// Defaults to `DefaultTabController.of(context)`.
  final TabController? controller;

  @override
  State<AppTabBarView> createState() => _AppTabBarViewState();
}

class _AppTabBarViewState extends State<AppTabBarView> {
  TabController? _tabs;
  PageController? _pages;
  final _start = _StartPage();
  late final _physics = _OnePagePhysics(_start);

  /// True while a tap on a tab animates the pages (ignore their callbacks).
  bool _programmatic = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = widget.controller ?? DefaultTabController.of(context);
    if (!identical(next, _tabs)) {
      _tabs?.removeListener(_onTabChanged);
      _tabs = next..addListener(_onTabChanged);
      _pages?.dispose();
      _pages = PageController(initialPage: next.index);
    }
  }

  @override
  void dispose() {
    _tabs?.removeListener(_onTabChanged);
    _pages?.dispose();
    super.dispose();
  }

  /// A tab was tapped (or the controller moved): show that page.
  void _onTabChanged() {
    final tabs = _tabs;
    final pages = _pages;
    if (tabs == null || pages == null || !tabs.indexIsChanging) return;
    if (!pages.hasClients) return;
    final target = tabs.index;
    if ((pages.page ?? target.toDouble()).round() == target) return;
    _programmatic = true;
    pages
        .animateToPage(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        )
        .whenComplete(() => _programmatic = false);
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.horizontal) return false;
    final tabs = _tabs;
    if (tabs == null || n.metrics.viewportDimension <= 0) return false;
    final page = n.metrics.pixels / n.metrics.viewportDimension;

    if (_programmatic) return false;
    if (n is ScrollStartNotification) {
      _start.page = page.round();
    } else if (n is ScrollUpdateNotification) {
      // The tab indicator follows the finger.
      tabs.offset = (page - tabs.index).clamp(-1.0, 1.0);
    } else if (n is ScrollEndNotification) {
      final settled = page.round();
      if (settled != tabs.index) tabs.index = settled;
      tabs.offset = 0;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: PageView(
          controller: _pages,
          pageSnapping: false,
          physics: _physics,
          children: widget.children,
        ),
      );
}

/// For a plain `PageView`: records where each swipe starts and hands the
/// one-page physics to [builder]. The `PageView` must set
/// `pageSnapping: false` (the physics does the snapping itself).
class OnePageScroll extends StatefulWidget {
  const OnePageScroll({super.key, required this.builder});

  final Widget Function(BuildContext context, ScrollPhysics physics) builder;

  @override
  State<OnePageScroll> createState() => _OnePageScrollState();
}

class _OnePageScrollState extends State<OnePageScroll> {
  final _start = _StartPage();
  late final _physics = _OnePagePhysics(_start);

  bool _onStart(ScrollStartNotification n) {
    // Only the paged view itself (not vertical lists inside its pages).
    if (n.depth == 0 &&
        n.metrics.axis == Axis.horizontal &&
        n.metrics.viewportDimension > 0) {
      _start.page = (n.metrics.pixels / n.metrics.viewportDimension).round();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollStartNotification>(
        onNotification: _onStart,
        child: widget.builder(context, _physics),
      );
}

/// The page a swipe started on, shared by the physics instances Flutter
/// clones through `applyTo`.
class _StartPage {
  int? page;
}

/// Clamping physics that also (a) stops a drag one page away from where it
/// began and (b) snaps to at most one page away on release.
class _OnePagePhysics extends ClampingScrollPhysics {
  const _OnePagePhysics(this._start, {super.parent});

  final _StartPage _start;

  @override
  _OnePagePhysics applyTo(ScrollPhysics? ancestor) =>
      _OnePagePhysics(_start, parent: buildParent(ancestor));

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    final adjusted = super.applyPhysicsToUserOffset(position, offset);
    final start = _start.page;
    if (start == null || position.viewportDimension <= 0) return adjusted;

    final size = position.viewportDimension;
    final target = (position.pixels - adjusted)
        .clamp((start - 1) * size, (start + 1) * size)
        .toDouble();
    return position.pixels - target;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final size = position.viewportDimension;
    final tolerance = toleranceFor(position);
    // Out of range (edge bounce), or not a paged view: default behaviour.
    if (size <= 0 ||
        position.pixels < position.minScrollExtent ||
        position.pixels > position.maxScrollExtent) {
      return super.createBallisticSimulation(position, velocity);
    }

    final start = _start.page;
    var page = position.pixels / size;
    if (velocity > tolerance.velocity) {
      page += 0.5;
    } else if (velocity < -tolerance.velocity) {
      page -= 0.5;
    }
    var target = page.roundToDouble();
    if (start != null) {
      target = target.clamp(start - 1.0, start + 1.0).toDouble();
    }
    final targetPixels = (target * size)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();

    if ((targetPixels - position.pixels).abs() < tolerance.distance) {
      return null;
    }
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      targetPixels,
      velocity,
      tolerance: tolerance,
    );
  }
}
