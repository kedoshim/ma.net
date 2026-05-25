import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:server_app/screens/home_page/home_page_widget.dart';
import 'package:server_app/services/server_process_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../services/sound_effect_service.dart';
import 'start_page_model.dart';

class StartPageWidget extends StatefulWidget {
  const StartPageWidget({super.key});

  @override
  State<StartPageWidget> createState() => _StartPageWidgetState();
}

class _StartPageWidgetState extends State<StartPageWidget> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  late StartPageModel _model;
  final TextEditingController _portController = TextEditingController(text: '8765');
  bool _isLoading = false;
  final ServerProcessService _serverService = ServerProcessService.instance;

  @override
  void initState() {
    super.initState();
    _model = StartPageModel();
  }

  Future<bool> isServerRunning(int port) async {
    try {
      final socket = await Socket.connect('127.0.0.1', port, timeout: const Duration(milliseconds: 500));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> killExistingServer(int port) async {
    await _serverService.stopServer();
  }

  Future<bool> waitUntilServerReady(int port) async {
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (await isServerRunning(port)) return true;
    }
    return false;
  }

  Future<String?> _showModeSelectionDialog() async {
    return await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Selecao de modo',
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SafeArea(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Material(
                  color: AppColors.screenBackground,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    height: MediaQuery.sizeOf(context).height * 0.7,
                    padding: const EdgeInsets.all(20),
                    child: ModeSelectionContent(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _checkDriverAndShowDialog() async {
    final installed = await _isDriverInstalled();
    if (!installed && mounted) {
      _showDriverInstallDialog();
    }
  }

  Future<bool> _isDriverInstalled() async {
    try {
      final result = await Process.run('sc', ['query', 'ViGEmBus']);
      if (result.stdout.toString().contains('1060')) {
        return false;
      }
      return true;
    } catch (e) {
      print('[DRIVER CHECK] sc query threw an exception: $e');
      final driverFile = File(r'C:\Windows\System32\drivers\ViGEmBus.sys');
      final exists = driverFile.existsSync();
      print('[DRIVER CHECK] Fallback check: ViGEmBus.sys exists = $exists');
      return exists;
    }
  }

  void _showDriverInstallDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.screenBackground,
          title: Text(
            'Sem Driver',
            style: AppTheme.titleSmall.copyWith(
              fontFamily: 'pico',
              color: AppColors.textPrimary,
            ),
          ),
          content: Text(
            'Esse app precisa do driver ViGEmBus para funcionar :P',
            style: AppTheme.bodyMedium.copyWith(
              fontFamily: 'pico',
              color: AppColors.textPrimary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancelar',
                style: AppTheme.bodyMedium.copyWith(
                  fontFamily: 'pico',
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _installDriver();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textPrimary,
                foregroundColor: AppColors.screenBackground,
              ),
              child: Text(
                'Instalar Driver',
                style: AppTheme.titleSmall.copyWith(
                  fontFamily: 'pico',
                  color: AppColors.screenBackground,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _findDriverInstallerPath() async {
    final exeDir = p.dirname(Platform.resolvedExecutable);
    final candidates = <String>[
      p.join(
        exeDir,
        'data',
        'flutter_assets',
        'assets',
        'drivers',
        'ViGEmBus_Setup.exe',
      ),
      p.join(exeDir, 'data', 'flutter_assets', 'drivers', 'ViGEmBus_Setup.exe'),
      p.join(Directory.current.path, 'assets', 'drivers', 'ViGEmBus_Setup.exe'),
      p.join(Directory.current.path, 'drivers', 'ViGEmBus_Setup.exe'),
      p.join(
        p.dirname(Platform.script.toFilePath()),
        'assets',
        'drivers',
        'ViGEmBus_Setup.exe',
      ),
    ];

    for (final path in candidates) {
      if (File(path).existsSync()) {
        return path;
      }
    }
    return null;
  }

  Future<void> _installDriver() async {
    try {
      final installerPath = await _findDriverInstallerPath();

      if (installerPath != null) {
        await Process.start(installerPath, [], mode: ProcessStartMode.detached);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Instalador não encontrado em assets/drivers/ViGEmBus_Setup.exe',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao iniciar instalador: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _portController.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: AppColors.screenBackground,
        body: Container(
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3)),
          child: SafeArea(
            top: true,
            child: Align(
              alignment: AlignmentDirectional(0.0, 0.0),
              child: Container(
                width: MediaQuery.sizeOf(context).width * 0.3,
                decoration: BoxDecoration(),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        if (_isLoading) return;

                        setState(() {
                          _isLoading = true;
                        });

                        try {
                          SoundEffectService.instance.playStartButton();

                          // Default start values: 4 players, unlocked (auto expand)
                          final slots = 4;
                          final fixed = true;

                          final port =
                              int.tryParse(_portController.text) ?? 8765;

                          // Let user pick XInput / DInput in a friendly modal
                          final chosen = await _showModeSelectionDialog();
                          final mode = (chosen == 'ds4') ? 'ds4' : 'x360';

                          if (port < 1024 || port > 65535) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Porta inválida')),
                            );
                            return;
                          }

                          final running = await isServerRunning(port);

                          if (running) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Servidor anterior encontrado. Encerrando para reiniciar...',
                                ),
                                duration: Duration(seconds: 2),
                              ),
                            );
                            await killExistingServer(port);
                          }

                          try {
                            final socket = await ServerSocket.bind(
                              InternetAddress.anyIPv4,
                              port,
                            );
                            await socket.close();
                          } catch (e) {
                            await killExistingServer(port);

                            try {
                              final socket2 = await ServerSocket.bind(
                                InternetAddress.anyIPv4,
                                port,
                              );
                              await socket2.close();
                            } catch (e2) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'A porta $port já está em uso por outro programa!',
                                  ),
                                ),
                              );
                              return;
                            }
                          }

                          await _serverService.startServer(
                            port: port,
                            slots: slots,
                            fixed: fixed,
                            controllerMode: mode,
                          );

                          final isReady = await waitUntilServerReady(port);

                          if (!mounted) return;

                          if (!isReady) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Falha ao iniciar o servidor. O driver ViGEmBus pode estar ausente ou houve um erro interno.',
                                ),
                              ),
                            );
                            await _checkDriverAndShowDialog();
                            return; // DO NOT PROGRESS TO THE HOME PAGE
                          }

                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              transitionDuration: const Duration(
                                milliseconds: 500,
                              ),
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      HomePageScreen(
                                        host: '127.0.0.1',
                                        port: port,
                                        initialControllerMode: mode,
                                      ),
                              transitionsBuilder:
                                  (
                                    context,
                                    animation,
                                    secondaryAnimation,
                                    child,
                                  ) {
                                    const begin = Offset(1.0, 0.0);
                                    const end = Offset.zero;
                                    const curve = Curves.easeInOut;
                                    var tween = Tween(
                                      begin: begin,
                                      end: end,
                                    ).chain(CurveTween(curve: curve));
                                    return SlideTransition(
                                      position: animation.drive(tween),
                                      child: child,
                                    );
                                  },
                            ),
                          );
                        } finally {
                          if (mounted) {
                            setState(() {
                              _isLoading = false;
                            });
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.screenBackground,
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(
                          color: AppColors.textPrimary,
                          width: 3.0,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        minimumSize: const Size(double.infinity, 60.0),
                        elevation: 0.0,
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 24.0,
                              height: 24.0,
                              child: CircularProgressIndicator(
                                color: AppColors.textPrimary,
                                strokeWidth: 3.0,
                              ),
                            )
                          : Text(
                              'iniciar',
                              style: AppTheme.titleSmall.copyWith(
                                fontFamily: 'pico',
                                letterSpacing: 0.0,
                                color: AppColors.textPrimary,
                              ),
                            ),
                    ),
                    if (kDebugMode) ...[
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () async {
                          if (_isLoading) return;
                          setState(() {
                            _isLoading = true;
                          });
                          try {
                            final chosen = await _showModeSelectionDialog();
                            final mode = (chosen == 'ds4') ? 'ds4' : 'x360';
                            final port = int.tryParse(_portController.text) ?? 8765;
                            if (port < 1024 || port > 65535) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Porta inválida')),
                              );
                              return;
                            }
                            final isReady = await waitUntilServerReady(port);
                            if (!mounted) return;
                            if (!isReady) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Não foi possível conectar ao servidor em execução.'),
                                ),
                              );
                              return;
                            }
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                transitionDuration: const Duration(milliseconds: 500),
                                pageBuilder: (context, animation, secondaryAnimation) =>
                                    HomePageScreen(
                                      host: '127.0.0.1',
                                      port: port,
                                      initialControllerMode: mode,
                                    ),
                                transitionsBuilder: (
                                  context,
                                  animation,
                                  secondaryAnimation,
                                  child,
                                ) {
                                  const begin = Offset(1.0, 0.0);
                                  const end = Offset.zero;
                                  const curve = Curves.easeInOut;
                                  var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                  return SlideTransition(
                                    position: animation.drive(tween),
                                    child: child,
                                  );
                                },
                              ),
                            );
                          } finally {
                            if (mounted) {
                              setState(() {
                                _isLoading = false;
                              });
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.screenBackground,
                          foregroundColor: AppColors.textPrimary,
                          side: BorderSide(color: AppColors.textPrimary, width: 2.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                          minimumSize: const Size(double.infinity, 48.0),
                          elevation: 0.0,
                        ),
                        child: Text(
                          'iniciar debug',
                          style: AppTheme.titleSmall.copyWith(
                            fontFamily: 'pico',
                            letterSpacing: 0.0,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ModeSelectionContent extends StatefulWidget {
  @override
  State<ModeSelectionContent> createState() => _ModeSelectionContentState();
}

class _ModeSelectionContentState extends State<ModeSelectionContent> {
  String? _chosen;

  void _select(String v) async {
    setState(() => _chosen = v);
    await Future.delayed(const Duration(milliseconds: 450));
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Escolha o modo de controle',
          style: AppTheme.titleSmall.copyWith(
            fontFamily: 'pico',
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _select('x360'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: EdgeInsets.all(_chosen == 'x360' ? 6 : 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundColor.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _chosen == 'x360'
                            ? AppColors.highlightColor
                            : AppColors.textPrimary.withOpacity(0.12),
                        width: _chosen == 'x360' ? 3 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.gamepad,
                              size: 36,
                              color: AppColors.textPrimary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'x•input',
                              style: AppTheme.titleSmall.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Melhor compatibilidade com jogos modernos',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Vibração funciona • Ideal para até 4 jogadores',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppColors.textPrimary.withOpacity(0.85),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Alguns jogos podem limitar players extras',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppColors.textPrimary.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _select('ds4'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: EdgeInsets.all(_chosen == 'ds4' ? 6 : 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundColor.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _chosen == 'ds4'
                            ? AppColors.highlightColor
                            : AppColors.textPrimary.withOpacity(0.12),
                        width: _chosen == 'ds4' ? 3 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.group,
                              size: 36,
                              color: AppColors.textPrimary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'd•input',
                              style: AppTheme.titleSmall.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Melhor para muitas pessoas',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Funciona em vários jogos party/local',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppColors.textPrimary.withOpacity(0.85),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Sem vibração em alguns jogos • Compatibilidade varia',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppColors.textPrimary.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Toque em uma opção para continuar',
          style: AppTheme.bodySmall.copyWith(
            color: AppColors.textPrimary.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}
