import 'dart:io';
import 'dart:math' as math;
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
import '../../widgets/player_face_indicator.dart';
import '../../models/player_face.dart';

class StartPageWidget extends StatefulWidget {
  const StartPageWidget({super.key});

  @override
  State<StartPageWidget> createState() => _StartPageWidgetState();
}

class _StartPageWidgetState extends State<StartPageWidget> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  late StartPageModel _model;
  final TextEditingController _portController = TextEditingController(
    text: '8765',
  );
  bool _isLoading = false;
  final ServerProcessService _serverService = ServerProcessService.instance;

  @override
  void initState() {
    super.initState();
    _model = StartPageModel();
  }

  Future<bool> isServerRunning(int port) async {
    try {
      final socket = await Socket.connect(
        '127.0.0.1',
        port,
        timeout: const Duration(milliseconds: 500),
      );
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
      barrierDismissible: false,
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
                  borderRadius: BorderRadius.circular(24),
                  clipBehavior: Clip.antiAlias,
                  child: Container(
                    width: MediaQuery.sizeOf(context).width * 0.85,
                    height: MediaQuery.sizeOf(context).height * 0.85,
                    constraints: const BoxConstraints(
                      maxWidth: 1000,
                      maxHeight: 750,
                    ),
                    padding: const EdgeInsets.all(32),
                    child: const ModeSelectionContent(isMandatory: true),
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
              fontFamily: 'momo',
              color: AppColors.textPrimary,
            ),
          ),
          content: Text(
            'Esse app precisa do driver ViGEmBus para funcionar :P',
            style: AppTheme.bodyMedium.copyWith(
              fontFamily: 'momo',
              color: AppColors.textPrimary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancelar',
                style: AppTheme.bodyMedium.copyWith(
                  fontFamily: 'momo',
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
                  fontFamily: 'momo',
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
                                fontFamily: 'momo',
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
                            final port =
                                int.tryParse(_portController.text) ?? 8765;
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
                                  content: Text(
                                    'Não foi possível conectar ao servidor em execução.',
                                  ),
                                ),
                              );
                              return;
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
                            width: 2.0,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          minimumSize: const Size(double.infinity, 48.0),
                          elevation: 0.0,
                        ),
                        child: Text(
                          'iniciar debug',
                          style: AppTheme.titleSmall.copyWith(
                            fontFamily: 'momo',
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
  final bool isMandatory;
  final String? initialMode;

  const ModeSelectionContent({
    super.key,
    this.isMandatory = false,
    this.initialMode,
  });

  @override
  State<ModeSelectionContent> createState() => _ModeSelectionContentState();
}

class _ModeSelectionContentState extends State<ModeSelectionContent> {
  String? _chosen;

  @override
  void initState() {
    super.initState();
    _chosen = widget.initialMode;
  }

  void _confirm() {
    if (_chosen != null) {
      Navigator.of(context).pop(_chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Escolha o modo de controle',
          style: AppTheme.titleMedium.copyWith(
            fontFamily: 'momo',
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Selecione como os controles virtuais serão reconhecidos pelo sistema.',
          style: AppTheme.bodyMedium.copyWith(
            color: AppColors.textPrimary.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 32),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _ModeCard(
                  mode: 'x360',
                  title: 'XInput',
                  faceConfig: const _FaceConfig(
                    faceText: 'X)',
                    color: Color(0xFF10B981), // Emerald Green
                  ),
                  isSelected: _chosen == 'x360',
                  onTap: () => setState(() => _chosen = 'x360'),
                  pros: const [
                    'Melhor compatibilidade até 4 manetes',
                    'Suporte a vibração',
                    'Ideal para jogos modernos',
                  ],
                  cons: const ['Pode não funcionar com mais de 4 manetes'],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _ModeCard(
                  mode: 'ds4',
                  title: 'DInput',
                  faceConfig: const _FaceConfig(
                    faceText: ':D',
                    color: Color(0xFFEF4444), // Red
                  ),
                  isSelected: _chosen == 'ds4',
                  onTap: () => setState(() => _chosen = 'ds4'),
                  pros: const ['Funciona com qualquer número de manetes'],
                  cons: const [
                    'Pode não ser reconhecido por todos os jogos',
                    'Sem suporte a vibração',
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (!widget.isMandatory) ...[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
                child: Text(
                  'Cancelar',
                  style: AppTheme.bodyMedium.copyWith(
                    fontFamily: 'momo',
                    color: AppColors.textPrimary.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
            ElevatedButton(
              onPressed: _chosen != null ? _confirm : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.highlightColor,
                foregroundColor: AppColors.textPrimary,
                disabledBackgroundColor: AppColors.textPrimary.withValues(
                  alpha: 0.1,
                ),
                disabledForegroundColor: AppColors.textPrimary.withValues(
                  alpha: 0.4,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: _chosen != null ? 4 : 0,
              ),
              child: Text(
                'Confirmar Seleção',
                style: AppTheme.titleSmall.copyWith(
                  fontFamily: 'momo',
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FaceConfig {
  final String faceText;
  final Color color;
  const _FaceConfig({required this.faceText, required this.color});
}

class _ModeCard extends StatefulWidget {
  final String mode;
  final String title;
  final _FaceConfig faceConfig;
  final bool isSelected;
  final VoidCallback onTap;
  final List<String> pros;
  final List<String> cons;

  const _ModeCard({
    required this.mode,
    required this.title,
    required this.faceConfig,
    required this.isSelected,
    required this.onTap,
    required this.pros,
    required this.cons,
  });

  @override
  State<_ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<_ModeCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    // Slight offset in animation duration to prevent synchronous perfection
    final duration = 2000 + (widget.mode == 'x360' ? 0 : 300);
    _floatController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: duration),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;
    final isHovered = _isHovered;

    final scale = isSelected ? 1.02 : (isHovered ? 1.01 : 1.0);
    final glowColor = widget.faceConfig.color;
    final borderColor = isSelected
        ? glowColor
        : (isHovered
              ? glowColor.withValues(alpha: 0.5)
              : AppColors.textPrimary.withValues(alpha: 0.12));

    final backgroundColor = isSelected
        ? glowColor.withValues(alpha: 0.08)
        : AppColors.backgroundColor.withValues(alpha: 0.04);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          transformAlignment: Alignment.center,
          transform: Matrix4.identity()..scale(scale),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: isSelected ? 3 : 2),
            boxShadow: isSelected || isHovered
                ? [
                    BoxShadow(
                      color: glowColor.withValues(
                        alpha: isSelected ? 0.25 : 0.1,
                      ),
                      blurRadius: isSelected ? 24 : 12,
                      spreadRadius: isSelected ? 4 : 0,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Title
                      Text(
                        widget.title,
                        style: AppTheme.titleMedium.copyWith(
                          fontFamily: 'momo',
                          color: isSelected ? glowColor : AppColors.textPrimary,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Animated Face
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: AnimatedBuilder(
                            animation: _floatController,
                            builder: (context, child) {
                              // Sway and bobbing
                              final floatY =
                                  math.sin(_floatController.value * math.pi) *
                                  8.0;
                              final floatX =
                                  math.cos(_floatController.value * math.pi) *
                                  3.0;
                              return Transform.translate(
                                offset: Offset(floatX, floatY),
                                child: child,
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: widget.faceConfig.color.withValues(
                                      alpha: 0.4,
                                    ),
                                    blurRadius: isSelected ? 20 : 10,
                                    spreadRadius: isSelected ? 4 : 0,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: PlayerFaceIndicator(
                                face: PlayerFaceData(
                                  color: widget.faceConfig.color,
                                  faceText: widget.faceConfig.faceText,
                                  rotation: PlayerFaceRotation.normal,
                                ),
                                size: 100,
                                roundedSquare: true,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Pros and Cons
                      _buildFeatureList(widget.pros, true),
                      const SizedBox(height: 12),
                      _buildFeatureList(widget.cons, false),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureList(List<String> items, bool isPro) {
    final icon = isPro
        ? Icons.add_circle_outline_rounded
        : Icons.remove_circle_outline_rounded;
    final color = isPro ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item,
                  style: AppTheme.bodyMedium.copyWith(
                    fontSize: 13,
                    color: AppColors.textPrimary.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
