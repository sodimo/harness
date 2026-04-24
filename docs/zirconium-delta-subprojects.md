# Zirconium subprojects/justfile/services Deltas for sodimo/harness

## Summary

Upstream zirconium removed `bluefin-common` as a submodule in commit `478b442` (Apr 22 2026), inlining `luks-tpm2-autounlock` directly into `mkosi.extra/usr/bin/` and expanding `00-start.just` to ~225 lines with many new `zjust` targets; our fork still depends on the submodule and references both files from it. Our `.gitmodules` carries three entries (`ublue-brew`, `bluefin-common`, `dotfiles`), while upstream is down to one (`ublue-brew`), plus `assets` and `zdots` which we dropped. The CI submodule init pattern diverges: upstream uses `submodules: true` in the `actions/checkout` step, whereas harness does a manual `git submodule update --init --depth=1` which is non-recursive by design. Upstream also has a `sysupdate` mkosi profile (systemd-sysupdate particleOS style, not bootc) that we do not carry; it is not relevant to the sodimo bootc-pull flow. Our `00-start.just` is three stubs, missing the full `zjust` orchestration present upstream.

---

## P0 — CI-breaking / security

**`subprojects/bluefin-common` still required by `mkosi.conf.d/subprojects.conf` but submodule is never populated in CI.**

`mkosi.conf.d/subprojects.conf` has two `ExtraTrees` lines referencing:
- `subprojects/bluefin-common/system_files/shared/usr/bin/luks-tpm2-autounlock:/usr/bin`
- `subprojects/bluefin-common/system_files/shared/usr/share/ublue-os/just:/usr/share/ublue-os/just`

`mkosi.postinst.chroot` validates with `stat /usr/bin/luks*tpm*` and `stat /usr/share/ublue-os/just/update.just` at build time. If the submodule is empty (which it will be when CI does `--init --depth=1` without ensuring the submodule is actually initialized and populated), the build will fail at mkosi `ExtraTrees` stage or at the `stat` validation. The submodule directory exists on disk locally (populated) but this is a CI landmine.

---

## P1 — Correctness

**`just build` missing `--profile=bootc-ostree` flag.**

Upstream: `build-ostree: mkosi -B --debug --profile=bootc-ostree`  
Harness: `build: mkosi -B --debug` (no profile)

The upstream Justfile separates `build` (calls `build-ostree`) from `build-sysupdate`. Harness dropped the profile flag, relying on mkosi's default profile selection. This works as long as `mkosi.conf` defaults to `bootc-ostree`, but it's fragile. The `load` target in harness searches `mkosi.profiles/bootc-ostree/mkosi.output/*` which implies the profile is still expected — a mismatch if mkosi selects differently.

**`just disk-image` missing `--generic-image --bootloader grub` flags.**

Upstream: `just bootc install to-disk --generic-image --bootloader grub --via-loopback ...`  
Harness: `just bootc install to-disk --via-loopback ...`

The `--generic-image` flag causes bootc to omit host-specific configuration (kargs, hostname) from the installed image. Missing it means the test disk image picks up the CI runner's configuration. The `--bootloader grub` flag is similarly meaningful for generic image production.

**Filesystem default is `ext4` in harness, `btrfs` upstream.**

Harness `Justfile` line 2: `filesystem := env("BUILD_FILESYSTEM", "ext4")`. Upstream uses `btrfs`. The harness mkosi.conf bootc-ostree profile also recently had an `083dd8e` commit dropping xfs in favor of btrfs. The Justfile default was not updated in that commit — it still says `ext4`. This means `just disk-image` produces an ext4 image while the mkosi profile itself targets btrfs.

---

## P2 — Architectural

**`00-start.just` is near-empty stub; upstream has full `zjust` orchestration.**

Upstream `00-start.just` is ~225 lines with: `update-dotfiles`, `_zdots-reset`, `reset-all-configs`, `toggle-user-motd`, `toggle-autorotation`, `toggle-automatic-dotfiles`, `toggle-fcitx5`, `preinstalled-flatpaks`, `reset-niri`, `update-greeter`, `toggle-updates`, `toggle-tpm2`, `check-local-overrides`, `generate-bug-report`.

