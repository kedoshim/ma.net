import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/session_models.dart';
import '../../services/host_api_service.dart';
import '../../theme/app_colors.dart';
import '../../models/player_face.dart';
import '../../widgets/player_face_indicator.dart';

/// Pieces of the game library screen: bigger game cards, the filter/sort bar,
/// the player count badge and the game details panel. Everything that the
/// player cursors can press gets a [GlobalKey] from the library so it can be
/// hit-tested against the cursors, and a list of who is hovering it.

enum LibrarySort { alphabetical, favorites, players }

/// Where a game stands for the players connected now: everyone plays,
/// it takes fewer than are here, or it needs more than are here.
enum PlayerFit { everyone, fewer, needsMore }

PlayerFit playerFit(GameEntry game, int players) {
  if (players < game.minPlayers) return PlayerFit.needsMore;
  if (players > game.maxPlayers) return PlayerFit.fewer;
  return PlayerFit.everyone;
}

class LibraryFilter {
  final bool fitsOnly;
  final Set<String> tags;
  final LibrarySort sort;

  const LibraryFilter({
    this.fitsOnly = false,
    this.tags = const {},
    this.sort = LibrarySort.favorites,
  });

  /// Decides ties and the order of little-played games. Drawn once per run
  /// of the app, so the order holds still while people pick and changes
  /// from one game night to the next; no game wins by its first letter.
  static int sessionSeed = math.Random().nextInt(1 << 30);

  /// Every Nth card in "favorites" is a game little played lately, so new
  /// and forgotten games keep getting a turn next to the favorites.
  static const int discoveryEvery = 4;

  /// About one real play in the last two months: below this a game counts
  /// as little played.
  static const double favoriteScore = 1.0;

  static LibrarySort parseSort(String value) => switch (value) {
    'alphabetical' => LibrarySort.alphabetical,
    'players' => LibrarySort.players,
    _ => LibrarySort.favorites,
  };

  static String serializeSort(LibrarySort sort) => switch (sort) {
    LibrarySort.alphabetical => 'alphabetical',
    LibrarySort.players => 'players',
    LibrarySort.favorites => 'favorites',
  };

  bool get isFiltering => fitsOnly || tags.isNotEmpty;

  LibraryFilter copyWith({
    bool? fitsOnly,
    Set<String>? tags,
    LibrarySort? sort,
  }) => LibraryFilter(
    fitsOnly: fitsOnly ?? this.fitsOnly,
    tags: tags ?? this.tags,
    sort: sort ?? this.sort,
  );

  LibraryFilter toggleTag(String tag) {
    final next = {...tags};
    if (!next.remove(tag)) next.add(tag);
    return copyWith(tags: next);
  }

  LibraryFilter nextSort() => copyWith(
    sort: LibrarySort.values[(sort.index + 1) % LibrarySort.values.length],
  );

  /// Games to show, in order. Games everyone can play come first, then the
  /// ones that take fewer players (those letting more people in first),
  /// then the ones that need more players. Tags combine with "any of".
  List<GameEntry> apply(List<GameEntry> games, int players) {
    final shown = [
      for (final game in games)
        if ((!fitsOnly || game.fits(players)) &&
            (tags.isEmpty ||
                game.tags.any((t) => tags.contains(t.toLowerCase()))))
          game,
    ];
    final ordered = switch (sort) {
      LibrarySort.alphabetical => [...shown]..sort(_byName),
      LibrarySort.favorites => favoritesOrder(shown),
      LibrarySort.players => [...shown]..sort((a, b) {
        final c = b.maxPlayers - a.maxPlayers;
        return c != 0 ? c : _byName(a, b);
      }),
    };
    final rank = Map<GameEntry, int>.identity()
      ..addAll({for (var i = 0; i < ordered.length; i++) ordered[i]: i});
    return ordered..sort((a, b) {
      final fa = playerFit(a, players), fb = playerFit(b, players);
      if (fa != fb) return fa.index - fb.index;
      if (fa == PlayerFit.fewer && a.maxPlayers != b.maxPlayers) {
        return b.maxPlayers - a.maxPlayers;
      }
      return rank[a]! - rank[b]!;
    });
  }

  static int _byName(GameEntry a, GameEntry b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());

