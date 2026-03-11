# Harness

Personal Fedora 44 bootc image. AMD-only, amd64-only. Niri compositor with QuickShell panel, greetd direct login, kitty terminal, chezmoi dotfiles. Built with raw `podman build` from `quay.io/fedora/fedora-bootc:44`.

## Installation

### From an existing Fedora Atomic system

```bash
sudo bootc switch --transport registry ghcr.io/mecattaf/harness:latest
```

Note that we may need to have
```
sudo bootc switch ghcr.io/mecattaf/harness:latest
systemctl reboot
```


### Fresh install via ISO

Download the ISO from [GitHub Actions artifacts](https://github.com/mecattaf/harness/actions/workflows/build-iso.yml) (built monthly).

## Specs

- **Base**: Fedora 44 bootc
- **Compositor**: Niri (git, via COPR)
- **Panel**: QuickShell (via COPR)
- **Login**: greetd (direct niri-session, no greeter UI)
- **Terminal**: kitty (primary), foot (kept for niri ecosystem)
- **Dotfiles**: chezmoi from [github.com/mecattaf/dotfiles](https://github.com/mecattaf/dotfiles)
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
