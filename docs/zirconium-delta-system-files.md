# Zirconium system-files / overrides Deltas for sodimo/harness

## Summary

Upstream zirconium performed a major architectural refactor (ec2a120) that moved all `/etc/` overrides into `/usr/share/factory/` and materializesthem at boot via `tmpfiles.d` symlinks — sodimo/harness has not adopted this and still places overrides directly in `mkosi.extra/etc/`. The SELinux `store-root` fix (49f56df) is absent from sodimo's `fedora-bootc-ostree` postinst. The DMS greeter `--cache-dir` flag (c6b51ef) and the `dms.service.d` satty override (05a51f3) are both missing from sodimo, which could cause greeter-state warnings and break screenshot annotation on the kiosk display. The `zocr` OCR-screenshot utility (586a2ad) and OpenRGB udev rules (6520b85) are upstream additions that sodimo has not pulled; both are low-priority for a headless kiosk. Sodimo's own additions — `sodimo-system.target`, NAS automount, kargs, sunshine/cloudflared packages, unprivileged-ports sysctl — have no upstream equivalent and are untouched by these upstream commits.

---

## P0 — correctness / security

### SELinux `store-root` fix (#228 / 49f56df)

**Status: MISSING in sodimo.**

Upstream's `mkosi.profiles/fedora-bootc-ostree/mkosi.postinst.chroot` appends:

```
printf "\n%s\n" "store-root=/etc/selinux" | tee -a /etc/selinux/semanage.conf
```

before the `cp -r /var/lib/selinux/targeted/active /etc/selinux/targeted/` block. Sodimo's equivalent file runs the `cp` commands but omits the `semanage.conf` write. Without `store-root=/etc/selinux`, `semanage` and `semodule` read from `/var/lib/selinux` at runtime; on a bootc/ostree image that directory may be reset or empty after an upgrade, making SELinux policy modifications fail silently or error.

**Action:** Add the `printf store-root` line to `/home/tom/sodimo-dev/harness/mkosi.profiles/fedora-bootc-ostree/mkosi.postinst.chroot`, immediately before the `cp -r /var/lib/selinux/targeted/active` line.

---

## P1 — architectural

### `/etc` → `/usr/share/factory` + `tmpfiles.d` refactor (ec2a120)

See the detailed analysis section below. This is the highest-effort but most important architectural delta.

---

## P2 — quality of life

### DMS greeter `--cache-dir` fix (c6b51ef)

**Status: MISSING in sodimo — IMPORTANT for kiosk use.**

Upstream's `greetd/config.toml` (stored in `/usr/share/factory/etc/greetd/config.toml`) sets:

```toml
command = "dms-greeter --command niri --cache-dir /var/cache/dms-greeter -C /etc/greetd/niri/config.kdl"
user = "greeter"
```

Sodimo's `/mkosi.extra/etc/greetd/config.toml` runs:

```toml
command = "niri-session"
user = "tom"
```

This means sodimo is **not using dms-greeter at all** in the greetd config — it is auto-logging directly as `tom`. This is intentional for a kiosk/headless setup, but it means that if DMS greeter is ever enabled (e.g., to enforce a lock screen on the kiosk display), the missing `--cache-dir` will cause it to fail to find its state and emit cache-directory warnings at startup.

If DMS greeter is to be used at any point: adopt the upstream `--cache-dir /var/cache/dms-greeter` flag and add the corresponding `tmpfiles.d` and `sysusers.d` entries (see factory refactor section).

### DMS satty screenshot-editor override (05a51f3)

**Status: MISSING in sodimo.**

Upstream ships `mkosi.extra/usr/lib/systemd/user/dms.service.d/override.conf`:

```ini
[Service]
Environment=DMS_SCREENSHOT_EDITOR=satty
```

Sodimo installs `dms` (via `harness-dms-copr.conf`) but has no `dms.service.d` override and does not install `satty`. Without this, DMS will fall back to its default screenshot editor or emit a warning. For a remote-display kiosk using sunshine, screenshot annotation via satty is useful but not critical. Effort is minimal: add the override conf + `satty` to the package list.

### `zocr` OCR screenshot script (586a2ad)

**Status: Not present in sodimo.**

Upstream adds `/usr/bin/zocr` — a bash script that takes a niri screenshot, runs `tesseract`, and copies text to clipboard via `wl-copy`. Depends on `tesseract` and `wl-clipboard`. Requires `niri msg action` IPC.

