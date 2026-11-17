extends RefCounted
## Presentation only: the fixed floor and fight simulation never move.
## Time is wall clock time, so rooftop weather keeps moving during hit-stop.

static func draw_backdrop(canvas: CanvasItem, backdrop: Texture2D, time: float) -> void:
	canvas.draw_texture_rect(backdrop, Rect2(0, 0, 1280, 720), false)
	# Faint cloud layers drift at different rates over the sky, providing
	# parallax without moving the photographed roof or its 511px fight line.
	for layer in range(3):
		var drift := sin(time * (0.075 + layer * 0.025) + layer * 1.7) * (8.0 + layer * 4.0)
		for i in range(5):
			var cx := float(i * 310 - 80 + layer * 83) + drift
			var cy := float(68 + layer * 54 + (i * 29 + layer * 17) % 46)
			var tint := Color(0.13, 0.37, 0.56, 0.026 + 0.005 * layer)
			_ellipse(canvas, Rect2(cx - 120, cy - 19, 240, 38), tint)
	# A distant, intermittent sky glow rather than a full-screen white flash.
	var lightning := fmod(time, 14.0)
	var flash := 0.0
	if lightning < 0.12:
		flash = 0.075 * (1.0 - lightning / 0.12)
	elif lightning > 0.20 and lightning < 0.29:
		flash = 0.045 * (1.0 - (lightning - 0.20) / 0.09)
	if flash > 0.0:
		canvas.draw_rect(Rect2(0, 0, 1280, 410), Color(0.52, 0.79, 1.0, flash))

static func draw_weather(canvas: CanvasItem, time: float) -> void:
	# Two rain depths, falling diagonally with deterministic seeds and no
	# particle nodes or changes to the stage collision/floor.
	for i in range(105):
		var depth := 0 if i < 70 else 1
		var speed := 310.0 if depth == 0 else 500.0
		var travel := time * speed + float((i * 97) % 733)
		var y := fposmod(travel, 720.0) - 20.0
		var x := fposmod(float((i * 193 + 47) % 1320) - travel * 0.19, 1320.0) - 20.0
		var length := 13.0 if depth == 0 else 20.0
		var alpha := 0.12 if depth == 0 else 0.18
		canvas.draw_line(Vector2(x, y), Vector2(x - length * 0.19, y + length), Color(0.61, 0.83, 1.0, alpha), 1.0, true)
	# Short-lived rings at and just in front of the feet plane.
	for i in range(18):
		var phase := fposmod(time * 0.75 + float(i) * 0.173, 1.0)
		var x := float((i * 173 + 57) % 1280)
		var y := 512.0 + float((i * 31) % 58)
		var rx := 3.0 + phase * 11.0
		var ry := 0.8 + phase * 2.4
		var points := PackedVector2Array()
		for n in range(17):
			var a := float(n) * TAU / 16.0
			points.append(Vector2(x + cos(a) * rx, y + sin(a) * ry))
		canvas.draw_polyline(points, Color(0.58, 0.83, 1.0, (1.0 - phase) * 0.25), 1.1, true)

static func draw_contact_shadow(canvas: CanvasItem, x: float, air_height: float) -> void:
	# Layered translucent ellipses are a runtime shadow, not baked sprite art.
	var air := clampf(air_height / 240.0, 0.0, 1.0)
	var width := 112.0 - air * 42.0
	for layer in range(4):
		var fraction := 1.0 - float(layer) * 0.18
		var h := (15.0 - air * 5.0) * fraction
		var w := width * fraction
		var opacity := (0.055 + float(layer) * 0.025) * (1.0 - air * 0.48)
		_ellipse(canvas, Rect2(x - w * 0.5, 511.0 - h * 0.5, w, h), Color(0.015, 0.025, 0.055, opacity))

static func _ellipse(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(32):
		var angle := float(i) * TAU / 32.0
		points.append(rect.get_center() + Vector2(cos(angle), sin(angle)) * rect.size * 0.5)
	canvas.draw_colored_polygon(points, color)
