import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../services/host_api_service.dart';
import '../services/online_service.dart';
import '../services/sound_effect_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/app_preferences.dart';
import 'juicy_widgets.dart';

const _onlineGreen = Color(0xFF10B981);
const _busyAmber = Color(0xFFF59E0B);
const _errorRed = Color(0xFFEF4444);

Color _stateColor(OnlineState state) => switch (state) {
  OnlineState.online => _onlineGreen,
  OnlineState.starting || OnlineState.verifying => _busyAmber,
  OnlineState.error => _errorRed,
  OnlineState.off => AppColors.textPrimary.withValues(alpha: 0.35),
};

/// Toolbar button for "Play online"; its color follows the tunnel state.
class OnlinePlayButton extends StatelessWidget {
  final HostApiService api;

  const OnlinePlayButton({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    final service = OnlineService.of(api);
    return ValueListenableBuilder<OnlineStatus>(
      valueListenable: service,
      builder: (context, status, _) {
        final active = status.state != OnlineState.off;
        return Tooltip(
          message: context.l10n.online.buttonTooltip,
          child: JuicyIconButton(
            size: 48,
            borderRadius: 14,
            backgroundColor: active ? _stateColor(status.state) : null,
            iconColor: active ? Colors.white : null,
            icon: const Icon(Icons.public_rounded),
            onTap: () {
              SoundEffectService.instance.playOptionsButton();
              OnlinePlayDialog.show(context, api);
            },
          ),
        );
      },
    );
  }
}

class OnlinePlayDialog extends StatelessWidget {
  final OnlineService service;

  const OnlinePlayDialog({super.key, required this.service});

  static Future<void> show(BuildContext context, HostApiService api) {
    return showDialog(
      context: context,
      builder: (_) => OnlinePlayDialog(service: OnlineService.of(api)),
    );
  }

  Future<void> _goOnline(BuildContext context) async {
    if (!await AppPreferences.onlineWarningSeen()) {
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final strings = dialogContext.l10n.online;
          return JuicyDialog(
            title: strings.warningTitle,
            maxWidth: 460,
            actions: [
              JuicyButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(dialogContext.l10n.common.cancel),
              ),
              JuicyButton(
                backgroundColor: AppColors.highlightColor,
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(strings.warningConfirm),
              ),
            ],
            child: Text(strings.warningBody, style: AppTheme.bodyMedium),
          );
        },
      );
      if (confirmed != true) return;
      await AppPreferences.setOnlineWarningSeen();
    }
    await service.start();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.online;
    return ValueListenableBuilder<OnlineStatus>(
      valueListenable: service,
      builder: (context, status, _) {
        return JuicyDialog(
          title: strings.title,
          maxWidth: 520,
          actions: [
            if (status.state == OnlineState.off)
              JuicyButton(
                backgroundColor: AppColors.highlightColor,
                onPressed: () => _goOnline(context),
                child: Text(strings.start),
              ),
            if (status.state == OnlineState.error)
              JuicyButton(
                backgroundColor: AppColors.highlightColor,
                onPressed: service.start,
                child: Text(strings.retry),
              ),
            if (status.state != OnlineState.off)
              JuicyButton(onPressed: service.stop, child: Text(strings.stop)),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(strings.subtitle, style: AppTheme.bodyMedium),
              const SizedBox(height: 16),
              _StatusRow(status: status),
              if (status.state == OnlineState.error) ...[
                const SizedBox(height: 8),
                Text(
                  strings.errorDetail(status.error),
                  style: AppTheme.bodySmall,
                ),
              ],
              if (status.isOnline) ...[
                const SizedBox(height: 16),
                _OnlineQr(service: service, url: status.url!),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StatusRow extends StatelessWidget {
  final OnlineStatus status;

  const _StatusRow({required this.status});

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
    return Row(
      children: [
        if (status.isBusy)
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: _busyAmber),
          )
        else
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: _stateColor(status.state),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.textPrimary, width: 2),
            ),
          ),
        const SizedBox(width: 10),
        Text(
          label,
          style: AppTheme.titleSmall.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

/// Big, high-contrast QR: it has to survive a compressed stream.
class _OnlineQr extends StatelessWidget {
  final OnlineService service;
  final String url;

  const _OnlineQr({required this.service, required this.url});

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.online;
    return Column(
      children: [
        Container(
          width: 320,
          height: 320,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.textPrimary, width: 3),
          ),
          child: Image.network(
            service.qrUrl,
            key: ValueKey(url),
            fit: BoxFit.contain,
            filterQuality: FilterQuality.none,
          ),
        ),
        const SizedBox(height: 10),
        Text(strings.scanHint, style: AppTheme.bodySmall, textAlign: TextAlign.center),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SelectableText(
                url.replaceFirst('https://', ''),
                style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            JuicyButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: url));
                if (!context.mounted) return;
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  SnackBar(content: Text(strings.linkCopied)),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.copy_rounded, size: 18),
                  const SizedBox(width: 6),
                  Text(strings.copyLink),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
