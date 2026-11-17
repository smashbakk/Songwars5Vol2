# Property of LiveLayer Technology LLC.
# Presentation only: the HUD reads simulation state without changing it.
extends Control

const Data = preload("res://scripts/combat/fighter_data.gd")
const BLUE := Color("49c9ff")
const WHITE := Color("f5f9ff")
const DARK := Color("0a142b")
const PINK := Color("ff729e")
var sim: RefCounted
var mode := "cpu"
var ghost := [1.0, 1.0]
var last_health := [1.0, 1.0]
var ghost_delay := [0.0, 0.0]
var previous_sim: RefCounted
var previous_countdown := -1
var fight_flash := 0.0
var ko_flash := 0.0
var was_round_over := false
var combo_last := 0
var combo_pop := 0.0
var combo_hold := 0.0
var combo_owner := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if sim == null: return
	if sim != previous_sim:
		previous_sim = sim
		ghost = [1.0, 1.0]
		last_health = [1.0, 1.0]
		ghost_delay = [0.0, 0.0]
		previous_countdown = int(sim.countdown)
		was_round_over = false
		combo_last = 0
	for i in 2:
		var fighter: Dictionary = sim.fighters[i]
		var fraction: float = clampf(float(fighter.hp) / maxf(float(fighter.max_hp), 1.0), 0.0, 1.0)
		if fraction < float(last_health[i]): ghost_delay[i] = 0.30
		if fraction > float(last_health[i]): ghost[i] = fraction
		last_health[i] = fraction
		ghost_delay[i] = maxf(0.0, float(ghost_delay[i]) - delta)
		if float(ghost_delay[i]) <= 0.0: ghost[i] = move_toward(float(ghost[i]), fraction, delta * 0.55)
	if previous_countdown > 0 and int(sim.countdown) == 0: fight_flash = 0.72
	previous_countdown = int(sim.countdown)
	if bool(sim.round_over) and not was_round_over: ko_flash = 1.15
	was_round_over = bool(sim.round_over)
	fight_flash = maxf(0.0, fight_flash - delta)
	ko_flash = maxf(0.0, ko_flash - delta)
	var hits := 0
	var owner := 0
	for i in 2:
		var fighter_hits := int(sim.fighters[i].combo_hits)
		if fighter_hits > hits:
			hits = fighter_hits
			owner = i
	for f in sim.fighters:
		if int(f.get("juggle_window", 0)) > 0 and int(f.get("juggle_hits", 0)) > hits:
			hits = int(f.get("juggle_hits", 0))
			owner = int(f.get("juggle_owner", 0))
	if hits >= 2: combo_owner = owner
	if hits >= 2 and hits != combo_last:
		combo_pop = 0.25
		combo_hold = 0.65
	if hits >= 2: combo_hold = 0.65
	combo_last = hits if hits >= 2 else combo_last
	combo_pop = maxf(0.0, combo_pop - delta)
	combo_hold = maxf(0.0, combo_hold - delta)
	if combo_hold <= 0.0: combo_last = 0
	queue_redraw()

func _bar(x: float, y: float, width: float, height: float, fill: float, color: Color, reverse: bool = false) -> void:
	var cut := minf(13.0, width * 0.12)
	var left := x + (width * (1.0 - fill) if reverse else 0.0)
	var right := x + (width if reverse else width * fill)
	if right - left < 1.0: return
	cut = minf(cut, (right - left) * 0.4)
	draw_colored_polygon(PackedVector2Array([Vector2(left + cut, y), Vector2(right, y), Vector2(right - cut, y + height), Vector2(left, y + height)]), color)

func _label(value: String, x: float, y: float, width: float, font_size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(x + 2, y + 3), value, alignment, width, font_size, Color(0.0, 0.0, 0.0, color.a * 0.8))
	draw_string(font, Vector2(x, y), value, alignment, width, font_size, color)

