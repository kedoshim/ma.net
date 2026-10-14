import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';

/// What the host's join rule asks of this phone before it gets a seat.
enum AccessGateStage { password, pending, denied }

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

/// Full-screen card shown while the room asks for a password, waits for
/// the host, or turned the phone away.
class AccessGateView extends StatefulWidget {
  const AccessGateView({
    super.key,
    required this.stage,
    required this.onSubmitPassword,
    required this.onRetry,
    this.reason,
    this.attemptsLeft,
  });

  final AccessGateStage stage;
  final String? reason;
  final int? attemptsLeft;
  final ValueChanged<String> onSubmitPassword;
  final VoidCallback onRetry;

  @override
  State<AccessGateView> createState() => _AccessGateViewState();
}

class _AccessGateViewState extends State<AccessGateView> {
  final TextEditingController _password = TextEditingController();
  bool _visible = false;

  @override
  void didUpdateWidget(AccessGateView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.attemptsLeft != oldWidget.attemptsLeft) _password.clear();
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _password.text.trim();
    if (value.isNotEmpty) widget.onSubmitPassword(value);
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
                  color: AppColors.screenBackground,
                  borderRadius: BorderRadius.circular(18),
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
