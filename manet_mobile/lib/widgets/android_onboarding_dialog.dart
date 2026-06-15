import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import 'juicy_widgets.dart';

class AndroidOnboardingDialog extends StatelessWidget {
  final VoidCallback? onDownloadClicked;
  final VoidCallback? onDismissClicked;

  const AndroidOnboardingDialog({
    super.key,
    this.onDownloadClicked,
    this.onDismissClicked,
  });

  Future<void> _handleDownload(BuildContext context) async {
    final url = Uri.base.resolve(kAndroidAppUrl);
    try {
      await launchUrl(url, webOnlyWindowName: '_blank');
    } catch (e) {
      debugPrint('Could not launch download URL: $e');
    }
    onDownloadClicked?.call();
    if (context.mounted) {
      Navigator.of(context).pop(true); // Return true to indicate download was clicked
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final styleButtonText = const TextStyle(
      fontFamily: 'momo',
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: AppColors.textPrimary,
    );

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.4, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          alignment: Alignment.center,
          child: child,
        );
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.screenBackground,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.textPrimary,
              width: AppColors.borderThickness,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Playful Mascot Face Container
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.highlightColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.textPrimary,
                    width: AppColors.borderThickness,
                  ),
                ),
                alignment: Alignment.center,
                child: const Text(
                  ':D', // Excited/Happy Android Face
                  style: TextStyle(
                    fontFamily: 'monomaniac',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                l10n.androidOnboarding.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'momo',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              // Description Text Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.textPrimary,
                    width: AppColors.borderThickness / 2,
                  ),
                ),
                child: Text(
                  l10n.androidOnboarding.subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: JuicyButton(
                      onTap: () => _handleDownload(context),
                      backgroundColor: AppColors.highlightColor,
                      child: Center(
                        child: Text(
                          l10n.androidOnboarding.download,
                          style: styleButtonText,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: JuicyButton(
                      onTap: () {
                        onDismissClicked?.call();
                        Navigator.of(context).pop(false);
                      },
                      backgroundColor: AppColors.lightColor,
                      child: Center(
                        child: Text(
                          l10n.androidOnboarding.continueInBrowser,
                          style: styleButtonText,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
