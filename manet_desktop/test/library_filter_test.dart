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
    expect(names(const LibraryFilter().apply(games, 3)), ['Festa', 'Zebra Kart', 'Aventura']);
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
    expect(names(const LibraryFilter(fitsOnly: true).apply(games, 3)), ['Festa', 'Zebra Kart']);
    expect(names(const LibraryFilter(tags: {'corrida'}).apply(games, 1)), ['Zebra Kart', 'Festa']);
    expect(
      names(const LibraryFilter(tags: {'corrida'}, fitsOnly: true).apply(games, 1)),
      ['Zebra Kart'],
    );
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
