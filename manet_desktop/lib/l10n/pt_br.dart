import 'strings.dart';

class PtBrStrings implements AppStrings {
  @override
  final CommonStrings common = PtBrCommonStrings();
  @override
  final StartPageStrings startPage = PtBrStartPageStrings();
  @override
  final ModeSelectionStrings modeSelection = PtBrModeSelectionStrings();
  @override
  final ErrorStrings error = PtBrErrorStrings();
  @override
  final LobbyStrings lobby = PtBrLobbyStrings();
  @override
  final HomeStrings home = PtBrHomeStrings();
  @override
  final SettingsStrings settings = PtBrSettingsStrings();
  @override
  final SlotsStrings slots = PtBrSlotsStrings();
  @override
  final PlayersStrings players = PtBrPlayersStrings();
  @override
  final LayoutEditorStrings layoutEditor = PtBrLayoutEditorStrings();
  @override
  final AlertsStrings alerts = PtBrAlertsStrings();
  @override
  final QrPanelStrings qrPanel = PtBrQrPanelStrings();
  @override
  final CreditsStrings credits = PtBrCreditsStrings();
  @override
  final ControllersStrings controllers = PtBrControllersStrings();
  @override
  final SessionStrings session = PtBrSessionStrings();
  @override
  final OnlineStrings online = PtBrOnlineStrings();
  @override
  final AccessStrings access = PtBrAccessStrings();
  @override
  final NetworkStrings network = PtBrNetworkStrings();
}

