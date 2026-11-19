class_name SimSnapshot
extends RefCounted
## A deep copy of an object's script state, for rollback (CombatSim.snapshot()).
## Copies every script variable by reflection, so new sim fields are covered
## without editing this file. Rules: plain values and packed arrays are copied,
## Resources are shared (they are configuration), RandomNumberGenerator keeps
## its state, and RefCounted script objects (also inside arrays) are copied deeply.

## Script instance id -> field names grouped by how they are copied, cached.
## Keyed by id so the cache never keeps a script alive.
static var _layouts: Dictionary = {}
const _PLAIN := 0 ## Value types and shared Resources: kept as they are.
const _DUPLICATE := 1 ## Packed arrays and arrays of value types.
const _DEEP := 2 ## Anything else: copied by _copy().

## Saved script variables of the captured object, in field order.
var values: Array = []


## Captures obj's script state.
static func capture(obj: Object) -> SimSnapshot:
	var snapshot := SimSnapshot.new()
	snapshot.values = _capture_values(obj)
	return snapshot


## Writes the saved state back into obj, which must have the captured object's script.
## The snapshot stays unchanged, so it can be restored again.
func restore_into(obj: Object) -> void:
	_restore_values(obj, values)


## [plain names, duplicate names, deep names] of obj's script variables.
static func _layout(obj: Object) -> Array:
	var source: Script = obj.get_script()
	var key := source.get_instance_id()
	if _layouts.has(key):
		return _layouts[key]
	var layout: Array = [[] as Array[StringName], [] as Array[StringName], [] as Array[StringName]]
	for property in obj.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			(layout[_kind_of(property)] as Array[StringName]).append(StringName(property.name))
	_layouts[key] = layout
	return layout


static func _kind_of(property: Dictionary) -> int:
	match property.type:
		TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME, TYPE_VECTOR2, \
		TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I, TYPE_VECTOR4, TYPE_QUATERNION, \
		TYPE_BASIS, TYPE_TRANSFORM3D, TYPE_COLOR:
			return _PLAIN
		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, \
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, \
		TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_COLOR_ARRAY, \
		TYPE_PACKED_VECTOR4_ARRAY:
			return _DUPLICATE
		TYPE_ARRAY:
			var element: String = property.hint_string
			if property.hint == PROPERTY_HINT_ARRAY_TYPE and element in ["int", "float", "bool",
					"Vector2", "Vector3", "String", "StringName"]:
				return _DUPLICATE
		TYPE_OBJECT:
			if _is_resource_class(property["class_name"]):
				return _PLAIN
	return _DEEP


static func _is_resource_class(name: StringName) -> bool:
	if name.is_empty():
		return false
	if ClassDB.class_exists(name):
		return ClassDB.is_parent_class(name, &"Resource")
	for global in ProjectSettings.get_global_class_list():
		if global["class"] == name:
			return _is_resource_class(global["base"])
	return false


## Saved as [plain values, duplicated values, deep copies], in layout order.
static func _capture_values(obj: Object) -> Array:
	var layout := _layout(obj)
	var plain: Array = []
	for field: StringName in layout[_PLAIN]:
		plain.append(obj.get(field))
	var duplicated: Array = []
	for field: StringName in layout[_DUPLICATE]:
		duplicated.append(obj.get(field).duplicate())
	var deep: Array = []
	for field: StringName in layout[_DEEP]:
		deep.append(_copy(obj.get(field)))
	return [plain, duplicated, deep]


static func _restore_values(obj: Object, saved: Array) -> void:
	var layout := _layout(obj)
	var names: Array[StringName] = layout[_PLAIN]
	var values: Array = saved[_PLAIN]
	for i in names.size():
		obj.set(names[i], values[i])
	names = layout[_DUPLICATE]
	values = saved[_DUPLICATE]
	for i in names.size():
		obj.set(names[i], values[i].duplicate())
	names = layout[_DEEP]
	values = saved[_DEEP]
	for i in names.size():
		var value: Variant = values[i]
		if value is _Saved:
			obj.set(names[i], (value as _Saved).rebuild(obj.get(names[i])))
		else:
			obj.set(names[i], _copy(value))


static func _copy(value: Variant) -> Variant:
	match typeof(value):
		TYPE_OBJECT:
			if value == null or value is Resource:
				return value
			if value is RandomNumberGenerator:
				return _SavedRng.new((value as RandomNumberGenerator).state)
			if (value as Object).get_script() != null:
				return _SavedObject.new(value)
			return value
		TYPE_ARRAY:
			var array: Array = value
			for item: Variant in array:
				if typeof(item) == TYPE_OBJECT:
					return _SavedObjects.new(array)
			return array.duplicate(true)
		TYPE_DICTIONARY:
			return (value as Dictionary).duplicate(true)
		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, \
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, \
		TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_COLOR_ARRAY, \
		TYPE_PACKED_VECTOR4_ARRAY:
			return value.duplicate()
	return value


## A saved value that needs rebuilding (objects, rng) rather than a plain copy.
class _Saved:
	extends RefCounted

	func rebuild(_current: Variant) -> Variant:
		return null


class _SavedRng:
	extends _Saved
	var state: int

	func _init(saved_state: int) -> void:
		state = saved_state

	func rebuild(current: Variant) -> Variant:
		var rng: RandomNumberGenerator = current if current is RandomNumberGenerator \
			else RandomNumberGenerator.new()
		rng.state = state
		return rng


## One script object; restored as a fresh instance so nothing else holding the old one sees it change.
class _SavedObject:
	extends _Saved
	var source: Script
	var values: Array

	func _init(obj: Object) -> void:
		source = obj.get_script()
		values = SimSnapshot._capture_values(obj)

	func rebuild(_current: Variant) -> Variant:
		var obj: Object = source.new()
		SimSnapshot._restore_values(obj, values)
		return obj


## An array holding objects (fighters, pickups, projectiles); restored in place,
## reusing the live instances so the view's references stay valid.
class _SavedObjects:
	extends _Saved
	var items: Array = []

	func _init(array: Array) -> void:
		for item: Variant in array:
			items.append(SimSnapshot._copy(item))

	func rebuild(current: Variant) -> Variant:
		var target: Array = current if current is Array else []
		var old := target.duplicate()
		target.resize(items.size())
		for i in items.size():
			var item: Variant = items[i]
			if item is _SavedObject:
				var saved := item as _SavedObject
				var live: Variant = old[i] if i < old.size() else null
				if live is Object and (live as Object).get_script() == saved.source:
					SimSnapshot._restore_values(live, saved.values)
					target[i] = live
				else:
					target[i] = saved.rebuild(null)
			elif item is _Saved:
				target[i] = (item as _Saved).rebuild(old[i] if i < old.size() else null)
			else:
				target[i] = SimSnapshot._copy(item)
		return target
