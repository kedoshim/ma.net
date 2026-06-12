abstract class AppStrings {
  CommonStrings get common;
  StartPageStrings get startPage;
  ModeSelectionStrings get modeSelection;
  ErrorStrings get error;
  LobbyStrings get lobby;
  HomeStrings get home;
  SettingsStrings get settings;
  SlotsStrings get slots;
  PlayersStrings get players;
  LayoutEditorStrings get layoutEditor;
  AlertsStrings get alerts;
  QrPanelStrings get qrPanel;
}

abstract class CommonStrings {
  String get cancel;
  String get confirm;
  String get save;
  String get error;
  String get success;
  String get ok;
  String get delete;
  String get close;
}

abstract class StartPageStrings {
  String get appTitle;
  String get startParty;
  String get startDebug;
  String version(String v);
}

abstract class ModeSelectionStrings {
  String get title;
  String get subtitle;
  String get xinputTitle;
  String get xinputHeadline;
  String get xinputDetails;
  String get dinputTitle;
  String get dinputHeadline;
  String get dinputDetails;
  String get cancel;
  String get play;
}

abstract class ErrorStrings {
  String get startupTitle;
  String get installDriver;
  String get installDriverErrorTitle;
  String get installDriverErrorMessage;
  String get invalidPortTitle;
  String get invalidPortMessage;
  String get connectionErrorTitle;
  String get connectionErrorMessage;
  String get applyConfigErrorTitle;
  String applyConfigErrorMessage(String error);
  String get layoutImportErrorTitle;
  String get layoutImportErrorMessage;
  String get noLogs;
  String get retry;
  String get logsCopied;
  String get copyLogs;
  String get selectPresetErrorTitle;
  String selectPresetErrorMessage(String error);
  String get loadPresetsErrorTitle;
  String loadPresetsErrorMessage(String error);
  String get applyModeErrorTitle;
  String applyModeErrorBody(String error);
}

abstract class LobbyStrings {
  String get lockTooltipReserve;
  String get lockTooltipAuto;
  String get xinput;
  String get dinput;
}

abstract class AlertsStrings {
  String get title;
  String get noAlerts;
  String get tooltip;
  String networkChangedAlert(String kindName, String address);
  String get networkChangedTitle;
  String networkChangedBody(String kindName);
  String get view;
  String get xinputLimitWarning;
}

abstract class HomeStrings {
  String get waitingPlayers;
  String get qrCodeTitle;
  String get joinIn;
  String get qrCodeInstruction;
  String get qrCodeNetworkError;
  String get qrCodeNetworkErrorDetails;
  String get qrCodeModeTip;
  String get onboardingTitle;
  String get onboardingSubtitle;
  String get onboardingNext;
  String get onboardingDone;
  String get onboardingSkip;
  String get onboardingBack;
  String get onboardingStepConnectTitle;
  String get onboardingStepConnectBody;
  String get onboardingStepArrangeTitle;
  String get onboardingStepArrangeBody;
  String get onboardingStepPlayTitle;
  String get onboardingStepPlayBody;
  String get wifiOffTitle;
  String get wifiOffBody;
  String get removeControllersTitle;
  String get removeControllersBody;
  String get selectModeBarrierLabel;
  String get wifi;
  String get ethernet;
  String get hotspot;
  String get newNetwork;
}

abstract class SettingsStrings {
  String get title;
  String get colorsTitle;
  String get timeoutTitle;
  String timeoutValue(int minutes);
  String get languageTitle;
}

abstract class SlotsStrings {
  String slotNumber(int index);
  String get slotLocked;
  String get slotEmpty;
  String slotConnected(String name);
}

abstract class PlayersStrings {
  String connectedCount(int count);
  String playerConnected(String name);
  String get reserveBench;
  String get emptyBench;
}

abstract class LayoutEditorStrings {
  String get title;
  String get saveButton;
  String get resetButton;
  String get browserTitle;
  String get noLayouts;
  String get importButton;
  String get exportButton;
  String get defaultLayoutName;
  
  String get deleteLayoutTitle;
  String deleteLayoutConfirm(String name);
  String get createLayoutButton;
  String get basicLayoutsTitle;
  String get extraCustomLayoutsTitle;
  String get badgeGame;
  String get badgeCustom;
  String get activeBadge;
  String get editButton;
  String get deleteButton;
  
  String get defaultNewLayoutName;
  String get nameHint;
  String get createButtonUpper;
  String get saveButtonUpper;
  
  String get movementModeTitle;
  
  String get dpadLabel;
  String get dpadHeadline;
  String get dpadDesc;
  
  String get fixedJoystickLabel;
  String get fixedJoystickHeadline;
  String get fixedJoystickDesc;
  
  String get floatingJoystickLabel;
  String get floatingJoystickHeadline;
  String get floatingJoystickDesc;
  
  String get visibleButtonsTitle;
  String get visibleButtonsTip;
  String get rightSticksTitle;
  String get rightStickFixedLabel;
  String get rightStickFloatingLabel;
  String get rightStickSwipeLabel;

  String get rightLayoutTitle;
  String get rightLayoutColumnsLabel;
  String get rightLayoutRowsLabel;
}

abstract class QrPanelStrings {
  Map<String, String> get textMap;
  String get currentNetworkLabel;
  String get fallbackNetworkLabel;
  String get sameNetworkLabel;
  String get ethernetNetworkLabel;
  String get activeHotspotLabel;
  String get helpButtonLabel;
  String get qrCreating;
  String get qrMissing;
  String get orAccessLink;
  String get otherConnectionsTooltip;
  String get useConnectionButton;
  
  // FAQ sheet strings
  String get faqTitle;
  String get faqCommonProblems;
  
  String get faqStep1Title;
  String get faqStep1Desc;
  String get faqStep2Title;
  String get faqStep2Desc;
  String get faqStep3Title;
  String get faqStep3Desc;
  
  String get faqNoAlternativeNetworks;
  
  String get faqWifiOffTitle;
  String get faqWifiOffDesc;
  String wifiOffSolution({String? networkName, String? kind});
  
  String get faqGameControllerNotWorkingTitle;
  String get faqGameControllerNotWorkingDesc;
  String get faqGameControllerNotWorkingSolution;
  
  String get faqPlayerLimitTitle;
  String get faqPlayerLimitDesc;
  String get faqPlayerLimitSolution;
}