class PtBrSessionStrings implements SessionStrings {
  @override
  String get lineupGetReady => 'Preparem-se!';
  @override
  String get consoleEditing => 'editando rostinho...';
  @override
  String get consolePlayTitle => 'Jogar';
  @override
  String get consolePlayHint => 'Entre aqui para selecionar um jogo';
  @override
  String consoleStartingIn(int seconds) => 'Começando em $seconds...';
  @override
  String get consoleJoinTitle => 'Como entrar';
  @override
  String consoleJoinWifi(String name) => 'Conecte no Wi-Fi $name';
  @override
  String consoleJoinNetwork(String name) => 'Conecte na rede $name';
  @override
  String consoleJoinWifiOrHotspot(String wifi, String hotspot) =>
      'Conecte no Wi-Fi $wifi ou no hotspot $hotspot';
  @override
  String consoleJoinScan(String link) => 'Aponte a câmera pro QR code ou acesse $link';
  @override
  String get consoleJoinFace => 'Monte seu rostinho e aperte Pronto';
  @override
  String get lineupTitle => 'Quem joga primeiro?';
  @override
  String lineupSeats(String game, int seats) => '$game tem $seats ${seats == 1 ? 'vaga' : 'vagas'}';
  @override
  String get lineupPlayNow => 'Quero jogar agora';
  @override
  String get lineupBench => 'Começo no banco';
  @override
  String get lineupChooseHint => 'Ande até um dos lados';
  @override
  String get lineupDedanha => 'Dedanha!';
  @override
  String get lineupZerinho => 'Zerinho ou um!';
  @override
  String get lineupDedanhaHint => 'Mostre de 0 a 5 dedos no celular: a soma conta pela roda';
  @override
  String get lineupZerinhoHint => 'Escolha 0 ou 1 no celular: a minoria é decidida';
  @override
  String lineupModeOut(int needed) => '$needed ${needed == 1 ? 'pessoa vai' : 'pessoas vão'} pro banco';
  @override
  String lineupModeIn(int needed) => '$needed ${needed == 1 ? 'vaga' : 'vagas'} pra decidir';
  @override
  String lineupPicked(int picked, int total) => '$picked/$total escolheram';
  @override
  String lineupTotal(int total) => 'Soma: $total';
  @override
  String get lineupTie => 'Empatou! De novo!';
  @override
  String get lineupNarrow => 'A minoria joga de novo!';
  @override
  String get lineupGoesOut => 'vai pro banco';
  @override
  String get lineupGoesIn => 'joga!';
  @override
  String get lineupDone => 'Escalação';
  @override
  String get lineupPlaying => 'Jogando';
  @override
  String get lineupOnBench => 'Banco';
  @override
  String get lineupCancel => 'Cancelar';
  @override
  String readyPrompt(int ready, int total) =>
      'Apertem START quando estiverem prontos · $ready/$total';
  @override
  String get allReady => 'Todo mundo pronto! Aperte START para escolher o jogo';
  @override
  String get controlsInBackground =>
      'Os controles estão indo para os jogos. Clique nesta janela para usá-los no ma•net.';
  @override
  String get chooseGame => 'Escolher jogo';
  @override
  String get ready => 'PRONTO';
  @override
  String get libraryTitle => 'Escolham o jogo';
  @override
  String get libraryHint =>
      'Analógico move · A vota, abre detalhes (i) e filtros · B tira o voto ou fecha detalhes · START decide';
  @override
  String get backToLobby => 'Lobby';
  @override
  String get manageGames => 'Gerenciar jogos';
  @override
  String get emptyLibrary => 'Nenhum jogo cadastrado ainda.';
  @override
  String get addFirstGame => 'Adicionar o primeiro jogo';
  @override
  String playersRange(int min, int max) => min == max
      ? '$min ${min == 1 ? 'jogador' : 'jogadores'}'
      : '$min–$max jogadores';
  @override
  String doesNotFit(int players) =>
      'Não comporta $players ${players == 1 ? 'jogador' : 'jogadores'}';
  @override
  String get clickToPlay => 'Clique para jogar agora';
  @override
  String startingIn(String game) => 'Abrindo $game em';
  @override
  String get cancel => 'Cancelar';
  @override
  String launchError(String code) => switch (code) {
        'path_not_found' => 'Não encontrei o arquivo do jogo. Confira o caminho em Gerenciar jogos.',
        'elevation_cancelled' => 'Esse jogo precisa de permissão de administrador, e o aviso do Windows foi recusado.',
        _ => 'Não consegui abrir o jogo.',
      };
  @override
  String playing(String game) => 'Jogando $game';
  @override
  String get playingHint => 'Quando o jogo fechar, o ma•net volta para o lobby sozinho.';
  @override
  String get untrackedHint =>
      'Esse jogo abriu por um atalho ou launcher, então o ma•net não sabe quando ele fecha.';
  @override
  String get closeGame => 'Fechar jogo';
  @override
  String get returnToLobby => 'Voltar ao lobby';
  @override
  String get gamesTitle => 'Jogos';
  @override
  String get tabGames => 'Jogos';
  @override
  String get tabLauncher => 'Launcher';
  @override
  String get launcherSettingsTitle => 'Aparência do Launcher';
  @override
  String get cardStyleLabel => 'Estilo dos Cards';
  @override
  String get cardStyleCoverOnly => 'Apenas Imagem';
  @override
  String get cardStyleClassic => 'Clássico (com detalhes)';
  @override
  String get gridDensityLabel => 'Linhas da Biblioteca';
  @override
  String get gridRows1 => '1 Linha (Amplo)';
  @override
  String get gridRows2 => '2 Linhas (Padrão)';
  @override
  String get gridRows3 => '3 Linhas (Compacto)';
  @override
  String get sortOrderLabel => 'Ordenação';
  @override
  String get sortRecent => 'Mais Recentes';
  @override
  String get sortAlphabetical => 'Alfabética (A–Z)';
  @override
  String get sortPlayers => 'Por Jogadores';
  @override
  String get manageGamesAndLauncher => 'Jogos e Launcher';
  @override
  String get addGame => 'Adicionar jogo';
  @override
  String get editGame => 'Editar jogo';
  @override
  String get gameName => 'Nome';
  @override
  String get gamePath => 'Executável ou atalho';
  @override
  String get gamePathHint => '.exe, .lnk, .url ou steam://...';
  @override
  String get chooseFile => 'Escolher arquivo';
  @override
  String get gameArguments => 'Argumentos (opcional)';
  @override
  String get gameCover => 'Capa';
  @override
  String get chooseCover => 'Escolher imagem';
  @override
  String get removeCover => 'Remover';
  @override
  String get minPlayers => 'Mínimo de jogadores';
  @override
  String get maxPlayers => 'Máximo de jogadores';
  @override
  String get gameLayout => 'Layout do controle';
  @override
  String get noLayout => 'Manter o atual';
  @override
  String get gameMode => 'Tipo de controle';
  @override
  String get keepMode => 'Manter o atual';
  @override
  String get saveGame => 'Salvar';
  @override
  String get deleteGame => 'Excluir';
  @override
  String deleteGameConfirm(String game) => 'Excluir "$game" da biblioteca?';
  @override
  String get saveError => 'Não deu para salvar. Confira nome e caminho.';
  @override
  String get findCover => 'Buscar capa';
  @override
  String get coverSearchTitle => 'Buscar capa';
  @override
  String get coverSearch => 'Buscar';
  @override
  String get coverSteamHint => 'Capas e dados da Steam e do IGDB. Clique em uma para usar.';
  @override
  String get coverNoResults => 'Nada encontrado com esse nome.';
  @override
  String get coverSearchError => 'Não consegui buscar agora. Confira a internet.';
  @override
  String get coverDownloadError => 'Não consegui baixar essa imagem.';
  @override
  String get coverOtherSources => 'Ou procure em outro lugar';
  @override
  String get coverGoogle => 'Google Imagens';
  @override
  String get coverGoogleSuffix => 'capa jogo';
  @override
  String get coverPasteLink => 'Cole aqui o link de uma imagem';
  @override
  String get coverUseLink => 'Usar';
  @override
  String get createLayout => 'Criar layout novo';
  @override
  String get rulesTitle => 'Por número de jogadores';
  @override
  String get rulesHint =>
      'Troque o tipo de controle ou o layout conforme quantas pessoas vão jogar. A primeira regra que servir vale.';
  @override
  String get addRule => '+ Regra';
  @override
  String get suggestXinputRule => 'x•input até 4, d•input acima';
  @override
  String get ruleFrom => 'De';
  @override
  String get ruleTo => 'a';
  @override
  String get displayTitle => 'Tela do jogo';
  @override
  String get displayAuto => 'Deixar o jogo escolher';
  @override
  String displayLabel(int number, bool primary, int width, int height) =>
      'Tela $number${primary ? ' (principal)' : ''} · $width×$height';
  @override
  String get fullscreenGame => 'Abrir em tela cheia';
  @override
  String get fullscreenGameHint => 'Se o jogo abrir em janela, o ma•net estica ela na tela inteira, sem bordas.';
  @override
  String get overlayHint => '↑ ↓ escolhe · A confirma · B volta · Home fecha';
  @override
  String get overlayResume => 'Voltar ao jogo';
  @override
  String get awayTitle => 'Jogo pausado: ninguém conectado';
  @override
  String get awayScan => 'Escaneie o QR code para continuar jogando';
  @override
  String awayClosesIn(String time) => 'O jogo fecha em $time e o MaNet volta ao lobby. O progresso não salvo será perdido.';
  @override
  String get awayClosesUntracked => 'O MaNet não consegue fechar este jogo: ele volta ao lobby e o jogo continua aberto atrás.';
  @override
  String get awayWaits => 'O jogo vai esperar vocês.';
  @override
  String get awayChooseTitle => 'Bem-vindos de volta!';
  @override
  String get awayResume => 'Continuar o jogo';
  @override
  String get awaySwitch => 'Escolher outro jogo';
  @override
  String get overlayAddPlayers => 'Adicionar jogadores';
  @override
  String get overlayLayout => 'Layout do controle';
  @override
  String get overlaySwitchGame => 'Trocar de jogo';
  @override
  String overlayConfirm(String action) => '$action? Aperte de novo';
  @override
  String get overlayPlayersTitle => 'Chama mais gente!';
  @override
  String get overlayQrZoom => 'Selecionar amplia o QR code';
  @override
  String get overlayPlayersHint => 'Aponte a câmera do celular para o QR code ou abra o link.';
  @override
  String get overlayLayoutTitle => 'Layout do controle';
  @override
  String overlayControlledBy(String name) => 'Quem controla: $name';
  @override
  String get inputPausedHint =>
      'Os controles estão pausados enquanto o jogo não estiver na frente, para não mexerem em outros programas.';
  @override
  String get coverInvalidLink => 'Isso não parece um link. Cole o endereço completo da imagem.';
  @override
  String get coverNotAnImage =>
      'Esse link abre uma página, não uma imagem. Clique com o botão direito na imagem e use "Copiar endereço da imagem".';
  @override
  String get overlayInCharge => 'está no comando';
  @override
  String get overlayHostOwner => 'Menu aberto no PC';
  @override
  String get overlaySeatsHint => 'Para trocar de lugar ou ir pro banco, use o botão Lugar no celular.';
  @override
  String get freeSeat => 'Livre';
  @override
  String playersInSession(int count) =>
      count == 1 ? '1 jogador na sessão' : '$count jogadores na sessão';
  @override
  String sortLabel(int sort) => switch (sort) {
    1 => 'Recentes',
    2 => 'Mais jogadores',
    _ => 'A–Z',
  };
  @override
  String fitsOnly(int players) => 'Cabem $players';
  @override
  String get clearFilters => 'Limpar';
  @override
  String get noGamesMatch => 'Nenhum jogo com esses filtros.';
  @override
  String playersShort(int min, int max) => min == max ? '$min' : '$min–$max';
  @override
  String get gameDetails => 'Detalhes';
  @override
  String get noDescription => 'Sem descrição ainda.';
  @override
  String fitsSession(int players) =>
      players == 1 ? 'Dá pra jogar sozinho' : 'Dá pra jogar com os $players';
  @override
  String get closeDetails => 'Fechar';
  @override
  String get voteForThis => 'Votar neste';
  @override
  String get watchTrailer => 'Ver trailer';
  @override
  String get gameDescription => 'Descrição';
  @override
  String get gameDescriptionHint => 'Uma ou duas frases sobre o jogo';
  @override
  String get gameTags => 'Tags';
  @override
  String get gameTagsHint => 'Separadas por vírgula: Corrida, Festa, Co-op local';
  @override
  String get gameTrailer => 'Trailer';
  @override
  String get gameTrailerHint => 'Link do vídeo (YouTube, Steam...)';
  @override
  String get gameImages => 'Imagens';
  @override
  String get gameImagesHint => 'Links de imagens, um por linha (aparecem no card e nos celulares)';
  @override
  String get searchTrailer => 'Buscar no YouTube';
  @override
  String get steamInfoLoading => 'Buscando descrição e detalhes do jogo...';
  @override
  String get fetchData => 'Buscar dados';
  @override
  String get fetchDataHint => 'Busca o jogo na internet e você escolhe o que preencher: capa, descrição, tags, trailer e imagens';
  @override
  String get dataPreviewTitle => 'O que preencher?';
  @override
  String get dataPreviewHint => 'Marque o que você quer usar desta busca.';
  @override
  String get dataWillReplace => 'Substitui o que já está preenchido';
  @override
  String get dataNothingFound => 'Nenhum dado extra encontrado para este jogo.';
  @override
  String get applyData => 'Preencher';
  @override
  String get addImage => 'Adicionar imagem';
  @override
  String get addImageConfirm => 'Adicionar';
  @override
  String get imageLinkHint => 'Cole o link da imagem';
  @override
  String get imageLoadError => 'Não foi possível carregar esta imagem';
  @override
  String loadingGame(String game) => 'Abrindo $game';
  @override
  List<String> get loadingLines => const [
    'Soprando o cartucho',
    'Esquentando os controles',
    'Ajustando a antena',
    'Desembaraçando o fio do controle',
    'Escolhendo o melhor lugar no sofá',
    'Pegando a pipoca',
    'Carregando os polígonos',
    'Acordando os NPCs',
  ];
  @override
  String loadingElapsed(int seconds) => '${seconds}s';
  @override
  String get loadingSlowHint => 'Demorando? Se o jogo já abriu, START mostra ele.';
  @override
  String get loadingShowGame => 'Mostrar o jogo';
  @override
  String get tournamentTitle => 'Torneio!';
  @override
  String tournamentIntro(int games) =>
      '$games jogos na disputa: em cada duelo, o mais votado avança';
  @override
  String tournamentRound(int matches, int round, int rounds) => switch (matches) {
    1 => 'Final',
    2 => 'Semifinal',
    4 => 'Quartas de final',
    _ => 'Rodada $round de $rounds',
  };
  @override
  String get tournamentLean =>
      'Leve seu rostinho para o lado do jogo que você quer jogar';
  @override
  String tournamentVotes(int count) => count == 1 ? '1 voto' : '$count votos';
  @override
  String tournamentAdvances(String game) => '$game avança!';
  @override
  String tournamentDraw(String game) => 'Empate! No sorteio, $game avança.';
  @override
  String tournamentChampion(String game) => 'Vamos jogar $game!';
  @override
  String get tournamentCancel => 'Biblioteca';
  @override
  String get lobbyCountdown => 'Todo mundo pronto! Abrindo a escolha de jogos…';
  @override
  String get freeMode => 'Modo livre';
  @override
  String get freeModeHint => 'Abra qualquer jogo com o mouse. Os celulares funcionam como controles comuns; aperte Home no celular para voltar.';
  @override
  String get leaveFreeMode => 'Sair do modo livre';
  @override
  String lobbyRequest(String name, int yes, int needed) =>
      '$name quer voltar ao lobby · $yes/$needed concordam';
  @override
  String get statusChoosing => 'escolhendo';
  @override
  String statusReading(String game) => 'lendo sobre $game';
  @override
  String get statusWantsLobby => 'quer voltar ao lobby';
  @override
  String votedCount(int voted, int total) => '$voted de $total escolheram';
}

