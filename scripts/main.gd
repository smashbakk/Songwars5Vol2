# Property of LiveLayer Technology LLC.
extends Control

const Data = preload("res://scripts/combat/fighter_data.gd")
const Simulation = preload("res://scripts/combat/fight_sim.gd")
const Brain = preload("res://scripts/combat/cpu_brain.gd")
const SaveStore = preload("res://scripts/progression/save_store.gd")
const Story = preload("res://scripts/progression/story_data.gd")
const Arena = preload("res://scripts/ui/arena_view.gd")
const Touch = preload("res://scripts/ui/touch_controls.gd")
const TEAL = Color("53ebc5")
const GOLD = Color("ffd18a")
const INK = Color("0c1329")
const PALE = Color("e7ecff")
const MUTED = Color("a1adcc")

var store = SaveStore.new()
var arena: Control
var ui: Control
var touch: Control
var sim: RefCounted
var cpu: RefCounted
var screen := "menu"
var mode := "cpu"
var selected := "cin"
var opponent := "bank"
var difficulty := 1
var story_index := 0
var select_opponent := false
var paused := false
var result_wait := 0
var keyboard_attack := ""
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
var relayout_pending := false

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
	get_tree().root.size_changed.connect(_window_resized)
	resized.connect(_request_relayout)
	_window_resized()
	if str(store.data.settings.get("layout", "")).is_empty():
		show_layout(true)
	else:
		show_menu()

func _setup_theme() -> void:
	var t := Theme.new()
	t.default_font_size = 20
	t.set_color("font_color", "Label", PALE)
	t.set_color("font_color", "Button", PALE)
	t.set_color("font_hover_color", "Button", TEAL)
	t.set_color("font_disabled_color", "Button", MUTED)
	t.set_stylebox("normal", "Button", box(Color("18223c"), Color("344363")))
	t.set_stylebox("hover", "Button", box(Color("203850"), TEAL))
	t.set_stylebox("pressed", "Button", box(Color("225b61"), TEAL))
	t.set_stylebox("focus", "Button", box(Color(0,0,0,0), GOLD))
	t.set_stylebox("disabled", "Button", box(Color("111a30"), Color("29324c")))
	t.set_constant("outline_size", "Label", 0)
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
	panel.add_theme_stylebox_override("panel", box(Color(0.035,0.055,0.11,0.96),Color("344363"),20))
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
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func row(parent: Node) -> HBoxContainer:
	var h := HBoxContainer.new()
	parent.add_child(h)
	return h

func show_menu() -> void:
	clear_ui("menu")
	var col := page("Keep your name lit.")
	text(col,"The Rooftop is open. Four fighters. One road to the gate.",20,MUTED)
	button(col,"STORY  /  The Prologue",enter_story,true)
	button(col,"PLAYER vs CPU",func(): mode="cpu"; select_opponent=false; show_select())
	button(col,"TRAINING  /  Free practice",func(): mode="training"; lesson=-1; select_opponent=false; show_select())
	var h := row(col)
	button(h,"Upgrades",show_upgrades)
	button(h,"Settings",show_settings)
	button(h,"Move guide",show_help)
	if not notices.is_empty(): text(col,notices,16,GOLD)
	text(col,"PASS 1 • MECHANICS BUILD\nProperty of LiveLayer Technology LLC.",14,MUTED)

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
	button(col,"Placeholder sound effects: " + ("MUTED" if store.data.settings.muted else "ON"),func():store.set_setting("muted",not store.data.settings.muted);show_settings())
	button(col,"Portrait fights: " + ("ENABLED" if store.data.settings.portrait_fights else "Landscape recommended"),func():store.set_setting("portrait_fights",not store.data.settings.portrait_fights);show_settings())
	button(col,"Tester story limit bypass: " + ("ON" if store.data.settings.tester_bypass else "OFF"),func():store.set_setting("tester_bypass",not store.data.settings.tester_bypass);show_settings())
	text(col,"Progress is saved on this device. Story attempts reset at 00:00 and 12:00 UTC in this offline prototype. Tester bypass is available for this testing build.",17,MUTED)
	text(col,"Save: " + ProjectSettings.globalize_path(store.save_path),14,MUTED)
	button(col,"Back",show_menu)