Harness `00-start.just` is 9 lines: `toggle-autorotation` (one-liner), `toggle-fcitx5` (one-liner), `preinstalled-flatpaks` (one-liner). All the dotfiles management, TPM2, update-toggle, and bug-report targets are absent. If `zjust` is on the PATH and users invoke it, they get three stubs.

**`subprojects/dotfiles` is in `.gitmodules` but `subprojects/bluefin-common` should not be.**

Our `.gitmodules` has three entries: `ublue-brew`, `bluefin-common`, `dotfiles`. Upstream is down to `ublue-brew` only (plus `assets`/`zdots` which are in a different path). Harness should eventually mirror this by: inlining `luks-tpm2-autounlock` into `mkosi.extra/usr/bin/` (upstream already did), removing the `ublue-os/just` dependency (or copying `update.just` inline), and removing the `bluefin-common` submodule + `.gitmodules` entry.

---

## P3 — Cosmetic / skip

- `artifacthub-repo.yml` and `.editorconfig` removed upstream in `478b442`; we don't appear to have them.
- `zmotd` script updated upstream to add `bootc upgrade` info; we carry our own branding path.
- `chore(deps)` auto-update commits for `ublue-brew` (`378200e`) — harness `.gitmodules` points at the same `ublue-brew` URL; dependabot should handle pin updates.

---

## bluefin-common removal (#241) — detailed analysis

### What upstream inlined

From commit `478b442`, upstream:
1. Copied `luks-tpm2-autounlock` from `bluefin-common/system_files/shared/usr/bin/` into `mkosi.extra/usr/bin/luks-tpm2-autounlock` directly.
2. Removed the two `ExtraTrees` lines from `mkosi.conf.d/subprojects.conf` that pulled from `bluefin-common`.
3. Expanded `mkosi.extra/usr/share/zirconium/just/00-start.just` with the `toggle-tpm2` target calling `/usr/bin/luks-tpm2-autounlock` and many other targets that were previously sourced from `ublue-os/just` (from `bluefin-common`).
4. Deleted the `.gitmodules` entry and the `subprojects/bluefin-common` directory pointer.

### What they dropped

The `ublue-os/just` files from `bluefin-common` (e.g. `update.just`) are no longer shipped. Any functionality those provided is either inlined into `00-start.just` or intentionally dropped.

### State in harness

Harness `mkosi.conf.d/subprojects.conf` still has both `ExtraTrees` lines. The `.gitmodules` still has the `bluefin-common` entry pointing at `https://github.com/projectbluefin/common`. The `mkosi.postinst.chroot` still validates `stat /usr/share/ublue-os/just/update.just`.

**To remove bluefin-common from harness:**
1. Copy `luks-tpm2-autounlock` from the bluefin-common submodule into `mkosi.extra/usr/bin/`.
2. Either copy `update.just` (or a sodimo equivalent) into `mkosi.extra/usr/share/harness/just/` and update the `stat` path in `mkosi.postinst.chroot`, or drop the validation entirely if `uupd` covers the update path.
3. Remove the two `ExtraTrees` lines from `mkosi.conf.d/subprojects.conf`.
4. Remove `[submodule "subprojects/bluefin-common"]` from `.gitmodules`.
5. Run `git rm -r --cached subprojects/bluefin-common && git rm subprojects/bluefin-common`.

Nothing else in the harness tree references `bluefin-common` beyond those three files.

---

## Submodule init pattern

### Upstream (zirconium)
```yaml
- uses: actions/checkout@...
  with:
    submodules: true
```
`submodules: true` runs `git submodule update --init --recursive` by default. Upstream only has `ublue-brew` (plus `assets`, `zdots`), none of which have nested submodules, so recursive is safe.

### Harness
```yaml
- uses: actions/checkout@...
- run: git submodule update --init --depth=1
```
Harness explicitly does **non-recursive** `--init --depth=1`. This is intentional: `subprojects/dotfiles` is the `sodimo/dotfiles` repo, which the memory confirms should remain app-layer only and not be recursively initialized into the image build.

### Nested-submodule warning analysis

