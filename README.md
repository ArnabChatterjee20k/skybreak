# Skybreak for Windows (x86_64)

Built from `main` at `3b86467c` (everything in the 9e645967 build: camera round 3, WEB-CACHE, aura v2,
Duo online, Pure Fight and the issue sweep fixes; plus the **#150 move escape**: dodges, sidesteps and side
vanish get you out of, or round, the opponent's strings; every afterimage a pose ghost (#127); and the camera
keeping both fighters framed when an escape leaves your back to a wall) with the official Godot 4.7.2 Windows release template (export templates
SHA-512 checked against `SHA512-SUMS.txt`), `Windows Desktop` preset. The game data (including
the high, medium and low voxel zone bakes) is embedded in `Skybreak.exe`.

The zip is 726,344,211 bytes, more than GitHub's 100 MB file limit, so it is split into 8 parts
(`split -b 90m`).

## Join and play

1. Download every `Skybreak-windows-x86_64.zip.partNN` file into one folder.
2. In that folder, open Command Prompt (`cmd`, not PowerShell) and run:

   ```bat
   copy /b Skybreak-windows-x86_64.zip.part00+Skybreak-windows-x86_64.zip.part01+Skybreak-windows-x86_64.zip.part02+Skybreak-windows-x86_64.zip.part03+Skybreak-windows-x86_64.zip.part04+Skybreak-windows-x86_64.zip.part05+Skybreak-windows-x86_64.zip.part06+Skybreak-windows-x86_64.zip.part07 Skybreak-windows-x86_64.zip
   ```

3. Optional check (PowerShell): `Get-FileHash Skybreak-windows-x86_64.zip` must print
   `1A48D991ED8255CA716C72646B135FE641AD4FB14C30DD63044BF490BB019EFC`.
4. Extract the zip and run `Skybreak\Skybreak.exe` (keep the `.dll` next to it).

Not boot-tested on Windows (no Windows machine in the cloud). The same commit's web export ran a
Vs AI match for 30 s with no console errors; full GUT 0 failing; see `reports/builds/2026-11-23-3b86467c.md`
on `main`.
