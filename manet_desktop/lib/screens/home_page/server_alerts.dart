import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/juicy_widgets.dart';
import '../../l10n/app_localizations.dart';

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
    Color? backgroundColor;
    if (hasUnseenError) {
      iconColor = Colors.red;
      backgroundColor = Colors.red.withValues(alpha: 0.1);
    } else if (hasUnseenWarning) {
      iconColor = Colors.amber;
      backgroundColor = Colors.amber.withValues(alpha: 0.1);
    } else {
      iconColor = AppColors.textPrimary.withValues(alpha: 0.4);
      backgroundColor = Colors.transparent;
    }

    return Tooltip(
      message: context.l10n.alerts.tooltip,
      child: JuicyIconButton(
        size: 48,
        borderRadius: 14,
        icon: Icon(
          hasUnseenError
              ? Icons.error_outline_rounded
              : Icons.warning_amber_rounded,
          color: iconColor,
        ),
        backgroundColor: backgroundColor,
        onTap: onTap,
      ),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.textPrimary, width: 4),
      ),
      title: Text(
        context.l10n.alerts.title,
        style: AppTheme.titleMedium.copyWith(
          color: AppColors.textPrimary,
          fontFamily: 'momo',
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: 420,
        height: 450,
        child: widget.alerts.isEmpty
            ? Center(
                child: Text(
                  context.l10n.alerts.noAlerts,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontFamily: 'momo',
                  ),
                ),
              )
            : ListView.builder(
                itemCount: widget.alerts.length,
                itemBuilder: (context, index) {
                  final alert = widget.alerts[index];
                  final isError = alert.isError;
                  final bgColor = isError
                      ? const Color(0xFFFDE8E8) // Soft red background
                      : const Color(0xFFFEF3C7); // Soft amber background
                  final borderColor = isError
                      ? const Color(0xFFF87171) // Red border
                      : const Color(0xFFFBBF24); // Amber border

                  return Card(
                    color: bgColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: borderColor,
                        width: 3.0,
                      ),
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Icon(
                        isError
                            ? Icons.error_outline
                            : Icons.warning_amber_rounded,
                        color: isError ? const Color(0xFFC53030) : const Color(0xFFB7791F),
                      ),
                      title: SelectableText(
                        alert.message,
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
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
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.highlightColor,
            foregroundColor: AppColors.textPrimary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(
                color: AppColors.textPrimary,
                width: 3,
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            context.l10n.common.close,
            style: TextStyle(
              fontFamily: 'momo',
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}
