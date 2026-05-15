import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:server_app/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:server_app/services/host_api_service.dart';
import 'gamepad_handler_widget.dart';

class QRCodePanel extends StatelessWidget {
  final ConnectionInfo? connectionInfo;
  final String qrCodeUrl;
  final bool isLoadingConnection;
  final UIScale scale;

  const QRCodePanel({
    super.key,
    required this.connectionInfo,
    required this.qrCodeUrl,
    required this.isLoadingConnection,
    required this.scale,
  });

  Future<void> _openLink() async {
    if (connectionInfo == null) return;
    final connectionUrl = connectionInfo!.url;
    final safeUrl = connectionUrl.startsWith('http')
        ? connectionUrl
        : 'http://$connectionUrl';

    final uri = Uri.parse(safeUrl);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingConnection) {
      return const Center(child: CircularProgressIndicator());
    }

    final connectionUrl = connectionInfo?.url ?? "Unavailable";

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(scale.eighth),
        border: Border.all(
          color: AppTheme.primaryText,
          width: scale.eighth / 4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(scale.eighth),
              child: ClipRRect(
                child: Image.network(
                  qrCodeUrl,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.all(scale.eighth),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _openLink,
                    child: Text(
                      '$connectionUrl'.replaceAll('http://', ''),
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.bodyMedium.copyWith(
                        fontFamily: 'pico',
                        fontSize: scale.eighth,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  iconSize: scale.eighth,
                  icon: Icon(
                    FontAwesomeIcons.copy,
                    color: AppTheme.primaryText,
                  ),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: connectionUrl));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Link copiado')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
