# Property of LiveLayer Technology LLC.
extends SceneTree

const Story = preload("res://scripts/progression/story_data.gd")
const Store = preload("res://scripts/progression/save_store.gd")
const Data = preload("res://scripts/combat/fighter_data.gd")
const Sim = preload("res://scripts/combat/fight_sim.gd")

var game
var failures: Array[String] = []
var checks := 0
var save_path := "res://work/ui_save.json"

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("UI FAIL: " + message)

func _settle() -> void:
	for i in range(3):
		await process_frame

func _nodes(node: Node) -> Array:
	var result: Array = []
	for child in node.get_children():
		result.append(child)
		result.append_array(_nodes(child))
	return result

func _button(prefix: String) -> Button:
	for node in _nodes(game.ui):
		if node is Button and node.text.begins_with(prefix):
			return node
	return null

func _press(prefix: String) -> void:
	var found := _button(prefix)
	_check(found != null, "button exists: " + prefix)
	if found != null:
		_check(not found.disabled, "button enabled: " + prefix)
		found.pressed.emit()
	await _settle()

func _fits(label: String) -> void:
	var bounds := Rect2(Vector2.ZERO, game.size)
	for node in _nodes(game.ui):
		if node is ScrollContainer:
			var rect: Rect2 = node.get_global_rect()
			_check(rect.position.x >= -1 and rect.end.x <= bounds.end.x + 1, label + " scroll horizontal bounds")
			_check(rect.position.y >= -1 and rect.end.y <= bounds.end.y + 1, label + " scroll vertical bounds")
		if node is Button:
			var rect: Rect2 = node.get_global_rect()
			_check(rect.position.x >= -1 and rect.end.x <= bounds.end.x + 1, label + " button horizontal bounds: " + node.text)

