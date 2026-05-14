import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../services/network_discovery_service.dart';
import 'qr_scanner_screen.dart';

class ConnectionSetupScreen extends StatefulWidget {
  final VoidCallback onConnected;

  const ConnectionSetupScreen({super.key, required this.onConnected});

  @override
  State<ConnectionSetupScreen> createState() => _ConnectionSetupScreenState();
}

class _ConnectionSetupScreenState extends State<ConnectionSetupScreen> {
  late NetworkDiscoveryService _discoveryService;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    _discoveryService = NetworkDiscoveryService();
    _discoveryService.startScanning();
  }

  @override
  void dispose() {
    _discoveryService.stopScanning();
    super.dispose();
  }

  Future<void> _connectToHost(DiscoveredHost host) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_host', host.ip);
    await prefs.setInt('server_port', host.port);
    await prefs.setBool('server_https', false);

    widget.onConnected();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // LEFT SIDE: Branding and fallback button
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'ma•net',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'pico',
                        fontSize: 48,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      icon: Icon(
                        Icons.qr_code_scanner,
                        color: AppColors.screenBackground,
                      ),
                      label: Text(
                        'Ou conecte via\nQR Code',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'pico',
                          color: AppColors.screenBackground,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => QRScannerScreen(
                              onConnected: widget.onConnected,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              // RIGHT SIDE: Expanded Server List
              Expanded(
                flex: 3,
                child: StreamBuilder<List<DiscoveredHost>>(
                  stream: _discoveryService.discoveredHosts,
                  initialData: const [],
                  builder: (context, snapshot) {
                    final hosts = snapshot.data ?? [];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              hosts.isEmpty
                                  ? 'Buscando hosts na rede...'
                                  : 'Hosts Disponíveis',
                              style: const TextStyle(
                                fontFamily: 'pico',
                                fontSize: 16,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.refresh,
                                color: AppColors.textPrimary,
                              ),
                              onPressed: () {
                                _discoveryService.forceRefresh();
                              },
                              tooltip: 'Buscar novamente',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (hosts.isEmpty)
                          Expanded(
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircularProgressIndicator(
                                    color: AppColors.textPrimary,
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Nenhum host encontrado ainda.\nCertifique-se que o PC e o celular\nestão na mesma rede Wi-Fi.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'pico',
                                      fontSize: 12,
                                      color: AppColors.textPrimary.withOpacity(
                                        0.7,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: ListView.builder(
                              itemCount: hosts.length,
                              itemBuilder: (context, index) {
                                final host = hosts[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: InkWell(
                                    onTap: () => _connectToHost(host),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: AppColors.textPrimary,
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.desktop_windows,
                                            color: AppColors.textPrimary,
                                            size: 32,
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  host.name,
                                                  style: const TextStyle(
                                                    fontFamily: 'pico',
                                                    fontSize: 16,
                                                    color:
                                                        AppColors.textPrimary,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  host.ip,
                                                  style: TextStyle(
                                                    fontFamily: 'pico',
                                                    fontSize: 12,
                                                    color: AppColors.textPrimary
                                                        .withOpacity(0.7),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Icon(
                                            Icons.chevron_right,
                                            color: AppColors.textPrimary,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
