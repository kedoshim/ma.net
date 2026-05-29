import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';

class ServerAlert {
  final String id;
  final String message;
  final bool isError;
  bool isSeen;

  ServerAlert({
    required this.message,
    this.isError = false,
    this.isSeen = false,
  }) : id = '${DateTime.now().microsecondsSinceEpoch}_${message.hashCode}';
}

class AlertIcon extends StatelessWidget {
  final List<ServerAlert> alerts;
  final VoidCallback onTap;

  const AlertIcon({super.key, required this.alerts, required this.onTap});

  @override
  Widget build(BuildContext context) {
    bool hasUnseenError = alerts.any((a) => !a.isSeen && a.isError);
    bool hasUnseenWarning = alerts.any((a) => !a.isSeen && !a.isError);

    Color iconColor;
    if (hasUnseenError) {
      iconColor = Colors.red;
    } else if (hasUnseenWarning) {
      iconColor = Colors.amber;
    } else {
      iconColor = AppColors.textPrimary.withValues(alpha: 0.4);
    }

    return IconButton(
      onPressed: onTap,
      icon: Icon(
        hasUnseenError
            ? Icons.error_outline_rounded
            : Icons.warning_amber_rounded,
        color: iconColor,
      ),
      tooltip: 'Avisos e Erros',
    );
  }
}

class ServerAlertsDialog extends StatefulWidget {
  final List<ServerAlert> alerts;
  final Function(String) onDismiss;

  const ServerAlertsDialog({
    super.key,
    required this.alerts,
    required this.onDismiss,
  });

  @override
  State<ServerAlertsDialog> createState() => _ServerAlertsDialogState();
}

class _ServerAlertsDialogState extends State<ServerAlertsDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.screenBackground,
      title: Text(
        'Avisos e Erros',
        style: AppTheme.titleSmall.copyWith(color: AppColors.textPrimary),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: widget.alerts.isEmpty
            ? Center(
                child: Text(
                  'Nenhum alerta.',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              )
            : ListView.builder(
                itemCount: widget.alerts.length,
                itemBuilder: (context, index) {
                  final alert = widget.alerts[index];
                  return Card(
                    color: AppColors.screenBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: alert.isError ? Colors.red : Colors.amber,
                        width: 1.5,
                      ),
                    ),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        alert.isError
                            ? Icons.error_outline
                            : Icons.warning_amber_rounded,
                        color: alert.isError ? Colors.red : Colors.amber,
                      ),
                      title: SelectableText(
                        alert.message,
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.textPrimary,
                        ),
                        onPressed: () {
                          widget.onDismiss(alert.id);
                          setState(() {});
                        },
                      ),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}
