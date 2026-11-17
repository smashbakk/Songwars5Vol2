# Property of LiveLayer Technology LLC.
extends Control

const Data = preload("res://scripts/combat/fighter_data.gd")
const Simulation = preload("res://scripts/combat/fight_sim.gd")
const Brain = preload("res://scripts/combat/cpu_brain.gd")
const SaveStore = preload("res://scripts/progression/save_store.gd")
const Story = preload("res://scripts/progression/story_data.gd")
const Arena = preload("res://scripts/ui/arena_view.gd")
const Touch = preload("res://scripts/ui/touch_controls.gd")
const AudioHooks = preload("res://scripts/ui/audio_hooks.gd")
const MenuBackdrop = preload("res://scripts/ui/menu_backdrop.gd")
const PortraitFrame = preload("res://scripts/ui/portrait_frame.gd")
const PORTRAITS = {
	"cin": "res://assets/menu/portrait_cin.jpg",
	"rico": "res://assets/menu/portrait_rico.jpg",
	"hood": "res://assets/menu/portrait_hood.png",
	"bank": "res://assets/menu/portrait_bank.jpg",
	"smash": "res://assets/menu/portrait_smash.jpg",
	"smash_armored": "res://assets/menu/portrait_smash_armored.jpg",
	"jo": "res://assets/menu/portrait_jo.jpg",
	"lmscurt": "res://assets/menu/portrait_lmscurt.jpg",
	"hublo": "res://assets/menu/portrait_hublo.png",
}
const BOARD_VIDEO := "res://assets/menu/loading-board.ogv"
const BOARD_STILL := "res://assets/menu/board-still.jpg"
const TITLE_LOGO := "res://assets/menu/vol2-title-logo.png"
const ROOFTOP_ART := "res://assets/menu/rooftop-night.jpg"
const STATUE_SHADER := "shader_type canvas_item;\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV);\n\tfloat g = dot(c.rgb, vec3(0.299, 0.587, 0.114));\n\tvec3 statue = mix(vec3(g), c.rgb, 0.22) * vec3(0.5, 0.62, 1.05);\n\tCOLOR = vec4(statue, c.a);\n}"
const TEAL = Color("53ebc5")
const GOLD = Color("ffd18a")
const INK = Color("0c1329")
const PALE = Color("e7ecff")
const MUTED = Color("a1adcc")
const HEALTH_NAMES := ["Standard", "Tough", "Rugged", "Hardened", "Fortified", "Unbreakable"]
# Smash gating (CEO ruling, Nov 15, 2026): both Smash forms are playable by
# the CEO and admins only. Regular users see them on the select screen but
# cannot pick either; Smash stays pickable as the opponent they face. The
# admin code unlocks both forms for the current session only.
const ADMIN_CODE := "LYVE"

var store = SaveStore.new()
var arena: Control
var ui: Control
var touch: Control
var sim: RefCounted
var cpu: RefCounted
var screen := "menu"
var mode := "cpu"
var selected := "cin"
var selected_variant := ""
var admin_unlocked := false
var admin_note := ""
var opponent := "bank"
var difficulty := 1
var story_index := 0
var select_opponent := false
var paused := false
var result_wait := 0
var keyboard_attack := ""
var key_edges := {}
var dummy_mode := 0
var lesson := -1
var lesson_complete := false
var story_queue: Array = []
var story_scene := ""
var panel_index := 0
var panel_elapsed := 0.0
var next_after_story := "fight"
var current_panel: Dictionary = {}
var notices := ""
var health_bars: Array = []
var health_labels: Array = []
var meter_labels: Array = []
var clock_label: Label
var fight_status: Label
var prompt_label: Label
var scene_continue: Button
var pending_result := false
var audio_player: AudioStreamPlayer
var audio_hooks: Node
var fight_accumulator := 0.0
var ko_slow_remaining := 0.0
var relayout_pending := false
var menu_textures: Dictionary = {}
var boot_elapsed := 0.0
var boot_ready := false
var boot_skip := false
var boot_bar: ProgressBar
var boot_pct: Label
var boot_player: VideoStreamPlayer
var boot_still: TextureRect
var press_elapsed := 0.0
var press_button: Button

func _ready() -> void:
	# Godot CLI can override the save file for isolated smoke tests, without changing the environment.
	var save_path := "user://songwars_save.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save-path="): save_path = arg.trim_prefix("--save-path=")
	store.load_save(save_path)
	_setup_theme()
	arena = Arena.new()
	add_child(arena)
	arena.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui = Control.new()
	add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	audio_hooks = AudioHooks.new()
	add_child(audio_hooks)
	get_tree().root.size_changed.connect(_window_resized)
	resized.connect(_request_relayout)
	_window_resized()
	show_boot()

func _setup_theme() -> void:
	var t := Theme.new()
	t.default_font_size = 20
	t.set_color("font_color", "Label", PALE)
	t.set_color("font_color", "Button", PALE)
	t.set_color("font_hover_color", "Button", TEAL)
	t.set_color("font_disabled_color", "Button", MUTED)
	t.set_stylebox("normal", "Button", box(Color("142d48"), Color("427da5"), 3))
	t.set_stylebox("hover", "Button", box(Color("174e70"), Color("55ceff"), 3))
	t.set_stylebox("pressed", "Button", box(Color("08799c"), Color("b7f2ff"), 3))
	t.set_stylebox("focus", "Button", box(Color(0,0,0,0), GOLD))
	t.set_stylebox("disabled", "Button", box(Color("111a30"), Color("29324c")))
	t.set_stylebox("normal", "LineEdit", box(Color("142d48"), Color("427da5"), 3))
	t.set_stylebox("focus", "LineEdit", box(Color("163b56"), Color("55ceff"), 3))
	t.set_stylebox("read_only", "LineEdit", box(Color("111a30"), Color("29324c"), 3))
	# Style scrollbars and option menus along with the primary buttons.
	for kind in ["VScrollBar", "HScrollBar"]:
		var track := StyleBoxFlat.new()
		track.bg_color = Color("10233a")
		track.set_corner_radius_all(3)
		var thumb := StyleBoxFlat.new()
		thumb.bg_color = Color("3884a9")
		thumb.set_corner_radius_all(3)
		thumb.content_margin_left = 4
		thumb.content_margin_right = 4
		thumb.content_margin_top = 4
		thumb.content_margin_bottom = 4
		t.set_stylebox("scroll", kind, track)
		t.set_stylebox("grabber", kind, thumb)
		t.set_stylebox("grabber_highlight", kind, thumb)
		t.set_stylebox("grabber_pressed", kind, thumb)
	for state_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		t.set_stylebox(state_name, "OptionButton", t.get_stylebox(state_name, "Button"))
	t.set_stylebox("panel", "PopupMenu", box(Color("10243a"), Color("427da5"), 3))
	t.set_stylebox("hover", "PopupMenu", box(Color("174e70"), Color("55ceff"), 3))
	t.set_color("font_color", "PopupMenu", PALE)
	t.set_color("font_hover_color", "PopupMenu", Color("9ee8ff"))
	t.set_constant("outline_size", "Label", 1)
	t.set_color("font_outline_color", "Label", Color("101b30"))
	t.set_constant("separation", "VBoxContainer", 12)
	t.set_constant("separation", "HBoxContainer", 12)
	theme = t

