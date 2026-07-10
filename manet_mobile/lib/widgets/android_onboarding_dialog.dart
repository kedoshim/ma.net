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
    final mediaQuery = MediaQuery.of(context);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final isSmallScreen = mediaQuery.size.height < 500;
    final compact = isLandscape || isSmallScreen;

    final styleButtonText = TextStyle(
      fontFamily: 'momo',
      fontSize: compact ? 13 : 14,
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
          constraints: BoxConstraints(
            maxWidth: 380,
            maxHeight: mediaQuery.size.height - 32,
          ),
          padding: compact ? const EdgeInsets.all(16) : const EdgeInsets.all(24),
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
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Playful Mascot Face Container
                Container(
                  width: compact ? 56 : 72,
                  height: compact ? 56 : 72,
                  decoration: BoxDecoration(
                    color: AppColors.androidGreen,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.textPrimary,
                      width: AppColors.borderThickness,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.android_rounded,
                    size: compact ? 30 : 38,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: compact ? 10 : 18),

                // Title
                Text(
                  l10n.androidOnboarding.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'momo',
                    fontSize: compact ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: compact ? 8 : 12),

                // Description Text Box
                Container(
                  width: double.infinity,
                  padding: compact
                      ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
                      : const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: compact ? 12 : 13,
                      height: 1.4,
                    ),
                  ),
                ),
                SizedBox(height: compact ? 14 : 22),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: JuicyButton(
                        onTap: () => _handleDownload(context),
                        backgroundColor: AppColors.androidGreen,
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
                SizedBox(height: compact ? 8 : 10),
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
      ),
    );
  }
}
