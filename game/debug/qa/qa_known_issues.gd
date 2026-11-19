class_name QaKnownIssues
extends RefCounted
## Bugs and missing features the QA harness found, filed in TODO.md. A QA scenario
## that hits one goes pending in CI and fails under tools/qa/run_qa.sh (strict mode).

## Id -> one line on what is wrong. Ids are TODO.md task ids.
const ISSUES := {
	&"T-D29": "No fighter-fighter pushboxes on main: fighters can overlap and pass through each other.",
	&"QA-2": "Brann's air lights stun shorter than his spike startup: the air route drops before the spike.",
}


## True when run_qa.sh runs the scenarios: known issues fail instead of going pending.
static func strict() -> bool:
	return OS.get_environment("SKYBREAK_QA_STRICT") == "1"


static func describe(id: StringName) -> String:
	return "%s: %s" % [id, ISSUES.get(id, "unfiled")]


## True once the sim keeps fighters' bodies apart (T-D29 merged).
static func has_pushboxes() -> bool:
	var source := (load("res://game/combat/combat_sim.gd") as Script).source_code
	return source.findn("pushbox") >= 0
