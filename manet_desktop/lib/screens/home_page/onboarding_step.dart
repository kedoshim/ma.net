import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

class OnboardingStepWidget extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget illustration;

  const OnboardingStepWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.illustration,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
      child: Column(
        children: [
          Expanded(flex: 5, child: illustration),
          const SizedBox(height: 32),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTheme.titleMedium.copyWith(
              fontFamily: 'momo',
              color: AppColors.textPrimary,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTheme.bodyMedium.copyWith(
              color: AppColors.textPrimary.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
