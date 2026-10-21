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

  @override
  final menu = EnUsMenuStrings();

  @override
  final relay = EnUsRelayStrings();

  @override
  final access = EnUsAccessStrings();
}

class EnUsRelayStrings implements RelayStrings {
  @override
  String get title => 'Controller found!';
  @override
  String offer(String padName) => '"$padName" is connected here. Play with it? Its buttons go to MaNet as if they were this screen.';
  @override
  String get sameMachineWarning => 'This browser is on the MaNet PC itself, which also shows the virtual controllers MaNet creates. Pick only a real controller.';
  @override
  String get padAnswerHint => 'Press A on the controller to use it, B to decline.';
  @override
  String get use => 'Use controller';
  @override
  String get notNow => 'Not now';
  @override
  String get usePad => 'Use physical controller';
  @override
  String active(String padName) => 'Playing with $padName';
  @override
  String get stop => 'Stop';
  @override
  String disconnected(String padName) => '$padName disconnected. Back to the screen.';
  @override
  String get pickTitle => 'Which controller?';
}

class EnUsMenuStrings implements MenuStrings {
  @override
  String get enter => 'Enter';
  @override
  String newSeat(int seat) => 'P$seat · new controller';
  @override
  String lagTitle(int ms) => 'Slow connection (~$ms ms)';
  @override
  String lagTipHotspot(String name, String address) => 'This PC has its own network, which is faster: connect your phone\'s Wi-Fi to ${name.isEmpty ? 'the PC hotspot' : name} and open $address.';
  @override
  String get lagTipRouter => 'The controller may lag. Try getting closer to the router, or turning on the PC\'s mobile hotspot.';
  @override
  String get lagOk => 'Got it';
  @override
  String get mousePasswordTitle => 'Mouse mode password';
  @override
  String get mousePasswordHint => 'Ask whoever runs ma•net for it';
  @override
  String get mousePasswordWrong => 'Wrong password';
  @override
  String get mousePasswordUnset => 'Mouse mode needs a password: set one in ma•net\'s settings on the PC.';
  @override
  String get mousePasswordEnter => 'Enter';
  @override
  String get checkInTitle => 'Make your face';
  @override
  String get checkInHint => 'Pick a name and a face to join';
  @override
  String get checkInButton => 'Ready, I want to play!';
  @override
  String get editFace => 'Edit face';
  @override
  String get consoleLobbyHint => 'Roll your face out to the right →';
  @override
  String get consoleWaitingHint => 'Waiting for the others...';
  @override
  String get lineupChooseHint => 'Walk to a side: play now or the bench';
  @override
  String get lineupPickDedanha => 'How many fingers?';
  @override
  String get lineupPickZerinho => 'Zero or one?';
  @override
  String get lineupWait => 'Watch the TV...';
  @override
  String get lineupAnnounceDedanha => 'Finger count! Get ready to pick 0 to 5';
  @override
  String get lineupAnnounceZerinho => 'Zero or one! Get ready to pick 0 or 1';
  @override
  String get lineupYouPlay => 'You play now!';
  @override
  String get lineupYouBench => 'You start on the bench';
  @override
  String get select => 'Select';
  @override
  String get back => 'Back';
  @override
  String get avatar => 'Avatar';
  @override
  String get lobbyHint => 'Press Ready when you are ready';
  @override
  String get libraryHint => 'Move the cursor to a game and pick it';
  @override
  String get overlayHint => 'Pick an option on the TV menu';
  @override
  String playgroundHint(String owner) => '$owner is in the menu. Play around: move and jump!';
  @override
  String get someone => 'Someone';
  @override
  String get jump => 'Jump';
  @override
  String get loadingHint => 'The game is opening... jump around meanwhile!';
  @override
  String get showGame => "It's open";
  @override
  String get seat => 'Seat';
  @override
  String get seatsTitle => 'Seats';
  @override
  String get seatsHint => 'Each seat is a controller in the game (P1 is player 1).';
  @override
  String get bench => 'Bench';
  @override
  String you(String name) => '$name (you)';
  @override
  String get swap => 'Swap';
  @override
  String get freeSeat => 'Free';
  @override
  String get sitHere => 'Sit here';
  @override
  String get goToBench => 'Go to the bench';
  @override
  String get joinGame => 'Join the game';
  @override
  String swapOffer(String name, String fromSeat, String toSeat) =>
      '$name wants to trade places with you.\nYou go to $fromSeat and $name goes to $toSeat.';
  @override
  String get accept => 'Accept';
  @override
  String get decline => 'Decline';
  @override
  String swapAccepted(String name) => '$name agreed to trade places!';
  @override
  String swapDeclined(String name) => '$name prefers to stay put.';
  @override
  String get tournamentHint =>
      'Tournament! Move your face to the side of the game you want to play.';
  @override
  String get betterInApp => 'It is better in the app';
  @override
  String get ready => 'Ready';
  @override
  String get notReady => 'Not ready';
  @override
  String get waitingOthers => 'Waiting for the others…';
  @override
  String startingIn(int seconds) => 'Everyone is ready! Starting in $seconds…';
  @override
  String get face => 'Face';
  @override
  String get cancelSelection => 'Cancel selection';
  @override
  String get info => 'Info';
  @override
  String get cancel => 'Cancel';
  @override
  String get backToLobby => 'Back to lobby';
  @override
  String lobbyWaiting(int yes, int needed) => 'Waiting $yes/$needed';
  @override
  String lobbyRequestOffer(String name) => '$name wants to go back to the lobby. Go back?';
  @override
  String get stayHere => 'Stay';
  @override
  String get goBack => 'Go back';
  @override
  String playersRange(int min, int max) => min == max ? '$min players' : '$min–$max players';
  @override
  String get noDescription => 'No description yet.';
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
  String get leftRowTitle => 'Left side (up to 2)';
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
  String wifiChanged(String expected) => 'You changed your Wi-Fi network.';
  @override
  String get noWifi => 'You left the Wi-Fi network used during the match.';
  @override
  String get noInternet => 'Your device seems to be offline at the moment.';
  @override
  String get unknown => 'The connection to MaNet was lost. Try closing and reopening the app or reconnecting to the Wi-Fi used during the match.';
  @override
  String currentNetwork(String current) => 'Current network: "$current"';
  @override
  String expectedNetwork(String expected) => 'Previous network: "$expected"';
  @override
  String get tryAgain => 'Try again';
  @override
  String get reconnect => 'Reconnect';
  @override
  String get diagnosing => 'Analyzing connection...';
}

