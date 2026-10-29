import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/player_face.dart';
import '../../services/host_api_service.dart';
import '../../services/session_controller.dart';
import '../../theme/app_colors.dart';
import '../../widgets/player_face_indicator.dart';
import '../library/face_playground.dart';
import 'gamepad_state.dart';
import 'qr_code_container.dart';
import '../../widgets/player_kick_menu.dart';

/// Faces in the lobby are bigger than in the overlay's playground.
const double _faceRadius = 50;

/// How long a face takes to turn from an organic shape into a circle.
const Duration _morphDuration = Duration(milliseconds: 450);

/// Console mode lobby, one edge-to-edge scene:
/// - the QR card in the middle (solid: faces can stand on it);
/// - phones still making their face float at the top as organic, wobbling
///   shapes ("being formed");
/// - after the check-in the shape turns into a circle and drops into the
///   physics playground;
/// - rolling out through the right edge is "ready": the face becomes a pill
///   stuck to the right edge. Cancel on the phone brings it back in.
/// Background texts teach how to join (left) and where to go (right).
class ConsoleLobbyView extends StatefulWidget {
  /// The QR card at a given scale (built by the stage, which has the
  /// connection data).
  final Widget Function(double size) qrCard;

  /// The network the phones should join.
  final ConnectionInfo? connection;

  /// The PC's hotspot name, offered next to the Wi-Fi in the join steps
  /// (null while it is off or the QR points at the internet).
  final String? hotspotName;

  /// Card with the hotspot's Wi-Fi QR at a given size, shown in the
  /// background above "How to join".
  final Widget Function(double size)? hotspotCard;

  const ConsoleLobbyView({
    super.key,
    required this.qrCard,
    this.connection,
    this.hotspotName,
    this.hotspotCard,
  });

  @override
  State<ConsoleLobbyView> createState() => _ConsoleLobbyViewState();
}

