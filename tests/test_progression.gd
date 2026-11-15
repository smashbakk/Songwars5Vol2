extends RefCounted
## Property of LiveLayer Technology LLC.

const SaveStore = preload("res://scripts/progression/save_store.gd")
const StoryData = preload("res://scripts/progression/story_data.gd")
const Sim = preload("res://scripts/combat/fight_sim.gd")
static var checks := 0

static func run() -> Array:
	checks = 0
	var failures: Array = []
	var path := "res://work/tests/progression_%d.json" % Time.get_ticks_usec()
	var store = SaveStore.new()
	_check(not store.load_save(path), "Missing save starts fresh", failures)
	_check(store.data.settings.layout == "", "First launch has no silently chosen layout", failures)
	_check(store.set_setting("layout", "traditional"), "Layout saves", failures)
	_check(not store.set_setting("layout", "unknown"), "Unknown layout rejected", failures)
	_check(store.get_points("cin") == 0, "Fresh fighter has no points", failures)
	_check(not store.purchase_upgrade("cin", "hp"), "Cannot buy without fighter points", failures)
	store.record_win("cin", "prologue_0", "bank")
	_check(store.get_points("cin") == 1 and store.get_points("bank") == 0, "Story points belong to the winning fighter", failures)
	_check(store.data.story.current == 1, "First win advances to the next match", failures)
	_check("bank" in store.data.story.unlocked_chapters, "Beating Bank unlocks his chapter immediately", failures)
	var health_quote: Dictionary = store.quote_upgrade("cin", "hp")
	_check(health_quote.allowed and health_quote.cost == 1 and health_quote.before == "200 HP" and health_quote.after == "210 HP", "Health quote shows the real pool and ten-HP step", failures)
	_check(store.purchase_upgrade("cin", "hp"), "Health purchase spends one point", failures)
	_check(store.get_upgrades("cin").hp == 1 and store.get_points("cin") == 0, "Health upgrades use +10 steps and exact cost", failures)
	store.record_win("cin", "prologue_0", "bank")
	store.record_win("cin", "prologue_0", "bank")
	store.record_win("cin", "prologue_0", "bank")
	_check(store.get_points("cin") == 3, "Replay wins continue to earn points", failures)
	var quote: Dictionary = store.quote_upgrade("cin", "damage")
	_check(quote.allowed and quote.cost == 3 and quote.before == "Standard" and quote.after == "Power", "Damage quote states exact class change", failures)
	_check(store.purchase_upgrade("cin", "damage"), "Damage class purchase succeeds", failures)
	_check(not store.quote_upgrade("cin", "damage").allowed and not store.quote_upgrade("cin", "speed").allowed, "Class ceilings cannot be exceeded", failures)
	store.data.fighters.hood.points = 30
	_check(not store.purchase_upgrade("hood", "damage"), "Power base fighter cannot buy damage", failures)
	_check(store.purchase_upgrade("hood", "speed") and store.purchase_upgrade("hood", "speed"), "Slow fighter buys two speed steps", failures)
	_check(not store.purchase_upgrade("hood", "speed"), "Speed stops at Fast", failures)
	for i in range(4):
		_grant_point(store, "cin")
		_check(store.purchase_upgrade("cin", "hp"), "Health purchases before cap", failures)
	_check(store.get_upgrades("cin").hp == 5 and not store.purchase_upgrade("cin", "hp"), "Health stops at 250 after the same five purchases", failures)
	_check(store.quote_upgrade("cin", "hp").before == "250 HP", "Capped health quote uses the real pool", failures)
	store.record_win("bank", "prologue_2", "hood")
	_check(store.data.story.current == 1 and store.get_points("bank") == 0, "Future fight cannot skip progression", failures)
	store.record_win("bank", "prologue_1", "rico")
	store.record_win("hood", "prologue_2", "hood")
	_check(store.data.story.current == 3 and store.data.story.unlocked_chapters.size() == 3, "Prologue clears after all three scheduled wins", failures)
	store.mark_seen("gate")
	var loaded = SaveStore.new()
	_check(loaded.load_save(path), "Save reload succeeds", failures)
	_check(loaded.data.settings.layout == "traditional" and loaded.has_seen("gate"), "Layout and seen scenes survive reload", failures)
	_check(loaded.get_upgrades("cin").damage == 1 and loaded.data.story.current == 3, "Upgrades and progression survive reload", failures)
	for i in range(3):
		_check(loaded.begin_attempt("limit", 43199), "Three attempts available in fixed period", failures)
	_check(loaded.attempts_remaining("limit", 43199) == 0 and not loaded.begin_attempt("limit", 43199), "Fourth attempt is blocked", failures)
	_check(loaded.attempts_remaining("other_match", 43199) == 3, "Attempt counts belong to individual match", failures)
	_check(loaded.attempts_remaining("limit", 43200) == 3, "UTC twelve-hour boundary resets allowance", failures)
	loaded.data.settings.tester_bypass = true
	_check(loaded.begin_attempt("limit", 43199) and loaded.attempts_remaining("limit", 43199) == 3, "Explicit tester bypass allows practice", failures)
	loaded.save()
	var corrupt := FileAccess.open(path, FileAccess.WRITE)
	corrupt.store_string("{broken JSON")
	corrupt.close()
	var recovered = SaveStore.new()
	_check(recovered.load_save(path) and recovered.last_error.contains("Recovered"), "Damaged primary recovers valid backup", failures)
	_check(recovered.save(), "Recovered save can be atomically rewritten", failures)
	_check(FileAccess.file_exists(path + ".corrupt"), "Damaged save preserved for recovery", failures)
	var raw: Dictionary = recovered.data.duplicate(true)
	raw.fighters.cin.points = -4
	raw.fighters.cin.upgrades.hp = 999
	raw.settings.layout = "garbage"
	var invalid := FileAccess.open(path, FileAccess.WRITE)
	invalid.store_string(JSON.stringify(raw))
	invalid.close()
	var sanitized = SaveStore.new()
	_check(sanitized.load_save(path) and sanitized.get_points("cin") == 0 and sanitized.get_upgrades("cin").hp == 5, "Loaded numbers are bounded and negative balances rejected", failures)
	_check(sanitized.data.settings.layout == "", "Invalid loaded layout requires fresh choice", failures)
	var chapters: Array = StoryData.chapter_lineups()
	_check(chapters.size() == 10 and chapters[9].opponents == ["rico", "bank", "smash"], "All ten locked chapter lineups retained", failures)
	var fights: Array = StoryData.prologue()
	_check(fights[0].opponent == "bank" and fights[1].opponent == "rico" and fights[2].opponent == "hood", "Prologue opponent order is locked", failures)
	var panels: Array = StoryData.scenes().gate.panels
	_check(panels[1].text == "Free or forgotten, brothers — that's the whole menu." and not panels[1].silhouette, "Smash voice appears unseen with exact line", failures)
	_check(panels[3].silhouette and panels[4].text == "Win it all back — or join the quiet ones.", "Silhouette follows voice and preserves second locked line", failures)
	_test_legacy_health_scale(path + ".legacy", failures)
	for suffix in ["", ".bak", ".tmp", ".corrupt"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	print("Progression: %d checks, %d failures." % [checks, failures.size()])
	return failures

static func _test_legacy_health_scale(path: String, failures: Array) -> void:
	# Exact version-1 shape: health upgrades were always counts, never HP.
	var legacy: Dictionary = {
		"version": 1,
		"settings": {"layout": "simplified", "subtitles": true, "muted": false, "portrait_fights": false, "tester_bypass": false},
		"fighters": {
			"cin": {"points": 5, "upgrades": {"hp": 3, "damage": 1, "speed": 0}},
			"rico": {"points": 0, "upgrades": {"hp": 0, "damage": 0, "speed": 0}},
			"hood": {"points": 7, "upgrades": {"hp": 4, "damage": 0, "speed": 2}},
			"bank": {"points": 0, "upgrades": {"hp": 0, "damage": 0, "speed": 0}},
		},
		"story": {"current": 1, "seen": {"gate": true}, "completed": {"prologue_0": true}, "unlocked_chapters": ["bank"], "attempts": {"prologue_1": {"period": 0, "used": 2}}},
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	var loaded = SaveStore.new()
	_check(loaded.load_save(path) and loaded.data.version == 1, "Existing version-1 saves load without a schema migration", failures)
	_check(loaded.data.fighters == legacy.fighters and loaded.data.story == legacy.story and loaded.data.settings == legacy.settings, "Legacy purchases, balances, settings, attempts and story progress retain their values", failures)
	var quote: Dictionary = loaded.quote_upgrade("cin", "hp")
	_check(quote.allowed and quote.before == "230 HP" and quote.after == "240 HP" and quote.cost == 1, "Legacy health counts quote the corresponding larger pool", failures)
	_check(not loaded.quote_upgrade("hood", "hp").allowed and loaded.quote_upgrade("hood", "hp").before == "250 HP", "Big Hood retains his four-purchase health ceiling", failures)
	var sim = Sim.new()
	sim.setup("cin", "hood", loaded.get_upgrades("cin"), loaded.get_upgrades("hood"))
	_check(sim.fighters[0].max_hp == 230 and sim.fighters[1].max_hp == 250, "Legacy health counts apply to the real story combat pools", failures)
	_check(sim.fighters[0].damage_rank == 2 and sim.fighters[1].speed_rank == 2, "Legacy class upgrades apply in combat", failures)
	_check(loaded.begin_attempt("prologue_1", 1) and loaded.attempts_remaining("prologue_1", 1) == 0, "Legacy attempt usage continues at the existing limit", failures)
	loaded.record_win("cin", "prologue_1", "rico")
	_check(loaded.data.story.current == 2 and loaded.get_points("cin") == 6 and "rico" in loaded.data.story.unlocked_chapters, "A legacy save continues story progression and awards the next win", failures)
	var reloaded = SaveStore.new()
	_check(reloaded.load_save(path) and reloaded.get_upgrades("cin").hp == 3 and reloaded.get_upgrades("hood").hp == 4 and reloaded.has_seen("gate"), "Continuing a legacy save preserves original purchase counts and seen scenes on disk", failures)
	for suffix in ["", ".bak", ".tmp", ".corrupt"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))

static func _grant_point(store, id: String) -> bool:
	store.data.fighters[id].points += 1
	return true

static func _check(condition: bool, description: String, failures: Array) -> void:
	checks += 1
	if not condition:
		failures.append(description)
