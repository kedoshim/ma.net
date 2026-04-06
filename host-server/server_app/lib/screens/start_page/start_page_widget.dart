import 'dart:io';
import 'dart:ui';
import 'package:server_app/screens/home_page/home_page_widget.dart';
import 'package:server_app/services/server_process_service.dart';
import 'package:styled_divider/styled_divider.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'start_page_model.dart';
export 'start_page_model.dart';

Future<void> waitUntilServerReady(int port) async {
  final client = HttpClient();

  for (int i = 0; i < 10; i++) {
    try {
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:$port/api/server/status'),
      );

      final response = await request.close();

      if (response.statusCode == 200) return;
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 500));
  }
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

  final TextEditingController _portController =
    TextEditingController(text: '8765');

  final scaffoldKey = GlobalKey<ScaffoldState>();

  final _serverService = ServerProcessService();

  @override
  void initState() {
    super.initState();
    _model = StartPageModel();
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
        backgroundColor: AppTheme.primaryBackground,
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
                      final slots = int.parse(_model.dropDownValue1 ?? '1');
                      final fixed = _model.checkboxValue ?? false;

                      final modeMap = {
                        'modo padrao': 'mixed',
                        'd•input': 'ds4',
                        'only x•input': 'x360',
                      };

                      final mode = modeMap[_model.dropDownValue2 ?? 'modo padrao']!;

                      final port = int.tryParse(_portController.text) ?? 8765;

                      if (port < 1024 || port > 65535) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Porta inválida'),
                          ),
                        );
                        return;
                      }

                      await _serverService.startServer(
                        port: port,
                        slots: slots,
                        fixed: fixed,
                        controllerMode: mode,
                      );
                      await waitUntilServerReady(port);

                      if (!mounted) return;

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
                      backgroundColor: AppTheme.primaryBackground,
                      foregroundColor: AppTheme.primaryText,
                      side: const BorderSide(
                        color: AppTheme.primaryText,
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
                                              child: DropdownButtonFormField<String>(
                                                initialValue: _model.dropDownValue1 ?? '1',
                                                items: ['1', '2', '3', '4', '5', '6', '7', '8']
                                                    .map((e) => DropdownMenuItem(
                                                          value: e,
                                                          child: Text(e),
                                                        ))
                                                    .toList(),
                                                onChanged: (val) {
                                                  setState(() {
                                                    _model.dropDownValue1 = val;
                                                  });
                                                },
                                                decoration: const InputDecoration(
                                                  border: InputBorder.none,
                                                ),
                                                style: AppTheme.bodyMedium.copyWith(
                                                  fontFamily: 'pico',
                                                  letterSpacing: 0.0,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ]
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        'jogadores',
                                        style: AppTheme.bodyMedium.copyWith(
                                          fontFamily: 'pico',
                                          letterSpacing: 0.0,
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
                                            borderRadius:
                                                BorderRadius.circular(4.0),
                                          ),
                                        ),
                                        unselectedWidgetColor: AppTheme.primaryText,
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
                                          color: AppTheme.primaryText,
                                        ),
                                        activeColor: AppTheme.primaryText,
                                        checkColor: AppTheme.primaryBackground,
                                      ),
                                    ),
                                    Text(
                                      'fixo',
                                      style: AppTheme.bodyMedium.copyWith(
                                        fontFamily: 'pico',
                                        letterSpacing: 0.0,
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
                                        ),
                                      ),
                                    ),
                                  ]
                                )
                              )
                            ]
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
                                initialValue: _model.dropDownValue2 ?? 'modo padrao',
                                items: ['modo padrao', 'd•input', 'only x•input']
                                    .map((e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(e),
                                        ))
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
