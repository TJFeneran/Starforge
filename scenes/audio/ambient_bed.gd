extends Node
## Persistent hub ambient bed — welcome, pause, and lobby share one loop.

const BED_PATH := "res://assets/audio/lobby/511493__the_toothpaste_vampires__ambient-space-noise-1-30bpm-6m-24s.wav"

@export_range(-40.0, 0.0, 0.1) var volume_db: float = -6.0
@export_range(0.1, 5.0, 0.05) var fade_in_sec: float = 1.5
@export_range(0.5, 4.0, 0.05) var loop_crossfade_sec: float = 2.0

var _stream: AudioStream
var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _active_is_a := true
var _crossfading := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_a = AudioStreamPlayer.new()
	_b = AudioStreamPlayer.new()
	_a.name = "BedA"
	_b.name = "BedB"
	_a.bus = &"Ambience"
	_b.bus = &"Ambience"
	add_child(_a)
	add_child(_b)
	_stream = _load_bed()
	if _stream == null:
		push_warning("AmbientBed: missing bed stream at %s" % BED_PATH)
		return
	_a.stream = _stream
	_b.stream = _stream
	_b.volume_db = -80.0
	_a.volume_db = -40.0
	_a.play()
	create_tween().tween_property(_a, "volume_db", volume_db, fade_in_sec).from(-40.0)


func _process(_delta: float) -> void:
	if _stream == null or _crossfading:
		return
	var active: AudioStreamPlayer = _a if _active_is_a else _b
	if not active.playing:
		return
	var length := _stream.get_length()
	if length <= loop_crossfade_sec + 0.05:
		return
	if active.get_playback_position() < length - loop_crossfade_sec:
		return
	_crossfading = true
	var fading_out := _a if _active_is_a else _b
	var fading_in := _b if _active_is_a else _a
	fading_in.volume_db = -80.0
	fading_in.play(0.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(fading_out, "volume_db", -80.0, loop_crossfade_sec)
	tween.tween_property(fading_in, "volume_db", volume_db, loop_crossfade_sec)
	tween.chain().tween_callback(func() -> void:
		fading_out.stop()
		_active_is_a = not _active_is_a
		_crossfading = false
	)


func _load_bed() -> AudioStream:
	if not ResourceLoader.exists(BED_PATH):
		return null
	var stream := load(BED_PATH) as AudioStream
	if stream == null:
		return null
	var wav := stream as AudioStreamWAV
	if wav != null:
		wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return stream