class _ConsoleLobbyViewState extends State<ConsoleLobbyView>
    with SingleTickerProviderStateMixin {
  late final SessionController _session;
  late final Ticker _ticker;
  final ValueNotifier<double> _time = ValueNotifier(0);

  Set<String> _present = {};
  Set<String> _checked = {};
  Set<String> _zone = {};

  /// Shape -> circle, started at (scene time).
  final Map<String, double> _morphing = {};

  /// Where each forming shape sits (scene coordinates), so the circle drops
  /// from there.
  final Map<String, Offset> _blobCenters = {};

  /// Each forming shape keeps its spot (an index into [_spotPool]) while
  /// the player edits: random when they arrive, the closest free one when
  /// they come back from the playground.
  final Map<String, int> _spotOf = {};
  final math.Random _random = math.Random();

  /// Where each face last was in the playground.
  final Map<String, Offset> _ballPositions = {};
  final Map<String, Offset> _dropFrom = {};

  /// Cancelled out of the pill: rolls back in from the right edge.
  final Set<String> _returning = {};

  /// Back from the library (or a game): faces are thrown in from the right
  /// edge one after the other, at these scene times.
  final Map<String, double> _arrivals = {};

  @override
  void initState() {
    super.initState();
    _session = context.read<SessionController>();
    _readSession(initial: true);
    _session.addListener(_onSession);
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _session.removeListener(_onSession);
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    _time.value = elapsed.inMicroseconds / 1e6;
    final arrived = [
      for (final e in _arrivals.entries)
        if (e.value <= _time.value) e.key,
    ];
    if (arrived.isNotEmpty) {
      setState(() {
        for (final id in arrived) {
          _arrivals.remove(id);
          _returning.add(id);
        }
      });
    }
    final done = [
      for (final e in _morphing.entries)
        if (_time.value - e.value >= _morphDuration.inMilliseconds / 1000)
          e.key,
    ];
    if (done.isNotEmpty) {
      setState(() {
        for (final id in done) {
          _morphing.remove(id);
          final center = _blobCenters[id];
          if (center != null) _dropFrom[id] = center;
        }
      });
    }
  }

  void _onSession() => setState(_readSession);

  void _readSession({bool initial = false}) {
    final snapshot = _session.snapshot;
    final present = {for (final p in snapshot.players) p.deviceId};
    final checked = {
      for (final id in snapshot.queue)
        if (present.contains(id)) id,
    };
    final zone = snapshot.playZone.intersection(checked);
    if (!initial) {
      for (final id in checked.difference(_checked)) {
        // Was a forming shape: turn it into a circle where it floats.
        if (_present.contains(id) && _blobCenters.containsKey(id)) {
          _morphing[id] = _time.value;
        }
      }
      for (final id in _zone.difference(zone)) {
        if (checked.contains(id)) _returning.add(id);
      }
    }
    if (initial) {
      var order = 0;
      for (final id in snapshot.queue) {
        if (checked.contains(id) && !zone.contains(id)) {
          _arrivals[id] = 0.15 + order++ * 0.2;
        }
      }
    }
    _arrivals.removeWhere(
      (id, _) => !checked.contains(id) || zone.contains(id),
    );
    _morphing.removeWhere((id, _) => !checked.contains(id));
    _present = present;
    _checked = checked;
    _zone = zone;
  }

  PlaygroundSpawn? _spawnOf(String id, Size size) {
    if (_returning.remove(id)) {
      // A little different for each player, so a group doesn't fly as one.
      final jitter = math.Random(id.hashCode);
      return PlaygroundSpawn(
        Offset(
          size.width - _faceRadius - 2,
          size.height * (0.22 + 0.16 * jitter.nextDouble()),
        ),
        Offset(
          -480 - 140 * jitter.nextDouble(),
          -220 - 80 * jitter.nextDouble(),
        ),
      );
    }
    final from = _dropFrom.remove(id);
    return from == null ? null : PlaygroundSpawn(from);
  }

  /// The QR card's place in the scene (also a solid platform): a tall card
  /// with room above and below the code.
  static Rect _cardRect(Size size) {
    final top = size.height * 0.07;
    final floorTop = size.height - kPlaygroundFloorHeight;
    final width = math.min(size.width * 0.17, 300.0);
    final height = math.min(width * 1.62, floorTop - top - 70);
    return Rect.fromLTWH((size.width - width) / 2, top, width, height);
  }

  /// Spots for the forming shapes around the QR card, slightly jittered so
  /// they don't look like a grid. The first [_mainSpots] (top two rows) are
  /// used first; the rest only when those are full.
  static const int _mainSpots = 12;

  static List<Offset> _spotPool(Size size) {
    const xs = [0.08, 0.2, 0.33, 0.66, 0.77, 0.88];
    const ys = [0.2, 0.42, 0.64];
    final jitter = math.Random(7);
    return [
      for (final y in ys)
        for (final x in xs)
          Offset(
            size.width * (x + (jitter.nextDouble() - 0.5) * 0.04),
            size.height * (y + (jitter.nextDouble() - 0.5) * 0.08),
          ),
    ];
  }

  /// Gives every forming shape a spot; existing ones never move.
  void _assignSpots(List<String> forming, List<Offset> pool) {
    _spotOf.removeWhere((id, _) => !forming.contains(id));
    for (final id in forming) {
      if (_spotOf.containsKey(id)) continue;
      final taken = _spotOf.values.toSet();
      var free = [
        for (var i = 0; i < pool.length; i++)
          if (!taken.contains(i)) i,
      ];
      if (free.isEmpty) free = [for (var i = 0; i < pool.length; i++) i];
      final back = _ballPositions.remove(id);
      if (back != null) {
        // Back to editing from the playground: the closest spot sideways.
        free.sort(
          (a, b) => (pool[a].dx - back.dx).abs().compareTo(
            (pool[b].dx - back.dx).abs(),
          ),
        );
        _spotOf[id] = free.first;
      } else {
        final main = free.where((i) => i < _mainSpots).toList();
        final choices = main.isNotEmpty ? main : free;
        _spotOf[id] = choices[_random.nextInt(choices.length)];
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final gamepads = context.watch<GamepadState>();
    final snapshot = session.snapshot;
    final strings = context.l10n.session;

    final order = [for (final p in snapshot.players) p.deviceId];
    final editing = [
      for (final id in order)
        if (!_checked.contains(id)) id,
    ];
    final forming = [...editing, ..._morphing.keys];
    final rolling = [
      for (final id in snapshot.queue)
        if (_checked.contains(id) &&
            !_zone.contains(id) &&
            !_morphing.containsKey(id) &&
            !_arrivals.containsKey(id))
          id,
    ];
    final pills = [
      for (final id in snapshot.queue)
        if (_zone.contains(id)) id,
    ];
    final countdown = snapshot.lobbyCountdown;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final card = _cardRect(size);
        final pool = _spotPool(size);
        _assignSpots(forming, pool);
        final spots = [for (final id in forming) pool[_spotOf[id]!]];
        _blobCenters
          ..clear()
          ..addAll({
            for (var i = 0; i < forming.length; i++) forming[i]: spots[i],
          });
        final blobSize = (size.width * 0.085).clamp(130.0, 200.0);
        // Poster grid: the same margin on both sides, close to the edges,
        // and one hanging line for both columns.
        final margin = math.max(size.width * 0.03, 32.0);
        final posterTop = size.height * 0.44;
        final posterWidth = math.max(
          240.0,
          size.width / 2 - card.width / 2 - margin - 48,
        );

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // How to join (left) and where to go (right), behind everything:
            // two columns hanging from the same line, mirrored around the
            // QR card, like a Swiss poster.
            if (widget.hotspotCard case final hotspotCard?)
              Positioned(
                left: margin,
                bottom: size.height - posterTop + 24,
                width: posterWidth,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: hotspotCard(
                    (posterTop - 140).clamp(80.0, 150.0).toDouble(),
                  ),
                ),
              ),
            Positioned(
              left: margin,
              top: posterTop,
              width: posterWidth,
              child: _JoinSteps(
                connection: widget.connection,
                hotspotName: widget.hotspotName,
              ),
            ),
            Positioned(
              right: margin,
              top: posterTop,
              width: posterWidth,
              child: _PlayHint(countdownEndsAt: countdown?.endsAt),
            ),
            Positioned.fromRect(
              rect: card,
              child: widget.qrCard(math.min(card.width * 0.8, 260)),
            ),
            Positioned(
              left: card.left - 60,
              width: card.width + 120,
              top: card.bottom + 14,
              child: Text(
                context.l10n.players.connectedCount(order.length),
                textAlign: TextAlign.center,
                style: _textStyle(_TypeScale.body),
              ),
            ),
            Positioned.fill(
              child: FacePlayground(
                deviceIds: rolling,
                framed: false,
                nameTags: true,
                nameTagsAbove: true,
                radius: _faceRadius,
                openRight: true,
                floor: true,
                onExitRight: (id) => unawaited(session.setLobbyZone(id, true)),
                spawnOf: _spawnOf,
                positions: _ballPositions,
                obstacles: (s) => [_cardRect(s)],
              ),
            ),
            // Discreet mouse-only shortcut to the game library, on the floor.
            Positioned(
              right: margin,
              bottom: 0,
              height: kPlaygroundFloorHeight,
              child: Center(child: _LibraryLink(onTap: session.openLibrary)),
            ),
            for (var i = 0; i < forming.length; i++)
              if (gamepads.deviceById(forming[i]) case final device?)
                _FormingFace(
                  key: ValueKey('blob-${forming[i]}'),
                  deviceId: device.id,
                  center: spots[i],
                  size: blobSize,
                  face: device.face,
                  name: device.name,
                  hint: strings.consoleEditing,
                  seed: forming[i].hashCode,
                  time: _time,
                  morphStart: _morphing[forming[i]],
                ),
            for (var i = 0; i < pills.length; i++)
              if (gamepads.deviceById(pills[i]) case final device?)
                _ReadyPill(
                  key: ValueKey('pill-${pills[i]}'),
                  deviceId: device.id,
                  name: device.name,
                  top: size.height * 0.24 + i * _pillStep(size, pills.length),
                  height: math.min(100, _pillStep(size, pills.length) - 14),
                  face: device.face,
                ),
          ],
        );
      },
    );
  }

  static double _pillStep(Size size, int count) =>
      math.min(118, size.height * 0.7 / math.max(1, count));
}

