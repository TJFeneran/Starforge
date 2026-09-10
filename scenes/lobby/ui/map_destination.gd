extends Resource
class_name MapDestination
## One selectable world entry for the hologram deployment map.

@export var id := ""
@export var title := ""
@export var blurb := ""
@export var available := true
## Mission scene loaded when the player embarks at the armed gate.
@export_file("*.tscn") var scene_path := ""
