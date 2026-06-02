import 'strings.dart';

class EnUsStrings implements AppStrings {
  @override
  final CommonStrings common = EnUsCommonStrings();
  @override
  final StartPageStrings startPage = EnUsStartPageStrings();
  @override
  final ModeSelectionStrings modeSelection = EnUsModeSelectionStrings();
  @override
  final ErrorStrings error = EnUsErrorStrings();
  @override
  final LobbyStrings lobby = EnUsLobbyStrings();
  @override
  final HomeStrings home = EnUsHomeStrings();
  @override
  final SettingsStrings settings = EnUsSettingsStrings();
  @override
  final SlotsStrings slots = EnUsSlotsStrings();
  @override
  final PlayersStrings players = EnUsPlayersStrings();
  @override
  final LayoutEditorStrings layoutEditor = EnUsLayoutEditorStrings();
  @override
  final AlertsStrings alerts = EnUsAlertsStrings();
  @override
  final QrPanelStrings qrPanel = EnUsQrPanelStrings();
}

class EnUsCommonStrings implements CommonStrings {
  @override
  String get cancel => 'Cancel';
  @override
  String get confirm => 'Confirm';
  @override
  String get save => 'Save';
  @override
  String get error => 'Error';
  @override
  String get success => 'Success';
  @override
  String get ok => 'OK';
  @override
  String get delete => 'Delete';
  @override
  String get close => 'Close';
}

class EnUsStartPageStrings implements StartPageStrings {
  @override
  String get appTitle => 'ma•net';
  @override
  String get startParty => 'start the party!';
  @override
  String get startDebug => 'start debug';
  @override
  String version(String v) => 'v$v';
}

class EnUsModeSelectionStrings implements ModeSelectionStrings {
  @override
  String get title => 'get the party ready!';
  @override
  String get subtitle => 'How should your phones be recognized by the PC?';
  @override
  String get xinputTitle => 'x•input';
  @override
  String get xinputHeadline => 'Recommended: up to 4 players';
  @override
  String get xinputDetails => 'High compatibility and rumble support.';
  @override
  String get dinputTitle => 'd•Input';
  @override
  String get dinputHeadline => 'Ideal for: 5+ players';
  @override
  String get dinputDetails => 'No limits, but no rumble support.';
  @override
  String get cancel => 'Cancel';
  @override
  String get play => 'let\'s play!';
}

class EnUsErrorStrings implements ErrorStrings {
  @override
  String get startupTitle => 'Oops! Startup Failed';
  @override
  String get installDriver => 'Install Driver';
  @override
  String get installDriverErrorTitle => 'Installation Error';
  @override
  String get installDriverErrorMessage => 'Could not find the ViGEmBus installer.';
  @override
  String get invalidPortTitle => 'Invalid Port';
  @override
  String get invalidPortMessage => 'That port won\'t work. Choose a number between 1024 and 65535.';
  @override
  String get connectionErrorTitle => 'Connection Error';
  @override
  String get connectionErrorMessage => 'Couldn\'t connect to the server on that port.';
  @override
  String get applyConfigErrorTitle => 'Error saving settings';
  @override
  String applyConfigErrorMessage(String error) => 'Failed to apply server settings: $error';
  @override
  String get layoutImportErrorTitle => 'Import Error';
  @override
  String get layoutImportErrorMessage => 'Failed to import the layout file.';
  @override
  String get noLogs => 'No logs.';
  @override
  String get retry => 'Try again';
  @override
  String get logsCopied => 'Logs copied to clipboard!';
  @override
  String get copyLogs => 'Copy Logs';
  @override
  String get selectPresetErrorTitle => 'Error selecting layout';
  @override
  String selectPresetErrorMessage(String error) => 'Failed to select layout: $error';
  @override
  String get loadPresetsErrorTitle => 'Error loading layouts';
  @override
  String loadPresetsErrorMessage(String error) => 'Failed to load layout catalog: $error';
  @override
  String get applyModeErrorTitle => 'Error applying mode';
  @override
  String applyModeErrorBody(String error) => 'Failed to apply mode: $error';
}

