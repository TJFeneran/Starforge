extends Resource
class_name MapDestination
## One selectable world entry for the hologram deployment map.

@export var id := ""
@export var title := ""
@export var blurb := ""
@export var available := true
## Future: path to mission scene once travel is wired.
@export_file("*.tscn") var scene_path := ""