func _finger(index: int, point: Vector2, held: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = held
	game.touch._input(event)

func _key(code: Key, held: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = held
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	game._unhandled_key_input(event)

func _uppercut_input(sample: Dictionary, label: String) -> void:
	for id in Data.IDS:
		var combat = Sim.new()
		combat.setup(id, "bank", {}, {}, true)
		combat.countdown = 0
		combat.step([sample, {}])
		_check(combat.fighters[0].move == "uppercut" and not combat.fighters[0].attack_low, label + " starts a high uppercut for " + id)

func _low_kick_input(sample: Dictionary, label: String) -> void:
	var combat = Sim.new()
	combat.setup("bank", "bank", {}, {}, true)
	combat.countdown = 0
	combat.step([sample, {}])
	_check(combat.fighters[0].move == "low_kick" and combat.fighters[0].attack_low, label + " starts a distinct low kick")

func _combo_inputs(samples: Array, label: String) -> void:
	var combat = Sim.new()
	combat.setup("bank", "bank", {}, {}, true)
	combat.countdown = 0
	combat.fighters[0].x = 500
	combat.fighters[1].x = 570
	for hit in samples.size():
		combat.step([samples[hit], {}])
		for tick in 45:
			if int(combat.fighters[1].get("juggle_hits",0)) == hit + 1:
				break
			combat.step([{}, {}])
		_check(int(combat.fighters[1].get("juggle_hits",0)) == hit + 1, label + " connects hit " + str(hit + 1))
	_check(combat.fighters[1].state == "stunned", label + " completes the string into stun")

func _keyboard_checks() -> void:
	var original_layout: String = game.store.data.settings.layout
	for layout in ["simplified", "traditional"]:
		game.store.set_setting("layout", layout)
		game.touch.layout = layout
		game.touch.clear()
		var combo_samples:Array=[]
		_key(KEY_S, true)
		_key(KEY_I, true)
		var sample: Dictionary = game._player_input()
		_check(sample.down and sample.attack == "heavy", layout + " keyboard Down + I delivers heavy with Down")
		_uppercut_input(sample, layout + " keyboard Down + I")
		combo_samples.append(sample.duplicate(true))
		_key(KEY_I, false)
		_key(KEY_U, true)
		sample=game._player_input()
		_check(sample.attack == "low", layout + " Down + U keeps drop-down punch")
		combo_samples.append(sample.duplicate(true))
		_key(KEY_U, false)
		_key(KEY_J, true)
		_check(game._player_input().attack == ("low" if layout == "simplified" else "light"), layout + " Down + J retains punch mapping")
		_key(KEY_J, false)
		_key(KEY_K, true)
		sample = game._player_input()
		_check(sample.attack == "low_kick", layout + " Down + K maps low kick")
		_low_kick_input(sample, layout + " keyboard Down + K")
		var low_kick_sample:Dictionary=sample.duplicate(true)
		_key(KEY_K, false)
		_key(KEY_S, false)
		_key(KEY_I, true)
		sample=game._player_input()
		_check(sample.attack=="heavy" and not sample.down,layout+" standing I maps high kick")
		combo_samples.append(sample.duplicate(true))
		combo_samples.append(low_kick_sample)
		_combo_inputs(combo_samples,layout+" keyboard juggle")
		_key(KEY_I,false)
		_key(KEY_W, true)
		_check(game._player_input().jump and game._player_input().jump, layout + " held keyboard Up stays held for simulator edge detection")
		_key(KEY_W, false)
		_check(not game._player_input().jump, layout + " release keyboard Up clears jump")
		_key(KEY_W, true)
		_check(game._player_input().jump, layout + " fresh keyboard Up delivers second jump press")
		_key(KEY_W, false)
		if layout == "simplified":
			game.touch._regions()
			_finger(0, game.touch.regions.down.get_center(), true)
			_key(KEY_K, true)
			_low_kick_input(game._player_input(), "touch Down + keyboard Kick")
			_key(KEY_K, false)
			game.touch.clear()
			_key(KEY_S, true)
			_finger(1, game.touch.regions.kick.get_center(), true)
			_low_kick_input(game._player_input(), "keyboard Down + touch Kick")
			_finger(1, game.touch.regions.kick.get_center(), false)
			_finger(1, game.touch.regions.punch.get_center(), true)
			_check(game._player_input().attack == "low", "keyboard Down + touch Punch preserves drop-down punch")
			_key(KEY_S, false)
			game.touch.clear()
	game.store.set_setting("layout", original_layout)
	game.touch.layout = original_layout

func _hud_checks() -> void:
	var target: Dictionary = game.sim.fighters[1]
	var previous_hp: int = target.hp
	target.hp = target.max_hp
	game._update_hud()
	_check(target.max_hp == 200 and game.health_labels[1].text.contains("200/200"), "health label shows the real 200 HP pool")
	_check(game.health_bars[1].max_value == 200 and game.health_bars[1].value == 200, "health bar uses the real 200 HP pool")
	target.hp -= 14
	game._update_hud()
	_check(game.health_labels[1].text.contains("186/200"), "heavy damage displays the true remaining pool")
	_check(is_equal_approx(game.health_bars[1].value / game.health_bars[1].max_value, 0.93), "clean heavy drains exactly seven percent of the health bar")
	target.hp = previous_hp
	var before:Dictionary=game.sim.snapshot()
	game.sim.countdown=0
	for owner in 2:
		var defender:Dictionary=game.sim.fighters[1-owner]
		defender.juggle_owner=owner
		defender.juggle_hits=2
		defender.juggle_window=12
		game._update_hud()
		_check(game.fight_status.text=="P%d  2 HITS" % (owner+1),"juggle HUD shows hit count for either side")
		defender.juggle_hits=4
		defender.juggle_window=0
		defender.state="stunned"
		game._update_hud()
		_check(game.fight_status.text=="P%d  4 HITS — STUNNED" % (owner+1),"juggle HUD identifies stun for either side")
		defender.juggle_hits=0
		defender.state="idle"
	game.sim.restore(before)
	game._update_hud()

func _pose_checks() -> void:
	var fight = game.arena.sim
	for id in Data.IDS:
		var preview = Sim.new()
		preview.setup(id, id, {}, {}, true)
		game.arena.sim = preview
		for phase in [3, 10, 24]:
			for fighter in preview.fighters:
				fighter.state = "attack"
				fighter.move = "uppercut"
				fighter.down = true
				fighter.attack_frame = phase
			var before: Dictionary = preview.snapshot()
			game.arena.queue_redraw()
			await _settle()
			_check(preview.snapshot() == before, "%s uppercut pose at frame %d renders both facings without changing simulation" % [id, phase])
	game.arena.sim = fight
	game.arena.queue_redraw()

func _touch_checks() -> void:
	var touch = game.touch
	touch.layout = "simplified"
	touch.clear()
	touch._regions()
	_finger(0, touch.regions.down_back.get_center(), true)
	_finger(1, touch.regions.punch.get_center(), true)
	var sample: Dictionary = touch.sample()
	_check(sample.move == -1 and sample.down and sample.attack == "low", "two fingers: down-back plus punch maps low punch")
	_check(touch.sample().attack == "", "held attack does not auto-chain")
	_finger(1, touch.regions.punch.get_center(), false)
	_finger(1, touch.regions.kick.get_center(), true)
	sample = touch.sample()
	_check(sample.down and sample.attack == "low_kick", "simplified down plus kick maps low kick")
	_low_kick_input(sample, "simplified touch Down + Kick")
	_finger(1,touch.regions.kick.get_center(),false)
	_finger(1,touch.regions.heavy.get_center(),true)
	_uppercut_input(touch.sample(),"simplified touch Down + Heavy")
	touch.clear()
	_finger(0, touch.regions.up_forward.get_center(), true)
	_finger(1, touch.regions.block.get_center(), true)
	sample = touch.sample()
	_check(sample.move == 1 and sample.jump and sample.block, "movement diagonal and block are independent contacts")
	_check(touch.sample().jump, "held touch Up remains held for simulator edge detection")
	_finger(0, touch.regions.up_forward.get_center(), false)
	_check(not touch.sample().jump, "releasing touch Up clears jump")
	_finger(0, touch.regions.up_forward.get_center(), true)
	_check(touch.sample().jump, "fresh touch Up delivers second jump press")
	touch.clear()
	_check(not touch.sample().block and touch.contacts.is_empty(), "clear releases all touch holds")
	touch.layout = "traditional"
	touch._regions()
	for action in ["light", "low", "kick", "heavy", "throw", "special"]:
		touch.clear()
		_finger(2, touch.regions[action].get_center(), true)
		_check(touch.sample().attack == action, "traditional touch maps " + action)
	touch.clear()
	_finger(0, touch.regions.down.get_center(), true)
	_finger(1, touch.regions.heavy.get_center(), true)
	_uppercut_input(touch.sample(), "traditional touch Down + Heavy")
	_finger(1, touch.regions.heavy.get_center(), false)
	_finger(1, touch.regions.low.get_center(), true)
	_check(touch.sample().attack == "low", "traditional touch Down + Low preserves drop-down punch")
	_finger(1,touch.regions.low.get_center(),false)
	_finger(1,touch.regions.kick.get_center(),true)
	_low_kick_input(touch.sample(),"traditional touch Down + Kick")
	touch.clear()
	touch.prompt_button = "heavy"
	touch._regions()
	_finger(0, touch.regions.prompt.get_center(), true)
	_check(touch.sample().attack == "heavy", "prompt tap sends exact prompted move")
	touch.clear()
	touch.prompt_button = ""
	for action in touch.regions:
		var rect: Rect2 = touch.regions[action]
		_check(rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= touch.size.x + 1 and rect.end.y <= touch.size.y + 1, "touch region fits viewport: " + action)
	for layout in ["simplified","traditional"]:
		touch.layout=layout
		touch.clear()
		touch._regions()
		var combo_samples:Array=[]
		_finger(0,touch.regions.down.get_center(),true)
		_finger(1,touch.regions.heavy.get_center(),true)
		combo_samples.append(touch.sample())
		_finger(1,touch.regions.heavy.get_center(),false)
		var punch:String="punch" if layout=="simplified" else "low"
		_finger(1,touch.regions[punch].get_center(),true)
		combo_samples.append(touch.sample())
		_finger(1,touch.regions[punch].get_center(),false)
		_finger(0,touch.regions.down.get_center(),false)
		_finger(1,touch.regions.heavy.get_center(),true)
		combo_samples.append(touch.sample())
		_finger(1,touch.regions.heavy.get_center(),false)
		_finger(0,touch.regions.down.get_center(),true)
		_finger(1,touch.regions.kick.get_center(),true)
		combo_samples.append(touch.sample())
		_combo_inputs(combo_samples,layout+" touch juggle")
		for action in touch.regions:
			var rect:Rect2=touch.regions[action]
			_check(rect.position.x>=0 and rect.position.y>=0 and rect.end.x<=touch.size.x+1 and rect.end.y<=touch.size.y+1,layout+" touch region fits viewport: "+action)
		touch.clear()
		_finger(1,touch.regions.heavy.get_center(),true)
		_finger(2,touch.regions.kick.get_center(),true)
		touch.sample()
		_check(touch.sample().attack=="",layout+" simultaneous taps do not queue a future string")
		touch.clear()

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save-path="):
			save_path = arg.trim_prefix("--save-path=")
	_check(save_path.begins_with("res://work/"), "smoke test uses isolated work save")
	if not save_path.begins_with("res://work/"):
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://work"))
	for suffix in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await _settle()
	_check(game.screen == "layout", "first launch requires explicit layout")
	await _press("SIMPLIFIED")
	_check(game.screen == "menu" and game.store.data.settings.layout == "simplified", "layout selection saves and opens menu")
	_fits("landscape menu")
	game.show_help()
	await _settle()
	_check(game.screen == "help", "move guide opens")
	game.show_settings()
	await _settle()
	await _press("Subtitles:")
	_check(not game.store.data.settings.subtitles, "subtitle preference persists")
	await _press("Placeholder sound effects:")
	_check(game.store.data.settings.muted, "mute preference persists")
	await _press("Tester story limit bypass:")
	_check(game.store.data.settings.tester_bypass, "tester bypass toggles")
	game.mode = "cpu"
	game.select_opponent = false
	for id in Data.IDS:
		game.show_select()
		await _settle()
		await _press(Data.get_fighter(id).name)
		_check(game.selected == id and game.select_opponent, "all four fighter choices work: " + id)
		game.select_opponent = false
	game.selected = "cin"
	game.opponent = "bank"
	game.start_fight()
	await _settle()
	_touch_checks()
	_keyboard_checks()
	_hud_checks()
	await _pose_checks()
	for tick in range(600):
		game._physics_process(1.0 / 60.0)
	_check(game.sim.frame == 600, "CPU match runs 600 fixed simulation steps")
	_check(game.sim.fighters.size() == 2, "fight uses two fighters")
	var old_frame: int = game.sim.frame
	game.toggle_pause()
	for tick in range(30):
		game._physics_process(1.0 / 60.0)
	_check(game.sim.frame == old_frame, "pause freezes fight simulation")
	game.toggle_pause()
	_check(not game.paused and game.screen == "fight", "resume returns to active fight")
	game.mode = "training"
	game.start_fight()
	await _settle()
	_check(game.sim.training and game.sim.fighters[0].meter == 60, "free training has infinite practice and starting meter")
	game.dummy_mode = 1
	for tick in range(90):
		game._physics_process(1.0 / 60.0)
	_check(game.screen == "fight", "guard dummy can run")
	game.show_lessons()
	await _settle()
	_check(_button("1. Move & Block") != null and _button("2. Combos") != null and _button("3. Survive") != null, "all three locked lessons available")
	await _press("Free practice")
	_check(game.lesson == -1 and not game.paused, "free practice returns from lesson menu")
	game.mode = "story"
	game.story_index = 0
	game.show_preview()
	await _settle()
	_check(game.opponent == "bank", "story starts against Bank Sinatra")
	game.start_story_attempt()
	await _settle()
	_check(game.screen == "story" and game.story_scene == "pull_in", "first attempt begins pull-in scene")
	var guard := 0
	while game.screen == "story" and guard < 30:
		game.advance_story()
		guard += 1
		await _settle()
	_check(game.screen == "fight", "prologue panels lead to playable match")
	_check(game.store.has_seen("pull_in") and game.store.has_seen("businessman"), "seen panels save for retry behavior")
	for fight_index in range(3):
		game.story_index = fight_index
		game.opponent = Story.prologue()[fight_index].opponent
		game.mode = "story"
		game.start_fight()
		game.sim.winner = 0
		game.sim.round_wins = [2, 0]
		game.show_results()
		await _settle()
		_check(int(game.store.data.story.current) == fight_index + 1, "story win advances match " + str(fight_index))
		_check(game.store.data.story.unlocked_chapters.has(game.opponent), "story win unlocks opponent chapter " + game.opponent)
	_check(game.store.get_points("cin") == 3, "three story wins award chosen fighter three points")
	game.show_upgrades()
	await _settle()
	game.confirm_upgrade("hp")
	await _settle()
	_check(game.screen == "confirm", "upgrade opens exact-change confirmation")
	_check(_button("Confirm purchase") != null and _button("Cancel") != null, "upgrade requires explicit confirmation")
	await _press("Cancel")
	_check(game.store.get_points("cin") == 3, "cancel preserves upgrade points")
	game.confirm_upgrade("hp")
	await _settle()
	await _press("Confirm purchase")
	_check(game.store.get_points("cin") == 2 and game.store.get_upgrades("cin").hp == 1, "confirmed fighter-specific upgrade persists")
	game._play_scenes(["gate"], "preview")
	await _settle()
	_check(game.arena.gate_phase == 1, "gate begins with no visible guard")
	game.advance_story()
	await _settle()
	_check(game.current_panel.text == "Free or forgotten, brothers — that's the whole menu." and game.arena.gate_phase == 1, "Smash exact first line is heard unseen")
	game.advance_story()
	game.advance_story()
	await _settle()
	_check(game.arena.gate_phase == 2, "Smash silhouette appears only after voice beat")
	game.advance_story()
	await _settle()
	_check(game.current_panel.text == "Win it all back — or join the quiet ones." and game.arena.gate_phase == 2, "Smash exact final line uses silhouette")
	var verify = Store.new()
	_check(verify.load_save(save_path), "local save reloads after UI progression")
	_check(int(verify.data.story.current) == 3 and verify.get_points("cin") == 2, "save reload preserves full prologue and upgrade spend")
	for dimensions in [Vector2i(1280,720), Vector2i(720,1280), Vector2i(390,844), Vector2i(844,390)]:
		root.size = dimensions
		await _settle()
		game.show_menu()
		await _settle()
		_fits(str(dimensions) + " menu")
		game.show_select()
		await _settle()
		_fits(str(dimensions) + " fighter select")
		game.mode = "training"
		game.start_fight()
		await _settle()
		_touch_checks()
		if dimensions.y > dimensions.x:
			_check(is_equal_approx(game.arena._world_scale.x, game.arena._world_scale.y), "portrait arena preserves fighter proportions")
			_check(game.arena._world_offset.y >= 160, "portrait arena leaves HUD room")
		_fits(str(dimensions) + " training")
		game.show_settings()
		await _settle()
		_fits(str(dimensions) + " settings")
	game.queue_free()
	await process_frame
	var args := OS.get_cmdline_args()
	for i in range(args.size() - 1):
		if args[i] == "--log-file":
			var log_path: String = args[i + 1]
			if not log_path.is_absolute_path() and not log_path.begins_with("res://"):
				log_path = "res://" + log_path
			if FileAccess.file_exists(log_path):
				var log_text := FileAccess.get_file_as_string(log_path)
				_check(not log_text.contains("SCRIPT ERROR:"), "no script runtime errors in UI smoke log")
				_check(not log_text.contains("Invalid polygon"), "no invalid rendering polygons in UI smoke log")
	print("UI smoke: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
