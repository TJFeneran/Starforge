extends Control
## Soft monumental arch framing the pause actions. Drawn, not a mesh asset.

@export var ring_color := Color(0.85, 0.835, 0.78, 0.16)
@export var accent_color := Color(1.0, 0.698, 0.22, 0.35)
@export var thickness := 10.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.38
	# Outer monumental ring with a split at the top, echoing the forge gate.
	draw_arc(center, radius, deg_to_rad(25.0), deg_to_rad(335.0), 64, ring_color, thickness, true)
	draw_arc(center, radius * 0.86, deg_to_rad(40.0), deg_to_rad(320.0), 48, Color(ring_color.r, ring_color.g, ring_color.b, ring_color.a * 0.55), thickness * 0.45, true)
	# Amber core cue — quiet, not a second menu.
	draw_arc(center + Vector2(0, radius * 0.08), radius * 0.12, 0.0, TAU, 32, accent_color, 2.0, true)
	# Buttress marks at the base of the opening.
	var base_y := center.y + radius * 0.72
	draw_line(Vector2(center.x - radius * 0.55, base_y), Vector2(center.x - radius * 0.22, base_y), ring_color, 3.0, true)
	draw_line(Vector2(center.x + radius * 0.22, base_y), Vector2(center.x + radius * 0.55, base_y), ring_color, 3.0, true)
