import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';

/// Small banner over the pad while the phone knocks on the host again.
/// It never blocks the controls and goes away on its own once connected;
/// after a while it adds a hint about what to check.
class ReconnectingBanner extends StatefulWidget {
  const ReconnectingBanner({
    super.key,
    required this.since,
    required this.onTapRetry,
  });

  final DateTime since;
  final VoidCallback onTapRetry;

  static const Duration hintAfter = Duration(seconds: 20);

  @override
  State<ReconnectingBanner> createState() => _ReconnectingBannerState();
}

class _ReconnectingBannerState extends State<ReconnectingBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob;
  Timer? _hintTimer;
  bool _showHint = false;

  @override
  void initState() {
    super.initState();
    _bob = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _armHint();
  }

  @override
  void didUpdateWidget(ReconnectingBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.since != widget.since) _armHint();
  }

  void _armHint() {
    _hintTimer?.cancel();
    final left = ReconnectingBanner.hintAfter - DateTime.now().difference(widget.since);
    _showHint = left <= Duration.zero;
    if (!_showHint) {
      _hintTimer = Timer(left, () {
        if (mounted) setState(() => _showHint = true);
      });
    }
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, alignment: Alignment.topCenter, child: child),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTapRetry,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.textPrimary,
              width: AppColors.borderThickness,
            ),
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            alignment: Alignment.topCenter,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _bob,
                  builder: (context, child) {
                    final t = Curves.easeInOut.transform(_bob.value);
                    return Transform.translate(
                      offset: Offset(0, -3 * t),
                      child: Transform.rotate(
                        angle: (t - 0.5) * 0.2 * math.pi / 2,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.highlightColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.textPrimary,
                        width: AppColors.borderThickness,
                      ),
                    ),
                    child: Text(
                      _showHint ? 'o_O' : 'o_o',
                      style: const TextStyle(
                        fontFamily: 'monomaniac',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.disconnect.reconnecting,
                        style: const TextStyle(
                          fontFamily: 'momo',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (_showHint) ...[
                        const SizedBox(height: 2),
                        Text(
                          l10n.disconnect.stillTrying,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            color: AppColors.textPrimary.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
