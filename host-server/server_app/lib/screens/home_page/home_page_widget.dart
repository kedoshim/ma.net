import 'dart:ui';
import 'package:server_app/screens/home_page/gamepad_handler_widget.dart';
import 'package:server_app/screens/home_page/qr_code_container.dart';
import 'package:styled_divider/styled_divider.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/host_api_service.dart';

// Helper function to insert dividers between list items
List<Widget> divideList(List<Widget> items, Widget divider) {
  if (items.isEmpty) return items;
  List<Widget> result = [];
  for (int i = 0; i < items.length; i++) {
    result.add(items[i]);
    if (i < items.length - 1) {
      result.add(divider);
    }
  }
  return result;
}

class HomePageWidget extends StatefulWidget {
  const HomePageWidget({super.key});

  static String routeName = 'HomePage';
  static String routePath = '/homePage';

  @override
  State<HomePageWidget> createState() => _HomePageWidgetState();
}

class _HomePageWidgetState extends State<HomePageWidget> {
  final scaffoldKey = GlobalKey<ScaffoldState>();

  final HostApiService _api = HostApiService();

  ConnectionInfo? connectionInfo;
  bool isLoadingConnection = true;

  @override
  void initState() {
    super.initState();
    loadConnectionInfo();
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
        backgroundColor: AppTheme.primaryBackground,
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
                      crossAxisAlignment: CrossAxisAlignment.end,
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
                        IconButton(
                          iconSize: 35.0,
                          icon: Icon(
                            Icons.power_settings_new_rounded,
                            color: AppTheme.primaryText,
                          ),
                          onPressed: () {
                            print('IconButton pressed ...');
                          },
                        ),
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
                            0.0,
                            50.0,
                            50.0,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // LEFT SIDE
                              gamepadHandlerWidget(context),
                              const SizedBox(width: 25),
                              // RIGHT SIDE
                              isLoadingConnection
                              ? const CircularProgressIndicator()
                              : connectionMethodsContainer(
                                  connectionInfo?.url ?? "Unavailable",
                                  qrCodeUrl: _api.getQrCodeUrl(),
                                )
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
