# setup-archlinux

Everything needed to rebuild this Arch machine after a format: packages grouped
by role, Hyprland + Quickshell dotfiles, and the quality-of-life / work tooling.

Scope is **post-install**: it assumes Arch is already booting with a user and
network. See [docs/fresh-install.md](docs/fresh-install.md) for the base install
(archinstall, limine, NVIDIA) that has to happen first.

```
./install.sh --dry-run     # see what would change
./install.sh               # do it
```

Tested on: Ryzen 5 5600, RTX 3060 (nvidia-open), Hyprland 0.56 (Lua config),
quickshell `end4-pC`, KDE Plasma as secondary session, limine + SDDM.

## What you get

| Area | Contents |
| --- | --- |
| Compositor | Hyprland (Lua config) + quickshell `end4-pC`, hyprlock, hypridle, hyprshot |
| Shell | zsh + oh-my-zsh + powerlevel10k, starship, fzf, zoxide, bat, eza-less `ls` |
| Editors | neovim (LazyVim-style), VS Code (`Visual Studio Code` + flags), opencode |
| Dev | docker + compose, pyenv, gopls/pyright/ts-lsp, TeX Live, octave, postgres libs, arduino |
| AI | ollama + ollama-cuda, LM Studio (manual), gpt4all |
| Desktop apps | Zen browser (pinned tarball), Obsidian, qBittorrent, aria2, mpv + MangoHud, Steam/Lutris/wine, VirtualBox-ish QEMU |
| KDE | full Plasma session, Dolphin/Kate/Konsole/Okular, SDDM `silent` theme |
| UX | matugen color generation, Kvantum, GTK/Qt theming, Bibata cursors, Noto + JetBrains Mono |

## Quick start

```bash
git clone --recurse-submodules git@github.com:mohammedaouamri5/setup-archlinux.git
cd setup-archlinux
./install.sh --dry-run        # inspect
./install.sh                  # packages -> configs -> system -> shell -> post
```

After a first login, finish the manual steps printed at the end (SSH keys, gh
auth, AI provider keys, LM Studio, pyenv versions).

## Layout

```
install.sh                 orchestrator (stages + flags)
lib/log.sh                 logging, dry-run helpers
lib/pkg.sh                 pacman / AUR helpers, multilib
lib/link.sh                symlink + copy with timestamped backups
packages/                  package groups, one per file (see below)
config/                    dotfiles, mirrors $HOME (config/.config/..., config/.zshrc)
system/                    files that go to /etc and /usr (pacman.conf, xkb, sddm.conf)
submodules/                hypr, nvim, end4-pC, .scripts (pinned commits)
scripts/check-packages.sh  drift check: repo lists vs `pacman -Qqe`
scripts/fetch-wallpapers.sh
scripts/render-home.sh     rewrite /home/mohammedaouamri if your user differs
docs/fresh-install.md      base install notes
logs/                      install logs (gitignored)
```

## Stages

Stages run in this order; `--stage` runs a subset.

| Stage | What it does |
| --- | --- |
| `packages` | enables multilib, full `pacman -Syu`, installs `packages/*.txt`, bootstraps `paru-bin`, then installs the AUR list |
| `configs` | updates submodules, symlinks dotfiles and the four config repos, renders `aria2.conf` |
| `system` | installs `/etc` files + custom `us` xkb layout with the `bruh` variant, SilentSDDM theme, enables services |
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
--force               replace config dirs even with uncommitted tracked changes
```

Every file that gets replaced is first moved to `<name>.bak-<timestamp>`, so a
bad run is recoverable.

## Package groups

| File | Contents |
| --- | --- |
| `00-base.txt` | base/base-devel, kernels, limine+grub, core CLI (installed with `--needed`, no-op on a live system) |
| `10-desktop.txt` | audio, bluetooth, theming, printing, screenshots, SDDM |
| `20-nvidia.txt` | nvidia-open (+lts), CUDA containers, Vulkan stack |
| `30-dev.txt` | docker, neovim, language servers, TeX Live, ollama, opencode |
| `40-apps.txt` | aria2, qBittorrent, mpv, Obsidian, Steam/Lutris/wine, QEMU, tailscale |
| `50-kde.txt` | Plasma session + the KDE apps the Hyprland keybinds use |
| `90-aur.txt` | illogical-impulse metapackages first, then the rest; `paru-bin` + `yay-bin` |

Skipping is intentional: `--no-nvidia` for an AMD/Intel box, `--no-kde` for a
Hyprland-only install, `--skip-group 30-dev` to drop ~4 GB of TeX.

`./scripts/check-packages.sh` compares the lists against `pacman -Qqe` on the
running machine and reports drift (expected: AUR helper + debug splits).

## How configs are deployed

Two strategies, because some apps rewrite their files by renaming them (which
would silently break a symlink):

- **Symlink** (the default): whole directories and static dotfiles point into
  the repo, so edits are versioned immediately — `hypr`, `nvim`, `end4-pC`,
  `.scripts`, kitty, foot, fish, btop, mpv, rofi, Qt/GTK themes, `.zshrc`,
  starship, git/npm configs.
- **Copy** (never symlinked): app state that gets rewritten — `illogical-impulse/config.json`,
  qBittorrent, VS Code `User/`, `kdeglobals`/`kwinrc`/`dolphinrc`/`katerc`,
  spectaclerc, `kde-material-you-colors`, `aria2.conf`.

The four config repos are git submodules pinned to commits:

```
submodules/hypr      -> ~/.config/hypr            (branch lua)
submodules/nvim      -> ~/.config/nvim            (branch main)
submodules/end4-pC   -> ~/.config/quickshell/end4-pC (branch feat/launcher)
submodules/scripts   -> ~/.scripts                (branch master)
```

Edit configs through the symlinked paths (`~/.config/hypr`, ...), commit inside
the submodule, then commit the pointer bump here. `./install.sh --update`
pulls the latest upstream submodule commits before linking.

## Wallpapers

The 1.3 GB collection is not in the repo. Host it and list the URLs in
`config/wallpapers/urls.txt`; `scripts/fetch-wallpapers.sh` (part of `post`)
downloads them into `~/Wallpapers` with `aria2c --continue`. The file ships
with placeholder `example.com` links.

## Not included (on purpose)

- Secrets: `~/.ssh`, `~/.gnupg`, `gh` auth, `~/.config/opencode/service.json`, AI provider keys
  in the quickshell config — re-add them manually.
- nix / nix-darwin, the `odysseus` and `openclaw-gateway` user services (their
  units are not vendored; running the installer on the live machine moves the
  existing `~/.config/systemd/user` out of the way and only re-enables aria2),
  homebrew, LM Studio models, docker volumes, browser profiles, pyenv builds.
- KDE's `~/.config/plasma*` state, session state, and anything under
  `~/.local/state`.

## Maintenance

```bash
./scripts/check-packages.sh          # did anything drift since the snapshot?
./install.sh --dry-run               # what would a re-run do?
git submodule update --remote        # refresh config repos, then commit pointers
```