func box(bg: Color, border: Color, radius: int = 12) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(1)
	b.set_corner_radius_all(radius)
	b.content_margin_left = 22
	b.content_margin_right = 22
	b.content_margin_top = 14
	b.content_margin_bottom = 14
	return b

func clear_ui(next_screen: String) -> void:
	screen = next_screen
	_apply_orientation(next_screen=="fight")
	paused = false
	keyboard_attack = ""
	for node in ui.get_children():
		ui.remove_child(node)
		node.queue_free()
	touch = null
	arena.sim = null
	arena.scene_mode = "menu"
	arena.gate_phase = 0
	arena.fighter_ids = [selected, opponent]

func page(title: String, eyebrow: String = "SONG WARS 5 / VOL. 2") -> VBoxContainer:
	if screen != "fight" and not ui.has_node("MenuBackdrop"):
		_menu_backdrop()
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.015, 0.025, 0.065, 0.56)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side, 24)
	ui.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = minf(size.x - 64, 660)
	panel.add_theme_stylebox_override("panel", box(Color(0.025,0.055,0.12,0.86),Color("357baa"),5))
	center.add_child(panel)
	var col := VBoxContainer.new()
	panel.add_child(col)
	text(col, eyebrow, 14, TEAL)
	text(col, title, 38)
	return col

func text(parent: Node, value: String, font_size: int = 20, color: Color = PALE) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func button(parent: Node, value: String, callback: Callable, accent: bool = false) -> Button:
	var b := Button.new()
	b.text = value
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.custom_minimum_size.y = 50
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if accent: b.add_theme_color_override("font_color", TEAL)
	b.mouse_entered.connect(func():
		if not b.disabled:
			audio_hooks.play_hook("ui_move", bool(store.data.settings.muted)))
	b.focus_entered.connect(func():
		if not b.disabled:
			audio_hooks.play_hook("ui_move", bool(store.data.settings.muted)))
	b.pressed.connect(func(): audio_hooks.play_hook("ui_pick", bool(store.data.settings.muted)))
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func row(parent: Node) -> HBoxContainer:
	var h := HBoxContainer.new()
	parent.add_child(h)
	return h

func cap(parent: Node, value: String, small: bool = false) -> PanelContainer:
	var b := StyleBoxFlat.new()
	b.bg_color = Color(0.10, 0.14, 0.27, 1.0)
	b.border_color = Color("7d8fc4")
	b.set_border_width_all(1)
	b.set_corner_radius_all(8)
	b.content_margin_left = 7 if small else 9
	b.content_margin_right = 7 if small else 9
	b.content_margin_top = 3
	b.content_margin_bottom = 3
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", b)
	var l := Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size", 14 if small else 15)
	l.add_theme_color_override("font_color", PALE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	parent.add_child(p)
	return p

func cap_label(parent: Node, value: String, color: Color = PALE) -> Label:
	var l := Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l

func guide_row(parent: Node) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	parent.add_child(h)
	return h

func guide_pair(parent: Node) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(h)
	return h

func chain_sep(parent: Node) -> void:
	var l := Label.new()
	l.text = "→"
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", MUTED)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(l)

func guide_panel(parent: Node, title: String) -> VBoxContainer:
	var b := StyleBoxFlat.new()
	b.bg_color = Color(0.05, 0.075, 0.16, 0.92)
	b.border_color = Color("2c3c66")
	b.set_border_width_all(1)
	b.set_corner_radius_all(14)
	b.content_margin_left = 14
	b.content_margin_right = 14
	b.content_margin_top = 6
	b.content_margin_bottom = 6
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", b)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	var head := Label.new()
	head.text = title
	head.add_theme_font_size_override("font_size", 16)
	head.add_theme_color_override("font_color", TEAL)
	v.add_child(head)
	return v

func stat_level(stat: String) -> Dictionary:
	var ups := store.get_upgrades(selected)
	var steps := int(ups[stat])
	var base: Dictionary = SaveStore.BASE[selected]
	var now_name := ""
	var next_name := ""
	var total := 0
	if stat == "hp":
		var pool := int(base["hp"]) + steps * SaveStore.HEALTH_STEP
		total = (SaveStore.HEALTH_CAP - int(base["hp"])) / SaveStore.HEALTH_STEP
		now_name = HEALTH_NAMES[clampi((pool - 200) / 10, 0, HEALTH_NAMES.size() - 1)]
		next_name = HEALTH_NAMES[clampi((pool + SaveStore.HEALTH_STEP - 200) / 10, 0, HEALTH_NAMES.size() - 1)]
	else:
		var names: Array = SaveStore.DAMAGE_NAMES if stat == "damage" else SaveStore.SPEED_NAMES
		var idx := int(base[stat]) + steps
		total = 2 - int(base[stat])
		now_name = names[clampi(idx, 0, 2)]
		next_name = names[clampi(idx + 1, 0, 2)]
	var pips := ""
	for i in total:
		pips += "●" if i < steps else "○"
	return {"now": now_name, "next": next_name, "pips": pips, "maxed": steps >= total}

func _boot_paths() -> Array:
	var paths: Array = [BOARD_VIDEO, BOARD_STILL, TITLE_LOGO, ROOFTOP_ART]
	for id in Data.IDS:
		paths.append(PORTRAITS[id])
	return paths

func show_boot() -> void:
	clear_ui("boot")
	boot_elapsed = 0.0
	boot_ready = false
	boot_skip = false
	for path in _boot_paths():
		ResourceLoader.load_threaded_request(path)
	var bg := ColorRect.new()
	bg.color = INK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(bg)
	boot_still = TextureRect.new()
	boot_still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	boot_still.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	boot_still.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	boot_still.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(boot_still)
	boot_player = VideoStreamPlayer.new()
	boot_player.expand = true
	boot_player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	boot_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(boot_player)
	var bottom := MarginContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 60
	bottom.offset_right = -60
	bottom.offset_top = -128
	bottom.offset_bottom = -20
	ui.add_child(bottom)
	var col := VBoxContainer.new()
	bottom.add_child(col)
	boot_pct = text(col, "0%", 16, PALE)
	boot_pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boot_bar = ProgressBar.new()
	boot_bar.min_value = 0
	boot_bar.max_value = 100
	boot_bar.value = 0
	boot_bar.show_percentage = false
	boot_bar.custom_minimum_size.y = 14
	boot_bar.add_theme_stylebox_override("background", box(Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.30), 7))
	boot_bar.add_theme_stylebox_override("fill", box(Color(0.36, 0.85, 1.0, 0.55), Color(0.7, 0.95, 1.0, 0.5), 7))
	col.add_child(boot_bar)
	var pill_row := CenterContainer.new()
	col.add_child(pill_row)
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", box(Color(0.05, 0.10, 0.20, 0.45), Color(0.33, 0.92, 0.77, 0.6), 14))
	pill_row.add_child(pill)
	var pill_label := Label.new()
	pill_label.text = "Powered By LiveLayerTech.net"
	pill_label.add_theme_font_size_override("font_size", 14)
	pill_label.add_theme_color_override("font_color", TEAL)
	pill.add_child(pill_label)
	var skip := button(col, "Tap to skip", func(): boot_skip = true)
	skip.custom_minimum_size.y = 34