/// Standard type sizes for the scene.
abstract final class _TypeScale {
  static const double label = 14;
  static const double body = 20;
  static const double display = 48;
}

TextStyle _textStyle(double size, {double alpha = 1}) => TextStyle(
  fontFamily: 'momo',
  fontWeight: FontWeight.bold,
  fontSize: size,
  height: 1.2,
  color: AppColors.textPrimary.withValues(alpha: alpha),
);

/// One column of the background poster: a display title and numbered lines
/// on a fixed number column, all flush left.
class _PosterColumn extends StatelessWidget {
  final Widget title;
  final List<(String, String)> lines;

  /// Parts of a line to stand out (the Wi-Fi and hotspot names).
  final List<String> emphasis;

  /// Flush right (the right column): plain lines, no number column.
  final bool alignRight;

  const _PosterColumn({
    required this.title,
    required this.lines,
    this.alignRight = false,
    this.emphasis = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignRight
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        title,
        const SizedBox(height: 18),
        for (final (number, text) in lines)
          if (alignRight)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                text,
                textAlign: TextAlign.right,
                style: _textStyle(_TypeScale.body, alpha: 0.7),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 44,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        number,
                        style: _textStyle(
                          _TypeScale.label,
                          alpha: 0.85,
                        ).copyWith(letterSpacing: 1.5),
                      ),
                    ),
                  ),
                  Expanded(child: _line(text)),
                ],
              ),
            ),
      ],
    );
  }
}

