import 'strings.dart';

class EnUsStrings implements AppStrings {
  @override
  final common = EnUsCommonStrings();

  @override
  final options = EnUsOptionsStrings();

  @override
  final quickActions = EnUsQuickActionsStrings();

  @override
  final status = EnUsStatusStrings();

  @override
  final scanner = EnUsScannerStrings();

  @override
  final editControls = EnUsEditControlsStrings();

  @override
  final editName = EnUsEditNameStrings();

  @override
  final connectionTips = EnUsConnectionTipsStrings();

  @override
  final presets = EnUsPresetsStrings();

  @override
  final joystick = EnUsJoystickStrings();

  @override
  final disconnect = EnUsDisconnectStrings();

  @override
  final androidOnboarding = EnUsAndroidOnboardingStrings();
}

class EnUsCommonStrings implements CommonStrings {
  @override
  String get cancel => 'Cancel';
  @override
  String get save => 'Save';
  @override
  String get ok => 'OK';
  @override
  String get close => 'Close';
}

class EnUsOptionsStrings implements OptionsStrings {
  @override
  String get title => 'Options';
  @override
  String get downloadApp => 'Download App';
  @override
  String get vibration => 'Vibration';
  @override
  String get vibrationAndroidOnly => 'Vibration is Android app only!';
  @override
  String get mouseMode => 'Mouse';
  @override
  String get exitDisconnect => 'Exit';
  @override
  String get themeColorsTitle => 'ma.net Colors';
  @override
  String get languageTitle => 'Language';
  @override
  String get sensitivity => 'Sensitivity';
  @override
  String get sensitivityTitle => 'Sensitivity Settings';
  @override
  String get leftStickSensitivity => 'Left Stick';
  @override
  String get rightStickSensitivity => 'Right Stick';
  @override
  String get swipeAcceleration => 'Swipe Acceleration';
  @override
  String get secondaryControls => 'Secondary Controls';
  @override
  String get collapse => 'Collapse';
  @override
  String get antiDeadzone => 'Anti-Deadzone';
  @override
  String get responseCurve => 'Response Curve';
  @override
  String get responseCurveLinear => 'Linear';
  @override
  String get responseCurveMild => 'Mild';
  @override
  String get responseCurveMedium => 'Medium';
  @override
  String get responseCurveAggressive => 'Aggressive';
  @override
  String get secondaryButtonsTitle => 'Secondary Buttons';
  @override
  String get movementTitle => 'Movement';
  @override
  String get rightStickTitle => 'Right Stick';
}

class EnUsQuickActionsStrings implements QuickActionsStrings {
  @override
  String get title => 'Quick Actions';
  @override
  String get volumeMediaSection => 'Volume & Media';
  @override
  String get windowsSystemSection => 'Windows / System';

  @override
  String getActionTitle(String actionId) {
    switch (actionId) {
      case 'mute_toggle':
        return 'Mute/Unmute';
      case 'volume_down':
        return 'Vol. Down';
      case 'volume_up':
        return 'Vol. Up';
      case 'previous_track':
        return 'Previous';
      case 'play_pause':
        return 'Play/Pause';
      case 'next_track':
        return 'Next';
      case 'windows_key':
        return 'Win Key';
      case 'windows_tab':
        return 'Win + Tab';
      case 'show_desktop':
        return 'Desktop';
      case 'task_manager':
        return 'Task Mgr';
      case 'escape':
        return 'Esc';
      case 'maximize_window':
        return 'Maximize';
      case 'minimize_window':
        return 'Minimize';
      default:
        return actionId;
    }
  }
}

class EnUsStatusStrings implements StatusStrings {
  @override
  String get searching => 'searching...';
  @override
  String get disconnected => 'disconnected';
  @override
  String get multipleHostsFound => 'select host';
  @override
  String get multipleHostsTitle => 'Multiple Hosts Found';
  @override
  String get waitingForSlot => 'Bench';
  @override
  String get enteringGame => 'Join Game';
  @override
  String get connected => 'Connected';
  @override
  String get connectedWaiting => 'Connected (Waiting for Slot)';

  @override
  String connectViaLink(String hostAddress) => 'Connected via link: $hostAddress';
}