func _boot_tick(delta: float) -> void:
	boot_elapsed += delta
	var paths := _boot_paths()
	var settled := 0.0
	var all_loaded := true
	for path in paths:
		var progress: Array = []
		var status := ResourceLoader.load_threaded_get_status(path, progress)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			settled += 1.0
		elif status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			all_loaded = false
			settled += float(progress[0]) if not progress.is_empty() else 0.0
		else:
			settled += 1.0
	var fraction := settled / float(paths.size())
	if is_instance_valid(boot_bar):
		boot_bar.value = fraction * 100.0
		if is_instance_valid(boot_pct):
			boot_pct.text = "%d%%" % int(fraction * 100.0)
	if all_loaded and not boot_ready:
		boot_ready = true
		for path in paths:
			var res := ResourceLoader.load_threaded_get(path)
			if res == null:
				push_warning("FRONT DOOR DEFECT: asset failed to load: " + path)
			else:
				menu_textures[path] = res
		if menu_textures.has(BOARD_VIDEO) and is_instance_valid(boot_player):
			boot_player.stream = menu_textures[BOARD_VIDEO]
			boot_player.play()
		elif is_instance_valid(boot_still):
			boot_still.texture = menu_textures.get(BOARD_STILL)
	if boot_elapsed >= 5.0 and not boot_ready:
		boot_ready = true
		for path in paths:
			if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
				menu_textures[path] = ResourceLoader.load_threaded_get(path)
	if boot_ready and (boot_elapsed >= 3.0 or boot_skip):
		show_press_start()

func show_press_start() -> void:
	clear_ui("press_start")
	press_elapsed = 0.0
	var bg := ColorRect.new()
	bg.color = INK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(bg)
	var tap := Button.new()
	tap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tap.focus_mode = Control.FOCUS_NONE
	for state_name in ["normal", "hover", "pressed", "focus"]:
		tap.add_theme_stylebox_override(state_name, box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0))
	tap.pressed.connect(_advance_press_start)
	ui.add_child(tap)
	var statues := HBoxContainer.new()
	statues.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	statues.offset_left = 24
	statues.offset_right = -24
	statues.offset_top = 180
	statues.offset_bottom = -110
	statues.mouse_filter = Control.MOUSE_FILTER_IGNORE
	statues.add_theme_constant_override("separation", 10)
	ui.add_child(statues)
	var sh := Shader.new()
	sh.code = STATUE_SHADER
	for id in ["smash", "jo", "rico", "lmscurt"]:
		var t := TextureRect.new()
		t.texture = _menu_texture(PORTRAITS[id])
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = sh
		t.material = mat
		statues.add_child(t)
	var top := CenterContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 14
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(top)
	var logo := TextureRect.new()
	logo.texture = _menu_texture(TITLE_LOGO)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(620, 290)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(logo)
	var bottom := CenterContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -100
	bottom.offset_bottom = -24
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(bottom)
	press_button = Button.new()
	press_button.text = "PRESS START"
	press_button.focus_mode = Control.FOCUS_NONE
	press_button.add_theme_font_size_override("font_size", 36)
	press_button.add_theme_color_override("font_color", GOLD)
	for state_name in ["normal", "hover", "pressed", "focus"]:
		press_button.add_theme_stylebox_override(state_name, box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0))
	press_button.pressed.connect(_advance_press_start)
	bottom.add_child(press_button)

func _advance_press_start() -> void:
	if str(store.data.settings.get("layout", "")).is_empty():
		show_layout(true)
	else:
		show_menu()

func _menu_texture(path: String) -> Texture2D:
	var tex: Texture2D = menu_textures.get(path)
	if tex == null and ResourceLoader.exists(path):
		tex = load(path)
	return tex

func _menu_backdrop() -> void:
	if ui.has_node("MenuBackdrop"):
		return
	var backdrop := MenuBackdrop.new()
	backdrop.name = "MenuBackdrop"
	backdrop.rooftop = _menu_texture(ROOFTOP_ART)
	ui.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.move_child(backdrop, 0)

func _portrait_rect(id: String, height: float, locked: bool = false) -> Control:
	var frame := PortraitFrame.new()
	frame.texture = _menu_texture(PORTRAITS.get(id, ""))
	frame.locked = locked
	frame.custom_minimum_size.y = height
	return frame

func show_roster() -> void:
	clear_ui("roster")
	_menu_backdrop()
	var col := page("Explore the Artists", "ROSTER / EIGHT FIGHTERS")
	var grid := GridContainer.new()
	grid.columns = 2 if size.x > 600 else 1
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	col.add_child(grid)
	for id in Data.IDS:
		var info: Dictionary = Data.get_fighter(id)
		var card := VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
		card.add_child(_portrait_rect(id, 120))
		text(card, str(info.name), 22)
		text(card, str(info.bio), 16, MUTED)
		text(card, "Special: " + str(info.big_name), 15, TEAL)
	button(col, "Back", show_menu)

func show_new_additions() -> void:
	clear_ui("new_additions")
	_menu_backdrop()
	var col := page("New Additions", "ROSTER / FUTURE DROPS")
	text(col, "This slot is where future fighters land when they drop. The launch eight are already in — find them in the Roster.", 20, MUTED)
	button(col, "Browse the Roster", show_roster)
	button(col, "Back", show_menu)

func show_menu() -> void:
	clear_ui("menu")
	_menu_backdrop()
	var col := page("Keep your name lit.")
	text(col,"The Rooftop is open. Eight fighters. One road to the gate.",20,MUTED)
	button(col,"STORY  /  The Prologue",enter_story,true)
	button(col,"PLAYER vs CPU",func(): mode="cpu"; select_opponent=false; show_select())
	button(col,"TRAINING  /  Free practice",func(): mode="training"; lesson=-1; select_opponent=false; show_select())
	button(col,"ROSTER  /  Explore the Artists",show_roster)
	button(col,"NEW ADDITIONS  /  Future fighters",show_new_additions)
	var h := row(col)
	button(h,"Upgrades",show_upgrades)
	button(h,"Settings",show_settings)
	button(h,"Move guide",show_help)
	if not notices.is_empty(): text(col,notices,16,GOLD)
	text(col,"Powered By LiveLayerTech.net",14,TEAL)

