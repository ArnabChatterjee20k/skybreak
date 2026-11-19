"""The Skybreak score as data: every theme, its harmony, hooks and grooves.

All melodies here were written for Skybreak. Battle themes are 32 bars: a
16-bar hook (phrases A B A' C) that repeats an octave up with harmony.
"""
import synth as s

# Chord shorthand: (semitones above the key root, quality).
def C(offset, quality="M"):
	return (offset, quality)


# ------------------------------------------------------------------ drum kits

ROCK = {
	"kick": ["X.....x...x.....", "X.....x.x.......", ],
	"snare": ["....X.......X...", "....X.......X..o"],
	"hat": ["x.x.x.x.x.x.x.x."],
}
FOUR = {
	"kick": ["X...X...X...X..."],
	"clap": ["....X.......X..."],
	"hat": ["..x...x...x...x."],
}
BREAK = {
	"kick": ["X.........X.....", "X.....X...X....."],
	"snare": ["....X.......X...", "....X..o....X.o."],
	"hat": ["xxx.xxx.xxx.xxxo"],
}
HALFTIME = {
	"kick": ["X......xX.......", "X.......X..x...."],
	"snare": ["........X......."],
	"hat": ["x.x.x.x.x.x.x.x."],
}
TRIBAL = {
	"kick": ["X.....x...X....."],
	"tom_lo": ["......x.......x.", "...x......x...x."],
	"tom_mid": ["..x.......x....."],
	"snare": ["....x.......X..."],
	"shaker": ["xoxoxoxoxoxoxoxo"],
}
SOFT_FILL = {
	"clap": ["........x...x.x."],
	"tom_mid": ["..........x....."],
	"tom_lo": ["..............x."],
}
SOFT = {
	"kick": ["X.......x.x.....", "X.........x....."],
	"clap": ["....x.......x..."],
	"shaker": ["x.xox.xox.xox.xo"],
}

FILL = {
	"snare": ["....o...o.o.xxXX"],
	"tom_hi": ["........x.x....."],
	"tom_lo": ["............x.x."],
}
CLIMAX_PERC = {
	"hat": ["xoxoxoxoxoxoxoxo"],
	"taiko": ["X.......x.x.....", "X.....x.X......."],
	"tom_lo": ["..........x..x.x"],
}
CALM_PERC = {"shaker": ["x.o.x.o.x.o.x.o."]}
CALM_RIDE = {"ride": ["x...x...x...x..."]}


THEMES = {}

THEMES["shattered_mesa"] = dict(
	title="Red Horizon", mood="Dusty desert showdown: twangy plucks, taiko, bold brass",
	bpm=147, root=50, scale="harmonic_minor", seed=101,
	progression=[C(0, "m"), C(8), C(10), C(7)] * 2 + [C(5, "m"), C(0, "m"), C(8), C(7)] + [C(0, "m"), C(8), C(10), C(7)],
	melody=[
		"1 . 1 5 - 4 3 - | 6 - 5 4 3 - 1 - | 7b - 7b 1 2 - 4 3 | 2 - - - 0 - 5 -",
		"1 . 1 5 - 4 3 - | 6 - 5 4 3 - 5 - | 7b - 7b 8 9 - 8 7b | 9 - - - 7 - - -",
		"4 - 6 - 8 - 7b 6 | 5 - - 3 4 5 - - | 6 - 5 6 8 - 9 - | 9 - - - 7 - - -",
		"8 - 8 9 8 - 6 5 | 6 - 5 - 4 - 3 - | 4 . 4 3 2 - 7b - | 2 - - - 5 - 0 -",
	],
	calm=dict(pad=s.v_strings, bass=s.v_sub_bass, bass_pat="R - - - - - - - | F - - - R - - -",
		arp=s.v_pluck, arp_pat="0 . 1 2 . 1 2 . 0 . 1 2 . 3 2 1", lead=s.v_pluck, perc=CALM_PERC),
	combat=dict(lead=s.v_pluck, lead2=s.v_brass, bass=s.v_bass, bass_pat="R R . R O R . R",
		drums={**ROCK, "taiko": ["X...............", "X.......X......."]}, stab=s.v_stab, stab_pat=". . x . . . x ."),
	climax=dict(counter=s.v_brass, choir=s.v_choir, perc=CLIMAX_PERC),
)

