/// What the web render watchdog does after a check.
enum WatchdogAction { none, repaint, reload }

/// The watchdog's decisions, kept apart from the DOM so plain `flutter test`
/// covers them (test/render_watchdog_check_test.dart).
///
/// [findCanvases] is asked again on every check, never cached: after a
/// context loss Flutter adds new canvases while the old ones stay on the
/// page, and a cached list once kept checking the old, healthy ones, missed
/// a new one dying, and left the pad blank until a manual reload.
class RenderWatchdogCheck<C> {
  RenderWatchdogCheck({required this.findCanvases, required this.isLost});

  final Iterable<C> Function() findCanvases;
  final bool Function(C canvas) isLost;

  bool _lostLastCheck = false;

  /// A dead canvas first gets one forced frame for Flutter to replace it;
  /// still dead on the next check, the page reloads.
  WatchdogAction check() {
    if (!findCanvases().any(isLost)) {
      _lostLastCheck = false;
      return WatchdogAction.none;
    }
    if (!_lostLastCheck) {
      _lostLastCheck = true;
      return WatchdogAction.repaint;
    }
    return WatchdogAction.reload;
  }

  /// The tab went to the background: a loss seen before then gets its
  /// forced frame again once the tab is back.
  void tabHidden() => _lostLastCheck = false;
}
