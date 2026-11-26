extends Node
var fire_player: AudioStreamPlayer
var reload_player: AudioStreamPlayer
var hit_player: AudioStreamPlayer
var wind_player: AudioStreamPlayer

func _ready() -> void:
	fire_player = make_player(0.105,93.0,0.70)
	reload_player = make_player(0.24,420.0,0.22)
	hit_player = make_player(0.095,780.0,0.10)

func make_player(duration: float, frequency: float, noise_level: float) -> AudioStreamPlayer:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var samples := int(duration*stream.mix_rate)
	var bytes := PackedByteArray()
	bytes.resize(samples*2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 619
	for i in range(samples):
		var t := float(i)/stream.mix_rate
		var envelope := exp(-t/duration*7.0)*minf(1.0,t*700.0)
		var wave := sin(TAU*frequency*t)*(1.0-noise_level)+rng.randf_range(-1.0,1.0)*noise_level
		bytes.encode_s16(i*2,int(clampf(wave*envelope,-1.0,1.0)*18000.0))
	stream.data = bytes
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = -9.0
	add_child(p)
	return p

func prepare_storm() -> void:
	if not is_instance_valid(wind_player):
		wind_player = make_wind()

func set_storm_exposure(amount: float) -> void:
	if amount<0.02:
		if is_instance_valid(wind_player) and wind_player.playing:
			wind_player.stop()
		return
	if not is_instance_valid(wind_player):
		wind_player = make_wind()
	wind_player.volume_db = linear_to_db(maxf(0.001,amount*0.28))
	if not wind_player.playing:
		wind_player.play()

func make_wind() -> AudioStreamPlayer:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 16000
	var count := stream.mix_rate*4
	var bytes := PackedByteArray()
	bytes.resize(count*2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 751
	var low := 0.0
	var middle := 0.0
	for i in range(count):
		var t := float(i)/float(count)
		var n := rng.randf_range(-1.0,1.0)
		low = lerpf(low,n,0.018)
		middle = lerpf(middle,n,0.12)
		var fade := minf(1.0,minf(t,1.0-t)*35.0)
		var gust := 0.72+0.20*sin(t*TAU*2.0)+0.08*cos(t*TAU*3.0)
		var sample := clampf((low*2.5+middle*0.8)*fade*gust,-1.0,1.0)
		bytes.encode_s16(i*2,int(sample*22000.0))
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = count
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = -45.0
	add_child(p)
	return p
