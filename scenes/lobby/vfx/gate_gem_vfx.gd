@tool
extends Node3D
## Geometry is built once; shaders and GPU particles animate without _process.
## Local origin is the gem center. Kept separate from the imported gate mesh.

var _armed := false
var _idle_light_energy := 1.1
var _armed_light_energy := 4.8

func _ready() -> void:
	if has_node("Aura"):
		_apply_armed_look()
		return
	var aura := MeshInstance3D.new()
	aura.name = "Aura"
	var shell := SphereMesh.new()
	shell.radius = 1.0
	shell.height = 2.0
	shell.radial_segments = 40
	shell.rings = 20
	aura.mesh = shell
	aura.scale = Vector3(0.72, 1.65, 0.7)
	var aura_material := ShaderMaterial.new()
	aura_material.shader = preload("res://assets/materials/lobby/gate_aura.gdshader")
	aura.material_override = aura_material
	_configure_mesh(aura)
	add_child(aura)

	var corona := MeshInstance3D.new()
	corona.name = "SoftCorona"
	var corona_mesh := QuadMesh.new()
	corona_mesh.size = Vector2(3.4, 4.6)
	corona.mesh = corona_mesh
	var corona_material := ShaderMaterial.new()
	corona_material.shader = preload("res://assets/materials/lobby/gate_corona.gdshader")
	corona.material_override = corona_material
	_configure_mesh(corona)
	add_child(corona)

	var ribbons := MeshInstance3D.new()
	ribbons.name = "OrbitFilaments"
	var mesh := ImmediateMesh.new()
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/materials/lobby/gate_filaments.gdshader")
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
	for orbit in range(3):
		var tilt := Basis(Vector3.UP, float(orbit) * TAU / 3.0)
		for segment in range(128):
			var u0 := float(segment) / 128.0
			var u1 := float(segment + 1) / 128.0
			var a := u0 * TAU
			var b := u1 * TAU
			var p0 := tilt * Vector3(cos(a) * 0.95, sin(a) * 1.65, sin(a * 2.0) * 0.21)
			var p1 := tilt * Vector3(cos(b) * 0.95, sin(b) * 1.65, sin(b * 2.0) * 0.21)
			var width := tilt * Vector3(cos(a), sin(a), 0.0) * 0.025
			var width1 := tilt * Vector3(cos(b), sin(b), 0.0) * 0.025
			_ribbon_vertex(mesh, p0 - width, Vector2(u0, 0), orbit)
			_ribbon_vertex(mesh, p1 - width1, Vector2(u1, 0), orbit)
			_ribbon_vertex(mesh, p1 + width1, Vector2(u1, 1), orbit)
			_ribbon_vertex(mesh, p0 - width, Vector2(u0, 0), orbit)
			_ribbon_vertex(mesh, p1 + width1, Vector2(u1, 1), orbit)
			_ribbon_vertex(mesh, p0 + width, Vector2(u0, 1), orbit)
	mesh.surface_end()
	ribbons.mesh = mesh
	_configure_mesh(ribbons)
	add_child(ribbons)

	var sparks := GPUParticles3D.new()
	sparks.name = "AscendingSparks"
	sparks.amount = 96
	sparks.lifetime = 3.2
	sparks.preprocess = 3.2
	sparks.local_coords = true
	sparks.visibility_aabb = AABB(Vector3(-1.5, -1.5, -1.5), Vector3(3, 4.2, 3))
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sparks.visibility_range_end = 45.0
	var process_material := ShaderMaterial.new()
	process_material.shader = preload("res://assets/materials/lobby/gate_sparks.gdshader")
	sparks.process_material = process_material
	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.012
	spark_mesh.height = 0.024
	spark_mesh.radial_segments = 6
	spark_mesh.rings = 3
	var spark_material := StandardMaterial3D.new()
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.vertex_color_use_as_albedo = true
	spark_material.emission_enabled = true
	spark_material.emission = Color(1.0, 0.56, 0.17)
	spark_material.emission_energy_multiplier = 5.0
	spark_mesh.material = spark_material
	sparks.draw_pass_1 = spark_mesh
	add_child(sparks)

	var glow := OmniLight3D.new()
	glow.name = "GemLight"
	glow.light_color = Color(1.0, 0.62, 0.22)
	glow.light_energy = _idle_light_energy
	glow.omni_range = 4.0
	glow.shadow_enabled = false
	glow.distance_fade_enabled = true
	glow.distance_fade_begin = 30.0
	glow.distance_fade_length = 10.0
	add_child(glow)
	_apply_armed_look()


func set_armed(armed: bool) -> void:
	_armed = armed
	_apply_armed_look()


func is_armed() -> bool:
	return _armed


func _apply_armed_look() -> void:
	var glow := get_node_or_null("GemLight") as OmniLight3D
	if glow:
		glow.light_energy = _armed_light_energy if _armed else _idle_light_energy
		glow.omni_range = 6.5 if _armed else 4.0
	var sparks := get_node_or_null("AscendingSparks") as GPUParticles3D
	if sparks:
		sparks.amount = 160 if _armed else 48
		sparks.emitting = true
	var aura := get_node_or_null("Aura") as MeshInstance3D
	if aura:
		aura.scale = Vector3(0.86, 1.9, 0.84) if _armed else Vector3(0.58, 1.35, 0.56)
	var corona := get_node_or_null("SoftCorona") as MeshInstance3D
	if corona:
		corona.scale = Vector3(1.18, 1.18, 1.18) if _armed else Vector3(0.82, 0.82, 0.82)


func _configure_mesh(instance: MeshInstance3D) -> void:
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	instance.visibility_range_end = 45.0

func _ribbon_vertex(mesh: ImmediateMesh, point: Vector3, uv: Vector2, orbit: int) -> void:
	mesh.surface_set_color(Color(float(orbit) / 3.0, 0, 0, 1))
	mesh.surface_set_uv(uv)
	mesh.surface_add_vertex(point)