class PtBrControllersStrings implements ControllersStrings {
  @override
  String get diagnosticsTitle => 'Diagnóstico';
  @override
  String get allGood => 'Tudo certo: o Windows só está vendo o que deveria.';
  @override
  String predictionWarning(int pads, int free, int out) =>
      'O ma•net usa $pads ${pads == 1 ? 'controle' : 'controles'} x•input, mas só $free das '
      '4 vagas do Windows ${free == 1 ? 'está livre' : 'estão livres'}: $out ${out == 1 ? 'jogador fica' : 'jogadores ficam'} '
      'de fora e jogos x•input não vão enxergá-${out == 1 ? 'lo' : 'los'}. Desconecte os outros controles ou use d•input.';
  @override
  String get windowsSeesTitle => 'O que o Windows está vendo';
  @override
  String get windowsSeesHint => 'Todos os controles de jogo conectados neste PC agora.';
  @override
  String get colDevice => 'Dispositivo';
  @override
  String get colType => 'Tipo';
  @override
  String get colSource => 'Quem criou';
  @override
  String get sourceManet => 'ma•net';
  @override
  String get sourcePhysical => 'Controle real';
  @override
  String get sourceSteam => 'Steam Input';
  @override
  String get sourceUnknown => 'Outro programa';
  @override
  String get outOfXinput => 'Ficaram de fora';
  @override
  String get appsTitle => 'Programas que podem criar controles';
  @override
  String get appsHint => 'O Windows não diz qual programa criou cada controle virtual; estes estão abertos agora.';
  @override
  String get appsEmpty => 'Nenhum programa conhecido aberto.';
  @override
  String likelySources(String apps) => 'Provavelmente: $apps';
  @override
  String get title => 'Controles no Windows';
  @override
  String get tooltip => 'Controles conectados';
  @override
  String summary(int total, int own) =>
      'O Windows está vendo $total ${total == 1 ? 'controle' : 'controles'}. '
      '$own ${own == 1 ? 'é' : 'são'} do ma•net.';
  @override
  String get xinputTitle => 'Vagas x•input';
  @override
  String get xinputSubtitle =>
      'O Windows só tem 4 vagas x•input. A ordem aqui é a mesma da luz do controle.';
  @override
  String get xinputFree => 'Livre';
  @override
  String get xinputOther => 'Outro controle';
  @override
  String xinputPlayer(int player) => 'Jogador $player';
  @override
  String noXinputWarning(int count) =>
      '$count ${count == 1 ? 'jogador do ma•net ficou' : 'jogadores do ma•net ficaram'} '
      'sem vaga x•input: jogos x•input não vão enxergá-${count == 1 ? 'lo' : 'los'}. '
      'Desconecte os outros controles ou use d•input.';
  @override
  String foreignWarning(int count) =>
      '$count ${count == 1 ? 'controle virtual não é' : 'controles virtuais não são'} deste ma•net: '
      'de outro programa, ou presos no driver depois de uma sessão que travou '
      '(esses somem ao reiniciar o PC).';
  @override
  String get devicesTitle => 'Dispositivos detectados';
  @override
  String get devicesEmpty => 'Nenhum controle detectado.';
  @override
  String get originVirtual => 'Virtual';
  @override
  String get originSteam => 'Steam';
  @override
  String get originPhysical => 'Físico';
  @override
  String deviceLabel(String vendor) => switch (vendor) {
        'xbox' => 'Controle Xbox',
        'playstation' => 'Controle PlayStation',
        'nintendo' => 'Controle Nintendo',
        'steam' => 'Controle Steam',
        _ => 'Controle genérico',
      };
  @override
  String staleServersWarning(int count) =>
      '${count == 1 ? 'Um servidor antigo' : '$count servidores antigos'} do ma•net '
      '${count == 1 ? 'continua aberto e mantém' : 'continuam abertos e mantêm'} controles conectados.';
  @override
  String get closeStaleServers => 'Fechar servidores antigos';
  @override
  String closedServers(int count) =>
      count == 0 ? 'Nenhum servidor antigo encontrado.' : '$count ${count == 1 ? 'servidor fechado' : 'servidores fechados'}.';
  @override
  String get recreate => 'Recriar controles';
  @override
  String get recreateHint =>
      'Desconecta e cria de novo os controles do ma•net. Os jogadores continuam nos mesmos lugares.';
  @override
  String get recreated => 'Controles recriados.';
  @override
  String get refresh => 'Atualizar';
  @override
  String get loadError => 'Não foi possível ler os controles do Windows.';
  @override
  String get actionError => 'Não deu certo. Tente de novo.';
  @override
  String playerMapping(int player, int windowsIndex) =>
      'Jogador $player é o controle $windowsIndex no Windows';
  @override
  String playerNoXinput(int player) => 'Jogador $player está sem vaga x•input';
}

