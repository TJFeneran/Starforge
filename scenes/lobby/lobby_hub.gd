extends Node3D
## Wires lobby interactables: globe → hologram map → armed gate → mission launch.

@onready var _map: CanvasLayer = $HologramMap
@onready var _globe_interact: Area3D = $CentralForge/Navigation/MapInteract
@onready var _globe_sfx: AudioStreamPlayer3D = $CentralForge/Navigation/InteractSFX
@onready var _embark_interact: ProximityInteractable = $ForgeMonumentPortal/EmbarkInteract
@onready var _portal_glow: OmniLight3D = $ForgeMonumentPortal/PortalGlow
@onready var _gem_vfx: Node3D = $ForgeMonumentPortal/GemVFX
@onready var _portal_vfx: Node3D = $ForgeMonumentPortal/PortalVFX

var _marked: MapDestination
var _idle_glow_energy := 1.4
var _idle_glow_range := 6.0
var _launching := false


func _ready() -> void:
	if PlayerState.is_campaign_scene(self):
		PlayerState.checkpoint(PlayerState.LOBBY)
	if _portal_glow:
		_idle_glow_energy = _portal_glow.light_energy
		_idle_glow_range = _portal_glow.omni_range
	if _globe_interact and _globe_interact.has_signal("interacted"):
		_globe_interact.interacted.connect(_on_globe_interacted)
	if _map.has_signal("opened"):
		_map.opened.connect(_on_map_opened)
	if _map.has_signal("closed"):
		_map.closed.connect(_on_map_closed)
	if _map.has_signal("destination_selected"):
		_map.destination_selected.connect(_on_destination_selected)
	if _embark_interact:
		_embark_interact.enabled = false
		_embark_interact.interacted.connect(_on_embark_interacted)
	_set_gate_armed(false)
	var workshops := get_node_or_null("Workshops")
	if workshops:
		for bay in workshops.get_children():
			if bay.has_signal("bench_interacted"):
				bay.bench_interacted.connect(_on_bench_interacted)


func _on_bench_interacted(purpose: String) -> void:
	if purpose == "armor":
		CampaignUI.open_workshop()
		return
	# Other workshop systems remain deferred.
	print("Workshop bench '%s' interacted — focused UI not built yet." % purpose)


func _on_map_opened() -> void:
	if _globe_sfx:
		_globe_sfx.pitch_scale = randf_range(0.97, 1.03)
		_globe_sfx.play()
	if _portal_vfx and _portal_vfx.has_method("start_rumble"):
		_portal_vfx.start_rumble()


func _on_map_closed() -> void:
	# Keep looping after selection while the gate stays open; stop on cancel.
	if _portal_vfx and _portal_vfx.has_method("is_armed") and _portal_vfx.is_armed():
		return
	if _portal_vfx and _portal_vfx.has_method("stop_rumble"):
		_portal_vfx.stop_rumble()


func _on_globe_interacted() -> void:
	if _map.has_method("open_map"):
		_map.open_map()


func _on_destination_selected(destination: MapDestination) -> void:
	_marked = destination
	_set_gate_armed(destination != null and not destination.scene_path.is_empty())
	if _map.has_method("close_map"):
		_map.close_map()


func _on_embark_interacted() -> void:
	if _launching or _marked == null or _marked.scene_path.is_empty():
		return
	if not ResourceLoader.exists(_marked.scene_path):
		push_error("Marked destination scene missing: %s" % _marked.scene_path)
		return
	_launching = true
	var scene_path := _marked.scene_path
	# Consume the marked destination and shut the gate as the wipe closes in,
	# so the portal is collapsing on departure and the lobby reloads disarmed.
	_marked = null
	_set_gate_armed(false)
	var transition := get_node_or_null("/root/SceneTransition")
	if transition and transition.has_method("change_scene"):
		transition.change_scene(scene_path)
	else:
		get_tree().change_scene_to_file(scene_path)


func _set_gate_armed(armed: bool) -> void:
	if _embark_interact:
		_embark_interact.enabled = armed
		if armed and _marked != null:
			_embark_interact.action_text = "Embark — %s" % _marked.title
		else:
			_embark_interact.action_text = "Embark"
	if _portal_glow:
		_portal_glow.light_energy = _idle_glow_energy * (3.2 if armed else 1.0)
		_portal_glow.omni_range = _idle_glow_range * (1.55 if armed else 1.0)
		_portal_glow.light_color = Color(0.12, 0.65, 1.0) if armed else Color(1.0, 0.7, 0.35)
	if _portal_vfx and _portal_vfx.has_method("set_armed"):
		_portal_vfx.set_armed(armed)
	if _gem_vfx and _gem_vfx.has_method("set_armed"):
		_gem_vfx.set_armed(armed)