  static int _draw(GameEntry game) =>
      Object.hash(sessionSeed, game.id, game.name);

  /// Favorites by score, with a little-played game every [discoveryEvery]
  /// cards. Ties and the little-played games follow this run's draw.
  static List<GameEntry> favoritesOrder(List<GameEntry> games) {
    int byDraw(GameEntry a, GameEntry b) => _draw(a).compareTo(_draw(b));
    final loved = [
      for (final g in games)
        if (g.score >= favoriteScore) g,
    ]..sort((a, b) {
        final c = b.score.compareTo(a.score);
        return c != 0 ? c : byDraw(a, b);
      });
    final others = [
      for (final g in games)
        if (g.score < favoriteScore) g,
    ]..sort(byDraw);
    final out = <GameEntry>[];
    var l = 0, o = 0;
    while (l < loved.length || o < others.length) {
      final discoveryTurn = (out.length + 1) % discoveryEvery == 0;
      if (o < others.length && (discoveryTurn || l >= loved.length)) {
        out.add(others[o++]);
      } else {
        out.add(loved[l++]);
      }
    }
    return out;
  }

  /// The library's most used tags (lower-cased key -> label as written).
  static Map<String, String> topTags(List<GameEntry> games, {int limit = 8}) {
    final counts = <String, int>{};
    final labels = <String, String>{};
    for (final game in games) {
      for (final tag in game.tags) {
        final key = tag.toLowerCase();
        counts[key] = (counts[key] ?? 0) + 1;
        labels.putIfAbsent(key, () => tag);
      }
    }
    final keys = counts.keys.toList()
      ..sort((a, b) {
        final c = counts[b]! - counts[a]!;
        return c != 0 ? c : a.compareTo(b);
      });
    return {for (final key in keys.take(limit)) key: labels[key]!};
  }
}

/// Outline color for something hovered by player cursors (the interface
/// only uses white and the highlight color; player colors stay on faces).
Color _hoverColor(List<DeviceModel> hoveredBy, Color fallback) =>
    hoveredBy.isEmpty ? fallback : AppColors.highlightColor;

/// Splits [games] into columns of [perColumn] for the horizontal grid.
/// With [centerOut] the first games land in the middle column and the rest
/// alternate right and left of it (so the most recent games are where the
/// library starts). Returns the columns left to right and the index of the
/// column to start centered on.
({List<List<GameEntry>> columns, int start}) layoutColumns(
  List<GameEntry> games, {
  int perColumn = 2,
  bool centerOut = true,
}) {
  final chunks = <List<GameEntry>>[
    for (var i = 0; i < games.length; i += perColumn)
      games.sublist(i, math.min(i + perColumn, games.length)),
  ];
  if (!centerOut || chunks.length < 3) {
    return (columns: chunks, start: 0);
  }
  // chunk 0 in the middle, then 1 to its right, 2 to its left, ...
  final left = <List<GameEntry>>[];
  final right = <List<GameEntry>>[];
  for (var i = 1; i < chunks.length; i++) {
    (i.isOdd ? right : left).add(chunks[i]);
  }
  return (
    columns: [...left.reversed, chunks.first, ...right],
    start: left.length,
  );
}

/// How hard the cursors push the grid sideways: each cursor inside an edge
/// zone (within [zone] of the left/right side of [grid], or past it, e.g.
/// pinned at the screen's edge) adds its depth (0..1), negative on the left.
/// Opposite pushes cancel out.
double edgePushForce(Iterable<Offset> cursors, Rect grid, double zone) {
  var force = 0.0;
  for (final c in cursors) {
    if (c.dy < grid.top || c.dy > grid.bottom) continue;
    if (c.dx < grid.left + zone) {
      force -= ((grid.left + zone - c.dx) / zone).clamp(0.0, 1.0);
    } else if (c.dx > grid.right - zone) {
      force += ((c.dx - (grid.right - zone)) / zone).clamp(0.0, 1.0);
    }
  }
  return force;
}

// ------------------------------------------------------------ player count

/// "3 players" with everyone's face, at the top of the library.
class PlayerCountBadge extends StatelessWidget {
  final List<DeviceModel> players;

