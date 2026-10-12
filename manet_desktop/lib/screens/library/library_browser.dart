import 'dart:io';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/session_models.dart';
import '../../services/host_api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/player_face_indicator.dart';

/// Pieces of the game library screen: bigger game cards, the filter/sort bar,
/// the player count badge and the game details panel. Everything that the
/// player cursors can press gets a [GlobalKey] from the library so it can be
/// hit-tested against the cursors, and a list of who is hovering it.

enum LibrarySort { alphabetical, recent, players }

class LibraryFilter {
  final bool fitsOnly;
  final Set<String> tags;
  final LibrarySort sort;

  const LibraryFilter({
    this.fitsOnly = false,
    this.tags = const {},
    this.sort = LibrarySort.alphabetical,
  });

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

  /// Games to show, in order. Games that fit the session always come first
  /// (the others are dimmed). Tags combine with "any of".
  List<GameEntry> apply(List<GameEntry> games, int players) {
    final shown = [
      for (final game in games)
        if ((!fitsOnly || game.fits(players)) &&
            (tags.isEmpty ||
                game.tags.any((t) => tags.contains(t.toLowerCase()))))
          game,
    ];
    int byName(GameEntry a, GameEntry b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase());
    shown.sort((a, b) {
      final fit = (a.fits(players) ? 0 : 1) - (b.fits(players) ? 0 : 1);
      if (fit != 0) return fit;
      return switch (sort) {
        LibrarySort.alphabetical => byName(a, b),
        LibrarySort.recent =>
          b.addedAt.compareTo(a.addedAt) != 0
              ? b.addedAt.compareTo(a.addedAt)
              : byName(a, b),
        LibrarySort.players =>
          b.maxPlayers != a.maxPlayers
              ? b.maxPlayers - a.maxPlayers
              : byName(a, b),
      };
    });
    return shown;
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

/// Outline color for something hovered by player cursors.
Color _hoverColor(List<DeviceModel> hoveredBy, Color fallback) =>
    hoveredBy.isEmpty ? fallback : hoveredBy.first.color;

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

  const LibraryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.hoveredBy,
    required this.onTap,
    this.icon,
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
              color: selected ? AppColors.highlightColor : AppColors.lightColor,
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
  static const double width = 232;
  static const double coverHeight = 210;
  static const double borderWidth = 4;
  static const double radius = 18;

  final GameEntry game;
  final int playerCount;
  final List<DeviceModel> voters;
  final List<DeviceModel> hoveredBy;
  final List<DeviceModel> infoHoveredBy;
  final bool isCountdownTarget;
  final GlobalKey? infoKey;
  final VoidCallback onTap;
  final VoidCallback onInfo;

  const LibraryGameCard({
    super.key,
    required this.game,
    required this.playerCount,
    required this.voters,
    required this.hoveredBy,
    required this.infoHoveredBy,
    required this.isCountdownTarget,
    required this.onTap,
    required this.onInfo,
    this.infoKey,
  });

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.session;
    final fits = game.fits(playerCount);
    final hovered = [...hoveredBy, ...infoHoveredBy];
    final highlighted = hovered.isNotEmpty || isCountdownTarget;
    final borderColor = isCountdownTarget
        ? AppColors.highlightColor
        : _hoverColor(hovered, AppColors.textPrimary);

    return Tooltip(
      message: strings.clickToPlay,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedScale(
            scale: highlighted ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            child: Opacity(
              opacity: fits ? 1 : 0.45,
              // Same border thickness on every side: the content sits inside
              // the border and no offset shadow thickens one edge.
              child: Container(
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
                      children: [
                        SizedBox(
                          height: coverHeight,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              GameCover(game: game),
                              Positioned(
                                left: 8,
                                top: 8,
                                child: _FitBadge(
                                  game: game,
                                  players: playerCount,
                                ),
                              ),
                              Positioned(
                                right: 8,
                                top: 8,
                                child: _InfoButton(
                                  key: infoKey,
                                  hoveredBy: infoHoveredBy,
                                  onTap: onInfo,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(height: borderWidth, color: borderColor),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                game.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _cardTitleStyle,
                              ),
                              const SizedBox(height: 3),
                              SizedBox(
                                height: 32,
                                child: Text(
                                  game.description.isEmpty
                                      ? strings.noDescription
                                      : game.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: _captionStyle,
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                height: 22,
                                child: ClipRect(
                                  child: Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: [
                                      for (final tag in game.tags.take(3))
                                        _TagPill(tag),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                height: 28,
                                child: Row(
                                  children: [
                                    for (final voter in voters.take(6))
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 4,
                                        ),
                                        child: TweenAnimationBuilder<double>(
                                          key: ValueKey('vote_${voter.id}'),
                                          tween: Tween(begin: 0.2, end: 1),
                                          duration: const Duration(
                                            milliseconds: 420,
                                          ),
                                          curve: Curves.elasticOut,
                                          builder: (context, scale, child) =>
                                              Transform.scale(
                                                scale: scale,
                                                child: child,
                                              ),
                                          child: PlayerFaceIndicator(
                                            face: voter.face,
                                            size: 26,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Players supported, green when the session fits.
class _FitBadge extends StatelessWidget {
  final GameEntry game;
  final int players;

  const _FitBadge({required this.game, required this.players});

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.session;
    final fits = game.fits(players);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: fits ? const Color(0xFF9BE59B) : AppColors.lightColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.textPrimary, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            fits ? Icons.check_rounded : Icons.person_rounded,
            size: 15,
            color: AppColors.textPrimary,
          ),
          const SizedBox(width: 3),
          Text(
            strings.playersShort(game.minPlayers, game.maxPlayers),
            style: _buttonStyle.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _InfoButton extends StatelessWidget {
  final List<DeviceModel> hoveredBy;
  final VoidCallback onTap;

  const _InfoButton({super.key, required this.hoveredBy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.l10n.session.gameDetails,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          scale: hoveredBy.isNotEmpty ? 1.2 : 1,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutBack,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: hoveredBy.isNotEmpty
                  ? AppColors.highlightColor
                  : AppColors.lightColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _hoverColor(hoveredBy, AppColors.textPrimary),
                width: 3,
              ),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              size: 20,
              color: AppColors.textPrimary,
            ),
          ),
        ),
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
                    Row(
                      children: [
                        _FitBadge(game: game, players: playerCount),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            fits
                                ? strings.fitsSession(playerCount)
                                : strings.doesNotFit(playerCount),
                            style: _captionStyle,
                          ),
                        ),
                      ],
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
