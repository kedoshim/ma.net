import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/controller_branding.dart';
import '../../services/host_api_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/layout_selector_widget.dart';
import 'server_alerts.dart';

enum ModeChangeState { idle, loading, success }

class LobbyToolbar extends StatefulWidget {
  final int serverSlots;
  final bool serverLocked;
  final String controllerMode;
  final PresetCatalog? layoutCatalog;
  final HostApiService layoutApi;
  final ValueListenable<ControllerBrandingMode> brandingModeListenable;
  final List<ServerAlert> alerts;
  final ModeChangeState modeChangeState;
  final VoidCallback onOpenAlerts;
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
    required this.alerts,
    required this.modeChangeState,
    required this.onOpenAlerts,
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
    if (oldWidget.serverSlots != widget.serverSlots ||
        oldWidget.serverLocked != widget.serverLocked) {
      _draftSlots = widget.serverSlots;
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
                  InkWell(
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
                        await widget.onApply(_draftSlots, newLockedState);
                      } finally {
                        if (mounted) {
                          setState(() {
                            _isApplying = false;
                          });
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Tooltip(
                        message: _draftLocked
                            ? 'Limite fixo de jogadores'
                            : 'Criar novos controles automaticamente',
                        child: Icon(
                          _draftLocked
                              ? Icons.lock_rounded
                              : Icons.lock_open_rounded,
                          color: AppColors.textPrimary.withValues(alpha: 0.8),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Minus
                  InkWell(
                    onTap: () => setState(
                      () => _draftSlots = (_draftSlots - 1).clamp(1, 64),
                    ),
                    borderRadius: BorderRadius.circular(16),
                    child: Icon(
                      Icons.remove_circle_rounded,
                      color: AppColors.highlightColor,
                      size: 28,
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
                  InkWell(
                    onTap: () => setState(
                      () => _draftSlots = (_draftSlots + 1).clamp(1, 64),
                    ),
                    borderRadius: BorderRadius.circular(16),
                    child: Icon(
                      Icons.add_circle_rounded,
                      color: AppColors.highlightColor,
                      size: 28,
                    ),
                  ),

                  // O espaço para o botão/loading sempre reservado
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: _isApplying
                        ? const CircularProgressIndicator(strokeWidth: 2)
                        : _hasChanges
                        ? InkWell(
                            onTap: () async {
                              setState(() => _isApplying = true);
                              try {
                                await widget.onApply(_draftSlots, _draftLocked);
                              } finally {
                                if (mounted)
                                  setState(() => _isApplying = false);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),

              // RIGHT SIDE: Input mode controls
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.alerts.isNotEmpty) ...[
                    AlertIcon(
                      alerts: widget.alerts,
                      onTap: widget.onOpenAlerts,
                    ),
                    const SizedBox(width: 12),
                  ],

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

                  InkWell(
                    // SYNTAX FIX & SCOPE FIX HERE:
                    onTap: () {
                      widget.onOpenSettings();
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.highlightColor.withValues(
                            alpha: 0.6,
                          ),
                          width: 2,
                        ),
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
                                ? 'x•input'
                                : 'd•input',
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
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