func show_select() -> void:
	clear_ui("select")
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
		var portrait := ColorRect.new()
		portrait.color = Color(info.color) * Color(0.4,0.4,0.4,1)
		portrait.custom_minimum_size.y = 54
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(portrait)
		var mark := Label.new()
		mark.text = str(info.name).substr(0,1)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.add_theme_font_size_override("font_size",38)
		mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		portrait.add_child(mark)
		button(card,info.name,func():_pick_fighter(id))
	if mode == "cpu":
		var h := row(col)
		for i in 3:
			button(h,["Easy","Standard","Hard"][i] + (" ✓" if difficulty==i else ""),func():difficulty=i;show_select())
	if select_opponent:
		button(col,"Random opponent",func():opponent=Data.IDS[randi()%4];start_fight())
	button(col,"Back",func():
		if select_opponent: select_opponent=false;show_select()
		elif mode=="story":show_preview()
		else:show_menu())

func _pick_fighter(id: String) -> void:
	if select_opponent:
		opponent=id
		start_fight()
	else:
		selected=id
		if mode=="story":show_preview()
		else:select_opponent=true;show_select()

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
	text(col,"Rooftop • Best of 3 • Easy CPU\n%s" % ("Tester bypass active" if store.data.settings.tester_bypass else "%d / 3 attempts remaining this period" % attempts),18,MUTED)
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
	lesson_complete=false
	var up: Dictionary=store.get_upgrades(selected) if mode=="story" else {}
	sim=Simulation.new()
	sim.setup(selected,opponent,up,{},mode=="training",7421)
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
	prompt_label=text(center,"",20,TEAL);prompt_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	touch=Touch.new();touch.layout=store.data.settings.layout;ui.add_child(touch)
	var track:=Label.new();track.text="ROOFTOP / PLACEHOLDER AUDIO  •  M: MUTE"
	track.add_theme_font_size_override("font_size",12);track.add_theme_color_override("font_color",MUTED)
	track.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	track.offset_top=-18;track.offset_left=24;track.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(track)
	_update_hud()

func _rebuild_fight_ui() -> void:
	var keep=sim
	clear_ui("fight")
	sim=keep;arena.sim=sim;arena.scene_mode="fight";_build_hud()

func _physics_process(_delta: float) -> void:
	if screen!="fight" or paused or sim==null:return
	if pending_result:
		result_wait+=1
		if result_wait>=80:show_results()
		return
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
		if event.get("type","") in ["hit","block","throw","big","minor_hit","dog"]:_sound(360 if event.get("type")=="block" else 110)
		if event.get("type","")=="big_start":_sound(55)
		if mode=="training" and lesson>=0:
			if lesson==0 and event.get("type")=="block" and int(event.get("target",-1))==0:lesson_complete=true
			if lesson==1 and int(sim.fighters[0].combo_hits)>=5:lesson_complete=true
			if lesson==2 and event.get("type","")=="big" and int(event.get("target",-1))==0 and bool(event.get("blocked",false)) and int(sim.fighters[1].big_index)>=sim.fighters[1].big_hits.size():lesson_complete=true
	if mode=="training":
		# The free-practice dummy recovers automatically; a reset also restores both meters.
		for fighter in sim.fighters:
			if int(fighter.hp)<=0:fighter.hp=fighter.max_hp
	_update_hud()
	arena.queue_redraw()
	touch.queue_redraw()
	if sim.match_over and mode!="training":pending_result=true

func _process(delta: float) -> void:
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
	if not keyboard_attack.is_empty():value.attack=keyboard_attack;keyboard_attack=""
	# Resolve attack variants after merging devices, so either device can hold Down.
	if value.attack=="punch":value.attack="low" if value.down else "light"
	elif value.attack=="kick" and value.down:value.attack="low_kick"
	return value

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:return
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
	for i in 2:
		var f:Dictionary=sim.fighters[i]
		health_bars[i].max_value=f.max_hp;health_bars[i].value=f.hp
		health_labels[i].text="%s  %d/%d   %s" % [Data.get_fighter(f.id).name,f.hp,f.max_hp,"●".repeat(int(sim.round_wins[i]))]
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

