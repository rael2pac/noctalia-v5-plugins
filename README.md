# Noctalia v5 Plugins

Plugins para Noctalia v5 (Wayland Shell).

## Plugins

### arch-updater
Gerenciador de atualizacoes para Arch Linux. Verifica updates do sistema (pacman), AUR e Flatpak.

- Widget na barra com icone e contagem de updates
- Painel com lista de pacotes, versoes e cores por repo
- Launcher com comando `/au`
- Atualizacao automatica a cada 2 minutos
- Som de notificacao ao detectar novas atualizacoes (toggle nas configuracoes do plugin)
  - Som padrao: `sounds/notification.wav` (WAV mono 44.1kHz)
  - Fallback: `canberra-gtk-play` (libcanberra)
  - Para usar outro som, substitua o arquivo ou configure o comando no menu do plugin

### hdmi-toggle
Gerenciador de monitores. Lista todos os monitores conectados e permite ligar/desligar cada um.

- Widget na barra com icone de monitor
- Painel com lista de monitores e status
- Toggle individual por monitor via niri

## Instalacao

### Via repo git (recomendado)

1. Abra o Noctalia Settings → Plugins
2. Adicione uma nova fonte git:
   - Nome: `rael2pac`
   - URL: `https://github.com/rael2pac/noctalia-v5-plugins`
3. Ative os plugins desejados

### Via CLI

```bash
noctalia msg plugins source add rael2pac git https://github.com/rael2pac/noctalia-v5-plugins
noctalia msg plugins enable rael2pac/arch-updater
noctalia msg plugins enable rael2pac/hdmi-toggle
```

### Manualmente

Copie os diretorios dos plugins para `~/.local/share/noctalia/plugins/`:

```bash
cp -r arch-updater ~/.local/share/noctalia/plugins/
cp -r hdmi-toggle ~/.local/share/noctalia/plugins/
```

## Dependencias

### arch-updater
- `checkupdates` (pacman-contrib)
- `yay` (ou outro AUR helper)
- `libcanberra` (som de notificacao padrao - opcional)

### hdmi-toggle
- `niri` (compositor Wayland)

## Licenca

MIT
