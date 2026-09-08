@tool
extends Node3D
## Self-contained visual only. Instance at floor level (local y = 0).
## Physical footprint radius: 2.35 m. Beacon: native 2.2 m × 1.5 scale.
## Full: 96 GPU motes, one shadow light, one shadowless arc pulse.
## Reduced: 28 GPU motes, no arcs/pulse, constant core, slower rings.

const ARC_PERIOD: float = 7.5
const ARC_START: float = 5.0
const ARC_DURATION: float = 0.32

@export var reduced_effects: bool = false:
	set(value):
		reduced_effects = value
		if is_node_ready():
			_apply_effects_mode()

## Editor is frozen and flicker-free by default. Preview is opt-in.
@export var preview_animation: bool = false:
	set(value):
		preview_animation = value
		if is_node_ready():
			_apply_effects_mode()

@onready var _outer: Node3D = $Containment/Outer
@onready var _middle: Node3D = $Containment/Middle
@onready var _inner: Node3D = $Containment/Inner
@onready var _motes: GPUParticles3D = $Motes
@onready var _arcs: MeshInstance3D = $Arcs
@onready var _pulse: OmniLight3D = $ArcPulse
@onready var _core_material: ShaderMaterial = $Containment/Core.material_override
@onready var _globe_material: ShaderMaterial = $Navigation/Globe.material_override
@onready var _arc_material: StandardMaterial3D = $Arcs.material_override
@onready var _endpoint_pairs: Array[Node3D] = [
	$Containment/Outer/Electrode, $Containment/CoreEndpointA,
	$Containment/Inner/Electrode, $Containment/CoreEndpointB,
]

var _elapsed: float = 0.0
var _rotation_phase: float = 0.0
var _arc_mesh: ImmediateMesh

func _ready() -> void:
	# Explicitly isolate animated materials even when instantiated from code.
	_core_material = _core_material.duplicate() as ShaderMaterial
	$Containment/Core.material_override = _core_material
	_globe_material = _globe_material.duplicate() as ShaderMaterial
	$Navigation/Globe.material_override = _globe_material
	_arc_material = _arc_material.duplicate() as StandardMaterial3D
	_arcs.material_override = _arc_material
	_arc_mesh = ImmediateMesh.new()
	_arcs.mesh = _arc_mesh
	_apply_effects_mode()

func set_reduced_effects(enabled: bool) -> void:
	reduced_effects = enabled

func _apply_effects_mode() -> void:
	var animate := not Engine.is_editor_hint() or preview_animation
	_motes.amount = 28 if reduced_effects else 96
	_motes.emitting = animate
	_globe_material.set_shader_parameter("flicker_strength", 0.0)
	_globe_material.set_shader_parameter("rotation_speed", 0.004 if reduced_effects else 0.018)
	_globe_material.set_shader_parameter("hologram_strength", 0.55 if reduced_effects else 0.8)
	_core_material.set_shader_parameter("pulse", 0.45)
	_arcs.visible = false
	_pulse.light_energy = 0.0
	_elapsed = 0.0
	if not animate:
		_rotation_phase = 0.0
		_update_rings()
	set_process(animate)

func _process(delta: float) -> void:
	_elapsed = fmod(_elapsed + delta, ARC_PERIOD)
	_rotation_phase = fmod(_rotation_phase + delta * (0.22 if reduced_effects else 1.0), TAU / 0.01)
	_update_rings()
	_core_material.set_shader_parameter("pulse", 0.45 if reduced_effects else 0.5 + 0.5 * sin(_elapsed * TAU / ARC_PERIOD))
	var arc_time := (_elapsed - ARC_START) / ARC_DURATION
	var active := not reduced_effects and arc_time > 0.0 and arc_time < 1.0
	_arcs.visible = active
	_pulse.light_energy = 0.0
	if active:
		# One smooth, scheduled discharge: no random flicker, identical light envelope.
		var envelope := sin(arc_time * PI)
		_pulse.light_energy = envelope * 0.8
		_arc_material.emission_energy_multiplier = 2.0 * envelope
		_rebuild_arcs(envelope)

func _update_rings() -> void:
	_outer.rotation = Vector3(0.28, 0.2 + _rotation_phase * 0.03, 0.12)
	_middle.rotation = Vector3(-0.4, -0.3 - _rotation_phase * 0.02, 0.24)
	_inner.rotation = Vector3(0.52, 0.1 + _rotation_phase * 0.04, -0.3)

func _rebuild_arcs(envelope: float) -> void:
	_arc_mesh.clear_surfaces()
	_arc_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for pair in range(2):
		var start := to_local(_endpoint_pairs[pair * 2].global_position)
		var end := to_local(_endpoint_pairs[pair * 2 + 1].global_position)
		var direction := (end - start).normalized()
		var side := direction.cross(Vector3.UP).normalized()
		var up := side.cross(direction).normalized()
		var previous := start
		for segment in range(1, 9):
			var t := float(segment) / 8.0
			var zig := sin(float(segment) * 2.37 + float(pair)) * sin(t * PI) * 0.065
			var point := start.lerp(end, t) + side * zig + up * zig * 0.55
			if segment == 8:
				point = end
			_append_arc_segment(previous, point, 0.009 * envelope)
			previous = point
	_arc_mesh.surface_end()

func _append_arc_segment(start: Vector3, end: Vector3, radius: float) -> void:
	var direction := (end - start).normalized()
	var side := direction.cross(Vector3.UP).normalized() * radius
	var up := side.normalized().cross(direction) * radius
	for face in range(4):
		var angle_a := float(face) * TAU / 4.0
		var angle_b := float(face + 1) * TAU / 4.0
		var offset_a := side * cos(angle_a) + up * sin(angle_a)
		var offset_b := side * cos(angle_b) + up * sin(angle_b)
		for vertex in [start + offset_a, end + offset_a, end + offset_b,
				start + offset_a, end + offset_b, start + offset_b]:
			_arc_mesh.surface_add_vertex(vertex)
