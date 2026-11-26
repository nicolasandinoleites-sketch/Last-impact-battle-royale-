extends Node
var fire_player: AudioStreamPlayer
var reload_player: AudioStreamPlayer
var hit_player: AudioStreamPlayer

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
