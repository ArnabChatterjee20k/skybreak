# Asset licences

Every third-party asset in the repo: where it came from, who made it, its
licence and which files use it. Free licences that allow personal use and
modification only. Add a row when you add an asset.

## Characters

### Kael body: VRoid Project "HairSample_Male" (T-D10)

| | |
|---|---|
| Author | VRoid Project (pixiv Inc.), made in VRoid Studio |
| Licence | **CC0**. The file's own VRM meta: `licenseName: CC0`, `allowedUserName: Everyone`, violent and commercial use allowed. The OpenGameArt collection below cites pixiv's VRoid help article on the sample models' conditions of use (https://vroid.pixiv.help/hc/en-us/articles/4402614652569); that page could not be opened from the cloud, so the embedded CC0 meta is the licence record here. |
| Official source | VRoid Studio sample models; also mirrored on OpenGameArt, "VRoid Studio CC0 models" (https://opengameart.org/content/vroid-studio-cc0-models). Neither is reachable from the cloud sessions (VRoid Hub needs a login; OpenGameArt is blocked by the proxy). |
| Downloaded from | A public GitHub mirror (Git LFS): https://media.githubusercontent.com/media/yanxue06/portfolio/HEAD/island/public/assets/characters/HairSample_Male.vrm, 2026-11-19. sha256 of the downloaded `.vrm`: `709058873e041b91d7a2a4f7975f062658c6ae4278fb5cb8a8b6779194176d58` (equals the LFS oid). The CC0 terms travel inside the file, so the mirror does not change them. |
| Modified | `game/characters/tools/prepare_vroid.gd`: turned 180° to face +Z, primitives sharing a material merged (hair: 114 → 1), base colour textures extracted. Orange recolour of the top in `kael_top.tres`. |
| Files | `game/characters/kael/kael_body.glb` (sha256 `9aef81da…2177`), `game/characters/kael/textures/*.png` |

## Animations

### Quaternius "Universal Animation Library" 1 and 2, Standard (free) editions (T-D10)

| | |
|---|---|
| Author | Quaternius (https://quaternius.com) |
| Licence | **CC0 1.0** (`License.txt` in both packs: "CC0 1.0 Universal (CC0 1.0) Public Domain Dedication"). |
| Official source | https://quaternius.com/packs/universalanimationlibrary.html and https://quaternius.itch.io/universal-animation-library (+ "...-2"); neither host is reachable from the cloud sessions. |
| Downloaded from | Unmodified copy of the itch.io archives in the public GitHub repo https://github.com/NafisRayan/Animate-Rigged-Humanoid-No-Blender (commit `5821923af517ac5fdc82505faa92a0d575fc1b1a`), files `Universal Animation Library[Standard]/…/Unreal-Godot/UAL1_Standard.glb` (sha256 `69591853…7997`) and `Universal Animation Library 2[Standard]/…/Unreal-Godot/UAL2_Standard.glb` (sha256 `8cee20ab…88a8`), 2026-11-19. The CC0 `License.txt` is in that copy. A second mirror, https://github.com/J-Ponzo/gltf-universal-animation-library (CC0), has the same UAL1 clip list. |
| Modified | Retargeted to `SkeletonProfileHumanoid` at import (`game/characters/rig/ual_bone_map.tres`); 24 clips copied and renamed into `humanoid_clips.res` by `game/characters/tools/build_clip_library.gd`, with the hips pinned horizontally (no root motion). |
| Files | `game/characters/animations/ual/ual1_standard.glb`, `ual2_standard.glb` (sources), `game/characters/animations/humanoid_clips.res` (what the game loads) |

## Looked at and not used (T-D10 research)

- **VRM consortium samples** (https://github.com/vrm-c/vrm-specification/tree/master/samples):
  `VRM1_Constraint_Twist_Sample` (pixiv, VRM Public License 1.0, modification
  and redistribution allowed, no credit needed) is a good anime avatar, but
  female; Kael is written as "he". Good fallback for a female fighter.
  `Seed-san` (VirtualCast) needs credit and is a mascot-style robot girl.
- **VRoid AvatarSample_A–C** (VRoid Hub licence: modification and
  redistribution allowed, credit unnecessary): the only no-login copies found
  are unofficial app mirrors; HairSample_Male has the clearer CC0 licence.
- **three.js examples** (`RobotExpressive.glb`, CC0): robot, not humanoid
  anime; `Xbot`/`Soldier`/`Michelle` come from Mixamo, excluded.
- **Mixamo, VRoid Hub, Sketchfab, Adobe**: need a login, excluded by the task.
- **Kenney, OpenGameArt, quaternius.com, itch.io, jsDelivr, unpkg**: blocked
  by the cloud proxy (HTTP 403 on CONNECT), so not tried further from here.
- **Kicks**: neither free UAL edition has kick clips; the paid "Pro" editions
  and Quaternius' character packs (per-rig kicks) would. See the PR for the
  gap list.
