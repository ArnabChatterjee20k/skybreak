extends GutTest
## The deterministic path (sim, AI, rollback) must not call libm-backed math, which
## differs in the last bit between platforms; DetMath has the portable versions.
## det_math.gd is scanned too: a bare sin() there would be Godot's global, not DetMath's.

const SCANNED := ["res://game/combat", "res://game/ai", "res://game/net"]
const OPT_OUT := "# det-ok:"
## Bare calls (not methods): transcendental math, angle helpers and the global RNG.
const BANNED_CALLS := [
	"sin", "cos", "tan", "atan", "atan2", "asin", "acos", "sinh", "cosh", "tanh", "pow", "exp",
	"log", "lerp_angle", "angle_difference", "rotate_toward", "ease", "randf", "randi",
	"randf_range", "randi_range", "randfn", "randomize", "seed", "rand_from_seed",
]
## Method calls that use sin, cos, atan2 or acos inside the engine, or the unseeded RNG's log/cos.
const BANNED_METHODS := [
	"rotated", "slerp", "slerpni", "spherical_cubic_interpolate", "angle", "angle_to",
	"signed_angle_to", "get_euler", "from_euler", "looking_at", "get_rotation_quaternion",
	"randfn", "rotate_toward", "get_angle",
]
## Constructors that are banned with two arguments (axis and angle).
const BANNED_TWO_ARG_CONSTRUCTORS := ["Basis", "Quaternion"]

var _calls := RegEx.create_from_string("(?<![\\w.])(%s)\\s*\\(" % "|".join(BANNED_CALLS))
var _methods := RegEx.create_from_string("\\.(%s)\\s*\\(" % "|".join(BANNED_METHODS))
var _constructors := RegEx.create_from_string("(?<![\\w.])(%s)\\s*\\(" % "|".join(BANNED_TWO_ARG_CONSTRUCTORS))


func test_the_deterministic_path_calls_no_platform_dependent_math() -> void:
	var hits: Array[String] = []
	for folder in SCANNED:
		for path in _scripts_under(folder):
			hits.append_array(lint_source(path, FileAccess.get_file_as_string(path)))
	assert_eq(hits, [] as Array[String], "banned calls:\n" + "\n".join(hits))


func test_the_lint_catches_each_kind_of_banned_call() -> void:
	var source := "\n".join([
		"var a := atan2(y, x)",
		"var b := Basis(Vector3.UP, yaw) * Vector3.FORWARD",
		"var c := v.rotated(Vector3.UP, 0.5)",
		"var d := Vector2(1, 2).angle()",
		"var e := randf()",
		"var f := Quaternion(axis, 0.3)",
		"var g := lerp_angle(a, b, 0.5)",
		"var h := pow(2.0, x)",
	])
	assert_eq(lint_source("x.gd", source).size(), 8)


func test_the_lint_allows_det_math_rng_methods_comments_strings_and_opt_outs() -> void:
	var source := "\n".join([
		"var a := DetMath.atan2(y, x)",
		"var b := DetMath.axis_angle(Vector3.UP, yaw)",
		"var c := rng.randf() + rng.randi_range(0, 3)",
		"# sin(x) in a comment",
		"var d := \"cos(x) in a string\"",
		"var e := Basis(x_axis, y_axis, z_axis)",
		"var f := Basis()",
		"var g := v.rotated(Vector3.UP, 0.5)  # det-ok: view-only",
		"var h := is_sin(x) + my.cos_table[0]",
		"static func sin(x: float) -> float:",
	])
	assert_eq(lint_source("x.gd", source), [] as Array[String])


func test_an_opt_out_needs_a_reason() -> void:
	assert_eq(lint_source("x.gd", "var a := sin(x)  # det-ok:").size(), 1)


## "path:line: code" for each banned call in source.
func lint_source(path: String, source: String) -> Array[String]:
	var hits: Array[String] = []
	var lines := source.split("\n")
	for i in lines.size():
		var line := lines[i]
		var at := line.find(OPT_OUT)
		if at >= 0 and not line.substr(at + OPT_OUT.length()).strip_edges().is_empty():
			continue
		var code := _code_only(line)
		if code.strip_edges().begins_with("static func ") or code.strip_edges().begins_with("func "):
			continue
		var banned := _calls.search(code) != null or _methods.search(code) != null
		for found in _constructors.search_all(code):
			banned = banned or _argument_count(code, found.get_end()) == 2
		if banned:
			hits.append("%s:%d: %s" % [path, i + 1, line.strip_edges()])
	return hits


# The line without comments, and with string contents blanked.
func _code_only(line: String) -> String:
	var out := ""
	var quote := ""
	var i := 0
	while i < line.length():
		var ch := line[i]
		if quote.is_empty():
			if ch == "#":
				break
			if ch == "\"" or ch == "'":
				quote = ch
			out += ch
		else:
			if ch == "\\":
				i += 1
			elif ch == quote:
				quote = ""
				out += ch
		i += 1
	return out


# Top-level arguments of the call whose "(" ends just before from.
func _argument_count(code: String, from: int) -> int:
	var depth := 0
	var count := 0
	var any := false
	for i in range(from, code.length()):
		var ch := code[i]
		if ch == "(" or ch == "[" or ch == "{":
			depth += 1
		elif ch == ")" or ch == "]" or ch == "}":
			if depth == 0:
				return count + 1 if any else 0
			depth -= 1
		elif ch == "," and depth == 0:
			count += 1
		elif ch != " ":
			any = true
	return count + 1 if any else 0


func _scripts_under(folder: String) -> Array[String]:
	var found: Array[String] = []
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"):
			found.append(folder.path_join(file))
	for sub in DirAccess.get_directories_at(folder):
		found.append_array(_scripts_under(folder.path_join(sub)))
	return found
