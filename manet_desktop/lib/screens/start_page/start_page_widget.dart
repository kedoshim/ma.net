import 'dart:math' as math;
import 'package:manet_desktop/screens/home_page/home_page_widget.dart';
import 'package:manet_desktop/services/server_process_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../services/sound_effect_service.dart';
import 'start_page_model.dart';
import '../../widgets/player_face_indicator.dart';
import '../../models/player_face.dart';
import '../../widgets/app_error_widget.dart';
import 'mode_selection_dialog.dart';

class StartPageWidget extends StatefulWidget {
  const StartPageWidget({super.key});

  @override
  State<StartPageWidget> createState() => _StartPageWidgetState();
}

class _StartPageWidgetState extends State<StartPageWidget> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  late StartPageModel _model;
  Offset _globalMousePos = Offset.zero;

  final TextEditingController _portController = TextEditingController(
    text: '8765',
  );
  bool _isLoading = false;
  String _appVersion = '';
  final ServerProcessService _serverService = ServerProcessService.instance;

  @override
  void initState() {
    super.initState();
    _model = StartPageModel();
    _loadTheme();
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = info.version;
      });
    } catch (_) {}
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString('selected_theme');
    if (themeName != null) {
      final theme = ColorTheme.values.firstWhere(
        (e) => e.name == themeName,
        orElse: () => ColorTheme.blue,
      );
      setState(() {
        AppColors.setTheme(theme);
      });
    }
  }

  Future<String?> _showModeSelectionDialog() async {
    return await Navigator.push<String>(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const ModeSelectionPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
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
      child: MouseRegion(
        onHover: (e) => setState(() => _globalMousePos = e.position),
        child: Scaffold(
          key: scaffoldKey,
          backgroundColor: AppColors.screenBackground,
          body: Stack(
            children: [
              Row(
                children: [
                  Expanded(flex: 1, child: _buildLeftPanel()),
                  Expanded(
                    flex: 2,
                    child: MascotWidget(
                      globalMousePos: _globalMousePos,
                      colors: const [
                        Color(0xFFFF6B6B),
                        Color(0xFFFFA94D),
                        Color(0xFFFFE066),
                        Color(0xFF8CE99A),
                        Color(0xFF66D9E8),
                        Color(0xFF74C0FC),
                        Color(0xFFA78BFA),
                        Color(0xFFF783AC),
                      ],
                      faces: const [
                        ':)',
                        ':D',
                        'X)',
                        ':P',
                        ':o',
                        '^-^',
                        ';)',
                        'B)',
                        ':3',
                        ':]',
                        ':>',
                        '=)',
                        '=D',
                        '=P',
                        '=3',
                        '8)',
                        '8D',
                        'XD',
                        'xD',
                        'XP',
                        'xP',
                        ':c',
                        ':(',
                        ':/',
                        ':|',
                        ':*',
                        ':\$',
                        'o_o',
                        'O_O',
                        '0_0',
                        '>_<',
                        '-_-',
                        'u_u',
                        'UwU',
                        'OwO',
                        'T_T',
                        'Q_Q',
                        '@_@',
                        '*_*',
                        '^o^',
                        '^.^',
                        '^w^',
                        '>:)',
                        '<:)',
                        ':v',
                        ':7',
                        ':9',
                        '._.',
                        '._o',
                        '>_>',
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                bottom: 16,
                right: 24,
                child: Text(
                  'v$_appVersion',
                  style: AppTheme.bodyMedium.copyWith(
                    fontFamily: 'momo',
                    fontSize: 14,
                    color: AppColors.textPrimary.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeftPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 64.0),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: AppColors.textPrimary.withValues(alpha: 0.1),
            width: 2,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ma•net',
            style: AppTheme.titleLarge.copyWith(
              fontFamily: 'momo',
              fontSize: 72,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -2,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 48,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.highlightColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const Spacer(),
          PlayfulButton(
            text: 'iniciar a festa',
            isLoading: _isLoading,
            onPressed: () => _handleStartup(isDebug: false),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 16),
            PlayfulButton(
              text: 'iniciar debug',
              isLoading: false,
              isSmall: true,
              onPressed: () => _handleStartup(isDebug: true),
            ),
          ],
          const SizedBox(height: 32),
          Row(
            children: [
              PlayfulIconButton(icon: FontAwesomeIcons.discord, onTap: () {}),
              const SizedBox(width: 16),
              PlayfulIconButton(icon: FontAwesomeIcons.github, onTap: () {}),
            ],
          ),
          const Spacer(),
          _buildColorSelectors(),
        ],
      ),
    );
  }

  Widget _buildColorSelectors() {
    return Row(
      children: ColorTheme.values.map((theme) {
        final themeData = AppColors.getTheme(theme);
        final isSelected = AppColors.screenBackground == themeData.background;

        return Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () async {
                setState(() {
                  AppColors.setTheme(theme);
                });

                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('selected_theme', theme.name);

                try {
                  SoundEffectService.instance.playThemeSelect();
                } catch (_) {}
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: isSelected ? 36 : 28,
                height: isSelected ? 36 : 28,
                decoration: BoxDecoration(
                  color: themeData.background,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.textPrimary,
                    width: isSelected ? 4 : 2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.textPrimary.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class PlayfulButton extends StatefulWidget {
  final String text;
  final bool isLoading;
  final VoidCallback onPressed;
  final bool isSmall;

  const PlayfulButton({
    super.key,
    required this.text,
    required this.isLoading,
    required this.onPressed,
    this.isSmall = false,
  });

  @override
  State<PlayfulButton> createState() => _PlayfulButtonState();
}

class _PlayfulButtonState extends State<PlayfulButton>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final scale = _isPressed ? 0.92 : (_isHovered ? 1.04 : 1.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onPressed();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()..scale(scale),
          transformAlignment: Alignment.center,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.highlightColor,
              borderRadius: BorderRadius.circular(widget.isSmall ? 16 : 24),
              border: Border.all(
                color: AppColors.textPrimary,
                width: widget.isSmall ? 3 : 5,
              ),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: widget.isSmall ? 24 : 40,
              vertical: widget.isSmall ? 16 : 24,
            ),
            child: widget.isLoading
                ? SizedBox(
                    width: widget.isSmall ? 16 : 28,
                    height: widget.isSmall ? 16 : 28,
                    child: CircularProgressIndicator(
                      color: AppColors.textPrimary,
                      strokeWidth: 4,
                    ),
                  )
                : Text(
                    widget.text,
                    style: AppTheme.titleMedium.copyWith(
                      fontFamily: 'momo',
                      fontSize: widget.isSmall ? 20 : 32,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class PlayfulIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const PlayfulIconButton({super.key, required this.icon, required this.onTap});

  @override
  State<PlayfulIconButton> createState() => _PlayfulIconButtonState();
}

class _PlayfulIconButtonState extends State<PlayfulIconButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final scale = _isPressed ? 0.9 : (_isHovered ? 1.1 : 1.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()..scale(scale),
          transformAlignment: Alignment.center,
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.textPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.textPrimary, width: 3),
          ),
          child: Icon(
            widget.icon,
            color: _isHovered
                ? AppColors.screenBackground
                : AppColors.textPrimary,
            size: 28,
          ),
        ),
      ),
    );
  }
}

class MascotWidget extends StatefulWidget {
  final List<Color> colors;
  final List<String> faces;
  final Offset globalMousePos;

  const MascotWidget({
    super.key,
    required this.colors,
    required this.faces,
    required this.globalMousePos,
  });

  @override
  State<MascotWidget> createState() => _MascotWidgetState();
}

class _MascotWidgetState extends State<MascotWidget>
    with TickerProviderStateMixin {
  late AnimationController _popController;
  late AnimationController _tickController;

  int _faceIndex = 0;
  int _colorIndex = 0;
  final double _mascotSize = 400.0;

  Offset _currentOffset = Offset.zero;
  Offset _lastOffset = Offset.zero;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _tickController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..repeat();

    _faceIndex = _random.nextInt(widget.faces.length);
    _colorIndex = _random.nextInt(widget.colors.length);
  }

  @override
  void dispose() {
    _popController.dispose();
    _tickController.dispose();
    super.dispose();
  }

  void _onTap() {
    int newFace;
    int newColor;

    // Garante que não repita a face ou a cor anterior
    do {
      newFace = _random.nextInt(widget.faces.length);
    } while (newFace == _faceIndex);

    do {
      newColor = _random.nextInt(widget.colors.length);
    } while (newColor == _colorIndex);

    setState(() {
      _faceIndex = newFace;
      _colorIndex = newColor;
    });

    _popController.forward(from: 0.0);
    try {
      SoundEffectService.instance.playDropPlayer();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_popController, _tickController]),
      builder: (context, child) {
        final renderBox = context.findRenderObject() as RenderBox?;
        final center = renderBox != null
            ? renderBox.localToGlobal(
                Offset(renderBox.size.width / 2, renderBox.size.height / 2),
              )
            : Offset.zero;

        var delta = widget.globalMousePos - center;

        // Lógica de movimento 2D flat (estilo analógico)
        const maxTravel = 90.0;
        Offset targetOffset;
        if (delta.distance > 800) {
          targetOffset = Offset.zero;
        } else {
          // Clamping independente para X e Y para permitir um alcance mais quadrado
          targetOffset = Offset(
            delta.dx.clamp(-maxTravel, maxTravel),
            delta.dy.clamp(-maxTravel, maxTravel),
          );
        }

        // Interpolação suave (Spring logic)
        _currentOffset = Offset(
          _currentOffset.dx + (targetOffset.dx - _currentOffset.dx) * 0.18,
          _currentOffset.dy + (targetOffset.dy - _currentOffset.dy) * 0.18,
        );

        // Física de wobble: reação à velocidade do movimento
        final velocity = _currentOffset - _lastOffset;
        _lastOffset = _currentOffset;

        final wobbleX = velocity.dx * 0.45;
        final wobbleY = velocity.dy * 0.45;

        // Física de clique (pop/squash)
        final t = _popController.value;
        final bounce = math.sin(t * math.pi * 3) * (1 - t);
        final scaleX = 1.0 + bounce * 0.18;
        final scaleY = 1.0 - bounce * 0.18;

        return Center(
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _onTap,
              child: Container(
                width: _mascotSize,
                height: _mascotSize,
                decoration: BoxDecoration(
                  color: AppColors.lightColor,
                  borderRadius: BorderRadius.circular(_mascotSize * 0.25),
                  border: Border.all(color: AppColors.textPrimary, width: 10),
                ),
                child: Center(
                  child: Transform(
                    transform: Matrix4.identity()
                      ..translate(_currentOffset.dx, _currentOffset.dy)
                      ..scale(scaleX, scaleY),
                    alignment: Alignment.center,
                    child: PlayerFaceIndicator(
                      face: PlayerFaceData(
                        color:
                            widget.colors[_colorIndex % widget.colors.length],
                        faceText:
                            widget.faces[_faceIndex % widget.faces.length],
                        rotation: PlayerFaceRotation.normal,
                      ),
                      size: _mascotSize * 0.45,
                      roundedSquare: false,
                      faceTranslateX: wobbleX,
                      faceTranslateY: wobbleY,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
