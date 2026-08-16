# Noctalia v5 Plugins

Plugins para Noctalia v5 (Wayland Shell).

## Plugins

### arch-updater
Gerenciador de atualizações para Arch Linux. Verifica updates do sistema (pacman), AUR e Flatpak.

- Widget na barra com icone e contagem de updates
- Painel com lista de pacotes, versoes e cores por repo
- Launcher com comando `/au`
- Verificacao automatica com intervalo configuravel (padrao 120 minutos)
- Notificacoes de novas atualizacoes vao para a **Central de Notificacoes** (via `notify-send`)
  - Toggle nas configuracoes: `Enviar para a Central de Notificações`
  - Som de notificacao ao detectar novas atualizacoes (toggle nas configuracoes do plugin)
    - Padrao: `canberra-gtk-play` (som do sistema)
    - Configuravel: use `paplay /caminho/som.wav` ou qualquer comando


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
- `libnotify` (comando `notify-send`, para a central de notificacoes)
- `libcanberra` (som de notificacao - opcional, para o som padrao)


### hdmi-toggle
- `niri` (compositor Wayland)

## Licenca

MIT
