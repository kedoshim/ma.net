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
  @override
  final CreditsStrings credits = EnUsCreditsStrings();
  @override
  final ControllersStrings controllers = EnUsControllersStrings();
  @override
  final SessionStrings session = EnUsSessionStrings();
  @override
  final OnlineStrings online = EnUsOnlineStrings();
  @override
  final AccessStrings access = EnUsAccessStrings();
  @override
  final NetworkStrings network = EnUsNetworkStrings();
}

class EnUsSessionStrings implements SessionStrings {
  @override
  String get lineupGetReady => 'Get ready!';
  @override
  String get consoleEditing => 'making their face...';
  @override
  String get consolePlayTitle => 'Play';
  @override
  String get consolePlayHint => 'Go in here to pick a game';
  @override
  String consoleStartingIn(int seconds) => 'Starting in $seconds...';
  @override
  String get consoleJoinTitle => 'How to join';
  @override
  String consoleJoinWifi(String name) => 'Connect to the Wi-Fi $name';
  @override
  String consoleJoinNetwork(String name) => 'Connect to the network $name';
  @override
  String consoleJoinWifiOrHotspot(String wifi, String hotspot) =>
      'Connect to the Wi-Fi $wifi or the hotspot $hotspot';
  @override
  String consoleJoinScan(String link) => 'Point the camera at the QR code or open $link';
  @override
  String get consoleJoinFace => 'Make your face and press Ready';
  @override
  String get lineupTitle => 'Who plays first?';
  @override
  String lineupSeats(String game, int seats) => '$game has $seats ${seats == 1 ? 'seat' : 'seats'}';
  @override
  String get lineupPlayNow => 'I want to play now';
  @override
  String get lineupBench => 'I\'ll start on the bench';
  @override
  String get lineupChooseHint => 'Walk to one of the sides';
  @override
  String get lineupDedanha => 'Finger count!';
  @override
  String get lineupZerinho => 'Zero or one!';
  @override
  String get lineupDedanhaHint => 'Show 0 to 5 fingers on the phone: the sum counts around the circle';
  @override
  String get lineupZerinhoHint => 'Pick 0 or 1 on the phone: the minority is decided';
  @override
  String lineupModeOut(int needed) => '$needed ${needed == 1 ? 'player goes' : 'players go'} to the bench';
  @override
  String lineupModeIn(int needed) => '$needed ${needed == 1 ? 'seat' : 'seats'} to fill';
  @override
  String lineupPicked(int picked, int total) => '$picked/$total picked';
  @override
  String lineupTotal(int total) => 'Total: $total';
  @override
  String get lineupTie => 'Tie! Again!';
  @override
  String get lineupNarrow => 'The minority plays again!';
  @override
  String get lineupGoesOut => 'to the bench';
  @override
  String get lineupGoesIn => 'plays!';
  @override
  String get lineupDone => 'Lineup';
  @override
  String get lineupPlaying => 'Playing';
  @override
  String get lineupOnBench => 'Bench';
  @override
  String get lineupCancel => 'Cancel';
  @override
  String readyPrompt(int ready, int total) => 'Press START when you are ready · $ready/$total';
  @override
  String get allReady => 'Everyone is ready! Press START to pick a game';
  @override
  String get controlsInBackground =>
      'Controllers are going to games. Click this window to use them in ma•net.';
  @override
  String get chooseGame => 'Pick a game';
  @override
  String get ready => 'READY';
  @override
  String get libraryTitle => 'Pick a game';
  @override
  String get libraryHint =>
      'Stick moves · A votes, opens details (i) and filters · B removes the vote or closes details · START decides';
  @override
  String get backToLobby => 'Lobby';
  @override
  String get manageGames => 'Manage games';
  @override
  String get emptyLibrary => 'No games yet.';
  @override
  String get addFirstGame => 'Add your first game';
  @override
  String playersRange(int min, int max) => min == max
      ? '$min ${min == 1 ? 'player' : 'players'}'
      : '$min–$max players';
  @override
  String doesNotFit(int players) => 'Doesn\'t fit $players ${players == 1 ? 'player' : 'players'}';
  @override
  String get clickToPlay => 'Click to play now';
  @override
  String startingIn(String game) => 'Starting $game in';
  @override
  String get cancel => 'Cancel';
  @override
  String launchError(String code) => switch (code) {
        'path_not_found' => 'Couldn\'t find the game file. Check its path in Manage games.',
        'elevation_cancelled' => 'This game needs admin rights, and the Windows prompt was declined.',
        _ => 'Couldn\'t start the game.',
      };
  @override
  String playing(String game) => 'Playing $game';
  @override
  String get playingHint => 'When the game closes, ma•net goes back to the lobby by itself.';
  @override
  String get untrackedHint =>
      'This game started through a shortcut or launcher, so ma•net can\'t tell when it closes.';
  @override
  String get closeGame => 'Close game';
  @override
  String get returnToLobby => 'Back to lobby';
  @override
  String get gamesTitle => 'Games';
  @override
  String get tabGames => 'Games';
  @override
  String get tabLauncher => 'Launcher';
  @override
  String get launcherSettingsTitle => 'Launcher Appearance';
  @override
  String get cardStyleLabel => 'Card Style';
  @override
  String get cardStyleCoverOnly => 'Cover Only';
  @override
  String get cardStyleClassic => 'Classic (with details)';
  @override
  String get gridDensityLabel => 'Library Rows';
  @override
  String get gridRows1 => '1 Row (Wide)';
  @override
  String get gridRows2 => '2 Rows (Default)';
  @override
  String get gridRows3 => '3 Rows (Compact)';
  @override
  String get sortOrderLabel => 'Sorting';
  @override
  String get sortRecent => 'Most Recent';
  @override
  String get sortAlphabetical => 'Alphabetical (A–Z)';
  @override
  String get sortPlayers => 'By Players';
  @override
  String get manageGamesAndLauncher => 'Games & Launcher';
  @override
  String get addGame => 'Add game';
  @override
  String get editGame => 'Edit game';
  @override
  String get gameName => 'Name';
  @override
  String get gamePath => 'Executable or shortcut';
  @override
  String get gamePathHint => '.exe, .lnk, .url or steam://...';
  @override
  String get chooseFile => 'Choose file';
  @override
  String get gameArguments => 'Arguments (optional)';
  @override
  String get gameCover => 'Cover';
  @override
  String get chooseCover => 'Choose image';
  @override
  String get removeCover => 'Remove';
  @override
  String get minPlayers => 'Minimum players';
  @override
  String get maxPlayers => 'Maximum players';
  @override
  String get gameLayout => 'Controller layout';
  @override
  String get noLayout => 'Keep current';
  @override
  String get gameMode => 'Controller type';
  @override
  String get keepMode => 'Keep current';
  @override
  String get saveGame => 'Save';
  @override
  String get deleteGame => 'Delete';
  @override
  String deleteGameConfirm(String game) => 'Remove "$game" from the library?';
  @override
  String get saveError => 'Couldn\'t save. Check the name and path.';
  @override
  String get findCover => 'Find cover';
  @override
  String get coverSearchTitle => 'Find a cover';
  @override
  String get coverSearch => 'Search';
  @override
  String get coverSteamHint => 'Covers and details from Steam and IGDB. Click one to use it.';
  @override
  String get coverNoResults => 'Nothing found with that name.';
  @override
  String get coverSearchError => 'Couldn\'t search right now. Check the internet.';
  @override
  String get coverDownloadError => 'Couldn\'t download that image.';
  @override
  String get coverOtherSources => 'Or look somewhere else';
  @override
  String get coverGoogle => 'Google Images';
  @override
  String get coverGoogleSuffix => 'game cover';
  @override
  String get coverPasteLink => 'Paste an image link here';
  @override
  String get coverUseLink => 'Use';
  @override
  String get createLayout => 'Create a new layout';
  @override
  String get rulesTitle => 'By player count';
  @override
  String get rulesHint =>
      'Switch controller type or layout depending on how many people play. The first matching rule wins.';
  @override
  String get addRule => '+ Rule';
  @override
  String get suggestXinputRule => 'x•input up to 4, d•input above';
  @override
  String get ruleFrom => 'From';
  @override
  String get ruleTo => 'to';
  @override
  String get displayTitle => 'Game screen';
  @override
  String get displayAuto => 'Let the game decide';
  @override
  String displayLabel(int number, bool primary, int width, int height) =>
      'Screen $number${primary ? ' (main)' : ''} · $width×$height';
  @override
  String get fullscreenGame => 'Open full screen';
  @override
  String get fullscreenGameHint => 'If the game opens in a window, ma•net stretches it over the whole screen, borderless.';
  @override
  String get overlayHint => '↑ ↓ choose · A confirm · B back · Home closes';
  @override
  String get overlayResume => 'Back to the game';
  @override
  String get awayTitle => 'Game paused: nobody connected';
  @override
  String get awayScan => 'Scan the QR code to keep playing';
  @override
  String awayClosesIn(String time) => 'The game closes in $time and MaNet goes back to the lobby. Unsaved progress will be lost.';
  @override
  String get awayClosesUntracked => "MaNet can't close this game: it goes back to the lobby and the game stays open behind it.";
  @override
  String get awayWaits => 'The game will wait for you.';
  @override
  String get awayChooseTitle => 'Welcome back!';
  @override
  String get awayResume => 'Keep playing';
  @override
  String get awaySwitch => 'Pick another game';
  @override
  String get overlayAddPlayers => 'Add players';
  @override
  String get overlayLayout => 'Controller layout';
  @override
  String get overlaySwitchGame => 'Switch game';
  @override
  String overlayConfirm(String action) => '$action? Press again';
  @override
  String get overlayPlayersTitle => 'Bring more people!';
  @override
  String get overlayQrZoom => 'Select shows the QR code big';
  @override
  String get overlayPlayersHint => 'Point a phone camera at the QR code or open the link.';
  @override
  String get overlayLayoutTitle => 'Controller layout';
  @override
  String overlayControlledBy(String name) => 'In control: $name';
  @override
  String get inputPausedHint =>
      'Controllers are paused while the game is not in front, so they don\'t touch other programs.';
  @override
  String get coverInvalidLink => 'That doesn\'t look like a link. Paste the full image address.';
  @override
  String get coverNotAnImage =>
      'That link opens a page, not an image. Right-click the image and use "Copy image address".';
  @override
  String get overlayInCharge => 'is in charge';
  @override
  String get overlayHostOwner => 'Menu opened on the PC';
  @override
  String get overlaySeatsHint => 'To trade places or go to the bench, use the Seat button on the phone.';
  @override
  String get freeSeat => 'Free';
  @override
  String playersInSession(int count) =>
      count == 1 ? '1 player in the session' : '$count players in the session';
  @override
  String sortLabel(int sort) => switch (sort) {
    1 => 'Recent',
    2 => 'Most players',
    _ => 'A–Z',
  };
  @override
  String fitsOnly(int players) => 'Fits $players';
  @override
  String get clearFilters => 'Clear';
  @override
  String get noGamesMatch => 'No games match these filters.';
  @override
  String playersShort(int min, int max) => min == max ? '$min' : '$min–$max';
  @override
  String get gameDetails => 'Details';
  @override
  String get noDescription => 'No description yet.';
  @override
  String fitsSession(int players) =>
      players == 1 ? 'Playable solo' : 'Playable with all $players';
  @override
  String get closeDetails => 'Close';
  @override
  String get voteForThis => 'Vote for this';
  @override
  String get watchTrailer => 'Watch trailer';
  @override
  String get gameDescription => 'Description';
  @override
  String get gameDescriptionHint => 'A sentence or two about the game';
  @override
  String get gameTags => 'Tags';
  @override
  String get gameTagsHint => 'Comma separated: Racing, Party, Local co-op';
  @override
  String get gameTrailer => 'Trailer';
  @override
  String get gameTrailerHint => 'Video link (YouTube, Steam...)';
  @override
  String get gameImages => 'Images';
  @override
  String get gameImagesHint => 'Image links, one per line (shown on the card and on the phones)';
  @override
  String get searchTrailer => 'Search YouTube';
  @override
  String get steamInfoLoading => 'Getting description and game details...';
  @override
  String get fetchData => 'Find game data';
  @override
  String get fetchDataHint => 'Search the game online and choose what to fill: cover, description, tags, trailer and images';
  @override
  String get dataPreviewTitle => 'What should be filled?';
  @override
  String get dataPreviewHint => 'Check what you want to use from this search.';
  @override
  String get dataWillReplace => 'Replaces what is already there';
  @override
  String get dataNothingFound => 'No extra data found for this game.';
  @override
  String get applyData => 'Fill in';
  @override
  String get addImage => 'Add image';
  @override
  String get addImageConfirm => 'Add';
  @override
  String get imageLinkHint => 'Paste the image link';
  @override
  String get imageLoadError => 'Could not load this image';
  @override
  String loadingGame(String game) => 'Opening $game';
  @override
  List<String> get loadingLines => const [
    'Blowing on the cartridge',
    'Warming up the controllers',
    'Adjusting the antenna',
    'Untangling the controller cable',
    'Picking the best spot on the couch',
    'Grabbing the popcorn',
    'Loading the polygons',
    'Waking up the NPCs',
  ];
  @override
  String loadingElapsed(int seconds) => '${seconds}s';
  @override
  String get loadingSlowHint => 'Taking long? If the game is already open, START shows it.';
  @override
  String get loadingShowGame => 'Show the game';
  @override
  String get tournamentTitle => 'Tournament!';
  @override
  String tournamentIntro(int games) =>
      '$games games in the running: the most voted in each duel advances';
  @override
  String tournamentRound(int matches, int round, int rounds) => switch (matches) {
    1 => 'Final',
    2 => 'Semifinal',
    4 => 'Quarterfinal',
    _ => 'Round $round of $rounds',
  };
  @override
  String get tournamentLean =>
      'Move your face to the side of the game you want to play';
  @override
  String tournamentVotes(int count) => count == 1 ? '1 vote' : '$count votes';
  @override
  String tournamentAdvances(String game) => '$game advances!';
  @override
  String tournamentDraw(String game) => 'Tie! $game advances by draw.';
  @override
  String tournamentChampion(String game) => "Let's play $game!";
  @override
  String get tournamentCancel => 'Library';
  @override
  String get lobbyCountdown => 'Everyone is ready! Opening the game selection…';
  @override
  String get freeMode => 'Free mode';
  @override
  String get freeModeHint => 'Open any game with the mouse. Phones work as plain controllers; press Home on a phone to come back.';
  @override
  String get leaveFreeMode => 'Leave free mode';
  @override
  String lobbyRequest(String name, int yes, int needed) =>
      '$name wants to go back to the lobby · $yes/$needed agree';
  @override
  String get statusChoosing => 'choosing';
  @override
  String statusReading(String game) => 'reading about $game';
  @override
  String get statusWantsLobby => 'wants to go back';
  @override
  String votedCount(int voted, int total) => '$voted of $total picked';
}

