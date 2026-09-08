extends SceneTree
## Run: godot --headless --path . --script scenes/lobby/vfx/validate_forge_reactor.gd

var _failures: int = 0

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)

func _run() -> void:
	var scene := load("res://scenes/lobby/vfx/forge_reactor.tscn") as PackedScene
	if scene == null:
		push_error("Reactor PackedScene did not load")
		quit(1)
		return
	var reactor := scene.instantiate()
	var second := scene.instantiate()
	root.add_child(reactor)
	root.add_child(second)
	reactor.set_process(false)
	second.set_process(false)
	_check(reactor.position == Vector3.ZERO, "Root must be floor-aligned at origin")
	var plinth := reactor.get_node("Plinth/Collision") as CollisionShape3D
	var plinth_shape := plinth.shape as CylinderShape3D
	_check(is_zero_approx(plinth.position.y - plinth_shape.height / 2.0), "Plinth collision must start at floor y=0")
	_check(plinth_shape.radius <= 3.0, "Plinth radius must remain <=3 m")
	var deck := reactor.get_node("Plinth/DeckCollision") as CollisionShape3D
	_check(is_equal_approx(deck.position.y - (deck.shape as CylinderShape3D).height / 2.0, plinth.position.y + plinth_shape.height / 2.0), "Deck and plinth collision must be flush")
	var lights := reactor.find_children("*", "Light3D", true, false)
	var shadows: int = 0
	for light in lights:
		if light.shadow_enabled:
			shadows += 1
	_check(lights.size() == 2 and shadows == 1, "Budget must be exactly two lights, one shadow caster")
	for child in reactor.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if mesh.mesh == null:
			continue
		var bounds := mesh.global_transform * mesh.get_aabb()
		for corner in range(8):
			var point := bounds.get_endpoint(corner)
			# Cylinder AABB diagonal is conservative; check projected axis bounds here.
			_check(absf(point.x) <= 3.0 and absf(point.z) <= 3.0, "Mesh exceeds containment bounds: " + mesh.name)
	var core_a := reactor.get_node("Containment/Core") as MeshInstance3D
	var core_b := second.get_node("Containment/Core") as MeshInstance3D
	_check(core_a.material_override != core_b.material_override, "Core materials must be instance-local")
	var globe_a := reactor.get_node("Navigation/Globe") as MeshInstance3D
	var globe_b := second.get_node("Navigation/Globe") as MeshInstance3D
	_check(globe_a.material_override != globe_b.material_override, "Navigation materials must be instance-local")
	var shared := load("res://assets/lookdev/world_globe_hologram.tres") as ShaderMaterial
	_check(globe_a.material_override != shared, "Navigation must not mutate shared hologram material")
	var motes := reactor.get_node("Motes") as GPUParticles3D
	var arcs := reactor.get_node("Arcs") as MeshInstance3D
	var pulse := reactor.get_node("ArcPulse") as OmniLight3D
	_check(motes.amount == 96, "Full particle budget must be 96")
	reactor.call("_process", 5.16)
	_check(arcs.visible and pulse.light_energy > 0.0, "Timed arc and light pulse must coincide")
	_check(arcs.mesh.get_surface_count() == 1, "Active arc should author a single bounded surface")
	reactor.call("_process", 0.3)
	_check(not arcs.visible and is_zero_approx(pulse.light_energy), "Arc pulse must stop after discharge")
	reactor.call("set_reduced_effects", true)
	reactor.set_process(false)
	_check(motes.amount == 28 and motes.amount < 40, "Reduced particle budget must be 28")
	reactor.call("_process", 5.16)
	_check(not arcs.visible and is_zero_approx(pulse.light_energy), "Reduced mode must disable arcs and pulse light")
	_check(is_equal_approx(core_a.material_override.get_shader_parameter("pulse"), 0.45), "Reduced core must remain steady")
	_check((second.get_node("Motes") as GPUParticles3D).amount == 96, "Reduced mode must not affect other instances")
	reactor.call("set_reduced_effects", false)
	_check(motes.amount == 96, "Full effects must restore")
	root.remove_child(reactor)
	root.remove_child(second)
	reactor.free()
	second.free()
	print("REACTOR VALIDATION: ", "PASS" if _failures == 0 else "FAIL", " (", _failures, " failures)")
	quit(0 if _failures == 0 else 1)
