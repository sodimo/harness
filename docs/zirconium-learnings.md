# Zirconium learnings for sodimo/harness

**Date:** 2026-04-24
**Method:** 4-agent parallel delta analysis (`zirconium-delta-{workflows,mkosi,system-files,subprojects}.md` hold the raw per-domain reports; this file is the consolidated decision list).
**Scope principle:** zirconium is a *reference*, not a target. We take learnings; we do NOT adopt zjust, z-branded scripts, or cosmetic-only diffs. Each decision below is atomic so you can revert any single change without affecting the others.

---

## 0. Divergence shape (for context)

- `zirconium-dev/zirconium` and `mecattaf/harness` share NO git history — mecattaf was seeded by a file-copy of zirconium at some early point, then went independent. There is no merge-base to rebase against; we can only cherry-pick learnings.
- `mecattaf/harness` ↔ `sodimo/harness` DO share history; merge-base is `cfa4528` (the wallpaper PR merge). Since that point:
  - sodimo added 17 commits (DMS swap, sunshine/moonlight, Strix Halo kargs, cloudflared pin, btrfs alignment, chezmoi rewire, dotfiles → sodimo org, iso fixes, tests dir).
  - mecattaf added only 4 commits (btrfs alignment + distrobox — both independently duplicated on sodimo — plus an openssh-askpass add/revert that mecattaf kept). Mecattaf is effectively frozen.
- Upstream zirconium kept moving: since the point where we diverged it has shipped `bluefin-common` removal, `/etc` → `/usr/share/factory` + tmpfiles refactor, sysupdate image, `uupd` terra migration, CI reusable-workflow split, many small correctness fixes.

---

## 1. Already applied autonomously (pre-consolidation)

### D-00a — Emergency: commented out `sunshine` + `moonlight-qt` in `mkosi.conf.d/terra.conf`
- **What:** the two packages are commented out with a TODO block. This is a non-zirconium fix — commit `d510e22` added them to `terra.conf` assuming they lived in terra44; they don't. They're in the `lizardbyte/beta` COPR. That single bad assumption has been the primary cause of CI red since 2026-04-22 (all the terra metalink / submodule failures we hit were downstream side-effects of this same step failing).
- **Why:** without this the `Build image` step fails at `dnf5 ... install sunshine` with `No match for argument: sunshine`. Getting CI green today is P0.
- **Revert:** re-enable both package lines (CI will break again unless LizardByte COPR is wired in). To wire LizardByte properly:
  1. Add `repos/lizardbyte-beta.repo` pointing at `https://copr.fedorainfracloud.org/coprs/lizardbyte/beta/repo/fedora-$releasever/`.
  2. Add `mkosi.conf.d/lizardbyte.conf` with `[Build] SandboxTrees=...` and `[Distribution] Repositories=copr:...:lizardbyte:beta`.
  3. Uncomment the two package lines here.
- **Status:** Applied in commit `33736b6`.

### D-00 — Flipped `sodimo/dotfiles` from private to public
- **What:** `gh api -X PATCH repos/sodimo/dotfiles -F private=false`
- **Why:** CI run #24903824501 failed at `git submodule update --init` because the workflow's GITHUB_TOKEN has no cross-repo read on private `sodimo/dotfiles`. You approved the flip in chat.
- **Revert:** `gh api -X PATCH repos/sodimo/dotfiles -F private=true`. Then re-add a deploy-key or PAT-based ssh-agent step in the workflow (see `24bd89a` commit message, tracked on `sodimo/dotfiles#13`).
- **Status:** Applied. Rebuild #24904223206 is proceeding past the old blocker.

---

## 2. Decisions to apply now (P0) — apply in order, each a separate commit

### D-01 — SELinux `store-root=/etc/selinux` fix (zirconium #228 / `49f56df`)
- **What:** Add one line to `mkosi.profiles/fedora-bootc-ostree/mkosi.postinst.chroot` immediately before the `cp -r /var/lib/selinux/targeted/active /etc/selinux/targeted/` block:
  ```bash
  printf "\n%s\n" "store-root=/etc/selinux" | tee -a /etc/selinux/semanage.conf
  ```
- **Why:** Without it, `semanage`/`semodule` read from `/var/lib/selinux` at runtime. On bootc, `/var/` can be reset across upgrades, so custom SELinux policy for cloudflared/sunshine would stop applying silently. Tiny, obvious, upstream already fixed it.
- **Scope:** one file, one line.
- **Revert:** remove the line.

### D-02 — Cache-poisoning gate (zirconium `9a148ea`)
- **What:** In `.github/workflows/build.yml`, add `if: github.event_name != 'pull_request'` to the `Setup mkosi cache` step (line ~56).
- **Why:** Today the cache is read/written on PR runs. A PR from any branch (or a fork if we ever open the repo to PRs) could poison the main-branch build cache. Upstream gates cache on `inputs.publish`.
- **Scope:** one workflow line.
- **Revert:** delete the `if:` line.

