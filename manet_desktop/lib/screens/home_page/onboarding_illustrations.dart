import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/player_face_indicator.dart';
import '../../widgets/layout_preview_widgets.dart';
import '../../models/player_face.dart';
import '../../models/controller_branding.dart';
import '../../services/host_api_service.dart';

/// Illustration for Step 1: Wi-Fi Connection
class Step1Illustration extends StatefulWidget {
  const Step1Illustration({super.key});

  @override
  State<Step1Illustration> createState() => _Step1IllustrationState();
}

class _Step1IllustrationState extends State<Step1Illustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final hover = math.sin(_controller.value * math.pi) * 10;
        final pulse = 1.0 + (_controller.value * 0.15);

        return Transform.translate(
          offset: Offset(0, -hover),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: pulse,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.highlightColor.withValues(alpha: 0.3),
                  ),
                ),
              ),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.highlightColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.textPrimary, width: 4),
                ),
                child: const Icon(
                  Icons.wifi_rounded,
                  size: 56,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Illustration for Step 2: QR Code Scanning
class Step2Illustration extends StatefulWidget {
  const Step2Illustration({super.key});

  @override
  State<Step2Illustration> createState() => _Step2IllustrationState();
}

class _Step2IllustrationState extends State<Step2Illustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 120,
        height: 180,
        decoration: BoxDecoration(
          color: AppColors.backgroundColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.textPrimary, width: 4),
        ),
        child: Stack(
          children: [
            // Fake screen content (QR Code)
            Center(
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: AppColors.textPrimary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  size: 50,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            // Scanning line animation
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                // Scan line goes from top (20) to bottom (160)
                final topOffset = 20.0 + (_controller.value * 130.0);
                return Positioned(
                  top: topOffset,
                  left: 10,
                  right: 10,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.greenAccent,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.greenAccent.withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Illustration for Step 3: Play & Enjoy
class Step3Illustration extends StatelessWidget {
  const Step3Illustration({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // The Face
        Transform.rotate(
          angle: 0.1,
          child: PlayerFaceIndicator(
            face: PlayerFaceData(
              color: AppColors.highlightColor,
              faceText: 'XD',
              rotation: PlayerFaceRotation.normal,
            ),
            size: 80,
            roundedSquare: true,
          ),
        ),
        const SizedBox(height: 16),
        // The Phone Controller Layout
        Container(
          width: 220,
          decoration: BoxDecoration(
            color: AppColors.backgroundColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.textPrimary, width: 4),
          ),
          child: IgnorePointer(
            child: StructuredLayoutPreview(
              brandingMode: ControllerBrandingMode.xinput,
              layout: ControllerPresetLayout(
                movementMode: 'dpad',
                visibleButtons: {'a': true, 'b': true, 'x': true, 'y': true},
                buttonOrder: ['a', 'b', 'x', 'y'],
              ),
              compact: true,
            ),
          ),
        ),
      ],
    );
  }
}
