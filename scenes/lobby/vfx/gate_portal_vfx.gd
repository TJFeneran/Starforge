@tool
extends Node3D
## A fixed, world-space aperture in front of the monument, not a camera billboard.
## Dormant until a globe destination is marked; animation stays on the GPU.

const IGNITION_DURATION := 1.4
const PORTAL_SHADER := preload("res://assets/materials/lobby/gate_portal.gdshader")
const SPARK_SHADER := preload("res://assets/materials/lobby/gate_portal_sparks.gdshader")

var _armed := false
var _activation := 0.0
var _ignition := 0.0
var _transition: Tween
var _surface: MeshInstance3D
var _material: ShaderMaterial
var _embers: GPUParticles3D
var _burst: GPUParticles3D
var _light: OmniLight3D
var _rumble: AudioStreamPlayer3D
var _rumble_base_db := 11.5


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rumble = get_node_or_null("PortalRumble") as AudioStreamPlayer3D
	if _rumble:
		_rumble.process_mode = Node.PROCESS_MODE_ALWAYS
		_rumble_base_db = _rumble.volume_db
		if _rumble.stream != null:
			var stream := _rumble.stream.duplicate()
			var wav := stream as AudioStreamWAV
			if wav != null:
				wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			_rumble.stream = stream
	_surface = MeshInstance3D.new()
	_surface.name = "EnergyAperture"
	var quad := QuadMesh.new()
	quad.size = Vector2(7.8, 7.8)
	_surface.mesh = quad
	_material = ShaderMaterial.new()
	_material.shader = PORTAL_SHADER
	_surface.material_override = _material
	_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_surface.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(_surface)
	_embers = _make_sparks("RimEmbers", 180, false)
	_burst = _make_sparks("IgnitionBurst", 240, true)
	_light = OmniLight3D.new()
	_light.name = "ApertureLight"
	_light.position.z = 0.8
	_light.light_color = Color(0.12, 0.65, 1.0)
	_light.omni_range = 8.0
	_light.shadow_enabled = false
	add_child(_light)
	_apply_energy()
	_surface.visible = false
	if _armed:
		_armed = false
		set_armed.call_deferred(true)


func set_armed(armed: bool) -> void:
	if _armed == armed:
		return
	_armed = armed
	if not is_node_ready():
		return
	if _transition and _transition.is_valid():
		_transition.kill()
	_transition = create_tween()
	_transition.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if armed:
		_surface.visible = true
		_embers.emitting = true
		# Rumble is started when the map opens; keep it looping while armed.
		if _rumble and _rumble.playing:
			_rumble.volume_db = _rumble_base_db
		# Gather from a pinprick, flare on reaching full diameter, then settle.
		_transition.tween_method(_set_activation, _activation, 1.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_transition.parallel().tween_method(_set_ignition, _ignition, 1.0, 0.45).set_delay(0.25)
		_transition.tween_callback(_burst.restart)
		_transition.tween_method(_set_ignition, 1.0, 0.0, IGNITION_DURATION - 0.7).set_trans(Tween.TRANS_SINE)
	else:
		_embers.emitting = false
		_burst.emitting = false
		_transition.tween_method(_set_activation, _activation, 0.0, 0.4)
		_transition.parallel().tween_method(_set_ignition, _ignition, 0.0, 0.4)
		_transition.tween_callback(func() -> void:
			_surface.visible = false
			stop_rumble()
		)


func is_armed() -> bool:
	return _armed


func get_activation() -> float:
	return _activation


func start_rumble() -> void:
	if _rumble == null:
		return
	_rumble.volume_db = _rumble_base_db
	if not _rumble.playing:
		_rumble.play()


func stop_rumble() -> void:
	if _rumble == null:
		return
	_rumble.stop()


func _set_activation(value: float) -> void:
	_activation = value
	_apply_energy()


func _set_ignition(value: float) -> void:
	_ignition = value
	_apply_energy()


func _apply_energy() -> void:
	if not _material:
		return
	_material.set_shader_parameter("activation", _activation)
	_material.set_shader_parameter("ignition", _ignition)
	for particles in [_embers, _burst]:
		var material := particles.process_material as ShaderMaterial
		material.set_shader_parameter("activation", _activation)
		material.set_shader_parameter("radius", 2.496 * lerpf(0.035, 1.0, _activation))
	_light.light_energy = _activation * (2.8 + _ignition * 5.0)


func _make_sparks(label: String, count: int, burst: bool) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = label
	particles.amount = count
	particles.lifetime = 1.15 if burst else 2.1
	particles.one_shot = burst
	particles.explosiveness = 1.0 if burst else 0.0
	particles.emitting = false
	particles.local_coords = true
	particles.visibility_aabb = AABB(Vector3(-4.5, -4.5, -1), Vector3(9, 9, 2))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process_material := ShaderMaterial.new()
	process_material.shader = SPARK_SHADER
	process_material.set_shader_parameter("burst", burst)
	particles.process_material = process_material
	var mesh := SphereMesh.new()
	mesh.radius = 0.018 if burst else 0.012
	mesh.height = mesh.radius * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.emission_enabled = true
	material.emission = Color(0.12, 0.65, 1.0)
	material.emission_energy_multiplier = 4.0
	mesh.material = material
	particles.draw_pass_1 = mesh
	add_child(particles)
	return particles
