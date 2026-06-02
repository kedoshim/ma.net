import 'dart:async';
import 'package:flutter/material.dart';

import '../models/quick_actions_definition.dart';
import '../theme/app_colors.dart';
import '../l10n/app_localizations.dart';
import 'juicy_widgets.dart';

typedef QuickActionCallback = void Function(String actionId);

class QuickActionsMenu extends StatelessWidget {
  final bool enabled;
  final QuickActionCallback onAction;

  const QuickActionsMenu({
    super.key,
    required this.enabled,
    required this.onAction,
  });

  void _showPopup(BuildContext context) {
    if (!enabled) return;
    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (context) => _QuickActionsDialog(onAction: onAction),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      height: 58,
      child: JuicyButton(
        onTap: enabled ? () => _showPopup(context) : null,
        backgroundColor: AppColors.backgroundColor,
        borderRadius: BorderRadius.circular(24),
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.more_horiz,
              color: enabled
                  ? AppColors.textPrimary
                  : AppColors.textPrimary.withValues(alpha: 0.45),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.quickActions.title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: enabled
                    ? AppColors.textPrimary
                    : AppColors.textPrimary.withValues(alpha: 0.45),
                fontFamily: 'momo',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsDialog extends StatefulWidget {
  final QuickActionCallback onAction;

  const _QuickActionsDialog({required this.onAction});

  @override
  State<_QuickActionsDialog> createState() => _QuickActionsDialogState();
}

class _QuickActionsDialogState extends State<_QuickActionsDialog> {
  void _onActionPressed(String actionId) {
    widget.onAction(actionId);
  }

  @override
  Widget build(BuildContext context) {
    return JuicyDialog(
      title: context.l10n.quickActions.title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSection(context, QuickActionGroup.volumeMedia),
          const SizedBox(height: 24),
          _buildSection(context, QuickActionGroup.windowsSystem),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, QuickActionGroup group) {
    final actions = quickActionsForGroup(group);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(
                group == QuickActionGroup.volumeMedia
                    ? Icons.perm_media_rounded
                    : Icons.desktop_windows_rounded,
                size: 18,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: 8),
              Text(
                group == QuickActionGroup.volumeMedia
                    ? context.l10n.quickActions.volumeMediaSection
                    : context.l10n.quickActions.windowsSystemSection,
                style: const TextStyle(
                  fontFamily: 'momo',
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          runSpacing: 10,
          spacing: 10,
          children: actions
              .map(
                (action) => _QuickActionTile(
                  action: action,
                  onPressed: _onActionPressed,
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _QuickActionTile extends StatefulWidget {
  final QuickActionDefinition action;
  final QuickActionCallback onPressed;

  const _QuickActionTile({required this.action, required this.onPressed});

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  Timer? _initialDelayTimer;
  Timer? _repeatTimer;

  bool get _isRepeatable =>
      widget.action.id == 'volume_up' || widget.action.id == 'volume_down';

  void _startRepeat() {
    if (!_isRepeatable) return;
    widget.onPressed(widget.action.id);
    _initialDelayTimer = Timer(const Duration(milliseconds: 400), () {
      _repeatTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        widget.onPressed(widget.action.id);
      });
    });
  }

  void _stopRepeat() {
    _initialDelayTimer?.cancel();
    _initialDelayTimer = null;
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  @override
  void dispose() {
    _stopRepeat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = AppColors.highlightColor.withValues(alpha: 0.3);
    final fgColor = AppColors.textPrimary;

    return SizedBox(
      width: 86,
      height: 72,
      child: JuicyButton(
        onStateChange: (state) {
          if (state == 'down') {
            _startRepeat();
          } else if (state == 'up') {
            if (!_isRepeatable) {
              widget.onPressed(widget.action.id);
            }
            _stopRepeat();
          }
        },
        backgroundColor: bgColor,
        borderRadius: BorderRadius.circular(16),
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.action.icon, size: 26, color: fgColor),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                context.l10n.quickActions.getActionTitle(widget.action.id),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'momo',
                  fontSize: 9,
                  color: fgColor,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
