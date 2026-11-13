# AGENTS.md — what this repo is and how to work on it

Context file for whoever (human or agent) touches this repo. User-facing usage
lives in [README.md](README.md); this file records the *intent*, the decisions and
the current state so they are not accidentally undone.

`state as of 2026-11-13`

## Purpose

One repo to rebuild this machine after a format: packages grouped by role, every
dotfile, system files, and the tooling needed for work.

It runs on **Arch**, **Fedora** and **openSUSE**. Debian/Ubuntu are deliberately
refused: the maintainer does not use them, and an `apt` backend would be dead
weight that nobody tests.

**Scope is post-install.** It starts from "the distro is booting, my user exists,
the network works" and finishes at "Hyprland session, all apps, same look and
keybinds". The disk/partition/bootloader part is only documented, in
[docs/fresh-install.md](docs/fresh-install.md). Distro-specific notes and the
package translation layer are in [docs/multi-distro.md](docs/multi-distro.md).

## Target machine

| | |
| --- | --- |
| Host | `hades` — Ryzen 5 5600, RTX 3060 (nvidia-open), NVMe |
| Kernel | `linux` + `linux-lts` (7.2.x at capture time) |
| Session | Hyprland 0.56.2 with **Lua** config (not hyprlang), quickshell `end4-pC` |
| Secondary session | KDE Plasma 6 (full install, used as fallback) |
| Login | SDDM + SilentSDDM `silent` theme |
| Boot | limine, systemd-boot style `/etc/default/limine` cmdline |
| Shell | zsh + oh-my-zsh + powerlevel10k + starship |
| Locale / TZ | `en_US.UTF-8` / `Africa/Casablanca` |
| Home | `/home/mohammedaouamri` (all configs were captured from here) |

Supported package backends:

| Family | Detection (`ID` / `ID_LIKE`) | Backend | Extras |
| --- | --- | --- | --- |
| Arch and derivatives | `arch`, `manjaro`, `endeavouros`, `garuda`, `cachyos`, `artix`, … | `pacman` | multilib + AUR (`paru`/`yay`) |
| Fedora and derivatives | `fedora`, `rhel`, `centos`, `rocky`, `almalinux`, `nobara`, `bazzite`, … | `dnf` | `packages/extra/fedora.txt` |
| openSUSE / SUSE | `opensuse*`, `suse`, `sles`, `tumbleweed`, `leap`, `slowroll` | `zypper` | `packages/extra/opensuse.txt` |
| Debian / Ubuntu / Mint / Pop | any of those, or `ID_LIKE` containing them | — | `die` on purpose |

## Ground rules

- **Never commit secrets.** Excluded and must stay excluded: `~/.ssh`,
  `~/.gnupg`, `~/.config/gh` (gh auth), `~/.config/opencode/service.json`
  (contains a real password), AI provider keys inside the quickshell config,
  browser profiles, `~/.git-credentials`.
- **No nix, no homebrew, no `odysseus` / `openclaw-gateway` units.** They exist on
  the live box but are deliberately not restored. Docker *is* wanted.
- **Non-destructive by default.** Every replaced file/dir is moved to
  `<path>.bak-<YYYYmmdd-HHMMSS>` first. A git worktree with *tracked* changes is
  never replaced unless `--force`.
- **Never run the installer as root.** It calls `sudo` per action.
- **Do not make a stage distro-specific when a data file will do.** Package
  names live in `packages/maps/`, native extras in `packages/extra/`, units in
  `system/services/`. `install.sh` should stay mostly `case $PKG_BACKEND`.
- Wallpapers (1.3 GB) are not in the repo; only the URL list is.
- Keep the "copy vs symlink" rule below. Turning a copied file into a symlink
  silently breaks apps that rewrite files by rename.
- **`config/manifest.txt` is the single source of truth** for dotfiles. Adding a
  path to `install.sh` instead of the manifest is a bug: the capture script would
  not know about it.

## Layout and responsibilities

