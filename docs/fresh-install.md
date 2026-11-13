# Base install (before `./install.sh`)

`install.sh` only handles a system that already boots and has a user + network.
This is the part it cannot do for you. Pick your distro below; the Arch path is
the one the repo was captured from and is the most detailed.

The post-install part is identical on all three: clone the repo (with
submodules), run `./install.sh --dry-run`, then `./install.sh`.

## Arch

### 1. Boot the ISO

Boot the Arch ISO in UEFI mode (`archinstall` needs UEFI for limine; if you use
legacy BIOS, install GRUB instead — `grub` is in `00-base.txt`).

### 2. archinstall

Suggested answers (adjust disk/timezone to taste):

| Screen | Value |
| --- | --- |
| Mirrors | your country / nearest, `ParallelDownloads = 20` is applied later by the installer |
| Disk | wipe, GPT, ext4 or btrfs, **no swap partition** (zram is used) |
| Bootloader | **limine** (limine + limine-mkinitcpio-hook are in the package group) |
| Kernels | `linux` **and** `linux-lts` |
| Hostname | whatever you like |
| Locale | `en_US.UTF-8`, UTF-8 |
| Timezone | `Africa/Casablanca` |
| Keyboard | `us` |
| Profile | `Minimal` (no desktop — Hyprland comes from the AUR metapackages) |
| Audio | `pipewire` |
| Network | `NetworkManager` (NetworkManager + iwd is fine too) |
| Additional packages | `base-devel git` |
| User | your normal user, member of `wheel`, with a password |

Reboot, log in on the TTY, and check networking:

```bash
ping -c1 archlinux.org
```

### 3. Clone and run

```bash
sudo pacman -S --needed git
git clone --recurse-submodules git@github.com:mohammedaouamri5/setup-archlinux.git
cd setup-archlinux
./install.sh --dry-run   # optional, inspect
./install.sh
```

The `packages` stage enables `[multilib]`, does a full `pacman -Syu`, and installs
everything including `nvidia-open` / `nvidia-open-lts` and the Vulkan stack.

### 4. NVIDIA notes (RTX 3060)

- `nvidia-open` + `nvidia-open-lts` are installed by `20-nvidia.txt`;
  `nvidia_drm.modeset=1` is what matters for Wayland.
- With limine, kernel parameters live in `/etc/default/limine` (package `limine`)
  and are applied by the limine hook. Make sure the cmdline contains:

  ```
  nvidia_drm.modeset=1
  ```

  then regenerate: `sudo limine-update` (or re-run the mkinitcpio hook).
- `nvidia-container-toolkit` is in the group; the docker NVIDIA runtime is
  configured by `system/etc/docker/daemon.json`.
- `system/etc/systemd/system/ollama.service.d/override.conf` points ollama at
  the CUDA libraries.

### 5. Locale (optional)

The base install already generated `en_US.UTF-8`. If you want another locale:

```bash
sudo sed -i 's/^#fr_FR.UTF-8/fr_FR.UTF-8/' /etc/locale.gen
sudo locale-gen
```

## Fedora

### 1. Base install

Use the **Fedora Workstation** or **Everything** netinstall and pick
"Minimal Install" (or Workstation if you want a GUI to fall back to). Create your
user, make sure it is in `wheel`, and update:

```bash
sudo dnf -y upgrade --refresh
sudo dnf -y install git curl tar
```

### 2. Enable the extra repositories

`install.sh` does not add third-party repositories for you. Before the first run,
enable what the maps assume:

```bash
# free + nonfree packages (NVIDIA, codecs, VirtualGL, ...)
sudo dnf -y install \
  https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# Hyprland + the Wayland tools (community COPR)
sudo dnf -y copr enable solopasha/hyprland
```

Notes specific to Fedora:

- The NVIDIA mapping in `packages/maps/fedora.map` installs `akmod-nvidia` and
  `xorg-x11-drv-nvidia-cuda` from RPM Fusion. If you use Secure Boot, enrol the
  akmod key (`sudo akmods --force` prints the path) or disable Secure Boot.