### D-03 — `mkosi cat-config --debug` render step (zirconium `5f61f2e`)
- **What:** Add a step between "Install mkosi" and "Build image" in `build.yml`:
  ```yaml
  - name: Render mkosi config (debug)
    run: sudo mkosi cat-config --debug
  ```
- **Why:** When Terra44 or any repo-resolution flaked (our run #24710754732), we lost visibility into exactly which metalink URLs and packages mkosi resolved. Zero-risk one-liner, immediately actionable next time CI flakes.
- **Scope:** workflow addition.
- **Revert:** delete step.

### D-04 — Build step hardening (zirconium `1e1c6d6`)
- **What:** In `build.yml` "Build image" step: add `set -e`, `--debug`, and `--profile=bootc-ostree`.
  ```yaml
  - name: Build image
    run: |
      set -e
      sudo env IMAGE_FULL="localhost/${IMAGE_NAME}:${DEFAULT_TAG}" mkosi -B -ff --debug --profile=bootc-ostree
  ```
- **Why:** `set -e` makes subcommand failure fail the step (today it doesn't). `--debug` gives us mkosi's full output. `--profile=bootc-ostree` removes reliance on implicit profile selection (harness Justfile's `load` target already expects bootc-ostree output paths).
- **Scope:** workflow build step.
- **Revert:** drop the three additions.

### D-05 — Justfile filesystem default: `ext4` → `btrfs`
- **What:** Line 2 of `Justfile`:
  ```justfile
  filesystem := env("BUILD_FILESYSTEM", "btrfs")
  ```
- **Why:** Our commit `083dd8e` aligned the bootc profile on btrfs. The Justfile default was missed in that pass — `just disk-image` still produces an ext4 disk that won't match how bootc lays it down. Upstream is already `btrfs`.
- **Scope:** one Justfile line.
- **Revert:** change back to `"ext4"`.

---

## 3. Decisions to apply soon (P1) — lower urgency, still clean wins

### D-06 — `nmtui`, `nm-connection-editor`, `lshw` (zirconium `#231 / 28143ee`)
- **What:** Add the three packages to `mkosi.conf.d/harness-desktop.conf`.
- **Why:** Headless Framework Desktop users troubleshooting the direct ethernet link to the NAS or a wifi issue need `nmtui` over SSH. `lshw` is the only sensible cross-check for the Strix Halo platform details. ~4 MB total.
- **Scope:** one conf file, three lines.
- **Revert:** delete the three packages.

### D-07 — `WithRecommends=True` removal (zirconium `d18316e` part)
- **What:** Remove the `WithRecommends=True` line from `mkosi.profiles/base/mkosi.conf.d/base-desktop.conf` (line ~6).
- **Why:** Upstream dropped this in the base-desktop rename commit. It pulls unpredictable recommended-package chains, inflating image size. `WithRecommends=True` in a bootc image is generally regretted.
- **Scope:** one line.
- **Revert:** re-add the line (sodimo's current behavior).
- **Risk flag:** worth a spot-check after image rebuild — some package might have been silently pulled via recommends that the system actually needed. Inspect `rpm-ostree status -v` diff post-change.

### D-08 — `[Output]` block at top-level `mkosi.conf` (zirconium `7963d2f`)
- **What:** Add to top-level `mkosi.conf`:
  ```ini
  [Output]
  OutputDirectory=mkosi.output
  ManifestFormat=json
  Output=%i_%v_%a
  ```
  Then delete the duplicate `OutputDirectory`/`Output` lines from `mkosi.profiles/bootc-ostree/mkosi.conf`.
- **Why:** Placing these at the top level means `mkosi build` with any profile writes to the same output dir, which simplifies CI and local debugging.
- **Scope:** two files.
- **Revert:** reverse both edits.

### D-09 — Drop the `ublue-os-packages` COPR; pull `uupd` from terra (zirconium `#238 / 29ce365`)
- **What:**
  - Delete `mkosi.conf.d/ublue-os-packages.conf`.
  - Delete `repos/ublue-os-packages.repo`.
  - Add `uupd` to the Packages list in `mkosi.conf.d/terra.conf`.
- **Why:** One less COPR to depend on. `ublue-os/packages` COPR has been flaky historically and `uupd` is now maintained in terra. Aligns with the zirconium direction and reduces our COPR surface.
- **Scope:** 2 file deletions, 1 Packages line addition.
- **Revert:** restore both files and remove `uupd` from terra.conf.

### D-10 — `actions/checkout` submodules pattern
- **What:** In `build.yml`, replace the current two-step (`Checkout` + `Init submodules (non-recursive)`) with:
  ```yaml
  - name: Checkout
    uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6
    with:
      submodules: true
      fetch-depth: 1
  ```
- **Why:** Simpler, idiomatic, and removes the manual `git submodule update` step that was the source of both our recent CI failures (nested-submodule ghost warning + the dotfiles auth issue). With sodimo/dotfiles now public this is the cleanest pattern.
- **Scope:** workflow.
- **Revert:** restore the two-step form.
- **Risk flag:** if anyone makes sodimo/dotfiles private again, this breaks. The D-00 revert note above tells you what to do in that case.

---

## 4. Decisions to apply when convenient (P2) — nice, not urgent

### D-11 — DMS satty screenshot-editor override (zirconium `05a51f3`)
- **What:** Ship `mkosi.extra/usr/lib/systemd/user/dms.service.d/override.conf`:
  ```ini
  [Service]
  Environment=DMS_SCREENSHOT_EDITOR=satty
  ```
  Add `satty` to `mkosi.conf.d/terra.conf` Packages.
- **Why:** You use the kiosk via Sunshine/Moonlight remote display; if users take screenshots from the remote session, satty gives them annotation. DMS otherwise warns about the missing editor config.
- **Scope:** one new unit override + one package.
- **Revert:** delete both.

### D-12 — Weekly scheduled build (zirconium `build-standard.yaml`)
- **What:** In `build.yml`, change cron from `"05 10 * * *"` (daily) to `"0 1 * * TUE"` (Tuesday 01:00 UTC).
- **Why:** Daily builds produce a lot of ghcr tags and burn runner minutes. The harness image changes infrequently. Upstream is weekly.
- **Scope:** one cron line.
- **Revert:** restore daily cron.

### D-13 — `bluefin-common` submodule removal (zirconium `#241 / 478b442`)
- **What:**
  1. Copy `subprojects/bluefin-common/system_files/shared/usr/bin/luks-tpm2-autounlock` into `mkosi.extra/usr/bin/`.
  2. Decide whether `/usr/share/ublue-os/just/update.just` is still load-bearing. If not (given we drop zjust), also drop it from `mkosi.postinst.chroot` `stat` validation.
  3. Remove the two `ExtraTrees` lines from `mkosi.conf.d/subprojects.conf`.
  4. Remove the `[submodule "subprojects/bluefin-common"]` stanza from `.gitmodules`.
  5. `git rm -r --cached subprojects/bluefin-common && git rm subprojects/bluefin-common`.
- **Why:** Upstream is off it; we only ever used two files from it; it's a transitive dependency on projectbluefin that we don't need. Also aligns with the bootc scope-split memory (fewer submodules = fewer CI surprises).
- **Scope:** multi-file, spread across two commits (one for the inline-copy, one for the submodule removal).
- **Revert:** restore the submodule stanza + `ExtraTrees` lines + `git submodule add`.
- **Risk flag:** do this AFTER D-00..D-10 have baked — it touches submodules again and we just stabilized that surface.

### D-14 — `/etc` → `/usr/share/factory/etc` + tmpfiles refactor (zirconium `ec2a120`)
- **What:** Move files from `mkosi.extra/etc/` into `mkosi.extra/usr/share/factory/etc/` (same relative paths) and materialize them at boot via a new `mkosi.extra/usr/lib/tmpfiles.d/99-harness-factory.conf` with `L+` / `L` rules.
- **Why:** bootc's `/etc` is a 3-way overlay merge on upgrade. Files placed directly in the image's `/etc` can be surprising on upgrade — especially `containers/policy.json`, `firewalld/zones/*.xml`, and `sysctl.d/*` drop-ins. Upstream fully migrated. Benefits: no merge conflicts on upgrade for the migrated files; canonical content lives read-only under `/usr/`.
- **Exceptions — keep in `/etc/` directly:**
  - `etc/NetworkManager/system-connections/router-link.nmconnection` — NM writes runtime state back here; a symlink into `/usr/` is read-only and NM will refuse.
  - `etc/pam.d/greetd-greeter` — some PAM implementations reject symlinks; test explicitly before migrating.
- **Scope:** large (migrate ~14 files, add tmpfiles.d config, validate with `systemd-tmpfiles --create --prefix=/etc` in a test image).
- **Revert:** move files back and delete the tmpfiles.d file.
- **Risk flag:** this is the single biggest architectural delta. Do AFTER everything else stabilizes, and in its own branch with a careful test.

---

## 5. Tracked but not now (P3) — deferred or skipped deliberately

### D-15 — `satty`, `maple-fonts`, `btop` packages
- **Status:** `satty` is covered by D-11 above. `maple-fonts` — skip; we already have a font pipeline. `btop` — skip unless you want it; cosmetic.

### D-16 — `extractions/setup-just` v3 → v4 pin bump
- **Status:** cosmetic; dependabot can handle this in a future sweep.

### D-17 — `sigstore/cosign-installer` v4.1.0 → v4.1.1
- **Status:** cosmetic; dependabot.

### D-18 — `merge_group:` trigger
- **Status:** add only if you enable merge queues on sodimo/harness. Harmless, not useful today.

### D-19 — Profile rename `base` → `base-desktop`
- **Status:** purely cosmetic; the rename makes the profile name self-describing but costs one directory rename + one `Profiles=` line. Skip unless we rebase from upstream.

### D-20 — Reusable workflow split (`reusable-build-bootc.yaml`)
- **Status:** zirconium built this to support multiple variants (nvidia, rawhide, sysupdate). We only ship one variant (harness:latest). Structural cost > value until we add a second profile.

### D-21 — `rechunk` via `just ostree-rechunk` vs `ublue-os/legacy-rechunk` action
- **Status:** the action is pinned and works; name has "legacy" in it but the action itself is stable. Switch only if the action is deprecated or if you want to unify with upstream's Justfile flow.

### D-22 — Brew-installed podman
- **Status:** only needed if we switch to podman push. We currently use skopeo copy. Skip.

---

## 6. Not adopted — upstream has, we explicitly do NOT want

Per your explicit guidance: skip zjust, z-branded scripts, and pure aesthetics.

- **`zjust` binary + its entire `00-start.just` orchestration** (~225 lines): we keep our three-stub `00-start.just`. Zjust is a runtime toggle layer we don't need; sodimo is a static-at-handoff black box.
- **`zfetch`, `zmotd`, `zocr`, `glorpfetch`**: all z-branded motd/fetch/OCR convenience scripts. Not relevant to headless kiosk.
- **`taidan.toml` first-boot wizard config**: we don't use taidan.
- **`chezmoi-update.service` + `.timer`**: your commit `24bd89a` deliberately dropped the runtime-pull path; dotfiles are baked in from `/usr/share/harness/dotfiles`. Don't re-port.
- **`sysupdate` mkosi profile**: systemd-sysupdate is a completely different update mechanism (UKI + signed partitions). Our `bootc upgrade` pull-from-ghcr flow already provides atomic A/B updates with rollback. Complexity cost >> benefit.
- **`nvidia` profile + `negativo17-nvidia.repo` + `nvidia-container-toolkit.repo`**: no NVIDIA on any harness target.
- **`assets/` directory**: upstream branding assets; we have `mkosi.extra/usr/share/backgrounds/` for our wallpaper.
- **OpenRGB udev rules**: no RGB hardware.
- **DMS `--cache-dir` fix + `dms-greeter` sysusers/tmpfiles**: the kiosk auto-logs in as `tom` via greetd without the DMS greeter; port only if we ever switch `greetd config.toml` back to using `dms-greeter` as `user = "greeter"`.

---

## 7. Observations worth keeping in mind

- **`tailscale.repo` has `gpgcheck=0` and `repo_gpgcheck=0`** in our tree. Minor security concern. Not on the upstream-delta list because upstream doesn't ship tailscale either, but flagging for your review.
- **`rechunker-group-fix.service` is explicitly `systemctl enable`d in `mkosi.profiles/bootc-ostree/mkosi.postinst.chroot` line 23** while also shipping a preset. Verify the preset already enables it — if so, the explicit enable is redundant.
- **`subprojects/dotfiles` submodule pin** is at `e400703`. Anytime you update sodimo/dotfiles and want the new pin in the image, `cd subprojects/dotfiles && git pull && cd - && git add subprojects/dotfiles && git commit`.

---

## 8. Suggested commit order

```
(1) D-01  selinux: write store-root=/etc/selinux in semanage.conf at image build
(2) D-02  ci: skip mkosi cache read/write on PR runs
(3) D-03  ci: render mkosi config with --debug before build
(4) D-04  ci: set -e + --debug + --profile=bootc-ostree in build step
(5) D-05  just: default BUILD_FILESYSTEM to btrfs (align with 083dd8e)
(6) D-06  pkg: add nmtui, nm-connection-editor, lshw for NM troubleshooting
(7) D-07  mkosi: drop WithRecommends=True from base profile
(8) D-08  mkosi: lift [Output] block to top-level mkosi.conf
(9) D-09  pkg: pull uupd from terra, drop ublue-os-packages COPR
(10) D-10 ci: actions/checkout submodules:true; drop manual init step
(11) D-11 dms: satty screenshot-editor override + satty package (optional)
(12) D-12 ci: weekly build cron (optional)
(13) D-13 subprojects: inline luks-tpm2-autounlock, drop bluefin-common submodule
(14) D-14 factory: /etc → /usr/share/factory/etc + tmpfiles.d refactor
```

Each is a standalone commit you can drop or revert.
