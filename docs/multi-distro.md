# Multi-distro support

The repo runs on Arch, Fedora and openSUSE. Debian/Ubuntu are refused on
purpose. The goal is one set of dotfiles and one canonical package list, with a
small translation layer for names that differ.

## How the distro is detected

`lib/pkg.sh` reads `/etc/os-release` once in `preflight`, before any stage runs.

| `ID` / `ID_LIKE` | `DISTRO_FAMILY` | `PKG_BACKEND` |
| --- | --- | --- |
| `arch`, `manjaro`, `endeavouros`, `garuda`, `cachyos`, `artix`, `arcolinux` | `arch` | `pacman` |
| `fedora`, `rhel`, `centos`, `rocky`, `almalinux`, `nobara`, `bazzite`, `ultramarine` | `fedora` | `dnf` |
| `opensuse*`, `suse`, `sles`, `tumbleweed`, `leap`, `slowroll` | `opensuse` | `zypper` |
| `debian`, `ubuntu`, `linuxmint`, `pop`, `elementary`, `kali`, `raspbian`, `neon`, `zorin` | — | `die` |

Anything else is tried through `ID_LIKE`; if that also fails, the installer
stops with `unsupported distribution`. `--distro arch|fedora|opensuse` overrides
detection for planning and is meant to be used with `--dry-run`.

## Canonical lists and the map format

`packages/*.txt` always use the **Arch spelling**, because that is what the live
machine runs and what `check-packages.sh` compares against `pacman -Qqe`.
On a non-Arch host each name goes through `packages/maps/<family>.map`:

```
# left = canonical (Arch) name, right = native name(s), comma or space separated
ros2-humble       ros-humble-desktop
texlive-*         texlive-scheme-full
illogical-impulse-*  -
some-package      -
```

Rules:

1. An **exact** match wins.
2. Otherwise the first matching **glob** wins (file order).
3. No match → the Arch name is tried as-is.
4. A right-hand side of `-` means "not available here" and drops the package.
5. A right-hand side with several names installs all of them.

A package that the native manager cannot find only produces a warning, so a
missing app never aborts a rebuild. `--strict` turns those warnings into
failures — useful when you are actively fixing a map.

`packages/extra/<family>.txt` is for packages that exist natively but have no
canonical Arch counterpart in the lists (the Hyprland/quickshell stack on
Fedora/openSUSE). Extras are installed **optionally**: failures warn but do not
stop the run.

## What each stage does off Arch

| Stage | Arch | Fedora | openSUSE |
| --- | --- | --- | --- |
| `packages` prepare | enable `[multilib]` | nothing | nothing |
| upgrade | `pacman -Syu` | `dnf -y --refresh upgrade` | `zypper refresh` + `dup` (Tumbleweed) / `update` (Leap) |
| base devel | `base-devel` | `@development-tools` | `pattern devel_basis` |
| canonical groups | pacman + translated names | dnf + `fedora.map` | zypper + `opensuse.map` |
| native extras | — | `extra/fedora.txt` | `extra/opensuse.txt` |
| AUR | bootstrap `paru-bin`, install `90-aur.txt` | translate `90-aur.txt`, optional | translate `90-aur.txt`, optional |
| `system` `/etc` | all files, including `pacman.conf` | all except `pacman.conf` | all except `pacman.conf` |
| `system` units | `system.txt` + `system.arch.txt` | `system.txt` (+ optional `system.fedora.txt`) | `system.txt` (+ optional `system.opensuse.txt`) |

Units are enabled only if `systemctl list-unit-files` knows them, so a service a
distro does not ship is a warning rather than an error. Installing Hyprland,
quickshell and matugen still requires the distro's third-party repository:

- **Fedora**: `sudo dnf copr enable solopasha/hyprland` (plus RPM Fusion for
  NVIDIA/codecs).
- **openSUSE**: the `X11:Hyprland` OBS repository (plus the NVIDIA repository
  for the driver).

`docs/fresh-install.md` has the exact commands.

## AUR-only packages

`90-aur.txt` is Arch-first. Off Arch the whole file is translated with the same
map and installed as *optional* packages, which means:

- `illogical-impulse-*` → `-` (provided by the native Hyprland/quickshell
  packages in `extra/<family>.txt` instead),
- `visual-studio-code-bin` → `code`,
- `yay-bin` / `paru-bin` → `-` (no AUR helper needed),
- everything else is tried under its Arch name and skipped with a warning when
  absent.

## Adding or fixing a distro name

```bash
# 1. see what the installer would try
./install.sh --dry-run --force --distro fedora --stage packages

# 2. add or correct the mapping
vim packages/maps/fedora.map

# 3. re-run; use --strict to see every miss as an error
./install.sh --dry-run --force --distro fedora --stage packages --strict

# 4. if the package simply has no canonical counterpart, add it to extras
vim packages/extra/fedora.txt
```

Use the distro's search command to find the real name:

```bash
dnf search <term>            # Fedora
zypper search <term>         # openSUSE
pacman -Ss <term>            # Arch
```

## Why no Debian/Ubuntu backend

Deliberately unsupported. There is no `apt` code path to test, the maintainer
does not run Debian-based systems, and a "best effort" apt backend would be
dead weight that rots. `lib/pkg.sh` refuses the family early with a clear
message. If that ever changes, add `PKG_BACKEND=apt`, an `apt` branch in
`pkg_refresh`/`pkg_install`/`pkg_list_installed`, and
`packages/maps/debian.map` — but do not half-support it.

## Known gaps

- Fedora/openSUSE maps were checked against package indexes, not installed on
  real machines. The first real run is the acceptance test; expect warnings.
- `check-packages.sh` is Arch-only (it compares `pacman -Qqe` against the
  lists). It exits with a notice elsewhere.
- KDE is a full Plasma 6 install on all three, but package names differ
  (`plasma-desktop` on Fedora vs `plasma6-desktop` on openSUSE); the maps cover
  the packages the Hyprland keybinds use.
- NVIDIA: `nvidia-open` is mapped to `akmod-nvidia` (Fedora, RPM Fusion) and
  `nvidia-open-driver-G06-signed-kmp-default` (openSUSE). If your card needs the
  proprietary driver, edit the map.
- Limine is Arch-only in practice. `00-base.txt` still lists it, and the map
  drops it elsewhere; use GRUB or systemd-boot on Fedora/openSUSE.