extension on _PosterColumn {
  /// A body line; each [emphasis] inside it is marked with the highlight
  /// color.
  Widget _line(String text) {
    final style = _textStyle(_TypeScale.body, alpha: 0.7);
    final marks = [
      for (final m in emphasis)
        if (m.isNotEmpty) m,
    ];
    if (marks.isEmpty) return Text(text, style: style);
    final markStyle = style.copyWith(
      color: AppColors.textPrimary,
      backgroundColor: AppColors.highlightColor,
    );
    final spans = <TextSpan>[];
    var rest = text;
    while (rest.isNotEmpty) {
      // The earliest mark left in the line.
      (int, String)? next;
      for (final mark in marks) {
        final at = rest.indexOf(mark);
        if (at >= 0 && (next == null || at < next.$1)) next = (at, mark);
      }
      if (next == null) {
        spans.add(TextSpan(text: rest));
        break;
      }
      final (at, mark) = next;
      spans
        ..add(TextSpan(text: rest.substring(0, at)))
        ..add(TextSpan(text: ' $mark ', style: markStyle));
      rest = rest.substring(at + mark.length);
    }
    return Text.rich(TextSpan(style: style, children: spans));
  }
}

/// "How to join", the left column of the poster.
class _JoinSteps extends StatelessWidget {
  final ConnectionInfo? connection;
  final String? hotspotName;

  const _JoinSteps({required this.connection, this.hotspotName});

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.session;
    final conn = connection;
    final parts = conn?.displayNameKey.split('__') ?? const <String>[];
    // Over the internet there is no network to join first.
    final network = conn == null || conn.kind == 'internet'
        ? ''
        : parts.length > 1 && parts[1].isNotEmpty
        ? parts[1]
        : QRCodePanel.displayName(context, conn);
    final link = conn?.url.replaceFirst(RegExp('^https?://'), '') ?? '';
    // The hotspot is a second way in, unless the QR already points at it.
    final hotspot = conn?.kind == 'hotspot' || hotspotName == network
        ? ''
        : hotspotName ?? '';
    final steps = [
      if (network.isNotEmpty && hotspot.isNotEmpty)
        strings.consoleJoinWifiOrHotspot(network, hotspot)
      else if (network.isNotEmpty)
        conn?.kind == 'wifi'
            ? strings.consoleJoinWifi(network)
            : strings.consoleJoinNetwork(network),
      if (link.isNotEmpty) strings.consoleJoinScan(link),
      strings.consoleJoinFace,
    ];
    return _PosterColumn(
      title: Text(
        strings.consoleJoinTitle,
        style: _textStyle(_TypeScale.display, alpha: 0.85),
      ),
      lines: [for (var i = 0; i < steps.length; i++) ('0${i + 1}', steps[i])],
      emphasis: [network, hotspot],
    );
  }
}

