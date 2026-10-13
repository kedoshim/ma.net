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

  test('games that fit come first, then the chosen order', () {
    expect(
      names(const LibraryFilter(sort: LibrarySort.alphabetical).apply(games, 3)),
      ['Festa', 'Zebra Kart', 'Aventura'],
    );
    expect(
      names(const LibraryFilter(sort: LibrarySort.recent).apply(games, 3)),
      ['Zebra Kart', 'Festa', 'Aventura'],
    );
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

  test('recent: last played first, then last added', () {
    const played = [
      GameEntry(id: 'old', name: 'Old', path: 'o', addedAt: 9),
      GameEntry(id: 'played', name: 'Played', path: 'p', addedAt: 1, lastPlayedAt: 100),
      GameEntry(id: 'new', name: 'New', path: 'n', addedAt: 10),
    ];
    expect(names(const LibraryFilter().apply(played, 1)), ['Played', 'New', 'Old']);
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
