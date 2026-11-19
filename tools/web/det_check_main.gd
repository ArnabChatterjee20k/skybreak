extends Node
## Browser entry for the determinism self-check: prints DetCheck's lines to the console.


func _ready() -> void:
	await get_tree().process_frame
	for line in DetCheck.new().run():
		print(line)
	print("det_check done")