func show_layout(first: bool = false) -> void:
	clear_ui("layout")
	var col := page("Choose your controls")
	text(col,"Both layouts use identical damage and timing. Change your layout between matches in Settings.",20,MUTED)
	button(col,"SIMPLIFIED  /  Pad + Punch + Kick + Heavy",func(): store.set_setting("layout","simplified"); show_menu(),true)
	text(col,"Down + Punch gives a low punch; Down + Kick gives a low kick. Heavy kicks high; Down + Heavy launches an uppercut. Release and press Up again in the air to double jump. Double-tap a direction to prompt a special.",17,MUTED)
	button(col,"TRADITIONAL  /  Four attacks + Throw + Special",func(): store.set_setting("layout","traditional"); show_menu())
	if not first: button(col,"Back",show_settings)

func show_settings() -> void:
	clear_ui("settings")
	var col := page("Settings")
	button(col,"Control layout: " + str(store.data.settings.layout).capitalize(),func():show_layout())
	button(col,"Subtitles: " + ("ON" if store.data.settings.subtitles else "OFF"),func():store.set_setting("subtitles",not store.data.settings.subtitles);show_settings())
	button(col,"Sound effects: " + ("MUTED" if store.data.settings.muted else "ON"),func():store.set_setting("muted",not store.data.settings.muted);show_settings())
	button(col,"Portrait fights: " + ("ENABLED" if store.data.settings.portrait_fights else "Landscape recommended"),func():store.set_setting("portrait_fights",not store.data.settings.portrait_fights);show_settings())
	button(col,"Unlimited story attempts: " + ("ON" if store.data.settings.tester_bypass else "OFF"),func():store.set_setting("tester_bypass",not store.data.settings.tester_bypass);show_settings())
	text(col,"Progress is saved on this device. Story attempts reset at 00:00 and 12:00 UTC.",17,MUTED)
	button(col,"Back",show_menu)

func show_select() -> void:
	clear_ui("select")
	_menu_backdrop()
	var title := "Choose your opponent" if select_opponent else "Choose your fighter"
	var col := page(title,mode.to_upper()+" / ROOFTOP")
	var grid := GridContainer.new()
	grid.columns = 2 if size.x > 600 else 1
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	col.add_child(grid)
	for id in Data.IDS:
		var info: Dictionary = Data.get_fighter(id)
		var card := VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
		var portrait := _portrait_rect(id, 150, id == "smash" and not admin_unlocked)
		card.add_child(portrait)
		if id == "smash" and not admin_unlocked:
			var locked := button(card, "Smash — LOCKED", func(): pass)
			locked.disabled = true
		else:
			var pick := button(card,info.name,func():_pick_fighter(id))
			pick.mouse_entered.connect(func(): portrait.set_active(true))
			pick.mouse_exited.connect(func(): portrait.set_active(false))
			pick.focus_entered.connect(func(): portrait.set_active(true))
			pick.focus_exited.connect(func(): portrait.set_active(false))
	if not select_opponent:
		var acard := VBoxContainer.new()
		acard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(acard)
		acard.add_child(_portrait_rect("smash_armored", 150, not admin_unlocked))
		if admin_unlocked:
			button(acard, "Armored Smash", _pick_armored)
		else:
			var alocked := button(acard, "Armored Smash — LOCKED", func(): pass)
			alocked.add_theme_font_size_override("font_size", 15)
			alocked.disabled = true
		if admin_unlocked:
			text(col, "ADMIN MODE — Smash is unlocked for this session.", 15, GOLD)
		else:
			text(col, "Smash is locked. Admins can unlock both forms.", 15, MUTED)
			button(col, "Admin unlock", show_admin_unlock)
	if mode == "cpu":
		var h := row(col)
		for i in 3:
			button(h,["Easy","Standard","Hard"][i] + (" ✓" if difficulty==i else ""),func():difficulty=i;show_select())
	if select_opponent:
		button(col,"Random opponent",func():opponent=Data.IDS[randi()%Data.IDS.size()];start_fight())
	button(col,"Back",func():
		if select_opponent: select_opponent=false;show_select()
		elif mode=="story":show_preview()
		else:show_menu())

func _pick_fighter(id: String) -> void:
	if id == "smash" and not admin_unlocked:
		return
	if select_opponent:
		opponent=id
		start_fight()
	else:
		selected=id
		selected_variant=""
		if mode=="story":show_preview()
		else:select_opponent=true;show_select()

func _pick_armored() -> void:
	if not admin_unlocked:
		return
	selected = "smash"
	selected_variant = "armored"
	if mode == "story": show_preview()
	else: select_opponent = true; show_select()

func show_admin_unlock() -> void:
	clear_ui("admin_unlock")
	_menu_backdrop()
	var col := page("Admin unlock", "ADMIN / SMASH ACCESS")
	text(col, "Smash — both forms — is an admin pick. Enter the admin code to unlock him for this session.", 18, MUTED)
	var entry := LineEdit.new()
	entry.secret = true
	entry.placeholder_text = "Admin code"
	entry.custom_minimum_size.y = 50
	col.add_child(entry)
	if admin_note != "":
		text(col, admin_note, 16, GOLD)
	button(col, "Unlock", func():
		if entry.text.strip_edges().to_upper() == ADMIN_CODE:
			admin_unlocked = true
			admin_note = ""
			select_opponent = false
			show_select()
		else:
			admin_note = "That code doesn't open it."
			show_admin_unlock())
	button(col, "Back", show_select)

func show_preview() -> void:
	clear_ui("preview")
	mode="story"
	var lineup: Array = Story.prologue()
	var fight: Dictionary = lineup[story_index]
	opponent=fight.opponent
	var col := page("The Prologue", "STORY / FIGHT %d OF 3" % (story_index+1))
	text(col,"Bank Sinatra  →  Rico Ruffino  →  Big Hood Tha King",18,TEAL)
	text(col,"%s\nvs %s" % [Data.get_fighter(selected).name,Data.get_fighter(opponent).name],26)
	var attempts: int = store.attempts_remaining(fight.id)
	text(col,"Rooftop • Best of 3 • Easy CPU\n%s" % ("Unlimited attempts" if store.data.settings.tester_bypass else "%d / 3 attempts remaining this period" % attempts),18,MUTED)
	if not notices.is_empty():text(col,notices,16,GOLD)
	var start := button(col,"Enter the Rooftop",start_story_attempt,true)
	start.disabled=attempts<=0 and not store.data.settings.tester_bypass
	if start.disabled:text(col,"This match is resting until the next reset. Training and CPU are always open.",17,GOLD)
	button(col,"Change fighter",func():select_opponent=false;show_select())
	var h := row(col)
	button(h,"Story upgrades",show_upgrades)
	button(h,"Browse fights",show_chapters)
	button(col,"Replay story scenes",func():_play_scenes(fight.scenes_before,"preview"))
	if int(store.data.story.current)>=3:
		button(col,"Replay the gate scene",func():_play_scenes([Story.ending_scene()],"preview"))
	button(col,"Main menu",show_menu)

