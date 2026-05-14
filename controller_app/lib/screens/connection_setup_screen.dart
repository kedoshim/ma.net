import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'qr_scanner_screen.dart';

class ConnectionSetupScreen extends StatelessWidget {
  final VoidCallback onConnected;

  const ConnectionSetupScreen({super.key, required this.onConnected});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'ma•net',
              style: TextStyle(
                fontFamily: 'pico',
                fontSize: 48,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Aguardando conexão',
              style: TextStyle(
                fontFamily: 'pico',
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              icon: Icon(
                Icons.qr_code_scanner,
                color: AppColors.screenBackground,
              ),
              label: Text(
                'Escanear QR Code',
                style: TextStyle(
                  fontFamily: 'pico',
                  color: AppColors.screenBackground,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => QRScannerScreen(onConnected: onConnected),
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
