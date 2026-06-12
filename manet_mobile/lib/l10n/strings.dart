abstract class AppStrings {
  CommonStrings get common;
  OptionsStrings get options;
  QuickActionsStrings get quickActions;
  StatusStrings get status;
  ScannerStrings get scanner;
  EditControlsStrings get editControls;
  EditNameStrings get editName;
  ConnectionTipsStrings get connectionTips;
  PresetsStrings get presets;
  JoystickStrings get joystick;
}

abstract class CommonStrings {
  String get cancel;
  String get save;
  String get ok;
  String get close;
}

abstract class OptionsStrings {
  String get title;
  String get downloadApp;
  String get vibration;
  String get vibrationAndroidOnly;
  String get mouseMode;
  String get exitDisconnect;
  String get themeColorsTitle;
  String get languageTitle;
}

abstract class QuickActionsStrings {
  String get title;
  String get volumeMediaSection;
  String get windowsSystemSection;
  String getActionTitle(String actionId);
}

abstract class StatusStrings {
  String get searching;
  String get disconnected;
  String get multipleHostsFound;
  String get multipleHostsTitle;
  String get waitingForSlot; // 'Banco'
  String get enteringGame; // 'Entrar na Partida'
  String get connected;
  String get connectedWaiting;
  String connectViaLink(String hostAddress);
}

abstract class ScannerStrings {
  String get title;
  String get qrScannerInstead;
}

abstract class EditControlsStrings {
  String get title;
  String get availableButtons;
  String get rightStickControls;
  String get dragToMove;
  String get noButtonsVisible;
  String get enableButtonsInSettings;
  String get columnsMode;
  String get rowsMode;
}

abstract class EditNameStrings {
  String get title;
  String get hint;
  String get noName;
}

abstract class ConnectionTipsStrings {
  String get title;
  String get subtitle;
  String get wifiSame;
  String get firewall;
  String get hotspot;
  String get gotIt;
}

abstract class PresetsStrings {
  String get title;
  String get colors;
  String get face;
  String get rotation;
  String get presetsTitle;
  String get editFaceTitle;
  String getPresetLabel(String presetId);
}

abstract class JoystickStrings {
  String get changeToFixed;
  String get changeToFloating;
  String get changeToDpad;
  String get touchpad;
  String get scroll;
  String get mouseModeTitle;
}
