# Property of LiveLayer Technology LLC.
extends Control

var layout := "simplified"
var contacts := {}
var actions: Array[String] = []
var regions := {}
var enabled := true
var prompt_button := ""
var prompt_kind := ""
var block_flash := false
var mouse_held := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _regions() -> void:
	regions.clear()
	var s := size
	var unit: float = clampf(minf(s.x / 13.0, s.y / 8.5), 46.0, 72.0)
	var left := Vector2(24, s.y - unit * 3.0 - 18)
	for cell in [[0,0,"up_back"],[1,0,"up"],[2,0,"up_forward"],[0,1,"left"],[1,1,"down"],[2,1,"right"],[0,2,"down_back"],[1,2,"down"],[2,2,"down_forward"]]:
		regions[cell[2]] = Rect2(left + Vector2(cell[0], cell[1]) * unit, Vector2.ONE * (unit - 3))
	var right := s.x - 24 - unit * 3.3
	if layout == "simplified":
		regions.punch = Rect2(Vector2(right, left.y) + unit * Vector2(0.8, -0.1), Vector2.ONE * unit * 1.1)
		regions.kick = Rect2(Vector2(right, left.y) + unit * Vector2(2.0, 0.65), Vector2.ONE * unit * 1.1)
	else:
		for cell in [[0,0,"light"],[1.15,0,"low"],[0,1.15,"kick"],[1.15,1.15,"heavy"],[2.3,0,"throw"],[2.3,1.15,"special"]]:
			regions[cell[2]] = Rect2(Vector2(right, left.y) + Vector2(cell[0], cell[1]) * unit, Vector2.ONE * unit)
	regions.block = Rect2(s.x * 0.5 - unit * 0.65, s.y - unit * 1.2 - 20, unit * 1.3, unit)
	if not prompt_button.is_empty():
		regions.prompt = Rect2(s.x * 0.5 - unit * 1.8, s.y - unit * 4.1 - 28, unit * 3.6, unit)

func _input(event: InputEvent) -> void:
	if not enabled or not visible:
		return
	# Touch is handled natively; ignore its emulated mouse copy to keep one tap = one attack.
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	_regions()
	if event is InputEventScreenTouch:
		if event.pressed:
			contacts[event.index] = event.position
			_press(event.position)
		else:
			contacts.erase(event.index)
	elif event is InputEventScreenDrag:
		contacts[event.index] = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_held = event.pressed
		if mouse_held:
			contacts[-1] = event.position
			_press(event.position)
		else:
			contacts.erase(-1)
	elif event is InputEventMouseMotion and mouse_held:
		contacts[-1] = event.position
	queue_redraw()

func _press(point: Vector2) -> void:
	for name in regions:
		if regions[name].has_point(point) and name in ["punch","light","low","kick","heavy","throw","special","prompt"]:
			actions.append(prompt_button if name == "prompt" else name)
			break

func sample() -> Dictionary:
	_regions()
	var result := {"move":0,"down":false,"jump":false,"block":false,"attack":""}
	for point in contacts.values():
		for name in regions:
			if not regions[name].has_point(point):
				continue
			if name in ["left","up_back","down_back"]: result.move = -1
			if name in ["right","up_forward","down_forward"]: result.move = 1
			if name in ["down","down_back","down_forward"]: result.down = true
			if name in ["up","up_back","up_forward"]: result.jump = true
			if name == "block": result.block = true
	if not actions.is_empty():
		result.attack = actions.pop_front()
		if result.attack == "punch": result.attack = "low" if result.down else "light"
		elif result.attack == "kick" and layout == "simplified" and result.down: result.attack = "heavy"
	return result

func clear() -> void:
	contacts.clear()
	actions.clear()
	mouse_held = false

func _draw() -> void:
	_regions()
	var font := ThemeDB.fallback_font
	var labels := {"left":"←","right":"→","up":"↑","up_back":"↖","up_forward":"↗","down_back":"↙","down_forward":"↘","down":"↓","punch":"PUNCH","kick":"KICK","light":"LP","low":"LOW","heavy":"HK","throw":"THROW","special":"SPECIAL","block":"HOLD\nBLOCK","prompt":prompt_button.to_upper()}
	for name in regions:
		var r: Rect2 = regions[name]
		var held := false
		for p in contacts.values():
			if r.has_point(p): held = true
		var accent := Color("43e2be") if name == "prompt" else Color("95a5d9")
		if name == "block" and prompt_kind == "block": accent = Color("ffcf73")
		draw_style_box(_box(Color(0.04,0.06,0.12,0.92) if not held else Color(0.15,0.33,0.38,0.95), accent), r)
		var text: String = labels.get(name, name.to_upper())
		var font_size := 15 if text.length() > 3 else 24
		var lines := text.split("\n")
		for i in lines.size():
			var width := font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			draw_string(font, Vector2(r.get_center().x-width/2, r.get_center().y + font_size*0.35 + (i-(lines.size()-1)*0.5)*font_size),lines[i], HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,accent)

func _box(bg: Color, stroke: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = Color(stroke, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	return style
