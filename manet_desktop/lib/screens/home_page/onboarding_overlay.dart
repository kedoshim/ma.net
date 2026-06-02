import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import 'onboarding_step.dart';
import 'onboarding_illustrations.dart';

class OnboardingOverlay extends StatefulWidget {
  static const String _prefKey = 'has_seen_onboarding';

  const OnboardingOverlay({super.key});

  /// Checks if the user has seen the onboarding before.
  /// If not, it presents the overlay on top of the current route.
  static Future<void> checkAndShow(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool(_prefKey) ?? false;

    if (!hasSeen && context.mounted) {
      await showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.7),
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, anim1, anim2) => const OnboardingOverlay(),
        transitionBuilder: (context, anim1, anim2, child) {
          final curve = CurvedAnimation(
            parent: anim1,
            curve: Curves.elasticOut,
          );
          return Transform.scale(
            scale: curve.value,
            child: FadeTransition(opacity: anim1, child: child),
          );
        },
      );
      await prefs.setBool(_prefKey, true);
    }
  }

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final int _totalPages = 3;

  void _nextPage() {
    if (_currentIndex < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _previousPage() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _finish() {
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 700,
          height: 500,
          decoration: BoxDecoration(
            color: AppColors.screenBackground,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: AppColors.textPrimary, width: 5),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.15),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            children: [
              // Top Bar (Skip Button)
              Padding(
                padding: const EdgeInsets.only(top: 16.0, right: 16.0),
                child: Align(
                  alignment: Alignment.topRight,
                  child: _currentIndex < _totalPages - 1
                      ? TextButton(
                          onPressed: _finish,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textPrimary.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          child: Text(
                            context.l10n.home.onboardingSkip,
                            style: const TextStyle(
                              fontFamily: 'momo',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : const SizedBox(
                          height: 48,
                        ), // Placeholder to keep height stable
                ),
              ),

              // Paged Content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);
                  },
                  children: [
                    OnboardingStepWidget(
                      title: context.l10n.home.onboardingStepConnectTitle,
                      subtitle: context.l10n.home.onboardingStepConnectBody,
                      illustration: const Step1Illustration(),
                    ),
                    OnboardingStepWidget(
                      title: context.l10n.home.onboardingStepArrangeTitle,
                      subtitle: context.l10n.home.onboardingStepArrangeBody,
                      illustration: const Step2Illustration(),
                    ),
                    OnboardingStepWidget(
                      title: context.l10n.home.onboardingStepPlayTitle,
                      subtitle: context.l10n.home.onboardingStepPlayBody,
                      illustration: const Step3Illustration(),
                    ),
                  ],
                ),
              ),

              // Bottom Controls
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                child: Row(
                  children: [
                    // Back Button
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _currentIndex > 0
                            ? TextButton(
                                onPressed: _previousPage,
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.textPrimary
                                      .withValues(alpha: 0.6),
                                ),
                                child: Text(
                                  context.l10n.home.onboardingBack,
                                  style: const TextStyle(
                                    fontFamily: 'momo',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),

                    // Progress Dots
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        _totalPages,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(right: 8),
                          height: 10,
                          width: _currentIndex == index ? 24 : 10,
                          decoration: BoxDecoration(
                            color: _currentIndex == index
                                ? AppColors.textPrimary
                                : AppColors.textPrimary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ),

                    // Next/Start Button
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.highlightColor,
                            foregroundColor: AppColors.textPrimary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 20,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(
                                color: AppColors.textPrimary,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Text(
                            _currentIndex == _totalPages - 1
                                ? context.l10n.home.onboardingDone
                                : context.l10n.home.onboardingNext,
                            style: const TextStyle(
                              fontFamily: 'momo',
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
