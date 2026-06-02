import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/controller_branding.dart';
import '../../services/host_api_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/layout_selector_widget.dart';
import '../../widgets/juicy_widgets.dart';
import 'server_alerts.dart';
import '../../l10n/app_localizations.dart';

enum ModeChangeState { idle, loading, success }

class LobbyToolbar extends StatefulWidget {
  final int serverSlots;
  final bool serverLocked;
  final String controllerMode;
  final PresetCatalog? layoutCatalog;
  final HostApiService layoutApi;
  final ValueListenable<ControllerBrandingMode> brandingModeListenable;
  final ModeChangeState modeChangeState;
  final ValueChanged<PresetCatalog> onLayoutCatalogChanged;
  final Future<void> Function(int slots, bool locked) onApply;
  final VoidCallback onOpenSettings;

  const LobbyToolbar({
    super.key,
    required this.serverSlots,
    required this.serverLocked,
    required this.controllerMode,
    required this.layoutCatalog,
    required this.layoutApi,
    required this.brandingModeListenable,
    required this.modeChangeState,
    required this.onLayoutCatalogChanged,
    required this.onApply,
    required this.onOpenSettings,
  });

  @override
  State<LobbyToolbar> createState() => _LobbyToolbarState();
}

class _LobbyToolbarState extends State<LobbyToolbar> {
  late int _draftSlots;
  late bool _draftLocked;
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _draftSlots = widget.serverSlots;
    _draftLocked = widget.serverLocked;
  }

  @override
  void didUpdateWidget(covariant LobbyToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serverSlots != widget.serverSlots) {
      _draftSlots = widget.serverSlots;
    }
    if (oldWidget.serverLocked != widget.serverLocked) {
      _draftLocked = widget.serverLocked;
    }
  }

  bool get _hasChanges =>
      _draftSlots != widget.serverSlots || _draftLocked != widget.serverLocked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24)),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // LEFT SIDE: Session size controls
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Lock Icon
                  Tooltip(
                    message: _draftLocked
                        ? context.l10n.lobby.lockTooltipReserve
                        : context.l10n.lobby.lockTooltipAuto,
                    child: JuicyIconButton(
                      size: 36,
                      borderRadius: 10,
                      borderColor: Colors.transparent,
                      icon: Icon(
                        _draftLocked
                            ? Icons.lock_rounded
                            : Icons.lock_open_rounded,
                        size: 20,
                      ),
                      onTap: () async {
                        if (_isApplying) return;

                        final newLockedState = !_draftLocked;

                        // Ativa o estado de carregamento imediatamente
                        setState(() {
                          _draftLocked = newLockedState;
                          _isApplying = true;
                        });

                        // Try/finally garante que o estado de loading seja removido
                        // mesmo se widget.onApply lançar uma exceção silenciosa
                        try {
                          await widget.onApply(widget.serverSlots, newLockedState);
                        } finally {
                          if (mounted) {
                            setState(() {
                              _isApplying = false;
                            });
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Minus
                  JuicyIconButton(
                    size: 32,
                    borderRadius: 8,
                    borderColor: Colors.transparent,
                    icon: const Icon(Icons.remove_circle_rounded),
                    iconColor: AppColors.highlightColor,
                    hoverBackgroundColor: AppColors.highlightColor,
                    hoverIconColor: AppColors.textPrimary,
                    onTap: () => setState(
                      () => _draftSlots = (_draftSlots - 1).clamp(1, 16),
                    ),
                  ),

                  // Slots count
                  SizedBox(
                    width: 40,
                    child: Center(
                      child: Text(
                        '$_draftSlots',
                        style: AppTheme.titleLarge.copyWith(
                          color: AppColors.textPrimary,
                          fontFamily: 'monomaniac',
                          fontSize: 22,
                        ),
                      ),
                    ),
                  ),

                  // Plus
                  JuicyIconButton(
                    size: 32,
                    borderRadius: 8,
                    borderColor: Colors.transparent,
                    icon: const Icon(Icons.add_circle_rounded),
                    iconColor: AppColors.highlightColor,
                    hoverBackgroundColor: AppColors.highlightColor,
                    hoverIconColor: AppColors.textPrimary,
                    onTap: () => setState(
                      () => _draftSlots = (_draftSlots + 1).clamp(1, 16),
                    ),
                  ),

                  // O espaço para o botão/loading sempre reservado
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: _isApplying
                        ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                        : _hasChanges
                        ? JuicyIconButton(
                            size: 32,
                            borderRadius: 8,
                            backgroundColor: Colors.green,
                            iconColor: Colors.white,
                            icon: const Icon(Icons.check_rounded),
                            onTap: () async {
                              setState(() => _isApplying = true);
                              try {
                                await widget.onApply(_draftSlots, _draftLocked);
                              } finally {
                                if (mounted)
                                  setState(() => _isApplying = false);
                              }
                            },
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),

              // RIGHT SIDE: Input mode controls
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Alerts icon moved to global header bar

                  // 6. Novo AnimatedSwitcher para a animação de alteração de modo
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: widget.modeChangeState == ModeChangeState.loading
                        ? Container(
                            key: const ValueKey('loading'),
                            margin: const EdgeInsets.only(right: 8.0),
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textPrimary.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          )
                        : widget.modeChangeState == ModeChangeState.success
                        ? Container(
                            key: const ValueKey('success'),
                            margin: const EdgeInsets.only(right: 8.0),
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 12,
                            ),
                          )
                        : const SizedBox.shrink(key: ValueKey('idle')),
                  ),

                  JuicyButton(
                    onPressed: widget.onOpenSettings,
                    borderRadius: 16,
                    borderThickness: 2.0,
                    backgroundColor: Colors.transparent,
                    borderColor: AppColors.highlightColor.withValues(alpha: 0.6),
                    customShadows: const [],
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.settings_rounded,
                          color: AppColors.textPrimary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.controllerMode.toLowerCase() == 'x360'
                              ? context.l10n.lobby.xinput
                              : context.l10n.lobby.dinput,
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (widget.layoutCatalog != null)
            LayoutSelectorWidget(
              api: widget.layoutApi,
              catalog: widget.layoutCatalog!,
              brandingModeListenable: widget.brandingModeListenable,
              onCatalogChanged: widget.onLayoutCatalogChanged,
            ),
        ],
      ),
    );
  }
}
