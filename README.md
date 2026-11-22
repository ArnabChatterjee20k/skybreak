# Skybreak for Windows (x86_64)

Built from `main` at `61925008` (PR #149 camera round 3: the locked opponent stays on screen
through specials, a voxel floor-aware camera; on top of #141 specials and the voxel art) with the official Godot 4.7.2 Windows release template (export templates
SHA-512 checked against `SHA512-SUMS.txt`), `Windows Desktop` preset. The game data (including
the high, medium and low voxel zone bakes) is embedded in `Skybreak.exe`.

The zip is 722,251,866 bytes, more than GitHub's 100 MB file limit, so it is split into 8 parts
(`split -b 90m`).

## Join and play

1. Download every `Skybreak-windows-x86_64.zip.partNN` file into one folder.
2. In that folder, open Command Prompt (`cmd`, not PowerShell) and run:

   ```bat
   copy /b Skybreak-windows-x86_64.zip.part00+Skybreak-windows-x86_64.zip.part01+Skybreak-windows-x86_64.zip.part02+Skybreak-windows-x86_64.zip.part03+Skybreak-windows-x86_64.zip.part04+Skybreak-windows-x86_64.zip.part05+Skybreak-windows-x86_64.zip.part06+Skybreak-windows-x86_64.zip.part07 Skybreak-windows-x86_64.zip
   ```

3. Optional check (PowerShell): `Get-FileHash Skybreak-windows-x86_64.zip` must print
   `CE8F31B3435B693EDBE9637A835284AF8234088E1BFDBB36955537F8D08EEFFC`.
4. Extract the zip and run `Skybreak\Skybreak.exe` (keep the `.dll` next to it).

Not boot-tested on Windows (no Windows machine in the cloud). The same commit's web export ran a
Vs AI match for 30 s with no console errors; full GUT 0 failing; see `reports/camera/round3/README.md`
on `main`.