Applicability for sodimo kiosk: low. The primary interaction surface is remote display via sunshine/moonlight; clipboard OCR is a desktop convenience. Skip unless interactive terminal sessions on the kiosk display are a workflow.

### `chezmoi-update` timer (upstream only)

**Status: Not ported by sodimo.**

Upstream ships `chezmoi-update.service` + `chezmoi-update.timer` (daily, `OnBootSec=5m`) and enables them in `01-zirconium.preset`. Sodimo's `chezmoi-init.service` only runs once (`ConditionPathExists=!%h/.local/share/chezmoi`). This means dotfile updates from `/usr/share/harness/dotfiles` are never re-applied automatically.

For a kiosk image where dotfiles are baked in (not fetched from a remote source), this is acceptable. If sodimo ever adds a remote dotfiles source, port the timer.

---

## P3 — cosmetic / skip

### OpenRGB udev rules (6520b85)

Upstream added udev rules for OpenRGB RGB controller hardware. Sodimo targets a Framework Desktop (Strix Halo) with no addressable RGB hardware in the kiosk configuration. **Skip.**

### `glorpfetch` / `zfetch` / `zmotd` / shell motd pipeline

Upstream ships branded motd/fetch scripts in `mkosi.extra/usr/bin/` and profile.d entries (`zfetch.sh`, `zmotd.sh`). Sodimo omits all of these. Cosmetic; not relevant to headless kiosk. **Skip.**

### `taidan.toml` factory config

