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


func test_every_constant_is_exactly_its_fdlibm_bit_pattern() -> void:
	var pairs := [
		[DetMath._INVPIO2, 0x3FE45F306DC9C883],
		[DetMath._PIO2_1, 0x3FF921FB54400000],
		[DetMath._PIO2_2, 0x3DD0B4611A600000],
		[DetMath._PIO2_2T, 0x3BA3198A2E037073],
		[DetMath._S1, -0x3FC5555555555549],
		[DetMath._S2, 0x3F8111111110F8A6],
		[DetMath._S3, -0x3F2A01A019C161D5],
		[DetMath._S4, 0x3EC71DE357B1FE7D],
		[DetMath._S5, -0x3E5AE5E68A2B9CEB],
		[DetMath._S6, 0x3DE5D93A5ACFD57C],
		[DetMath._C1, 0x3FA555555555554C],
		[DetMath._C2, -0x3F56C16C16C15177],
		[DetMath._C3, 0x3EFA01A019CB1590],
		[DetMath._C4, -0x3E927E4F809C52AD],
		[DetMath._C5, 0x3E21EE9EBDB4B1C4],
		[DetMath._C6, -0x3DA8FAE9BE8838D4],
		[DetMath._PI, 0x400921FB54442D18],
		[DetMath._PI_LO, 0x3CA1A62633145C07],
		[DetMath._LN2_HI, 0x3FE62E42FEE00000],
		[DetMath._LN2_LO, 0x3DEA39EF35793C76],
		[DetMath._INVLN2, 0x3FF71547652B82FE],
		[DetMath._P1, 0x3FC555555555553E],
		[DetMath._P2, -0x3F66C16C16BEBD93],
		[DetMath._P3, 0x3F11566AAF25DE2C],
		[DetMath._P4, -0x3EBBBD41C5D26BF1],
		[DetMath._P5, 0x3E66376972BEA4D0],
		[DetMath._SQRT2, 0x3FF6A09E667F3BCD],
		[DetMath._ATANHI0, 0x3FDDAC670561BB4F],
		[DetMath._ATANHI1, 0x3FE921FB54442D18],
		[DetMath._ATANHI2, 0x3FEF730BD281F69B],
		[DetMath._ATANHI3, 0x3FF921FB54442D18],
		[DetMath._ATANLO0, 0x3C7A2B7F222F65E2],
		[DetMath._ATANLO1, 0x3C81A62633145C07],
		[DetMath._ATANLO2, 0x3C7007887AF0CBBD],
		[DetMath._ATANLO3, 0x3C91A62633145C07],
		[DetMath._AT0, 0x3FD555555555550D],
		[DetMath._AT1, -0x3FC999999998EBC4],
		[DetMath._AT2, 0x3FC24924920083FF],
		[DetMath._AT3, -0x3FBC71C6FE231671],
		[DetMath._AT4, 0x3FB745CDC54C206E],
		[DetMath._AT5, -0x3FB3B0F2AF749A6D],
		[DetMath._AT6, 0x3FB10D66A0D03D51],
		[DetMath._AT7, -0x3FADDE2D52DEFD9A],
		[DetMath._AT8, 0x3FA97B4B24760DEB],
		[DetMath._AT9, -0x3FA2B4442C6A6C2F],
		[DetMath._AT10, 0x3F90AD3AE322DA11],
		[DetMath._LG0, 0x3FE5555555555593],
		[DetMath._LG1, 0x3FD999999997FA04],
		[DetMath._LG2, 0x3FD2492494229359],
		[DetMath._LG3, 0x3FCC71C51D8E78AF],
		[DetMath._LG4, 0x3FC7466496CB03DE],
		[DetMath._LG5, 0x3FC39A09D078C69F],
		[DetMath._LG6, 0x3FC2F112DF3E5244],
	]
	for pair in pairs:
		var bits: int = pair[1]
		var expected := -DetMath._bits(-bits) if bits < 0 else DetMath._bits(bits)
		assert_eq(_to_bits(pair[0]), _to_bits(expected), "constant %s" % expected)


func _to_bits(x: float) -> int:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, x)
	return bytes.decode_s64(0)


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
