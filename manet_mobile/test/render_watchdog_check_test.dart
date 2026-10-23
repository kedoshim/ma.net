import 'package:flutter_test/flutter_test.dart';
import 'package:manet_mobile/utils/render_watchdog_check.dart';

/// A stand-in for one of Flutter's WebGL canvases.
class _Canvas {
  bool lost = false;
}

void main() {
  late List<_Canvas> page;
  late int scans;
  late RenderWatchdogCheck<_Canvas> watch;

  setUp(() {
    page = [];
    scans = 0;
    watch = RenderWatchdogCheck<_Canvas>(
      findCanvases: () {
        scans++;
        return List.of(page);
      },
      isLost: (c) => c.lost,
    );
  });

  test('healthy canvases need nothing', () {
    page.add(_Canvas());
    expect(watch.check(), WatchdogAction.none);
  });

  test('a dead canvas gets one forced frame, then a reload', () {
    page.add(_Canvas()..lost = true);
    expect(watch.check(), WatchdogAction.repaint);
    expect(watch.check(), WatchdogAction.reload);
  });

  test('a canvas that comes back in time needs no reload', () {
    final canvas = _Canvas()..lost = true;
    page.add(canvas);
    expect(watch.check(), WatchdogAction.repaint);
    canvas.lost = false;
    expect(watch.check(), WatchdogAction.none);
  });

  // The regression this guards: after a context loss Flutter adds new
  // canvases while the old ones stay on the page. A watchdog that cached the
  // canvases it had seen kept checking the old, healthy ones, missed the new
  // one dying, and the pad stayed blank until a manual reload.
  test('the page is scanned again on every check', () {
    page.add(_Canvas());
    expect(watch.check(), WatchdogAction.none);
    expect(watch.check(), WatchdogAction.none);

    page.add(_Canvas()..lost = true);
    expect(watch.check(), WatchdogAction.repaint);
    expect(scans, 3);
  });

  test('hiding the tab gives a dead canvas its forced frame again', () {
    page.add(_Canvas()..lost = true);
    expect(watch.check(), WatchdogAction.repaint);
    watch.tabHidden();
    expect(watch.check(), WatchdogAction.repaint);
  });
}
