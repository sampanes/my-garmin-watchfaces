# Forerunner 265 Backup and Recovery

This is the recovery contract for the physical Forerunner 265 used by this
repository. The goal is to make Garmin's cloud backup only one layer of the
plan, not the only copy of anything important.

## What "whole-watch backup" means

Windows exposes the watch as an MTP portable device, not as a block disk. We
can preserve every file visible under `Internal Storage`, but we cannot make a
bit-for-bit image of firmware, hidden databases, secure storage, or partitions
that Garmin does not expose.

The practical recovery set has three independent layers:

1. **MTP snapshot:** every visible watch file, empty directory, source size,
   source timestamp, copy status, and local SHA-256.
2. **Rebuild kit:** source control, exact PRGs, app UUIDs, SDK/device profile,
   and the original developer signing key.
3. **Garmin account layer:** the official Device Backup and the Connect IQ
   Store download history.

No one layer is complete by itself.

## Data map

| Data | Where it appears | Recovery status |
|---|---|---|
| Activities and monitoring files | `GARMIN/Activity`, `GARMIN/Monitor`, related FIT directories | Copyable when MTP exposes them; already-synced history also lives in Garmin Connect. |
| Device and activity settings | `GARMIN/Settings/Settings.fit`, sport-profile FIT files | Back up every time. Prefer Garmin's supported Device Backup restore; do not blindly inject FIT files. |
| Firstbeat/long-horizon analytics | `GARMIN/FbtBackup/lha_bkup.fit` on the FR265 | Copyable and valuable, but not a substitute for settings or app backup. |
| Sideloaded Connect IQ programs | `GARMIN/Apps/*.PRG` | Copy the installed PRG and preserve its source, UUID, and signing key. Garmin's cloud does not recreate local development builds. |
| Connect IQ private storage | `GARMIN/Apps/DATA/*.DAT`, `*.IDX`, `*.IMT` | Copy as an exact trio before reinstalling an app. Raw restoration is experimental and must be version/identity matched. |
| Connect IQ settings and diagnostics | `GARMIN/Apps/SETTINGS`, `LOGS`, `MAIL`, and related files | Copyable. Useful for reconstruction and diagnosis; not all files have a documented restore contract. |
| Store-installed Connect IQ content | Device files plus Garmin account download history | Garmin can queue prior downloads from **Not Installed**. Keep an MTP copy anyway. |
| Firmware, hidden databases, secure material | Not exposed by MTP | Not imageable with this workflow. Do not claim otherwise. |

## Make a backup

1. Close Garmin Express, including its tray process. Do not start a firmware
   update, sync, restore, app install, or reset while the snapshot is running.
2. Plug the watch into USB and confirm Windows shows
   `This PC > Forerunner 265 > Internal Storage`.
3. From the repository root, run:

   ```powershell
   .\scripts\backup-garmin-device.ps1
   ```

4. Do not unplug until the script reports a completed and verified backup.
   An incomplete run must remain visibly incomplete; it is evidence, not a
   valid recovery point.
5. Re-verify a backup at any time, especially after moving it:

   ```powershell
   .\scripts\verify-garmin-device-backup.ps1 -BackupPath "<backup-folder>"
   ```

6. Copy the completed backup to encrypted storage on a different physical
   device. The backup can contain location, health, device-identity, sensor,
   and account-adjacent metadata. `bin/` is Git-ignored deliberately; never
   commit a device backup.

Run this before and after firmware updates, before app replacement, after an
important activity has synced, and after any meaningful configuration change.

## Settings record and workouts as code

Every completed backup also writes `settings-inventory.txt` (each decoded
setting as one line) and `settings-diff.txt` (what changed since the previous
backup) into its folder. Strength workouts live as TOML files in
`scripts/watch/workouts/` and are pushed to the watch with
`.\scripts\watch-tools.ps1 push`. See [scripts/watch/README.md](../../scripts/watch/README.md).

The inventory is a record and a rebuild checklist, not a restore source: it is
never written back to the watch.

## Preserve the rebuild kit

An MTP snapshot is not enough for locally developed Connect IQ apps.

- Keep this repository committed and mirrored.
- Keep known-good FR265 PRGs with SHA-256 hashes.
- Preserve the app UUIDs in each `manifest.xml`.
- Back up the Monkey C developer key to encrypted storage outside the repo.
  Losing the key can prevent continuity of an app's signed identity.
- Record the Connect IQ SDK version and FR265 device-profile hash used for a
  release.
- For stateful apps such as Friend, capture `PRG`, `DATA`, `SETTINGS`, and
  `LOGS` together. Do not replace the PRG first and hope the state survives.

## Recovery order

Always preserve the damaged/current state before attempting a restore.

1. **Snapshot first.** Make a new MTP backup, even when the watch looks empty.
2. **Protect unsynced activities.** Confirm whether `GARMIN/Activity` contains
   files not present in Garmin Connect.
3. **Use Garmin's supported restore first.** Inspect the Device Backup before
   pressing Restore. Garmin retains only the latest backup for a device, so a
   post-reset sync may already have replaced the useful copy.
4. **Reinstall Store content.** Use Connect IQ's **Not Installed** list.
5. **Reinstall sideloaded apps from the rebuild kit.** Verify UUID, signing
   key, target (`fr265`), PRG hash/size, and the visible on-watch version.
6. **Handle private app state separately.** Raw `DAT/IDX/IMT` restoration is
   unsupported by Garmin and must never be automatic. Require an exact app
   identity/version match, preserve the new state first, restore all related
   files as one set, and verify on the watch before considering it successful.
7. **Reconstruct remaining preferences manually** from a written inventory or
   screenshots when Garmin's backup did not retain them.

Do not make a general-purpose script that copies an old snapshot back onto the
watch wholesale. The source tree contains output-only files, input queues,
ephemeral files, firmware-managed databases, and paths with no supported
restore semantics.

## Restore drill

A backup is not trustworthy until it has been exercised without risking the
only copy.

- Verify all manifest hashes locally.
- Confirm `GarminDevice.xml` identifies the expected model and hardware unit.
- Confirm expected PRGs and every expected private-storage trio are present.
- Decode important FIT files with Garmin's FIT SDK and verify integrity,
  identity, and file type.
- Test raw Connect IQ state recovery first with a disposable probe app, not
  Friend's only surviving state.
- Record which steps are Garmin-supported, empirically verified, or still
  experimental.

## Official references

- [Garmin Device Backup and Restore](https://support.garmin.com/en-US/?faq=fLogiPl4Vr5p8u0bFNWmK7)
- [Backing up Garmin device data manually](https://support.garmin.com/en-US/?faq=AXV7LuWgc73v21nq6nbDa6)
- [Forerunner 265 backup and restore manual](https://www8.garmin.com/manuals/webhelp/GUID-F41EAFB3-6CC9-42DE-9C6C-9E358DBB0671/EN-US/GUID-84E6578A-579D-464C-BF8A-8FB3BFC458B9.html)
- [Reinstalling Connect IQ downloads](https://support.garmin.com/en-US/?faq=nfeK0ZgFWu5WGHBTcKCNS9)