Upstream places a `taidan.toml` in `/usr/share/factory/etc/` for first-boot setup wizard. Sodimo does not use taidan (the binary is commented out in upstream's own postinst with a FIXME). **Skip.**

---

## `/etc` → `/usr/share/factory` refactor — detailed analysis

### What upstream changed

Commit ec2a120 moved all mutable `/etc/` overrides out of `mkosi.extra/etc/` and into `mkosi.extra/usr/share/factory/etc/`. A new `tmpfiles.d` rule file (`99-zirconium-factory.conf`) creates symlinks at boot:

```
L+ /etc/containers/policy.json          - - - - /usr/share/factory/etc/containers/policy.json
L+ /etc/containers/registries.d/zirconium-dev.yaml
L+ /etc/taidan.toml
L  /etc/greetd/config.toml
L  /etc/profile.d/fcitx5.sh
L  /etc/profile.d/zfetch.sh
L  /etc/profile.d/zirconium-font-settings.sh
L  /etc/profile.d/zirconium-qt-override.sh
L  /etc/profile.d/zmotd.sh
d  /etc/greetd/niri
f  /etc/greetd/niri/config.kdl
```

(`L+` = force-create symlink even if target exists; `L` = create symlink only if missing.)

### Why bootc prefers this pattern

bootc's `/etc` overlay is a 3-way merge between the image `/etc`, the previous deployment `/etc`, and the running system `/etc`. Files placed directly in `mkosi.extra/etc/` become part of the image `/etc` but are subject to that merge on upgrade, which can cause unexpected overwrites or conflicts. Placing canonical content in `/usr/share/factory/etc/` (immutable, under `/usr/`) and symlinking into `/etc/` at boot via `tmpfiles.d` bypasses the merge entirely: the symlink itself is trivially mergeable, and the content is always the version baked into the current image.

### What sodimo currently places in `mkosi.extra/etc/`

| File | Risk if left in /etc |
|---|---|
| `etc/greetd/config.toml` | Low — auto-login config, unlikely to conflict |
| `etc/containers/policy.json` | Medium — upgrade merge could revert container registry trust |
| `etc/containers/registries.d/harness.yaml` | Medium — same |
| `etc/firewalld/zones/external.xml` + `internal.xml` | Medium — firewall policy drift on upgrade |
| `etc/NetworkManager/system-connections/router-link.nmconnection` | **High** — NM manages this at runtime; symlinking would break NM write-back. Leave in `/etc/` or use `nmconnection` in a separate mechanism. |
| `etc/pam.d/greetd-greeter` | Low — PAM files not touched by bootc merge in practice |
| `etc/polkit-1/rules.d/10-udisks2.rules` | Low |
| `etc/profile.d/fcitx5.sh` | Low — identical to upstream factory content |
| `etc/profile.d/harness-font-settings.sh` | Low |
| `etc/profile.d/harness-qt-override.sh` | Low |
| `etc/sysctl.d/99-router.conf` | Low — sysctl.d is read-only drop-in, fine in either location |
| `etc/sysctl.d/99-sodimo-unprivileged-ports.conf` | Low — same |
| `etc/systemd/resolved.conf.d/99-harness.conf` | Low — drop-in, fine in either location |
| `etc/xdg/xdg-terminals.list` | Low |

### Migration effort estimate

**Low-to-medium.** The mechanical work is:
1. Move the files from `mkosi.extra/etc/` to `mkosi.extra/usr/share/factory/etc/` (keeping the same relative paths).
2. Create `mkosi.extra/usr/lib/tmpfiles.d/99-harness-factory.conf` with `L+` rules for each file.
3. Validate with `systemd-tmpfiles --create --prefix=/etc` in a test image.

**Exceptions — do NOT move to factory:**
- `etc/NetworkManager/system-connections/router-link.nmconnection`: NM writes runtime state back to `/etc/NetworkManager/system-connections/`. A symlink pointing into `/usr/` would be read-only and NM would refuse or silently drop changes. Keep this in `mkosi.extra/etc/` or provision it via NM keyfile in a firstboot service.
- `etc/pam.d/greetd-greeter`: PAM files must be regular files, not symlinks, for some PAM implementations. Use `L+` with care; test explicitly.

**Sodimo-specific units not affected:**
`sodimo-system.target`, `mnt-nas.automount/mount`, `enable-linger.service` all live under `usr/lib/systemd/` already — correctly outside `/etc/`. The sunshine and cloudflared packages are installed via RPM, not via `mkosi.extra/etc/`. The kargs toml lives under `usr/lib/bootc/kargs.d/`. None of these are affected by the factory refactor.

**Recommendation:** Adopt the factory refactor in the next image build cycle. The correctness benefit (no bootc upgrade merge conflicts on policy.json, firewalld zones, and profile.d scripts) outweighs the migration cost. Prioritize `containers/policy.json` and `firewalld/zones/` as the highest-risk files.

---

## SELinux fix (#228) — applicability

**Verdict: Apply immediately.** Sodimo's `mkosi.profiles/fedora-bootc-ostree/mkosi.postinst.chroot` is missing the `store-root=/etc/selinux` line in `semanage.conf`. This is a one-line addition. Without it, any post-boot `semanage`/`semodule` invocation (e.g., adding a custom policy for cloudflared or sunshine) will read from `/var/lib/selinux` which is under `/var/` — not persisted across bootc upgrades in the same way as `/etc/selinux/`. The upstream fix was specifically motivated by `semanage` failing to find the policy store after a bootc image transition.

**Diff to apply** in `mkosi.profiles/fedora-bootc-ostree/mkosi.postinst.chroot`:

```bash
# Add before: cp -r "/var/lib/selinux/targeted/active" "/etc/selinux/targeted/"
printf "\n%s\n" "store-root=/etc/selinux" | tee -a /etc/selinux/semanage.conf
grep -F -e "store-root=/etc/selinux" /etc/selinux/semanage.conf  # verify
```

---

## DMS greeter cache fix — applicability

Sodimo's greetd is configured for direct auto-login as `tom` (not using dms-greeter). The `--cache-dir` fix is not blocking today. However, if a lock-screen or multi-session flow is ever added, note:

1. The `greeter` sysuser (`uid=767`) and group must be created via `sysusers.d` — upstream ships `mkosi.extra/usr/lib/sysusers.d/dms-greeter.conf`. Sodimo does not have this.
2. The `tmpfiles.d` rule creating `/var/cache/dms-greeter/` with `greeter:greeter` ownership (`99-dms-greeter.conf`) must be added.
3. The greetd `config.toml` must pass `--cache-dir /var/cache/dms-greeter` to `dms-greeter`.

None of this is needed while the kiosk auto-logs in as `tom`. Flag for if greetd's `user` is ever changed back to `greeter`.

---

## New udev rules / services — applicability to sodimo

| Item | Upstream commit | Sodimo relevance |
|---|---|---|
| OpenRGB udev rules | 6520b85 | None — no RGB hardware in Framework Desktop kiosk config. Skip. |
| `zocr` script + tesseract | 586a2ad | Low — clipboard OCR is a desktop convenience. Sunshine remote session can relay clipboard anyway. Skip unless local terminal workflow needed. |
| `dms.service.d` satty override | 05a51f3 | Applicable if screenshot annotation is used in the kiosk session. Low effort: add override conf + `satty` package. |
| `chezmoi-update.timer` | (upstream only) | Not needed while dotfiles are baked in from `/usr/share/harness/dotfiles`. Revisit if remote chezmoi source is added. |
