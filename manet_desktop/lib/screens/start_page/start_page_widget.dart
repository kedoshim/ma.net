import 'dart:math' as math;
import 'package:manet_desktop/screens/home_page/home_page_widget.dart';
import 'package:manet_desktop/services/server_process_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../services/sound_effect_service.dart';
import 'start_page_model.dart';
import '../../widgets/player_face_indicator.dart';
import '../../models/player_face.dart';
import '../../widgets/app_error_widget.dart';

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
                    decoration: BoxDecoration(
                      color: AppColors.screenBackground,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.textPrimary,
                        width: 10,
                      ),
                    ),
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

  void _showStartupErrorDialog(ServerStartupResult result) {
    final logs = ServerProcessService.instance.logs.join('\n');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AppErrorWidget(
        title: 'Erro na Inicialização',
        message: result.message,
        logs: logs,
        additionalActions: [
          if (result.status == ServerStartupStatus.missingDriver)
            ElevatedButton.icon(
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text(
                'Instalar Driver',
                style: TextStyle(fontFamily: 'momo'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textPrimary,
                foregroundColor: AppColors.screenBackground,
              ),
              onPressed: () async {
                final success = await ServerProcessService.instance
                    .installDriver();
                if (!mounted) return;

                Navigator.of(dialogContext).pop();

                if (!success) {
                  showDialog(
                    context: context,
                    builder: (_) => const AppErrorWidget(
                      title: 'Erro de Instalação',
                      message: 'Falha ao localizar o instalador do ViGEmBus.',
                    ),
                  );
                }
              },
            ),
        ],
      ),
    );
  }

  Future<void> _handleStartup({required bool isDebug}) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      SoundEffectService.instance.playStartButton();

      final port = int.tryParse(_portController.text) ?? 8765;
      if (port < 1024 || port > 65535) {
        showDialog(
          context: context,
          builder: (context) => const AppErrorWidget(
            title: 'Porta Inválida',
            message:
                'A porta informada não é válida. Utilize um valor entre 1024 e 65535.',
          ),
        );
        return;
      }

      final chosen = await _showModeSelectionDialog();
      if (chosen == null) return;
      final mode = (chosen == 'ds4') ? 'ds4' : 'x360';

      if (isDebug) {
        final isReady = await _serverService.isServerResponding(port);
        if (!mounted) return;
        if (!isReady) {
          showDialog(
            context: context,
            builder: (context) => const AppErrorWidget(
              title: 'Erro de Conexão',
              message:
                  'Não foi possível conectar ao servidor em execução na porta informada.',
            ),
          );
          return;
        }
        _navigateToHome(port, mode);
        return;
      }

      final result = await _serverService.startServer(
        port: port,
        slots: 4,
        fixed: true,
        controllerMode: mode,
      );

      if (!mounted) return;

      if (result.isSuccess) {
        _navigateToHome(port, mode);
      } else {
        _showStartupErrorDialog(result);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToHome(int port, String mode) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, secondaryAnimation) => HomePageScreen(
          host: '127.0.0.1',
          port: port,
          initialControllerMode: mode,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var tween = Tween(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeInOut));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
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
                      onPressed: () => _handleStartup(isDebug: false),
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
                        onPressed: () => _handleStartup(isDebug: true),
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
                  side: BorderSide(color: AppColors.textPrimary, width: 2),
                ),
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
              : AppColors.textPrimary);

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
