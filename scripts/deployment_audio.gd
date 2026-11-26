extends Node
# Original synthesized sounds. Two loop voices and one event voice; no per-frame allocations.
const BASE := "res://assets/audio/deployment/"
var engine: AudioStreamPlayer
var wind: AudioStreamPlayer
var cue: AudioStreamPlayer
var clips: Dictionary = {}
var motor_gain := 0.0
var wind_gain := 0.0
var last_phase := -1
var ramp_started := false
var green_signal := false
var muted := false
var event_count := 0

func _ready() -> void:
 for id in ["turbines","airflow","ramp","ready","wings","touchdown"]:
  var stream := load(BASE+id+".wav") as AudioStreamWAV
  if id in ["turbines","airflow"]:
   stream = stream.duplicate() as AudioStreamWAV
   stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
   stream.loop_begin = 0
   stream.loop_end = roundi(stream.get_length()*stream.mix_rate)
  clips[id] = stream
 engine = voice("turbines")
 wind = voice("airflow")
 cue = voice("ready")
 reset()

func voice(id: String) -> AudioStreamPlayer:
 var p := AudioStreamPlayer.new()
 p.stream = clips[id]
 p.volume_db = -60.0
 add_child(p)
 return p

func event(id: String) -> void:
 if muted: return
 cue.stream = clips[id]
 cue.volume_db = -15.0
 cue.play()
 event_count += 1

func loop_voice(p: AudioStreamPlayer, gain: float, pitch: float) -> void:
 p.volume_db = linear_to_db(maxf(0.001,gain))
 p.pitch_scale = pitch
 if gain>0.008 and not p.playing: p.play()
 elif gain<=0.008 and p.playing: p.stop()

func step(dt: float, phase: int, speed: float, ramp_opening: float, requested: bool) -> void:
 if muted: return
 var motor_target := 0.0
 var wind_target := 0.0
 if phase==0: motor_target = 0.40
 elif phase==1:
  motor_target = 0.18+0.16*ramp_opening
  wind_target = 0.10*ramp_opening
 elif phase==2: wind_target = 0.16+0.40*clampf(speed/23.0,0.0,1.0)
 elif phase==3:
  motor_target = 0.13
  wind_target = 0.13+0.16*clampf(speed/12.0,0.0,1.0)
 if phase==1 and requested and not ramp_started:
  event("ramp")
  ramp_started = true
 if phase==1 and ramp_opening>=0.99 and not green_signal:
  event("ready")
  green_signal = true
 if phase!=last_phase:
  if phase==3: event("wings")
  elif phase==4: event("touchdown")
 last_phase = phase
 var blend := 1.0-exp(-dt*7.0)
 motor_gain = lerpf(motor_gain,motor_target,blend)
 wind_gain = lerpf(wind_gain,wind_target,blend)
 loop_voice(engine,motor_gain,0.85 if phase==1 else 1.0)
 loop_voice(wind,wind_gain,0.85+0.3*clampf(speed/23.0,0.0,1.0))

func reset() -> void:
 for p in [engine,wind,cue]:
  if is_instance_valid(p): p.stop()
 motor_gain = 0.0
 wind_gain = 0.0
 last_phase = -1
 ramp_started = false
 green_signal = false
 event_count = 0

func _notification(what: int) -> void:
 if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT]:
  muted = true
  for p in [engine,wind,cue]:
   if is_instance_valid(p): p.stop()
  motor_gain = 0.0
  wind_gain = 0.0
 elif what in [NOTIFICATION_APPLICATION_RESUMED,NOTIFICATION_APPLICATION_FOCUS_IN]:
  muted = false
