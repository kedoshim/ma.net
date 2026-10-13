import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:manet_desktop/services/igdb_service.dart';

void main() {
  group('IgdbDetails', () {
    test('game modes and genres become couch tags and categories', () {
      final tags = IgdbDetails.couchTags(
        modes: ['Single player', 'Co-operative', 'Split screen', 'Multiplayer'],
        genres: ['Action', 'Indie'],
      );

      expect(tags, contains('Co-op'));
      expect(tags, contains('Tela dividida'));
      expect(tags, contains('Multijogador'));
      expect(tags, contains('Action'));
      expect(tags, contains('Indie'));
    });

    test('builds high-res cover URL from image ID or partial URL', () {
      expect(
        IgdbDetails.coverUrlFromImageId('co262g'),
        'https://images.igdb.com/igdb/image/upload/t_cover_big/co262g.jpg',
      );

      expect(
        IgdbDetails.coverUrlFromImageId('//images.igdb.com/igdb/image/upload/t_thumb/co262g.jpg'),
        'https://images.igdb.com/igdb/image/upload/t_cover_big/co262g.jpg',
      );
    });

    test('parses game details correctly from IGDB API response map', () {
      final data = {
        'id': 18433,
        'name': 'Overcooked!',
        'summary': 'Overcooked! is a chaotic couch co-op cooking game for 1-4 players.',
        'cover_expanded': {
          'image_id': 'co262g',
          'url': '//images.igdb.com/igdb/image/upload/t_thumb/co262g.jpg',
        },
        'game_modes_expanded': [
          {'name': 'Co-operative'},
          {'name': 'Split screen'},
        ],
        'genres_expanded': [
          {'name': 'Simulator'},
        ],
        'screenshots_expanded': [
          {'image_id': 'sc123'},
          {'image_id': 'sc456'},
        ],
        'websites_expanded': [
          {'url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'},
        ],
      };

      final details = IgdbDetails.fromGameData(data);

      expect(details.name, 'Overcooked!');
      expect(details.description, contains('chaotic couch co-op'));
      expect(details.coverUrl, 'https://images.igdb.com/igdb/image/upload/t_cover_big/co262g.jpg');
      expect(details.tags, contains('Co-op'));
      expect(details.tags, contains('Tela dividida'));
      expect(details.tags, contains('Simulator'));
      expect(details.screenshots, [
        'https://images.igdb.com/igdb/image/upload/t_screenshot_big/sc123.jpg',
        'https://images.igdb.com/igdb/image/upload/t_screenshot_big/sc456.jpg',
      ]);
      expect(details.trailerUrl, 'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
    });
  });

  group('IgdbService', () {
    test('search parses list of games from proxy', () async {
      final mockClient = http_testing.MockClient((request) async {
        expect(request.url.path, '/api/igdb/search');
        return http.Response(
          '{"data": [{"id": 1, "name": "Game A", "cover_expanded": {"image_id": "c1"}}]}',
          200,
        );
      });

      final service = IgdbService(client: mockClient);
      final results = await service.search('Game');

      expect(results.length, 1);
      expect(results.first.id, 1);
      expect(results.first.name, 'Game A');
      expect(results.first.coverUrl, contains('c1.jpg'));
    });

    test('fetchGameDetails returns null on error', () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response('Not found', 404);
      });

      final service = IgdbService(client: mockClient);
      final details = await service.fetchGameDetails(999);

      expect(details, isNull);
    });
  });
}
