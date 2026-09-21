extends Node
## One campaign slot; checkpoints restore at the scene's safe spawn with full HP.
## Sandboxes never attach to this state or write campaign saves.
signal changed
signal save_failed(message: String)

const LOBBY := "res://scenes/lobby/lobby.tscn"
const FIELD := "res://scenes/field/forge_field.tscn"
const STARTERS := ["base_suit", "dustcoat"]
const BALANCE_PATH := "res://assets/data/armor/armor_balance.json"

var save_path := "user://campaign.json"
var catalog: Array = []
var data: Dictionary = {}
var active := false
var last_error := ""

func _ready() -> void:
	catalog = JSON.parse_string(FileAccess.get_file_as_string(BALANCE_PATH))["armors"]

func armor(id: String) -> Dictionary:
	for item: Dictionary in catalog:
		if item.id == id:
			return item
	return {}

func has_save() -> bool:
	return not _read_save().is_empty()

func save_exists() -> bool:
	return FileAccess.file_exists(save_path)

func start_new(starter: String) -> bool:
	if starter not in STARTERS:
		return false
	var fresh := {"version": 1, "starter": starter, "equipped": starter,
		"unlocked": [starter], "checkpoint": LOBBY, "pending_blueprint": ""}
	if not _commit(fresh):
		return false
	active = true
	return true

func continue_game() -> bool:
	var loaded := _read_save()
	if loaded.is_empty():
		last_error = "The save could not be loaded. Start a new game to create a new save."
		return false
	data = loaded
	active = true
	changed.emit()
	return true

func is_campaign_scene(scene: Node) -> bool:
	return active and scene != null and scene.scene_file_path in [LOBBY, FIELD]

func checkpoint(scene_path: String) -> bool:
	if not active or scene_path not in [LOBBY, FIELD]:
		return false
	var next := data.duplicate(true)
	next.checkpoint = scene_path
	return _commit(next)

func next_armor_id() -> String:
	if not active:
		return ""
	for item: Dictionary in catalog:
		if item.id not in STARTERS and item.id not in data.unlocked:
			return item.id
	return ""

func recover_blueprint() -> bool:
	if not active or data.checkpoint != FIELD or not data.pending_blueprint.is_empty():
		return false
	var id := next_armor_id()
	if id.is_empty():
		return false
	var next := data.duplicate(true)
	next.pending_blueprint = id
	return _commit(next)

func return_to_forge() -> bool:
	if not active:
		return true
	var next := data.duplicate(true)
	if not next.pending_blueprint.is_empty():
		if next.pending_blueprint != next_armor_id():
			return false
		next.unlocked.append(next.pending_blueprint)
		next.pending_blueprint = ""
	next.checkpoint = LOBBY
	return _commit(next)

func respawn() -> bool:
	if not active:
		return true
	var next := data.duplicate(true)
	next.pending_blueprint = ""
	next.checkpoint = LOBBY
	return _commit(next)

func equip(id: String) -> bool:
	if not active or id not in data.unlocked or armor(id).is_empty():
		return false
	var next := data.duplicate(true)
	next.equipped = id
	return _commit(next)

func _commit(next: Dictionary) -> bool:
	var temp_path := save_path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return _failed()
	file.store_string(JSON.stringify(next, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(temp_path, save_path) != OK:
		return _failed()
	data = next
	last_error = ""
	changed.emit()
	return true

func _failed() -> bool:
	last_error = "Could not save progress. Check available disk space and folder permissions, then try again."
	save_failed.emit(last_error)
	return false

func _read_save() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(save_path)) != OK:
		return {}
	var parsed: Variant = parser.data
	if not parsed is Dictionary:
		return {}
	var value: Dictionary = parsed
	if value.get("version") != 1 or value.get("starter") not in STARTERS:
		return {}
	if value.get("checkpoint") not in [LOBBY, FIELD] or not value.get("unlocked") is Array:
		return {}
	var owned: Array = value.unlocked
	if owned.is_empty() or owned[0] != value.starter or owned.size() > catalog.size() - 1:
		return {}
	# Require an ordered prefix: no skipped tiers, duplicate rewards or unknown IDs.
	for i in range(1, owned.size()):
		if owned[i] != catalog[i + 1].id:
			return {}
	if value.get("equipped") not in owned or not value.get("pending_blueprint") is String:
		return {}
	var pending: String = value.pending_blueprint
	if not pending.is_empty():
		if value.checkpoint != FIELD or owned.size() >= catalog.size() - 1 or pending != catalog[owned.size() + 1].id:
			return {}
	return value
