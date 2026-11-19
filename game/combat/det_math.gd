class_name DetMath
extends RefCounted
## Platform-independent math for the deterministic path (sim, AI, rollback).
##
## libm's sin, cos, atan2, pow, exp and log differ in the last bit between
## glibc, MSVC and wasm, and Godot's Basis(axis, angle), Vector3.rotated(),
## slerp() and angle() call them. Everything here uses only IEEE-754 + - * /,
## sqrt, floor and fmod, which are exact or correctly rounded everywhere, in
## 64-bit floats, with the fdlibm (FreeBSD msun) kernels and constants given
## as exact bit patterns. Accuracy against correctly rounded results (see
## tests/combat/test_det_math.gd and the T-D32 PR for the measured table):
##   sin, cos: <= 1 ulp for |x| < 2^19 * PI/2 (range reduction by Cody-Waite).
##   atan, atan2: <= 1 ulp. asin, acos: <= 2 ulp (atan2 of a sqrt).
##   exp, log: <= 1 ulp. pow: exact by squaring for integer |y| <= 64, else
##   exp(y * log(x)), relative error ~ (1 + |y * ln x|) ulp.
## The sign of zero is ignored by atan2, so -0.0 inputs give the +0.0 result.
## Calls inside this class are written DetMath.sin() and so on: a bare sin()
## resolves to Godot's global (libm) function before this class's own.

const PI_HALF := PI / 2.0

static var _invpio2: float = _bits(0x3FE45F306DC9C883)
static var _pio2_1: float = _bits(0x3FF921FB54400000)
static var _pio2_2: float = _bits(0x3DD0B4611A600000)
static var _pio2_2t: float = _bits(0x3BA3198A2E037073)

static var _s1: float = -_bits(0x3FC5555555555549)
static var _s2: float = _bits(0x3F8111111110F8A6)
static var _s3: float = -_bits(0x3F2A01A019C161D5)
static var _s4: float = _bits(0x3EC71DE357B1FE7D)
static var _s5: float = -_bits(0x3E5AE5E68A2B9CEB)
static var _s6: float = _bits(0x3DE5D93A5ACFD57C)

static var _c1: float = _bits(0x3FA555555555554C)
static var _c2: float = -_bits(0x3F56C16C16C15177)
static var _c3: float = _bits(0x3EFA01A019CB1590)
static var _c4: float = -_bits(0x3E927E4F809C52AD)
static var _c5: float = _bits(0x3E21EE9EBDB4B1C4)
static var _c6: float = -_bits(0x3DA8FAE9BE8838D4)

static var _atanhi: PackedFloat64Array = PackedFloat64Array([_bits(0x3FDDAC670561BB4F),
	_bits(0x3FE921FB54442D18), _bits(0x3FEF730BD281F69B), _bits(0x3FF921FB54442D18)])
static var _atanlo: PackedFloat64Array = PackedFloat64Array([_bits(0x3C7A2B7F222F65E2),
	_bits(0x3C81A62633145C07), _bits(0x3C7007887AF0CBBD), _bits(0x3C91A62633145C07)])
static var _at: PackedFloat64Array = PackedFloat64Array([_bits(0x3FD555555555550D),
	-_bits(0x3FC999999998EBC4), _bits(0x3FC24924920083FF), -_bits(0x3FBC71C6FE231671),
	_bits(0x3FB745CDC54C206E), -_bits(0x3FB3B0F2AF749A6D), _bits(0x3FB10D66A0D03D51),
	-_bits(0x3FADDE2D52DEFD9A), _bits(0x3FA97B4B24760DEB), -_bits(0x3FA2B4442C6A6C2F),
	_bits(0x3F90AD3AE322DA11)])
static var _pi: float = _bits(0x400921FB54442D18)
static var _pi_lo: float = _bits(0x3CA1A62633145C07)

