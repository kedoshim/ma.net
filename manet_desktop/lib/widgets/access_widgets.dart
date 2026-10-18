import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../services/access_service.dart';
import '../services/online_service.dart';
import '../services/sound_effect_service.dart';
import '../theme/app_colors.dart';
import 'juicy_widgets.dart';

const onlineGreen = Color(0xFF10B981);
const busyAmber = Color(0xFFF59E0B);
const errorRed = Color(0xFFEF4444);

const TextStyle accessTitleStyle = TextStyle(
  fontFamily: 'momo',
  fontWeight: FontWeight.bold,
  fontSize: 16,
  color: AppColors.textPrimary,
);
const TextStyle accessLabelStyle = TextStyle(
  fontFamily: 'momo',
  fontWeight: FontWeight.bold,
  fontSize: 14,
  color: AppColors.textPrimary,
);
const TextStyle accessBodyStyle = TextStyle(
  fontFamily: 'momo',
  fontSize: 14,
  color: AppColors.textPrimary,
);
TextStyle get accessHintStyle => TextStyle(
  fontFamily: 'momo',
  fontSize: 12,
  color: AppColors.textPrimary.withValues(alpha: 0.7),
);

Color onlineStateColor(OnlineState state) => switch (state) {
  OnlineState.online => onlineGreen,
  OnlineState.starting || OnlineState.verifying => busyAmber,
  OnlineState.error => errorRed,
  OnlineState.off => AppColors.textPrimary.withValues(alpha: 0.35),
};

void showNetworkToast(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: accessLabelStyle.copyWith(color: Colors.white),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Tunnel state, its public link and a copy button.
class OnlineStatusSection extends StatelessWidget {
  final OnlineStatus status;

  const OnlineStatusSection({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.online;
    final label = switch (status.state) {
      OnlineState.off => strings.stateOff,
      OnlineState.starting => strings.stateStarting,
      OnlineState.verifying => strings.stateVerifying,
      OnlineState.online => strings.stateOnline,
      OnlineState.error => strings.stateError,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (status.isBusy)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: busyAmber,
                ),
              )
            else
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: onlineStateColor(status.state),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.textPrimary, width: 2),
                ),
              ),
            const SizedBox(width: 10),
            Text(label, style: accessTitleStyle),
          ],
        ),
        if (status.state == OnlineState.error) ...[
          const SizedBox(height: 6),
          Text(strings.errorDetail(status.error), style: accessHintStyle),
        ],
        if (status.isOnline) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  status.url!.replaceFirst('https://', ''),
                  style: accessBodyStyle.copyWith(fontFamily: 'monomaniac'),
                ),
              ),
              const SizedBox(width: 8),
              JuicyButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: status.url!));
                  if (context.mounted)
                    showNetworkToast(context, strings.linkCopied);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.copy_rounded,
                      size: 16,
                      color: AppColors.textPrimary,
                    ),
                    const SizedBox(width: 6),
                    Text(strings.copyLink, style: accessLabelStyle),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Lifts every ban of this session; hidden when nobody is banned.
class UnbanAllButton extends StatelessWidget {
  final AccessService access;

  const UnbanAllButton({super.key, required this.access});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AccessStatus>(
      valueListenable: access,
      builder: (context, status, _) {
        if (status.bannedCount == 0) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: JuicyButton(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              onPressed: access.unbanAll,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.undo_rounded,
                    size: 16,
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    context.l10n.access.unbanAll(status.bannedCount),
                    style: accessLabelStyle,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The three join rules as cards (also used for the local network rule).
class AccessModePicker extends StatelessWidget {
  final AccessMode value;
  final ValueChanged<AccessMode> onChanged;

  const AccessModePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.access;
    final options = [
      (
        AccessMode.open,
        Icons.lock_open_rounded,
        strings.modeOpen,
        strings.modeOpenHint,
      ),
      (
        AccessMode.password,
        Icons.password_rounded,
        strings.modePassword,
        strings.modePasswordHint,
      ),
      (
        AccessMode.approval,
        Icons.how_to_reg_rounded,
        strings.modeApproval,
        strings.modeApprovalHint,
      ),
    ];
    return Column(
      children: [
        for (final (mode, icon, label, hint) in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: JuicyCard(
              isSelected: value == mode,
              selectedColor: AppColors.highlightColor,
              backgroundColor: AppColors.lightColor,
              borderRadius: 12,
              borderThickness: 3.0,
              onTap: () {
                SoundEffectService.instance.playThemeSelect();
                onChanged(mode);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(icon, color: AppColors.textPrimary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: accessLabelStyle),
                          Text(hint, style: accessHintStyle),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class RoomPasswordField extends StatelessWidget {
  final TextEditingController controller;
  final bool visible;
  final String? error;
  final VoidCallback onToggleVisible;
  final ValueChanged<String> onChanged;

  const RoomPasswordField({
    super.key,
    required this.controller,
    required this.visible,
    required this.error,
    required this.onToggleVisible,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.textPrimary, width: 2),
    );
    return TextField(
      controller: controller,
      obscureText: !visible,
      onChanged: onChanged,
      maxLength: 64,
      style: accessBodyStyle,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.lightColor,
        labelText: context.l10n.access.passwordLabel,
        labelStyle: accessHintStyle,
        errorText: error,
        errorStyle: accessHintStyle.copyWith(color: errorRed),
        counterText: '',
        suffixIcon: IconButton(
          icon: Icon(
            visible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: onToggleVisible,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border,
      ),
    );
  }
}
