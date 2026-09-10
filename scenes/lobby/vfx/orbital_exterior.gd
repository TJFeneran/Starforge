@tool
extends Node3D

## World-space geometry, not a sky photograph: parallax stars, shaded planetary
## spheres and bounded ray-marched nebulae. Kept within the lobby camera's 220 m far plane.
const SURFACE = preload("res://assets/materials/lobby/orbital_surface.gdshader")
const NEBULA = preload("res://assets/materials/lobby/orbital_nebula.gdshader")
const MOON_POSITION := Vector3(110, 65, -32)

func _ready() -> void:
	if has_node("Stars"):
		return
	_build_stars()
	_planet("Moon", MOON_POSITION, 25.0, Color(0.72, 0.77, 0.82), false)
	_planet("DistantGiant", Vector3(-135, 72, 46), 31.0, Color(0.57, 0.49, 0.35), true)
	_planet("RearWorld", Vector3(12, 42, -165), 38.0, Color(0.55, 0.68, 0.82), false)
	_cloud("EasternDust", Vector3(125, 65, 42), Vector3(43, 23, 65), Color(0.20, 0.33, 0.47), 0.65)
	_cloud("WesternDust", Vector3(-125, 69, -38), Vector3(40, 28, 70), Color(0.26, 0.22, 0.35), 0.65)
	_cloud("TransitDust", Vector3(-20, 48, -140), Vector3(70, 32, 42), Color(0.28, 0.38, 0.58), 1.1)
	var moonlight := DirectionalLight3D.new()
	moonlight.name = "Moonlight"
	moonlight.light_color = Color(0.69, 0.81, 1.0)
	moonlight.light_energy = 1.65
	moonlight.shadow_enabled = true
	moonlight.directional_shadow_max_distance = 85.0
	moonlight.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	moonlight.shadow_bias = 0.025
	moonlight.shadow_normal_bias = 0.6
	moonlight.light_angular_distance = 0.6
	moonlight.basis = Basis.looking_at(-MOON_POSITION.normalized(), Vector3.UP)
	add_child(moonlight)

func _build_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 904217
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 6
	sphere.rings = 3
	sphere.material = material
	var stars := MultiMesh.new()
	stars.transform_format = MultiMesh.TRANSFORM_3D
	stars.use_colors = true
	stars.mesh = sphere
	stars.instance_count = 6500
	for i: int in range(stars.instance_count):
		var direction := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
		var distance := rng.randf_range(155.0, 195.0)
		var size := rng.randf_range(0.018, 0.075)
		if i % 37 == 0:
			size = rng.randf_range(0.10, 0.15)
		var tint := Color(0.70, 0.82, 1.0).lerp(Color(1.0, 0.84, 0.64), rng.randf())
		var energy := rng.randf_range(0.7, 2.5) if i % 37 != 0 else 5.0
		stars.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), direction * distance))
		stars.set_instance_color(i, Color(tint.r * energy, tint.g * energy, tint.b * energy))
	var instance := MultiMeshInstance3D.new()
	instance.name = "Stars"
	instance.multimesh = stars
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(instance)

func _planet(label: String, at: Vector3, radius: float, color: Color, gas: bool) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 96
	sphere.rings = 64
	var material := ShaderMaterial.new()
	material.shader = SURFACE
	material.set_shader_parameter("rock_color", Vector3(color.r, color.g, color.b))
	material.set_shader_parameter("gas_giant", gas)
	material.set_shader_parameter("sun_direction", Vector3(-0.45, 0.55, -0.65))
	var planet := MeshInstance3D.new()
	planet.name = label
	planet.mesh = sphere
	planet.material_override = material
	planet.position = at
	planet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	planet.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(planet)

func _cloud(label: String, at: Vector3, dimensions: Vector3, color: Color, density: float) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	var material := ShaderMaterial.new()
	material.shader = NEBULA
	material.set_shader_parameter("cloud_color", Vector3(color.r, color.g, color.b))
	material.set_shader_parameter("density", density)
	var cloud := MeshInstance3D.new()
	cloud.name = label
	cloud.mesh = sphere
	cloud.material_override = material
	cloud.position = at
	cloud.scale = dimensions
	cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cloud.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(cloud)
