# Skybreak for Windows (x86_64)

Built from `main` at `9e645967` (everything before, camera round 3, WEB-CACHE, aura v2 and Duo online,
plus **Pure Fight**: 2.5D hand-to-hand 1v1 vs AI, local 2P on one keyboard, training, and online 1v1
through the Duo lobby; and the issue sweep fixes: FFA-4 spawns, the dash afterimage, fighters no longer
drawn inside each other) with the official Godot 4.7.2 Windows release template (export templates
SHA-512 checked against `SHA512-SUMS.txt`), `Windows Desktop` preset. The game data (including
the high, medium and low voxel zone bakes) is embedded in `Skybreak.exe`.

The zip is 726,800,985 bytes, more than GitHub's 100 MB file limit, so it is split into 8 parts
(`split -b 90m`).

## Join and play

1. Download every `Skybreak-windows-x86_64.zip.partNN` file into one folder.
2. In that folder, open Command Prompt (`cmd`, not PowerShell) and run:

   ```bat
   copy /b Skybreak-windows-x86_64.zip.part00+Skybreak-windows-x86_64.zip.part01+Skybreak-windows-x86_64.zip.part02+Skybreak-windows-x86_64.zip.part03+Skybreak-windows-x86_64.zip.part04+Skybreak-windows-x86_64.zip.part05+Skybreak-windows-x86_64.zip.part06+Skybreak-windows-x86_64.zip.part07 Skybreak-windows-x86_64.zip
   ```

3. Optional check (PowerShell): `Get-FileHash Skybreak-windows-x86_64.zip` must print
   `3E4BA1511CCAEA0D838F05492B8F315CC1F65EEAC0A63B794C5A3E99C9F562A3`.
4. Extract the zip and run `Skybreak\Skybreak.exe` (keep the `.dll` next to it).

Not boot-tested on Windows (no Windows machine in the cloud). The same commit's web export ran a
Vs AI match for 30 s with no console errors; full GUT 0 failing; see `reports/builds/2026-11-22-9e645967.md`
on `main`.
