# Zirconium mkosi/repos/packages Deltas for sodimo/harness

## Summary

Upstream zirconium has diverged from sodimo/harness in three key areas: (1) `uupd` was migrated from ublue-os COPR to terra — harness still ships its own `ublue-os-packages.conf` pulling from COPR; (2) the output/manifest config in `mkosi.conf` is absent from harness top-level (harness places `OutputDirectory`/`Output` inside the profile instead); (3) the base profile is named `base` in harness vs `base-desktop` in upstream — a cosmetic rename but the profile `[Match]` key must stay consistent with `Profiles=` in `mkosi.conf`. The terra repo files are byte-identical between the two repos; the CI metalink/checksum fix (stripping `repo_gpgcheck=1` and `enabled_metadata=0` on the shipped image) is harness-only and correct — upstream has no equivalent. Harness adds a large number of sodimo-specific packages (cockpit, caddy, sunshine/moonlight, google-cloud-cli, font pipeline) with no upstream analog; those are intentional and out of scope for this report.

---

## P0 — CI-breaking / security

### `uupd` still sourced from ublue-os COPR in harness

- **Upstream** (zirconium commit `29ce365`): removed `mkosi.conf.d/ublue-os-packages.conf` and `repos/ublue-os-packages.repo`; added `uupd` to `mkosi.conf.d/terra.conf`.
- **Harness**: `mkosi.conf.d/ublue-os-packages.conf` and `repos/ublue-os-packages.repo` still present; `uupd` not in terra.conf.
- **Risk**: ublue-os COPR is an extra dependency and a potential failure point. If that COPR becomes unavailable or returns a stale package, the build breaks.
- **Recommendation**: adopt. Drop-in change — remove `ublue-os-packages.conf` + `ublue-os-packages.repo`, add `uupd` to `mkosi.conf.d/terra.conf` Packages block.

---

## P1 — correctness

### `OutputDirectory`, `ManifestFormat`, `Output` missing from harness `mkosi.conf`

- **Upstream** `mkosi.conf`:
  ```
  [Output]
  ImageId=Zirconium
  OutputDirectory=mkosi.output
  ManifestFormat=json
  Output=%i_%v_%a
  ```
- **Harness** `mkosi.conf` only has `ImageId=harness`. The `OutputDirectory=mkosi.output` and `Output=%i_%v_%a` are placed inside `mkosi.profiles/bootc-ostree/mkosi.conf` instead.
- Upstream commit `7963d2f` explicitly moved these to the top-level to fix default output placement for all profiles.
- **Recommendation**: adopt. Add `OutputDirectory=mkosi.output`, `ManifestFormat=json`, `Output=%i_%v_%a` to the `[Output]` section in `mkosi.conf`. Then remove the duplicate `OutputDirectory`/`Output` lines from `mkosi.profiles/bootc-ostree/mkosi.conf`.

### `rechunker-group-fix.service` not enabled in zirconium but enabled in harness

- **Harness** `mkosi.profiles/bootc-ostree/mkosi.postinst.chroot` line 23: `systemctl enable rechunker-group-fix.service`
- **Upstream**: no such `systemctl enable` call; service is shipped but not explicitly enabled.
- This is harness-intentional (the service and preset file exist), but worth verifying the preset file (`90-rechunker-fix.preset`) already enables it — if it does, the explicit `systemctl enable` is redundant.

### `rsync` missing from `fedora-bootc-ostree/others.conf` in harness

- **Upstream** `mkosi.profiles/fedora-bootc-ostree/mkosi.conf.d/others.conf` line 41: `rsync`
- **Harness**: `rsync` absent from that file.
- `rsync` is referenced inside `mkosi.profiles/bootc-ostree/mkosi.finalize.chroot` for the RPM DB migration (`rsync -av "$RPM_MUT_DB/" "$RPM_OSTREE_DB/"`). If `rsync` is not available in the tools tree at finalize time this silently degrades to the `2>/dev/null` suppressed path.
- **Recommendation**: check whether the tools tree already provides `rsync`. If not, add it to `others.conf`.

### Profile rename: `base` → `base-desktop` + `Hostname` directive

