# setup-archlinux

Rebuild this machine after a format, on **Arch**, **Fedora** or **openSUSE**:
packages grouped by role, every dotfile, system files, and the work tooling.
Debian/Ubuntu are deliberately not supported.

Scope is **post-install**: it assumes the machine boots, your user exists and
the network works. Base-install notes are in
[docs/fresh-install.md](docs/fresh-install.md). Distro specifics and the package
translation layer are in [docs/multi-distro.md](docs/multi-distro.md).

> Decisions, intent and known issues are recorded in [AGENTS.md](AGENTS.md).

```bash
./install.sh --dry-run     # see what would change
./install.sh               # do it
```

Tested on: Arch + Ryzen 5 5600, RTX 3060 (nvidia-open), Hyprland 0.56 (Lua
config), quickshell `end4-pC`, KDE Plasma as secondary session, limine + SDDM.
Fedora/openSUSE are implemented in the scripts but still need a real run on
those systems (see "Status" below).

## What you get

| Area | Contents |
| --- | --- |
| Compositor | Hyprland (Lua config) + quickshell `end4-pC`, hyprlock, hypridle, hyprshot |
| Shell | zsh + oh-my-zsh + powerlevel10k, starship, fzf, zoxide, bat |
| Editors | neovim (LazyVim-style), VS Code (flags + User/), opencode |
| Dev | docker + compose, pyenv, gopls/pyright/ts-lsp, TeX Live, octave, postgres libs, arduino |
| AI | ollama (+ CUDA on Arch/NVIDIA), LM Studio (manual), gpt4all |
| Desktop apps | Zen browser (pinned tarball), Obsidian, qBittorrent (+ `qbittorrent-nox` daemon), aria2 (RPC daemon), mpv + MangoHud, Steam/Lutris/wine, QEMU |
| KDE | Plasma session, Dolphin/Kate/Konsole/Okular, SDDM `silent` theme |
| UX | matugen color generation, Kvantum, GTK/Qt theming, Bibata cursors, Noto + JetBrains Mono |
| Dotfiles | hypr, nvim, end4-pC, `.scripts`, plus ~80 app configs (KDE rc files, fuzzel, Thunar, qalculate, Zed/VS Code, GTK/Qt, …) |

## Quick start

```bash
git clone --recurse-submodules git@github.com:mohammedaouamri5/setup-archlinux.git
cd setup-archlinux
./install.sh --dry-run        # inspect
./install.sh                  # packages -> configs -> system -> shell -> post
```

After the first login, finish the manual steps printed at the end (SSH keys, gh
auth, AI provider keys, LM Studio, pyenv versions).

## Supported systems

| Family | Backend | Packages | AUR-only apps |
| --- | --- | --- | --- |
| Arch, Manjaro, EndeavourOS, CachyOS, … | `pacman` | `packages/0*`–`50*` | installed with `paru`/`yay` |
| Fedora, RHEL, Nobara, Bazzite, … | `dnf` | same lists, renamed by `packages/maps/fedora.map` | skipped or replaced by native equivalents |
| openSUSE / SUSE | `zypper` | same lists, renamed by `packages/maps/opensuse.map` | skipped or replaced by native equivalents |
| Debian, Ubuntu, Mint, … | — | refused on purpose | — |

The canonical lists stay in Arch spelling. `packages/maps/<family>.map` translates
names (including wildcards), `packages/extra/<family>.txt` adds native-only
packages (Hyprland/quickshell stack on Fedora/openSUSE), and unavailable packages
only warn. Use `--strict` when you want them to fail the run.

## Layout

```
install.sh                   orchestrator (stages + flags)
lib/log.sh                   logging, dry-run helpers
lib/pkg.sh                   distro detection, pacman/dnf/zypper, AUR, translations
lib/link.sh                  symlink + copy with timestamped backups
lib/configs.sh               manifest-driven deployment, legacy ii migration
config/manifest.txt          one line per dotfile: link, copy, render or submodule
config/                      captured dotfiles, mirroring $HOME
system/                      files rooted at / (etc, xkb, sddm, services)
submodules/                  hypr, nvim, end4-pC, .scripts (pinned commits)
packages/                    package groups, maps/, extra/
scripts/capture-configs.sh   refresh config/ from the live $HOME
scripts/check-packages.sh    drift check (Arch only)
scripts/fetch-wallpapers.sh  download the wallpaper collection
scripts/render-home.sh       rewrite /home/mohammedaouamri if your user differs
docs/                        fresh-install, multi-distro notes
logs/                        install logs (gitignored)
```

## Stages

Stages run in this order; `--stage` runs a subset.

| Stage | What it does |
| --- | --- |
| `packages` | refreshes+upgrades with the native manager, installs the groups, bootstraps `paru-bin` on Arch only, then translates the AUR list where possible |
| `configs` | updates submodules, deploys every line of `config/manifest.txt`, migrates a legacy `~/.config/quickshell/ii`, prepares wallpaper dirs |
| `system` | installs `/etc` files (skips `pacman.conf` off Arch), custom `us` xkb layout with the `bruh` variant, SilentSDDM, enables units that exist |
| `shell` | oh-my-zsh + plugins, powerlevel10k, pyenv, Zen browser, sets zsh as login shell |
| `post` | wallpapers, font cache, Hyprland reload, manual-steps checklist |

Flags:

