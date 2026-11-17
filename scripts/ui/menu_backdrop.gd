extends Control

# A quiet, animated rooftop establishes the same setting on every menu screen.
var rooftop: Texture2D
var elapsed := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	if rooftop:
		var tex_size := rooftop.get_size()
		var scale_factor := maxf(size.x / tex_size.x, size.y / tex_size.y) * 1.035
		var draw_size := tex_size * scale_factor
		var drift := Vector2(sin(elapsed * 0.13) * 3.0, cos(elapsed * 0.11) * 2.0)
		draw_texture_rect(rooftop, Rect2((size - draw_size) * 0.5 + drift, draw_size), false, Color(0.46, 0.54, 0.75))
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color("0c1329"))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.03, 0.09, 0.24))
	# Deterministic individual rain streaks, driven by time rather than frame rate.
	for i in 64:
		var x := fposmod(float(i * 173 + 21), maxf(size.x, 1.0))
		var y := fposmod(float(i * 91) + elapsed * (185.0 + float(i % 4) * 28.0), maxf(size.y, 1.0))
		draw_line(Vector2(x, y), Vector2(x - 3.0, y + 13.0), Color(0.56, 0.78, 1.0, 0.19), 1.0)
