class_name VfxPool
extends Node3D
## A fixed-size pool of one kind of effect. spawn() reuses an idle effect and,
## once all `capacity` effects are busy, restarts the oldest; it never grows past it.

var kind: StringName
var capacity := 6

var _effects: Array[VfxEffect] = []
var _spawned := 0


func _init(effect_kind: StringName = &"", max_size: int = 6) -> void:
	kind = effect_kind
	capacity = maxi(max_size, 1)
	name = String(effect_kind)


## Builds `count` effects ahead of time so the first hit allocates nothing.
func fill(count: int) -> void:
	while _effects.size() < mini(count, capacity):
		_add()


## An effect ready for play_at().
func spawn() -> VfxEffect:
	var pick: VfxEffect = null
	for effect in _effects:
		if not effect.is_playing():
			pick = effect
			break
	if pick == null:
		if _effects.size() < capacity:
			pick = _add()
		else:
			pick = _effects[0]
			for effect in _effects:
				if effect.started_order < pick.started_order:
					pick = effect
			pick.stop()
	_spawned += 1
	pick.started_order = _spawned
	return pick


func size() -> int:
	return _effects.size()


func playing_count() -> int:
	var count := 0
	for effect in _effects:
		if effect.is_playing():
			count += 1
	return count


func effects() -> Array[VfxEffect]:
	return _effects


func advance(delta: float) -> void:
	for effect in _effects:
		effect.advance(delta)


func _add() -> VfxEffect:
	var effect := VfxCatalog.build(kind)
	add_child(effect)
	_effects.append(effect)
	return effect
