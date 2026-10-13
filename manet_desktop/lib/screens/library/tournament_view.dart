import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/session_models.dart';
import '../../services/host_api_service.dart';
import '../../services/session_controller.dart';
import '../../services/sound_effect_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/comic_burst.dart';
import '../../widgets/juicy_widgets.dart';
import '../home_page/gamepad_state.dart';
import '../../widgets/player_cursor.dart';

/// Elimination tournament between the games voted in the library. The server
/// runs the bracket and the clock (manet_server/src/core/tournament.py); this
/// screen shows it: the entrants, each head-to-head, who advanced, and the
/// champion. In a head-to-head the screen is split in two fields; players
/// steer their face cursors and vote for the field they stand in (the strip
/// in the middle abstains). This screen reports each player's field.
class TournamentView extends StatefulWidget {
  const TournamentView({super.key});

  @override
  State<TournamentView> createState() => _TournamentViewState();
}

class _TournamentViewState extends State<TournamentView>
    with SingleTickerProviderStateMixin {
  // Same feel as the library cursors.
  static const double _cursorSpeed = 900;
  static const double _deadZone = 0.12;
  static const double _cursorSize = 58;

  /// Half the width of the neutral strip in the middle (where "VS" sits).
  static const double _neutralHalfWidth = 60;

  // Burst triggers per side; bumped when a match result comes in.
  int _burstA = 0;
  int _burstB = 0;
  int _championBurst = 0;
  String? _lastResultKey;
  String? _lastStage;

  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  final GlobalKey _stackKey = GlobalKey();
  final ValueNotifier<Map<String, Offset>> _cursors = ValueNotifier(const {});
  final ValueNotifier<Map<String, int>> _bops = ValueNotifier(const {});
  // Field each player's cursor is in, and what was last sent for which match.
  final Map<String, String?> _fields = {};
  final Map<String, String?> _sent = {};
  String? _matchKey;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _cursors.dispose();
    _bops.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final dt = _lastTick == Duration.zero
        ? 0.016
        : (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final session = context.read<SessionController>();
    final t = session.snapshot.tournament;
    if (box == null || !box.hasSize || t == null) return;
    final size = box.size;
    final players = session.snapshot.players;
    final gamepads = context.read<GamepadState>();

    // A new head-to-head: everyone starts again in the neutral strip.
    final key = t.stage == 'match' || t.stage == 'result'
        ? '${t.round}/${t.match}'
        : null;
    final fresh = key != null && key != _matchKey;
    if (key != null) _matchKey = key;

    final next = <String, Offset>{};
    for (var i = 0; i < players.length; i++) {
      final id = players[i].deviceId;
      var position = fresh ? null : _cursors.value[id];
      position ??= Offset(
        size.width / 2,
        // Spread along the strip, at the height of the fields.
        size.height * (0.3 + 0.35 * (i + 1) / (players.length + 1)),
      );
      final input = gamepads.inputListenable(id).value;
      position += _stickVelocity(input.stickX, input.stickY) * dt;
      next[id] = Offset(
        position.dx.clamp(0.0, size.width),
        position.dy.clamp(0.0, size.height),
      );
    }
    if (fresh) _sent.clear();
    _cursors.value = next;

    for (final entry in next.entries) {
      final x = entry.value.dx;
      final field = x < size.width / 2 - _neutralHalfWidth
          ? 'a'
          : (x > size.width / 2 + _neutralHalfWidth ? 'b' : null);
      if (field != _fields[entry.key]) {
        _fields[entry.key] = field;
        if (field != null && t.stage == 'match') _bop(entry.key);
      }
      // Report changes while the match is open (votes reset each match).
      if (t.stage == 'match' &&
          (!_sent.containsKey(entry.key) || _sent[entry.key] != field)) {
        _sent[entry.key] = field;
        unawaited(session.tournamentVote(entry.key, field));
      }
    }
  }

  Offset _stickVelocity(double x, double y) {
    final magnitude = math.sqrt(x * x + y * y);
    if (magnitude < _deadZone) return Offset.zero;
    final eased = math
        .pow((magnitude - _deadZone) / (1 - _deadZone), 1.6)
        .toDouble();
    return Offset(x / magnitude, y / magnitude) * eased * _cursorSpeed;
  }

  void _bop(String deviceId) {
    final next = Map<String, int>.from(_bops.value);
    next[deviceId] = (next[deviceId] ?? 0) + 1;
    _bops.value = next;
  }

  void _react(TournamentState t) {
    final resultKey = t.stage == 'result' && t.result != null
        ? '${t.round}/${t.match}'
        : null;
    if (resultKey != null && resultKey != _lastResultKey) {
      _lastResultKey = resultKey;
      final side = t.result!.side;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => side == 'a' ? _burstA++ : _burstB++);
      });
      unawaited(SoundEffectService.instance.playCountdownGo());
    }
    if (t.stage != _lastStage) {
      _lastStage = t.stage;
      if (t.stage == 'champion') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _championBurst++);
        });
      } else if (t.stage == 'match') {
        unawaited(SoundEffectService.instance.playStartButton());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final t = session.snapshot.tournament;
    if (t == null) return const SizedBox.shrink();
    _react(t);

    final Widget body = switch (t.stage) {
      'intro' => _IntroBody(tournament: t),
      'champion' => _ChampionBody(
        game: session.gameById(t.champion),
        trigger: _championBurst,
      ),
      _ => _MatchBody(
        tournament: t,
        matchSeconds: session.snapshot.matchSeconds,
        burstA: _burstA,
        burstB: _burstB,
      ),
    };

    final gamepads = context.watch<GamepadState>();
    final showCursors = t.stage == 'match' || t.stage == 'result';
    return Stack(
      key: _stackKey,
      children: [
        _buildContent(context, t, body),
        if (showCursors)
          Positioned.fill(
            child: IgnorePointer(
              child: ValueListenableBuilder<Map<String, Offset>>(
                valueListenable: _cursors,
                builder: (context, cursors, _) =>
                    ValueListenableBuilder<Map<String, int>>(
                      valueListenable: _bops,
                      builder: (context, bops, _) => Stack(
                        children: [
                          for (final entry in cursors.entries)
                            if (gamepads.deviceById(entry.key)
                                case final device?)
                              Positioned(
                                left: entry.value.dx - _cursorSize / 2,
                                top: entry.value.dy - _cursorSize / 2,
                                child: PlayerCursor(
                                  device: device,
                                  size: _cursorSize,
                                  bopTrigger: bops[entry.key] ?? 0,
                                ),
                              ),
                        ],
                      ),
                    ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, TournamentState t, Widget body) {
    final session = context.read<SessionController>();
    final strings = context.l10n.session;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            JuicyButton(
              onPressed: session.cancelTournament,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.arrow_back_rounded,
                    size: 18,
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(width: 6),
                  Text(strings.tournamentCancel, style: _buttonStyle),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(strings.tournamentTitle, style: _titleStyle),
                  Text(
                    t.stage == 'intro' || t.stage == 'champion'
                        ? strings.tournamentIntro(t.entrants.length)
                        : _roundLabel(context, t),
                    style: _captionStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeOutBack,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween(begin: 0.92, end: 1.0).animate(animation),
                child: child,
              ),
            ),
            // match and result share a layout so the cards stay in place.
            child: KeyedSubtree(
              key: ValueKey(t.stage == 'result' ? 'match' : t.stage),
              child: body,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(height: 120, child: _Bracket(tournament: t)),
      ],
    );
  }

  String _roundLabel(BuildContext context, TournamentState t) {
    final strings = context.l10n.session;
    final matchesInRound = t.round < t.rounds.length
        ? t.rounds[t.round].length
        : 1;
    return strings.tournamentRound(
      matchesInRound,
      t.round + 1,
      t.rounds.length,
    );
  }
}

// --------------------------------------------------------------------- intro

class _IntroBody extends StatelessWidget {
  final TournamentState tournament;

  const _IntroBody({required this.tournament});

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionController>();
    final entrants = tournament.entrants;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math
            .min(
              200.0,
              (constraints.maxWidth - 18 * (entrants.length - 1)) /
                  entrants.length,
            )
            .clamp(110.0, 200.0);
        return Center(
          child: SingleChildScrollView(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 18,
              runSpacing: 18,
              children: [
                for (final (index, id) in entrants.indexed)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 500 + index * 160),
                    curve: Interval(
                      index * 160 / (500 + index * 160),
                      1,
                      curve: Curves.elasticOut,
                    ),
                    builder: (context, value, child) =>
                        Transform.scale(scale: value, child: child),
                    child: _TournamentCard(
                      game: session.gameById(id),
                      width: width,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// --------------------------------------------------------------------- match

class _MatchBody extends StatelessWidget {
  final TournamentState tournament;
  final double matchSeconds;
  final int burstA;
  final int burstB;

  const _MatchBody({
    required this.tournament,
    required this.matchSeconds,
    required this.burstA,
    required this.burstB,
  });

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionController>();
    final gamepads = context.watch<GamepadState>();
    final strings = context.l10n.session;
    final t = tournament;
    final match = t.current;
    if (match == null) return const SizedBox.shrink();

    final result = t.stage == 'result' ? t.result : null;
    final votesA = [
      for (final e in t.votes.entries)
        if (e.value == 'a')
          if (gamepads.deviceById(e.key) case final device?) device,
    ];
    final votesB = [
      for (final e in t.votes.entries)
        if (e.value == 'b')
          if (gamepads.deviceById(e.key) case final device?) device,
    ];
    final total = votesA.length + votesB.length;

    Widget side(
      String key,
      String? gameId,
      List<DeviceModel> voters,
      int burst,
    ) {
      final share = total == 0 ? 0.5 : voters.length / total;
      final won = result != null && result.side == key;
      final lost = result != null && result.side != key;
      return Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Card height is ~1.05 x width + the name strip; leave room for
            // the voters row and the winner's scale-up.
            final width = math
                .min(
                  constraints.maxWidth * 0.7,
                  (constraints.maxHeight - 110) / 1.3,
                )
                .clamp(110.0, 340.0);
            // The field: standing anywhere on this half votes for it.
            final fieldColor = won
                ? AppColors.highlightColor
                : (voters.isNotEmpty && result == null
                      ? voters.last.color
                      : AppColors.textPrimary);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: fieldColor.withValues(
                  alpha: voters.isNotEmpty || won ? 0.16 : 0.04,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: fieldColor.withValues(
                    alpha: voters.isNotEmpty || won ? 0.7 : 0.15,
                  ),
                  width: 3,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedRotation(
                    turns: lost ? (key == 'a' ? -0.02 : 0.02) : 0,
                    duration: const Duration(milliseconds: 300),
                    child: AnimatedScale(
                      scale: won
                          ? 1.12
                          : lost
                          ? 0.82
                          : 0.92 + 0.2 * share,
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutBack,
                      child: AnimatedOpacity(
                        opacity: lost ? 0.4 : 1,
                        duration: const Duration(milliseconds: 300),
                        child: ComicBopBurst(
                          trigger: burst,
                          burstRadius: width * 0.75,
                          rayCount: 12,
                          rayWidth: 6,
                          playSound: true,
                          burstColor: AppColors.highlightColor,
                          child: _TournamentCard(
                            game: session.gameById(gameId),
                            width: width,
                            borderColor: won
                                ? AppColors.highlightColor
                                : (voters.isNotEmpty && result == null
                                      ? voters.last.color
                                      : AppColors.textPrimary),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: Container(
                      key: ValueKey(voters.length),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lightColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.textPrimary,
                          width: 3,
                        ),
                      ),
                      child: Text(
                        strings.tournamentVotes(voters.length),
                        style: _buttonStyle.copyWith(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    final String hint;
    if (result == null) {
      hint = strings.tournamentLean;
    } else if (result.drawn) {
      hint = strings.tournamentDraw(
        session.gameById(result.winner)?.name ?? '',
      );
    } else {
      hint = strings.tournamentAdvances(
        session.gameById(result.winner)?.name ?? '',
      );
    }

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              side('a', match.a, votesA, burstA),
              SizedBox(
                width: 120,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'VS',
                      style: TextStyle(
                        fontFamily: 'momo',
                        fontWeight: FontWeight.bold,
                        fontSize: 44,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (t.endsAt != null && result == null)
                      _MatchClock(endsAt: t.endsAt!, total: matchSeconds),
                  ],
                ),
              ),
              side('b', match.b, votesB, burstB),
            ],
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(
            hint,
            key: ValueKey(hint),
            textAlign: TextAlign.center,
            style: result == null ? _hintStyle : _resultStyle,
          ),
        ),
      ],
    );
  }
}

/// Seconds left in the match, as a rounded square that drains.
class _MatchClock extends StatefulWidget {
  final DateTime endsAt;
  final double total;

  const _MatchClock({required this.endsAt, required this.total});

  @override
  State<_MatchClock> createState() => _MatchClockState();
}

class _MatchClockState extends State<_MatchClock> {
  Timer? _timer;
  int _lastSecond = -1;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() {});
      final seconds = _left.inMilliseconds / 1000;
      final whole = seconds.ceil();
      if (whole != _lastSecond && whole <= 3 && whole > 0) {
        unawaited(SoundEffectService.instance.playCountdownTick());
      }
      _lastSecond = whole;
    });
  }

  Duration get _left {
    final left = widget.endsAt.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = _left.inMilliseconds / 1000;
    final fraction = widget.total <= 0
        ? 0.0
        : (seconds / widget.total).clamp(0.0, 1.0);
    const size = 72.0;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.textPrimary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: AppColors.lightColor),
            Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: fraction,
                widthFactor: 1,
                child: ColoredBox(
                  color: seconds <= 3
                      ? AppColors.highlightColor
                      : AppColors.highlightColor.withValues(alpha: 0.45),
                ),
              ),
            ),
            Center(
              child: Text(
                '${seconds.ceil()}',
                style: const TextStyle(
                  fontFamily: 'momo',
                  fontWeight: FontWeight.bold,
                  fontSize: 30,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ champion

class _ChampionBody extends StatelessWidget {
  final GameEntry? game;
  final int trigger;

  const _ChampionBody({required this.game, required this.trigger});

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.session;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxHeight * 0.55).clamp(140.0, 300.0);
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ComicBopBurst(
                trigger: trigger,
                burstRadius: width * 0.8,
                rayCount: 16,
                rayWidth: 7,
                playSound: true,
                burstColor: AppColors.highlightColor,
                child: _TournamentCard(
                  game: game,
                  width: width,
                  borderColor: AppColors.highlightColor,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                strings.tournamentChampion(game?.name ?? ''),
                textAlign: TextAlign.center,
                style: _resultStyle.copyWith(fontSize: 30),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------------- bracket

/// Every round side by side; the current match is outlined.
class _Bracket extends StatelessWidget {
  final TournamentState tournament;

  const _Bracket({required this.tournament});

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionController>();
    final t = tournament;
    String name(String? id) =>
        id == null ? '?' : (session.gameById(id)?.name ?? '?');

    Widget pill(String? id, TournamentMatch m) {
      final out = m.winner != null && m.winner != id;
      final won = m.winner != null && m.winner == id;
      return Container(
        width: 130,
        margin: const EdgeInsets.symmetric(vertical: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: won ? AppColors.highlightColor : AppColors.lightColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          id == null && m.isBye ? '—' : name(id),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _captionStyle.copyWith(
            color: AppColors.textPrimary.withValues(alpha: out ? 0.35 : 1),
            decoration: out ? TextDecoration.lineThrough : null,
          ),
        ),
      );
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final (r, round) in t.rounds.indexed) ...[
            if (r > 0)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textPrimary,
                ),
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (m, match) in round.indexed)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color:
                          r == t.round && m == t.match && t.stage != 'champion'
                          ? AppColors.highlightColor
                          : AppColors.textPrimary,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        pill(match.a, match),
                        if (!match.isBye) pill(match.b, match),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              Icons.emoji_events_rounded,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------- card

class _TournamentCard extends StatelessWidget {
  static const double borderWidth = 4;
  static const double radius = 18;

  final GameEntry? game;
  final double width;
  final Color borderColor;

  const _TournamentCard({
    required this.game,
    required this.width,
    this.borderColor = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width,
      padding: const EdgeInsets.all(borderWidth),
      decoration: BoxDecoration(
        color: borderColor,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - borderWidth),
        child: ColoredBox(
          color: AppColors.lightColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: width * 1.05,
                child: _Cover(game: game),
              ),
              Container(height: borderWidth, color: borderColor),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Text(
                  game?.name ?? '?',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: _cardTitleStyle.copyWith(
                    fontSize: (width / 11).clamp(14.0, 24.0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  final GameEntry? game;

  const _Cover({required this.game});

  @override
  Widget build(BuildContext context) {
    final game = this.game;
    if (game != null &&
        game.coverPath.isNotEmpty &&
        File(game.coverPath).existsSync()) {
      return Image.file(File(game.coverPath), fit: BoxFit.cover);
    }
    final name = game?.name ?? '?';
    final hue = (name.codeUnits.fold<int>(0, (a, b) => a + b) * 37) % 360;
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return Container(
      color: HSLColor.fromAHSL(1, hue.toDouble(), 0.55, 0.72).toColor(),
      alignment: Alignment.center,
      child: FittedBox(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            initials,
            style: const TextStyle(
              fontFamily: 'momo',
              fontSize: 56,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

const TextStyle _titleStyle = TextStyle(
  fontFamily: 'momo',
  fontWeight: FontWeight.bold,
  fontSize: 24,
  color: AppColors.textPrimary,
);

const TextStyle _cardTitleStyle = TextStyle(
  fontFamily: 'momo',
  fontWeight: FontWeight.bold,
  fontSize: 16,
  color: AppColors.textPrimary,
);

const TextStyle _buttonStyle = TextStyle(
  fontFamily: 'momo',
  fontWeight: FontWeight.bold,
  fontSize: 14,
  color: AppColors.textPrimary,
);

const TextStyle _hintStyle = TextStyle(
  fontFamily: 'momo',
  fontSize: 18,
  color: AppColors.textPrimary,
);

const TextStyle _resultStyle = TextStyle(
  fontFamily: 'momo',
  fontWeight: FontWeight.bold,
  fontSize: 24,
  color: AppColors.textPrimary,
);

final TextStyle _captionStyle = TextStyle(
  fontFamily: 'momo',
  fontSize: 12,
  color: AppColors.textPrimary.withValues(alpha: 0.65),
);
