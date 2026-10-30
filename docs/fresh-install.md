# Base install (before `./install.sh`)

`install.sh` only handles a system that already boots and has a user + network.
This is the part it cannot do for you.

## 1. Boot the ISO

Boot the Arch ISO in UEFI mode (`archinstall` needs UEFI for limine; if you use
legacy BIOS, install GRUB instead — `grub` is in `00-base.txt`).

## 2. archinstall

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

## 3. Clone and run

```bash
sudo pacman -S --needed git
git clone --recurse-submodules git@github.com:mohammedaouamri5/setup-archlinux.git
cd setup-archlinux
./install.sh --dry-run   # optional, inspect
./install.sh
```

The `packages` stage enables `[multilib]`, does a full `pacman -Syu`, and installs
everything including `nvidia-open` / `nvidia-open-lts` and the Vulkan stack.

## 4. NVIDIA notes (RTX 3060)

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

## 5. Locale (optional)

The base install already generated `en_US.UTF-8`. If you want another locale:

```bash
sudo sed -i 's/^#fr_FR.UTF-8/fr_FR.UTF-8/' /etc/locale.gen
sudo locale-gen
```

## 6. After the first login

1. Re-add secrets (see README "Not included"): `ssh-keygen -t ed25519`, `gh auth login`,
   quickshell/AI provider keys, `~/.config/opencode/service.json`.
2. `pyenv install 3.12 && pyenv global 3.12` (builds take ~10 min each).
3. `systemctl --user daemon-reload && systemctl --user enable --now aria2.service`
   if the installer could not reach a session bus.
4. Put your wallpaper URLs in `config/wallpapers/urls.txt` and run
   `./scripts/fetch-wallpapers.sh`.
5. Reboot once — SDDM (`silent` theme), NVIDIA modeset and the quickshell
   autostart all settle cleanly after a real reboot.
