import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:manet_desktop/models/session_models.dart';
import 'package:manet_desktop/screens/library/library_browser.dart';

void main() {
  const games = [
    GameEntry(name: 'Zebra Kart', path: 'z', minPlayers: 1, maxPlayers: 4, tags: ['Corrida'], addedAt: 3),
    GameEntry(name: 'Aventura', path: 'a', minPlayers: 1, maxPlayers: 1, tags: ['Aventura'], addedAt: 5),
    GameEntry(name: 'Festa', path: 'f', minPlayers: 2, maxPlayers: 8, tags: ['Festa', 'corrida'], addedAt: 1),
  ];
  List<String> names(List<GameEntry> list) => [for (final g in list) g.name];

  test('everyone plays first, then fewer seats, then needs more', () {
    const az = LibrarySort.alphabetical;
    expect(
      names(const LibraryFilter(sort: az).apply(games, 3)),
      ['Festa', 'Zebra Kart', 'Aventura'],
    );
    // 5 players: Festa fits everyone; Zebra Kart (4) lets more in than
    // Aventura (1); nothing needs more.
    expect(names(const LibraryFilter(sort: az).apply(games, 5)), ['Festa', 'Zebra Kart', 'Aventura']);
    // 1 player: Festa needs 2 and goes last.
    expect(names(const LibraryFilter(sort: az).apply(games, 1)), ['Aventura', 'Zebra Kart', 'Festa']);
    expect(playerFit(games[0], 5), PlayerFit.fewer);
    expect(playerFit(games[2], 1), PlayerFit.needsMore);
    expect(
      names(const LibraryFilter(sort: LibrarySort.players).apply(games, 3)),
      ['Festa', 'Zebra Kart', 'Aventura'],
    );
  });

  test('filters combine: fits the session AND any of the tags', () {
    const az = LibrarySort.alphabetical;
    expect(names(const LibraryFilter(fitsOnly: true, sort: az).apply(games, 3)), ['Festa', 'Zebra Kart']);
    expect(names(const LibraryFilter(tags: {'corrida'}, sort: az).apply(games, 1)), ['Zebra Kart', 'Festa']);
    expect(
      names(const LibraryFilter(tags: {'corrida'}, fitsOnly: true, sort: az).apply(games, 1)),
      ['Zebra Kart'],
    );
  });

  test('favorites: by score, a little-played game every 4th card', () {
    final list = [
      for (var i = 0; i < 6; i++)
        GameEntry(id: 'fav$i', name: 'Fav $i', path: 'f$i', score: 10.0 - i),
      for (var i = 0; i < 3; i++)
        GameEntry(id: 'new$i', name: 'New $i', path: 'n$i', score: 0.2),
    ];
    final order = LibraryFilter.favoritesOrder(list);
    final kinds = [for (final g in order) g.id.substring(0, 3)];
    expect(kinds, ['fav', 'fav', 'fav', 'new', 'fav', 'fav', 'fav', 'new', 'new']);
    expect(
      [for (final g in order) if (g.score >= 1) g.id],
      ['fav0', 'fav1', 'fav2', 'fav3', 'fav4', 'fav5'],
    );
  });

  test('no game wins by its name: unplayed games follow the night draw', () {
    final list = [
      for (var i = 0; i < 12; i++)
        GameEntry(id: 'g$i', name: String.fromCharCode(65 + i), path: '$i'),
    ];
    final previous = LibraryFilter.sessionSeed;
    try {
      LibraryFilter.sessionSeed = 1;
      final first = names(LibraryFilter.favoritesOrder(list));
      expect(names(LibraryFilter.favoritesOrder(list)), first); // holds still
      final orders = {
        for (var seed = 1; seed <= 6; seed++)
          (() {
            LibraryFilter.sessionSeed = seed;
            return names(LibraryFilter.favoritesOrder(list)).join();
          })(),
      };
      expect(orders.length, greaterThan(1)); // changes between nights
    } finally {
      LibraryFilter.sessionSeed = previous;
    }
  });

  test('the old "recent" order reads as favorites', () {
    expect(LibraryFilter.parseSort('recent'), LibrarySort.favorites);
    expect(LibraryFilter.parseSort('alphabetical'), LibrarySort.alphabetical);
  });

  test('columns start in the middle and alternate right/left', () {
    final list = [for (var i = 0; i < 9; i++) GameEntry(id: '$i', name: '$i', path: '$i')];
    final layout = layoutColumns(list);
    // chunks: [0,1] [2,3] [4,5] [6,7] [8] -> left: [4,5],[8] / right: [2,3],[6,7]
    expect(
      [for (final c in layout.columns) c.map((g) => g.id).join()],
      ['8', '45', '01', '23', '67'],
    );
    expect(layout.start, 2);
    final plain = layoutColumns(list, centerOut: false);
    expect(plain.start, 0);
    expect(plain.columns.first.map((g) => g.id).join(), '01');
  });

  test('cursors at both edges cancel each other out', () {
    const grid = Rect.fromLTWH(0, 0, 1000, 500);
    expect(edgePushForce(const [Offset(500, 250)], grid, 100), 0);
    expect(edgePushForce(const [Offset(950, 250)], grid, 100), closeTo(0.5, 1e-9));
    expect(edgePushForce(const [Offset(0, 250)], grid, 100), closeTo(-1, 1e-9));
    expect(edgePushForce(const [Offset(0, 250), Offset(1000, 250)], grid, 100), 0);
    // Past the side (cursor stuck at the screen edge) pushes fully.
    expect(edgePushForce(const [Offset(1030, 250)], grid, 100), closeTo(1, 1e-9));
    // Outside the strip vertically (e.g. on the header) doesn't push.
    expect(edgePushForce(const [Offset(0, 600)], grid, 100), 0);
  });

  test('top tags merge different casing and count usage', () {
    expect(LibraryFilter.topTags(games), {'corrida': 'Corrida', 'aventura': 'Aventura', 'festa': 'Festa'});
  });

  test('YouTube ids from common links', () {
    expect(youTubeId('https://www.youtube.com/watch?v=abc123&t=4'), 'abc123');
    expect(youTubeId('https://youtu.be/abc123'), 'abc123');
    expect(youTubeId('https://youtube.com/embed/abc123'), 'abc123');
    expect(youTubeId('https://store.steampowered.com/app/1'), isNull);
  });
}
