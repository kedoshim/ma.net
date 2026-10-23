# MaNet

Product, UX, visual and tone principles live in GEMINI.md and apply here too:

@GEMINI.md

This file adds what an agent needs to change the code without breaking it.

## Commands

- Server tests: `manet_server/.venv/Scripts/python -m pytest` (from `manet_server`).
  The global Python lacks the dependencies, so plain `pytest` fails on imports.
- Mobile and desktop: `flutter analyze` and `flutter test` in `manet_mobile` /
  `manet_desktop`. Both already have info/warning lines; judge a change by the
  lines it adds, and never leave an `error`.
- `flutter test --platform chrome` does not run on this machine (even a
  one-line test times out while loading), so keep web logic testable in the
  VM: put decisions in plain Dart and leave only a thin `dart:html` layer
  (see `render_watchdog_check.dart` / `render_watchdog_web.dart`).
- Web controller build: `flutter build web --release --no-web-resources-cdn`
  (what `build_web.bat` and the installer scripts run). Without the flag the
  phone downloads CanvasKit from Google's CDN, so a phone on the PC's hotspot
  or a LAN without internet gets a blank page.
- The server serves `manet_mobile/build/web` as is: rebuild after changing the
  web controller. A file copied into `build/web` by hand skips the build's
  substitutions (index.html's `$FLUTTER_BASE_HREF`).

## Contracts between the three apps

- A controller layout preset field lives in three places that must agree: the
  server normalizes it (`manet_server/src/core/controller_presets.py`, the
  source of truth, tested in `tests/test_controller_presets.py`), the phone
  reads it (`manet_mobile/lib/models/controller_layout_preset.dart`) and the
  desktop edits it (`ControllerPresetLayout` in
  `manet_desktop/lib/services/host_api_service.dart`, UI in
  `widgets/layout_editor_view.dart`). Unknown values fall back to a default on
  every side.
- `lib/models/controller_left_zone.dart` exists in both Flutter apps and the
  server applies the same rule; change all three together.
- Every UI string goes in `l10n/strings.dart`, `pt_br.dart` and `en_us.dart` of
  its app. Users see Portuguese first.
- The app version lives in `manet_server/src/app/version.py`.

## Fragile areas

Each of these looks like it could be simplified or "optimized" and has broken
when it was. Change one only after reproducing the original problem, and keep
its test passing.

- **Web render watchdog** (`manet_mobile/lib/utils/render_watchdog_web.dart`
  and `render_watchdog_check.dart`). After the phone leaves the page and comes
  back, the pad can stay blank. The check must walk the whole page every
  time: after a context loss Flutter adds new canvases, and a cached canvas
  list once missed a new one dying. Test: `test/render_watchdog_check_test.dart`.
- **Firefox touch repair** (script in `manet_mobile/web/index.html`). It looks
  redundant on Chrome. On Firefox for Android, with two fingers down, the
  browser can stop sending `pointermove` for one finger while `touchmove` still
  tracks it; without the script one stick freezes. Verify on Firefox for
  Android with both sticks held, lifting and touching again several times.
- **Stick input engine** (`manet_mobile/lib/services/gamepad_input_engine.dart`).
  Its pointer routes run for every move of every finger (up to 120 Hz each).
  No logging there outside `kDebugMode`: on the web each line becomes a
  `console.log` and two sticks were enough to stall the page.
- **Floating right stick** (`manet_mobile/lib/widgets/right_stick_controls.dart`).
  The stick is drawn in a Stack that must fill its cell
  (`StackFit.expand`); in a loose-width column it shrank while held and drew
  the stick half a cell away from the finger.
  Test: `test/floating_right_stick_test.dart`.
- **Virtual pads** (`manet_server/src/core/gamepad_factory.py`). Never free a
  vgamepad target; always go through `retire_gamepad()`. Freeing a pad with a
  rumble callback crashes the server (use-after-free inside ViGEmClient) about
  half the time when switching XInput/DInput.
- **Tool mode vs console mode** (`manet_server/src/core/session_state.py`). In
  tool mode phones are plain gamepads: no menu mode, nothing moves the session
  to the library on its own. Gate console-only behavior on `self.console` and
  keep `tests/test_tool_mode.py` passing.
- **Online play** (cloudflared tunnel). Through the tunnel `request.remote` is
  always 127.0.0.1, so loopback checks mean nothing: use `request_origin()`.
  Everything under `/api/` needs the admin token unless allowlisted in
  `manet_server/src/app/security.py`.

## Working rules

- Performance: measure the problem before optimizing, and say what was
  measured. An optimization made on a hunch is how the watchdog broke.
- Web input bugs: reproduce in the browser where they were reported. Chrome
  and Firefox differ, and phones open the controller over plain http, so
  secure-context-only APIs are missing there.
- Several sessions often work in this folder at once and leave uncommitted
  changes in the same files. Don't revert or commit work you didn't do; ask
  which changes go in a commit.
- Comments say why, in plain words, matching the density around them.
- Commits: a title that says what changed for the player, then a body grouped
  by area (see `git log`).
- Phone UI: buttons are rounded squares, never circles; menu buttons are white
  with a black border, not colored. Desktop text sets the `momo` font
  explicitly (unstyled Text falls back to the wrong font).