| Path | Responsibility |
| --- | --- |
| `install.sh` | orchestration, flags, stage order, system/shell/post logic |
| `lib/log.sh` | logging, `run`/`run_sh`/`sudo_run` (all honour `--dry-run`) |
| `lib/pkg.sh` | distro detection, pacman/dnf/zypper backends, AUR, translations |
| `lib/link.sh` | `link_file`, `link_dir`, `copy_file`, `render_copy`, `sudo_install`, `clone_if_missing` |
| `lib/configs.sh` | manifest deployment, legacy `ii` migration, wallpaper dirs |
| `config/manifest.txt` | one line per dotfile: submodule, link, copy, render or template |
| `packages/*.txt` | canonical groups in Arch spelling; comments allowed |
| `packages/maps/<family>.map` | Arch-name → native-name translation (glob-aware) |
| `packages/extra/<family>.txt` | native-only packages, installed optionally |
| `config/` | dotfiles mirroring `$HOME` (`config/.config/...`, `config/.zshrc`) |
| `system/` | files rooted at `/` (`system/etc/...`, `system/usr/...`) |
| `system/services/` | `system.txt`, `user.txt`, plus `system.<family>.txt` |
| `submodules/` | the four upstream config repos, pinned |
| `scripts/capture-configs.sh` | refresh `config/` from the live `$HOME` |
| `scripts/check-packages.sh` | drift check (Arch only, guarded elsewhere) |
| `scripts/fetch-wallpapers.sh` | download the wallpaper collection |
| `scripts/render-home.sh` | rewrite `/home/mohammedaouamri` if the user differs |

## Decisions and why

**Cross-distro through data, not forks.** `packages/*.txt` stay in the canonical
Arch spelling because that is what the live machine uses and what
`check-packages.sh` compares against `pacman -Qqe`. `lib/pkg.sh` detects the
family once, then `pkg_translate` maps each name through
`packages/maps/<family>.map` (exact match first, then shell globs like
`texlive-*`). A missing package only warns; `--strict` makes it fatal. This keeps
one list to maintain instead of three divergent ones.

**AUR is Arch-only.** `aur_group` installs `90-aur.txt` with `paru`/`yay` on
Arch. Elsewhere the same file is run through the translation layer as *optional*
native packages, so e.g. `visual-studio-code-bin` becomes `code` and
`illogical-impulse-*` disappears. Native Hyprland/quickshell packages live in
`packages/extra/<family>.txt` and still require the distro's third-party repo
(COPR on Fedora, OBS on openSUSE).

**Submodules instead of vendoring configs.** `hypr`, `nvim`, `end4-pC` and
`.scripts` are independently versioned by the user (and edited straight from the
symlinked live paths), so they stay separate repos pinned to commits:
`hypr@lua`, `nvim@main`, `end4-pC@feat/launcher`, `.scripts@master`. Updating =
`./install.sh --update` (`git submodule update --remote`) + commit the pointers.

**Symlink vs copy.** Symlink whole directories and static dotfiles (edits are
versioned instantly): hypr, nvim, end4-pC, .scripts, kitty, foot, fish, btop,
mpv, rofi, fuzzel, Thunar, Qt/GTK themes, matugen, `.zshrc`, `.p10k.zsh`,
starship, git/npm. Copy (never symlink) anything an app rewrites:
`illogical-impulse/config.json` (rendered), qBittorrent, VS Code `User/`,
`kdeglobals`/`kwinrc`/`dolphinrc`/`katerc`, `spectaclerc`, `aria2.conf`, the
KDE rc files. Reason: many apps write a temp file and `rename()` over the
target, which replaces a symlink with a real file and loses the link.

**Manifest-driven deployment.** `lib/configs.sh` reads `config/manifest.txt`, one
entry per line. `scripts/capture-configs.sh` reads the same file in reverse, so
capture and deploy cannot drift. Missing sources only warn, which allows a
partial capture or a fresh clone.

**User units are linked file-by-file, never as a directory.** `~/.config/systemd/user`
must stay a real directory because `systemctl --user enable` writes
`default.target.wants/` inside it; symlinking the whole directory would make
systemd write that state into the repo. The manifest therefore links
`aria2.service` and `qbittorrent-nox.service` individually, and
`system/services/user.txt` enables those plus `ydotool.service` (which ships with
the `ydotool` package, a dependency of `illogical-impulse-toolkit`).

