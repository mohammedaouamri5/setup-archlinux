# AGENTS.md — what this repo is and how to work on it

Context file for whoever (human or agent) touches this repo. User-facing usage
lives in [README.md](README.md); this file records the *intent*, the decisions and
the current state so they are not accidentally undone.

`state as of 2026-11-12`

## Purpose

One repo to rebuild this specific Arch machine after a format: packages grouped
by role, dotfiles, system files, and the tooling needed for work.

**Scope is post-install.** It starts from "Arch is booting, my user exists, the
network works" and finishes at "Hyprland session, all apps, same look and
keybinds". The disk/partition/bootloader part is only documented, in
[docs/fresh-install.md](docs/fresh-install.md).

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
- Wallpapers (1.3 GB) are not in the repo; only the URL list is.
- Keep the "copy vs symlink" rule below. Turning a copied file into a symlink
  silently breaks apps that rewrite files by rename.

## Layout and responsibilities

| Path | Responsibility |
| --- | --- |
| `install.sh` | orchestration, flags, stage order |
| `lib/log.sh` | logging, `run`/`run_sh`/`sudo_run` (all honour `--dry-run`) |
| `lib/pkg.sh` | `pacman_group`, `aur_group`, multilib, paru bootstrap, per-package retry |
| `lib/link.sh` | `link_file`, `link_dir`, `copy_file`, `render_copy`, `sudo_install`, `clone_if_missing` |
| `packages/*.txt` | one group per file; comments allowed |
| `config/` | dotfiles mirroring `$HOME` (`config/.config/...`, `config/.zshrc`) |
| `system/` | files rooted at `/` (`system/etc/...`, `system/usr/...`) |
| `submodules/` | the four upstream config repos, pinned |
| `scripts/` | `check-packages`, `fetch-wallpapers`, `render-home` |

## Decisions and why

**Submodules instead of vendoring configs.** `hypr`, `nvim`, `end4-pC` and
`.scripts` are independently versioned by the user (and edited straight from the
symlinked live paths), so they stay separate repos pinned to commits:
`hypr@lua`, `nvim@main`, `end4-pC@feat/launcher`, `.scripts@master`. Updating =
`./install.sh --update` (`git submodule update --remote`) + commit the pointers.

**Symlink vs copy.** Symlink whole directories and static dotfiles (edits are
versioned instantly): hypr, nvim, end4-pC, .scripts, kitty, foot, fish, btop,
mpv, rofi, Qt/GTK themes, matugen, `.zshrc`, `.p10k.zsh`, starship, git/npm.
Copy (never symlink) anything an app rewrites: `illogical-impulse/config.json`,
qBittorrent, VS Code `User/`, `kdeglobals`/`kwinrc`/`dolphinrc`/`katerc`,
`spectaclerc`, `aria2.conf`. Reason: many apps write a temp file and `rename()`
over the target, which replaces a symlink with a real file and loses the link.

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

**SDDM theme is cloned at install time.** `SilentSDDM` v1.5.0 (~255 MB) is not
vendored; the `system` stage clones the tag, installs its Qt6 deps and copies it
to `/usr/share/sddm/themes/silent`.

**Two wallpaper paths.** The collection actually lives in `~/wallpapers`
(1.3 GB); `~/Wallpapers` is a symlink to it because the Quickshell config stores
the capitalised path while hyprlock/matugen write the lowercase one.
`ensure_wallpaper_dir` preserves that.

**Home path templating.** `config/` was captured from `/home/mohammedaouamri`.
Files that are copied get `/home/mohammedaouamri` replaced by `$HOME`
(`render_copy`, `REPO_HOME` env). Symlinked files cannot be rewritten at install
time, so absolute paths inside them were replaced by `$HOME` (starship, fish) or
are fixed by `scripts/render-home.sh` if the username ever differs.

## Stage order

`packages → configs → system → shell → post` (configs before system on purpose:
the `system` stage enables the user unit that the `configs` stage puts in place).

- **packages**: enable multilib, full `pacman -Syu`, groups, paru bootstrap, AUR.
- **configs**: `git submodule update`, symlink/copy matrix, render `aria2.conf`,
  wallpaper dirs.
- **system**: install `system/etc/*` + custom xkb `us` (with the `bruh` variant
  used by `kb_variant`), SilentSDDM, enable system units (and user units if a
  session bus is reachable).
- **shell**: oh-my-zsh + plugins, powerlevel10k, pyenv clone, Zen, `chsh`.
- **post**: wallpapers, `fc-cache`, `hyprctl reload`, manual-steps checklist.

## Current state

- Installer is complete and was verified with `--dry-run` on the capture machine
  plus a fresh clone (`--recurse-submodules`) from GitHub. **It has never been
  run for real end-to-end**, so the first real run is still the acceptance test.
- `./scripts/check-packages.sh` is green against the live system.
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
   `link_dir` will refuse to replace it until those are committed.
7. Not restored on purpose: browser profiles, docker volumes/images, LM Studio
   models, KDE `plasma*` state, `~/.local/state`, pyenv builds, gh auth, SSH/GPG
   keys, `odysseus` + `openclaw-gateway` units.

## How to change things

```bash
# add a package to a group, then verify the lists still match reality
vim packages/40-apps.txt
./scripts/check-packages.sh

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
./scripts/check-packages.sh          # must be green on the capture machine
./install.sh --dry-run               # no sudo, no writes, full stage walk
git clone --recurse-submodules <remote> /tmp/check && cd /tmp/check && ./install.sh --dry-run
```

Nothing should touch `~/.config` or `/etc` unless `--dry-run` is absent.
