import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/access_service.dart';
import '../services/sound_effect_service.dart';
import '../theme/app_colors.dart';
import 'player_face_indicator.dart';
import 'juicy_widgets.dart';

const TextStyle _nameStyle = TextStyle(
  fontFamily: 'momo',
  fontWeight: FontWeight.bold,
  fontSize: 15,
  color: AppColors.textPrimary,
);
const TextStyle _buttonStyle = TextStyle(
  fontFamily: 'momo',
  fontWeight: FontWeight.bold,
  fontSize: 13,
  color: AppColors.textPrimary,
);

/// Phones waiting for the host's answer ("I approve" rule), stacked in a
/// corner over the lobby and the in-game overlay.
class JoinRequestsCard extends StatelessWidget {
  final AccessService access;

  const JoinRequestsCard({super.key, required this.access});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AccessStatus>(
      valueListenable: access,
      builder: (context, status, _) {
        return Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final request in status.pending.take(4))
                Padding(
                  key: ValueKey(request.deviceId),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RequestTile(request: request, access: access),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _RequestTile extends StatelessWidget {
  final JoinRequest request;
  final AccessService access;

  const _RequestTile({required this.request, required this.access});

  void _answer({required bool accept, bool ban = false}) {
    SoundEffectService.instance.playOptionsButton();
    access.answer(request.deviceId, accept: accept, ban: ban);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.access;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.elasticOut,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.screenBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.textPrimary, width: 3),
          boxShadow: const [
            BoxShadow(color: Colors.black26, offset: Offset(0, 6), blurRadius: 14),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                // Drawn like in the lobby (dark face text, its rotation).
                PlayerFaceIndicator(face: request.face, size: 44),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.wantsToJoin(request.name),
                        style: _nameStyle,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Icon(
                            request.online ? Icons.public_rounded : Icons.wifi_rounded,
                            size: 14,
                            color: AppColors.textPrimary.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            request.online ? strings.viaInternet : strings.viaLan,
                            style: _buttonStyle.copyWith(
                              fontWeight: FontWeight.normal,
                              fontSize: 12,
                              color: AppColors.textPrimary.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Tooltip(
                  message: strings.ban,
                  child: JuicyIconButton(
                    size: 38,
                    borderRadius: 10,
                    icon: const Icon(Icons.block_rounded, size: 18),
                    onTap: () => _answer(accept: false, ban: true),
                  ),
                ),
                const Spacer(),
                JuicyButton(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  onPressed: () => _answer(accept: false),
                  child: Text(strings.reject, style: _buttonStyle),
                ),
                const SizedBox(width: 8),
                JuicyButton(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  backgroundColor: AppColors.highlightColor,
                  onPressed: () => _answer(accept: true),
                  child: Text(strings.accept, style: _buttonStyle),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
