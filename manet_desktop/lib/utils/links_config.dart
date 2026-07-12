import 'package:url_launcher/url_launcher.dart';

class LinksConfig {
  static const String discordUrl = 'https://discord.gg/QBaUvEKd2g';
  static const String itchIoUrl = 'https://kedoshim.itch.io/manet';

  /// Helper to open a URL safely in the external default application (browser)
  static Future<void> openUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
