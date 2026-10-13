import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../services/igdb_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/juicy_widgets.dart';

/// Covers live in %LOCALAPPDATA%\MaNet\covers so the library keeps working
/// offline and the images can't disappear from under it.
class CoverStore {
  static Directory get _dir {
    final base =
        Platform.environment['LOCALAPPDATA'] ?? Directory.systemTemp.path;
    return Directory(p.join(base, 'MaNet', 'covers'));
  }

  /// Accepts what people actually paste from a browser: direct image links,
  /// Google's redirect/preview links (imgres?imgurl=, url?url=) and the
  /// inline `data:image/...;base64,...` that "Copy image address" gives for
  /// Google Images thumbnails.
  static Future<String> download(String link, String nameHint) async {
    final source = link.trim();
    List<int> bytes;
    if (source.startsWith('data:')) {
      final comma = source.indexOf(',');
      if (comma < 0 || !source.substring(0, comma).contains('base64')) {
        throw const CoverDownloadError(CoverError.invalidLink);
      }
      try {
        bytes = base64Decode(source.substring(comma + 1));
      } on FormatException {
        throw const CoverDownloadError(CoverError.invalidLink);
      }
    } else {
      final uri = _unwrap(Uri.tryParse(source));
      if (uri == null || !uri.hasScheme || !uri.scheme.startsWith('http')) {
        throw const CoverDownloadError(CoverError.invalidLink);
      }
      final http.Response response;
      try {
        response = await http.get(uri, headers: const {
          // Some image hosts refuse requests that don't look like a browser.
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/124.0 Safari/537.36',
          'Accept': 'image/avif,image/webp,image/png,image/jpeg,image/*;q=0.8',
        }).timeout(const Duration(seconds: 20));
      } catch (_) {
        throw const CoverDownloadError(CoverError.unreachable);
      }
      if (response.statusCode != 200) {
        throw const CoverDownloadError(CoverError.unreachable);
      }
      bytes = response.bodyBytes;
    }

    final ext = _imageExtension(bytes);
    if (ext == null) {
      // Usually the link of a web page (search result), not of the image.
      throw const CoverDownloadError(CoverError.notAnImage);
    }
    final slug = nameHint.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final file = File(
      p.join(_dir.path, '$slug-${source.hashCode.toUnsigned(32)}.$ext'),
    );
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// Google wraps the real image link in its own URLs.
  static Uri? _unwrap(Uri? uri) {
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    if (host.contains('google.')) {
      for (final key in const ['imgurl', 'url', 'q']) {
        final inner = uri.queryParameters[key];
        if (inner != null && inner.startsWith('http')) return Uri.tryParse(inner);
      }
    }
    return uri;
  }

  /// Detects the format from the file's first bytes (servers often send a
  /// wrong or missing content type).
  static String? _imageExtension(List<int> b) {
    bool startsWith(List<int> sig, [int offset = 0]) =>
        b.length >= offset + sig.length &&
        List.generate(sig.length, (i) => b[offset + i] == sig[i]).every((ok) => ok);
    if (startsWith(const [0xFF, 0xD8, 0xFF])) return 'jpg';
    if (startsWith(const [0x89, 0x50, 0x4E, 0x47])) return 'png';
    if (startsWith(const [0x47, 0x49, 0x46, 0x38])) return 'gif';
    if (startsWith(const [0x52, 0x49, 0x46, 0x46]) && startsWith(const [0x57, 0x45, 0x42, 0x50], 8)) {
      return 'webp';
    }
    if (startsWith(const [0x42, 0x4D])) return 'bmp';
    return null;
  }
}

enum CoverError { invalidLink, unreachable, notAnImage }

/// Unified game metadata (description, tags, trailer and screenshots).
class GameDetails {
  final String description;
  final List<String> tags;
  final String trailerUrl;
  final List<String> screenshots;

  const GameDetails({
    required this.description,
    required this.tags,
    required this.trailerUrl,
    this.screenshots = const [],
  });
}

/// What the cover search returns: the downloaded file, plus optional
/// game details and the Steam app ID when available.
class CoverPick {
  final String path;
  final int? steamAppId;
  final GameDetails? details;

