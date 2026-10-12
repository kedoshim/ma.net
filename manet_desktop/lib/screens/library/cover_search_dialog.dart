import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
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

  static Future<String> download(String url, String nameHint) async {
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 20));
    final type = response.headers['content-type'] ?? '';
    if (response.statusCode != 200 || !type.startsWith('image/')) {
      throw Exception('not an image');
    }
    final ext = switch (type) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/gif' => 'gif',
      _ => 'jpg',
    };
    final slug = nameHint.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final file = File(
      p.join(_dir.path, '$slug-${url.hashCode.toUnsigned(32)}.$ext'),
    );
    await file.parent.create(recursive: true);
    await file.writeAsBytes(response.bodyBytes);
    return file.path;
  }
}

class _SteamResult {
  final int appId;
  final String name;

  const _SteamResult(this.appId, this.name);

  /// Portrait library art (600x900); some apps only have the wide header.
  String get coverUrl =>
      'https://cdn.cloudflare.steamstatic.com/steam/apps/$appId/library_600x900.jpg';
  String get headerUrl =>
      'https://cdn.cloudflare.steamstatic.com/steam/apps/$appId/header.jpg';
}

/// Find a cover for a game: Steam store search (official art, no API key
/// needed), a Google Images search in the browser, or a pasted image link.
/// Pops the downloaded file's path.
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
  List<_SteamResult> _results = const [];
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
      final uri = Uri.https('store.steampowered.com', '/api/storesearch/', {
        'term': term,
        'l': 'portuguese',
        'cc': 'BR',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      final items =
          ((jsonDecode(response.body) as Map<String, dynamic>)['items']
              as List<dynamic>? ??
          const []);
      final results = [
        for (final item in items.take(12))
          _SteamResult(item['id'] as int, item['name'] as String? ?? ''),
      ];
      if (!mounted) return;
      setState(() {
        _results = results;
        if (results.isEmpty) _message = context.l10n.session.coverNoResults;
      });
    } catch (_) {
      if (mounted)
        setState(() => _message = context.l10n.session.coverSearchError);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _use(String url, [String? fallbackUrl]) async {
    setState(() {
      _downloading = true;
      _message = null;
    });
    try {
      String path;
      try {
        path = await CoverStore.download(url, _query.text);
      } catch (_) {
        if (fallbackUrl == null) rethrow;
        path = await CoverStore.download(fallbackUrl, _query.text);
      }
      if (mounted) Navigator.of(context).pop(path);
    } catch (_) {
      if (mounted)
        setState(() => _message = context.l10n.session.coverDownloadError);
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
                    onTap: () => _use(result.coverUrl, result.headerUrl),
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

  void _useLink() {
    final link = _link.text.trim();
    if (link.startsWith('http')) _use(link);
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
  final _SteamResult result;
  final VoidCallback onTap;

  const _CoverOption({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: result.name,
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
              child: Image.network(
                result.coverUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, _, __) => Image.network(
                  result.headerUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, _, __) => ColoredBox(
                    color: AppColors.lightColor,
                    child: Center(
                      child: Text(
                        result.name,
                        textAlign: TextAlign.center,
                        style: _captionStyle,
                      ),
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