class EnUsLobbyStrings implements LobbyStrings {
  @override
  String get lockTooltipReserve => 'New players wait on the bench';
  @override
  String get lockTooltipAuto => 'New players get a controller automatically';
  @override
  String get xinput => 'x•input';
  @override
  String get dinput => 'd•input';
}

class EnUsHomeStrings implements HomeStrings {
  @override
  String get waitingPlayers => 'Waiting for players...';
  @override
  String get qrCodeTitle => 'Connect your controller!';
  @override
  String get joinIn => 'Join in :)';
  @override
  String get qrCodeInstruction => 'Scan this QR Code with your phone or visit the link in your browser:';
  @override
  String get qrCodeNetworkError => 'No local network connection';
  @override
  String get qrCodeNetworkErrorDetails => 'Make sure your computer is connected to the network.';
  @override
  String get qrCodeModeTip => 'Tip: switch between XInput and DInput if needed.';
  @override
  String get onboardingTitle => 'Welcome to ma.net! :D';
  @override
  String get onboardingSubtitle => 'Turn your phones into game controllers and play together!';
  @override
  String get onboardingNext => 'Next';
  @override
  String get onboardingDone => 'Start';
  @override
  String get onboardingSkip => 'Skip';
  @override
  String get onboardingBack => 'Back';
  @override
  String get onboardingStepConnectTitle => 'Connect to the same network';
  @override
  String get onboardingStepConnectBody => 'Your phone and computer must be on the same network to talk.';
  @override
  String get onboardingStepArrangeTitle => 'Point at the QR Code';
  @override
  String get onboardingStepArrangeBody => 'Open your phone camera or scanner app and scan the code on screen.';
  @override
  String get onboardingStepPlayTitle => 'Play 🎉';
  @override
  String get onboardingStepPlayBody => 'Ready! Now just call your friends, choose your controller, and start playing.';
  @override
  String get wifiOffTitle => 'Computer disconnected from network';
  @override
  String get wifiOffBody => 'Please connect to a network to continue using controllers.';
  @override
  String get removeControllersTitle => 'Remove controllers?';
  @override
  String get removeControllersBody => 'Removing controllers may disconnect active players.';
  @override
  String get selectModeBarrierLabel => 'Select Mode';
  @override
  String get wifi => 'Wi-Fi';
  @override
  String get ethernet => 'Ethernet (Cable)';
  @override
  String get hotspot => 'Hotspot';
  @override
  String get newNetwork => 'New Network';
}

class EnUsSettingsStrings implements SettingsStrings {
  @override
  String get title => 'Options';
  @override
  String get colorsTitle => 'ma.net colors';
  @override
  String get timeoutTitle => 'Hold slots for disconnected players';
  @override
  String timeoutValue(int minutes) => '$minutes min';
  @override
  String get languageTitle => 'Language';
}



class EnUsSlotsStrings implements SlotsStrings {
  @override
  String slotNumber(int index) => 'Slot $index';
  @override
  String get slotLocked => 'Locked';
  @override
  String get slotEmpty => 'Empty';
  @override
  String slotConnected(String name) => 'Player $name connected';
}

class EnUsPlayersStrings implements PlayersStrings {
  @override
  String connectedCount(int count) => count == 1 ? '1 player connected' : '$count players connected';
  @override
  String playerConnected(String name) => 'Player $name joined the lobby!';
  @override
  String get reserveBench => 'Reserves Bench';
  @override
  String get emptyBench => 'reserves bench';
}

class EnUsLayoutEditorStrings implements LayoutEditorStrings {
  @override
  String get title => 'Layout Editor';
  @override
  String get saveButton => 'Save Layout';
  @override
  String get resetButton => 'Reset to Default';
  @override
  String get browserTitle => 'Available Layouts';
  @override
  String get noLayouts => 'No custom layouts found.';
  @override
  String get importButton => 'Import Layout';
  @override
  String get exportButton => 'Export Layout';
  @override
  String get defaultLayoutName => 'Default';
  
  @override
  String get deleteLayoutTitle => 'Delete layout';
  @override
  String deleteLayoutConfirm(String name) => 'Do you want to delete "$name"?';
  @override
  String get createLayoutButton => 'Create layout';
  @override
  String get basicLayoutsTitle => 'Basic layouts';
  @override
  String get extraCustomLayoutsTitle => 'Extras and Custom';
  @override
  String get badgeGame => 'Game';
  @override
  String get badgeCustom => 'Custom';
  @override
  String get activeBadge => 'Active';
  @override
  String get editButton => 'Edit';
  @override
  String get deleteButton => 'Delete';
  
