import 'package:flutter/material.dart';

import '../models/quick_actions_definition.dart';
import '../theme/app_colors.dart';

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
    final buttonBackground = enabled
        ? AppColors.backgroundColor
        : AppColors.backgroundColor.withValues(alpha: 0.35);
    final buttonBorderColor = enabled
        ? AppColors.textPrimary
        : AppColors.textPrimary.withValues(alpha: 0.25);

    return GestureDetector(
      onTap: () => _showPopup(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: 84,
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: buttonBackground,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: buttonBorderColor,
            width: AppColors.borderThickness,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              'Actions',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: enabled
                    ? AppColors.textPrimary
                    : AppColors.textPrimary.withValues(alpha: 0.45),
                fontFamily: 'pico',
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
    return Dialog(
      backgroundColor: Colors.white,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.screenBackground,
              AppColors.highlightColor.withValues(alpha: 0.18),
              AppColors.screenBackground,
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppColors.textPrimary,
            width: AppColors.borderThickness,
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  left: 24,
                  top: 16,
                  right: 16,
                  bottom: 8,
                ),
                child: Row(
                  children: [
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontFamily: 'pico',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close,
                        size: 24,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSection(QuickActionGroup.volumeMedia),
                        const SizedBox(height: 24),
                        _buildSection(QuickActionGroup.windowsSystem),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(QuickActionGroup group) {
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
                quickActionGroupLabel(group),
                style: const TextStyle(
                  fontFamily: 'pico',
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
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = AppColors.highlightColor.withValues(alpha: 0.3);
    final fgColor = AppColors.textPrimary;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed(widget.action.id);
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 86,
          height: 72,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.textPrimary,
              width: AppColors.borderThickness,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.action.icon, size: 26, color: fgColor),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  widget.action.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'pico',
                    fontSize: 9,
                    color: fgColor,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
