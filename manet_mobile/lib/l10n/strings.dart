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
  DisconnectStrings get disconnect;
  AndroidOnboardingStrings get androidOnboarding;
  MenuStrings get menu;
}

abstract class MenuStrings {
  String get select;
  String get back;
  String get avatar;
  String get lobbyHint;
  String get libraryHint;
  String get overlayHint;
  String playgroundHint(String owner);
  String get someone;
  String get jump;
  String get seat;
  String get seatsTitle;
  String get seatsHint;
  String get bench;
  String you(String name);
  String get swap;
  String get freeSeat;
  String get goToBench;
  String get joinGame;
  String swapOffer(String name, String fromSeat, String toSeat);
  String get accept;
  String get decline;
  String swapAccepted(String name);
  String swapDeclined(String name);
  String get tournamentHint;
  String get betterInApp;
  String get ready;
  String get notReady;
  String get waitingOthers;
  String startingIn(int seconds);
  String get face;
  String get cancelSelection;
  String get info;
  String get cancel;
  String get backToLobby;
  String lobbyWaiting(int yes, int needed);
  String lobbyRequestOffer(String name);
  String get stayHere;
  String get goBack;
  String playersRange(int min, int max);
  String get noDescription;
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
  String get sensitivity;
  String get sensitivityTitle;
  String get leftStickSensitivity;
  String get rightStickSensitivity;
  String get swipeAcceleration;
  String get secondaryControls;
  String get collapse;
  String get antiDeadzone;
  String get responseCurve;
  String get responseCurveLinear;
  String get responseCurveMild;
  String get responseCurveMedium;
  String get responseCurveAggressive;
  String get secondaryButtonsTitle;
  String get movementTitle;
  String get rightStickTitle;
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
  String get editMode;
  String get useMode;
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

abstract class DisconnectStrings {
  String get title;
  String get subtitle;
  String get hostOffline;
  String wifiChanged(String expected);
  String get noWifi;
  String get noInternet;
  String get unknown;
  String currentNetwork(String current);
  String expectedNetwork(String expected);
  String get tryAgain;
  String get reconnect;
  String get diagnosing;
}

abstract class AndroidOnboardingStrings {
  String get title;
  String get subtitle;
  String get download;
  String get continueInBrowser;
}