func enter_story() -> void:
	mode="story"
	story_index=mini(int(store.data.story.current),2)
	if int(store.data.story.current)>=3 and not store.has_seen(Story.ending_scene()):
		_play_scenes([Story.ending_scene()],"complete")
	else:show_preview()

func show_chapters() -> void:
	clear_ui("chapters")
	var col := page("Your road", "STORY / CHAPTERS")
	for i in 3:
		var completed: bool=i<int(store.data.story.current)
		var b := button(col,"%s  %d. %s" % ["✓" if completed else "·",i+1,Data.get_fighter(Story.prologue()[i].opponent).name],func():story_index=i;show_preview())
		b.disabled=i>int(store.data.story.current)
	text(col,"Fighter chapters unlocked",24)
	var unlocked: Array=store.data.story.unlocked_chapters
	text(col,"None yet" if unlocked.is_empty() else ", ".join(unlocked.map(func(id):return Data.get_fighter(id).name)),18,TEAL)
	text(col,"Unlocks are saved. Fighter chapters and the main tournament continue in a later build; this pass plays the complete three-fight prologue.",17,MUTED)
	button(col,"Back",show_preview)

func start_story_attempt() -> void:
	var fight: Dictionary=Story.prologue()[story_index]
	if not store.begin_attempt(fight.id):
		notices=store.last_error
		show_preview();return
	var unseen: Array=[]
	for id in fight.scenes_before:
		if not store.has_seen(id):unseen.append(id)
	if unseen.is_empty():start_fight()
	else:_play_scenes(unseen,"fight")

func _play_scenes(ids: Array, after: String) -> void:
	story_queue=ids.duplicate()
	next_after_story=after
	story_scene=str(story_queue.pop_front())
	panel_index=0
	show_story_panel()

func show_story_panel() -> void:
	clear_ui("story")
	panel_elapsed=0.0
	arena.scene_mode="story"
	var scene: Dictionary=Story.scenes()[story_scene]
	current_panel=scene.panels[panel_index]
	var art: String=str(current_panel.get("art",""))
	if bool(current_panel.get("silhouette",false)) or art.contains("silhouette") or art.contains("guard"):arena.gate_phase=2
	elif story_scene=="gate":arena.gate_phase=1
	var col := page(str(scene.title),"THE PROLOGUE / %d OF %d" % [panel_index+1,scene.panels.size()])
	text(col,art.replace("_"," ").capitalize(),16,MUTED)
	var speaker: String=str(current_panel.get("speaker",""))
	if not speaker.is_empty():text(col,speaker.to_upper(),17,TEAL)
	# Scripted dialogue remains available with subtitles off because this pass has no recorded voices.
	text(col,str(current_panel.text),25)
	if story_scene=="gate" and speaker.to_lower().contains("smash"):
		text(col,"Voice cue • temporary text performance",14,MUTED)
	scene_continue=button(col,"Continue",advance_story,true)
	scene_continue.disabled=true
	if store.has_seen(story_scene) and panel_index>=int(scene.panels.size()/2):
		button(col,"Skip seen scene",func():panel_index=scene.panels.size()-1;advance_story())
	text(col,"Property of LiveLayer Technology LLC.",14,MUTED)

func advance_story() -> void:
	var scene: Dictionary=Story.scenes()[story_scene]
	panel_index+=1
	if panel_index<scene.panels.size():show_story_panel();return
	store.mark_seen(story_scene)
	if not story_queue.is_empty():
		story_scene=str(story_queue.pop_front());panel_index=0;show_story_panel();return
	if next_after_story=="fight":start_fight()
	elif next_after_story=="complete":
		notices="Prologue complete. The gate is open. Your progress and chapter unlocks are saved."
		show_menu()
	else:show_preview()

func start_fight() -> void:
	clear_ui("fight")
	result_wait=0
	pending_result=false
	fight_accumulator=0.0
	ko_slow_remaining=0.0
	lesson_complete=false
	var up: Dictionary=store.get_upgrades(selected) if mode=="story" else {}
	sim=Simulation.new()
	sim.setup(selected,opponent,up,{},mode=="training",7421)
	# Intro pacing is presentation only; the deterministic combat model stays intact.
	sim.countdown = 78
	cpu=Brain.new()
	cpu.setup(0 if mode=="story" else difficulty,291)
	arena.sim=sim
	arena.scene_mode="fight"
	if mode=="training":sim.fighters[0].meter=60;sim.fighters[1].meter=60
	_build_hud()

func _build_hud() -> void:
	health_bars.clear();health_labels.clear();meter_labels.clear()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	margin.offset_left=22;margin.offset_right=-22;margin.offset_top=16
	ui.add_child(margin)
	var col:=VBoxContainer.new();margin.add_child(col)
	var h:=row(col)
	# Preserve layout and legacy readouts for programmatic access; the drawn
	# game HUD below is the visible layer.
	h.modulate.a = 0.0
	for i in 2:
		if i==1:
			var middle:=VBoxContainer.new();middle.custom_minimum_size.x=105;h.add_child(middle)
			clock_label=text(middle,"99",36,GOLD);clock_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			text(middle,"ROOFTOP",12,MUTED).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var side:=VBoxContainer.new();side.size_flags_horizontal=Control.SIZE_EXPAND_FILL;h.add_child(side)
		health_labels.append(text(side,"",19))
		var bar:=ProgressBar.new();bar.custom_minimum_size.y=18;bar.show_percentage=false
		bar.add_theme_stylebox_override("background",box(Color("17233e"),Color("344363"),4))
		bar.add_theme_stylebox_override("fill",box(TEAL if i==0 else Color("f08291"),Color(0,0,0,0),4))
		side.add_child(bar);health_bars.append(bar)
		meter_labels.append(text(side,"",16,TEAL if i==0 else GOLD))
	var tools:=row(col)
	button(tools,"Ⅱ  Pause",toggle_pause)
	text(tools,mode.to_upper()+"  •  "+str(store.data.settings.layout).to_upper(),15,MUTED)
	if mode=="training":
		button(tools,"Reset",start_fight)
		button(tools,"Dummy: "+["Idle","Guard","CPU"][dummy_mode],func():dummy_mode=(dummy_mode+1)%3;_rebuild_fight_ui())
		button(tools,"Lessons",show_lessons)
	var center:=VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	center.offset_top=160;center.offset_left=24;center.offset_right=-24
	center.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(center)
	fight_status=text(center,"",26,GOLD);fight_status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	fight_status.visible = false
	prompt_label=text(center,"",20,TEAL);prompt_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	touch=Touch.new();touch.layout=store.data.settings.layout;ui.add_child(touch)
	var game_hud = preload("res://scripts/ui/game_hud.gd").new()
	game_hud.sim = sim
	game_hud.mode = mode
	ui.add_child(game_hud)
	game_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_update_hud()

