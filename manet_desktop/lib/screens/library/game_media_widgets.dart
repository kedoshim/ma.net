import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../widgets/juicy_widgets.dart';
import 'cover_search_dialog.dart';

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

/// Bordered picture with a small "x" in the corner.
class _RemovableTile extends StatelessWidget {
  final Widget image;
  final double width;
  final double height;
  final VoidCallback? onRemove;

  const _RemovableTile({
    required this.image,
    required this.width,
    required this.height,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width + 8,
      height: height + 8,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 8,
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: AppColors.textPrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.textPrimary, width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: image,
            ),
          ),
          if (onRemove != null)
            Positioned(
              right: 0,
              top: 0,
              child: GestureDetector(
                onTap: onRemove,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.lightColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.textPrimary, width: 2),
                    ),
                    child: const Icon(Icons.close_rounded, size: 15, color: AppColors.textPrimary),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Widget _brokenImage() => const Center(
  child: Icon(Icons.broken_image_rounded, color: AppColors.textPrimary),
);

/// The game's cover as a portrait card; "x" removes it.
class CoverTile extends StatelessWidget {
  final String path;
  final VoidCallback onRemove;

  const CoverTile({super.key, required this.path, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final hasImage = path.isNotEmpty && File(path).existsSync();
    return _RemovableTile(
      width: 96,
      height: 128,
      onRemove: hasImage ? onRemove : null,
      image: hasImage
          ? Image.file(File(path), fit: BoxFit.cover, errorBuilder: (_, _, _) => _brokenImage())
          : const Icon(Icons.sports_esports_rounded, size: 36, color: AppColors.textPrimary),
    );
  }
}

/// Extra images as thumbnails: "+" asks for a link, "x" removes one.
class ImageGallery extends StatelessWidget {
  final List<String> urls;
  final ValueChanged<List<String>> onChanged;

  const ImageGallery({super.key, required this.urls, required this.onChanged});