static var _ln2_hi: float = _bits(0x3FE62E42FEE00000)
static var _ln2_lo: float = _bits(0x3DEA39EF35793C76)
static var _invln2: float = _bits(0x3FF71547652B82FE)
static var _p1: float = _bits(0x3FC555555555553E)
static var _p2: float = -_bits(0x3F66C16C16BEBD93)
static var _p3: float = _bits(0x3F11566AAF25DE2C)
static var _p4: float = -_bits(0x3EBBBD41C5D26BF1)
static var _p5: float = _bits(0x3E66376972BEA4D0)
static var _lg: PackedFloat64Array = PackedFloat64Array([_bits(0x3FE5555555555593),
	_bits(0x3FD999999997FA04), _bits(0x3FD2492494229359), _bits(0x3FCC71C51D8E78AF),
	_bits(0x3FC7466496CB03DE), _bits(0x3FC39A09D078C69F), _bits(0x3FC2F112DF3E5244)])
static var _sqrt2: float = _bits(0x3FF6A09E667F3BCD)
static var _head := 0.0
static var _tail := 0.0
static var _sin := 0.0
static var _cos := 0.0


## Sine of x radians.
static func sin(x: float) -> float:
	match _reduce(x) & 3:
		0: return _ksin(_head, _tail)
		1: return _kcos(_head, _tail)
		2: return -_ksin(_head, _tail)
		_: return -_kcos(_head, _tail)


## Cosine of x radians.
static func cos(x: float) -> float:
	match _reduce(x) & 3:
		0: return _kcos(_head, _tail)
		1: return -_ksin(_head, _tail)
		2: return -_kcos(_head, _tail)
		_: return _ksin(_head, _tail)


## Arc tangent in (-PI/2, PI/2).
static func atan(x: float) -> float:
	var ax := absf(x)
	var id := -1
	if ax >= 7.378697629483821e19:  # 2^66
		var big := _atanhi[3] + _atanlo[3]
		return -big if x < 0.0 else big
	if ax < 0.4375:
		if ax < 7.450580596923828e-09:  # 2^-27
			return x
	else:
		if ax < 1.1875:
			if ax < 0.6875:
				id = 0
				ax = (2.0 * ax - 1.0) / (2.0 + ax)
			else:
				id = 1
				ax = (ax - 1.0) / (ax + 1.0)
		elif ax < 2.4375:
			id = 2
			ax = (ax - 1.5) / (1.0 + 1.5 * ax)
		else:
			id = 3
			ax = -1.0 / ax
	var t := x if id < 0 else ax
	var z := t * t
	var w := z * z
	var s1 := z * (_at[0] + w * (_at[2] + w * (_at[4] + w * (_at[6] + w * (_at[8] + w * _at[10])))))
	var s2 := w * (_at[1] + w * (_at[3] + w * (_at[5] + w * (_at[7] + w * _at[9]))))
	if id < 0:
		return t - t * (s1 + s2)
	var result := _atanhi[id] - ((t * (s1 + s2) - _atanlo[id]) - t)
	return -result if x < 0.0 else result


## Angle of (x, y) in [-PI, PI]; the sign of zero is ignored (atan2(-0.0, -1) is PI).
static func atan2(y: float, x: float) -> float:
	if y == 0.0:
		return _pi if x < 0.0 else 0.0
	if x == 0.0:
		return -PI_HALF if y < 0.0 else PI_HALF
	var z := DetMath.atan(absf(y) / absf(x))
	if x > 0.0:
		return -z if y < 0.0 else z
	var back := _pi - (z - _pi_lo)
	return -back if y < 0.0 else back


## Arc cosine in [0, PI] of x clamped to [-1, 1].
static func acos(x: float) -> float:
	x = clampf(x, -1.0, 1.0)
	return DetMath.atan2(sqrt((1.0 - x) * (1.0 + x)), x)


## Arc sine in [-PI/2, PI/2] of x clamped to [-1, 1].
static func asin(x: float) -> float:
	x = clampf(x, -1.0, 1.0)
	return DetMath.atan2(x, sqrt((1.0 - x) * (1.0 + x)))


