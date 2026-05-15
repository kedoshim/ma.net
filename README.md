# Ma.net

O Ma.net é um aplicativo que transforma celulares em manetes para jogos no computador.

A ideia é simples:

Você abre o executável no PC, aparece um QR Code na tela, os jogadores apontam o celular e pronto. Todo mundo já entra com um controle funcionando.

O objetivo do projeto é facilitar multiplayer local e deixar esse processo divertido.

Porque jogar com amigos deveria ser fácil.

---

# Como funciona

O servidor roda no computador e cria controles virtuais de Xbox.

Os celulares se conectam pela rede local usando:

-   QR Code
    
-   navegador
    
-   ou aplicativo Android
    
    

---

# Funcionalidades

-   Multiplayer local via celular
    
-   Controles virtuais XInput e DInput
    
-   Conexão instantânea via QR Code
    
-   Aplicativo Android
    
-   Descoberta automática na rede local
    
-   Interface responsiva
    
-   Inputs em tempo real
    
-   Visualização dos analógicos e botões no servidor
    
-   Feedback visual animado
    
-   Sistema de slots
    
-   Personalização de rosto/cor
    
-   Configurações persistentes
    
-   Reconexão automática
    

---

# Tecnologias

## Front-end

-   [Flutter](https://flutter.dev?utm_source=chatgpt.com)
    

## Back-end

-   [Python](https://www.python.org?utm_source=chatgpt.com)
    
-   [FastAPI](https://fastapi.tiangolo.com?utm_source=chatgpt.com)
    
-   [WebSockets](https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API?utm_source=chatgpt.com)
    

## Controles virtuais

-   [vgamepad](https://github.com/yannbouteiller/vgamepad?utm_source=chatgpt.com)
    
-   [ViGEmBus](https://github.com/nefarius/ViGEmBus?utm_source=chatgpt.com)
    

---

# Objetivo do projeto

O Ma.net nasceu porque multiplayer local ainda é uma das formas mais divertidas de jogar.

Só que:

-   controles são caros
    
-   conectar vários controles é chato
    
-   sempre falta um controle
    
-   e sempre existe aquele amigo que chega depois
    

Então a proposta é:  
transformar o setup da jogatina numa coisa rápida, acessível e divertida.

O celular já está no bolso de todo mundo.  
Então ele vira o controle.

---

# Roadmap

Coisas que ainda quero adicionar:

-   Vibração/Haptics
    
-   Efeitos sonoros
    
-   Presets de controle
    
-   Multiplayer pela internet (não só Wi-Fi local)
    

A ideia dessa última é permitir coisas tipo:

-   jogar por chamada no Discord
    
-   jogar remoto com amigos
    
-   transformar literalmente qualquer lugar numa LAN party improvisada
    

---

# Instalação

## Dependência importante

O Windows precisa do driver ViGEmBus instalado para criar controles virtuais.

Baixe aqui:

[ViGEmBus Releases](https://github.com/nefarius/ViGEmBus/releases?utm_source=chatgpt.com)

---

# Contribuindo

Achou bug?  
Abre uma issue.

Quer melhorar alguma coisa?  
Manda um PR.

Quer fazer um rostinho amaldiçoado?  
Apoiado.

---

# Licença

MIT.

---

# Autor

Feito por Abraão, 22 anos.

Amante da experiência de juntar amigos no mesmo lugar pra jogar.

Esse projeto existe porque eu queria facilitar minhas próprias jogatinas.

Agora eu quero levar isso pra mais pessoas também.


# Creditos

Bubble Pops by Abacagi -- https://freesound.org/s/497198/ -- License: Attribution 4.0