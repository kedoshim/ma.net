import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../models/player_face.dart';
import '../../services/sound_effect_service.dart';
import '../../theme/app_colors.dart';
import '../home_page/gamepad_state.dart';
import 'face_aquarium_sim.dart';

/// Buttons that throw a face (START is left alone: it shows the game).
const Set<String> kAquariumThrowButtons = {'A', 'B', 'X', 'Y'};

/// The loading screen's minigame: a box that fills with copies of the
/// players' faces, one per button press. [sim] is owned by the caller,
/// which reads the counters from it.
class FaceAquarium extends StatefulWidget {
  final List<String> deviceIds;
  final AquariumSim sim;

  /// Fires after each throw and each overflow so the owner can redraw its
  /// counter.
  final VoidCallback? onChanged;

  const FaceAquarium({
    super.key,
    required this.deviceIds,
    required this.sim,
    this.onChanged,
  });

  @override
  State<FaceAquarium> createState() => _FaceAquariumState();
}

class _FaceAquariumState extends State<FaceAquarium>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<int> _frame = ValueNotifier(0);
  StreamSubscription<PadButtonEvent>? _buttons;
  Duration _last = Duration.zero;
  final Map<String, ui.Image> _looks = {};

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    _buttons = context.read<GamepadState>().buttonEvents.listen(_onButton);
    widget.sim
      ..onLand = SoundEffectService.instance.playPlayerJoinPop
      ..onOverflow = () {
        SoundEffectService.instance.playCountdownGo();
        widget.onChanged?.call();
      };
  }

  @override
  void dispose() {
    _ticker.dispose();
    _buttons?.cancel();
    _frame.dispose();
    widget.sim
      ..onLand = null
      ..onOverflow = null;
    for (final image in _looks.values) {
      image.dispose();
    }
    super.dispose();
  }

  void _onButton(PadButtonEvent event) {
    if (!event.pressed || !kAquariumThrowButtons.contains(event.button)) return;
    final index = widget.deviceIds.indexOf(event.deviceId);
    if (index < 0) return;
    // Each player throws from their own spot along the top.
    widget.sim.throwFace(event.deviceId, (index + 1) / (widget.deviceIds.length + 1));
    widget.onChanged?.call();
  }

  void _tick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 1 / 60
        : math.min(1 / 30, (elapsed - _last).inMicroseconds / 1e6);
    _last = elapsed;
    widget.sim.step(dt);
    _frame.value++;
  }

  /// The face drawn once into a small image, so a tank of hundreds of faces
  /// is just as many image draws (no text layout per frame).
  ui.Image? _lookOf(String deviceId, GamepadState pads) {
    final face = pads.deviceById(deviceId)?.face;
    if (face == null) return null;
    final key = '$deviceId|${face.color.toARGB32()}|${face.faceText}|${face.rotation}';
    return _looks[key] ??= _paintFace(face);
  }

  @override
  Widget build(BuildContext context) {
    final pads = context.read<GamepadState>();
    return LayoutBuilder(
      builder: (context, constraints) {
        widget.sim.size = constraints.biggest;
        return CustomPaint(
          size: constraints.biggest,
          painter: _AquariumPainter(
            sim: widget.sim,
            repaint: _frame,
            lookOf: (id) => _lookOf(id, pads),
          ),
        );
      },
    );
  }
}

const double _lookSize = 96;

ui.Image _paintFace(PlayerFaceData face) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const c = Offset(_lookSize / 2, _lookSize / 2);
  const border = 6.0;
  canvas.drawCircle(c, _lookSize / 2 - border / 2, Paint()..color = face.color);
  canvas.drawCircle(
    c,
    _lookSize / 2 - border / 2,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = border
      ..color = AppColors.textPrimary,
  );
  final text = TextPainter(
    text: TextSpan(
      text: face.faceText,
      style: TextStyle(
        fontFamily: 'monomaniac',
        fontFamilyFallback: const ['noto_symbols'],
        fontSize: _lookSize * 0.62,
        height: 0.9,
        color: Colors.black.withValues(alpha: 0.8),
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  // Shrunk to fit inside the circle, like the face indicator does.
  final fit = math.min(1.0, (_lookSize * 0.72) / math.max(text.width, 1));
  canvas
    ..translate(c.dx, c.dy)
    ..rotate(playerFaceRotationAngle(face.rotation))
    ..scale(fit);
  text.paint(canvas, Offset(-text.width / 2, -text.height / 2));
  text.dispose();
  final picture = recorder.endRecording();
  final image = picture.toImageSync(_lookSize.toInt(), _lookSize.toInt());
  picture.dispose();
  return image;
}

class _AquariumPainter extends CustomPainter {
  _AquariumPainter({
    required this.sim,
    required Listenable repaint,
    required this.lookOf,
  }) : super(repaint: repaint);

  final AquariumSim sim;
  final ui.Image? Function(String deviceId) lookOf;

  static final Paint _imagePaint = Paint()..filterQuality = FilterQuality.medium;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final face in sim.faces) {
      final d = face.radius * 2;
      final look = lookOf(face.ownerId);
      if (look == null) continue;
      // Pops in when thrown, then squashes when it lands and wobbles back.
      final pop = Curves.elasticOut.transform(math.min(1, face.age / 0.45));
      var sx = pop;
      var sy = pop;
      final landed = face.landedAge;
      if (landed != null && landed < 1) {
        final wobble = math.sin(landed * 26) * math.exp(-landed * 5) * 0.3;
        sx *= 1 + wobble;
        sy *= 1 - wobble;
      }
      canvas
        ..save()
        ..translate(face.position.dx, face.position.dy)
        ..rotate(face.angle)
        ..scale(sx, sy)
        ..drawImageRect(
          look,
          const Rect.fromLTWH(0, 0, _lookSize, _lookSize),
          Rect.fromCenter(center: Offset.zero, width: d, height: d),
          _imagePaint,
        )
        ..restore();
    }
    canvas.restore();

    // The floor, which slides open in the middle while the box drains.
    final floor = Paint()
      ..strokeWidth = 4
      ..color = AppColors.textPrimary;
    final y = size.height - 2;
    var open = 0.0;
    if (sim.draining case final left?) {
      final t = (left / AquariumSim.drainSeconds).clamp(0.0, 1.0);
      open = math.min(1.0, math.sin(t * math.pi) * 1.6) * size.width * 0.3;
    }
    final mid = size.width / 2;
    if (open <= 0) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), floor);
      return;
    }
    canvas
      ..drawLine(Offset(0, y), Offset(mid - open, y), floor)
      ..drawLine(Offset(mid + open, y), Offset(size.width, y), floor);
    // The two trapdoor flaps hanging down.
    final flap = Paint()
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = AppColors.textPrimary;
    canvas
      ..drawLine(Offset(mid - open, y), Offset(mid - open, size.height + 20), flap)
      ..drawLine(Offset(mid + open, y), Offset(mid + open, size.height + 20), flap);
  }

  @override
  bool shouldRepaint(_AquariumPainter old) => old.sim != sim;
}