func show_results() -> void:
	var win:bool=sim.winner==0
	var score:String="%d — %d" % [sim.round_wins[0],sim.round_wins[1]]
	var reward_saved:=true
	if mode=="story" and win:
		store.record_win(selected,Story.prologue()[story_index].id,opponent)
		reward_saved=store.last_error.is_empty()
	clear_ui("results")
	var col:=page("You kept your name lit." if win else "The Rooftop remembers.",mode.to_upper()+" / RESULT")
	text(col,"%s wins  •  %s" % [Data.get_fighter(selected if win else opponent).name,score],26,TEAL if win else GOLD)
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
		button(col,"Random next opponent",func():opponent=Data.IDS[randi()%4];start_fight())
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
	text(col,"%s  /  %d points" % [Data.get_fighter(selected).name,store.get_points(selected)],25,TEAL)
	for stat in ["hp","damage","speed"]:
		var quote:Dictionary=store.quote_upgrade(selected,stat)
		var b:=button(col,"%s  /  %s → %s  /  %d points" % ["Health" if stat=="hp" else stat.capitalize(),str(quote.get("before","")),str(quote.get("after","MAX")),int(quote.get("cost",0))],func():confirm_upgrade(stat))
		b.disabled=not bool(quote.get("allowed",false))
	if not notices.is_empty():text(col,notices,16,GOLD)
	button(col,"Back",func():
		if mode=="story":show_preview()
		else:show_menu())

func confirm_upgrade(stat:String) -> void:
	clear_ui("confirm")
	var quote:Dictionary=store.quote_upgrade(selected,stat)
	var col:=page("Confirm your upgrade")
	text(col,"%s • %s\n%s → %s\nSpend exactly %d points. %d points will remain." % [Data.get_fighter(selected).name,stat.capitalize(),str(quote.before),str(quote.after),quote.cost,store.get_points(selected)-int(quote.cost)],24)
	button(col,"Confirm purchase",func():
		var ok:bool=store.purchase_upgrade(selected,stat)
		notices="Upgrade saved." if ok else "Purchase could not be saved. Your points were kept."
		show_upgrades(),true)
	button(col,"Cancel",show_upgrades)

func show_help(from_pause:bool=false) -> void:
	if not from_pause:clear_ui("help")
	var col:=page("The move guide")
	text(col,"MOVE  WASD / arrows. Up jumps; release and press Up again while airborne for one higher double jump. Steer and attack in the air. Hold Back to block high, Down + Back to block low. Space / HOLD BLOCK is the accessible block control. No air blocking.",18)
	text(col,"ATTACK  J light punch · U low punch · K kick · I heavy. Down + I / Heavy is a rising uppercut that catches jump-ins. Down + K / Kick is a low kick in both layouts. Simplified: Down + J / Punch gives a low punch, and Heavy supplies the high kick / uppercut. Five regular hits knock down. Attacks chain manually after a clean hit; every hit keeps full damage.",18)
	text(col,"JUGGLE  Uppercut → Low punch → standing Heavy (high kick) → Down + Kick. Press each attack after the previous hit connects. Only the next correct move hits during the float; four hits stun for 90 frames and leave the next hit free. Wrong moves whiff. Landing or running out of time ends the string. Each launch permits one string; damage stays unscaled.",18)
	text(col,"SPECIALS  Double-tap Back with 1 notch, or Forward with 3, then press the prompted attack within 2 seconds. Traditional Special / O opens the same prompt: hold Back for minor, Forward for big. Missing a big prompt costs 1 notch.",18)
	text(col,"DEFEND  Block within 0.25 seconds of a regular hit to earn half a notch once per engagement. During a big special, tap and keep holding BLOCK / Space for half damage and survival. Jump before capture to evade.",18)
	text(col,"THROW  Back → Forward → Punch, or L / Throw, at close range with at least 1 notch. Meter is held, not spent: 16 / 22 / 30 damage. When grabbed, Back → Back → Down within 0.6 seconds breaks free.",18)
	text(col,"TRAIN  Free reset, idle / guard / CPU dummy, full starting meter, F2 refill, and three quick practice challenges. Esc pauses. M mutes placeholder effects.",18,MUTED)
	button(col,"Back",func():
		if from_pause:_rebuild_fight_ui();paused=true;toggle_pause()
		else:show_menu())

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
		"story":
			var elapsed:=panel_elapsed
			show_story_panel()
			panel_elapsed=elapsed
