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
  String get title => 'Opções';
  @override
  String get colorsTitle => 'Cores do ma.net';
  @override
  String get timeoutTitle => 'Tempo de reserva para jogadores desconectados';
  @override
  String timeoutValue(int minutes) => '$minutes min';
  @override
  String get languageTitle => 'Idioma';
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
  String get rightLayoutTitle => 'ARRANJO DOS BOTÕES';
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
