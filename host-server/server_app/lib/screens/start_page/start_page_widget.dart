import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:server_app/screens/home_page/home_page_widget.dart';
import 'package:server_app/services/server_process_service.dart';
import 'package:styled_divider/styled_divider.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import 'start_page_model.dart';
export 'start_page_model.dart';

Future<bool> waitUntilServerReady(int port) async {
  final client = HttpClient();

  for (int i = 0; i < 10; i++) {
    try {
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:$port/api/server/status'),
      );

      final response = await request.close();

      if (response.statusCode == 200) return true;
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 500));
  }
  return false;
}

Future<bool> isServerRunning(int port) async {
  final client = HttpClient();
  client.connectionTimeout = const Duration(milliseconds: 500);
  try {
    final request = await client.getUrl(
      Uri.parse('http://127.0.0.1:$port/api/server/status'),
    );
    final response = await request.close().timeout(
      const Duration(milliseconds: 500),
    );
    return response.statusCode == 200;
  } catch (_) {
    return false;
  } finally {
    client.close();
  }
}

Future<void> killExistingServer(int port) async {
  try {
    if (Platform.isWindows) {
      final result = await Process.run('cmd', [
        '/c',
        'netstat -ano | findstr :$port',
      ]);
      final lines = result.stdout.toString().split('\n');
      for (var line in lines) {
        if (line.contains('LISTENING')) {
          final parts = line.trim().split(RegExp(r'\s+'));
          if (parts.isNotEmpty) {
            final pid = parts.last;
            await Process.run('taskkill', ['/F', '/PID', pid]);
          }
        }
      }
    } else {
      await Process.run('sh', [
        '-c',
        'fuser -k $port/tcp || lsof -t -i:$port | xargs kill -9',
      ]);
    }
    await Future.delayed(const Duration(seconds: 1));
  } catch (_) {}
}

class StartPageWidget extends StatefulWidget {
  const StartPageWidget({super.key});

  static String routeName = 'StartPage';
  static String routePath = '/startPage';

  @override
  State<StartPageWidget> createState() => _StartPageWidgetState();
}

class _StartPageWidgetState extends State<StartPageWidget> {
  late StartPageModel _model;

  final TextEditingController _portController = TextEditingController(
    text: '8765',
  );

  final scaffoldKey = GlobalKey<ScaffoldState>();

  final _serverService = ServerProcessService.instance;