  @override
  String get defaultNewLayoutName => 'My Layout 001';
  @override
  String get nameHint => 'Layout Name';
  @override
  String get createButtonUpper => 'CREATE';
  @override
  String get saveButtonUpper => 'SAVE';
  
  @override
  String get movementModeTitle => 'MOVEMENT MODE';
  
  @override
  String get dpadLabel => 'D-Pad';
  @override
  String get dpadHeadline => 'Precise Digital';
  @override
  String get dpadDesc => 'Ideal for platformers and fighting games.';
  
  @override
  String get fixedJoystickLabel => 'Fixed Joystick';
  @override
  String get fixedJoystickHeadline => 'Static Analog';
  @override
  String get fixedJoystickDesc => 'Fixed position on screen for muscle memory.';
  
  @override
  String get floatingJoystickLabel => 'Floating Joystick';
  @override
  String get floatingJoystickHeadline => 'Dynamic';
  @override
  String get floatingJoystickDesc => 'Joystick appears wherever you touch.';
  
  @override
  String get visibleButtonsTitle => 'VISIBLE BUTTONS';
  @override
  String get visibleButtonsTip => 'Tap buttons to show or hide them in your layout.';
}

class EnUsAlertsStrings implements AlertsStrings {
  @override
  String get title => 'Alerts and Warnings';
  @override
  String get noAlerts => 'No alerts.';
  @override
  String get tooltip => 'Alerts and Warnings';
  @override
  String networkChangedAlert(String kindName, String address) => 'Network changed to $kindName (Address: $address)';
  @override
  String get networkChangedTitle => 'Network changed! :D';
  @override
  String networkChangedBody(String kindName) => 'Connection updated to $kindName.';
  @override
  String get view => 'View';
  @override
  String get xinputLimitWarning => 'Some games may not support more than 4 x•input controllers. If you run into issues, try d•input.';
}

class EnUsQrPanelStrings implements QrPanelStrings {
  @override
  Map<String, String> get textMap => const {
    'connection_label_this_device': 'This device',
    'connection_label_wifi': 'Wi-Fi',
    'connection_label_ethernet': 'Cable',
    'connection_label_hotspot': 'Hotspot',
    'connection_label_backup': 'Extra',
    'ui_more_connections': 'Other ways to connect',
    'ui_more': 'More',
    'ui_copied': 'Link copied',
    'ui_chip_selected': 'On screen',
    'ui_chip_recommended': 'Best pick',
    'ui_chip_preferred': 'Saved',
    'ui_chip_last_success': 'Worked',
    'ui_use_this': 'Use this',
    'ui_showing': 'Showing',
    'ui_connection_fallback': 'Connection',
    'ui_connection_hint_wifi': 'Phones join through the same Wi-Fi.',
    'ui_connection_hint_hotspot': 'Good when your computer shares the signal.',
    'ui_connection_hint_ethernet': 'Helpful when the PC is on cable internet.',
    'ui_connection_hint_backup': 'Worth a try if the first one does not work.',
    'diag_button_label': 'Help',
    'diag_sheet_title': 'Connection helper',
    'diag_sheet_healthy': 'Everything looks ready to play.',
    'diag_sheet_attention': 'A few things may be getting in the way.',
    'diag_action_refresh': 'Refresh',
    'diag_action_copy_link': 'Copy link',
    'diag_action_firewall': 'Open Firewall',
    'diag_action_firewall_advanced': 'Advanced Firewall',
    'diag_title_server_started': 'Server started',
    'diag_body_server_started': 'Your game room is up and waiting.',
    'diag_title_qr_ready': 'QR code ready',
    'diag_body_qr_ready': 'Friends can scan this code to join.',
    'diag_title_no_network': 'No local network found',
    'diag_body_no_network': 'This computer does not look connected to a phone-friendly network yet.',
    'diag_title_local_only': 'This code stays on this computer',
    'diag_body_local_only': 'Phones may not reach this room yet. Try refreshing the network choice.',
    'diag_title_multiple_networks': 'More than one network found',
    'diag_body_multiple_networks': 'If one code does not work, try switching to another network source.',
    'diag_title_hotspot_permission': 'Hotspot may need permission',
    'diag_body_hotspot_permission': 'Using hotspot mode? Windows may need Public network access allowed.',
    'diag_title_reachability': 'Phones may have trouble reaching this room',
    'diag_body_reachability': 'Try refreshing the network source or switching to another one.',
    'diag_title_firewall_hint': 'Firewall may be blocking phones',
    'diag_body_firewall_hint': 'If nobody can join after scanning, Windows Firewall is a common reason.',
    'diag_title_hotspot_waiting': 'Hotspot still waiting for players',
    'diag_body_hotspot_waiting': 'If phones see the hotspot but cannot join, try allowing Public access.',
    'diag_tip_title': 'If phones cannot join',
    'diag_tip_line_1': '1. Put everyone on the same network',
    'diag_tip_line_2': '2. Allow Windows Firewall access',
    'diag_tip_line_3': '3. Try Hotspot if Wi-Fi fails',
    'diag_tip_got_it': 'Got it',
    'diag_action_done': 'Opened helper',
  };