```
--all                 every stage (default)
--stage LIST          packages,configs,system,shell,post
--dry-run             print actions, change nothing
--update              git submodule update --remote before linking
--skip-group NAME     skip one package group (e.g. 20-nvidia)
--no-kde              skip 50-kde.txt
--no-nvidia           skip 20-nvidia.txt
--skip-wallpapers     no download in the post stage
--strict              a package missing from this distro is an error
--distro NAME         pretend to be arch|fedora|opensuse (use with --dry-run)
--force               replace config dirs even with uncommitted tracked changes
```

Every replaced file/dir is first moved to `<name>.bak-<timestamp>`, so a bad run
is recoverable.

## Package groups

| File | Contents |
| --- | --- |
| `00-base.txt` | base tools, kernels, bootloader, core CLI (installed with `--needed`) |
| `10-desktop.txt` | audio, bluetooth, theming, printing, screenshots, SDDM |
| `20-nvidia.txt` | nvidia-open (+lts), CUDA containers, Vulkan stack |
| `30-dev.txt` | docker, neovim, language servers, TeX Live, ollama, opencode |
| `40-apps.txt` | aria2, qBittorrent, mpv, Obsidian, Steam/Lutris/wine, QEMU, tailscale |
| `50-kde.txt` | Plasma session + the KDE apps the Hyprland keybinds use |
| `90-aur.txt` | illogical-impulse metapackages first, then the rest; `paru-bin` + `yay-bin` |

Skipping is intentional: `--no-nvidia` for an AMD/Intel box, `--no-kde` for a
Hyprland-only install, `--skip-group 30-dev` to drop ~4 GB of TeX.

`./scripts/check-packages.sh` compares the lists against `pacman -Qqe` on Arch
and reports drift (expected: AUR helper + debug splits). The map/extra format
and per-group notes are in [packages/README.md](packages/README.md).

## How configs are deployed

`config/manifest.txt` is the single source of truth. Each line is one of:

| Kind | Meaning |
| --- | --- |
| `submodule` | symlink a pinned config repo (`hypr`, `nvim`, `end4-pC`, `.scripts`) |
| `link-dir` | symlink a whole directory (apps write inside the repo) |
| `link-file` | symlink a static dotfile |
| `copy-file` | real copy — for apps that rewrite by `rename()` and would break a symlink |
| `render-file` | copy, replacing `/home/mohammedaouamri` with `$HOME` |
| `render-tmpl` | copy, replacing `@HOME@` with `$HOME` (aria2) |

The four config repos stay submodules pinned to commits:

```
submodules/hypr      -> ~/.config/hypr               (branch lua)
submodules/nvim      -> ~/.config/nvim               (branch main)
submodules/end4-pC   -> ~/.config/quickshell/end4-pC (branch feat/launcher)
submodules/scripts   -> ~/.scripts                   (branch master)
```

Edit configs through the symlinked paths, commit inside the submodule, then bump
the pointer here. `./install.sh --update` pulls the latest submodule commits.

### Capturing more configs

`config/` is a snapshot of the live machine. To refresh it after changing app
settings:

```bash
./scripts/capture-configs.sh --dry-run   # see what would be copied
./scripts/capture-configs.sh             # copy manifest entries from $HOME
```

Add a path to `config/manifest.txt` first if it is not captured yet. The script
excludes caches, sessions, logs, secrets and `*.wants` symlinks, and keeps a
handful of deliberately portable files (`.zshrc`, fish, starship, yay) unless
`--force` is used. A secret scan runs at the end.

### Legacy Quickshell `ii`

`end4-pC` keeps its runtime settings in `~/.config/illogical-impulse` (not in
`~/.config/quickshell/ii`). If an old `ii` tree is present, the `configs` stage
merges its `actions/`, `presets/`, `ai/` and `schemes/` into that directory,
saves its `config.json` as `config.json.ii-migrated-<stamp>`, and moves the whole
old tree to `~/.config/quickshell/ii.bak-<stamp>`. Nothing is deleted.

## Wallpapers

The 1.3 GB collection is not in the repo. Host it and list URLs in
`config/wallpapers/urls.txt`; `scripts/fetch-wallpapers.sh` (part of `post`)
downloads into `~/wallpapers` with `aria2c --continue`. `~/Wallpapers` is kept as
a symlink because the Quickshell config uses the capitalised path. The file
ships with `example.com` placeholders.

## Not included (on purpose)

- Secrets: `~/.ssh`, `~/.gnupg`, `~/.config/gh`, `~/.config/opencode/service.json`,
  AI provider keys in the quickshell config, `~/.docker` auth, `~/.codeium`,
  browser profiles, `~/.git-credentials`, shell histories.
- Caches, sessions and app data: browser profiles, Electron caches, LM Studio
  models, docker volumes/images, `~/.local/state`, pyenv builds, game files.
- nix / nix-darwin, homebrew, the `odysseus` and `openclaw-gateway` user units.
- KDE session state beyond the config files in the manifest.

## Status

- Arch path is the primary one and is verified with `--dry-run` on the capture
  machine.
- Fedora (`dnf`) and openSUSE (`zypper`) package translation is implemented and
  dry-run tested with `--distro`; the first real run on those distros is still
  the acceptance test. Hyprland/quickshell may need a COPR/OBS repository first.
- `./scripts/check-packages.sh` is green on this Arch machine.

## Maintenance

```bash
./scripts/capture-configs.sh         # refresh config/ from this machine
./scripts/check-packages.sh          # did package lists drift?
./install.sh --dry-run               # what would a re-run do?
git submodule update --remote        # refresh config repos, then commit pointers
```
