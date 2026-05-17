import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:server_app/screens/home_page/gamepad_state.dart';
import 'package:server_app/screens/home_page/gamepad_handler_widget.dart';

import '../../theme/app_theme.dart';
import '../../services/host_api_service.dart';
import '../../services/server_process_service.dart';
import '../../services/sound_effect_service.dart';
import '../start_page/start_page_widget.dart';
import '../../theme/app_colors.dart';
import '../../widgets/server_options_popup.dart';

class HomePageScreen extends StatelessWidget {
  final String host;
  final int port;

  const HomePageScreen({super.key, required this.host, required this.port});

  @override
  Widget build(BuildContext context) {
    final api = HostApiService(host: host, port: port);

    return ChangeNotifierProvider(
      create: (_) => GamepadState(api)..initialize(),
      child: HomePageWidget(host: host, port: port),
    );
  }
}

class HomePageWidget extends StatefulWidget {
  final String host;
  final int port;

  const HomePageWidget({super.key, required this.host, required this.port});

  @override
  State<HomePageWidget> createState() => _HomePageWidgetState();
}

class _HomePageWidgetState extends State<HomePageWidget> {
  final scaffoldKey = GlobalKey<ScaffoldState>();

  late final HostApiService _api;

  ConnectionInfo? connectionInfo;
  bool isLoadingConnection = true;
  ColorTheme _currentTheme = ColorTheme.blue;

  @override
  void initState() {
    super.initState();
    SoundEffectService.instance.init();
    _api = HostApiService(host: widget.host, port: widget.port);
    loadConnectionInfo();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeName = prefs.getString('selected_theme');
      if (themeName != null) {
        final theme = ColorTheme.values.firstWhere(
          (e) => e.name == themeName,
          orElse: () => ColorTheme.blue,
        );
        if (mounted) {
          setState(() {
            _currentTheme = theme;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> loadConnectionInfo() async {
    try {
      final info = await _api.fetchConnectionInfo();

      if (!mounted) return;

      setState(() {
        connectionInfo = info;
        isLoadingConnection = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoadingConnection = false;
      });
    }
  }

  @override
  void dispose() {
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
        body: SafeArea(
          top: true,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Align(
                alignment: AlignmentDirectional(-1.0, 0.0),
                child: Container(
                  decoration: BoxDecoration(),
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      50.0,
                      40.0,
                      0.0,
                      0.0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                            10.0,
                            0.0,
                            0.0,
                            0.0,
                          ),
                          child: Text(
                            'ma•net',
                            style: AppTheme.bodyMedium.copyWith(
                              fontFamily: 'pico',
                              fontSize: 40.0,
                              letterSpacing: 0.0,
                            ),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          iconSize: 30.0,
                          icon: const Icon(
                            Icons.settings,
                            color: AppColors.textPrimary,
                          ),
                          onPressed: () {
                            SoundEffectService.instance.playOptionsButton();
                            showDialog(
                              context: context,
                              builder: (context) => ServerOptionsPopup(
                                currentTheme: _currentTheme,
                                onThemeChanged: (theme) async {
                                  setState(() => _currentTheme = theme);
                                  try {
                                    final prefs =
                                        await SharedPreferences.getInstance();
                                    await prefs.setString(
                                      'selected_theme',
                                      theme.name,
                                    );
                                  } catch (_) {}
                                },
                              ),
                            );
                          },
                        ),
                        IconButton(
                          iconSize: 30.0,
                          icon: const Icon(
                            Icons.power_settings_new_rounded,
                            color: AppColors.textPrimary,
                          ),
                          onPressed: () async {
                            print('Turning off ...');

                            await ServerProcessService.instance.stopServer();

                            if (!mounted) return;

                            Navigator.of(context).pushAndRemoveUntil(
                              PageRouteBuilder(
                                pageBuilder:
                                    (context, animation, secondaryAnimation) =>
                                        const StartPageWidget(),
                                transitionsBuilder:
                                    (
                                      context,
                                      animation,
                                      secondaryAnimation,
                                      child,
                                    ) {
                                      const begin = Offset(-1.0, 0.0);
                                      const end = Offset.zero;
                                      const curve = Curves.easeInOutCubic;
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
                              (route) => false,
                            );
                          },
                        ),
                        SizedBox(width: 50),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  width: MediaQuery.sizeOf(context).width * 1.0,
                  decoration: BoxDecoration(),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                            50.0,
                            50.0,
                            50.0,
                            50.0,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Expanded(
                                child: AdaptiveStageLayout(
                                  connectionInfo: connectionInfo,
                                  qrCodeUrl: _api.getQrCodeUrl(),
                                  isLoadingConnection: isLoadingConnection,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
