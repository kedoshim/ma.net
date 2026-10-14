import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/access_service.dart';
import '../services/session_controller.dart';
import '../theme/app_colors.dart';

const TextStyle _itemStyle = TextStyle(
  fontFamily: 'momo',
  fontWeight: FontWeight.bold,
  fontSize: 14,
  color: AppColors.textPrimary,
);

/// Right-click on a player: kick, or kick and ban for the rest of the
/// session. Needs a [SessionController] above it.
class KickMenuRegion extends StatelessWidget {
  final String deviceId;
  final String name;
  final Widget child;

  const KickMenuRegion({
    super.key,
    required this.deviceId,
    required this.name,
    required this.child,
  });

  Future<void> _open(BuildContext context, Offset position) async {
    final access = AccessService.of(context.read<SessionController>().api);
    final strings = context.l10n.access;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final choice = await showMenu<bool>(
      context: context,
      color: AppColors.screenBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.textPrimary, width: 2.5),
      ),
      position: RelativeRect.fromRect(
        position & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem<bool>(
          enabled: false,
          height: 32,
          child: Text(
            name,
            style: _itemStyle.copyWith(color: AppColors.textPrimary.withValues(alpha: 0.6)),
          ),
        ),
        PopupMenuItem<bool>(
          value: false,
          child: Row(
            children: [
              const Icon(Icons.logout_rounded, size: 18, color: AppColors.textPrimary),
              const SizedBox(width: 10),
              Text(strings.kick, style: _itemStyle),
            ],
          ),
        ),
        PopupMenuItem<bool>(
          value: true,
          child: Row(
            children: [
              const Icon(Icons.block_rounded, size: 18, color: Color(0xFFEF4444)),
              const SizedBox(width: 10),
              Text(strings.kickAndBan, style: _itemStyle),
            ],
          ),
        ),
      ],
    );
    if (choice != null) await access.kick(deviceId, ban: choice);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapDown: (details) => _open(context, details.globalPosition),
      child: child,
    );
  }
}
