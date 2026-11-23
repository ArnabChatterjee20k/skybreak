extends GutTest
## MOVE-ESCAPE-CAM: SKYBREAK_REQUIRE_BAKES=1 turns missing zone bakes into failures.

var _saved := {}


func before_each() -> void:
	for name: String in ["SKYBREAK_REQUIRE_BAKES", "SKYBREAK_QA_STRICT"]:
		_saved[name] = OS.get_environment(name)
		OS.unset_environment(name)


func after_each() -> void:
	for name: String in _saved:
		if (_saved[name] as String).is_empty():
			OS.unset_environment(name)
		else:
			OS.set_environment(name, _saved[name])


func test_bakes_are_optional_by_default() -> void:
	assert_false(QaKnownIssues.bakes_required())


func test_require_bakes_makes_missing_bakes_fail() -> void:
	OS.set_environment("SKYBREAK_REQUIRE_BAKES", "1")
	assert_true(QaKnownIssues.bakes_required())


func test_strict_qa_also_requires_bakes() -> void:
	OS.set_environment("SKYBREAK_QA_STRICT", "1")
	assert_true(QaKnownIssues.bakes_required())
