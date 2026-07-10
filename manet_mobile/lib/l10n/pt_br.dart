import 'strings.dart';

class PtBrStrings implements AppStrings {
  @override
  final common = PtBrCommonStrings();

  @override
  final options = PtBrOptionsStrings();

  @override
  final quickActions = PtBrQuickActionsStrings();

  @override
  final status = PtBrStatusStrings();

  @override
  final scanner = PtBrScannerStrings();

  @override
  final editControls = PtBrEditControlsStrings();

  @override
  final editName = PtBrEditNameStrings();

  @override
  final connectionTips = PtBrConnectionTipsStrings();

  @override
  final presets = PtBrPresetsStrings();

  @override
  final joystick = PtBrJoystickStrings();

  @override
  final disconnect = PtBrDisconnectStrings();

  @override
  final androidOnboarding = PtBrAndroidOnboardingStrings();
}

class PtBrCommonStrings implements CommonStrings {
  @override
  String get cancel => 'Cancelar';
  @override
  String get save => 'Salvar';
  @override
  String get ok => 'OK';
  @override
  String get close => 'Fechar';
}

class PtBrOptionsStrings implements OptionsStrings {
  @override
  String get title => 'Opcoes';
  @override
  String get downloadApp => 'Baixar App';
  @override
  String get vibration => 'Vibracao';
  @override
  String get vibrationAndroidOnly => 'Vibracao apenas no app Android!';
  @override
  String get mouseMode => 'Mouse';
  @override
  String get exitDisconnect => 'Sair';
  @override
  String get themeColorsTitle => 'Cores do ma.net';
  @override
  String get languageTitle => 'Idioma';
  @override
  String get sensitivity => 'Sensibilidade';
  @override
  String get sensitivityTitle => 'Ajustes de Sensibilidade';
  @override
  String get leftStickSensitivity => 'Analógico Esquerdo';
  @override
  String get rightStickSensitivity => 'Analógico Direito';
  @override
  String get swipeAcceleration => 'Aceleração do Swipe';
  @override
  String get secondaryControls => 'Controles Secundários';
  @override
  String get collapse => 'Recolher';
  @override
  String get antiDeadzone => 'Anti-Deadzone';
  @override
  String get responseCurve => 'Curva de Resposta';
  @override
  String get responseCurveLinear => 'Linear';
  @override
  String get responseCurveMild => 'Suave';
  @override
  String get responseCurveMedium => 'Média';
  @override
  String get responseCurveAggressive => 'Agressiva';
  @override
  String get secondaryButtonsTitle => 'Botões Secundários';
  @override
  String get movementTitle => 'Movimento';
  @override
  String get rightStickTitle => 'Analógico Direito';
}

class PtBrQuickActionsStrings implements QuickActionsStrings {
  @override
  String get title => 'Quick Actions';
  @override
  String get volumeMediaSection => 'Volume & Mídia';
  @override
  String get windowsSystemSection => 'Windows / System';

  @override
  String getActionTitle(String actionId) {
    switch (actionId) {
      case 'mute_toggle':
        return 'Mudo/Som';
      case 'volume_down':
        return 'Vol. Menos';
      case 'volume_up':
        return 'Vol. Mais';
      case 'previous_track':
        return 'Anterior';
      case 'play_pause':
        return 'Play/Pause';
      case 'next_track':
        return 'Próxima';
      case 'windows_key':
        return 'Tecla Win';
      case 'windows_tab':
        return 'Win + Tab';
      case 'show_desktop':
        return 'Desktop';
      case 'task_manager':
        return 'Gerenc. de Tar.';
      case 'escape':
        return 'Esc';
      case 'maximize_window':
        return 'Maximizar';
      case 'minimize_window':
        return 'Minimizar';
      default:
        return actionId;
    }
  }
}

class PtBrStatusStrings implements StatusStrings {
  @override
  String get searching => 'procurando...';
  @override
  String get disconnected => 'desconectado';
  @override
  String get multipleHostsFound => 'selecionar host';
  @override
  String get multipleHostsTitle => 'Vários Hosts Encontrados';
  @override
  String get waitingForSlot => 'Banco';
  @override
  String get enteringGame => 'Entrar na Partida';
  @override
  String get connected => 'Conectado';
  @override
  String get connectedWaiting => 'Conectado (Aguardando Vaga)';

  @override
  String connectViaLink(String hostAddress) => 'Conectado via link: $hostAddress';
}