## e to the power x.
static func exp(x: float) -> float:
	if x > 709.782712893384:
		return INF
	if x < -745.1332191019411:
		return 0.0
	var k := 0
	var hi := x
	var lo := 0.0
	if absf(x) > 0.34657359027997264:  # ln(2) / 2
		k = int(floorf(x * _invln2 + 0.5))
		hi = x - k * _ln2_hi
		lo = k * _ln2_lo
		x = hi - lo
	elif absf(x) < 3.725290298461914e-09:  # 2^-28
		return 1.0 + x
	var t := x * x
	var c := x - t * (_p1 + t * (_p2 + t * (_p3 + t * (_p4 + t * _p5))))
	if k == 0:
		return 1.0 - ((x * c) / (c - 2.0) - x)
	return _scale(1.0 - ((lo - (x * c) / (2.0 - c)) - hi), k)


## Natural logarithm; NAN below zero, -INF at zero.
static func log(x: float) -> float:
	if x < 0.0 or is_nan(x):
		return NAN
	if x == 0.0:
		return -INF
	if is_inf(x):
		return INF
	var k := 0
	if x < 2.2250738585072014e-308:  # subnormal: scale up by 2^54
		x *= 18014398509481984.0
		k = -54
	var bits := _to_bits(x)
	k += ((bits >> 52) & 0x7FF) - 1023
	var m := _bits((bits & 0xFFFFFFFFFFFFF) | 0x3FF0000000000000)
	if m > _sqrt2:
		m *= 0.5
		k += 1
	var f := m - 1.0
	var s := f / (2.0 + f)
	var z := s * s
	var w := z * z
	var t1 := w * (_lg[1] + w * (_lg[3] + w * _lg[5]))
	var t2 := z * (_lg[0] + w * (_lg[2] + w * (_lg[4] + w * _lg[6])))
	var hfsq := 0.5 * f * f
	return k * _ln2_hi - ((hfsq - (s * (hfsq + t1 + t2) + k * _ln2_lo)) - f)


## x to the power y; integer powers up to 64 are exact by repeated squaring.
static func pow(x: float, y: float) -> float:
	if y == 0.0:
		return 1.0
	var whole := floorf(y)
	if y == whole and absf(y) <= 64.0:
		return _int_pow(x, int(y))
	if x == 0.0:
		return 0.0 if y > 0.0 else INF
	if x < 0.0:
		if y != whole:
			return NAN
		var magnitude := DetMath.exp(y * DetMath.log(-x))
		return -magnitude if fmod(absf(y), 2.0) == 1.0 else magnitude
	if absf(whole) <= 64.0:
		# Whole part by squaring, so only the fraction goes through exp(log).
		return _int_pow(x, int(whole)) * DetMath.exp((y - whole) * DetMath.log(x))
	return DetMath.exp(y * DetMath.log(x))


## x modulo y with the sign of y, never -0.0; fmod is exact everywhere.
static func fposmod(x: float, y: float) -> float:
	var r := fmod(x, y)
	if (r < 0.0 and y > 0.0) or (r > 0.0 and y < 0.0):
		r += y
	return r + 0.0


## Angle wrapped into [-PI, PI).
static func wrap_angle(angle: float) -> float:
	return DetMath.fposmod(angle + _pi, TAU) - _pi


## Shortest signed turn from one angle to another, in [-PI, PI).
static func angle_difference(from: float, to: float) -> float:
	return DetMath.wrap_angle(to - from)


## Interpolates between angles the short way round.
static func lerp_angle(from: float, to: float, weight: float) -> float:
	return from + DetMath.angle_difference(from, to) * weight


## Planar unit vector the yaw faces: Basis(Vector3.UP, yaw) * Vector3.FORWARD.
static func forward(yaw: float) -> Vector3:
	_sin_cos(yaw)
	return DetMath.canon(Vector3(-_sin, 0.0, -_cos))


## Yaw that faces along v's planar part, the inverse of forward().
static func yaw_of(v: Vector3) -> float:
	return DetMath.atan2(-v.x, -v.z)