  Future<void> _add(BuildContext context) async {
    final url = await showDialog<String>(
      context: context,
      builder: (_) => const _AddImageDialog(),
    );
    if (url != null && !urls.contains(url)) onChanged([...urls, url]);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final url in urls)
          _RemovableTile(
            width: 136,
            height: 76,
            onRemove: () => onChanged([...urls]..remove(url)),
            image: Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => _brokenImage()),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Tooltip(
            message: context.l10n.session.addImage,
            child: JuicyButton(
              onPressed: () => _add(context),
              borderRadius: 12,
              padding: EdgeInsets.zero,
              child: const SizedBox(
                width: 76,
                height: 76,
                child: Icon(Icons.add_rounded, size: 34, color: AppColors.textPrimary),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Paste a link and see the image before adding it.
class _AddImageDialog extends StatefulWidget {
  const _AddImageDialog();

  @override
  State<_AddImageDialog> createState() => _AddImageDialogState();
}

class _AddImageDialogState extends State<_AddImageDialog> {
  final _link = TextEditingController();
  String _preview = '';

  @override
  void initState() {
    super.initState();
    _link.addListener(_update);
    _pasteFromClipboard();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (mounted && _link.text.isEmpty && text.startsWith('http')) _link.text = text;
  }

  void _update() {
    final text = _link.text.trim();
    setState(() => _preview = text.startsWith('http') ? text : '');
  }

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.session;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.textPrimary, width: 2),
    );
    return JuicyDialog(
      title: strings.addImage,
      maxWidth: 520,
      actions: [
        JuicyButton(
          onPressed: () => Navigator.of(context).pop(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(strings.cancel, style: _buttonStyle),
        ),
        JuicyButton(
          onPressed: _preview.isEmpty ? null : () => Navigator.of(context).pop(_preview),
          backgroundColor: AppColors.highlightColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(strings.addImageConfirm, style: _buttonStyle),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _link,
            autofocus: true,
            style: _bodyStyle,
            onSubmitted: (_) {
              if (_preview.isNotEmpty) Navigator.of(context).pop(_preview);
            },
            decoration: InputDecoration(
              hintText: strings.imageLinkHint,
              isDense: true,
              filled: true,
              fillColor: AppColors.lightColor,
              border: border,
              enabledBorder: border,
            ),
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.textPrimary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.textPrimary, width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: _preview.isEmpty
                  ? const Icon(Icons.image_outlined, size: 40, color: AppColors.textPrimary)
                  : Image.network(
                      _preview,
                      key: ValueKey(_preview),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Center(
                        child: Text(strings.imageLoadError, style: _captionStyle),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fields the "fetch data" search can fill.
enum GameDataField { cover, description, tags, trailer, images }

/// What a search found, shown field by field with a checkbox each before
/// anything in the form is replaced. Pops the chosen fields.
class GameDataPreviewDialog extends StatefulWidget {
  final CoverPick pick;
  final GameDetails? details;

  /// Fields the form already has: unchecked by default so nothing typed
  /// gets lost by accident.
  final Set<GameDataField> filled;

  const GameDataPreviewDialog({
    super.key,
    required this.pick,
    required this.details,
    required this.filled,
  });

  @override
  State<GameDataPreviewDialog> createState() => _GameDataPreviewDialogState();
}

class _GameDataPreviewDialogState extends State<GameDataPreviewDialog> {
  late final Set<GameDataField> _available;
  late final Set<GameDataField> _chosen;

  @override
  void initState() {
    super.initState();
    final d = widget.details;
    _available = {
      if (widget.pick.path.isNotEmpty) GameDataField.cover,
      if (d != null && d.description.trim().isNotEmpty) GameDataField.description,
      if (d != null && d.tags.isNotEmpty) GameDataField.tags,
      if (d != null && d.trailerUrl.trim().isNotEmpty) GameDataField.trailer,
      if (d != null && d.screenshots.isNotEmpty) GameDataField.images,
    };
    _chosen = _available.difference(widget.filled);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.session;
    final d = widget.details;

    Widget row(GameDataField field, String label, Widget preview) {
      final on = _chosen.contains(field);
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => on ? _chosen.remove(field) : _chosen.add(field)),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: on ? AppColors.highlightColor.withValues(alpha: 0.25) : AppColors.lightColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.textPrimary, width: 2),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  on ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                  color: AppColors.textPrimary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: _buttonStyle),
                      if (widget.filled.contains(field))
                        Text(strings.dataWillReplace, style: _captionStyle),
                      const SizedBox(height: 6),
                      preview,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return JuicyDialog(
      title: strings.dataPreviewTitle,
      maxWidth: 640,
      actions: [
        JuicyButton(
          onPressed: () => Navigator.of(context).pop(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(strings.cancel, style: _buttonStyle),
        ),
        JuicyButton(
          onPressed: _chosen.isEmpty ? null : () => Navigator.of(context).pop(_chosen),
          backgroundColor: AppColors.highlightColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(strings.applyData, style: _buttonStyle),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(strings.dataPreviewHint, style: _captionStyle),
          const SizedBox(height: 12),
          if (_available.contains(GameDataField.cover))
            row(
              GameDataField.cover,
              strings.gameCover,
              _RemovableTile(
                width: 72,
                height: 96,
                image: Image.file(File(widget.pick.path), fit: BoxFit.cover),
              ),
            ),
          if (_available.contains(GameDataField.description))
            row(
              GameDataField.description,
              strings.gameDescription,
              Text(d!.description, maxLines: 4, overflow: TextOverflow.ellipsis, style: _bodyStyle),
            ),
          if (_available.contains(GameDataField.tags))
            row(GameDataField.tags, strings.gameTags, Text(d!.tags.join(', '), style: _bodyStyle)),
          if (_available.contains(GameDataField.trailer))
            row(
              GameDataField.trailer,
              strings.gameTrailer,
              Text(d!.trailerUrl, maxLines: 1, overflow: TextOverflow.ellipsis, style: _bodyStyle),
            ),
          if (_available.contains(GameDataField.images))
            row(
              GameDataField.images,
              strings.gameImages,
              SizedBox(
                height: 54,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final url in d!.screenshots)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            url,
                            width: 96,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox(width: 96),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (_available.isEmpty) Text(strings.dataNothingFound, style: _bodyStyle),
        ],
      ),
    );
  }
}
