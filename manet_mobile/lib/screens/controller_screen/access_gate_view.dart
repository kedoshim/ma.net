import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/player_face.dart';
import '../../theme/app_colors.dart';
import '../../widgets/player_face_indicator.dart';

/// What the host's join rule asks of this phone before it gets a seat.
enum AccessGateStage { name, password, pending, denied }

const TextStyle _titleStyle = TextStyle(
  fontFamily: 'momo',
  fontWeight: FontWeight.bold,
  fontSize: 18,
  color: AppColors.textPrimary,
);
const TextStyle _bodyStyle = TextStyle(
  fontFamily: 'momo',
  fontSize: 14,
  color: AppColors.textPrimary,
);

/// Full-screen card shown while the room asks for a name or a password,
/// waits for the host, or turned the phone away.
class AccessGateView extends StatefulWidget {
  const AccessGateView({
    super.key,
    required this.stage,
    required this.onSubmitPassword,
    required this.onSubmitName,
    required this.onRetry,
    this.reason,
    this.attemptsLeft,
    this.initialName,
    this.initialFace,
  });

  final AccessGateStage stage;
  final String? reason;
  final int? attemptsLeft;

  /// What the phone already has, so a retry starts from the last attempt.
  final String? initialName;
  final PlayerFaceData? initialFace;
  final ValueChanged<String> onSubmitPassword;
  final void Function(String name, PlayerFaceData face) onSubmitName;
  final VoidCallback onRetry;

  @override
  State<AccessGateView> createState() => _AccessGateViewState();
}