func _rebuild_fight_ui() -> void:
	var keep=sim
	clear_ui("fight")
	sim=keep;arena.sim=sim;arena.scene_mode="fight";_build_hud()

func _physics_process(delta: float) -> void:
	if screen != "fight" or paused or sim == null: return
	if pending_result:
		# A readable winner's pose follows the KO before the results screen.
		result_wait += 1
		if result_wait >= 120: show_results()
		return
	var speed := 0.30 if ko_slow_remaining > 0.0 else (0.92 if sim.hitstop > 0 else 1.15)
	ko_slow_remaining = maxf(0.0, ko_slow_remaining - delta)
	fight_accumulator += speed
	while fight_accumulator >= 1.0 and not pending_result:
		fight_accumulator -= 1.0
		_fight_tick()

func _fight_tick() -> void:
	var input:=_player_input()
	var enemy: Dictionary={}
	if mode!="training" or dummy_mode==2:enemy=cpu.decide(sim,1)
	elif dummy_mode==1:enemy={"block":true,"down":input.down}
	if mode=="training" and lesson==0:
		var distance:int=int(sim.fighters[0].x)-int(sim.fighters[1].x)
		enemy={"move":signi(distance) if absi(distance)>100 else 0,"attack":"light" if sim.frame%100==0 else ""}
	elif mode=="training" and lesson==2:
		sim.fighters[1].meter=60
		if not sim.fighters[1].prompt.is_empty():enemy={"attack":str(sim.fighters[1].prompt.get("button","light"))}
		elif sim.frame%300==0:enemy={"move":int(sim.fighters[1].facing),"attack":"special"}
	sim.step([input,enemy])
	for event in sim.events:
		arena.present_event(event)
		var kind := str(event.get("type", ""))
		var hook := ""
		if kind in ["hit", "dog", "minor_hit", "big"]:
			hook = "block" if bool(event.get("blocked", false)) else ("hit_heavy" if int(event.get("damage", 0)) >= 12 else "hit_light")
		elif kind == "block": hook = "block"
		elif kind in ["throw", "throw_break", "grab"]: hook = "throw"
		elif kind in ["round_end", "match_end"]:
			hook = "ko"
			ko_slow_remaining = 1.0
		elif kind == "fight": hook = "round_call"
		elif kind == "next_round":
			sim.countdown = 78
			hook = "round_call"
		if not hook.is_empty(): audio_hooks.play_hook(hook, bool(store.data.settings.muted))
		if mode=="training" and lesson>=0:
			if lesson==0 and event.get("type")=="block" and int(event.get("target",-1))==0:lesson_complete=true
			if lesson==1 and int(sim.fighters[0].combo_hits)>=5:lesson_complete=true
			if lesson==2 and event.get("type","")=="big" and int(event.get("target",-1))==0 and bool(event.get("blocked",false)) and int(sim.fighters[1].big_index)>=sim.fighters[1].big_hits.size():lesson_complete=true
	if mode=="training":
		for fighter in sim.fighters:
			if int(fighter.hp)<=0:fighter.hp=fighter.max_hp
	_update_hud()
	arena.queue_redraw()
	if is_instance_valid(touch): touch.queue_redraw()
	if sim.match_over and mode!="training":pending_result=true

func _process(delta: float) -> void:
	if screen == "boot":
		_boot_tick(delta)
	elif screen == "press_start":
		press_elapsed += delta
		if is_instance_valid(press_button):
			press_button.modulate.a = 0.45 + 0.55 * absf(sin(press_elapsed * 2.4))
	if screen=="story":
		panel_elapsed+=delta
		if is_instance_valid(scene_continue):
			scene_continue.disabled=panel_elapsed<float(current_panel.get("minimum_seconds",1.0))
			if scene_continue.disabled:scene_continue.text="Continue in %ds" % ceili(float(current_panel.get("minimum_seconds",1.0))-panel_elapsed)
			else:scene_continue.text="Continue"
	if is_instance_valid(arena):arena.queue_redraw()

func _player_input() -> Dictionary:
	var keyboard_down:=Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)
	var value: Dictionary=touch.sample(keyboard_down) if is_instance_valid(touch) else {"move":0,"down":false,"jump":false,"attack":"","block":false}
	var left:=Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)
	var right:=Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)
	if left or right:value.move=int(right)-int(left)
	value.down=value.down or keyboard_down
	value.jump=value.jump or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
	value.block=value.block or Input.is_physical_key_pressed(KEY_SPACE)
	# Keyboard attacks are POLLED like movement, not only event-driven: on
	# the Chromebook/Android app, key events can fail to reach
	# _unhandled_key_input while is_physical_key_pressed keeps working —
	# that is why movement worked but punches did not (CEO report,
	# Nov 15, 2026). Edge-detected here so holding a key fires once.
	var attack_keys := {
		KEY_J: "punch" if store.data.settings.layout == "simplified" else "light",
		KEY_U: "low", KEY_K: "kick", KEY_I: "heavy", KEY_L: "throw", KEY_O: "special",
	}
	for code in attack_keys:
		var held := Input.is_physical_key_pressed(code)
		if held and not bool(key_edges.get(code, false)):
			keyboard_attack = str(attack_keys[code])
		key_edges[code] = held
	if not keyboard_attack.is_empty():value.attack=keyboard_attack;keyboard_attack=""
	# Resolve attack variants after merging devices, so either device can hold Down.
	if value.attack=="punch":value.attack="low" if value.down else "light"
	elif value.attack=="kick" and value.down:value.attack="low_kick"
	return value

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	if screen == "press_start": _advance_press_start(); return
	if screen == "boot": boot_skip = true; return
	if event.physical_keycode==KEY_ESCAPE and screen=="fight":toggle_pause();return
	if event.physical_keycode==KEY_M:store.set_setting("muted",not store.data.settings.muted)
	if screen!="fight" or paused:return
	match event.physical_keycode:
		KEY_J:keyboard_attack="punch" if store.data.settings.layout=="simplified" else "light"
		KEY_U:keyboard_attack="low"
		KEY_K:keyboard_attack="kick"
		KEY_I:keyboard_attack="heavy"
		KEY_L:keyboard_attack="throw"
		KEY_O:keyboard_attack="special"
		KEY_F2:
			if mode=="training":sim.fighters[0].meter=60;sim.fighters[1].meter=60

