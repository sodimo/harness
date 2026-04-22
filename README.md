# Harness

Personal Fedora 44 bootc image. AMD-only, amd64-only. Niri compositor with DankMaterialShell panel, greetd direct login, kitty terminal, chezmoi dotfiles. Built with raw `podman build` from `quay.io/fedora/fedora-bootc:44`.

## Installation

### From an existing Fedora Atomic system

```bash
sudo bootc switch --transport registry ghcr.io/sodimo/harness:latest
```

Note that we may need to have
```
sudo bootc switch ghcr.io/sodimo/harness:latest
systemctl reboot
```


### Fresh install via ISO

Download the ISO from [GitHub Actions artifacts](https://github.com/sodimo/harness/actions/workflows/build-iso.yml) (built monthly).

## Specs

- **Base**: Fedora 44 bootc
- **Compositor**: Niri (git, via COPR)
- **Panel**: DankMaterialShell (via COPR avengemedia/dms)
- **Login**: greetd (direct niri-session, no greeter UI)
- **Terminal**: kitty (primary), foot (kept for niri ecosystem)
- **Dotfiles**: chezmoi from [github.com/sodimo/dotfiles](https://github.com/sodimo/dotfiles), baked into the image as a snapshot at `/usr/share/harness/dotfiles` (static-at-handoff; updates ship via new bootc images, not a daily pull)
- **Updates**: bootc auto-updates (7-day timer) + uupd

## Packages

See [comparison.yml](comparison.yml) for the full package list.

## Building

```bash
podman build -t harness:latest -f Containerfile .
```

## License

Apache 2.0

### Thanks

A lot of inspiration was taken from [zirconium](https://github.com/zirconium-dev/zirconium)