class PtBrCommonStrings implements CommonStrings {
  @override
  String get cancel => 'Cancelar';
  @override
  String get confirm => 'Confirmar';
  @override
  String get save => 'Salvar';
  @override
  String get error => 'Erro';
  @override
  String get success => 'Sucesso';
  @override
  String get ok => 'OK';
  @override
  String get delete => 'Excluir';
  @override
  String get close => 'Fechar';
}

class PtBrStartPageStrings implements StartPageStrings {
  @override
  String get appTitle => 'ma•net';
  @override
  String get startParty => 'iniciar a festa';
  @override
  String get startDebug => 'iniciar debug';
  @override
  String version(String v) => 'v$v';
}

class PtBrModeSelectionStrings implements ModeSelectionStrings {
  @override
  String get title => 'preparar a festa!';
  @override
  String get subtitle => 'Como os celulares serão reconhecidos no computador?';
  @override
  String get xinputTitle => 'x•input';
  @override
  String get xinputHeadline => 'Recomendado: até 4 controles';
  @override
  String get xinputDetails => 'Alta compatibilidade e vibração.';
  @override
  String get dinputTitle => 'd•Input';
  @override
  String get dinputHeadline => 'Ideal para: 5+ controles';
  @override
  String get dinputDetails => 'Sem limites, mas sem vibração.';
  @override
  String get cancel => 'Cancelar';
  @override
  String get play => 'vamos jogar!';
}