  @override
  String get currentNetworkLabel => 'Current network';
  @override
  String get fallbackNetworkLabel => 'Connection';
  @override
  String get sameNetworkLabel => 'Same network as PC';
  @override
  String get ethernetNetworkLabel => 'Local Network (Cable)';
  @override
  String get activeHotspotLabel => 'Active Hotspot';
  @override
  String get helpButtonLabel => 'Help';
  @override
  String get qrCreating => 'Creating QR...';
  @override
  String get qrMissing => 'No QR';
  @override
  String get orAccessLink => 'or access link:';
  @override
  String get otherConnectionsTooltip => 'Other ways to connect';
  @override
  String get useConnectionButton => 'Use';

  @override
  String get faqTitle => 'Quick Connection Guide';
  @override
  String get faqCommonProblems => 'Common Problems';

  @override
  String get faqStep1Title => 'Stay on the same network';
  @override
  String get faqStep1Desc => 'Your computer and phones must be connected to the same Wi-Fi.';
  @override
  String get faqStep2Title => 'Scan the QR Code';
  @override
  String get faqStep2Desc => 'Open your phone camera or a QR Code scanner and point it at the screen.';
  @override
  String get faqStep3Title => 'Access via link';
  @override
  String get faqStep3Desc => 'If the QR Code fails, type the link shown on screen into your phone\'s browser.';

  @override
  String get faqNoAlternativeNetworks => 'No alternative networks found.';

  @override
  String get faqWifiOffTitle => 'Phone won\'t connect';
  @override
  String get faqWifiOffDesc => 'The phone and the PC might not be communicating.';
  @override
  String wifiOffSolution({String? networkName, String? kind}) {
    if (kind == 'ethernet') {
      return '• The PC is on cable. Make sure the phone is on the local network Wi-Fi\n• Check if Windows Firewall is blocking access\n• Try refreshing the page';
    }
    if (networkName != null && networkName.isNotEmpty) {
      return '• Make sure your phone is connected to:\n  "$networkName"\n• Check if Windows Firewall is blocking access\n• Try refreshing the page';
    }
    return '• Make sure both are on the same Wi-Fi network\n• Check if Windows Firewall is blocking access\n• Try refreshing the page on your phone';
  }

  @override
  String get faqGameControllerNotWorkingTitle => 'Controller doesn\'t work in the game';
  @override
  String get faqGameControllerNotWorkingDesc => 'Some games only recognize specific controller types.';
  @override
  String get faqGameControllerNotWorkingSolution =>
      '• Try switching between XInput and DInput in the options\n• Different games might work better with different modes';

  @override
  String get faqPlayerLimitTitle => 'More than 4 players don\'t work';
  @override
  String get faqPlayerLimitDesc => 'Windows limits XInput controllers to a maximum of 4 players.';
  @override
  String get faqPlayerLimitSolution =>
      '• We suggest switching the server mode to DInput to play with more people';
}
