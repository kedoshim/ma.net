import 'dart:convert';
import 'package:http/http.dart' as http;

/// Details and media for a game fetched from IGDB (via Playnite services proxy).
class IgdbDetails {
  final String name;
  final String description;
  final String coverUrl;
  final List<String> tags;
  final List<String> screenshots;
  final String trailerUrl;

  const IgdbDetails({
    required this.name,
    required this.description,
    required this.coverUrl,
    required this.tags,
    this.screenshots = const [],
    this.trailerUrl = '',
  });

  /// Map IGDB game modes and genres into couch-relevant tags and categories.
  static List<String> couchTags({
    Iterable<String>? modes,
    Iterable<String>? genres,
  }) {
    final tags = <String>[];
    void add(String tag) {
      if (!tags.contains(tag)) tags.add(tag);
    }

    if (modes != null) {
      for (final mode in modes) {
        final m = mode.toLowerCase();
        if (m.contains('split') || m.contains('dividida') || m.contains('compartilhada')) {
          add('Tela dividida');
        } else if (m.contains('co-op') || m.contains('cooperative') || m.contains('coop')) {
          add('Co-op');
        } else if (m.contains('pvp') || m.contains('versus') || m.contains('competitive')) {
          add('PvP');
        } else if (m.contains('multiplayer') || m.contains('multijogador')) {
          add('Multijogador');
        }
      }
    }

    if (genres != null) {
      for (final g in genres) {
        if (g.trim().isNotEmpty) add(g.trim());
      }
    }

    return tags;
  }

  /// Builds a high-resolution cover image URL given an image ID or a thumbnail URL.
  static String coverUrlFromImageId(String source) {
    if (source.isEmpty) return '';
    // If it's already an IGDB URL with /t_thumb/, replace it with /t_cover_big/
    if (source.contains('images.igdb.com')) {
      final normalized = source.startsWith('//') ? 'https:$source' : source;
      return normalized.replaceAll(RegExp(r'/t_[^/]+/'), '/t_cover_big/');
    }
    // Clean image ID
    final id = source.trim();
    return 'https://images.igdb.com/igdb/image/upload/t_cover_big/$id.jpg';
  }

  /// Parse game data from the Playnite IGDB service response map.
  static IgdbDetails fromGameData(Map<String, dynamic> data) {
    final name = data['name'] as String? ?? '';
    final summary = data['summary'] as String? ?? data['storyline'] as String? ?? '';

    // Cover
    String coverUrl = '';
    final coverExpanded = data['cover_expanded'] as Map<String, dynamic>?;
    if (coverExpanded != null) {
      final imageId = coverExpanded['image_id'] as String?;
      final rawUrl = coverExpanded['url'] as String?;
      if (imageId != null && imageId.isNotEmpty) {
        coverUrl = coverUrlFromImageId(imageId);
      } else if (rawUrl != null && rawUrl.isNotEmpty) {
        coverUrl = coverUrlFromImageId(rawUrl);
      }
    }

    // Modes & Genres
    final modes = [
      for (final item in (data['game_modes_expanded'] as List<dynamic>? ?? const []))
        if (item is Map<String, dynamic> && item['name'] != null)
          item['name'] as String,
    ];
    final genres = [
      for (final item in (data['genres_expanded'] as List<dynamic>? ?? const []))
        if (item is Map<String, dynamic> && item['name'] != null)
          item['name'] as String,
    ];
    final tags = couchTags(modes: modes, genres: genres);

    // Screenshots
    final screenshots = [
      for (final shot in (data['screenshots_expanded'] as List<dynamic>? ?? const []))
        if (shot is Map<String, dynamic>)
          if (shot['image_id'] case final String id when id.isNotEmpty)
            'https://images.igdb.com/igdb/image/upload/t_screenshot_big/$id.jpg'
          else if (shot['url'] case final String url when url.isNotEmpty)
            (url.startsWith('//') ? 'https:$url' : url).replaceAll(RegExp(r'/t_[^/]+/'), '/t_screenshot_big/'),
    ].take(8).toList();

    // Trailer / Website
    String trailer = '';
    for (final site in (data['websites_expanded'] as List<dynamic>? ?? const [])) {
      if (site is Map<String, dynamic>) {
        final url = site['url'] as String? ?? '';
        if (url.contains('youtube.com') || url.contains('youtu.be')) {
          trailer = url;
          break;
        }
      }
    }

    return IgdbDetails(
      name: name,
      description: summary.trim(),
      coverUrl: coverUrl,
      tags: tags,
      screenshots: screenshots,
      trailerUrl: trailer,
    );
  }
}

/// A search result returned by IGDB search.
class IgdbSearchResult {
  final int id;
  final String name;
  final String coverUrl;

  const IgdbSearchResult({
    required this.id,
    required this.name,
    required this.coverUrl,
  });
}

/// Client for searching and retrieving game data from IGDB via proxy.
class IgdbService {
  static const String defaultEndpoint = 'https://api2.playnite.link/api/';

  final String endpoint;
  final http.Client _client;

  IgdbService({String? endpoint, http.Client? client})
      : endpoint = endpoint ?? defaultEndpoint,
        _client = client ?? http.Client();

  /// Search games by name.
  Future<List<IgdbSearchResult>> search(String query) async {
    final term = query.trim();
    if (term.isEmpty) return const [];

    final uri = Uri.parse(endpoint).resolve('igdb/search');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'MaNet/1.0',
      },
      body: jsonEncode({'SearchTerm': term}),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      return const [];
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final items = body['data'] as List<dynamic>? ?? const [];

    final results = <IgdbSearchResult>[];
    for (final item in items.take(12)) {
      if (item is! Map<String, dynamic>) continue;
      final id = item['id'] as int? ?? 0;
      final name = item['name'] as String? ?? '';
      String coverUrl = '';
      if (item['cover_expanded'] case final Map<String, dynamic> cover) {
        if (cover['image_id'] case final String imageId when imageId.isNotEmpty) {
          coverUrl = IgdbDetails.coverUrlFromImageId(imageId);
        } else if (cover['url'] case final String url when url.isNotEmpty) {
          coverUrl = IgdbDetails.coverUrlFromImageId(url);
        }
      }
      if (id > 0 && name.isNotEmpty) {
        results.add(IgdbSearchResult(id: id, name: name, coverUrl: coverUrl));
      }
    }

    return results;
  }

  /// Fetch full game details by IGDB ID.
  Future<IgdbDetails?> fetchGameDetails(int id) async {
    final uri = Uri.parse(endpoint).resolve('igdb/game/$id');
    final response = await _client.get(
      uri,
      headers: {'User-Agent': 'MaNet/1.0'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      return null;
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) return null;

    return IgdbDetails.fromGameData(data);
  }
}