func _update_hud() -> void:
	# Lesson objectives remain readable during training; match announcements
	# are rendered by the game HUD.
	fight_status.visible = mode == "training" and sim.countdown <= 0 and not sim.round_over
	for i in 2:
		var f:Dictionary=sim.fighters[i]
		health_bars[i].max_value=f.max_hp;health_bars[i].value=f.hp
		health_labels[i].text="%s   %s" % [Data.get_fighter(f.id).name,"●".repeat(int(sim.round_wins[i]))]
		var m:int=int(f.meter)
		meter_labels[i].text="%s  %d/60%s" % ["▰".repeat(int(m/20))+"▱".repeat(3-int(m/20)),m,"  THROW READY" if m>=20 else ""]
	clock_label.text="∞" if mode=="training" else "%02d" % ceili(sim.time_left/60.0)
	var p:Dictionary=sim.fighters[0].prompt
	touch.prompt_button=""
	touch.prompt_kind=str(p.get("kind",""))
	prompt_label.text=""
	if not p.is_empty():
		var kind:String=str(p.get("kind",""))
		if kind=="block":
			if int(sim.fighters[0].y)==0:prompt_label.text="BIG SPECIAL — TAP & HOLD BLOCK / SPACE"
		elif kind=="throw_break":prompt_label.text="GRABBED — BACK → BACK → DOWN!"
		else:
			touch.prompt_button=str(p.get("button","light"))
			prompt_label.text="%s SPECIAL — %s  /  %.1fs" % [kind.to_upper(),touch.prompt_button.to_upper(),float(p.get("remaining",0))/60.0]
	if sim.countdown>0:fight_status.text=str(ceili(sim.countdown/60.0)) + "  •  GET READY"
	elif sim.round_over:fight_status.text="ROUND OVER"
	elif pending_result or sim.match_over:fight_status.text="K.O."
	elif mode=="training":
		fight_status.text="FREE PRACTICE  •  F2 refills meter" if lesson<0 else ("CHALLENGE COMPLETE ✓" if lesson_complete else ["MOVE & BLOCK  /  Block a punch","COMBOS  /  Land five regular hits","SURVIVE  /  Tap and hold the Block prompt"][lesson])
	else:
		var combo:int=int(sim.fighters[0].combo_hits)
		fight_status.text="%d HIT COMBO" % combo if combo>1 else ""
	if sim.countdown<=0 and not sim.round_over and not sim.match_over:
		for target in sim.fighters:
			var hits:int=int(target.get("juggle_hits",0))
			if hits>=2 and (int(target.get("juggle_window",0))>0 or str(target.state)=="stunned"):
				fight_status.text="P%d  %d HITS%s" % [int(target.get("juggle_owner",0))+1,hits," — STUNNED" if str(target.state)=="stunned" else ""]

func toggle_pause() -> void:
	if screen!="fight":return
	if paused:
		_rebuild_fight_ui();return
	paused=true
	if is_instance_valid(touch):touch.clear();touch.enabled=false
	var col:=page("Paused",mode.to_upper()+" / ROOFTOP")
	text(col,"All combat timers and prompts are frozen.",18,MUTED)
	button(col,"Resume",toggle_pause,true)
	button(col,"Move guide",func():show_help(true))
	button(col,"Quit to menu",show_menu)

func show_lessons() -> void:
	paused=true
	if is_instance_valid(touch):touch.clear();touch.enabled=false
	var col:=page("Quick lessons","TRAINING / THREE CORE CHALLENGES")
	var names:=["1. Move & Block","2. Combos & the 5-Hit Rule","3. Survive the Big Special"]
	for i in 3:
		button(col,names[i],func():lesson=i;dummy_mode=0;start_fight())
	button(col,"Free practice",func():lesson=-1;start_fight())

