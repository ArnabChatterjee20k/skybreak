class_name DetMath
extends RefCounted
## Platform-independent math for the deterministic path (sim, AI, rollback).
##
## libm's sin, cos, atan2, pow, exp and log differ in the last bit between
## glibc, MSVC and wasm, and Godot's Basis(axis, angle), Vector3.rotated(),
## slerp() and angle() call them. Everything here uses only IEEE-754 + - * /,
## sqrt, floor and fmod, which are exact or correctly rounded everywhere, in
## 64-bit floats, with the fdlibm (FreeBSD msun) kernels. Worst error against
## glibc, measured by tools/diag/det_math_accuracy.gd:
##   sin, cos: 1 ulp for |x| < 2^19 * PI/2 (Cody-Waite range reduction).
##   atan, atan2, exp, log: 1 ulp. acos, asin: 2 ulp (atan2 of a sqrt).
##   pow: exact by squaring for integer |y| <= 64; else the whole part by
##   squaring times exp(fraction * log(x)), 4 ulp; |y| > 64: (1 + |y ln x|) ulp.
## The sign of zero is ignored by atan2, so -0.0 inputs give the +0.0 result.
## Constants are exact fdlibm bit patterns, built as integer / 2^k (Godot's own
## decimal parser is not correctly rounded); test_det_math.gd checks every one.
## Calls inside this class are written DetMath.sin() and so on: a bare sin()
## resolves to Godot's global (libm) function before this class's own.

const PI_HALF := PI / 2.0

const _INVPIO2 := float(5734161139222659) / float(1 << 53)
const _PIO2_1 := float(1686629713) / float(1 << 30)
const _PIO2_2 := float(2242054355) / float(1 << 62) / float(1 << 3)
const _PIO2_2T := float(5376105825661043) / float(1 << 62) / float(1 << 59)

const _S1 := -float(6004799503160649) / float(1 << 55)
const _S2 := float(2401919801261139) / float(1 << 58)
const _S3 := -float(7320136532976085) / float(1 << 62) / float(1 << 3)
const _S4 := float(6506786730409597) / float(1 << 62) / float(1 << 9)
const _S5 := -float(7571127717829867) / float(1 << 62) / float(1 << 16)
const _S6 := float(1537454791456095) / float(1 << 62) / float(1 << 21)

const _C1 := float(1501199875790163) / float(1 << 55)
const _C2 := -float(6405119470031223) / float(1 << 62)
const _C3 := float(457508533350745) / float(1 << 62) / float(1 << 2)
const _C4 := -float(5205429506036397) / float(1 << 62) / float(1 << 12)
const _C5 := float(1261860039765105) / float(1 << 62) / float(1 << 17)
const _C6 := -float(1757820317994549) / float(1 << 62) / float(1 << 25)

const _ATANHI0 := float(8352332796509007) / float(1 << 54)
const _ATANHI1 := float(884279719003555) / float(1 << 50)
const _ATANHI2 := float(8852218891597467) / float(1 << 53)
const _ATANHI3 := float(884279719003555) / float(1 << 49)
const _ATANLO0 := float(3683087214424817) / float(1 << 62) / float(1 << 45)
const _ATANLO1 := float(4967757600021511) / float(1 << 62) / float(1 << 45)
const _ATANLO2 := float(4511882386918333) / float(1 << 62) / float(1 << 46)
const _ATANLO3 := float(4967757600021511) / float(1 << 62) / float(1 << 44)
const _ATANHI: Array[float] = [_ATANHI0, _ATANHI1, _ATANHI2, _ATANHI3]
const _ATANLO: Array[float] = [_ATANLO0, _ATANLO1, _ATANLO2, _ATANLO3]
const _AT0 := float(6004799503160589) / float(1 << 54)
const _AT1 := -float(1801439850937073) / float(1 << 53)
const _AT2 := float(5146970997949439) / float(1 << 55)
const _AT3 := -float(8006398829074033) / float(1 << 56)
const _AT4 := float(3275337272528951) / float(1 << 55)
const _AT5 := -float(5542580929731181) / float(1 << 56)
const _AT6 := float(4799809039908177) / float(1 << 56)
const _AT7 := -float(4203530284924621) / float(1 << 56)
const _AT8 := float(7172437082246635) / float(1 << 57)
const _AT9 := -float(5264754476739631) / float(1 << 57)
const _AT10 := float(4694068057790993) / float(1 << 58)
const _PI := float(884279719003555) / float(1 << 48)
const _PI_LO := float(4967757600021511) / float(1 << 62) / float(1 << 43)

const _LN2_HI := float(2977044471) / float(1 << 32)
const _LN2_LO := float(3691024475790907) / float(1 << 62) / float(1 << 22)
const _INVLN2 := float(3248660424278399) / float(1 << 51)
const _P1 := float(3002399751580319) / float(1 << 54)
const _P2 := -float(6405119469862291) / float(1 << 61)
const _P3 := float(1220022702274443) / float(1 << 62) / float(1 << 2)
const _P4 := -float(7807914560613361) / float(1 << 62) / float(1 << 10)
const _P5 := float(390835970239053) / float(1 << 62) / float(1 << 11)
const _LG0 := float(6004799503160723) / float(1 << 53)
const _LG1 := float(1801439850921601) / float(1 << 52)
const _LG2 := float(5146971033736025) / float(1 << 54)
const _LG3 := float(8006390766270639) / float(1 << 55)
const _LG4 := float(3275661152453103) / float(1 << 54)
const _LG5 := float(5517391500461727) / float(1 << 55)
const _LG6 := float(1332903234475153) / float(1 << 53)
const _SQRT2 := float(6369051672525773) / float(1 << 52)
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
		var big := _ATANHI3 + _ATANLO3
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
	var s1 := z * (_AT0 + w * (_AT2 + w * (_AT4 + w * (_AT6 + w * (_AT8 + w * _AT10)))))
	var s2 := w * (_AT1 + w * (_AT3 + w * (_AT5 + w * (_AT7 + w * _AT9))))
	if id < 0:
		return t - t * (s1 + s2)
	var result := _ATANHI[id] - ((t * (s1 + s2) - _ATANLO[id]) - t)
	return -result if x < 0.0 else result


