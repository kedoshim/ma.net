import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/host_api_service.dart';
import '../services/network_mode_service.dart';
import '../theme/app_colors.dart';

/// "No Wi-Fi?" card with a QR that joins the phone to the PC's hotspot.
/// Shown only while the hotspot is on and the QR points at the local
/// network, so its password never ends up on an online stream.
class HotspotWifiQr extends StatelessWidget {
  final HostApiService api;
  final double size;

  /// Space around the card; none while hidden.
  final EdgeInsetsGeometry margin;

  const HotspotWifiQr({
    super.key,
    required this.api,
    this.size = 150,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final network = NetworkModeService.of(api);
    return ListenableBuilder(
      listenable: network,
      builder: (context, _) {
        final hotspot = network.value.hotspot;
        final visible = network.showWifiQr;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: !visible
              ? const SizedBox.shrink()
              : Container(
                  key: ValueKey('wifi-qr-${hotspot.ssid}'),
                  width: size + 28,
                  margin: margin,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.lightColor.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.textPrimary.withValues(alpha: 0.35),
                      width: 3,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.wifi_tethering_rounded,
                            size: 18,
                            color: AppColors.textPrimary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              context.l10n.network.wifiQrTitle,
                              style: const TextStyle(
                                fontFamily: 'momo',
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(4),
                        child: Image.network(
                          network.wifiQrUrl,
                          width: size,
                          height: size,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) =>
                              SizedBox(width: size, height: size),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.network.wifiQrCaption(hotspot.ssid ?? ''),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'momo',
                          fontSize: 12,
                          color: AppColors.textPrimary.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
