extends Node
## Player settings. Autoloaded as `GameSettings`.
## Video settings apply to the main window immediately and persist to user://settings.cfg.
## On a fresh install nothing is applied at launch, so project.godot still decides the
## initial window; once the player picks a video setting it is restored every launch.

signal video_changed

enum DisplayMode { WINDOWED, FULLSCREEN, EXCLUSIVE_FULLSCREEN }

const SETTINGS_PATH := "user://settings.cfg"
const VIDEO_SECTION := "video"
const MIN_RESOLUTION := Vector2i(640, 360)
const DISPLAY_MODE_LABELS := {
	DisplayMode.WINDOWED: "Windowed",
	DisplayMode.FULLSCREEN: "Fullscreen",
	DisplayMode.EXCLUSIVE_FULLSCREEN: "Exclusive Fullscreen",
}
const COMMON_RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3440, 1440),
	Vector2i(3840, 2160),
]

var display_mode := DisplayMode.WINDOWED
var resolution := Vector2i(1920, 1080)

var _config := ConfigFile.new()
var _has_saved_video := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_read_window_state()
	_load()
	if _has_saved_video:
		apply_video()


static func display_mode_label(mode: DisplayMode) -> String:
	return DISPLAY_MODE_LABELS.get(mode, "Windowed")


func set_display_mode(mode: DisplayMode) -> void:
	display_mode = mode
	apply_video()
	save()


func set_resolution(size: Vector2i) -> void:
	resolution = size
	apply_video()
	save()


func get_screen_size() -> Vector2i:
	return DisplayServer.screen_get_size(get_window().current_screen)


## Common 16:9 sizes that fit the current display, plus the native size and the
## active resolution, sorted small to large.
func get_resolution_options() -> Array[Vector2i]:
	var screen := get_screen_size()
	var options: Array[Vector2i] = []
	for res in COMMON_RESOLUTIONS:
		if res.x <= screen.x and res.y <= screen.y:
			options.append(res)
	for extra: Vector2i in [screen, resolution]:
		if extra.x >= MIN_RESOLUTION.x and extra.y >= MIN_RESOLUTION.y and not options.has(extra):
			options.append(extra)
	options.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x < b.x if a.x != b.x else a.y < b.y)
	return options


func describe_video() -> String:
	if display_mode == DisplayMode.WINDOWED:
		return "Windowed %d × %d" % [resolution.x, resolution.y]
	return display_mode_label(display_mode)


func apply_video() -> void:
	var window := get_window()
	match display_mode:
		DisplayMode.WINDOWED:
			window.mode = Window.MODE_WINDOWED
			window.borderless = false
			window.size = resolution
			_center_window(window)
		DisplayMode.FULLSCREEN:
			window.mode = Window.MODE_FULLSCREEN
		DisplayMode.EXCLUSIVE_FULLSCREEN:
			window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	video_changed.emit()


func save() -> void:
	_config.set_value(VIDEO_SECTION, "display_mode", int(display_mode))
	_config.set_value(VIDEO_SECTION, "resolution", resolution)
	var err := _config.save(SETTINGS_PATH)
	if err != OK:
		push_warning("GameSettings: could not save %s (%s)" % [SETTINGS_PATH, error_string(err)])
		return
	_has_saved_video = true


func _center_window(window: Window) -> void:
	var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
	window.position = usable.position + (usable.size - window.size) / 2


## Seed defaults from however project.godot launched the window.
func _read_window_state() -> void:
	var window := get_window()
	display_mode = _mode_from_window(window.mode)
	if display_mode == DisplayMode.WINDOWED:
		resolution = window.size
		return
	var width := int(ProjectSettings.get_setting("display/window/size/window_width_override", 0))
	var height := int(ProjectSettings.get_setting("display/window/size/window_height_override", 0))
	if width <= 0 or height <= 0:
		width = int(ProjectSettings.get_setting("display/window/size/viewport_width", 1920))
		height = int(ProjectSettings.get_setting("display/window/size/viewport_height", 1080))
	resolution = Vector2i(width, height)


func _mode_from_window(mode: Window.Mode) -> DisplayMode:
	match mode:
		Window.MODE_FULLSCREEN:
			return DisplayMode.FULLSCREEN
		Window.MODE_EXCLUSIVE_FULLSCREEN:
			return DisplayMode.EXCLUSIVE_FULLSCREEN
		_:
			return DisplayMode.WINDOWED


func _load() -> void:
	if _config.load(SETTINGS_PATH) != OK:
		return
	if not _config.has_section(VIDEO_SECTION):
		return
	_has_saved_video = true
	var mode_value := int(_config.get_value(VIDEO_SECTION, "display_mode", int(display_mode)))
	if DisplayMode.values().has(mode_value):
		display_mode = mode_value as DisplayMode
	var saved: Variant = _config.get_value(VIDEO_SECTION, "resolution", resolution)
	if saved is Vector2i and saved.x >= MIN_RESOLUTION.x and saved.y >= MIN_RESOLUTION.y:
		resolution = saved