class EnUsScannerStrings implements ScannerStrings {
  @override
  String get title => 'Scan Host';
  @override
  String get qrScannerInstead => 'Scan QR Code instead';
}

class EnUsEditControlsStrings implements EditControlsStrings {
  @override
  String get title => 'edit controls';
  @override
  String get availableButtons => 'Available buttons';
  @override
  String get rightStickControls => 'Right Stick Controls';
  @override
  String get dragToMove => 'Drag to move';
  @override
  String get noButtonsVisible => 'No visible buttons';
  @override
  String get enableButtonsInSettings => 'Enable buttons in settings';
  @override
  String get columnsMode => 'Two columns';
  @override
  String get rowsMode => 'Two rows';
  @override
  String get editMode => 'Edit';
  @override
  String get useMode => 'Use';
}

class EnUsEditNameStrings implements EditNameStrings {
  @override
  String get title => 'Edit Nickname';
  @override
  String get hint => 'Enter nickname...';
  @override
  String get noName => 'No Name';
}

class EnUsConnectionTipsStrings implements ConnectionTipsStrings {
  @override
  String get title => 'Phone could not connect :P';
  @override
  String get subtitle => 'Here are some tips to try and fix it:';
  @override
  String get wifiSame => '1. Check if both are on the same Wi-Fi network.';
  @override
  String get firewall => '2. Windows Firewall might be blocking the connection.';
  @override
  String get hotspot => '3. Try using your computer\'s Hotspot if Wi-Fi fails.';
  @override
  String get gotIt => 'Got it';
}

class EnUsPresetsStrings implements PresetsStrings {
  @override
  String get title => 'face editor';
  @override
  String get colors => 'colors';
  @override
  String get face => 'face';
  @override
  String get rotation => 'rotation';
  @override
  String get presetsTitle => 'presets';
  @override
  String get editFaceTitle => 'Edit Face';

  @override
  String getPresetLabel(String presetId) {
    switch (presetId) {
      case 'happy':
        return 'chillin';
      case 'angry':
        return 'aarrhh';
      case 'yeah':
        return 'woohoo';
      case 'confused':
        return 'confused';
      case 'sad':
        return 'bummed';
      case 'silly':
        return 'silly';
      case 'sexy':
        return 'hey there';
      case 'cursed':
        return 'smooch';
      default:
        return presetId;
    }
  }
}

class EnUsJoystickStrings implements JoystickStrings {
  @override
  String get changeToFixed => 'Switch to Fixed Joystick';
  @override
  String get changeToFloating => 'Switch to Floating Joystick';
  @override
  String get changeToDpad => 'Switch to D-Pad';
  @override
  String get touchpad => 'touchpad';
  @override
  String get scroll => 'scroll';
  @override
  String get mouseModeTitle => 'mouse mode';
}

class EnUsDisconnectStrings implements DisconnectStrings {
  @override
  String get title => 'You were disconnected';
  @override
  String get subtitle => 'Could not remain connected to MaNet.';
  @override
  String get hostOffline => 'The computer hosting the match was turned off or closed MaNet.';
  @override
  String wifiChanged(String expected) => 'It looks like you changed your Wi-Fi network. Go back to "$expected" to continue playing.';
  @override
  String get noWifi => 'Make sure you are still connected to the same Wi-Fi network as the hosting computer.';
  @override
  String get noInternet => 'Your device seems to be offline at the moment.';
  @override
  String get unknown => 'The connection to MaNet was lost. Try closing and reopening the app or reconnecting to the Wi-Fi used during the match.';
  @override
  String currentNetwork(String current) => 'Current network: "$current"';
  @override
  String expectedNetwork(String expected) => 'Expected network: "$expected"';
  @override
  String get tryAgain => 'Try again';
  @override
  String get reconnect => 'Reconnect';
  @override
  String get diagnosing => 'Analyzing connection...';
}

class EnUsAndroidOnboardingStrings implements AndroidOnboardingStrings {
  @override
  String get title => 'Better experience in the app';
  @override
  String get subtitle => 'MaNet has an Android app with a more stable and comfortable experience for playing.\n\nYou can continue using the browser normally or install the app.';
  @override
  String get download => 'Download App';
  @override
  String get continueInBrowser => 'Continue in browser';
}