  @override
  void initState() {
    super.initState();
    _model = StartPageModel();
    _loadTheme();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDriverAndShowDialog();
    });
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
        AppColors.setTheme(theme);
        if (mounted) {
          setState(() {});
        }
      }
    } catch (_) {}
  }

  Future<void> _checkDriverAndShowDialog() async {
    if (Platform.isWindows) {
      final isInstalled = await _isDriverInstalled();
      if (!isInstalled && mounted) {
        _showDriverInstallDialog();
      }
    }
  }

  Future<bool> _isDriverInstalled() async {
    try {
      print('[DRIVER CHECK] Executing: sc query ViGEmBus');
      final result = await Process.run('cmd', ['/c', 'sc query ViGEmBus']);
      final output = result.stdout.toString() + result.stderr.toString();
      print('[DRIVER CHECK] Exit code: ${result.exitCode}');
      print('[DRIVER CHECK] Output:\n$output');
      
      final lowerOutput = output.toLowerCase();
      if (result.exitCode != 0 || 
          output.contains('1060') || 
          lowerOutput.contains('does not exist') ||
          lowerOutput.contains('falha') ||
          lowerOutput.contains('não existe') ||
          lowerOutput.contains('stopped')) {
        print('[DRIVER CHECK] Driver not found (service query failed).');
        return false;
      }
      print('[DRIVER CHECK] Driver is installed.');
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
        body: SafeArea(
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
                      final slots = int.parse(_model.dropDownValue1 ?? '4');
                      final fixed = _model.checkboxValue ?? false;

                      final modeMap = {
                        'modo padrao': 'mixed',
                        'd•input': 'ds4',
                        'only x•input': 'x360',
                      };

                      final mode =
                          modeMap[_model.dropDownValue2 ?? 'modo padrao']!;

                      final port = int.tryParse(_portController.text) ?? 8765;

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
                            duration: const Duration(seconds: 2),
                          ),
                        );
                        await killExistingServer(port);
                      } else {
                        try {
                          // Testa se a porta está ocupada por um processo desconhecido
                          final socket = await ServerSocket.bind(
                            InternetAddress.loopbackIPv4,
                            port,
                          );
                          await socket.close();
                        } catch (e) {
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
                        // Re-trigger the driver check to immediately pop up the dialog if missing
                        await _checkDriverAndShowDialog();
                        return; // DO NOT PROGRESS TO THE HOME PAGE
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HomePageScreen(
                            host: '127.0.0.1',
                            port: 8765,
                          ),
                        ),
                      );
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
                    child: Text(
                      'iniciar',
                      style: AppTheme.titleSmall.copyWith(
                        fontFamily: 'pico',
                        letterSpacing: 0.0,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Container(
                          decoration: BoxDecoration(),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Container(
                                width: 140,
                                height: 50.0,
                                decoration: BoxDecoration(),
                                child: Row(
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    Flexible(
                                      flex: 2,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.max,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Flexible(
                                            child: Container(
                                              width: 40,
                                              decoration: BoxDecoration(),
                                              child:
                                                  DropdownButtonFormField<
                                                    String
                                                  >(
                                                    dropdownColor: AppColors.screenBackground,
                                                    initialValue:
                                                        _model.dropDownValue1 ??
                                                        '4',
                                                    items:
                                                        [
                                                              '1',
                                                              '2',
                                                              '3',
                                                              '4',
                                                              '5',
                                                              '6',
                                                              '7',
                                                              '8',
                                                            ]
                                                            .map(
                                                              (e) =>
                                                                  DropdownMenuItem(
                                                                    value: e,
                                                                    child: Text(
                                                                      e,
                                                                    ),
                                                                  ),
                                                            )
                                                            .toList(),
                                                    onChanged: (val) {
                                                      setState(() {
                                                        _model.dropDownValue1 =
                                                            val;
                                                      });
                                                    },
                                                    decoration:
                                                        const InputDecoration(
                                                          border:
                                                              InputBorder.none,
                                                        ),
                                                    style: AppTheme.bodyMedium
                                                        .copyWith(
                                                          fontFamily: 'pico',
                                                          letterSpacing: 0.0,
                                                          color: AppColors.textPrimary,
                                                        ),
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        'jogadores',
                                        style: AppTheme.bodyMedium.copyWith(
                                          fontFamily: 'pico',
                                          letterSpacing: 0.0,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 100.0,
                                height: 50.0,
                                decoration: BoxDecoration(),
                                child: Row(
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    Theme(
                                      data: ThemeData(
                                        checkboxTheme: CheckboxThemeData(
                                          visualDensity: VisualDensity.compact,
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              4.0,
                                            ),
                                          ),
                                        ),
                                        unselectedWidgetColor:
                                            AppColors.textPrimary,
                                      ),
                                      child: Checkbox(
                                        value: _model.checkboxValue ??= false,
                                        onChanged: (newValue) {
                                          setState(() {
                                            _model.checkboxValue = newValue;
                                          });
                                        },
                                        side: BorderSide(
                                          width: 2,
                                          color: AppColors.textPrimary,
                                        ),
                                        activeColor: AppColors.textPrimary,
                                        checkColor: AppColors.screenBackground,
                                      ),
                                    ),
                                    Text(
                                      'fixo',
                                      style: AppTheme.bodyMedium.copyWith(
                                        fontFamily: 'pico',
                                        letterSpacing: 0.0,
                                          color: AppColors.textPrimary,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 0,
                                      child: TextFormField(
                                        controller: _portController,
                                        keyboardType: TextInputType.number,
                                        style: AppTheme.bodyMedium.copyWith(
                                          fontFamily: 'pico',
                                          letterSpacing: 0.0,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        width: 130,
                        height: 50.0,
                        decoration: BoxDecoration(),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              width: 230,
                              decoration: BoxDecoration(),
                              child: DropdownButtonFormField<String>(
                                dropdownColor: AppColors.screenBackground,
                                initialValue:
                                    _model.dropDownValue2 ?? 'modo padrao',
                                items:
                                    ['modo padrao', 'd•input', 'only x•input']
                                        .map(
                                          (e) => DropdownMenuItem(
                                            value: e,
                                            child: Text(e),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _model.dropDownValue2 = val;
                                  });
                                },
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                ),
                                style: AppTheme.bodyMedium.copyWith(
                                  fontFamily: 'pico',
                                  letterSpacing: 0.0,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
