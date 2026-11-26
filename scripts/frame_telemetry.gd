extends RefCounted
# Monotonic process-frame intervals, not GPU execution times or Android presentation times.
const WINDOW_US := 10000000
var previous_us := 0
var start_us := 0
var profile := -1
var samples := PackedFloat64Array()
var latest: Dictionary = {}

func reset(now_us: int = 0) -> void:
	previous_us = now_us
	start_us = now_us
	samples.clear()

static func summarize(values: PackedFloat64Array) -> Dictionary:
	if values.is_empty():
		return {}
	var sorted := values.duplicate()
	sorted.sort()
	var count := sorted.size()
	var total := 0.0
	for value in sorted:
		total += value
	var median := (sorted[floori(float(count-1)/2.0)]+sorted[floori(float(count)/2.0)])*0.5
	var tail_count := maxi(1,ceili(count*0.01))
	var tail_total := 0.0
	for i in range(count-tail_count,count):
		tail_total += sorted[i]
	return {"frames":count,"mean_fps":1000.0*count/maxf(total,0.001),
		"median_ms":median,"p95_ms":sorted[ceili(count*0.95)-1],
		"p99_ms":sorted[ceili(count*0.99)-1],
		"one_percent_low_fps":1000.0*tail_count/maxf(tail_total,0.001)}

func record(now_us: int, current_profile: int) -> Dictionary:
	if profile!=current_profile or previous_us==0:
		profile = current_profile
		reset(now_us)
		latest = {}
		return {}
	var gap := now_us-previous_us
	previous_us = now_us
	# Discard clock discontinuities or suspension; do not discard normal slow frames.
	if gap<=0:
		reset(now_us)
		return {}
	samples.append(float(gap)/1000.0)
	if now_us-start_us<WINDOW_US:
		return {}
	var result := summarize(samples)
	result["duration_ms"] = float(now_us-start_us)/1000.0
	result["profile"] = profile
	result["process_ms"] = Performance.get_monitor(Performance.TIME_PROCESS)*1000.0
	result["physics_ms"] = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0
	result["draw_calls"] = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	result["primitives"] = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	result["static_mb"] = Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0
	latest = result
	reset(now_us)
	return result