THEMES["skyhold_ruins"] = dict(
	title="Islands of Gold", mood="Soaring and heroic: wide strings, leaping brass hook",
	bpm=168, root=52, scale="lydian", seed=202,
	progression=[C(0), C(2), C(9, "m"), C(7)] + [C(9, "m"), C(7), C(0), C(2)] + [C(0), C(2), C(9, "m"), C(7)] + [C(4, "m"), C(2), C(9, "m"), C(7)],
	melody=[
		"1 - 5 - 8 - - 7 | 9 - - 8 7 - 6 5 | 6 - - 5 6 - 8 - | 5 - - - - - . .",
		"3 - 3 4 5 - 3 - | 2 - 2 3 4 - 2 - | 1 - 3 - 5 - 8 - | 9 - - - 11 - 9 -",
		"1 - 5 - 8 - - 7 | 9 - - 8 7 - 6 5 | 6 - 7 - 8 - 9 - | 12 - - - - - . .",
		"10 - - 9 8 - 7 - | 9 - 8 7 6 - 5 - | 6 - 7 - 8 - 9 - | 7 - - - 5 - - -",
	],
	calm=dict(pad=s.v_pad, bass=s.v_sub_bass, bass_pat="R - - - - - - - | R - - - F - - -",
		arp=s.v_bell, arp_pat="0 . . 2 . . 4 . . 3 . . 1 . . .", lead=s.v_flute, perc=CALM_RIDE),
	combat=dict(lead=s.v_brass, lead2=s.v_supersaw_lead, bass=s.v_bass, bass_pat="R O R O R O R O",
		drums=ROCK, stab=s.v_strings, stab_pat="x - - - x - x -"),
	climax=dict(counter=s.v_supersaw_lead, choir=s.v_choir, perc=CLIMAX_PERC),
)

THEMES["stormfall_city"] = dict(
	title="Neon Downpour", mood="Night-city chase: gated synths, breakbeat, octave bass",
	bpm=175, root=54, scale="minor", seed=303,
	progression=[C(0, "m"), C(8), C(3), C(10)] + [C(5, "m"), C(8), C(0, "m"), C(7)] + [C(0, "m"), C(8), C(3), C(10)] + [C(5, "m"), C(8), C(0, "m"), C(7)],
	melody=[
		"1 . 3 . 5 4 3 1 | 8 . 7 . 5 - 3 - | 5 . 4 . 3 4 5 8 | 7 - - - 5 - - -",
		"4 - 4 5 6 - 5 4 | 3 - 3 4 5 - 3 - | 1 . 1 3 5 - 8 - | 7# - - - 5 - - -",
		"8 . 10 . 9 8 7 5 | 6 . 5 . 3 - 1 - | 3 . 4 . 5 6 7 8 | 9 - - - 7 - - -",
		"6 - 5 - 6 - 8 - | 6 - 5 - 3 - 1 - | 3 . 5 . 8 . 10 . | 9 - - - 7# - - -",
	],
	calm=dict(pad=s.v_pad, bass=s.v_sub_bass, bass_pat="R - - R - - R - | R - - R - - F -",
		arp=s.v_square_pluck, arp_pat="0 2 1 3 2 4 3 2 0 2 1 3 2 4 3 5", lead=s.v_soft_lead, perc={"hat": ["..x...x...x...x."]}),
	combat=dict(lead=s.v_supersaw_lead, lead2=s.v_supersaw_lead, bass=s.v_bass, bass_pat="L O L O L O L O",
		drums=BREAK, stab=s.v_stab, stab_pat=". x . x . x . x"),
	climax=dict(counter=s.v_brass, choir=s.v_pad, perc={"hat": ["xxxxxxxxxxxxxxxx"], "clap": ["....X.......X..."], "tom_lo": ["..........x.x.x."]}),
)

