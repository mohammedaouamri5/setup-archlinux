# Package lists

One file per role. Names are written in **Arch spelling**; `lib/pkg.sh`
translates them through `maps/<family>.map` on Fedora and openSUSE. Comments and
blank lines are ignored, and only the first column of a line is used.

| File | Contents |
| --- | --- |
| `00-base.txt` | kernels, bootloader, core CLI, fonts. Installed with `--needed`, so it is a no-op on an existing system. |
| `10-desktop.txt` | audio, bluetooth, theming, printing, screenshots, SDDM, Wayland plumbing. |
| `20-nvidia.txt` | `nvidia-open` (+lts), CUDA containers, Vulkan stack. Skip with `--no-nvidia`. |
| `30-dev.txt` | docker, neovim, language servers, TeX Live, ollama, opencode. |
| `40-apps.txt` | aria2, qBittorrent (+ `qbittorrent-nox` daemon), mpv, Obsidian, Steam/Lutris/wine, QEMU, tailscale. |
| `50-kde.txt` | Plasma 6 + the KDE apps the Hyprland keybinds use. Skip with `--no-kde`. |
| `90-aur.txt` | AUR-only packages, `illogical-impulse-*` metapackages first. On non-Arch it is translated and installed optionally. |

Skipping groups:

```bash
./install.sh --no-nvidia                  # AMD/Intel machine
./install.sh --no-kde                     # Hyprland-only
./install.sh --skip-group 30-dev          # drop ~4 GB of TeX
```

## maps/

`maps/arch` is implicit (no file needed). The other two translate the canonical
names:

```
# canonical-name    native-name [more native names...]
base-devel          @development-tools
linux-lts           -
texlive-*           texlive-scheme-full
```

- Exact match first, then globs in file order.
- `-` means the package does not exist on that distro and is dropped.
- No entry means "try the Arch name unchanged".
- A missing package warns; `--strict` makes it an error.

Verify a change without installing anything:

```bash
./install.sh --dry-run --force --distro fedora --stage packages
./install.sh --dry-run --force --distro opensuse --stage packages --strict
```

## extra/

Native packages with no canonical Arch counterpart (mostly the
Hyprland/quickshell stack). They are installed **optionally** on that family,
after the translated groups. Third-party repositories are not added
automatically — see [docs/fresh-install.md](../docs/fresh-install.md):

- Fedora: RPM Fusion + `solopasha/hyprland` COPR.
- openSUSE: NVIDIA repo + `X11:Hyprland` OBS repo.

## Keeping lists in sync with reality

```bash
./scripts/check-packages.sh
```

On Arch it compares the expanded lists against `pacman -Qqe` and reports drift.
Expected noise: AUR helpers (`paru`, `yay`), `-debug` splits, and packages pulled
in as dependencies. On Fedora/openSUSE it exits with a notice (the drift check
is Arch-only).
