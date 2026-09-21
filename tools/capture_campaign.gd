extends SceneTree
## Run with a real rendering display. All saves isolated in /tmp.
var state: Node

func _initialize() -> void:
	call_deferred("_capture")

func shot(name: String) -> void:
	print("Capturing ", name)
	await create_timer(1.0).timeout
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/campaign_" + name + ".png")

func _capture() -> void:
	print("Starting campaign capture")
	root.show()
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1920, 1080)
	state = root.get_node("PlayerState")
	state.save_path = "/tmp/starforge-campaign-capture-%d.json" % OS.get_process_id()
	change_scene_to_file("res://scenes/main.tscn")
	await scene_changed
	await shot("menu")
	var menu: Node = current_scene.get_node("WelcomeScreen")
	menu._on_start()
	await shot("starters")
	menu._chosen = "dustcoat"
	menu._start_new()
	await scene_changed
	await shot("dustcoat_lobby")
	change_scene_to_file(state.FIELD)
	await scene_changed
	await shot("field")
	var cache: Node = current_scene.get_node("ArmorBlueprint")
	var interact: Node = cache.get_child(cache.get_child_count() - 1)
	interact.interacted.emit()
	assert(state.data.pending_blueprint == "outpost_plate")
	await shot("recovered")
	current_scene._on_return_interacted()
	await scene_changed
	await create_timer(1.5).timeout
	assert(state.data.unlocked.has("outpost_plate"))
	var ui: Node = root.get_node("CampaignUI")
	ui.open_workshop()
	ui._selected = "outpost_plate"
	ui._refresh_detail()
	await shot("workshop")
	ui._on_apply()
	ui.close_workshop()
	await shot("outpost_equipped")
	root.get_node("PauseMenu")._on_main_menu()
	await scene_changed
	await shot("continue")
	current_scene.get_node("WelcomeScreen")._on_continue()
	await scene_changed
	assert(current_scene.get_node("Player").selected_armor_index == 1)
	await shot("continued")
	DirAccess.remove_absolute(state.save_path)
	print("Campaign visual flow verified: New Game, Dustcoat, blueprint extraction, workshop equip, Main Menu, Continue")
	quit()