class _AccessGateViewState extends State<AccessGateView> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _faceText = TextEditingController();
  late PlayerFaceData _face;
  bool _visible = false;
  bool _nameMissing = false;

  @override
  void initState() {
    super.initState();
    _face = widget.initialFace ?? PlayerFaceData.random();
    _name.text = widget.initialName ?? '';
    _faceText.text = _face.faceText;
  }

  @override
  void didUpdateWidget(AccessGateView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.attemptsLeft != oldWidget.attemptsLeft) _password.clear();
  }

  @override
  void dispose() {
    _password.dispose();
    _name.dispose();
    _faceText.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _password.text.trim();
    if (value.isNotEmpty) widget.onSubmitPassword(value);
  }

  void _submitName() {
    final value = _name.text.trim();
    if (value.isEmpty) {
      setState(() => _nameMissing = true);
      return;
    }
    widget.onSubmitName(value, _face);
  }

  void _setFace(PlayerFaceData face) => setState(() => _face = face);

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: _bodyStyle.copyWith(fontWeight: FontWeight.bold)),
  );

  OutlineInputBorder get _fieldBorder => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: AppColors.textPrimary, width: 2),
  );

  List<Widget> _nameStage(BuildContext context) {
    final strings = context.l10n.access;
    final presets = context.l10n.presets;
    return [
      Text(strings.nameTitle, style: _titleStyle, textAlign: TextAlign.center),
      const SizedBox(height: 6),
      Text(strings.nameHint, style: _bodyStyle, textAlign: TextAlign.center),
      const SizedBox(height: 16),
      PlayerFaceIndicator(
        face: _face,
        size: 96,
        roundedSquare: true,
        borderColor: AppColors.textPrimary,
      ),
      const SizedBox(height: 14),
      _sectionLabel(presets.face),
      SizedBox(
        width: 120,
        child: TextField(
          controller: _faceText,
          maxLength: 3,
          textAlign: TextAlign.center,
          onChanged: (text) => _setFace(_face.copyWith(faceText: text, clearPreset: true)),
          style: _bodyStyle.copyWith(fontFamily: 'monomaniac', fontSize: 22),
          decoration: InputDecoration(
            isDense: true,
            counterText: '',
            filled: true,
            fillColor: Colors.white,
            border: _fieldBorder,
            enabledBorder: _fieldBorder,
            focusedBorder: _fieldBorder,
          ),
        ),
      ),
      const SizedBox(height: 12),
      _sectionLabel(presets.rotation),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          for (final rotation in PlayerFaceRotation.values)
            GestureDetector(
              onTap: () => _setFace(_face.copyWith(rotation: rotation, clearPreset: true)),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: rotation == _face.rotation ? AppColors.textPrimary : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: PlayerFaceIndicator(face: _face.copyWith(rotation: rotation), size: 36),
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),
      _sectionLabel(presets.colors),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          for (final color in playerFacePalette)
            GestureDetector(
              onTap: () => _setFace(_face.copyWith(color: color, clearPreset: true)),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.textPrimary,
                    width: color.toARGB32() == _face.color.toARGB32() ? 3.5 : 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 18),
      TextField(
        controller: _name,
        maxLength: 15,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.go,
        onChanged: (_) {
          if (_nameMissing) setState(() => _nameMissing = false);
        },
        onSubmitted: (_) => _submitName(),
        style: _bodyStyle,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          labelText: strings.nameField,
          labelStyle: _bodyStyle,
          errorText: _nameMissing ? strings.nameRequired : null,
          errorStyle: _bodyStyle.copyWith(fontSize: 12, color: const Color(0xFFEF4444)),
          counterStyle: _bodyStyle.copyWith(fontSize: 11),
          border: _fieldBorder,
          enabledBorder: _fieldBorder,
          focusedBorder: _fieldBorder,
        ),
      ),
      const SizedBox(height: 8),
      _button(strings.requestToJoin, _submitName),
    ];
  }

  Widget _button(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.highlightColor,
          foregroundColor: AppColors.textPrimary,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.textPrimary, width: 2),
          ),
        ),
        onPressed: onPressed,
        child: Text(label, style: _titleStyle.copyWith(fontSize: 16)),
      ),
    );
  }

  List<Widget> _passwordStage(BuildContext context) {
    final strings = context.l10n.access;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.textPrimary, width: 2),
    );
    return [
      const Icon(Icons.lock_rounded, size: 48, color: AppColors.textPrimary),
      const SizedBox(height: 12),
      Text(strings.passwordTitle, style: _titleStyle, textAlign: TextAlign.center),
      const SizedBox(height: 6),
      Text(strings.passwordHint, style: _bodyStyle, textAlign: TextAlign.center),
      const SizedBox(height: 18),
      TextField(
        controller: _password,
        autofocus: true,
        obscureText: !_visible,
        textInputAction: TextInputAction.go,
        onSubmitted: (_) => _submit(),
        style: _bodyStyle,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          labelText: strings.passwordField,
          labelStyle: _bodyStyle,
          errorText: widget.attemptsLeft == null
              ? null
              : strings.wrongPassword(widget.attemptsLeft!),
          errorStyle: _bodyStyle.copyWith(fontSize: 12, color: const Color(0xFFEF4444)),
          suffixIcon: IconButton(
            icon: Icon(
              _visible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: AppColors.textPrimary,
            ),
            onPressed: () => setState(() => _visible = !_visible),
          ),
          border: border,
          enabledBorder: border,
          focusedBorder: border,
        ),
      ),
      const SizedBox(height: 14),
      _button(strings.enter, _submit),
    ];
  }

  List<Widget> _pendingStage(BuildContext context) {
    final strings = context.l10n.access;
    return [
      const SizedBox(
        width: 44,
        height: 44,
        child: CircularProgressIndicator(strokeWidth: 4, color: AppColors.textPrimary),
      ),
      const SizedBox(height: 18),
      Text(strings.pendingTitle, style: _titleStyle, textAlign: TextAlign.center),
      const SizedBox(height: 6),
      Text(strings.pendingBody, style: _bodyStyle, textAlign: TextAlign.center),
    ];
  }

  List<Widget> _deniedStage(BuildContext context) {
    final strings = context.l10n.access;
    return [
      Icon(
        widget.reason == 'banned' ? Icons.block_rounded : Icons.door_front_door_rounded,
        size: 48,
        color: AppColors.textPrimary,
      ),
      const SizedBox(height: 12),
      Text(strings.deniedTitle(widget.reason), style: _titleStyle, textAlign: TextAlign.center),
      const SizedBox(height: 6),
      Text(strings.deniedBody(widget.reason), style: _bodyStyle, textAlign: TextAlign.center),
      if (widget.reason != 'banned') ...[
        const SizedBox(height: 18),
        _button(strings.tryAgain, widget.onRetry),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final children = switch (widget.stage) {
      AccessGateStage.name => _nameStage(context),
      AccessGateStage.password => _passwordStage(context),
      AccessGateStage.pending => _pendingStage(context),
      AccessGateStage.denied => _deniedStage(context),
    };
    return Positioned.fill(
      child: Material(
        color: AppColors.screenBackground,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 360),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.textPrimary,
                    width: AppColors.borderThickness,
                  ),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: children),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