func _draw() -> void:
	if sim == null or size.x < 100: return
	var s := minf(size.x / 1280.0, size.y / 720.0)
	var edge := 25.0 * s
	var bar_width := maxf(100.0, (size.x - 2.0 * edge - 150.0 * s) / 2.0)
	var y := 35.0 * s
	var bar_h := 21.0 * s
	for i in 2:
		var fighter: Dictionary = sim.fighters[i]
		var right_side := i == 1
		var x: float = size.x - edge - bar_width if right_side else edge
		var side_color: Color = PINK if right_side else BLUE
		var hp := clampf(float(fighter.hp) / maxf(float(fighter.max_hp), 1.0), 0.0, 1.0)
		_bar(x - 3.0 * s, y - 3.0 * s, bar_width + 6.0 * s, bar_h + 6.0 * s, 1.0, Color("78caff"), right_side)
		_bar(x, y, bar_width, bar_h, 1.0, DARK, right_side)
		_bar(x, y, bar_width, bar_h, float(ghost[i]), Color("ffcf75"), right_side)
		_bar(x, y, bar_width, bar_h, hp, side_color, right_side)
		for n in 7:
			var facet_x := x + bar_width * float(n + 1) / 8.0
			draw_line(Vector2(facet_x, y + 2.0 * s), Vector2(facet_x - 5.0 * s, y + bar_h - 2.0 * s), Color(0.03, 0.1, 0.19, 0.23), maxf(1.0, s))
		var align := HORIZONTAL_ALIGNMENT_RIGHT if right_side else HORIZONTAL_ALIGNMENT_LEFT
		_label(str(Data.get_fighter(str(fighter.id)).name).to_upper(), x, 25.0 * s, bar_width, int(18 * s), WHITE, align)
		var meter := clampf(float(fighter.meter) / 60.0, 0.0, 1.0)
		_bar(x, y + 29.0 * s, bar_width * 0.65, 7.0 * s, 1.0, DARK, right_side)
		_bar(x, y + 29.0 * s, bar_width * 0.65, 7.0 * s, meter, side_color, right_side)
		_label("SPECIAL", x, y + 48.0 * s, bar_width * 0.65, int(10 * s), WHITE, align)
		var throw_x := x + bar_width * 0.7
		_bar(throw_x, y + 29.0 * s, bar_width * 0.3, 7.0 * s, 1.0, DARK, right_side)
		_bar(throw_x, y + 29.0 * s, bar_width * 0.3, 7.0 * s, minf(float(fighter.meter) / 20.0, 1.0), Color("ffda80"), right_side)
		_label("THROW", throw_x, y + 48.0 * s, bar_width * 0.3, int(10 * s), Color("ffda80"), align)
		for pip in 2:
			var px := x + (bar_width - 9.0 * s - pip * 15.0 * s if right_side else 9.0 * s + pip * 15.0 * s)
			draw_circle(Vector2(px, y + 60.0 * s), 4.0 * s, side_color if int(sim.round_wins[i]) > pip else Color("31445b"))
	var clock := "∞" if mode == "training" else "%02d" % ceili(float(sim.time_left) / 60.0)
	_label(clock, size.x / 2.0 - 60.0 * s, 54.0 * s, 120.0 * s, int(36 * s), WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_label("ROOFTOP", size.x / 2.0 - 60.0 * s, 71.0 * s, 120.0 * s, int(10 * s), BLUE, HORIZONTAL_ALIGNMENT_CENTER)
	var title := ""
	var strength := 0.0
	if int(sim.countdown) > 0:
		title = "ROUND %d" % int(sim.round_number)
		strength = minf(1.0, minf((78.0 - float(sim.countdown)) / 10.0, float(sim.countdown) / 10.0))
	elif ko_flash > 0.0:
		title = "K.O."
		strength = minf(1.0, ko_flash * 3.0)
	elif fight_flash > 0.0:
		title = "FIGHT!"
		strength = minf(1.0, fight_flash * 4.0)
	if not title.is_empty():
		var cy := size.y * 0.38
		var hw := minf(size.x * 0.34, 390.0 * s)
		draw_colored_polygon(PackedVector2Array([Vector2(size.x / 2.0 - hw + 22.0 * s, cy - 48.0 * s), Vector2(size.x / 2.0 + hw, cy - 48.0 * s), Vector2(size.x / 2.0 + hw - 22.0 * s, cy + 30.0 * s), Vector2(size.x / 2.0 - hw, cy + 30.0 * s)]), Color(0.02, 0.06, 0.15, 0.84 * strength))
		draw_line(Vector2(size.x / 2.0 - hw, cy + 31.0 * s), Vector2(size.x / 2.0 + hw - 22.0 * s, cy + 31.0 * s), Color(BLUE, strength), 4.0 * s)
		_label(title, size.x / 2.0 - hw, cy + 16.0 * s, hw * 2.0, int(55 * s), Color(WHITE, strength), HORIZONTAL_ALIGNMENT_CENTER)
	elif combo_hold > 0.0 and combo_last >= 2:
		var combo_size := int((30.0 + 25.0 * combo_pop) * s)
		_label("%d HIT COMBO" % combo_last, 35.0 * s if combo_owner == 0 else size.x - 335.0 * s, size.y * 0.30, 300.0 * s, combo_size, Color(BLUE if combo_owner == 0 else PINK, minf(1.0, combo_hold * 4.0)), HORIZONTAL_ALIGNMENT_LEFT if combo_owner == 0 else HORIZONTAL_ALIGNMENT_RIGHT)