# The original winner art is displayed at full screen; the panel carries the
# existing result actions and story progression above it.
func _results_page(winner_id: String) -> VBoxContainer:
	_menu_backdrop()
	var paths := {
		"cin": "cin-city", "rico": "rico-ruffino", "hood": "big-hood",
		"bank": "bank-sinatra", "smash": "tyshawn-smash", "smash_armored": "tyshawn-smash-gold",
		"jo": "jo-nextlevel", "lmscurt": "lmscurt", "hublo": "hublo"
	}
	var art := TextureRect.new()
	art.texture = load("res://assets/fighters/" + str(paths.get(winner_id, "cin-city")) + "-win-panel.png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.025, 0.065, 0.30)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	ui.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 24)
	var aligned := HBoxContainer.new()
	margin.add_child(aligned)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aligned.add_child(spacer)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.x = minf(size.x * 0.46, 540.0)
	aligned.add_child(scroll)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", box(Color(0.015, 0.045, 0.11, 0.87), Color("49c9ff"), 5))
	scroll.add_child(panel)
	var col := VBoxContainer.new()
	panel.add_child(col)
	text(col, "MATCH COMPLETE", 14, TEAL)
	text(col, str(Data.get_fighter(winner_id).name).to_upper() + " WINS", 38, TEAL)
	return col

func show_results() -> void:
	var win:bool=sim.winner==0
	var score:String="%d — %d" % [sim.round_wins[0],sim.round_wins[1]]
	var reward_saved:=true
	if mode=="story" and win:
		store.record_win(selected,Story.prologue()[story_index].id,opponent)
		reward_saved=store.last_error.is_empty()
	clear_ui("results")
	var col:=_results_page(selected if win else opponent)
	text(col,score,26,TEAL if win else GOLD)
	if mode=="story":
		var partings:=["Win or lose… it keeps the change.","Heh. Wolf's gotta respect teeth. Go on — the big one's waiting, and he don't pace. He sits. Like it's a throne… or a post.","Go on, then. He's awake now. We all heard the chain."]
		if win or story_index==0:text(col,"“"+str(partings[story_index])+"”",22)
		if win:
			if reward_saved:text(col,"+1 upgrade point for %s • %d saved\n%s's fighter chapter unlocked" % [Data.get_fighter(selected).name,store.get_points(selected),Data.get_fighter(opponent).name],18,TEAL)
			else:text(col,"Progress could not be saved: "+store.last_error,18,GOLD)
			button(col,"Continue",func():
				if story_index==2:_play_scenes([Story.ending_scene()],"complete")
				else:story_index+=1;show_preview(),true)
		else:button(col,"Retry",start_story_attempt,true)
		if not (win and story_index==2 and not store.has_seen(Story.ending_scene())):button(col,"Return to Story",show_preview)
	else:
		button(col,"Rematch",start_fight,true)
		button(col,"Random next opponent",func():opponent=Data.IDS[randi()%Data.IDS.size()];start_fight())
		button(col,"Change fighter / opponent",func():select_opponent=false;show_select())
	if not (mode=="story" and win and story_index==2 and not store.has_seen(Story.ending_scene())):button(col,"Main menu",show_menu)

func show_upgrades() -> void:
	clear_ui("upgrades")
	var col:=page("Story upgrades", "LOCAL PROFILE / ROSTER")
	text(col,"Permanent upgrades apply in Story. Training and CPU use base stats.",18,MUTED)
	var choose:=OptionButton.new()
	for id in Data.IDS:choose.add_item(Data.get_fighter(id).name)
	choose.selected=Data.IDS.find(selected)
	choose.item_selected.connect(func(index):selected=Data.IDS[index];show_upgrades())
	col.add_child(choose)
	text(col, Data.get_fighter(selected).name, 25, TEAL)
	for stat in ["hp", "damage", "speed"]:
		var quote: Dictionary = store.quote_upgrade(selected, stat)
		var level := stat_level(stat)
		var title: String = "Health" if stat == "hp" else stat.capitalize()
		var label := ""
		if bool(level.maxed):
			label = "%s   %s   %s — MAX" % [title, str(level.pips), str(level.now)]
		else:
			label = "%s   %s   %s → %s" % [title, str(level.pips), str(level.now), str(level.next)]
		var b := button(col, label, func(): confirm_upgrade(stat))
		b.disabled = not bool(quote.get("allowed", false))
	if not notices.is_empty():text(col,notices,16,GOLD)
	button(col,"Back",func():
		if mode=="story":show_preview()
		else:show_menu())

func confirm_upgrade(stat: String) -> void:
	clear_ui("confirm")
	var col := page("Confirm your upgrade")
	var level := stat_level(stat)
	var title: String = "Health" if stat == "hp" else stat.capitalize()
	text(col, "%s • %s\n%s → %s\nThis raise is permanent in Story." % [Data.get_fighter(selected).name, title, str(level.now), str(level.next)], 24)
	button(col,"Confirm purchase",func():
		var ok:bool=store.purchase_upgrade(selected,stat)
		notices="Upgrade saved." if ok else "Purchase could not be saved. Your points were kept."
		show_upgrades(),true)
	button(col,"Cancel",show_upgrades)

func show_help(from_pause: bool = false) -> void:
	if not from_pause: clear_ui("help")
	var col := page("The move guide")
	var grid := GridContainer.new()
	grid.columns = 2 if size.x >= 700 else 1
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(grid)

	var move := guide_panel(grid, "MOVE")
	var r := guide_row(move)
	cap(r, "WASD"); cap(r, "←→↑↓"); cap_label(r, "Move")
	r = guide_row(move)
	var pair := guide_pair(r)
	cap(pair, "↑"); cap_label(pair, "Jump")
	pair = guide_pair(r)
	cap(pair, "↑×2"); cap_label(pair, "Double jump")
	r = guide_row(move)
	pair = guide_pair(r)
	cap(pair, "←"); cap_label(pair, "Block high")
	pair = guide_pair(r)
	cap(pair, "↓+←"); cap_label(pair, "Block low")
	r = guide_row(move)
	cap(r, "SPACE"); cap_label(r, "Hold block — none in air")

	var attack := guide_panel(grid, "ATTACK")
	r = guide_row(attack)
	pair = guide_pair(r)
	cap(pair, "J"); cap_label(pair, "Light punch")
	pair = guide_pair(r)
	cap(pair, "U"); cap_label(pair, "Low punch")
	r = guide_row(attack)
	pair = guide_pair(r)
	cap(pair, "K"); cap_label(pair, "Kick")
	pair = guide_pair(r)
	cap(pair, "I"); cap_label(pair, "Heavy")
	r = guide_row(attack)
	pair = guide_pair(r)
	cap(pair, "↓+I"); cap_label(pair, "Uppercut")
	pair = guide_pair(r)
	cap(pair, "↓+K"); cap_label(pair, "Low kick")
	r = guide_row(attack)
	cap(r, "↓+J"); cap_label(r, "Low punch — 5 hits knock down")

	var juggle := guide_panel(grid, "JUGGLE — THE STRING")
	r = guide_row(juggle)
	cap(r, "↓+I", true); chain_sep(r); cap(r, "U", true); chain_sep(r); cap(r, "I", true); chain_sep(r); cap(r, "↓+K", true)
	cap_label(juggle, "Uppercut, low punch, high kick, low kick — land each hit and the full string stuns. Next hit free.")

	var specials := guide_panel(grid, "SPECIALS")
	r = guide_row(specials)
	pair = guide_pair(r)
	cap(pair, "←←"); cap_label(pair, "1 notch")
	pair = guide_pair(r)
	cap(pair, "→→"); cap_label(pair, "3 notches")
	cap_label(specials, "Then hit the flashing attack, fast.")
	r = guide_row(specials)
	cap(r, "O"); cap_label(r, "Prompt: ← minor · → big")

	var defend := guide_panel(grid, "DEFEND")
	r = guide_row(defend)
	cap(r, "BLOCK"); cap_label(r, "Timed block = half notch")
	cap_label(defend, "Hold block vs a big special: half damage. Jump escapes a capture.")

	var throw := guide_panel(grid, "THROW")
	r = guide_row(throw)
	cap(r, "←", true); chain_sep(r); cap(r, "→", true); chain_sep(r); cap(r, "J", true); cap_label(r, "Close, 1 notch")
	r = guide_row(throw)
	cap(r, "L"); cap_label(r, "Throw — grabbed? ←←↓ breaks free")

	var back := button(col, "Back", func():
		if from_pause: _rebuild_fight_ui(); paused = true; toggle_pause()
		else: show_menu())
	back.custom_minimum_size.y = 42

func _sound(frequency:float) -> void:
	if store.data.settings.muted or DisplayServer.get_name()=="headless":return
	var sound:=AudioStreamWAV.new()
	sound.format=AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate=22050
	var bytes:=PackedByteArray();bytes.resize(1764)
	for n in 882:
		var value:int=int(sin(float(n)*frequency*TAU/22050.0)*3500.0*(1.0-float(n)/882.0))
		bytes.encode_s16(n*2,value)
	sound.data=bytes
	audio_player.stream=sound;audio_player.play()

func _window_resized() -> void:
	var window:=get_tree().root
	# Portrait uses a readable phone canvas; the fight's world stays 1280 units wide.
	if window.content_scale_size!=Vector2i.ZERO:
		var target:=Vector2i(480,854) if window.size.y>window.size.x else Vector2i(1280,720)
		if window.content_scale_size!=target:window.content_scale_size=target
	_request_relayout()

func _apply_orientation(fighting:bool) -> void:
	if OS.get_name() not in ["Android","iOS"]:return
	var orientation:=DisplayServer.SCREEN_SENSOR_PORTRAIT
	if fighting:orientation=DisplayServer.SCREEN_SENSOR if store.data.settings.portrait_fights else DisplayServer.SCREEN_SENSOR_LANDSCAPE
	DisplayServer.screen_set_orientation(orientation)

func _request_relayout() -> void:
	if relayout_pending or not is_node_ready() or ui==null:return
	relayout_pending=true
	_relayout.call_deferred()

func _relayout() -> void:
	relayout_pending=false
	match screen:
		"fight":
			var was_paused:=paused
			_rebuild_fight_ui()
			if was_paused:toggle_pause()
		"menu":show_menu()
		"layout":show_layout(str(store.data.settings.layout).is_empty())
		"select":show_select()
		"preview":show_preview()
		"chapters":show_chapters()
		"upgrades":show_upgrades()
		"settings":show_settings()
		"help":show_help()
		"roster":show_roster()
		"admin_unlock":show_admin_unlock()
		"new_additions":show_new_additions()
		"boot","press_start":pass
		"story":
			var elapsed:=panel_elapsed
			show_story_panel()
			panel_elapsed=elapsed
