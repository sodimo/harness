# Harness scope

Authoritative source-of-truth for what lives in `sodimo/harness` versus the sibling Sodimo repos. Tracks D-014 (harness scope) and the dotfiles-vs-harness quadlet split (D-164 context).

## One-line definition

> Harness is **anything that goes into the Linux server that is not a dot-config file** — it is programs.
> (No Terraform.)
> — Tom's annotation, D-014

## What lives in `sodimo/harness`

The OS image itself — a Fedora 44 bootc image built with `mkosi` — and the **system-scope** surface that lives below the user session.

Concretely:

- **Base OS image** (`mkosi.conf`, `mkosi.profiles/`, `mkosi.postinst.chroot`) — Fedora 44 bootc derivation.
- **Package selection** (`mkosi.conf.d/*.conf`) — every RPM that ships in the image, including Caddy, Cockpit, cloudflared, tailscale, sunshine+moonlight-qt.
- **Repo definitions** (`repos/*.repo`) — third-party DNF repositories sandboxed in during build.
- **Kernel cmdline** (`mkosi.extra/usr/lib/bootc/kargs.d/harness.toml`) — Strix Halo `iommu=pt` + `amdgpu.gttsize` + `ttm.pages_limit` (#11).
- **Sysctl drop-ins** (`mkosi.extra/etc/sysctl.d/*.conf`) — e.g. `net.ipv4.ip_unprivileged_port_start=0` (#8) and `net.ipv4.ip_forward=1`.
- **System-scope systemd units** (`mkosi.extra/usr/lib/systemd/system/`) — `tailscaled`, `cloudflared`, `cockpit.socket`, `mnt-nas.*`, grouped under `sodimo-system.target` (#7).
- **System-scope presets** (`mkosi.extra/usr/lib/systemd/system-preset/01-harness.preset`) — auto-enable list.
- **Compositor + login** — niri WM (git COPR), DankMaterialShell panel, greetd direct-login.
- **Baked dotfiles snapshot** — `subprojects/dotfiles` submodule (points at `sodimo/dotfiles`) copied to `/usr/share/harness/dotfiles` and applied on first login by `chezmoi-init.service`.

## What does **not** live here

### `sodimo/dotfiles`
User-scope surface: every podman **quadlet** (Caddy site blocks, the self-hosted mail stack, OpenWebUI, Vaultwarden, Twenty CRM), the user-scope `sodimo.target`, user-scope systemd units. Anything you'd `systemctl --user` runs from here. Shipped into the image as a static snapshot — `static-at-handoff`, no runtime git pulls. See #10 for the rewire that dropped the runtime-update path.

### `sodimo/mcp`
Model Context Protocol servers and wrappers (Twenty MCP, etc.). Not baked into the OS image.

### `sodimo/etl`
ETL scripts / cron jobs for the data layer. Not baked into the OS image.

### `sodimo/changelog`
The end-user manual. Owns `35-harness.md` — the narrative doc for operators — which this file **does not** replace. This file is the in-repo technical source of truth; the changelog manual is the human-facing text.

## Scope-boundary principles

- **No Terraform** in this repo — infrastructure-as-code lives elsewhere if at all.
- **System-scope vs user-scope split** is the primary axis: harness ships everything that starts before a user logs in; dotfiles ships everything scoped to `--user`.
- **Static-at-handoff**: once an image is built and shipped, the device never phones home to git. Updates arrive via a new bootc image + `bootc switch`.
- **Pin every version** (principle 1 / D-167): RPMs and container images have explicit version tags; `:latest` is banned except for deliberately-called-out exceptions (currently just `cockpit:latest`).

## In-flight work tracked by issue

- **#4** (D-052) — Gemma + Qwen + next local model: quadlets live in `sodimo/dotfiles`; harness provides the GPU kargs (#11) and the package stack (`llama-swap`, vulkan drivers already shipped).
- **#5** (D-065) — OpenWebUI quadlet: lives in `sodimo/dotfiles` as a user-scope quadlet; harness exposes the reverse-proxy + port.
- **#2** (D-024) — NAS mount protocol: in-person blocker.
- **#3** (D-025) — Framework Desktop rack placement: in-person blocker.

## Cross-references

- Decision ledger: `sodimo/changelog:src/content/manual/en/55-annex-decisions.md`
- Operator manual chapter: `sodimo/changelog:src/content/manual/en/35-harness.md`
- Dotfiles split: `sodimo/dotfiles#13` (chezmoi auth decision)
