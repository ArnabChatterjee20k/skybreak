class_name MatchCues
extends Node
## Round sounds and music from MatchFlow (T-127): the 3-2-1 count and "fight"
## UI cues, the round-end and victory cues, and the MusicDirector's battle
## theme, intensity, round resets and stingers. The arena calls after_tick()
## right after match_flow.step(); this node only watches phase changes, so it
## needs no hooks inside MatchFlow.

## UI cue ids in the T-D20 ui bank.
const CUE_COUNT: Array[StringName] = [&"round_count_1", &"round_count_2", &"round_count_3"]
const CUE_FIGHT := &"round_fight"
const CUE_ROUND_END := &"round_end"
const CUE_VICTORY := &"victory"

## Index of the human player (whose win plays the victory stinger).
var player_index := 0
## Battle theme zone (a MusicCatalog.BATTLE key).
var zone: StringName = &"shattered_mesa"
## Default to the autoloads; tests inject fakes.
var director: Object
var music: Object

var _phase := -1
var _round := 0
var _count := 0


func _ready() -> void:
	if director == null:
		director = get_node_or_null(^"/root/AudioDirector")
	if music == null:
		music = get_node_or_null(^"/root/MusicDirector")


## Call once per sim tick, after match_flow.step(sim).
func after_tick(flow: MatchFlow, sim: CombatSim) -> void:
	if not flow.enabled:
		return
	var phase := flow.phase
	if phase != _phase or flow.round_number != _round:
		_enter(flow, phase)
		_phase = phase
		_round = flow.round_number
	var count := flow.count()
	if count != _count:
		_count = count
		if count > 0:
			_play(CUE_COUNT[count - 1])
	if phase == MatchFlow.Phase.FIGHT and music != null:
		music.observe_sim(sim, _final_round(flow))


func _enter(flow: MatchFlow, phase: int) -> void:
	match phase:
		MatchFlow.Phase.INTRO:
			if music != null:
				if flow.round_number == 1:
					music.start_battle(zone)
				else:
					music.round_started()
		MatchFlow.Phase.FIGHT:
			_play(CUE_FIGHT)
		MatchFlow.Phase.KO:
			_play(CUE_ROUND_END)
			if music != null:
				var match_over: bool = flow.wins.max() >= MatchFlow.WINS_NEEDED
				music.round_ended(match_over, flow.last_winner == player_index)
		MatchFlow.Phase.MATCH_OVER:
			_play(CUE_VICTORY)


func _play(cue: StringName) -> void:
	if director != null:
		director.play(cue)


## Both sides one win from the match: music goes straight to its climax layer.
static func _final_round(flow: MatchFlow) -> bool:
	for wins in flow.wins:
		if wins < MatchFlow.WINS_NEEDED - 1:
			return false
	return true