**Capture protects curated files.** `capture-configs.sh` refuses to overwrite
`.zshrc`, `.config/yay/config.json`, `.config/fish/config.fish` and
`.config/starship.toml` unless `--force` is passed. Those were hand-edited to be
portable (`$HOME` instead of `/home/mohammedaouamri`, no homebrew/pyenv calls),
and a blind capture from a live machine would undo that. It also excludes
`.git`, caches, `*.bak*`, logs, `*.wants`, `globalStorage`, model/state dirs,
and runs a cheap secret scan at the end.

**Legacy `~/.config/quickshell/ii` is migrated, not deleted.** `end4-pC` reads
runtime settings from `~/.config/illogical-impulse`, not from
`~/.config/quickshell/ii`. If an old `ii` tree exists, `migrate_legacy_ii` merges
`actions/`, `presets/`, `ai/` and `schemes/` into the new location, copies
`config.json` to `config.json.ii-migrated-<stamp>` (it must not clobber the
deployed one), and moves the old tree to `ii.bak-<stamp>`. The live machine has
no `ii` directory today, so this path is dormant but tested by review.

**Package groups are skippable.** `00-base`, `10-desktop`, `20-nvidia`,
`30-dev`, `40-apps`, `50-kde`, `90-aur`; flags `--no-nvidia`, `--no-kde`,
`--skip-group`. KDE is ON by default because `dolphin` arrives through
`illogical-impulse-kde` and the Hyprland keybinds use it.

**`paru-bin`, not `paru`.** Bootstrapping `paru` from source needs a full Rust
toolchain; `paru-bin` is a binary package. `90-aur.txt` therefore lists
`paru-bin` and `check-packages.sh` whitelists `paru`/debug splits as expected
drift.

**Zen browser from a pinned tarball.** `~/.config/hypr/custom/variables.lua` sets
`browser = "~/.local/opt/zen/zen"` and `custom/keybinds.lua` binds `SUPER+F` to
it. The AUR `zen-browser-bin` installs to `/opt`, which would not match. So
`install_zen` downloads the upstream `zen.linux-x86_64.tar.xz` into
`~/.local/opt/zen` (override with `ZEN_URL`) and drops a local `.desktop` file.
This works on every supported distro.

**SDDM theme is cloned at install time.** `SilentSDDM` v1.5.0 (~255 MB) is not
vendored; the `system` stage clones the tag, installs its Qt6 deps (canonical
names translated by the map) and copies it to `/usr/share/sddm/themes/silent`.

**Two wallpaper paths.** The collection actually lives in `~/wallpapers`
(1.3 GB); `~/Wallpapers` is a symlink to it because the Quickshell config stores
the capitalised path while hyprlock/matugen write the lowercase one.
`ensure_wallpaper_dir` preserves that.

**Home path templating.** `config/` was captured from `/home/mohammedaouamri`.
Files that are copied get `/home/mohammedaouamri` replaced by `$HOME`
(`render-file`, `REPO_HOME` env). Templates get `@HOME@` replaced
(`render-tmpl`, used by `aria2.conf`). Symlinked files cannot be rewritten at
install time, so absolute paths inside them were replaced by `$HOME` (starship,
fish) or are fixed by `scripts/render-home.sh` if the username ever differs.

## Stage order

`packages → configs → system → shell → post` (configs before system on purpose:
the `system` stage enables the user unit that the `configs` stage puts in place).

- **packages**: distro detect, multilib (Arch), refresh/full upgrade, base devel,
  canonical groups, native extras, paru bootstrap + AUR (Arch) or translated
  AUR list (other families).
- **configs**: `git submodule update`, deploy every manifest line, migrate a
  legacy `ii`, prepare wallpaper dirs.
- **system**: install `system/etc/*` (skips `pacman.conf` off Arch), custom xkb
  `us` with the `bruh` variant at `/usr/share/X11/xkb/symbols/us`, SilentSDDM,
  enable units that actually exist (system + user if a session bus is reachable).
- **shell**: oh-my-zsh + plugins, powerlevel10k, pyenv clone, Zen, `chsh`.
- **post**: wallpapers, `fc-cache`, `hyprctl reload`, manual-steps checklist.

## Current state

- The Arch path is complete and was verified with `--dry-run` on the capture
  machine plus a fresh clone (`--recurse-submodules`) from GitHub. **It has never
  been run for real end-to-end**, so the first real run is still the acceptance
  test.
