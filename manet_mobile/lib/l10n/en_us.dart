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
  String get dragToMove => 'Drag to move';
  @override
  String get noButtonsVisible => 'No visible buttons';
  @override
  String get enableButtonsInSettings => 'Enable buttons in settings';
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
