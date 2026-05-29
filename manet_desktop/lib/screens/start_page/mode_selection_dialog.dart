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
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        children: [
          if (widget.showHeader) ...[
            Text(
              'preparar a festa!',
              style: AppTheme.titleMedium.copyWith(
                fontFamily: 'momo',
                fontSize: 42,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
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
                ),
              ),
            ),
            const SizedBox(height: 50),
          ],
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _ModeCard(
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
                  const SizedBox(width: 32),
                  Expanded(
                    child: _ModeCard(
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
            const SizedBox(height: 50),
            SizedBox(
              height: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (!widget.isMandatory)
                    Positioned(
                      left: 0,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 48,
                                  vertical: 20,
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
  }
}

class _FaceConfig {
  final String faceText;
  final Color color;
  const _FaceConfig({required this.faceText, required this.color});
}

class _ModeCard extends StatefulWidget {
  final String mode;
  final String title;
  final String headline;
  final _FaceConfig faceConfig;
  final bool isSelected;
  final VoidCallback onTap;
  final String details;

  const _ModeCard({
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
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(28),
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
                      const SizedBox(height: 8),
                      Text(
                        widget.title,
                        style: AppTheme.titleMedium.copyWith(
                          fontFamily: 'momo',
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: isSelected
                              ? brandColor
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
                              width: 100,
                              height: 100,
                              decoration: const BoxDecoration(),
                              child: PlayerFaceIndicator(
                                face: PlayerFaceData(
                                  color: widget.faceConfig.color,
                                  faceText: widget.faceConfig.faceText,
                                  rotation: PlayerFaceRotation.normal,
                                ),
                                size: 100,
                                roundedSquare: true,
                                borderColor: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        widget.headline,
                        textAlign: TextAlign.center,
                        style: AppTheme.bodyMedium.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isSelected
                              ? brandColor
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.details,
                        textAlign: TextAlign.center,
                        style: AppTheme.bodySmall.copyWith(
                          fontSize: 14,
                          color: AppColors.textPrimary.withValues(alpha: 0.6),
                        ),
                      ),
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