class EnUsControllersStrings implements ControllersStrings {
  @override
  String get diagnosticsTitle => 'Diagnosis';
  @override
  String get allGood => 'All good: Windows only sees what it should.';
  @override
  String predictionWarning(int pads, int free, int out) =>
      'ma•net uses $pads x•input ${pads == 1 ? 'controller' : 'controllers'}, but only $free of the '
      '4 Windows slots ${free == 1 ? 'is' : 'are'} free: $out ${out == 1 ? 'player stays' : 'players stay'} '
      'out and x•input games won\'t see them. Unplug the other controllers or use d•input.';
  @override
  String get windowsSeesTitle => 'What Windows sees';
  @override
  String get windowsSeesHint => 'Every game controller plugged into this PC right now.';
  @override
  String get colDevice => 'Device';
  @override
  String get colType => 'Type';
  @override
  String get colSource => 'Created by';
  @override
  String get sourceManet => 'ma•net';
  @override
  String get sourcePhysical => 'Real controller';
  @override
  String get sourceSteam => 'Steam Input';
  @override
  String get sourceUnknown => 'Another program';
  @override
  String get outOfXinput => 'Left out';
  @override
  String get appsTitle => 'Programs that can create controllers';
  @override
  String get appsHint => 'Windows doesn\'t tell which program created each virtual controller; these are open now.';
  @override
  String get appsEmpty => 'No known program running.';
  @override
  String likelySources(String apps) => 'Probably: $apps';
  @override
  String get title => 'Controllers in Windows';
  @override
  String get tooltip => 'Connected controllers';
  @override
  String summary(int total, int own) =>
      'Windows sees $total ${total == 1 ? 'controller' : 'controllers'}. '
      '$own ${own == 1 ? 'is' : 'are'} from ma•net.';
  @override
  String get xinputTitle => 'x•input slots';
  @override
  String get xinputSubtitle =>
      'Windows only has 4 x•input slots. The order matches the controller light.';
  @override
  String get xinputFree => 'Free';
  @override
  String get xinputOther => 'Other controller';
  @override
  String xinputPlayer(int player) => 'Player $player';
  @override
  String noXinputWarning(int count) =>
      '$count ma•net ${count == 1 ? 'player has' : 'players have'} no x•input slot, '
      'so x•input games won\'t see ${count == 1 ? 'them' : 'them'}. '
      'Disconnect the other controllers or use d•input.';
  @override
  String foreignWarning(int count) =>
      '$count virtual ${count == 1 ? 'controller is' : 'controllers are'} not from this ma•net: '
      'another app owns them, or they got stuck in the driver after a session crashed '
      '(those go away after restarting the PC).';
  @override
  String get devicesTitle => 'Detected devices';
  @override
  String get devicesEmpty => 'No controllers detected.';
  @override
  String get originVirtual => 'Virtual';
  @override
  String get originSteam => 'Steam';
  @override
  String get originPhysical => 'Physical';
  @override
  String deviceLabel(String vendor) => switch (vendor) {
        'xbox' => 'Xbox controller',
        'playstation' => 'PlayStation controller',
        'nintendo' => 'Nintendo controller',
        'steam' => 'Steam controller',
        _ => 'Generic controller',
      };
  @override
  String staleServersWarning(int count) =>
      '${count == 1 ? 'An old ma•net server is' : '$count old ma•net servers are'} still running '
      'and keeping controllers plugged in.';
  @override
  String get closeStaleServers => 'Close old servers';
  @override
  String closedServers(int count) =>
      count == 0 ? 'No old servers found.' : '$count ${count == 1 ? 'server' : 'servers'} closed.';
  @override
  String get recreate => 'Recreate controllers';
  @override
  String get recreateHint =>
      'Unplugs and recreates ma•net\'s controllers. Players stay in the same slots.';
  @override
  String get recreated => 'Controllers recreated.';
  @override
  String get refresh => 'Refresh';
  @override
  String get loadError => 'Couldn\'t read the controllers from Windows.';
  @override
  String get actionError => 'That didn\'t work. Try again.';
  @override
  String playerMapping(int player, int windowsIndex) =>
      'Player $player is controller $windowsIndex in Windows';
  @override
  String playerNoXinput(int player) => 'Player $player has no x•input slot';
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
  String get mousePasswordTitle => 'Mouse mode password';
  @override
  String get mousePasswordHint => 'Phones need it to control this PC\'s mouse (not needed in free mode). Empty: mouse mode only in free mode.';
  @override
  String get lobbyStartTitle => 'Start picking a game when';
  @override
  String get lobbyStartHint => 'Players walk out through the right edge. Nobody can still be making their face.';
  @override
  String get lobbyStartMajority => 'Most go';
  @override
  String get lobbyStartAll => 'Everyone goes';
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
  @override
  String get fullScreenTitle => 'Full screen (F11)';
  @override
  String get matchSecondsTitle => 'Tournament duel length';
  @override
  String matchSecondsValue(int seconds) => '${seconds}s';
  @override
  String get abandonCloseTitle => 'Close abandoned game after';
  @override
  String get abandonCloseHint => 'Counted once every phone has left. Whoever comes back before that can keep playing in the same seat.';
  @override
  String abandonCloseValue(int minutes) => minutes == 0 ? 'Never' : '$minutes min';
  @override
  String get freeModeTitle => 'Free mode';
  @override
  String get freeModeHint => 'Lets the game selection minimize MaNet so phones work as plain controllers for any game.';
  @override
  String get consoleModeTitle => 'Console mode';
  @override
  String get consoleModeHint => 'On: players just join and controllers are created when a game starts. Off: tool mode, the technical lobby with slots, x/d•input and layout.';
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
  @override
  String get rightSticksTitle => 'RIGHT STICKS';
  @override
  String get rightStickFixedLabel => 'Fixed Right Stick';
  @override
  String get rightStickFloatingLabel => 'Floating Right Stick';
  @override
  String get rightStickSwipeLabel => 'Touchpad';
  @override
  String get rightStickFireTitle => 'FIRE WITH THE RIGHT STICK';
  @override
  String get rightStickFireTip =>
      'Aim and shoot with one thumb. On touch: the button is held while the stick is touched. Fire ring: only once the stick goes past the ring. Players can change it on their phone.';
  @override
  String get rightStickFireOff => 'Off';
  @override
  String get rightStickFireTouch => 'On touch';
  @override
  String get rightStickFireRing => 'Fire ring';
  @override
  String get rightLayoutTitle => 'BUTTON LAYOUT';
  @override
  String get leftRowTitle => 'LEFT SIDE';
  @override
  String get leftRowTip => 'Up to 2 buttons in a row above the stick, for games that use both sticks.';
  @override
  String get rightLayoutColumnsLabel => 'Columns';
  @override
  String get rightLayoutRowsLabel => 'Rows';
  @override
  String get duplicateNameError => 'A layout with this name already exists';
  @override
  String get nameEmptyError => 'Layout name cannot be empty';
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
    'connection_label_internet': 'Internet',
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

class EnUsCreditsStrings implements CreditsStrings {
  @override
  String get title => 'Credits';
  @override
  String get developer => 'Developed by kedoshim.';
  @override
  String get description => 'MaNet was built with a simple idea: playing with local friends should require less hassle and bring more fun. :)';
  @override
  String get assetsTitle => 'Third-party assets:';
}

class EnUsOnlineStrings implements OnlineStrings {
  @override
  String get buttonTooltip => 'Play online';
  @override
  String get title => 'Play online';
  @override
  String get subtitle =>
      'Creates a public link so people far away can join from their phone, for example while watching your stream.';
  @override
  String get stateOff => 'Off';
  @override
  String get stateStarting => 'Opening connection...';
  @override
  String get stateVerifying => 'Testing the link...';
  @override
  String get stateOnline => 'Online';
  @override
  String get stateError => 'Could not go online';
  @override
  String errorDetail(String? code) => switch (code) {
    'cloudflared_missing' => 'The online connection component is missing. Reinstall MaNet.',
    'unreachable' => 'The link was created but did not respond. Check your internet and try again.',
    _ => 'Check your internet and try again.',
  };
  @override
  String get activate => 'Activate';
  @override
  String get save => 'Save';
  @override
  String get stop => 'Turn off';
  @override
  String get retry => 'Try again';
  @override
  String get copyLink => 'Copy link';
  @override
  String get linkCopied => 'Link copied';
  @override
  String get nowOnline => 'Online! The lobby QR now points to the public link.';
  @override
  String get failedToast => 'Could not go online.';
  @override
  String get openWarning =>
      'Anyone who sees the QR or the link gets in right away. You can kick players at any time, and the link changes every time you go online.';
}

class EnUsAccessStrings implements AccessStrings {
  @override
  String get whoCanJoin => 'Who can join';
  @override
  String get modeOpen => 'Anyone';
  @override
  String get modeOpenHint => 'Gets in right away.';
  @override
  String get modePassword => 'Password';
  @override
  String get modePasswordHint => 'You share the password elsewhere, in the chat for example.';
  @override
  String get modeApproval => 'I approve';
  @override
  String get modeApprovalHint => 'Each person waits for you to accept them here.';
  @override
  String get passwordLabel => 'Room password';
  @override
  String get passwordRequired => 'Enter a password';
  @override
  String wantsToJoin(String name) => '$name wants to join';
  @override
  String get viaInternet => 'over the internet';
  @override
  String get viaLan => 'on the local network';
  @override
  String get accept => 'Accept';
  @override
  String get reject => 'Decline';
  @override
  String get ban => 'Ban';
  @override
  String get kick => 'Kick';
  @override
  String get kickAndBan => 'Kick and ban';
  @override
  String unbanAll(int count) => 'Unban everyone ($count)';
}

class EnUsNetworkStrings implements NetworkStrings {
  @override
  String get modeLocal => 'Local';
  @override
  String get modeBoth => 'Both';
  @override
  String get modeOnline => 'Online';
  @override
  String get chipTooltip => 'Where players join from';
  @override
  String get optionsTooltip => 'Network and access options';
  @override
  String get panelTitle => 'Network and access';
  @override
  String get modeLocalHint => 'Only people on the same Wi-Fi (or the PC hotspot) can join.';
  @override
  String get modeBothHint => 'Both QR codes work at the same time. Use the switch above the QR to pick which one shows.';
  @override
  String get modeOnlineHint => 'Only the public link works. People on the local network cannot join.';
  @override
  String get localColumn => 'Local network';
  @override
  String get onlineColumn => 'Internet';
  @override
  String get defaultRule => 'Default rule';
  @override
  String get localHint => 'For people on the same Wi-Fi or the PC hotspot.';
  @override
  String get ownOnlineRule => 'Separate rule for the internet';
  @override
  String get ownOnlineRuleOff => 'Off: internet players follow the local network rule.';
  @override
  String get ownOnlineRuleOffDefault => 'Off: internet players follow the default rule.';
  @override
  String get hotspotOff => 'PC hotspot is off';
  @override
  String get hotspotOnUnknown => 'PC hotspot is on';
  @override
  String hotspotOn(String ssid) => 'PC hotspot is on: $ssid';
  @override
  String get hotspotHint => 'People without Wi-Fi can join the PC hotspot: its Wi-Fi QR shows in the lobby.';
  @override
  String get wifiQrTitle => 'No Wi-Fi?';
  @override
  String wifiQrCaption(String ssid) => 'Scan to join the $ssid Wi-Fi';
  @override
  String get qrSwitchLabel => 'Which QR to show';
  @override
  String get done => 'Done';
  @override
  String get saved => 'Join rules saved';
}