class PtBrErrorStrings implements ErrorStrings {
  @override
  String get startupTitle => 'Erro na Inicialização';
  @override
  String get installDriver => 'Instalar Driver';
  @override
  String get installDriverErrorTitle => 'Erro de Instalação';
  @override
  String get installDriverErrorMessage => 'Falha ao localizar o instalador do ViGEmBus.';
  @override
  String get invalidPortTitle => 'Porta Inválida';
  @override
  String get invalidPortMessage => 'A porta informada não é válida. Utilize um valor entre 1024 e 65535.';
  @override
  String get connectionErrorTitle => 'Erro de Conexão';
  @override
  String get connectionErrorMessage => 'Não foi possível conectar ao servidor em execução na porta informada.';
  @override
  String get applyConfigErrorTitle => 'Erro ao aplicar configurações';
  @override
  String applyConfigErrorMessage(String error) => 'Falha ao aplicar as configurações no servidor: $error';
  @override
  String get layoutImportErrorTitle => 'Erro ao Importar';
  @override
  String get layoutImportErrorMessage => 'Falha ao importar o arquivo de layout.';
  @override
  String get noLogs => 'Nenhum log.';
  @override
  String get retry => 'Tentar novamente';
  @override
  String get logsCopied => 'Logs copiados para a área de transferência!';
  @override
  String get copyLogs => 'Copiar Logs';
  @override
  String get selectPresetErrorTitle => 'Erro ao selecionar preset';
  @override
  String selectPresetErrorMessage(String error) => 'Não foi possível selecionar o preset: $error';
  @override
  String get loadPresetsErrorTitle => 'Erro ao carregar presets';
  @override
  String loadPresetsErrorMessage(String error) => 'Falha ao carregar catálogo de presets: $error';
  @override
  String get applyModeErrorTitle => 'Falha ao aplicar modo';
  @override
  String applyModeErrorBody(String error) => 'Falha ao aplicar modo: $error';
}

class PtBrLobbyStrings implements LobbyStrings {
  @override
  String get lockTooltipReserve => 'Novos jogadores entram no banco de reservas';
  @override
  String get lockTooltipAuto => 'Novos jogadores recebem uma manete automaticamente';
  @override
  String get xinput => 'x•input';
  @override
  String get dinput => 'd•input';
}

class PtBrHomeStrings implements HomeStrings {
  @override
  String get waitingPlayers => 'Aguardando jogadores...';
  @override
  String get qrCodeTitle => 'Conecte sua manete!';
  @override
  String get joinIn => 'Entra aí :)';
  @override
  String get qrCodeInstruction => 'Aponte a câmera do seu celular para o QR Code abaixo ou acesse o link no seu navegador:';
  @override
  String get qrCodeNetworkError => 'Sem conexão de rede local';
  @override
  String get qrCodeNetworkErrorDetails => 'Verifique se o seu computador está conectado à rede.';
  @override
  String get qrCodeModeTip => 'Dica: troque entre XInput e DInput se necessário.';
  @override
  String get onboardingTitle => 'Bem-vindo ao ma.net! :)';
  @override
  String get onboardingSubtitle => 'Use seus celulares como controles de videogame de forma simples e divertida.';
  @override
  String get onboardingNext => 'Próximo';
  @override
  String get onboardingDone => 'Começar';
  @override
  String get onboardingSkip => 'Pular';
  @override
  String get onboardingBack => 'Voltar';
  @override
  String get onboardingStepConnectTitle => 'Conecte na mesma rede';
  @override
  String get onboardingStepConnectBody => 'Seu celular e computador precisam estar na mesma rede para conversarem.';
  @override
  String get onboardingStepArrangeTitle => 'Aponte para o QR Code';
  @override
  String get onboardingStepArrangeBody => 'Abra a câmera ou o app no celular e escaneie o código na tela do PC.';
  @override
  String get onboardingStepPlayTitle => 'Jogue 🎉';
  @override
  String get onboardingStepPlayBody => 'Pronto! Agora é só chamar a galera, escolher seu controle e começar a jogar.';
  @override
  String get wifiOffTitle => 'Computador desconectado da rede';
  @override
  String get wifiOffBody => 'Conecte-se a uma rede para continuar usando os controles.';
  @override
  String get removeControllersTitle => 'Remover controles?';
  @override
  String get removeControllersBody => 'Remover controles pode desconectar jogadores atuais';
  @override
  String get selectModeBarrierLabel => 'Seleção de modo';
  @override
  String get wifi => 'Wi-Fi';
  @override
  String get ethernet => 'Ethernet (Cabo)';
  @override
  String get hotspot => 'Hotspot';
  @override
  String get newNetwork => 'Nova Rede';
}

class PtBrSettingsStrings implements SettingsStrings {
  @override
  String get mousePasswordTitle => 'Senha do modo mouse';
  @override
  String get mousePasswordHint => 'Os celulares precisam dela pra controlar o mouse do PC (no modo livre não precisa). Vazia: modo mouse só no modo livre.';
  @override
  String get lobbyStartTitle => 'Começar a escolha de jogo quando';
  @override
  String get lobbyStartHint => 'As pessoas saem pela borda direita. Ninguém pode estar montando o rostinho.';
  @override
  String get lobbyStartMajority => 'A maioria sair';
  @override
  String get lobbyStartAll => 'Todos saírem';
  @override
  String get title => 'Opções';
  @override
  String get colorsTitle => 'Cores do ma.net';
  @override
  String get timeoutTitle => 'Tempo de reserva para jogadores desconectados';
  @override
  String timeoutValue(int minutes) => '$minutes min';
  @override
  String get languageTitle => 'Idioma';
  @override
  String get fullScreenTitle => 'Tela cheia (F11)';
  @override
  String get matchSecondsTitle => 'Tempo de cada duelo do torneio';
  @override
  String matchSecondsValue(int seconds) => '${seconds}s';
  @override
  String get abandonCloseTitle => 'Fechar jogo abandonado após';
  @override
  String get abandonCloseHint => 'Contado depois que todos os celulares saem. Quem voltar antes pode continuar o jogo no mesmo lugar.';
  @override
  String abandonCloseValue(int minutes) => minutes == 0 ? 'Nunca' : '$minutes min';
  @override
  String get freeModeTitle => 'Modo livre';
  @override
  String get freeModeHint => 'Permite minimizar o MaNet na escolha de jogos para os celulares virarem controles comuns em qualquer jogo.';
  @override
  String get consoleModeTitle => 'Modo console';
  @override
  String get consoleModeHint => 'Ligado: as pessoas só entram e os controles são criados quando um jogo abre. Desligado: modo ferramenta, com o lobby técnico de slots, x/d•input e layout.';
}

