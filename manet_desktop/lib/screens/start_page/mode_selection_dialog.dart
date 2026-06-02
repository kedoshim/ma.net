import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/player_face_indicator.dart';
import '../../models/player_face.dart';
import '../../widgets/juicy_widgets.dart';
import '../../l10n/app_localizations.dart';

class ModeSelectionPage extends StatelessWidget {
  final String? initialMode;

  const ModeSelectionPage({super.key, this.initialMode});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      body: ModeSelectionContent(
        isMandatory: true,
        initialMode: initialMode,
        showHeader: true,
        showConfirmButton: true,
      ),
    );
  }
}

class ModeSelectionContent extends StatefulWidget {
  final bool isMandatory;
  final String? initialMode;
  final bool showHeader;
  final bool showConfirmButton;

  const ModeSelectionContent({
    super.key,
    this.isMandatory = false,
    this.initialMode,
    this.showHeader = true,
    this.showConfirmButton = true,
  });

  @override
  State<ModeSelectionContent> createState() => _ModeSelectionContentState();
}

class _ModeSelectionContentState extends State<ModeSelectionContent> {
  String? _chosen;

  @override
  void initState() {
    super.initState();
    _chosen = widget.initialMode;
  }

  void _confirm() {
    if (_chosen != null) {
      Navigator.of(context).pop(_chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 750;
        final isVeryCompact = constraints.maxHeight < 500;
        final outerPadding = isCompact ? 20.0 : 40.0;
        final headerSpacing = isCompact ? 16.0 : 50.0;

        return Padding(
          padding: EdgeInsets.all(outerPadding),
          child: Column(
            children: [
              if (widget.showHeader) ...[
                Text(
                  context.l10n.modeSelection.title,
                  style: AppTheme.titleMedium.copyWith(
                    fontFamily: 'momo',
                    fontSize: isCompact ? 32 : 42,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (!isVeryCompact) ...[
                  SizedBox(height: isCompact ? 12 : 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.textPrimary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      context.l10n.modeSelection.subtitle,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppColors.textPrimary.withValues(alpha: 0.6),
                        fontWeight: FontWeight.bold,
                        fontSize: isCompact ? 12 : null,
                      ),
                    ),
                  ),
                ],
                SizedBox(height: headerSpacing),
              ],
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isCompact ? 0 : 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _ModeCard(
                          isCompact: isCompact,
                          isVeryCompact: isVeryCompact,
                          mode: 'x360',
                          title: context.l10n.modeSelection.xinputTitle,
                          headline: context.l10n.modeSelection.xinputHeadline,
                          faceConfig: const _FaceConfig(
                            faceText: 'X)',
                            color: Color(0xFF4D96FF), // Azure
                          ),
                          isSelected: _chosen == 'x360',
                          onTap: () {
                            setState(() => _chosen = 'x360');
                            if (!widget.showConfirmButton) {
                              Navigator.of(context).pop('x360');
                            }
                          },
                          details: context.l10n.modeSelection.xinputDetails,
                        ),
                      ),
                      SizedBox(width: isCompact ? 16 : 32),
                      Expanded(
                        child: _ModeCard(
                          isCompact: isCompact,
                          isVeryCompact: isVeryCompact,
                          mode: 'ds4',
                          title: context.l10n.modeSelection.dinputTitle,
                          headline: context.l10n.modeSelection.dinputHeadline,
                          faceConfig: const _FaceConfig(
                            faceText: ':D',
                            color: Color(0xFFFF6B6B), // Coral
                          ),
                          isSelected: _chosen == 'ds4',
                          onTap: () {
                            setState(() => _chosen = 'ds4');
                            if (!widget.showConfirmButton) {
                              Navigator.of(context).pop('ds4');
                            }
                          },
                          details: context.l10n.modeSelection.dinputDetails,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.showConfirmButton) ...[
                SizedBox(height: isCompact ? 20 : 50),
                SizedBox(
                  height: isCompact ? 72 : 96,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (!widget.isMandatory)
                        Positioned(
                          left: 0,
                          child: JuicyButton(
                            onPressed: () => Navigator.of(context).pop(),
                            backgroundColor: Colors.transparent,
                            borderThickness: 0.0,
                            borderRadius: 12,
                            padding: EdgeInsets.symmetric(
                              horizontal: isCompact ? 16 : 24,
                              vertical: isCompact ? 12 : 16,
                            ),
                            child: Text(
                              context.l10n.common.cancel,
                              style: AppTheme.bodyMedium.copyWith(
                                fontFamily: 'momo',
                                color: AppColors.textPrimary.withValues(alpha: 0.7),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 600),
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                              return ScaleTransition(
                                scale: CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.elasticOut,
                                ),
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              );
                            },
                        child: _chosen != null
                            ? Padding(
                                key: const ValueKey('confirm_btn_anim'),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: JuicyButton(
                                  onPressed: _confirm,
                                  backgroundColor: AppColors.highlightColor,
                                  borderRadius: 20,
                                  borderThickness: 5.0,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isCompact ? 32 : 48,
                                    vertical: isCompact ? 12 : 20,
                                  ),
                                  child: Text(
                                    context.l10n.modeSelection.play,
                                    style: AppTheme.titleSmall.copyWith(
                                      fontFamily: 'momo',
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      height: 1.0,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(key: ValueKey('empty_btn')),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _FaceConfig {
  final String faceText;
  final Color color;
  const _FaceConfig({required this.faceText, required this.color});
}

class _ModeCard extends StatefulWidget {
  final String mode;
  final bool isCompact;
  final bool isVeryCompact;
  final String title;
  final String headline;
  final _FaceConfig faceConfig;
  final bool isSelected;
  final VoidCallback onTap;
  final String details;

  const _ModeCard({
    this.isCompact = false,
    this.isVeryCompact = false,
    required this.mode,
    required this.title,
    required this.headline,
    required this.faceConfig,
    required this.isSelected,
    required this.onTap,
    required this.details,
  });

  @override
  State<_ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<_ModeCard> with TickerProviderStateMixin {
  late AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    final duration = 2000 + (widget.mode == 'x360' ? 0 : 300);
    _floatController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: duration),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;
    final brandColor = widget.faceConfig.color;

    return JuicyCard(
      onTap: widget.onTap,
      isSelected: isSelected,
      selectedColor: brandColor,
      backgroundColor: AppColors.lightColor,
      borderRadius: widget.isCompact ? 20 : 28,
      borderThickness: widget.isCompact ? 3.0 : 4.0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: EdgeInsets.all(widget.isVeryCompact ? 12 : (widget.isCompact ? 20 : 32)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.title,
                      style: AppTheme.titleMedium.copyWith(
                        fontFamily: 'momo',
                        fontSize: widget.isVeryCompact ? 20 : (widget.isCompact ? 26 : 32),
                        fontWeight: FontWeight.w900,
                        color: isSelected
                            ? brandColor
                            : AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: widget.isVeryCompact ? 12 : (widget.isCompact ? 16 : 24)),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: widget.isVeryCompact ? 8 : (widget.isCompact ? 12 : 16)),
                      child: Center(
                        child: AnimatedBuilder(
                          animation: _floatController,
                          builder: (context, child) {
                            final floatY =
                                math.sin(_floatController.value * math.pi) *
                                8.0;
                            final floatX =
                                math.cos(_floatController.value * math.pi) *
                                3.0;
                            return Transform.translate(
                              offset: Offset(floatX, floatY),
                              child: child,
                            );
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: widget.isVeryCompact ? 60 : (widget.isCompact ? 80 : 100),
                            height: widget.isVeryCompact ? 60 : (widget.isCompact ? 80 : 100),
                            decoration: const BoxDecoration(),
                            child: PlayerFaceIndicator(
                              face: PlayerFaceData(
                                color: widget.faceConfig.color,
                                faceText: widget.faceConfig.faceText,
                                rotation: PlayerFaceRotation.normal,
                              ),
                              size: widget.isVeryCompact ? 60 : (widget.isCompact ? 80 : 100),
                              roundedSquare: true,
                              borderColor: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: widget.isVeryCompact ? 12 : (widget.isCompact ? 16 : 24)),
                    Text(
                      widget.headline,
                      textAlign: TextAlign.center,
                      style: AppTheme.bodyMedium.copyWith(
                        fontSize: widget.isVeryCompact ? 13 : (widget.isCompact ? 16 : 18),
                        fontWeight: FontWeight.w900,
                        color: isSelected
                            ? brandColor
                            : AppColors.textPrimary,
                      ),
                    ),
                    if (!widget.isVeryCompact) ...[
                      SizedBox(height: widget.isCompact ? 4 : 8),
                      Text(
                        widget.details,
                        textAlign: TextAlign.center,
                        style: AppTheme.bodySmall.copyWith(
                          fontSize: widget.isCompact ? 12 : 14,
                          color: AppColors.textPrimary.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
