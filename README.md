# Skybreak for Windows (x86_64)

Built from `main` at `46da3b2062e6fc94c513882c546ba127a20a0c74` (voxel art merge, PR #148, plus the
visual-golden refresh) with the official Godot 4.7.2 Windows release template (export templates
SHA-512 checked against `SHA512-SUMS.txt`), `Windows Desktop` preset. The game data (including
the high, medium and low voxel zone bakes) is embedded in `Skybreak.exe`.

The zip is 724,862,052 bytes, more than GitHub's 100 MB file limit, so it is split into 8 parts
(`split -b 90m`).

## Join and play

1. Download every `Skybreak-windows-x86_64.zip.partNN` file into one folder.
2. In that folder, open Command Prompt (`cmd`, not PowerShell) and run:

   ```bat
   copy /b Skybreak-windows-x86_64.zip.part00+Skybreak-windows-x86_64.zip.part01+Skybreak-windows-x86_64.zip.part02+Skybreak-windows-x86_64.zip.part03+Skybreak-windows-x86_64.zip.part04+Skybreak-windows-x86_64.zip.part05+Skybreak-windows-x86_64.zip.part06+Skybreak-windows-x86_64.zip.part07 Skybreak-windows-x86_64.zip
   ```

3. Optional check (PowerShell): `Get-FileHash Skybreak-windows-x86_64.zip` must print
   `89024AA44340EBE0C52FA274A503A9C874B797A25DE578F2BE191EC986A8EC26`.
4. Extract the zip and run `Skybreak\Skybreak.exe` (keep the `.dll` next to it).

Not boot-tested on Windows (no Windows machine in the cloud). The Linux export of the same commit
booted the menu and loaded a Vs AI match in voxel Frozen Peaks from its bake (exit 0, no script
errors); see `reports/ship/voxel-ship.md` on `main`.