class EnUsAndroidOnboardingStrings implements AndroidOnboardingStrings {
  @override
  String get title => 'Android App';
  @override
  String get subtitle => 'A more stable and comfortable experience for playing.';
  @override
  String get download => 'Download app';
  @override
  String get continueInBrowser => 'Continue in browser';
}

class EnUsAccessStrings implements AccessStrings {
  @override
  String get passwordTitle => 'This room has a password';
  @override
  String get passwordHint => 'Ask the host for the password.';
  @override
  String get passwordField => 'Password';
  @override
  String get enter => 'Join';
  @override
  String wrongPassword(int attemptsLeft) => attemptsLeft == 1
      ? 'Wrong password. 1 attempt left.'
      : 'Wrong password. $attemptsLeft attempts left.';
  @override
  String get pendingTitle => 'Waiting for the host';
  @override
  String get pendingBody => 'Your request to join was sent. Stay on this screen.';
  @override
  String deniedTitle(String? reason) => switch (reason) {
    'banned' => 'You can\'t join this room',
    'kicked' => 'You were removed from the room',
    'timeout' => 'The request expired',
    'lan_disabled' => 'This room only accepts players over the internet',
    'too_many_attempts' => 'Too many wrong attempts',
    _ => 'The host declined your request',
  };
  @override
  String deniedBody(String? reason) => switch (reason) {
    'banned' => 'The host blocked this device for this session.',
    'timeout' => 'The host didn\'t answer in time. You can ask again.',
    'lan_disabled' => 'Ask the host for the online link and join through it.',
    'too_many_attempts' => 'Wait a minute before trying again.',
    _ => 'You can try again if the host asks you to.',
  };
  @override
  String get tryAgain => 'Try again';
}