  const PlayerCountBadge({super.key, required this.players});

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.session;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
      decoration: BoxDecoration(
        color: AppColors.lightColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.textPrimary, width: 3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.highlightColor,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: AppColors.textPrimary, width: 2),
            ),
            child: Text('${players.length}', style: _numberStyle),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.playersInSession(players.length),
                style: _buttonStyle,
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final player in players.take(8))
                    Padding(
                      padding: const EdgeInsets.only(right: 3),
                      child: PlayerFaceIndicator(face: player.face, size: 20),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- filter bar

/// A chip the cursors (and the mouse) can press.
class LibraryChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final List<DeviceModel> hoveredBy;
  final VoidCallback onTap;
  final Color? backgroundColor;

  const LibraryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.hoveredBy,
    required this.onTap,
    this.icon,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          scale: hoveredBy.isNotEmpty ? 1.08 : 1,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.highlightColor
                  : (backgroundColor ?? AppColors.lightColor),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _hoverColor(hoveredBy, AppColors.textPrimary),
                width: 3,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: AppColors.textPrimary),
                  const SizedBox(width: 5),
                ],
                Text(label, style: _buttonStyle.copyWith(fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Target ids used by the library's cursor hit-testing.
abstract final class LibraryTargets {
  static const fitsOnly = 'filter:fits';
  static const sort = 'filter:sort';
  static const clear = 'filter:clear';
  static String tag(String key) => 'tag:$key';
  static String game(String id) => 'game:$id';
  static String info(String id) => 'info:$id';
  static const lobby = 'nav:lobby';
  static const freeMode = 'nav:free';
  static const panel = 'panel';
  static const panelVote = 'panel:vote';
  static const panelTrailer = 'panel:trailer';
  static const panelClose = 'panel:close';
}

class LibraryFilterBar extends StatelessWidget {
  final LibraryFilter filter;
  final Map<String, String> tags;
  final int playerCount;
  final GlobalKey Function(String target) keyFor;
  final List<DeviceModel> Function(String target) hoveredBy;
  final ValueChanged<String> onPress;

  const LibraryFilterBar({
    super.key,
    required this.filter,
    required this.tags,
    required this.playerCount,
    required this.keyFor,
    required this.hoveredBy,
    required this.onPress,
  });

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.session;
    Widget chip(String target, String label, bool selected, {IconData? icon}) =>
        LibraryChip(
          key: keyFor(target),
          label: label,
          icon: icon,
          selected: selected,
          hoveredBy: hoveredBy(target),
          onTap: () => onPress(target),
        );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        chip(
          LibraryTargets.sort,
          strings.sortLabel(filter.sort.index),
          false,
          icon: Icons.sort_rounded,
        ),
        chip(
          LibraryTargets.fitsOnly,
          strings.fitsOnly(playerCount),
          filter.fitsOnly,
          icon: Icons.groups_rounded,
        ),
        for (final entry in tags.entries)
          chip(
            LibraryTargets.tag(entry.key),
            entry.value,
            filter.tags.contains(entry.key),
          ),
        if (filter.isFiltering)
          chip(
            LibraryTargets.clear,
            strings.clearFilters,
            false,
            icon: Icons.close_rounded,
          ),
      ],
    );
  }
}

// -------------------------------------------------------------------- card

class LibraryGameCard extends StatelessWidget {
  static const double borderWidth = 4;
  static const double radius = 18;
  static const double nameHeight = 40;
  static const double onlyForHeight = 30;

  final GameEntry game;
  final int playerCount;
  final double width;
  final double height;

  /// Players whose vote is stuck on this card, as round stickers.
  final List<DeviceModel> voters;
  final List<DeviceModel> hoveredBy;
  final bool isCountdownTarget;
  final bool coverOnly;
  final VoidCallback onTap;
  final VoidCallback? onSecondaryTap;