## v turned by angle radians about +Y: Basis(Vector3.UP, angle) * v.
static func rotate_y(v: Vector3, angle: float) -> Vector3:
	_sin_cos(angle)
	var s := _sin
	var c := _cos
	return DetMath.canon(Vector3(v.x * c + v.z * s, v.y, v.z * c - v.x * s))


## v turned by angle radians about +X: Basis(Vector3.RIGHT, angle) * v.
static func rotate_x(v: Vector3, angle: float) -> Vector3:
	_sin_cos(angle)
	var s := _sin
	var c := _cos
	return DetMath.canon(Vector3(v.x, v.y * c - v.z * s, v.y * s + v.z * c))


## Rotation by angle radians about the unit axis, like Basis(axis, angle).
static func axis_angle(axis: Vector3, angle: float) -> Basis:
	_sin_cos(angle)
	var s := _sin
	var c := _cos
	var t := 1.0 - c
	var x := axis.x
	var y := axis.y
	var z := axis.z
	return Basis(
		Vector3(x * x * t + c, x * y * t + z * s, x * z * t - y * s),
		Vector3(x * y * t - z * s, y * y * t + c, y * z * t + x * s),
		Vector3(x * z * t + y * s, y * z * t - x * s, z * z * t + c))


## v with -0.0 components turned into +0.0, so state and hashes are canonical.
static func canon(v: Vector3) -> Vector3:
	return v + Vector3.ZERO


## Rounds x to the nearest float32 (Vector3 and Basis store float32), explicitly.
static func to_f32(x: float) -> float:
	return Vector3(x, 0.0, 0.0).x


# Sine and cosine of x into _sin and _cos, from one range reduction.
static func _sin_cos(x: float) -> void:
	match _reduce(x) & 3:
		0:
			_sin = _ksin(_head, _tail)
			_cos = _kcos(_head, _tail)
		1:
			_sin = _kcos(_head, _tail)
			_cos = -_ksin(_head, _tail)
		2:
			_sin = -_ksin(_head, _tail)
			_cos = -_kcos(_head, _tail)
		_:
			_sin = -_kcos(_head, _tail)
			_cos = _ksin(_head, _tail)


# x^n by repeated squaring.
static func _int_pow(x: float, n: int) -> float:
	var result := 1.0
	var base := x
	var left := absi(n)
	while left > 0:
		if left & 1:
			result *= base
		base *= base
		left >>= 1
	return 1.0 / result if n < 0 else result


# x * 2^k, exact unless the result over- or underflows.
static func _scale(x: float, k: int) -> float:
	if k > 1023:
		return x * _bits(0x7FE0000000000000) * _bits(k << 52)
	if k < -1021:
		return x * _bits((k + 54 + 1023) << 52) * _bits((1023 - 54) << 52)
	return x * _bits((k + 1023) << 52)


# Quadrant n of x - n * PI/2; leaves the remainder in _head + _tail, |_head| <= PI/4.
static func _reduce(x: float) -> int:
	var n := floorf(x * _invpio2 + 0.5)
	var t := x - n * _pio2_1
	var w := n * _pio2_2
	var r := t - w
	w = n * _pio2_2t - ((t - r) - w)
	_head = r - w
	_tail = (r - _head) - w
	return int(n)


static func _ksin(x: float, y: float) -> float:
	var z := x * x
	var v := z * x
	var r := _s2 + z * (_s3 + z * (_s4 + z * (_s5 + z * _s6)))
	return x - ((z * (0.5 * y - v * r) - y) - v * _s1)


static func _kcos(x: float, y: float) -> float:
	var z := x * x
	var w := z * z
	var r := z * (_c1 + z * (_c2 + z * _c3)) + w * w * (_c4 + z * (_c5 + z * _c6))
	var hz := 0.5 * z
	var one_minus := 1.0 - hz
	return one_minus + (((1.0 - one_minus) - hz) + (z * r - x * y))


static func _bits(bits: int) -> float:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_s64(0, bits)
	return bytes.decode_double(0)


static func _to_bits(x: float) -> int:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, x)
	return bytes.decode_s64(0)
