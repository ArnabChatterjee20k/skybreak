# Music licences

Every file in `game/audio/music/` is original work made for Skybreak. All of it
is composed as code in `source/` and synthesised there with numpy/scipy: no
samples, loops, soundfonts, presets or recordings from anywhere else, and no
melodies or motifs from existing games or anime.

Author: Skybreak project (composed and rendered by a `desktop` cloud agent for
the owner, T-D21). Licence: same as the Skybreak repository (personal,
non-commercial project; owner holds all rights).

| File | Title | Source | Licence | Author |
|---|---|---|---|---|
| `tracks/menu.ogg` | Skybreak (main theme) | `source/themes.py` `MENU`, `render.py menu()` | Skybreak project | Skybreak project |
| `tracks/character_select.ogg` | Choose Your Legend | `themes.py` `SELECT`, `render.py select()` | Skybreak project | Skybreak project |
| `tracks/battle_shattered_mesa_{calm,combat,climax}.ogg` | Red Horizon | `themes.py` `THEMES["shattered_mesa"]` | Skybreak project | Skybreak project |
| `tracks/battle_skyhold_ruins_{calm,combat,climax}.ogg` | Islands of Gold | `themes.py` `THEMES["skyhold_ruins"]` | Skybreak project | Skybreak project |
| `tracks/battle_stormfall_city_{calm,combat,climax}.ogg` | Neon Downpour | `themes.py` `THEMES["stormfall_city"]` | Skybreak project | Skybreak project |
| `tracks/battle_frozen_peaks_{calm,combat,climax}.ogg` | Glass Summit | `themes.py` `THEMES["frozen_peaks"]` | Skybreak project | Skybreak project |
| `tracks/battle_verdant_falls_{calm,combat,climax}.ogg` | Canopy Run | `themes.py` `THEMES["verdant_falls"]` | Skybreak project | Skybreak project |
| `tracks/battle_ember_rift_{calm,combat,climax}.ogg` | Magma Heart | `themes.py` `THEMES["ember_rift"]` | Skybreak project | Skybreak project |
| `tracks/battle_heartbloom_gardens_{calm,combat,climax}.ogg` | Petals for Two | `themes.py` `THEMES["heartbloom_gardens"]` | Skybreak project | Skybreak project |
| `tracks/victory.ogg` | Victory Fanfare | `render.py victory()` | Skybreak project | Skybreak project |
| `tracks/defeat.ogg` | Fallen (KO stinger) | `render.py defeat()` | Skybreak project | Skybreak project |
| `preview/preview_stormfall_city.ogg` | 60 s preview mix | `source/preview.py` from the tracks above | Skybreak project | Skybreak project |

## Tools used to render (not shipped)

| Tool | Licence |
|---|---|
| numpy, scipy | BSD-3-Clause |
| soundfile (libsndfile, libvorbis) | BSD-3-Clause / LGPL-2.1 / BSD |
| pyloudnorm (ITU-R BS.1770 loudness) | MIT |
| matplotlib (analysis plots only) | PSF-based |