class PtBrScannerStrings implements ScannerStrings {
  @override
  String get title => 'Escanear Host';
  @override
  String get qrScannerInstead => 'Escanear QR em vez disso';
}

class PtBrEditControlsStrings implements EditControlsStrings {
  @override
  String get title => 'editar controles';
  @override
  String get availableButtons => 'Botões disponíveis';
  @override
  String get rightStickControls => 'Controles do Analógico Direito';
  @override
  String get dragToMove => 'Arraste para mover';
  @override
  String get noButtonsVisible => 'Sem botões visíveis';
  @override
  String get enableButtonsInSettings => 'Habilite botões nas configurações';
  @override
  String get columnsMode => 'Duas colunas';
  @override
  String get rowsMode => 'Duas linhas';
  @override
  String get editMode => 'Editar';
  @override
  String get useMode => 'Uso';
}

class PtBrEditNameStrings implements EditNameStrings {
  @override
  String get title => 'Editar Apelido';
  @override
  String get hint => 'Digite o apelido...';
  @override
  String get noName => 'Sem Nome';
}

class PtBrConnectionTipsStrings implements ConnectionTipsStrings {
  @override
  String get title => 'O celular não conectou :P';
  @override
  String get subtitle => 'Algumas dicas para tentar resolver:';
  @override
  String get wifiSame => '1. Verifique se ambos estão na mesma rede Wi-Fi.';
  @override
  String get firewall => '2. O Firewall do Windows pode estar bloqueando a conexão.';
  @override
  String get hotspot => '3. Tente usar o roteador (Hotspot) do próprio computador se o Wi-Fi falhar.';
  @override
  String get gotIt => 'Entendi';
}

class PtBrPresetsStrings implements PresetsStrings {
  @override
  String get title => 'rostinho';
  @override
  String get colors => 'cores';
  @override
  String get face => 'rosto';
  @override
  String get rotation => 'rotacao';
  @override
  String get presetsTitle => 'presets';
  @override
  String get editFaceTitle => 'Editar Rostinho';

  @override
  String getPresetLabel(String presetId) {
    switch (presetId) {
      case 'happy':
        return 'de boa';
      case 'angry':
        return 'aarrhh';
      case 'yeah':
        return 'uhul';
      case 'confused':
        return 'confuso';
      case 'sad':
        return 'tô mal';
      case 'silly':
        return 'paia';
      case 'sexy':
        return 'oi sumido';
      case 'cursed':
        return 'beijoca';
      default:
        return presetId;
    }
  }
}

class PtBrJoystickStrings implements JoystickStrings {
  @override
  String get changeToFixed => 'Mudar para Joystick Fixo';
  @override
  String get changeToFloating => 'Mudar para Joystick Flutuante';
  @override
  String get changeToDpad => 'Mudar para D-Pad';
  @override
  String get touchpad => 'touchpad';
  @override
  String get scroll => 'scroll';
  @override
  String get mouseModeTitle => 'mouse mode';
}

class PtBrDisconnectStrings implements DisconnectStrings {
  @override
  String get title => 'Você foi desconectado';
  @override
  String get subtitle => 'Não foi possível continuar conectado ao MaNet.';
  @override
  String get hostOffline => 'O computador que estava hospedando a partida foi desligado ou encerrou o MaNet.';
  @override
  String wifiChanged(String expected) => 'Você mudou de rede Wi-Fi.';
  @override
  String get noWifi => 'Você saiu da rede Wi-Fi utilizada durante a partida.';
  @override
  String get noInternet => 'Seu dispositivo parece estar sem conexão no momento.';
  @override
  String get unknown => 'A conexão com o MaNet foi perdida. Tente fechar e abrir novamente o aplicativo ou reconectar ao Wi-Fi utilizado durante a partida.';
  @override
  String currentNetwork(String current) => 'Rede atual: "$current"';
  @override
  String expectedNetwork(String expected) => 'Rede anterior: "$expected"';
  @override
  String get tryAgain => 'Tentar novamente';
  @override
  String get reconnect => 'Reconectar';
  @override
  String get diagnosing => 'Analisando conexão...';
}

class PtBrAndroidOnboardingStrings implements AndroidOnboardingStrings {
  @override
  String get title => 'Aplicativo Android';
  @override
  String get subtitle => 'Uma experiência mais estável e confortável para jogar.';
  @override
  String get download => 'Baixar aplicativo';
  @override
  String get continueInBrowser => 'Continuar no navegador';
}