class PtBrSlotsStrings implements SlotsStrings {
  @override
  String slotNumber(int index) => 'Slot $index';
  @override
  String get slotLocked => 'Bloqueado';
  @override
  String get slotEmpty => 'Vazio';
  @override
  String slotConnected(String name) => 'Jogador $name conectado';
}

class PtBrPlayersStrings implements PlayersStrings {
  @override
  String connectedCount(int count) => count == 1 ? '1 jogador conectado' : '$count jogadores conectados';
  @override
  String playerConnected(String name) => 'Jogador $name se conectou';
  @override
  String get reserveBench => 'Banco de Reservas';
  @override
  String get emptyBench => 'banco de reservas';
}

class PtBrLayoutEditorStrings implements LayoutEditorStrings {
  @override
  String get title => 'Editor de Layout';
  @override
  String get saveButton => 'Salvar Layout';
  @override
  String get resetButton => 'Restaurar Padrão';
  @override
  String get browserTitle => 'Layouts Disponíveis';
  @override
  String get noLayouts => 'Nenhum layout personalizado encontrado.';
  @override
  String get importButton => 'Importar Layout';
  @override
  String get exportButton => 'Exportar Layout';
  @override
  String get defaultLayoutName => 'Padrão';
  
  @override
  String get deleteLayoutTitle => 'Excluir layout';
  @override
  String deleteLayoutConfirm(String name) => 'Deseja excluir "$name"?';
  @override
  String get createLayoutButton => 'Criar layout';
  @override
  String get basicLayoutsTitle => 'Layouts básicos';
  @override
  String get extraCustomLayoutsTitle => 'Extras e Personalizados';
  @override
  String get badgeGame => 'Jogo';
  @override
  String get badgeCustom => 'Personalizado';
  @override
  String get activeBadge => 'Atual';
  @override
  String get editButton => 'Editar';
  @override
  String get deleteButton => 'Excluir';
  
  @override
  String get defaultNewLayoutName => 'Meu Layout 001';
  @override
  String get nameHint => 'Nome do Layout';
  @override
  String get createButtonUpper => 'CRIAR';
  @override
  String get saveButtonUpper => 'SALVAR';
  
  @override
  String get movementModeTitle => 'MODO DE MOVIMENTO';
  
  @override
  String get dpadLabel => 'D-Pad';
  @override
  String get dpadHeadline => 'Digital Preciso';
  @override
  String get dpadDesc => 'Ideal para jogos de plataforma e luta.';
  
  @override
  String get fixedJoystickLabel => 'Joystick Fixo';
  @override
  String get fixedJoystickHeadline => 'Analógico Estático';
  @override
  String get fixedJoystickDesc => 'Posição fixa na tela para memória muscular.';
  
  @override
  String get floatingJoystickLabel => 'Joystick Flutuante';
  @override
  String get floatingJoystickHeadline => 'Dinâmico';
  @override
  String get floatingJoystickDesc => 'O joystick aparece onde você toca.';
  
  @override
  String get visibleButtonsTitle => 'BOTÕES VISÍVEIS';
  @override
  String get visibleButtonsTip => 'Toque nos botões para ativar ou desativar no seu layout.';
  @override
  String get rightSticksTitle => 'ANALÓGICOS DIREITOS';
  @override
  String get rightStickFixedLabel => 'Analógico direito fixo';
  @override
  String get rightStickFloatingLabel => 'Analógico direito flutuante';
  @override
  String get rightStickSwipeLabel => 'Touchpad';
  @override
  String get aimButtonsTitle => 'BOTÕES DE MIRA';
  @override
  String get aimButtonsTip =>
      'Botões do lado direito que também miram. Tocar é só o botão; arrastar segura o botão e mexe o analógico direito, para mirar e atirar com o mesmo dedo.';
  @override
  String get rightStickFireTitle => 'ATIRAR COM O ANALÓGICO DIREITO';
  @override
  String get rightStickFireTip =>
      'Mirar e atirar com o mesmo dedo. Ao tocar: o botão fica apertado enquanto o analógico é tocado. Anel: só quando o analógico passa do anel. O jogador pode mudar no celular.';
  @override
  String get rightStickFireOff => 'Desligado';
  @override
  String get rightStickFireTouch => 'Ao tocar';
  @override
  String get rightStickFireRing => 'Anel';
  @override
  String get rightLayoutTitle => 'ARRANJO DOS BOTÕES';
  @override
  String get leftRowTitle => 'LADO ESQUERDO';
  @override
  String get leftRowTip => 'Até 2 botões numa linha acima do analógico, para jogos que usam os dois analógicos.';
  @override
  String get rightLayoutColumnsLabel => 'Colunas';
  @override
  String get rightLayoutRowsLabel => 'Linhas';
  @override
  String get duplicateNameError => 'Já existe um layout com este nome';
  @override
  String get nameEmptyError => 'O nome do layout não pode ficar vazio';
}

class PtBrAlertsStrings implements AlertsStrings {
  @override
  String get title => 'Avisos e Erros';
  @override
  String get noAlerts => 'Nenhum alerta.';
  @override
  String get tooltip => 'Avisos e Erros';
  @override
  String networkChangedAlert(String kindName, String address) => 'Rede alterada para $kindName (Endereço: $address)';
  @override
  String get networkChangedTitle => 'Rede alterada! :)';
  @override
  String networkChangedBody(String kindName) => 'Conexão atualizada para $kindName.';
  @override
  String get view => 'Ver';
  @override
  String get xinputLimitWarning => 'Alguns jogos podem não suportar mais de 4 controles x•input. Se tiver problemas, tente d•input.';
}

