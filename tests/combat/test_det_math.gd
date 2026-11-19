extends GutTest
## DetMath is the platform-independent math of the deterministic path (T-D32).


func test_sin_cos_and_atan2_stay_within_2_ulp_of_libm() -> void:
	var worst := 0.0
	for i in 4_001:
		var x := (i - 2_000) * 0.01234
		worst = maxf(worst, _ulps(DetMath.sin(x), sin(x)))
		worst = maxf(worst, _ulps(DetMath.cos(x), cos(x)))
		worst = maxf(worst, _ulps(DetMath.atan2(x, 1.5 - x * 0.5), atan2(x, 1.5 - x * 0.5)))
		worst = maxf(worst, _ulps(DetMath.atan2(-1.0, x), atan2(-1.0, x)))
	assert_lte(worst, 2.0)


func test_inverse_trig_exp_log_and_pow_stay_close_to_libm() -> void:
	var worst := 0.0
	for i in 2_001:
		var t := (i - 1_000) / 1_000.0
		worst = maxf(worst, _ulps(DetMath.acos(t), acos(t)))
		worst = maxf(worst, _ulps(DetMath.asin(t), asin(t)))
		worst = maxf(worst, _ulps(DetMath.exp(t * 50.0), exp(t * 50.0)))
		worst = maxf(worst, _ulps(DetMath.log(absf(t) * 70.0 + 0.01), log(absf(t) * 70.0 + 0.01)))
		worst = maxf(worst, _ulps(DetMath.pow(absf(t) * 9.0, 1.8), pow(absf(t) * 9.0, 1.8)))
	assert_lte(worst, 4.0)


func test_exact_cases() -> void:
	assert_eq(DetMath.sin(0.0), 0.0)
	assert_eq(DetMath.cos(0.0), 1.0)
	assert_eq(DetMath.atan2(0.0, -1.0), PI)
	assert_eq(DetMath.atan2(1.0, 0.0), PI / 2.0)
	assert_eq(DetMath.atan2(0.0, 0.0), 0.0)
	assert_eq(DetMath.pow(3.0, 4.0), 81.0)
	assert_eq(DetMath.pow(2.0, -2.0), 0.25)
	assert_eq(DetMath.exp(0.0), 1.0)
	assert_eq(DetMath.log(1.0), 0.0)
	assert_eq(DetMath.acos(1.0), 0.0)


func test_atan2_ignores_the_sign_of_zero() -> void:
	var negative_zero := 0.0
	negative_zero = -negative_zero
	assert_true(_sign_bit(negative_zero))
	assert_eq(DetMath.atan2(negative_zero, -1.0), PI)
	assert_false(_sign_bit(DetMath.atan2(negative_zero, 1.0)))


func test_canon_turns_negative_zero_into_positive_zero() -> void:
	# Built at run time: GDScript pools a -0.0 literal with 0.0, as they compare equal.
	var negative_zero := 0.0
	negative_zero = -negative_zero
	var raw := Vector3(negative_zero, 1.0, negative_zero)
	assert_ne(var_to_bytes(raw), var_to_bytes(Vector3(0, 1, 0)), "the raw vector has -0.0")
	assert_eq(var_to_bytes(DetMath.canon(raw)), var_to_bytes(Vector3(0, 1, 0)))


func test_forward_and_rotations_match_godots_basis_within_float32_rounding() -> void:
	for i in 64:
		var yaw := (i - 32) * 0.2
		var basis := Basis(Vector3.UP, yaw)
		assert_almost_eq(DetMath.forward(yaw), basis * Vector3.FORWARD, Vector3.ONE * 1e-6)
		assert_almost_eq(DetMath.rotate_y(Vector3(1, 2, 3), yaw), basis * Vector3(1, 2, 3), Vector3.ONE * 1e-5)
		assert_almost_eq(DetMath.rotate_x(Vector3(1, 2, 3), yaw), Basis(Vector3.RIGHT, yaw) * Vector3(1, 2, 3),
			Vector3.ONE * 1e-5)
		var axis := Vector3(1, 2, -0.5).normalized()
		assert_almost_eq(DetMath.axis_angle(axis, yaw) * Vector3(0.3, -1, 2), Basis(axis, yaw) * Vector3(0.3, -1, 2),
			Vector3.ONE * 1e-5)
		assert_almost_eq(DetMath.yaw_of(DetMath.forward(yaw)), DetMath.wrap_angle(yaw), 1e-6)


func test_wrap_angle_and_angle_difference_take_the_short_way() -> void:
	assert_almost_eq(DetMath.wrap_angle(3.0 * PI), -PI, 1e-12)
	assert_almost_eq(DetMath.angle_difference(0.1, TAU - 0.1), -0.2, 1e-12)
	assert_almost_eq(DetMath.lerp_angle(PI - 0.1, -PI + 0.1, 0.5), PI, 1e-12)
	assert_eq(DetMath.fposmod(-1.0, 3.0), 2.0)
	assert_false(_sign_bit(DetMath.fposmod(-3.0, 3.0)))


func _ulps(a: float, b: float) -> float:
	var ulp := absf(_next_up(absf(b)) - absf(b))
	return absf(a - b) / maxf(ulp, 4.9e-324)


func _next_up(x: float) -> float:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, x)
	bytes.encode_s64(0, bytes.decode_s64(0) + 1)
	return bytes.decode_double(0)


func _sign_bit(x: float) -> bool:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, x)
	return bytes.decode_s64(0) < 0
