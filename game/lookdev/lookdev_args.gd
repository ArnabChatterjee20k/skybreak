class_name LookdevArgs
extends RefCounted
## Command-line arguments for the look-dev tools: positionals plus --key=value
## options, from everything after "--" on the Godot command line.

var positional: Array[String] = []
var options := {}


static func parse() -> LookdevArgs:
	var a := LookdevArgs.new()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var eq := arg.find("=")
			if eq < 0:
				a.options[arg.substr(2)] = "true"
			else:
				a.options[arg.substr(2, eq - 2)] = arg.substr(eq + 1)
		else:
			a.positional.append(arg)
	return a


func pos(i: int, fallback := "") -> String:
	return positional[i] if i < positional.size() else fallback


func get_option(key: String, fallback := "") -> String:
	return options.get(key, fallback)


## A required option: quits with a usage message if it's missing.
func need(key: String, usage: String) -> String:
	if not options.has(key):
		push_error("missing --%s=...\n%s" % [key, usage])
		(Engine.get_main_loop() as SceneTree).quit(2)
		return ""
	return options[key]
