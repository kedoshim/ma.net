import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';

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
    return AlertDialog(
      backgroundColor: AppColors.screenBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.textPrimary, width: 2),
      ),
      title: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.redAccent,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: AppTheme.titleSmall.copyWith(
                fontFamily: 'momo',
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
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
                      logs!.isEmpty ? 'Nenhum log.' : logs!,
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
        ),
      ),
      actions: [
        if (additionalActions != null) ...additionalActions!,
        if (onRetry != null)
          ElevatedButton.icon(
            icon: const Icon(Icons.replay_rounded, size: 18),
            label: const Text(
              'Tentar novamente',
              style: TextStyle(fontFamily: 'momo'),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.textPrimary,
              foregroundColor: AppColors.screenBackground,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              onRetry?.call();
            },
          ),
        if (logs != null)
          TextButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text(
              'Copiar Logs',
              style: TextStyle(fontFamily: 'momo'),
            ),
            style: TextButton.styleFrom(foregroundColor: AppColors.textPrimary),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: logs ?? ''));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Logs copiados para a área de transferência!'),
                ),
              );
            },
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Fechar',
            style: TextStyle(fontFamily: 'momo', color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}