/// "Play >>>", the right column of the poster, with marching arrows; the
/// countdown replaces the hint once it runs.
class _PlayHint extends StatefulWidget {
  final DateTime? countdownEndsAt;

  const _PlayHint({required this.countdownEndsAt});

  @override
  State<_PlayHint> createState() => _PlayHintState();
}

class _PlayHintState extends State<_PlayHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _arrows = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _arrows.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.session;
    return AnimatedBuilder(
      animation: _arrows,
      builder: (context, _) {
        final endsAt = widget.countdownEndsAt;
        final seconds = endsAt == null
            ? null
            : math.max(
                0,
                (endsAt.difference(DateTime.now()).inMilliseconds / 1000)
                    .ceil(),
              );
        return _PosterColumn(
          alignRight: true,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                strings.consolePlayTitle,
                style: _textStyle(_TypeScale.display, alpha: 0.85),
              ),
              const SizedBox(width: 16),
              for (var i = 0; i < 3; i++)
                Text(
                  '>',
                  style: _textStyle(_TypeScale.display).copyWith(
                    color: AppColors.highlightColor.withValues(
                      // A light runs through the arrows, left to right.
                      alpha:
                          0.35 +
                          0.65 *
                              math.max(
                                0,
                                1 - ((_arrows.value * 3 - i) % 3).abs(),
                              ),
                    ),
                  ),
                ),
            ],
          ),
          lines: [
            (
              '',
              seconds != null
                  ? strings.consoleStartingIn(seconds)
                  : strings.consolePlayHint,
            ),
          ],
        );
      },
    );
  }
}

/// A phone still making its face: an organic shape in the player's color
/// that keeps changing, as if being formed. When the player checks in it
/// turns into a circle ([morphStart]) and the playground takes over.
class _FormingFace extends StatelessWidget {
  final String deviceId;
  final Offset center;
  final double size;
  final PlayerFaceData face;
  final String name;
  final String hint;
  final int seed;
  final ValueNotifier<double> time;
  final double? morphStart;

