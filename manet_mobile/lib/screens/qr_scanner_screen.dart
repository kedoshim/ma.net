import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/preferences_service.dart';
import '../theme/app_colors.dart';
import '../l10n/app_localizations.dart';

class QRScannerScreen extends StatefulWidget {
  final VoidCallback onConnected;

  const QRScannerScreen({super.key, required this.onConnected});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool _isProcessing = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        final urlStr = barcode.rawValue!;
        try {
          final uri = Uri.parse(urlStr);
          if (uri.scheme == 'http' || uri.scheme == 'https') {
            setState(() {
              _isProcessing = true;
            });

            await PreferencesService.instance.saveConnection(
              uri.host,
              uri.port,
              uri.scheme == 'https',
            );

            if (mounted) {
              Navigator.of(context).pop();
              widget.onConnected();
            }
            return;
          }
        } catch (e) {
          // ignore invalid URLs natively
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          context.l10n.scanner.title,
          style: const TextStyle(fontFamily: 'momo'),
        ),
        backgroundColor: Colors.black,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Stack(
        children: [
          MobileScanner(onDetect: _onDetect),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.textPrimary.withOpacity(0.5),
                  width: 4,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.textPrimary),
              ),
            ),
        ],
      ),
    );
  }
}