class PtBrQrPanelStrings implements QrPanelStrings {
  @override
  Map<String, String> get textMap => const {
    'connection_label_this_device': 'Este dispositivo',
    'connection_label_wifi': 'Wi-Fi',
    'connection_label_ethernet': 'Cabo',
    'connection_label_hotspot': 'Hotspot',
    'connection_label_backup': 'Extra',
    'connection_label_internet': 'Internet',
    'ui_more_connections': 'Outras formas de conectar',
    'ui_more': 'Mais',
    'ui_copied': 'Link copiado',
    'ui_chip_selected': 'Na tela',
    'ui_chip_recommended': 'Melhor escolha',
    'ui_chip_preferred': 'Salvo',
    'ui_chip_last_success': 'Funcionou',
    'ui_use_this': 'Usar esta',
    'ui_showing': 'Exibindo',
    'ui_connection_fallback': 'Conexão',
    'ui_connection_hint_wifi': 'Os celulares entram pela mesma rede Wi-Fi.',
    'ui_connection_hint_hotspot': 'Bom quando o computador compartilha o sinal.',
    'ui_connection_hint_ethernet': 'Útil quando o PC está na internet a cabo.',
    'ui_connection_hint_backup': 'Vale tentar se a primeira não funcionar.',
    'diag_button_label': 'Ajuda',
    'diag_sheet_title': 'Assistente de conexão',
    'diag_sheet_healthy': 'Tudo pronto para jogar!',
    'diag_sheet_attention': 'Algumas coisas podem estar atrapalhando.',
    'diag_action_refresh': 'Atualizar',
    'diag_action_copy_link': 'Copiar link',
    'diag_action_firewall': 'Abrir Firewall',
    'diag_action_firewall_advanced': 'Firewall Avançado',
    'diag_title_server_started': 'Servidor iniciado',
    'diag_body_server_started': 'Sua sala de jogos está ativa e esperando.',
    'diag_title_qr_ready': 'Código QR pronto',
    'diag_body_qr_ready': 'Os amigos podem ler o código para entrar.',
    'diag_title_no_network': 'Nenhuma rede local encontrada',
    'diag_body_no_network': 'Este computador não parece conectado a uma rede para os celulares ainda.',
    'diag_title_local_only': 'Este código fica apenas no computador',
    'diag_body_local_only': 'Os celulares podem não alcançar esta sala. Tente atualizar a escolha de rede.',
    'diag_title_multiple_networks': 'Mais de uma rede encontrada',
    'diag_body_multiple_networks': 'Se um código não funcionar, tente mudar para outra fonte de rede.',
    'diag_title_hotspot_permission': 'Hotspot pode precisar de permissão',
    'diag_body_hotspot_permission': 'Usando modo hotspot? O Windows pode precisar liberar o acesso à rede Pública.',
    'diag_title_reachability': 'Celulares podem ter problemas para alcançar esta sala',
    'diag_body_reachability': 'Tente atualizar a fonte de rede ou mudar para outra.',
    'diag_title_firewall_hint': 'Firewall pode estar bloqueando celulares',
    'diag_body_firewall_hint': 'Se ninguém conseguir entrar após ler, o Windows Firewall é um motivo comum.',
    'diag_title_hotspot_waiting': 'Hotspot ainda esperando jogadores',
    'diag_body_hotspot_waiting': 'Se os celulares virem o hotspot mas não entrarem, tente liberar o acesso Público.',
    'diag_tip_title': 'Se os celulares não conseguirem entrar',
    'diag_tip_line_1': '1. Coloque todos na mesma rede',
    'diag_tip_line_2': '2. Permita o acesso no Windows Firewall',
    'diag_tip_line_3': '3. Tente o Hotspot se o Wi-Fi falhar',
    'diag_tip_got_it': 'Entendido',
    'diag_action_done': 'Assistente aberto',
  };

  @override
  String get currentNetworkLabel => 'Rede atual';
  @override
  String get fallbackNetworkLabel => 'Conexão';
  @override
  String get sameNetworkLabel => 'Mesma rede do PC';
  @override
  String get ethernetNetworkLabel => 'Rede Local (Cabo)';
  @override
  String get activeHotspotLabel => 'Hotspot Ativo';
  @override
  String get helpButtonLabel => 'Ajuda';
  @override
  String get qrCreating => 'Criando QR...';
  @override
  String get qrMissing => 'Sem QR';
  @override
  String get orAccessLink => 'ou acesse o link:';
  @override
  String get otherConnectionsTooltip => 'Outras formas de conectar';
  @override
  String get useConnectionButton => 'Usar';

  @override
  String get faqTitle => 'Guia Rápido de Conexão';
  @override
  String get faqCommonProblems => 'Problemas Comuns';

  @override
  String get faqStep1Title => 'Fique na mesma rede';
  @override
  String get faqStep1Desc => 'Seu computador e os celulares precisam estar conectados no mesmo Wi-Fi.';
  @override
  String get faqStep2Title => 'Escaneie o QR Code';
  @override
  String get faqStep2Desc => 'Abra a câmera do celular ou um leitor de QR Code e aponte para a tela.';
  @override
  String get faqStep3Title => 'Acesse pelo link';
  @override
  String get faqStep3Desc => 'Se o QR Code falhar, digite o link exibido na tela no navegador do celular.';

  @override
  String get faqNoAlternativeNetworks => 'Nenhuma rede alternativa encontrada.';

  @override
  String get faqWifiOffTitle => 'O celular não conecta';
  @override
  String get faqWifiOffDesc => 'O celular e o PC podem não estar se comunicando.';
  @override
  String wifiOffSolution({String? networkName, String? kind}) {
    if (kind == 'ethernet') {
      return '• O PC está no cabo. Certifique-se que o celular está no Wi-Fi da rede local\n• Veja se o Firewall do Windows está bloqueando\n• Tente recarregar a página';
    }
    if (networkName != null && networkName.isNotEmpty) {
      return '• Verifique se o celular está conectado na rede:\n  "$networkName"\n• Veja se o Firewall do Windows está bloqueando\n• Tente recarregar a página';
    }
    return '• Verifique se ambos estão no mesmo Wi-Fi\n• Veja se o Firewall do Windows está bloqueando\n• Tente recarregar a página do celular';
  }

