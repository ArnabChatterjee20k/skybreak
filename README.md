# Skybreak media-2 (main 66b15ce)

`media-2-66b15ce.mp4`: 54 s at 1600x900 and 60 fps, H.264 + AAC with game sound and music. Recorded headless on main `66b15ce` with Godot 4.7.2 Movie Maker (`--fixed-fps 60`) under xvfb, using the OpenGL 3 (Compatibility) renderer on Mesa llvmpipe. Vulkan isn't available in the cloud container. 1600x900 is the project's own window size; `--resolution 1920x1080` didn't override it.

| Time | Segment | How |
|---|---|---|
| 0:00–0:22 | Kael vs Vexa, Heartbloom Gardens, AI lv3, seed 2: the last 22 s of round 1, the K.O. at 0:19, the K.O. banner and health bars | `game/debug/media_capture.gd -- duel heartbloom_gardens 2` |
| 0:22–0:36 | Lyra with the Heartstring Bow vs Brann with the Sky Lance, Shattered Mesa, AI lv3, seed 4 | scratch script (not committed) that gives both their weapon at the start |
| 0:36–0:54 | FFA-4 (Kael, Vexa, Lyra, Brann) on Skyhold Ruins, AI lv3, seed 3, mostly in flight | `media_capture.gd -- ffa skyhold_ruins 3 1260` |

## Honest flaws (checked frame by frame at 2 frames per second)
- **No weapons in the Kael vs Vexa duel.** Both stay UNARMED for the whole segment: no pickup is taken in those 22 s.
- **0:00–0:18:** dozens of large opaque white blobs lie on the Heartbloom ground. They are flat and unlit and read as holes, not petals or dust. The duel is the same 2- to 3-hit string over and over (#106).
- **0:00–0:18:** hit sparks are white starbursts that cover the defender (for example 0:02.5, 0:08.5, 0:15.5; #77). The "N HITS" counter is on screen almost all the time (#80).
- **0:19:** the K.O. banner reads well and the health bars show it (Kael's bar empty). But at the K.O. instant Kael is still upright inside Vexa's grab; he falls about 1 s later. The speed lines and the white ring over the floor are busy.
- **0:21.9–0:22.3:** the fade-out lands on a dark "ROUND 2" card, so the cut shows a half-faded second-round intro.
- **0:22–0:36 (bow):** Lyra fires from range, but Brann stays far away (about 25 m) and small for the whole segment, so the lance is never seen up close. The arrows fly as upright pink rods, not along their path (0:26.5). Seen from behind, the drawn bow is edge-on and reads as a staff.
- **0:36–0:54 (FFA-4 on Skyhold):** the camera keeps only Kael and Lyra in frame. **Vexa and Brann never appear** (#75, #107). The zone is washed out by a heavy pale-yellow haze (QA-10 / #100). Long coloured altitude lines run from each flier to the ground and dominate the frame.
- **HUD:** signature weapons read UNARMED. Lyra carries her bow in the FFA, but her slot says UNARMED (#78). The HUD panels are small at 900p.
- The video is 1600x900, not 1080p.