- **Upstream** `mkosi.conf` line 3: `Profiles=base-desktop,fedora-bootc-ostree`; profile dir is `mkosi.profiles/base-desktop/`.
- **Harness**: `Profiles=base,bootc-ostree,fedora-bootc-ostree`; profile dir is `mkosi.profiles/base/`.
- Also, upstream `mkosi.conf` has `[Content] Hostname=zirconium`; harness sets hostname in `mkosi.postinst.chroot` instead.
- The rename is cosmetic; the important thing is consistency. If harness ever merges profile config from upstream verbatim, `[Match] Profiles=base-desktop` blocks will silently not apply.
- **Recommendation**: track-only. Document the divergence. No functional change needed for a single-profile image.

### `WithRecommends=True` still set in harness `base/base-desktop.conf`

- **Upstream** `base-desktop/base-desktop.conf`: no `WithRecommends` line (removed in commit `d18316e` alongside the rename).
- **Harness** `base/base-desktop.conf` line 6: `WithRecommends=True`
- This causes the base layer to pull recommendations, which can inflate image size unpredictably.
- **Recommendation**: remove the `WithRecommends=True` line from `mkosi.profiles/base/mkosi.conf.d/base-desktop.conf`.

---

## P2 — quality of life

### `virtualbox-guest-additions` still in upstream x86-64 profile; harness already removes it

- Upstream `mkosi.profiles/base-desktop/mkosi.conf.d/x86-64.conf` still includes `virtualbox-guest-additions`.
- Harness has it in `RemovePackages` in `harness-desktop.conf`. Harness is ahead here — no action needed.

### `satty`, `maple-fonts`, `hyfetch`, `btop` in upstream terra.conf — not in harness

- **Upstream** `mkosi.conf.d/terra.conf` Packages: `iio-niri`, `maple-fonts`, `satty`, `valent`, `xdg-terminal-exec-nautilus`, `uupd`
- **Harness** terra.conf: `terra-release`, `terra-release-extras`, `nautilus-open-any-terminal`, `xdg-terminal-exec-nautilus`, `iio-niri`, `valent`, `sunshine`, `moonlight-qt`
- Missing from harness: `maple-fonts`, `satty`
- `maple-fonts` is a developer font with good ligature support; low risk to add.
- `satty` (commit `e4c469d`) is a screenshot annotation tool. Pairs with the upstream `zorc` OCR screenshot script. Relevant if harness users do screenshots.

### `btop` in upstream `theme.conf`; not in harness

- Upstream `theme.conf` line 39: `btop` (commit `41bcf85`).
- Harness ships `htop` equivalents via devtools but not `btop` specifically.

### `nmtui`/`nm-connection-editor`/`lshw` in upstream `theme.conf`; not in harness

- Upstream commit `28143ee` added: `lshw`, `nm-connection-editor`, `nmtui` to `theme.conf`.
- Harness `harness-desktop.conf` does not include these. Framework Desktop users doing network troubleshooting will want `nmtui`.
- **Recommendation**: add `nmtui`, `nm-connection-editor`, `lshw` to `harness-desktop.conf`.

### Upstream removed `bluefin-common` subproject dependency (commit `478b442`)

- Upstream `subprojects.conf` only references `ublue-brew/system_files:/`
- Harness `subprojects.conf` also includes `bluefin-common/system_files/shared/usr/bin/luks-tpm2-autounlock` and `bluefin-common/system_files/shared/usr/share/ublue-os/just`. Upstream dropped `bluefin-common` as a subproject dependency in `478b442`.
- Harness intentionally keeps `luks-tpm2-autounlock` and the `ublue-os/just` recipes — these are load-bearing for the harness workflow and should not be removed. Just note the upstream is moving away from `bluefin-common`.

---

## P3 — cosmetic / skip

- Upstream ASCII art logo in `mkosi.conf` is identical — shared.
- `mkosi.bump` and `mkosi.clean` are byte-identical.
- `iso.toml` differs only in the `ghcr.io/` image path (zirconium vs sodimo/harness) — correct as-is.
- Upstream `iso-nvidia.toml` has no harness equivalent — out of scope (no nvidia variant).
- `mkosi.prepare.chroot`: identical except harness adds google-cloud-cli RPM download and the font pipeline — both harness-only additions, correct.

---

## Package additions to consider