THEMES["frozen_peaks"] = dict(
	title="Glass Summit", mood="Icy and tense: FM bells, 16th arps, cold strings",
	bpm=140, root=47, scale="minor", seed=404,
	progression=[C(0, "m"), C(8), C(5, "m"), C(7)] + [C(3), C(10), C(8), C(7)] + [C(0, "m"), C(8), C(5, "m"), C(7)] + [C(3), C(10), C(8), C(7)],
	melody=[
		"5 - - 4 5 - 8 - | 6 - - 5 6 - 3 - | 4 - - 3 4 - 7 - | 7# - - - - - . .",
		"3 - 5 - 8 - 7 - | 5 - 4 - 5 - 7 - | 8 - 7 - 6 - 5 - | 7# - 6 - 7# - - -",
		"5 - - 4 5 - 8 - | 6 - - 5 6 - 3 - | 4 - - 3 4 - 7 - | 7# - - - 9 - - -",
		"10 - - 9 10 - 12 - | 11 - - 10 9 - 8 - | 8 - - 7 6 - 5 - | 5 - - - 7# - - -",
	],
	calm=dict(pad=s.v_strings, bass=s.v_sub_bass, bass_pat="R - - - - - - - | R - - - - - - -",
		arp=s.v_bell, arp_pat="0 2 4 2 3 2 4 5 0 2 4 2 3 5 4 2", lead=s.v_bell, perc={}),
	combat=dict(lead=s.v_strings, lead2=s.v_supersaw_lead, bass=s.v_bass, bass_pat="R R R R R R F O",
		drums=HALFTIME, stab=s.v_square_pluck, stab_pat="x x . x x . x .", lead_octave=1),
	climax=dict(counter=s.v_bell, choir=s.v_choir, perc={"hat": ["xoxoxoxoxoxoxoxo"], "snare": ["....X.......X..."], "tom_lo": ["..........x..x.x"]}),
)

THEMES["verdant_falls"] = dict(
	title="Canopy Run", mood="Jungle sprint: marimba, tribal toms, breathy flute hook",
	bpm=144, root=55, scale="mixolydian", seed=505,
	progression=[C(0), C(10), C(5), C(0)] + [C(9, "m"), C(5), C(7), C(7, "sus4")] + [C(0), C(10), C(5), C(0)] * 2,
	melody=[
		"5 - 6 5 3 - 2 1 | 7 - 1 2 3 - 2 - | 1 - 3 5 6 - 5 3 | 5 - - - - - . .",
		"3 - 3 5 6 - 5 3 | 1 - 1 3 5 - 3 1 | 2 - 2 3 4 - 5 6 | 5 - - - 4 - 2 -",
		"5 - 6 5 3 - 2 1 | 7 - 1 2 3 - 2 - | 1 - 3 5 6 - 8 9 | 8 - - - - - . .",
		"8 - 9 8 6 - 5 3 | 7 - 8 9 10 - 9 - | 8 - 6 5 3 - 2 - | 1 - - - - - . .",
	],
	calm=dict(pad=s.v_pad, bass=s.v_sub_bass, bass_pat="R - - - R - - - | R - - - F - - -",
		arp=s.v_marimba, arp_pat="0 . 2 1 . 2 3 . 0 . 2 1 . 3 2 .", lead=s.v_flute, perc=CALM_PERC),
	combat=dict(lead=s.v_flute, lead2=s.v_brass, bass=s.v_bass, bass_pat="R . R F . R O .",
		drums=TRIBAL, stab=s.v_marimba, stab_pat="x . x x . x . x", lead_octave=1),
	climax=dict(counter=s.v_brass, choir=s.v_choir, perc={"taiko": ["X.......X.x....."], "tom_hi": ["..x...x...x...x."], "hat": ["x.x.x.x.x.x.x.x."]}),
)