  @override
  String get faqGameControllerNotWorkingTitle => 'O controle não funciona no jogo';
  @override
  String get faqGameControllerNotWorkingDesc => 'Alguns jogos só reconhecem tipos específicos de controles.';
  @override
  String get faqGameControllerNotWorkingSolution =>
      '• Tente trocar entre XInput e DInput nas configurações\n• Alguns jogos funcionam melhor com modos diferentes';

  @override
  String get faqPlayerLimitTitle => 'Mais de 4 jogadores não funcionam';
  @override
  String get faqPlayerLimitDesc => 'O Windows limita controles XInput a no máximo 4 jogadores.';
  @override
  String get faqPlayerLimitSolution =>
      '• Sugerimos trocar o modo do servidor para DInput para jogar com mais pessoas';
}

class PtBrCreditsStrings implements CreditsStrings {
  @override
  String get title => 'Créditos';
  @override
  String get developer => 'Desenvolvido por kedoshim.';
  @override
  String get description => 'O MaNet foi criado com uma ideia simples em mente: jogar com amigos locais deve ser simples, direto e muito divertido. :)';
  @override
  String get assetsTitle => 'Recursos de terceiros:';
}

class PtBrOnlineStrings implements OnlineStrings {
  @override
  String get buttonTooltip => 'Jogar online';
  @override
  String get title => 'Jogar online';
  @override
  String get subtitle =>
      'Gera um link público para quem está longe entrar pelo celular, por exemplo assistindo sua live.';
  @override
  String get stateOff => 'Desligado';
  @override
  String get stateStarting => 'Abrindo conexão...';
  @override
  String get stateVerifying => 'Testando o link...';
  @override
  String get stateOnline => 'Online';
  @override
  String get stateError => 'Não foi possível ficar online';
  @override
  String errorDetail(String? code) => switch (code) {
    'cloudflared_missing' => 'O componente de conexão online não foi encontrado. Reinstale o MaNet.',
    'unreachable' => 'O link foi criado, mas não respondeu. Verifique sua internet e tente de novo.',
    _ => 'Verifique sua internet e tente de novo.',
  };
  @override
  String get activate => 'Ativar';
  @override
  String get save => 'Salvar';
  @override
  String get stop => 'Desligar';
  @override
  String get retry => 'Tentar de novo';
  @override
  String get copyLink => 'Copiar link';
  @override
  String get linkCopied => 'Link copiado';
  @override
  String get nowOnline => 'Online! O QR do lobby agora leva ao link público.';
  @override
  String get failedToast => 'Não foi possível ficar online.';
  @override
  String get openWarning =>
      'Quem vir o QR ou o link entra direto. Você pode expulsar jogadores a qualquer momento, e o link muda a cada vez que você fica online.';
}

class PtBrAccessStrings implements AccessStrings {
  @override
  String get whoCanJoin => 'Quem pode entrar';
  @override
  String get modeOpen => 'Qualquer pessoa';
  @override
  String get modeOpenHint => 'Entra direto.';
  @override
  String get modePassword => 'Com senha';
  @override
  String get modePasswordHint => 'Você passa a senha por fora, no chat por exemplo.';
  @override
  String get modeApproval => 'Eu aprovo';
  @override
  String get modeApprovalHint => 'Cada pessoa espera você aceitar aqui na tela.';
  @override
  String get passwordLabel => 'Senha da sala';
  @override
  String get passwordRequired => 'Digite uma senha';
  @override
  String wantsToJoin(String name) => '$name quer entrar';
  @override
  String get viaInternet => 'pela internet';
  @override
  String get viaLan => 'pela rede local';
  @override
  String get accept => 'Aceitar';
  @override
  String get reject => 'Recusar';
  @override
  String get ban => 'Banir';
  @override
  String get kick => 'Expulsar';
  @override
  String get kickAndBan => 'Expulsar e banir';
  @override
  String unbanAll(int count) => 'Desbanir todos ($count)';
}

class PtBrNetworkStrings implements NetworkStrings {
  @override
  String get modeLocal => 'Local';
  @override
  String get modeBoth => 'Ambos';
  @override
  String get modeOnline => 'Online';
  @override
  String get chipTooltip => 'Por onde os jogadores entram';
  @override
  String get optionsTooltip => 'Opções de rede e acesso';
  @override
  String get panelTitle => 'Rede e acesso';
  @override
  String get modeLocalHint => 'Só quem está no mesmo Wi-Fi (ou no hotspot do PC) entra.';
  @override
  String get modeBothHint => 'Os dois QR funcionam ao mesmo tempo. Use o seletor em cima do QR para escolher qual aparece.';
  @override
  String get modeOnlineHint => 'Só entra quem usar o link público. Quem está na rede local não consegue entrar.';
  @override
  String get localColumn => 'Rede local';
  @override
  String get onlineColumn => 'Internet';
  @override
  String get defaultRule => 'Regra padrão';
  @override
  String get localHint => 'Para quem está no mesmo Wi-Fi ou no hotspot do PC.';
  @override
  String get ownOnlineRule => 'Regra própria para internet';
  @override
  String get ownOnlineRuleOff => 'Desligado: quem vem pela internet segue a regra da rede local.';
  @override
  String get ownOnlineRuleOffDefault => 'Desligado: quem vem pela internet segue a regra padrão.';
  @override
  String get hotspotOff => 'Hotspot do PC desligado';
  @override
  String get hotspotOnUnknown => 'Hotspot do PC ligado';
  @override
  String hotspotOn(String ssid) => 'Hotspot do PC ligado: $ssid';
  @override
  String get hotspotHint => 'Quem não tem Wi-Fi pode entrar no hotspot do PC: o QR do Wi-Fi aparece no lobby.';
  @override
  String get wifiQrTitle => 'Sem Wi-Fi?';
  @override
  String wifiQrCaption(String ssid) => 'Escaneie para entrar no Wi-Fi $ssid';
  @override
  String get qrSwitchLabel => 'Qual QR mostrar';
  @override
  String get done => 'Pronto';
  @override
  String get saved => 'Regras de entrada salvas';
}
