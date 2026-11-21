SKYBREAK - LOOK-DEV VIDEOS (voxel characters and zones)
Built 2026-11-21 from the latest look-dev renders.

Only the latest version of each character and zone is here. The one exception
is characters/kael/earlier/, which keeps Kael's v1 moves reels (already approved).

Where the files came from
- A GitHub release (lookdev-*), when the latest version has one.
- Otherwise the lookdev/* branch (branch@commit below). Those render sessions
  could not create releases, so they committed the videos to their branch instead.
Every clip is look-dev only: rendered offline with a software renderer (lavapipe)
or the GTX 1650, not captured from the game. The grey figure in the character
reels is a stand-in sparring dummy.

Moves reels: walk, run, jump/land, take-off/hover, flight, flight dash,
dodge, guard, jab/kick/3-hit combo, ki blast volley, beam charge and fire,
hit react and knockdown, each labelled on screen, against the dummy.
Spin = 6 s turntable. Idle loop = 6 s idle animation. Preview GIF = short
cut of the moves reel. Fly-through = 20 s camera flight through the zone, no fighters.

CHARACTERS
characters/kael/        Kael v2 (release lookdev-kael-v2: https://github.com/ArnabChatterjee20k/skybreak/releases/tag/lookdev-kael-v2)
  kael_moves_v2.mp4           moves reel, 1080p60, 58 s
  kael_moves_v2_preview.gif   moves reel preview, 600x338, 20 s
  kael_spin.mp4               turntable, 1080p30, 6 s
  kael_idle_loop.mp4          idle loop, 1080p30, 6 s
  (Kael v3 exists as code on lookdev/kael-v3@e1aac81 but was never rendered.)
characters/kael/earlier/  Kael v1 (release lookdev-kael-v1: https://github.com/ArnabChatterjee20k/skybreak/releases/tag/lookdev-kael-v1)
  kael_moves_v1.mp4           v1 moves reel, 1080p60, 57 s
  kael_moves_v1_firstcut.mp4  v1 first cut of the moves reel, 1080p60, 33 s
  kael_moves_v1_preview.gif   v1 moves reel preview, 600x338, 22 s

characters/vexa/        Vexa v1 (release lookdev-vexa-v1: https://github.com/ArnabChatterjee20k/skybreak/releases/tag/lookdev-vexa-v1)
  vexa_moves_v1.mp4           moves reel, 1080p60, 56 s
  vexa_moves_v1_preview.gif   moves reel preview, 600x338, 18 s
  vexa_spin.mp4               turntable, 1080p30, 6 s
  vexa_idle_loop.mp4          idle loop, 1080p30, 6 s
  (The Vexa v2 colour pass is code on lookdev/vexa-voxel@38346bb, never rendered.)

characters/lyra/        Lyra v2 (branch lookdev/lyra-v2-media@1b82364, folder lyra-v2/;
                        no release. The older v1 release is lookdev-lyra-v1)
  lyra_moves_v2.mp4           moves reel, 1080p60, 58 s
  lyra_moves_v2_preview.gif   moves reel preview, 1280x720, 15 s
  lyra_spin.mp4               turntable, 1080p30, 6 s
  lyra_idle_loop.mp4          idle loop, 1080p30, 6 s

characters/brann/       Brann v2 (branch lookdev/brann-v2-renders@8eee2e6,
                        reports/lookdev/brann_v2/; no release)
  brann_moves_v2_part0.mp4    moves reel part 1 (walk to ki volley), 1080p60, 30 s
  brann_moves_v2_part1.mp4    moves reel part 2 (beam, combos, hit react), 1080p60, 29 s
  brann_moves_v2_preview.gif  moves reel preview, 1920x1080, 7.5 s
  brann_spin.mp4              turntable, 1080p30, 6 s
  brann_idle_loop.mp4         idle loop, 1080p30, 6 s

ZONES (each a 1080p30, 20 s fly-through, no release; from the branch)
zones/heartbloom/       heartbloom_flythrough_v2.mp4      lookdev/heartbloom-zone@5c0edb3
                        (release lookdev-heartbloom-v1 holds only v1 draft stills, no video)
zones/ember_rift/       ember_rift_flythrough_v1.mp4      lookdev/zone-ember_rift@7f3e7e5 (night)
zones/frozen_peaks/     frozen_peaks_flythrough_v1.mp4    lookdev/zone-frozen_peaks@bfc8b11
zones/shattered_mesa/   shattered_mesa_flythrough_v1.mp4  lookdev/zone-shattered_mesa@49ad5ef
zones/skyhold_ruins/    skyhold_ruins_flythrough_v1.mp4   lookdev/zone-skyhold_ruins@ed8877a
zones/stormfall_city/   stormfall_city_flythrough_v1.mp4  lookdev/zone-stormfall_city@e53245e (night, rain)
zones/verdant_falls/    verdant_falls_flythrough_v1.mp4   lookdev/zone-verdant_falls@67f44f5

NOT INCLUDED
- Voxel weapons: turntable stills only, no video (lookdev/lyra-v2-media, weapons-v1/).
- Fight videos with the voxel characters in a real zone: none exist yet. The
  voxel models are not in the game yet.