The CI warning `fatal: No url found for submodule path 'subprojects/dotfiles/dmsFULLlatest/plugins/.repos/0026f1eba8dedaec'` refers to a path that does not exist in the current `subprojects/dotfiles` checkout (which is at commit `e400703`). This warning almost certainly originated in a prior mecattaf/harness state where `dotfiles` pointed at a different repo that had DMS (DankMaterialShell) as a nested git submodule with plugin repos. The current `sodimo/dotfiles` submodule has no `.gitmodules` file, so recursive init produces no output and no warning. If the warning reappears, it means the `subprojects/dotfiles` submodule pointer drifted back to a mecattaf ref — verify with `git -C subprojects/dotfiles log --oneline -1` and check the remote URL in `.gitmodules` is still `https://github.com/sodimo/dotfiles`.

The harness non-recursive `--depth=1` pattern is correct and should be kept.

---

## sysupdate — applicability to sodimo flow

Upstream `eae9e61` adds a `sysupdate` mkosi profile implementing systemd-sysupdate (particleOS style): separate `usr`, `usr-verity`, `usr-verity-sig`, and UKI partition transfer files. It uses `SplitArtifacts=uki,partitions`, `Format=disk`, verity signing, and SecureBoot. This is a **completely different update mechanism** from bootc.

**sodimo/harness uses bootc.** The secondary Framework boxes pull `ghcr.io/sodimo/harness:latest` via `bootc upgrade`. This already provides in-place image updates with A/B staging and rollback — which is the core value proposition of sysupdate for upstream.

**Recommendation: do not port the sysupdate profile.** The complexity cost is high (partition layout, verity signing pipeline, TPM PCR binding for the UKI profiles), the benefit is zero given bootc already provides atomic image updates with rollback. The only scenario where sysupdate would add value is if sodimo wanted to distribute signed OCI-independent disk updates without a container registry — which contradicts the `ghcr.io` pull model. Skip.

---

## Justfile delta

| Target | Upstream (zirconium) | Harness |
|--------|----------------------|---------|
| `image` default | `localhost/zirconium:latest` | `localhost/harness:latest` |
| `filesystem` default | `btrfs` | `ext4` (stale — should be `btrfs`) |
| `build` | calls `build-ostree` sub-target | direct `mkosi -B --debug` (no profile) |
| `build-ostree` | `mkosi -B --debug --profile=bootc-ostree` | absent |
| `build-sysupdate` | `mkosi -B --debug --profile=sysupdate` | absent (correct) |
| `load` | searches `mkosi.output/*` | searches `mkosi.profiles/bootc-ostree/mkosi.output/*` |
| `disk-image` | `--generic-image --bootloader grub --via-loopback` | `--via-loopback` only (missing flags) |
| `ostree-rechunk` | identical | identical |
| `bootc` | identical | identical |
| `rechunk` | identical | identical |
| `clean` | identical | identical |

**No zjust includes.** Neither repo has a `justfile.d/` directory or `import` directives. The zjust mechanism is the binary `zjust` (a just wrapper that searches `XDG_DATA_DIRS` for `*.just` files), not a Justfile include. The `00-start.just` files are picked up at runtime by `zjust`, not at build-time by `just --import`.

**Missing from harness `Justfile`:** `build-ostree` (just a rename/split, but the profile flag is the critical part).

---

## distrobox implementation comparison

| Aspect | Upstream (zirconium) | Harness |
|--------|----------------------|---------|
| Package source | `theme.conf` packages list: `distrobox` | `harness-devtools.conf` packages list: `distrobox` + `toolbox` |
| Re-add commit | `44f4d0e fix: re-add distrobox` | `f2b193f feat: add toolbox and distrobox explicitly` |
| Location in conf | `mkosi.conf.d/theme.conf` (single conf) | `mkosi.conf.d/harness-devtools.conf` (separate devtools conf) |
| Extra additions | none | `toolbox`, `podman-compose`, `podman-tui`, `podmansh`, `ramalama`, `whisper-cpp`, Python AI stack |

Both sides independently added back distrobox after it was apparently removed upstream. The harness implementation is more deliberate: it lives in a dedicated `harness-devtools.conf` alongside a broad ML/AI tooling set. Upstream's re-add was a simple single-package fix. The sodimo split (devtools conf separate from base conf) is the better architecture for a headless secondaries scenario — toolbox/distrobox can be omitted for minimal images by dropping the devtools conf include.

No conflict between the two implementations. Harness is a strict superset.
