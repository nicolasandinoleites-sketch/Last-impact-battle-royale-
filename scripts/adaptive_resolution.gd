extends RefCounted
# Low-profile only. Decisions use monotonic 10 s telemetry windows, not instant FPS.
# Never resize during an active touch, reload, aim or round transition.
const SIZES := [Vector2i(800,450),Vector2i(720,405),Vector2i(640,360)]
var level := 0
var slow_windows := 0
var fast_windows := 0
var pending := -1
var cooldown_windows := 0

func reset() -> void:
	level = 0
	slow_windows = 0
	fast_windows = 0
	pending = -1
	cooldown_windows = 0

func observe(report: Dictionary) -> void:
	if pending>=0 or report.get("duration_ms",0.0)<10000 or report.get("frames",0)<10:
		return
	if cooldown_windows>0:
		cooldown_windows -= 1
		return
	var fps := float(report.get("mean_fps",0.0))
	var p95 := float(report.get("p95_ms",0.0))
	if fps<=0.0 or p95<=0.0 or not is_finite(fps) or not is_finite(p95):
		return
	if fps<25.0 and p95>45.0:
		slow_windows += 1
		fast_windows = 0
	elif fps>=29.0 and p95<=37.0:
		fast_windows += 1
		slow_windows = 0
	else:
		slow_windows = 0
		fast_windows = 0
	if slow_windows>=2 and level<SIZES.size()-1:
		pending = level+1
	elif fast_windows>=4 and level>0:
		pending = level-1

func commit_if_safe(safe: bool) -> bool:
	if pending<0 or not safe:
		return false
	level = pending
	pending = -1
	slow_windows = 0
	fast_windows = 0
	cooldown_windows = 2
	return true

func resolution() -> Vector2i:
	return SIZES[level]