- Fedora and openSUSE are implemented and dry-run tested with
  `--distro fedora|opensuse --stage packages`; the first real run on those
  systems is the acceptance test. Hyprland/quickshell need COPR/OBS repos first.
- `./scripts/check-packages.sh` is green against the live Arch system and exits
  early with a notice on other families.
- `config/` now contains the full captured set (~80 app configs + KDE rc files),
  not just the handful of top-level dotfiles.
- `master` is the default branch and mirrors `auto-install`; push to both (or
  delete `auto-install`, it is a leftover from the planning session).

## Known issues / TODO

1. **Keymap toggle does not persist.** `~/.scripts/chmap` writes
   `~/.config/hypr/language.lua`, but `hyprland.lua` now requires
   `hyprland.language`, so the choice is lost on restart. Fix by writing
   `hyprland/language.lua` (either `require("lang-<map>")` if the Lua loader
   resolves root-relative requires, or by copying `lang-<map>.lua` — note
   `lang-*.lua` lack the touchpad block that `hyprland/language.lua` has).
2. **Wallpaper URLs are placeholders** (`config/wallpapers/urls.txt`). Host the
   collection and fill them in; `fetch-wallpapers.sh` skips `example.com`.
3. **`pyenv` versions are not installed** (3.9.25 / 3.12.12 / 3.14.0 on the live
   box). `stage_shell` only clones pyenv; versions are a manual step (slow builds).
4. **Disk is 96% full** (424G/468G). A full `pacman -Syu` + AUR rebuild can need
   several GB; free space before the first real run.
5. **shellcheck was never run** (not installed at build time). Run
   `shellcheck install.sh lib/*.sh scripts/*.sh` before trusting a real run.
6. **Live `~/.config/hypr` has uncommitted tracked changes**
   (`custom/rules.lua`, `hyprland/colors.lua`, `hyprlock/colors.conf`) —
   `link_dir` will refuse to replace it until those are committed. Use
   `--force` only after understanding that it backs the worktree up first.
7. **Fedora/openSUSE maps are best effort.** Names were checked against package
   indexes, not installed. Expect warnings on a first real run; add corrections
   to `packages/maps/<family>.map` or native packages to
   `packages/extra/<family>.txt`.
8. **`qbittorrent-nox` is listed but not installed on the live box** (only the
   GUI `qbittorrent` is), so `check-packages.sh` reports drift until
   `sudo pacman -S qbittorrent-nox` is run. The unit exists either way.
9. Not restored on purpose: browser profiles, docker volumes/images, LM Studio
   models, KDE `plasma*` state, `~/.local/state`, pyenv builds, gh auth, SSH/GPG
   keys, `odysseus` + `openclaw-gateway` units.

## How to change things

```bash
# add a package to a canonical group, then verify the lists still match reality
vim packages/40-apps.txt
./scripts/check-packages.sh

# teach another distro a name (left = Arch spelling)
vim packages/maps/fedora.map
./install.sh --dry-run --force --distro fedora --stage packages

# add a dotfile: put it in the manifest first, then capture it
vim config/manifest.txt
./scripts/capture-configs.sh --dry-run
./scripts/capture-configs.sh

# change a dotfile: edit the live symlinked path, commit in the submodule,
# then bump the pointer here
cd ~/.config/hypr && git add -A && git commit -m "..." && git push
cd ~/DEV/setup-archlinux && git add submodules/hypr && git commit -m "hypr: bump"

# pull the latest upstream configs and pin them
./install.sh --update --stage configs

# absolute paths in symlinked configs (only if the username differs)
./scripts/render-home.sh /home/mohammedaouamri "$HOME"
```

## Verification recipe

```bash
bash -n install.sh lib/*.sh scripts/*.sh
./scripts/check-packages.sh          # must be green on the Arch capture machine
./install.sh --dry-run --force       # no sudo, no writes, full stage walk
./install.sh --dry-run --force --distro fedora   --stage packages
./install.sh --dry-run --force --distro opensuse --stage packages
git clone --recurse-submodules <remote> /tmp/check && cd /tmp/check && ./install.sh --dry-run
```

Nothing should touch `~/.config` or `/etc` unless `--dry-run` is absent.
