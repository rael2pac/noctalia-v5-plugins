# AGENTS.md — Noctalia v5 Plugins

Repo de plugins para Noctalia v5 (Wayland shell). Os plugins deste repo são instalados neste
computador a partir da **fonte git** `rael2pac`
(`https://github.com/rael2pac/noctalia-v5-plugins.git`), não de um caminho local.

## Plugins existentes

| Plugin | Id | Versão atual |
| --- | --- | --- |
| arch-updater | `rael2pac/arch-updater` | 3.5.1 |
| hdmi-toggle | `rael2pac/hdmi-toggle` | 1.0.0 |
| disk-monitor | `rael2pac/disk-monitor` | 2.0.0 |
| audio-switcher | `rael2pac/audio-switcher` | 1.2.6 |
| gpu-temp | `rael2pac/gpu-temp` | 1.0.0 |

O `catalog.toml` na raiz lista todos e deve sempre ter a mesma `version` de cada `plugin.toml`.

## Como testar mudanças

O runtime do Noctalia usa o cache materializado em
`~/.local/state/noctalia/plugins/materialized/rael2pac/<plugin>/` (copiado do git), **não** os
arquivos desta pasta. Editar aqui não muda nada em runtime até publicar + atualizar a fonte.

Workflow para atualizar um plugin:

1. Edite os arquivos aqui (ex.: `arch-updater/service.luau`).
2. Bumpe a versão em `arch-updater/plugin.toml` **e** em `catalog.toml`.
3. `git commit` + `git push`.
4. `noctalia msg plugins update rael2pac` (atualiza a fonte e faz hot-reload dos plugins habilitados).
5. Verifique: `noctalia msg plugins list` mostra a nova versão e o plugin `enabled`.

O auto-update global (`[plugins].auto_update = true`) também atualiza as fontes git a cada 6h.

## Criar um novo plugin

1. Crie a pasta `meu-plugin/` com:
   - `plugin.toml` (manifesto: `id`, `name`, `version`, `plugin_api`, `icon`, `description`, `tags`, `dependencies`)
   - entry scripts (`.luau`) conforme o tipo: `service`, `widget`, `panel`, `launcher_provider`
   - `translations/*.json` (pt, pt-BR, en, en-US)
   - `icons/*.svg` se o painel/widget usar ícones custom
2. Adicione o bloco `[[plugin]]` correspondente em `catalog.toml`.
3. `git commit` + `git push`.
4. `noctalia msg plugins update rael2pac`.
5. `noctalia msg plugins enable rael2pac/meu-plugin`.

Referência da API de runtime: https://docs.noctalia.dev/noctalia/plugins/development/runtime-api/
Versionamento de plugin_api: https://docs.noctalia.dev/noctalia/plugins/development/plugin-api/

## Comandos úteis

```bash
noctalia msg plugins list                                   # todos os plugins, com fonte e versão
noctalia msg plugins source list                            # fontes configuradas
noctalia msg plugins update rael2pac                        # atualiza a fonte git + hot-reload
noctalia msg plugins enable/disable rael2pac/<plugin>       # liga/desliga um plugin
noctalia msg plugins source add <nome> git <url>            # adiciona fonte git
noctalia msg plugins source remove <nome>                   # remove fonte custom
noctalia msg plugin rael2pac/arch-updater:updater all refresh   # força o serviço a verificar updates
```

## Logs e estado

- Log do Noctalia: `~/.cache/noctalia/noctalia.log`
- Histórico de notificações: `~/.local/state/noctalia/notification_history.json`
- Config/estado: `~/.local/state/noctalia/settings.toml`

Testar notificação manual (a mesma chamada que o arch-updater usa para a central):
`notify-send -a "Arch Updater" -i system-software-update -u normal "resumo" "corpo"`

## Segurança

- **Nunca** commitar tokens ou senhas. A autenticação de push usa o PAT embutido na URL remota
  em `.git/config` (`https://rael2pac:<TOKEN>@github.com/rael2pac/noctalia-v5-plugins.git`). Se o
  push falhar com 401, o token expirou/foi revogado: gere outro em
  GitHub → Settings → Developer settings → Personal access tokens e atualize a URL com
  `git remote set-url origin`.
- O repo é público; não coloque segredos no código, catálogo ou docs.
