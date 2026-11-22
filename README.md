# Skybreak for Windows (x86_64)

Built from `main` at `746036c1` (PR #141 specials: Kael and Vexa special kits on keys 1/2/3,
Momentum, Afterimage, on top of the voxel art) with the official Godot 4.7.2 Windows release template (export templates
SHA-512 checked against `SHA512-SUMS.txt`), `Windows Desktop` preset. The game data (including
the high, medium and low voxel zone bakes) is embedded in `Skybreak.exe`.

The zip is 727,574,429 bytes, more than GitHub's 100 MB file limit, so it is split into 8 parts
(`split -b 90m`).

## Join and play

1. Download every `Skybreak-windows-x86_64.zip.partNN` file into one folder.
2. In that folder, open Command Prompt (`cmd`, not PowerShell) and run:

   ```bat
   copy /b Skybreak-windows-x86_64.zip.part00+Skybreak-windows-x86_64.zip.part01+Skybreak-windows-x86_64.zip.part02+Skybreak-windows-x86_64.zip.part03+Skybreak-windows-x86_64.zip.part04+Skybreak-windows-x86_64.zip.part05+Skybreak-windows-x86_64.zip.part06+Skybreak-windows-x86_64.zip.part07 Skybreak-windows-x86_64.zip
   ```

3. Optional check (PowerShell): `Get-FileHash Skybreak-windows-x86_64.zip` must print
   `08D6095708D98971E241CCDDE9738E65EDB511C48282A3B3A866BA70BC44AB8B`.
4. Extract the zip and run `Skybreak\Skybreak.exe` (keep the `.dll` next to it).

Not boot-tested on Windows (no Windows machine in the cloud). The same commit's web export ran a
Vs AI match for 30 s with no console errors, and a headless bot-vs-bot Versus on voxel Shattered
Mesa ran 150 s of fight with no script errors; see `reports/gameplay/resume.md` on `main`.