- `dnf` has no AUR. Anything AUR-only is either mapped to a native package
  (`visual-studio-code-bin` → `code`, `neofetch` → `neofetch`) or skipped with a
  warning. Hyprland/quickshell/matugen come from the COPR.
- Fedora's default `firewalld` replaces `ufw`/`iptables`; the service list is
  split so `system/services/system.fedora.txt` is used automatically.
- Use `--strict` if you want a missing mapping to fail instead of warn.

### 3. Clone and run

```bash
git clone --recurse-submodules git@github.com:mohammedaouamri5/setup-archlinux.git
cd setup-archlinux
./install.sh --dry-run --force --distro fedora  # optional, inspect the plan
./install.sh --distro fedora                     # or omit --distro (auto-detected)
```

## openSUSE

### 1. Base install

Use the **openSUSE Tumbleweed** netinstall or DVD and choose the "Server" or
"Minimal" pattern. Tumbleweed is assumed; Leap works but has older Hyprland
packages. Create your user in `wheel` and update:

```bash
sudo zypper --non-interactive refresh
sudo zypper --non-interactive dup      # Tumbleweed
sudo zypper --non-interactive install git curl tar
```

### 2. Enable the extra repositories

```bash
# Hyprland and friends (OBS)
sudo zypper --non-interactive addrepo --refresh \
  https://download.opensuse.org/repositories/X11:/Hyprland/openSUSE_Tumbleweed/ hyprland
sudo zypper --non-interactive --gpg-auto-import-keys refresh

# NVIDIA (only if you have an NVIDIA card)
sudo zypper --non-interactive addrepo --refresh \
  https://download.nvidia.com/opensuse/tumbleweed nvidia
sudo zypper --non-interactive --gpg-auto-import-keys refresh
```

Notes specific to openSUSE:

- `packages/maps/opensuse.map` installs the `plasma6-*` names and
  `nvidia-open-driver-G06-signed-kmp-default`. If your card needs the
  proprietary driver, change the `nvidia-open` line in the map.
- `zypper` does not have an AUR. AUR-only apps are mapped or skipped exactly like
  on Fedora; `packages/extra/opensuse.txt` lists native alternatives.
- Some packages (`qt6-multimedia-ffmpeg`, `qt6-imageformats`, `webkitgtk-6.0`)
  are not in the default repos; the SDDM theme still installs with the packages
  that are available. Add a repo or accept the warnings.
- Use `--strict` to turn missing packages into errors.

### 3. Clone and run

```bash
git clone --recurse-submodules git@github.com:mohammedaouamri5/setup-archlinux.git
cd setup-archlinux
./install.sh --dry-run --force --distro opensuse  # optional, inspect the plan
./install.sh                                     # auto-detects zypper
```

## Why not Debian/Ubuntu

Deliberately unsupported. `lib/pkg.sh` refuses `debian`, `ubuntu`, `linuxmint`,
`pop`, `elementary`, `kali`, `raspbian`, `neon`, `zorin` and anything whose
`ID_LIKE` mentions them. There is no `apt` backend to keep tested, and the
maintainer does not run them.

## After the first login (all distros)

1. Re-add secrets (see README "Not included"): `ssh-keygen -t ed25519`, `gh auth login`,
   quickshell/AI provider keys, `~/.config/opencode/service.json`.
2. `pyenv install 3.12 && pyenv global 3.12` (builds take ~10 min each).
3. `systemctl --user daemon-reload && systemctl --user enable --now aria2.service`
   if the installer could not reach a session bus.
4. Put your wallpaper URLs in `config/wallpapers/urls.txt` and run
   `./scripts/fetch-wallpapers.sh`.
5. Reboot once — SDDM (`silent` theme), NVIDIA modeset and the quickshell
   autostart all settle cleanly after a real reboot.
