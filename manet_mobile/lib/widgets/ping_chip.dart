import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';

/// The face tells how the link feels for playing; the number is for the
/// curious. 200 ms matches where the pad starts suggesting a better network.
String pingFace(int? ms) {
  if (ms == null) return '...';
  if (ms < 60) return ':D';
  if (ms < 120) return ':)';
  if (ms < 200) return ':|';
  return ':(';
}

/// Live round trip to the PC, refreshed with every pong while it is shown.
class PingChip extends StatelessWidget {
  const PingChip({super.key, required this.ping});

  final ValueListenable<int?> ping;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int?>(
      valueListenable: ping,
      builder: (context, ms, _) {
        final face = pingFace(ms);
        return Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.textPrimary, width: 2.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pops each time the face changes, so a worse link is noticed.
              TweenAnimationBuilder<double>(
                key: ValueKey(face),
                tween: Tween(begin: 0.6, end: 1.0),
                duration: const Duration(milliseconds: 450),
                curve: Curves.elasticOut,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.highlightColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.textPrimary, width: 2),
                  ),
                  child: Text(
                    face,
                    style: const TextStyle(
                      fontFamily: 'monomaniac',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                ms == null
                    ? context.l10n.options.pingMeasuring
                    : context.l10n.options.ping(ms),
                style: const TextStyle(
                  fontFamily: 'momo',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