## Angle of (x, y) in [-PI, PI]; the sign of zero is ignored (atan2(-0.0, -1) is PI).
static func atan2(y: float, x: float) -> float:
	if y == 0.0:
		return _PI if x < 0.0 else 0.0
	if x == 0.0:
		return -PI_HALF if y < 0.0 else PI_HALF
	var z := DetMath.atan(absf(y) / absf(x))
	if x > 0.0:
		return -z if y < 0.0 else z
	var back := _PI - (z - _PI_LO)
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
		k = int(floorf(x * _INVLN2 + 0.5))
		hi = x - k * _LN2_HI
		lo = k * _LN2_LO
		x = hi - lo
	elif absf(x) < 3.725290298461914e-09:  # 2^-28
		return 1.0 + x
	var t := x * x
	var c := x - t * (_P1 + t * (_P2 + t * (_P3 + t * (_P4 + t * _P5))))
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
	if m > _SQRT2:
		m *= 0.5
		k += 1
	var f := m - 1.0
	var s := f / (2.0 + f)
	var z := s * s
	var w := z * z
	var t1 := w * (_LG1 + w * (_LG3 + w * _LG5))
	var t2 := z * (_LG0 + w * (_LG2 + w * (_LG4 + w * _LG6)))
	var hfsq := 0.5 * f * f
	return k * _LN2_HI - ((hfsq - (s * (hfsq + t1 + t2) + k * _LN2_LO)) - f)


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
	return DetMath.fposmod(angle + _PI, TAU) - _PI


## Shortest signed turn from one angle to another, in [-PI, PI).
static func angle_difference(from: float, to: float) -> float:
	return DetMath.wrap_angle(to - from)


## Interpolates between angles the short way round.
static func lerp_angle(from: float, to: float, weight: float) -> float:
	return from + DetMath.angle_difference(from, to) * weight


## Planar unit vector the yaw faces: Basis(Vector3.UP, yaw) * Vector3.FORWARD.
static func forward(yaw: float) -> Vector3:
	_sin_cos(yaw)
	return Vector3(-_sin, 0.0, -_cos) + Vector3.ZERO


## Yaw that faces along v's planar part, the inverse of forward().
static func yaw_of(v: Vector3) -> float:
	return DetMath.atan2(-v.x, -v.z)


## v turned by angle radians about +Y: Basis(Vector3.UP, angle) * v.
static func rotate_y(v: Vector3, angle: float) -> Vector3:
	_sin_cos(angle)
	var s := _sin
	var c := _cos
	return Vector3(v.x * c + v.z * s, v.y, v.z * c - v.x * s) + Vector3.ZERO


## v turned by angle radians about +X: Basis(Vector3.RIGHT, angle) * v.
static func rotate_x(v: Vector3, angle: float) -> Vector3:
	_sin_cos(angle)
	var s := _sin
	var c := _cos
	return Vector3(v.x, v.y * c - v.z * s, v.y * s + v.z * c) + Vector3.ZERO


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


# Sine and cosine of x into _sin and _cos: _reduce, _ksin and _kcos inlined, as calls dominate the cost.
static func _sin_cos(x: float) -> void:
	var n := floorf(x * _INVPIO2 + 0.5)
	var t := x - n * _PIO2_1
	var w := n * _PIO2_2
	var r := t - w
	w = n * _PIO2_2T - ((t - r) - w)
	var hx := r - w
	var tx := (r - hx) - w
	var z := hx * hx
	var v := z * hx
	var sr := _S2 + z * (_S3 + z * (_S4 + z * (_S5 + z * _S6)))
	var s := hx - ((z * (0.5 * tx - v * sr) - tx) - v * _S1)
	var zz := z * z
	var cr := z * (_C1 + z * (_C2 + z * _C3)) + zz * zz * (_C4 + z * (_C5 + z * _C6))
	var hz := 0.5 * z
	var one_minus := 1.0 - hz
	var c := one_minus + (((1.0 - one_minus) - hz) + (z * cr - hx * tx))
	match int(n) & 3:
		0:
			_sin = s
			_cos = c
		1:
			_sin = c
			_cos = -s
		2:
			_sin = -s
			_cos = -c
		_:
			_sin = -c
			_cos = s


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
	var n := floorf(x * _INVPIO2 + 0.5)
	var t := x - n * _PIO2_1
	var w := n * _PIO2_2
	var r := t - w
	w = n * _PIO2_2T - ((t - r) - w)
	_head = r - w
	_tail = (r - _head) - w
	return int(n)


static func _ksin(x: float, y: float) -> float:
	var z := x * x
	var v := z * x
	var r := _S2 + z * (_S3 + z * (_S4 + z * (_S5 + z * _S6)))
	return x - ((z * (0.5 * y - v * r) - y) - v * _S1)


static func _kcos(x: float, y: float) -> float:
	var z := x * x
	var w := z * z
	var r := z * (_C1 + z * (_C2 + z * _C3)) + w * w * (_C4 + z * (_C5 + z * _C6))
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
