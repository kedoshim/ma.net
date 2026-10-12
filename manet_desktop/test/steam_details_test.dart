import 'package:flutter_test/flutter_test.dart';
import 'package:manet_desktop/screens/library/cover_search_dialog.dart';

void main() {
  test('Steam play-mode categories become short couch tags', () {
    // Real category names from the store API (l=brazilian).
    expect(
      SteamDetails.couchTags([
        'Um jogador',
        'Multijogador',
        'JxJ',
        'JxJ on-line',
        'JxJ tela dividida/compart.',
        'Cooperativo',
        'Cooperativo on-line',
        'Coop. tela dividida/compart.',
        'Tela dividida/compartilhada',
        'Remote Play Together',
      ]),
      ['Multijogador', 'PvP', 'Tela dividida', 'Co-op'],
    );
  });

  test('app data gives description, genres + couch tags and a trailer', () {
    final details = SteamDetails.fromAppData(728880, {
      'short_description': 'Caos na cozinha &amp; muito <b>fogo</b>!',
      'genres': [
        {'description': 'Ação'},
        {'description': 'Casual'},
      ],
      'categories': [
        {'description': 'Cooperativo'},
      ],
      'movies': [
        {'id': 1, 'hls_h264': 'x'},
      ],
    });
    expect(details.description, 'Caos na cozinha & muito fogo!');
    expect(details.tags, ['Ação', 'Casual', 'Co-op']);
    expect(details.trailerUrl, 'https://store.steampowered.com/app/728880');
  });
}