THEMES["ember_rift"] = dict(
	title="Magma Heart", mood="Volcanic and heavy: growl bass, low brass, choir, war drums",
	bpm=150, root=48, scale="harmonic_minor", seed=606,
	progression=[C(0, "m"), C(8), C(5, "m"), C(7)] + [C(0, "m"), C(10), C(8), C(7)] + [C(0, "m"), C(8), C(5, "m"), C(7)] * 2,
	melody=[
		"1 - 1 2 3 - 2 1 | 6 - - 5 6 - 5 - | 4 - 4 5 6 - 5 4 | 7 - - - 5 - - -",
		"8 - 8 7b 8 - 10 - | 9 - 8 - 7b - 6 - | 6 - 5 - 6 - 8 - | 7 - - - - - . .",
		"1 - 1 2 3 - 5 3 | 6 - - 5 6 - 8 - | 4 - 6 5 4 - 3 2 | 7 - - - 5 - 7 -",
		"10 - 10 9 10 - 12 - | 13 - - 12 11 - 10 - | 11 - 10 - 9 - 8 - | 7 - - - 5 - - -",
	],
	calm=dict(pad=s.v_choir, bass=s.v_sub_bass, bass_pat="R - - - - - - - | L - - - - - - -",
		arp=s.v_pluck, arp_pat="0 . . 0 . . 1 . 0 . . 0 . . 2 .", lead=s.v_brass, perc={"taiko": ["X...............", "X.......x......."]}),
	combat=dict(lead=s.v_brass, lead2=s.v_supersaw_lead, bass=s.v_growl_bass, bass_pat="R R . R R . R O",
		drums=HALFTIME, stab=s.v_stab, stab_pat="x . . x . . x .", lead_octave=0),
	climax=dict(counter=s.v_supersaw_lead, choir=s.v_choir, perc={"taiko": ["X..x..x.X..x..x."], "hat": ["xoxoxoxoxoxoxoxo"], "tom_lo": ["............xxxx"]}),
)

THEMES["heartbloom_gardens"] = dict(
	title="Petals for Two", mood="Warm, romantic and playful: e-piano, glockenspiel, strings, light claps",
	bpm=120, root=53, scale="major", seed=707,
	progression=[C(0, "M7"), C(4, "m7"), C(9, "m7"), C(5, "M7")] + [C(2, "m7"), C(7, "7"), C(4, "m7"), C(9, "m7")] + [C(0, "M7"), C(4, "m7"), C(9, "m7"), C(5, "M7")] + [C(5, "M7"), C(4, "m7"), C(2, "m7"), C(7, "7")],
	melody=[
		"3 - 5 - 8 - 7 5 | 6 - 5 - 3 - 5 - | 4 - 3 4 6 - 5 4 | 3 - - - 2 - 1 -",
		"2 - 4 - 6 - 5 4 | 5 - - 4 3 - 2 - | 3 - 5 - 7 - 6 5 | 6 - - - . . 5 6",
		"8 - 5 - 8 - 7 5 | 6 - 5 - 3 - 5 - | 4 - 3 4 6 - 8 9 | 7 - - - 6 - 5 -",
		"8 - 7 6 5 - 6 - | 7 - 6 5 3 - 5 - | 6 - 5 4 3 - 2 - | 5 - - - 6 - 7b -",
	],
	calm=dict(pad=s.v_epiano, bass=s.v_sub_bass, bass_pat="R - - - F - - - | R - - - T - - -",
		arp=s.v_glock, arp_pat="0 . 2 . 3 . 2 . 1 . 3 . 4 . 3 .", lead=s.v_glock, perc={"shaker": ["x.o.x.o.x.o.x.o."]}, pad_beats=2),
	combat=dict(lead=s.v_soft_lead, lead2=s.v_epiano, bass=s.v_bass, bass_pat="R . . R F . R .",
		drums=SOFT, fill=SOFT_FILL, stab=s.v_epiano, stab_pat=". x . x . x . x"),
	climax=dict(counter=s.v_strings, choir=s.v_strings, perc={"hat": ["x.x.x.x.x.x.x.x."], "clap": ["....X.......X..."], "tom_mid": ["............x.x."]}),
)

ZONE_ORDER = ["shattered_mesa", "skyhold_ruins", "stormfall_city", "frozen_peaks",
	"verdant_falls", "ember_rift", "heartbloom_gardens"]

MENU = dict(
	title="Skybreak", mood="Main theme: heroic call to adventure", bpm=140, root=57, scale="minor", seed=11,
	progression=[C(0, "m"), C(8), C(3), C(10)] + [C(8), C(10), C(7), C(7)],
	melody=[
		"1 - 5 - 4 3 4 5 | 6 - - 5 3 - - - | 3 - 5 - 8 - 7 - | 7b - - - - - . .",
		"6 - 6 7 8 - 6 - | 7 - 7 8 9 - 7 - | 5 - 5 6 7 - 5 - | 7# - - - 9 - - -",
	],
)

SELECT = dict(
	title="Choose Your Legend", mood="Bouncy groove for picking fighters", bpm=126, root=52, scale="dorian", seed=12,
	progression=[C(0, "m7"), C(5, "7"), C(0, "m7"), C(10)] * 2,
)
