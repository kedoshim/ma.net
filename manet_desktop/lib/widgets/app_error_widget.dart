import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import 'juicy_widgets.dart';
import '../l10n/app_localizations.dart';

class AppErrorWidget extends StatelessWidget {
  final String title;
  final String message;
  final String? logs;
  final VoidCallback? onRetry;
  final List<Widget>? additionalActions;

  const AppErrorWidget({
    super.key,
    required this.title,
    required this.message,
    this.logs,
    this.onRetry,
    this.additionalActions,
  });

  @override
  Widget build(BuildContext context) {
    return JuicyDialog(
      title: title,
      maxWidth: 560,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: AppTheme.bodyMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          if (logs != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              height: 160,
              child: SingleChildScrollView(
                child: Text(
                  logs!.isEmpty ? context.l10n.error.noLogs : logs!,
                  style: const TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 12,
                    color: Colors.greenAccent,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (additionalActions != null) ...additionalActions!,
        if (onRetry != null)
          JuicyButton(
            onPressed: () {
              Navigator.of(context).pop();
              onRetry?.call();
            },
            backgroundColor: AppColors.textPrimary,
            borderRadius: 12,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.replay_rounded, size: 18, color: AppColors.screenBackground),
                const SizedBox(width: 8),
                Text(
                  context.l10n.error.retry,
                  style: TextStyle(
                    fontFamily: 'momo',
                    color: AppColors.screenBackground,
                  ),
                ),
              ],
            ),
          ),
        if (logs != null)
          JuicyButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: logs ?? ''));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.l10n.error.logsCopied),
                ),
              );
            },
            backgroundColor: Colors.transparent,
            borderThickness: 0.0,
            borderRadius: 12,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.copy_rounded, size: 18, color: AppColors.textPrimary),
                const SizedBox(width: 8),
                Text(
                  context.l10n.error.copyLogs,
                  style: const TextStyle(
                    fontFamily: 'momo',
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        JuicyButton(
          onPressed: () => Navigator.of(context).pop(),
          backgroundColor: Colors.transparent,
          borderThickness: 0.0,
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            context.l10n.common.close,
            style: const TextStyle(fontFamily: 'momo', color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}