  const LibraryGameCard({
    super.key,
    required this.game,
    required this.playerCount,
    required this.width,
    required this.height,
    required this.voters,
    required this.hoveredBy,
    required this.isCountdownTarget,
    this.coverOnly = true,
    required this.onTap,
    this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.session;
    final fits = game.fits(playerCount);
    final fit = playerFit(game, playerCount);
    // Takes fewer players than are here: a bar says so, which is also why
    // these games sit at the end of the library.
    final onlyFor = fit == PlayerFit.fewer;
    final highlighted = hoveredBy.isNotEmpty || isCountdownTarget;
    final borderColor = highlighted
        ? AppColors.highlightColor
        : AppColors.textPrimary;
    final sticker = math.min(64.0, height * 0.2);

    Widget innerContent;
    if (coverOnly) {
      innerContent = GameCover(game: game);
    } else {
      innerContent = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final coverWidth = math.min(
                  box.maxHeight * 2 / 3,
                  box.maxWidth * 0.55,
                );
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: coverWidth,
                      child: GameCover(game: game),
                    ),
                    if (box.maxWidth - coverWidth > 60) ...[
                      Container(
                        width: borderWidth,
                        color: borderColor,
                      ),
                      Expanded(
                        child: GameExtras(game: game),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          Container(
            height: borderWidth,
            color: borderColor,
          ),
          SizedBox(
            height: nameHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  game.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _cardTitleStyle,
                ),
              ),
            ),
          ),
        ],
      );
    }

    Widget cardBody = Container(
      padding: const EdgeInsets.all(borderWidth),
      decoration: BoxDecoration(
        color: borderColor,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          radius - borderWidth,
        ),
        child: ColoredBox(
          color: AppColors.lightColor,
          child: Stack(
            fit: StackFit.expand,
            children: [
              innerContent,
              if (onlyFor)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: coverOnly ? 0 : nameHeight + borderWidth,
                  height: onlyForHeight,
                  child: ColoredBox(
                    color: borderColor,
                    child: Center(
                      child: Text(
                        strings.onlyForPlayers(game.maxPlayers),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _onlyForStyle,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    // Needs more players than are here (rare): dimmed.
    if (fit == PlayerFit.needsMore) {
      const grayscaleMatrix = <double>[
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0,      0,      0,      1, 0,
      ];
      cardBody = ColorFiltered(
        colorFilter: const ColorFilter.matrix(grayscaleMatrix),
        child: Opacity(
          opacity: 0.38,
          child: cardBody,
        ),
      );
    }

    final tooltipMessage = coverOnly
        ? '${game.name} · ${strings.clickToPlay}'
        : strings.clickToPlay;

    return Tooltip(
      message: tooltipMessage,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        cursor: fits ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
        child: GestureDetector(
          onTap: onTap,
          onSecondaryTap: onSecondaryTap,
          child: AnimatedScale(
            scale: highlighted ? 1.04 : 1.0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(child: cardBody),
                  // Votes: round stickers stuck at the bottom of the cover.
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: (coverOnly ? 8 : nameHeight + borderWidth + 8) +
                        (onlyFor ? onlyForHeight : 0),
                    child: Wrap(
                      spacing: -sticker * 0.25,
                      runSpacing: -sticker * 0.3,
                      children: [
                        for (final voter in voters)
                          VoteSticker(
                            key: ValueKey('sticker_${voter.id}'),
                            device: voter,
                            size: sticker,
                          ),
                      ],
                    ),
                  ),
                  if (voters.isNotEmpty)
                    Positioned(
                      right: -8,
                      top: -8,
                      child: VoteCountBadge(count: voters.length),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A player's vote: their face squashed into a round sticker stuck to the
/// card. It lands flattened and springs back round, with a little tilt.
class VoteSticker extends StatelessWidget {
  final DeviceModel device;
  final double size;

  const VoteSticker({super.key, required this.device, required this.size});

  @override
  Widget build(BuildContext context) {
    // Each player's sticker always sits at the same slight angle.
    final tilt = ((device.id.hashCode % 21) - 10) / 60;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      builder: (context, t, child) {
        final squash = Curves.elasticOut.transform(t);
        return Transform.rotate(
          angle: tilt,
          child: Transform.scale(
            scaleX: 1.6 - 0.6 * squash,
            scaleY: 0.4 + 0.6 * squash,
            child: child,
          ),
        );
      },
      child: FaceSticker(face: device.face, size: size),
    );
  }
}

/// A face as a round sticker with a black border.
class FaceSticker extends StatelessWidget {
  final PlayerFaceData face;
  final double size;

  const FaceSticker({super.key, required this.face, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: face.color,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.textPrimary, width: 3),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(1, 2)),
        ],
      ),
      padding: EdgeInsets.all(size * 0.18),
      child: FittedBox(
        child: Transform.rotate(
          angle: playerFaceRotationAngle(face.rotation),
          child: Text(
            face.faceText,
            maxLines: 1,
            style: TextStyle(
              fontFamily: 'monomaniac',
              fontFamilyFallback: const ['noto_symbols'],
              fontSize: size * 0.5,
              height: 0.9,
              color: Colors.black.withValues(alpha: 0.85),
            ),
          ),
        ),
      ),
    );
  }
}

/// The wide part of a card: the game's extra images (a big one and up to
/// two small ones), or its description and tags when it has none.
class GameExtras extends StatelessWidget {
  final GameEntry game;

  const GameExtras({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final shots = game.screenshots;
    if (shots.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                game.description.isEmpty
                    ? context.l10n.session.noDescription
                    : game.description,
                overflow: TextOverflow.fade,
                style: _captionStyle.copyWith(fontSize: 13),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [for (final tag in game.tags.take(3)) _TagPill(tag)],
            ),
          ],
        ),
      );
    }
    Widget image(String url) => Image.network(
      url,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) =>
          ColoredBox(color: AppColors.highlightColor.withValues(alpha: 0.25)),
    );
    final small = shots.skip(1).take(2).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 3, child: image(shots.first)),
        if (small.isNotEmpty) ...[
          const SizedBox(height: 3),
          Expanded(
            flex: 2,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, url) in small.indexed) ...[
                  if (i > 0) const SizedBox(width: 3),
                  Expanded(child: image(url)),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Number of votes on a card, in its top-right corner.
class VoteCountBadge extends StatelessWidget {
  final int count;

  const VoteCountBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(count),
      tween: Tween(begin: 1.6, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.highlightColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.textPrimary, width: 3),
        ),
        child: Text('$count', style: _numberStyle),
      ),
    );
  }
}


