extends SceneTree
## Prints the determinism self-check (DetCheck); compare the output across platforms.
## godot --headless --path . -s res://tools/diag/det_check.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for line in DetCheck.new().run():
		print(line)
	quit()
