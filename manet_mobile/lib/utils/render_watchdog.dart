import 'render_watchdog_stub.dart'
    if (dart.library.html) 'render_watchdog_web.dart' as impl;

/// Web only: brings the screen back when the browser drops the WebGL
/// context of a background tab (Firefox on Android does this), which left
/// the pad blank while touches still worked. No-op elsewhere.
void startRenderWatchdog() => impl.startRenderWatchdog();