  const _FormingFace({
    super.key,
    required this.deviceId,
    required this.center,
    required this.size,
    required this.face,
    required this.name,
    required this.hint,
    required this.seed,
    required this.time,
    this.morphStart,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: center.dx - 110,
      top: center.dy - size / 2 - 34,
      width: 220,
      child: KickMenuRegion(
        deviceId: deviceId,
        name: name,
        child: IgnorePointer(
          child: ValueListenableBuilder<double>(
            valueListenable: time,
            builder: (context, t, _) {
              final morph = morphStart == null
                  ? 0.0
                  : Curves.easeInOut.transform(
                      ((t - morphStart!) /
                              (_morphDuration.inMilliseconds / 1000))
                          .clamp(0.0, 1.0),
                    );
              final ball = _faceRadius * 2;
              final side = size + (ball - size) * morph;
              // Gentle floating, gone once it is a circle about to drop.
              final bob = math.sin(t * 0.9 + seed % 7) * 7 * (1 - morph);
              final labels = 1 - morph;
              return Transform.translate(
                offset: Offset(0, bob),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: labels,
                      child: SizedBox(
                        height: 30,
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _textStyle(_TypeScale.body),
                        ),
                      ),
                    ),
                    SizedBox(height: 4 + (size - side) / 2),
                    SizedBox(
                      width: side,
                      height: side,
                      child: CustomPaint(
                        painter: _BlobPainter(
                          color: face.color,
                          time: t,
                          seed: seed,
                          wobble: 1 - morph,
                          outlined: morph > 0,
                        ),
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(side * 0.2),
                            child: FittedBox(
                              child: Transform.rotate(
                                angle: playerFaceRotationAngle(face.rotation),
                                child: Text(
                                  face.faceText,
                                  style: TextStyle(
                                    fontFamily: 'monomaniac',
                                    fontFamilyFallback: const ['noto_symbols'],
                                    fontSize: side * 0.6,
                                    height: 0.9,
                                    color: Colors.black.withValues(alpha: 0.8),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 6 + (size - side) / 2),
                    Opacity(
                      opacity: labels,
                      child: Text(
                        hint,
                        maxLines: 1,
                        style: _textStyle(_TypeScale.label, alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Organic outline: a circle whose radius ripples with a few slow sine
/// harmonics (different per player). [wobble] 0 is a plain circle.
class _BlobPainter extends CustomPainter {
  final Color color;
  final double time;
  final int seed;
  final double wobble;
  final bool outlined;

  _BlobPainter({
    required this.color,
    required this.time,
    required this.seed,
    required this.wobble,
    required this.outlined,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);
    final harmonics = [
      for (final k in [2, 3, 5])
        (
          k,
          0.05 + random.nextDouble() * 0.07,
          random.nextDouble() * math.pi * 2,
          0.4 + random.nextDouble() * 0.8,
        ),
    ];
    final center = size.center(Offset.zero);
    final base = size.shortestSide / 2 * (1 - 0.14 * wobble);
    final path = Path();
    const points = 72;
    for (var i = 0; i <= points; i++) {
      final a = 2 * math.pi * i / points;
      var r = 1.0;
      for (final (k, amp, phase, speed) in harmonics) {
        r += amp * wobble * math.sin(k * a + phase + time * speed);
      }
      final p = center + Offset(math.cos(a), math.sin(a)) * base * r;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
    if (outlined) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, size.shortestSide * 0.04) * (1 - wobble)
          ..color = AppColors.textPrimary,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BlobPainter old) =>
      old.time != time || old.wobble != wobble || old.color != color;
}

/// A ready player: a pill stuck to the right edge with their face and an
/// arrow; it slides in from outside the screen.
class _ReadyPill extends StatelessWidget {
  final String deviceId;
  final String name;
  final double top;
  final double height;
  final PlayerFaceData face;

  const _ReadyPill({
    super.key,
    required this.deviceId,
    required this.name,
    required this.top,
    required this.height,
    required this.face,
  });

  @override
  Widget build(BuildContext context) {
    // Wider than shown: the right side (and its border) stays off screen,
    // so the pill looks stuck to the edge. The slide-in overshoots about a
    // tenth of the width to the left, so the hidden part must outgrow that
    // (a fixed 12 px let the right border peek in during the entrance).
    final hidden = height * 0.5;
    final width = height * 1.65 + hidden;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      right: -hidden,
      top: top,
      width: width,
      height: height,
      child: KickMenuRegion(
        deviceId: deviceId,
        name: name,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 1, end: 0),
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutBack,
          builder: (context, slide, child) => Transform.translate(
            offset: Offset(width * slide, 0),
            child: child,
          ),
          child: Container(
            padding: EdgeInsets.all(height * 0.08),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.horizontal(
                left: Radius.circular(height / 2),
              ),
              border: Border.all(color: AppColors.textPrimary, width: 4),
            ),
            child: Row(
              children: [
                PlayerFaceIndicator(face: face, size: height * 0.84),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: height * 0.32,
                  color: AppColors.textPrimary,
                ),
                SizedBox(width: height * 0.1 + hidden),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small text link on the floor: the host opens the library with the mouse.
class _LibraryLink extends StatefulWidget {
  final VoidCallback onTap;

  const _LibraryLink({required this.onTap});

  @override
  State<_LibraryLink> createState() => _LibraryLinkState();
}

class _LibraryLinkState extends State<_LibraryLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final style = _textStyle(_TypeScale.label, alpha: _hover ? 1 : 0.5);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.grid_view_rounded, size: 16, color: style.color),
            const SizedBox(width: 6),
            Text(context.l10n.session.chooseGame, style: style),
          ],
        ),
      ),
    );
  }
}