  const CoverPick(this.path, {this.steamAppId, this.details});
}

/// Store info for a Steam app (public store API, no key needed).
class SteamDetails extends GameDetails {
  const SteamDetails({
    required super.description,
    required super.tags,
    required super.trailerUrl,
    super.screenshots = const [],
  });

  /// Steam's play-mode categories are long ("Co-op, tela dividida/
  /// compartilhada", "PvP online"...); keep the couch-relevant ones as
  /// short tags.
  static List<String> couchTags(Iterable<String> categories) {
    final tags = <String>[];
    void add(String tag) {
      if (!tags.contains(tag)) tags.add(tag);
    }

    for (final category in categories) {
      final c = category.toLowerCase();
      if (c.contains('online') || c.contains('on-line') || c.contains('remote')) {
        continue;
      }
      if (c.contains('tela') || c.contains('ecrã') || c.contains('split')) {
        add('Tela dividida');
      } else if (c.contains('co-op') || c.contains('coop')) {
        add('Co-op');
      } else if (c.contains('pvp') || c.contains('jxj')) {
        add('PvP');
      } else if (c.contains('multijogador') || c.contains('multi-player')) {
        add('Multijogador');
      }
    }
    return tags;
  }

  static Future<SteamDetails?> fetch(int appId) async {
    try {
      final uri = Uri.https('store.steampowered.com', '/api/appdetails', {
        'appids': '$appId',
        'l': 'brazilian',
        'cc': 'BR',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final entry = body['$appId'] as Map<String, dynamic>?;
      if (entry == null || entry['success'] != true) return null;
      return fromAppData(appId, entry['data'] as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static SteamDetails fromAppData(int appId, Map<String, dynamic> data) {
    final genres = [
      for (final g in data['genres'] as List<dynamic>? ?? const [])
        (g as Map<String, dynamic>)['description'] as String? ?? '',
    ].where((g) => g.isNotEmpty).take(4);
    final couch = couchTags([
      for (final c in data['categories'] as List<dynamic>? ?? const [])
        (c as Map<String, dynamic>)['description'] as String? ?? '',
    ]);

    String trailer = '';
    for (final movie in data['movies'] as List<dynamic>? ?? const []) {
      final m = movie as Map<String, dynamic>;
      final url =
          (m['mp4'] as Map<String, dynamic>?)?['max'] ??
          (m['webm'] as Map<String, dynamic>?)?['max'];
      if (url is String && url.isNotEmpty) {
        trailer = url;
        break;
      }
    }
    if (trailer.isEmpty && (data['movies'] as List<dynamic>? ?? const []).isNotEmpty) {
      // Newer apps only list streaming formats: the store page plays them.
      trailer = 'https://store.steampowered.com/app/$appId';
    }

    final screenshots = [
      for (final shot in data['screenshots'] as List<dynamic>? ?? const [])
        if ((shot as Map<String, dynamic>)['path_full'] case final String url
            when url.startsWith('http'))
          url,
    ].take(8).toList();

    return SteamDetails(
      description: cleanHtml(data['short_description'] as String? ?? ''),
      tags: [...genres, ...couch],
      trailerUrl: trailer,
      screenshots: screenshots,
    );
  }

  /// Steam descriptions come as HTML snippets.
  static String cleanHtml(String html) => html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ')
      .trim();
}

class CoverDownloadError implements Exception {
  final CoverError reason;
  const CoverDownloadError(this.reason);
}

enum GameMetadataSource { steam, igdb }

class _SearchResultItem {
  final String name;
  final GameMetadataSource source;
  final String coverUrl;
  final String? headerUrl;
  final int? steamAppId;
  final int? igdbId;

  const _SearchResultItem({
    required this.name,
    required this.source,
    required this.coverUrl,
    this.headerUrl,
    this.steamAppId,
    this.igdbId,
  });
}

/// Find a cover for a game: Unified search across Steam store and IGDB,
/// Google Images in the browser, or a pasted image link.
/// Pops the downloaded file's path and game details.
class CoverSearchDialog extends StatefulWidget {
  final String initialQuery;

  const CoverSearchDialog({super.key, required this.initialQuery});

  @override
  State<CoverSearchDialog> createState() => _CoverSearchDialogState();
}

class _CoverSearchDialogState extends State<CoverSearchDialog> {
  late final TextEditingController _query = TextEditingController(
    text: widget.initialQuery,
  );
  final TextEditingController _link = TextEditingController();
  final IgdbService _igdbService = IgdbService();
  List<_SearchResultItem> _results = const [];
  bool _searching = false;
  bool _downloading = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery.trim().isNotEmpty) _search();
  }

  @override
  void dispose() {
    _query.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final term = _query.text.trim();
    if (term.isEmpty) return;
    setState(() {
      _searching = true;
      _message = null;
    });

    try {
      final steamFuture = _searchSteam(term);
      final igdbFuture = _searchIgdb(term);

      final responses = await Future.wait([steamFuture, igdbFuture]);
      final steamResults = responses[0];
      final igdbResults = responses[1];

      final results = <_SearchResultItem>[];
      final maxLen = math.max(steamResults.length, igdbResults.length);
      for (var i = 0; i < maxLen; i++) {
        if (i < steamResults.length) results.add(steamResults[i]);
        if (i < igdbResults.length) results.add(igdbResults[i]);
      }

      if (!mounted) return;
      setState(() {
        _results = results;
        if (results.isEmpty) _message = context.l10n.session.coverNoResults;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _message = context.l10n.session.coverSearchError);
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<List<_SearchResultItem>> _searchSteam(String term) async {
    try {
      final uri = Uri.https('store.steampowered.com', '/api/storesearch/', {
        'term': term,
        'l': 'brazilian',
        'cc': 'BR',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      final items =
          ((jsonDecode(response.body) as Map<String, dynamic>)['items']
              as List<dynamic>? ??
          const []);
      return [
        for (final item in items.take(12))
          if (item['id'] is int)
            _SearchResultItem(
              name: item['name'] as String? ?? '',
              source: GameMetadataSource.steam,
              steamAppId: item['id'] as int,
              coverUrl:
                  'https://cdn.cloudflare.steamstatic.com/steam/apps/${item['id']}/library_600x900.jpg',
              headerUrl:
                  'https://cdn.cloudflare.steamstatic.com/steam/apps/${item['id']}/header.jpg',
            ),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<List<_SearchResultItem>> _searchIgdb(String term) async {
    try {
      final list = await _igdbService.search(term);
      return [
        for (final item in list)
          _SearchResultItem(
            name: item.name,
            source: GameMetadataSource.igdb,
            igdbId: item.id,
            coverUrl: item.coverUrl,
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _useItem(_SearchResultItem result) async {
    setState(() {
      _downloading = true;
      _message = null;
    });
    try {
      String path;
      try {
        path = await CoverStore.download(result.coverUrl, _query.text);
      } catch (_) {
        if (result.headerUrl == null) rethrow;
        path = await CoverStore.download(result.headerUrl!, _query.text);
      }

      GameDetails? details;
      if (result.source == GameMetadataSource.steam && result.steamAppId != null) {
        details = await SteamDetails.fetch(result.steamAppId!);
      } else if (result.source == GameMetadataSource.igdb && result.igdbId != null) {
        final igdb = await _igdbService.fetchGameDetails(result.igdbId!);
        if (igdb != null) {
          details = GameDetails(
            description: igdb.description,
            tags: igdb.tags,
            trailerUrl: igdb.trailerUrl,
            screenshots: igdb.screenshots,
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pop(CoverPick(
          path,
          steamAppId: result.steamAppId,
          details: details,
        ));
      }
    } on CoverDownloadError catch (e) {
      if (mounted) {
        final strings = context.l10n.session;
        setState(() => _message = switch (e.reason) {
          CoverError.invalidLink => strings.coverInvalidLink,
          CoverError.notAnImage => strings.coverNotAnImage,
          CoverError.unreachable => strings.coverDownloadError,
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = context.l10n.session.coverDownloadError);
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _useLink() async {
    final link = _link.text.trim();
    if (link.isEmpty) return;
    setState(() {
      _downloading = true;
      _message = null;
    });
    try {
      final path = await CoverStore.download(link, _query.text);
      if (mounted) Navigator.of(context).pop(CoverPick(path));
    } on CoverDownloadError catch (e) {
      if (mounted) {
        final strings = context.l10n.session;
        setState(() => _message = switch (e.reason) {
          CoverError.invalidLink => strings.coverInvalidLink,
          CoverError.notAnImage => strings.coverNotAnImage,
          CoverError.unreachable => strings.coverDownloadError,
        });
      }
    } catch (_) {
      if (mounted) setState(() => _message = context.l10n.session.coverDownloadError);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _openGoogle() {
    final query =
        '${_query.text.trim()} ${context.l10n.session.coverGoogleSuffix}';
    launchUrl(
      Uri.https('www.google.com', '/search', {'tbm': 'isch', 'q': query}),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.session;
    return JuicyDialog(
      title: strings.coverSearchTitle,
      maxWidth: 720,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _field(
                  _query,
                  hint: strings.gameName,
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              JuicyButton(
                onPressed: _searching ? null : _search,
                backgroundColor: AppColors.highlightColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Text(strings.coverSearch, style: _buttonStyle),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(strings.coverSteamHint, style: _captionStyle),
          const SizedBox(height: 12),
          if (_searching || _downloading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final result in _results)
                  _CoverOption(
                    result: result,
                    onTap: () => _useItem(result),
                  ),
              ],
            ),
          if (_message != null) ...[
            const SizedBox(height: 10),
            Text(_message!, style: _bodyStyle),
          ],
          const SizedBox(height: 18),
          Text(
            strings.coverOtherSources,
            style: _bodyStyle.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              JuicyButton(
                onPressed: _openGoogle,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.travel_explore_rounded,
                      size: 18,
                      color: AppColors.textPrimary,
                    ),
                    const SizedBox(width: 6),
                    Text(strings.coverGoogle, style: _buttonStyle),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _field(
                  _link,
                  hint: strings.coverPasteLink,
                  onSubmitted: (_) => _useLink(),
                ),
              ),
              const SizedBox(width: 8),
              JuicyButton(
                onPressed: _downloading ? null : _useLink,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Text(strings.coverUseLink, style: _buttonStyle),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller, {
    String? hint,
    ValueChanged<String>? onSubmitted,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.textPrimary, width: 2),
    );
    return TextField(
      controller: controller,
      onSubmitted: onSubmitted,
      style: _bodyStyle,
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: AppColors.lightColor,
        border: border,
        enabledBorder: border,
      ),
    );
  }
}

class _CoverOption extends StatelessWidget {
  final _SearchResultItem result;
  final VoidCallback onTap;

  const _CoverOption({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSteam = result.source == GameMetadataSource.steam;
    return Tooltip(
      message: '${result.name} (${isSteam ? "Steam" : "IGDB"})',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 96,
            height: 144,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.textPrimary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    result.coverUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, _, __) {
                      if (result.headerUrl != null) {
                        return Image.network(
                          result.headerUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, _, __) => _fallback(context),
                        );
                      }
                      return _fallback(context);
                    },
                  ),
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSteam
                            ? const Color(0xFF1B2838)
                            : const Color(0xFF9146FF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white38, width: 1),
                      ),
                      child: Text(
                        isSteam ? 'Steam' : 'IGDB',
                        style: const TextStyle(
                          fontFamily: 'momo',
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    return ColoredBox(
      color: AppColors.lightColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Text(
            result.name,
            textAlign: TextAlign.center,
            style: _captionStyle,
          ),
        ),
      ),
    );
  }
}

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