| Package | Source | Rationale | Conflicts? |
|---|---|---|---|
| `uupd` (from terra, drop COPR) | terra | Fewer deps, removes ublue-os COPR dependency | No — replaces existing |
| `satty` | terra | Screenshot annotation; upstream added in `e4c469d` | No |
| `maple-fonts` | terra | Developer font, upstream added alongside satty | No — harness already has a font pipeline; might duplicate |
| `btop` | Fedora | Better TUI resource monitor than htop; upstream added in `41bcf85` | No |
| `nmtui` | Fedora | TUI for NetworkManager; upstream added in `28143ee` | No |
| `nm-connection-editor` | Fedora | GUI NM editor; upstream added in `28143ee` | No |
| `lshw` | Fedora | Hardware lister; upstream added in `28143ee` | No |

---

## Repo config changes

### `terra.repo` — identical

Both repos are byte-for-byte identical. The metalink URL (`tetsudou.fyralabs.com`) and `repo_gpgcheck=0` are the same. No action.

The harness-specific BIB fix lives in `mkosi.postinst.chroot` (the `sed` that sets `enabled_metadata=0` and strips `repo_gpgcheck=1` and `file://` gpgkey lines at image-build time). Upstream has no equivalent; this is correct harness behavior.

### `terra-extras.repo` — identical

Both repos are byte-for-byte identical.

### `avengemedia-danklinux.repo` — minor delta

- **Upstream**: no `excludepkgs` line.
- **Harness** line 11: `excludepkgs=danksearch`
- Harness added this in commit `79c4ed2` to fix a stray package pulled in from the danklinux COPR. Correct — keep.

### `avengemedia-dms-git.repo` (upstream) vs `avengemedia-dms.repo` (harness)

- Upstream uses the `dms-git` COPR (bleeding-edge builds) and installs `dms`, `dms-cli`, `dms-greeter`, `dgop`, `dsearch`, `quickshell-git` from it.
- Harness uses the stable `dms` COPR and installs only `dms` from it. `dms-greeter` and `dgop` come from the separate `danklinux` COPR in harness.
- Upstream's `dms-git` also declares a `coprdep:` entry that adds `danklinux` as a runtime dependency repo.
- **Recommendation**: track-only. Harness intentionally uses stable `dms` COPR. The split between danklinux/dms-git is upstream's packaging detail.

### `negativo17-nvidia.repo` / `nvidia-container-toolkit.repo` — harness does not ship these

Out of scope (no nvidia variant for harness). Skip.

### `cloudflared.repo` — harness-only addition with version pin

Harness pins `cloudflared-2026.3.0-1` via `harness-extra-repos.conf`. Upstream has no cloudflared repo. Correct.

### `tailscale.repo` — harness-only; present but `gpgcheck=0`

`repos/tailscale.repo` has `gpgcheck=0` and `repo_gpgcheck=0`. This is a minor security concern. Consider enabling `gpgcheck=1` with the proper key.

---

## Profile layout notes

### Upstream renamed `base` → `base-desktop` (commit `d18316e`)

- Upstream: `mkosi.conf` `Profiles=base-desktop,fedora-bootc-ostree`; profile at `mkosi.profiles/base-desktop/`.
- Harness: `Profiles=base,bootc-ostree,fedora-bootc-ostree`; profile at `mkosi.profiles/base/`.
- The rename communicates intent (this profile is for desktop targets, not minimal/server builds). For harness, which is always a desktop target, the rename would be accurate but is not functionally required.
- **Recommendation**: adopt if/when rebasing; it is a cosmetic rename with one config line change (`Profiles=base,bootc-ostree,...` → `Profiles=base-desktop,bootc-ostree,...` and renaming the directory). Not urgent.

### Upstream added `nvidia` and `sysupdate` profiles — harness has neither

Both are out of scope. `nvidia` is a separate variant; `sysupdate` is an experimental UKI/sysupdate image format not used in harness.

### Harness carries three profiles (`base`, `bootc-ostree`, `fedora-bootc-ostree`); upstream carries five (`base-desktop`, `bootc-ostree`, `fedora-bootc-ostree`, `nvidia`, `sysupdate`)

For a single-target image, the harness three-profile structure is the correct subset. No consolidation needed.

### `[Output]` split: upstream top-level vs harness in profile

Upstream places `OutputDirectory=mkosi.output`, `ManifestFormat=json`, `Output=%i_%v_%a` in the top-level `mkosi.conf` (since `7963d2f`). Harness puts `OutputDirectory` and `Output` inside `mkosi.profiles/bootc-ostree/mkosi.conf`. This means a plain `mkosi build` without the bootc-ostree profile active will scatter outputs. Adoption of the upstream placement is a correctness fix (P1 above).
