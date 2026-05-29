import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/player_face_indicator.dart';
import '../../models/player_face.dart';

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
                  'preparar a festa!',
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
                      'Como os celulares serão reconhecidos no computador?',
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
                  padding: EdgeInsets.symmetric(horizontal: isCompact ? 0 : 40),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _ModeCard(
                          isCompact: isCompact,
                          isVeryCompact: isVeryCompact,
                          mode: 'x360',
                          title: 'x•input',
                          headline: 'Recomendado: até 4 controles',
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
                          details: 'Alta compatibilidade e vibração.',
                        ),
                      ),
                      SizedBox(width: isCompact ? 16 : 32),
                      Expanded(
                        child: _ModeCard(
                          isCompact: isCompact,
                          isVeryCompact: isVeryCompact,
                          mode: 'ds4',
                          title: 'd•Input',
                          headline: 'Ideal para: 5+ controles',
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
                          details: 'Sem limites, mas sem vibração.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.showConfirmButton) ...[
                SizedBox(height: isCompact ? 20 : 50),
                SizedBox(
                  height: isCompact ? 60 : 80,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (!widget.isMandatory)
                        Positioned(
                          left: 0,
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                horizontal: isCompact ? 16 : 24,
                                vertical: isCompact ? 12 : 16,
                              ),
                            ),
                            child: Text(
                              'Cancelar',
                              style: AppTheme.bodyMedium.copyWith(
                                fontFamily: 'momo',
                                color: AppColors.textPrimary.withValues(alpha: 0.7),
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
                                child: ElevatedButton(
                                  onPressed: _confirm,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.highlightColor,
                                    foregroundColor: AppColors.textPrimary,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isCompact ? 32 : 48,
                                      vertical: isCompact ? 16 : 20,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: BorderSide(
                                        color: AppColors.textPrimary,
                                        width: 5,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    'vamos jogar!',
                                    style: AppTheme.titleSmall.copyWith(
                                      fontFamily: 'momo',
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
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
  bool _isHovered = false;
  bool _isPressed = false;
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
    final isHovered = _isHovered;
    final isPressed = _isPressed;

    final scale = isPressed
        ? 0.98
        : (isSelected ? 1.04 : (isHovered ? 1.02 : 1.0));
    final brandColor = widget.faceConfig.color;
    final borderColor = isSelected ? brandColor : AppColors.textPrimary;
    final borderWidth = isSelected ? 6.0 : 4.0;

    final backgroundColor = isSelected
        ? brandColor.withValues(alpha: 0.1)
        : AppColors.lightColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          transformAlignment: Alignment.center,
          transform: Matrix4.identity()..scale(scale),
          margin: EdgeInsets.all(widget.isCompact ? 8 : 12),
          padding: EdgeInsets.all(widget.isVeryCompact ? 12 : (widget.isCompact ? 20 : 32)),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(widget.isCompact ? 20 : 28),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
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
              );
            },
          ),
        ),
      ),
    );
  }
}
