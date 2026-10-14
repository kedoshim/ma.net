import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/physical_gamepad/physical_gamepad_relay.dart';
import '../theme/app_colors.dart';

const TextStyle _bold = TextStyle(
  fontFamily: 'momo',
  fontWeight: FontWeight.bold,
  fontSize: 15,
  color: AppColors.textPrimary,
);

const TextStyle _body = TextStyle(fontFamily: 'momo', fontSize: 14, height: 1.3, color: AppColors.textPrimary);

const TextStyle _faint = TextStyle(fontFamily: 'momo', fontSize: 13, color: Color(0x99222222));

/// "A controller is connected here, play with it?" Pops true / false. The
/// pad itself can answer: A uses it, B declines.
class PhysicalPadOfferDialog extends StatefulWidget {
  final PadInfo pad;
  final bool sameMachine;

  const PhysicalPadOfferDialog({super.key, required this.pad, this.sameMachine = false});

  @override
  State<PhysicalPadOfferDialog> createState() => _PhysicalPadOfferDialogState();
}

class _PhysicalPadOfferDialogState extends State<PhysicalPadOfferDialog> {
  StreamSubscription<String>? _presses;
  bool _answered = false;

  @override
  void initState() {
    super.initState();
    final relay = PhysicalGamepadRelay.instance;
    relay.holdCapture(true);
    _presses = relay.presses.listen((button) {
      if (button == 'A') _answer(true);
      if (button == 'B') _answer(false);
    });
  }

  void _answer(bool use) {
    if (_answered || !mounted) return;
    _answered = true;
    Navigator.of(context).pop(use);
  }

  @override
  void dispose() {
    _presses?.cancel();
    PhysicalGamepadRelay.instance.holdCapture(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.relay;
    return Dialog(
      backgroundColor: AppColors.lightColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.textPrimary, width: AppColors.borderThickness),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sports_esports_rounded, size: 44, color: AppColors.textPrimary),
              const SizedBox(height: 8),
              Text(strings.title, style: _bold.copyWith(fontSize: 18)),
              const SizedBox(height: 8),
              Text(strings.offer(widget.pad.name), textAlign: TextAlign.center, style: _body),
              if (widget.sameMachine) ...[
                const SizedBox(height: 8),
                Text(strings.sameMachineWarning, textAlign: TextAlign.center, style: _faint),
              ],
              const SizedBox(height: 8),
              Text(strings.padAnswerHint, textAlign: TextAlign.center, style: _faint),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _PadButton(label: strings.notNow, onTap: () => _answer(false)),
                  const SizedBox(width: 12),
                  _PadButton(label: strings.use, primary: true, onTap: () => _answer(true)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Picks one of several connected pads (manual start of relay mode).
class PhysicalPadPickerDialog extends StatelessWidget {
  final List<PadInfo> pads;

  const PhysicalPadPickerDialog({super.key, required this.pads});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.lightColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.textPrimary, width: AppColors.borderThickness),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.l10n.relay.pickTitle, style: _bold.copyWith(fontSize: 18)),
              const SizedBox(height: 12),
              for (final pad in pads)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PadButton(
                    label: pad.name,
                    icon: Icons.sports_esports_rounded,
                    wide: true,
                    onTap: () => Navigator.of(context).pop(pad),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small pill at the bottom of the controller: which physical pad is being
/// relayed (tap to stop), or an offer to use one that is connected.
class PhysicalPadChip extends StatelessWidget {
  final VoidCallback onUse;

  const PhysicalPadChip({super.key, required this.onUse});

  @override
  Widget build(BuildContext context) {
    final relay = PhysicalGamepadRelay.instance;
    return ListenableBuilder(
      listenable: relay,
      builder: (context, _) {
        final strings = context.l10n.relay;
        final activePad = relay.activePad;
        if (activePad == null && relay.pads.isEmpty) return const SizedBox.shrink();

        final label = activePad != null ? strings.active(activePad.name) : strings.usePad;
        return GestureDetector(
          onTap: activePad != null ? relay.disable : onUse,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: activePad != null ? AppColors.highlightColor : AppColors.lightColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.textPrimary, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sports_esports_rounded, size: 18, color: AppColors.textPrimary),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(label, overflow: TextOverflow.ellipsis, style: _bold.copyWith(fontSize: 13)),
                ),
                if (activePad != null) ...[
                  const SizedBox(width: 8),
                  Text(strings.stop, style: _bold.copyWith(fontSize: 13, decoration: TextDecoration.underline)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PadButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool wide;
  final IconData? icon;

  const _PadButton({
    required this.label,
    required this.onTap,
    this.primary = false,
    this.wide = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: wide ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: primary ? AppColors.highlightColor : AppColors.lightColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.textPrimary, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: AppColors.textPrimary),
              const SizedBox(width: 8),
            ],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: _bold)),
          ],
        ),
      ),
    );
  }
}