class _TagPill extends StatelessWidget {
  final String tag;

  const _TagPill(this.tag);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.highlightColor.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.textPrimary, width: 1.5),
      ),
      child: Text(tag, maxLines: 1, style: _buttonStyle.copyWith(fontSize: 11)),
    );
  }
}

/// The game's cover, or a colored placeholder with its initials.
class GameCover extends StatelessWidget {
  final GameEntry game;

  const GameCover({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    if (game.coverPath.isNotEmpty && File(game.coverPath).existsSync()) {
      return Image.file(File(game.coverPath), fit: BoxFit.cover);
    }
    final hue = (game.name.codeUnits.fold<int>(0, (a, b) => a + b) * 37) % 360;
    final initials = game.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return Container(
      color: HSLColor.fromAHSL(1, hue.toDouble(), 0.55, 0.72).toColor(),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontFamily: 'momo',
          fontSize: 56,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- details

/// YouTube video id from the usual link shapes, for the thumbnail.
String? youTubeId(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return null;
  final host = uri.host.replaceFirst('www.', '').replaceFirst('m.', '');
  if (host == 'youtu.be' && uri.pathSegments.isNotEmpty) {
    return uri.pathSegments.first;
  }
  if (host == 'youtube.com' || host == 'music.youtube.com') {
    if (uri.queryParameters['v'] case final v? when v.isNotEmpty) return v;
    final segments = uri.pathSegments;
    if (segments.length >= 2 &&
        (segments.first == 'embed' || segments.first == 'shorts')) {
      return segments[1];
    }
  }
  return null;
}

/// Side panel with everything about one game. Its buttons can be pressed by
/// any player's cursor; Back from whoever opened it closes it.
class GameDetailsPanel extends StatelessWidget {
  final GameEntry game;
  final int playerCount;
  final DeviceModel? openedBy;
  final List<DeviceModel> voters;
  final GlobalKey Function(String target) keyFor;
  final List<DeviceModel> Function(String target) hoveredBy;
  final ValueChanged<String> onPress;

  const GameDetailsPanel({
    super.key,
    required this.game,
    required this.playerCount,
    required this.openedBy,
    required this.voters,
    required this.keyFor,
    required this.hoveredBy,
    required this.onPress,
  });

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.session;
    final fits = game.fits(playerCount);
    final videoId = youTubeId(game.trailerUrl);

    Widget button(
      String target,
      String label,
      IconData icon, {
      bool primary = false,
    }) {
      final hovered = hoveredBy(target);
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          key: keyFor(target),
          onTap: () => onPress(target),
          child: AnimatedScale(
            scale: hovered.isNotEmpty ? 1.06 : 1,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutBack,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: primary
                    ? AppColors.highlightColor
                    : AppColors.lightColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _hoverColor(hovered, AppColors.textPrimary),
                  width: 3,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20, color: AppColors.textPrimary),
                  const SizedBox(width: 6),
                  Text(label, style: _buttonStyle),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      key: keyFor(LibraryTargets.panel),
      decoration: BoxDecoration(
        color: AppColors.lightColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.textPrimary, width: 4),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              // Smaller screens keep room for the text and the buttons.
              height: (constraints.maxHeight * 0.36).clamp(80.0, 220.0),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GameCover(game: game),
                  if (openedBy != null)
                    Positioned(
                      left: 10,
                      top: 10,
                      child: PlayerFaceIndicator(
                        face: openedBy!.face,
                        size: 34,
                      ),
                    ),
                ],
              ),
            ),
            Container(height: 4, color: AppColors.textPrimary),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(game.name, style: _titleStyle),
                    const SizedBox(height: 6),
                    Text(
                      fits
                          ? strings.fitsSession(playerCount)
                          : strings.doesNotFit(playerCount),
                      style: _captionStyle,
                    ),
                    if (game.tags.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: [for (final tag in game.tags) _TagPill(tag)],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      game.description.isEmpty
                          ? strings.noDescription
                          : game.description,
                      style: _bodyStyle,
                    ),
                    if (game.trailerUrl.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => onPress(LibraryTargets.panelTrailer),
                        child: _TrailerPreview(
                          key: keyFor(LibraryTargets.panelTrailer),
                          videoId: videoId,
                          hoveredBy: hoveredBy(LibraryTargets.panelTrailer),
                        ),
                      ),
                    ],
                    if (voters.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          for (final voter in voters)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: PlayerFaceIndicator(
                                face: voter.face,
                                size: 26,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Container(height: 3, color: AppColors.textPrimary),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.end,
                children: [
                  button(
                    LibraryTargets.panelClose,
                    strings.closeDetails,
                    Icons.close_rounded,
                  ),
                  if (fits)
                    button(
                      LibraryTargets.panelVote,
                      strings.voteForThis,
                      Icons.how_to_vote_rounded,
                      primary: true,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrailerPreview extends StatelessWidget {
  final String? videoId;
  final List<DeviceModel> hoveredBy;

  const _TrailerPreview({
    super.key,
    required this.videoId,
    required this.hoveredBy,
  });

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.session;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 150,
        decoration: BoxDecoration(
          color: AppColors.textPrimary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _hoverColor(hoveredBy, AppColors.textPrimary),
            width: 3,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (videoId != null)
              Image.network(
                'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.lightColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.textPrimary, width: 3),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.play_arrow_rounded,
                      size: 24,
                      color: AppColors.textPrimary,
                    ),
                    const SizedBox(width: 4),
                    Text(strings.watchTrailer, style: _buttonStyle),
                  ],
                ),
              ),
            ),
          ],
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

const TextStyle _onlyForStyle = TextStyle(
  fontFamily: 'momo',
  fontWeight: FontWeight.bold,
  fontSize: 15,
  color: AppColors.lightColor,
);

const TextStyle _cardTitleStyle = TextStyle(
  fontFamily: 'momo',
  fontWeight: FontWeight.bold,
  fontSize: 17,
  color: AppColors.textPrimary,
);

const TextStyle _numberStyle = TextStyle(
  fontFamily: 'momo',
  fontWeight: FontWeight.bold,
  fontSize: 22,
  color: AppColors.textPrimary,
);

const TextStyle _bodyStyle = TextStyle(
  fontFamily: 'momo',
  fontSize: 14,
  color: AppColors.textPrimary,
);

const TextStyle _buttonStyle = TextStyle(
  fontFamily: 'momo',
  fontWeight: FontWeight.bold,
  fontSize: 14,
  color: AppColors.textPrimary,
);

final TextStyle _captionStyle = TextStyle(
  fontFamily: 'momo',
  fontSize: 12,
  color: AppColors.textPrimary.withValues(alpha: 0.65),
);
