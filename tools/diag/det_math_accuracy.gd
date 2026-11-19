extends SceneTree
## Prints DetMath's worst error in ulps against the platform libm, per function.
## godot --headless --path . -s res://tools/diag/det_math_accuracy.gd


func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 32
	_report("sin", func(x: float) -> float: return DetMath.sin(x), func(x: float) -> float: return sin(x), rng, -100.0, 100.0)
	_report("cos", func(x: float) -> float: return DetMath.cos(x), func(x: float) -> float: return cos(x), rng, -100.0, 100.0)
	_report("atan", func(x: float) -> float: return DetMath.atan(x), func(x: float) -> float: return atan(x), rng, -50.0, 50.0)
	_report("atan2(x,1-x)", func(x: float) -> float: return DetMath.atan2(x, 1.0 - x), func(x: float) -> float: return atan2(x, 1.0 - x), rng, -10.0, 10.0)
	_report("atan2(1,x)", func(x: float) -> float: return DetMath.atan2(1.0, x), func(x: float) -> float: return atan2(1.0, x), rng, -10.0, 10.0)
	_report("acos", func(x: float) -> float: return DetMath.acos(x), func(x: float) -> float: return acos(x), rng, -1.0, 1.0)
	_report("asin", func(x: float) -> float: return DetMath.asin(x), func(x: float) -> float: return asin(x), rng, -1.0, 1.0)
	_report("exp", func(x: float) -> float: return DetMath.exp(x), func(x: float) -> float: return exp(x), rng, -700.0, 700.0)
	_report("log", func(x: float) -> float: return DetMath.log(x), func(x: float) -> float: return log(x), rng, 1e-6, 1e6)
	_report("pow(x,2.5)", func(x: float) -> float: return DetMath.pow(x, 2.5), func(x: float) -> float: return pow(x, 2.5), rng, 0.0, 100.0)
	_report("pow(x,0.37)", func(x: float) -> float: return DetMath.pow(x, 0.37), func(x: float) -> float: return pow(x, 0.37), rng, 0.0, 100.0)
	quit()


func _report(name: String, ours: Callable, libm: Callable, rng: RandomNumberGenerator, low: float, high: float) -> void:
	var worst := 0.0
	var worst_at := 0.0
	var samples := 200_000
	for i in samples:
		var x := rng.randf_range(low, high) if i % 2 == 0 else low + (high - low) * i / samples
		var a: float = ours.call(x)
		var b: float = libm.call(x)
		var ulp := _ulp(b)
		var err := absf(a - b) / ulp if ulp > 0.0 else 0.0
		if err > worst:
			worst = err
			worst_at = x
	print("%-14s [%s, %s]  max %.2f ulp vs libm (at %s)" % [name, low, high, worst, String.num(worst_at, 17)])


func _ulp(x: float) -> float:
	x = absf(x)
	if x == 0.0:
		return 4.9e-324
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, x)
	bytes.encode_s64(0, bytes.decode_s64(0) + 1)
	return bytes.decode_double(0) - x
