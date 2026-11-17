extends RefCounted

# Property of LiveLayer Technology LLC.
# v8 sprite package: every fighter's full pose set must load from the
# project at 640x640, and the arena's pose/form mapping must resolve the
# poses the fight actually shows (incl. Rico's wolf morph burst and
# Smash's gold swap). A missing or unloadable sprite is a failure —
# a fighter must never go invisible.

const Arena = preload("res://scripts/ui/arena_view.gd")

const SETS: Array = ["bank-sinatra", "big-hood", "cin-city", "hublo", "jo-nextlevel", "lmscurt", "rico-ruffino", "rico-wolf", "tyshawn-smash", "tyshawn-smash-gold"]
const POSES: Array = ["idle", "idle-1", "idle-2", "idle-3", "idle-4", "fwd", "back", "walk-1", "walk-2", "walk-3", "walk-4", "punch", "low-punch", "kick", "roundhouse", "uppercut", "crouch-uppercut", "sweep", "lunge", "throw", "block", "crouch", "hurt", "dizzy", "ko", "ko-panel", "jump", "dash-fwd", "dash-back", "getup", "intro", "win", "win-jump", "win-panel", "finisher", "portrait"]

static var failures: Array = []
static var check_count: int = 0

static func _check(condition: bool, message: String) -> void:
	check_count += 1
	if not condition:
		failures.append(message)

static func run() -> Array:
	failures = []
	check_count = 0
	_test_loads()
	_test_mapping()
	print("Sprites: %d checks, %d failures." % [check_count, failures.size()])
	return failures

static func _test_loads() -> void:
	for prefix in SETS:
		for pose in POSES:
			var path := "res://assets/fighters/" + str(prefix) + "-" + str(pose) + ".png"
			_check(ResourceLoader.exists(path), "Sprites: missing file " + path)
			if not ResourceLoader.exists(path):
				continue
			var tex := load(path) as Texture2D
			_check(tex != null, "Sprites: unloadable texture " + path)
			if tex != null:
				_check(tex.get_size() == Vector2(640, 640), "Sprites: %s is %s, expected 640x640" % [path, str(tex.get_size())])
	# Cin City's extra pose and Rico's five morph frames complete the 366.
	_check(load("res://assets/fighters/cin-city-special-dog-lunge.png") as Texture2D != null, "Sprites: cin-city-special-dog-lunge.png unloadable")
	for n in range(1, 6):
		_check(load("res://assets/fighters/rico-wolf-morph-%d.png" % n) as Texture2D != null, "Sprites: rico-wolf-morph-%d.png unloadable" % n)

static func _fighter(state: String, move: String = "", age: int = 0, extra: Dictionary = {}) -> Dictionary:
	var f: Dictionary = {"state": state, "move": move, "attack_frame": age, "facing": 1, "down": false, "blocking": false, "prev_move": 0, "minor": "lunge", "y": 0}
	f.merge(extra, true)
	return f

static func _test_mapping() -> void:
	var arena = Arena.new()
	# --- Form: Rico's wolf burst (morph frames, then the wolf set). ---
	var form: Array = arena._sprite_form("rico", _fighter("big_start", "big", 0))
	_check(str(form[0]) == "rico-wolf" and str(form[1]) == "morph-1", "Sprites: Rico big_start frame 0 should open morph-1, got %s" % str(form))
	form = arena._sprite_form("rico", _fighter("big_start", "big", 12))
	_check(str(form[1]) == "morph-3", "Sprites: Rico big_start frame 12 should be morph-3, got %s" % str(form))
	form = arena._sprite_form("rico", _fighter("big_start", "big", 29))
	_check(str(form[1]) == "morph-5", "Sprites: Rico big_start frame 29 should be morph-5, got %s" % str(form))
	form = arena._sprite_form("rico", _fighter("big_start", "big", 45))
	_check(str(form[0]) == "rico-wolf" and str(form[1]).is_empty(), "Sprites: Rico after the burst should be the wolf set, got %s" % str(form))
	form = arena._sprite_form("rico", _fighter("big", "big", 10))
	_check(str(form[0]) == "rico-wolf", "Sprites: Rico during his big should be wolf form, got %s" % str(form))
	form = arena._sprite_form("rico", _fighter("idle"))
	_check(str(form[0]) == "rico-ruffino", "Sprites: Rico at idle should be base form, got %s" % str(form))
	# --- Form: Smash's gold swap (explosive flash, then gold). ---
	form = arena._sprite_form("smash", _fighter("big_start", "big", 0))
	_check(str(form[0]) == "tyshawn-smash-gold", "Sprites: Smash big_start frame 0 should flash gold, got %s" % str(form))
	form = arena._sprite_form("smash", _fighter("big_start", "big", 3))
	_check(str(form[0]) == "tyshawn-smash", "Sprites: Smash big_start frame 3 should flash back to base, got %s" % str(form))
	form = arena._sprite_form("smash", _fighter("big", "big", 10))
	_check(str(form[0]) == "tyshawn-smash-gold", "Sprites: Smash during his big should be gold form, got %s" % str(form))
	form = arena._sprite_form("smash", _fighter("idle"))
	_check(str(form[0]) == "tyshawn-smash", "Sprites: Smash at idle should be base form, got %s" % str(form))
	form = arena._sprite_form("cin", _fighter("idle"))
	_check(str(form[0]) == "cin-city", "Sprites: Cin prefix should be cin-city, got %s" % str(form))
	# --- Poses: core state/move map. ---
	_check(arena._sprite_pose("bank", _fighter("idle"), "idle", "", 0, 0) == "idle", "Sprites: idle frame 0 should be the idle pose")
	_check(arena._sprite_pose("bank", _fighter("idle"), "idle", "", 30, 0) == "idle-1", "Sprites: idle cycle should advance to idle-1 at frame 30")
	_check(arena._sprite_pose("bank", _fighter("attack", "light"), "attack", "light", 5, 0) == "punch", "Sprites: light attack should show punch")
	_check(arena._sprite_pose("bank", _fighter("attack", "low"), "attack", "low", 5, 0) == "low-punch", "Sprites: low attack should show low-punch")
	_check(arena._sprite_pose("bank", _fighter("attack", "low_kick"), "attack", "low_kick", 5, 0) == "sweep", "Sprites: low kick should show sweep")
	_check(arena._sprite_pose("bank", _fighter("attack", "heavy"), "attack", "heavy", 5, 0) == "roundhouse", "Sprites: heavy should show roundhouse")
	_check(arena._sprite_pose("bank", _fighter("attack", "uppercut", 5, {"down": true}), "attack", "uppercut", 5, 0) == "crouch-uppercut", "Sprites: ducking uppercut should show crouch-uppercut")
	_check(arena._sprite_pose("bank", _fighter("attack", "uppercut"), "attack", "uppercut", 5, 0) == "uppercut", "Sprites: standing uppercut should show uppercut")
	_check(arena._sprite_pose("bank", _fighter("attack", "minor", 12, {"minor": "projectile"}), "attack", "minor", 12, 0) == "throw", "Sprites: Bank's projectile minor should show the throw pose")
	_check(arena._sprite_pose("cin", _fighter("attack", "minor", 12, {"minor": "lunge"}), "attack", "minor", 12, 0) == "special-dog-lunge", "Sprites: Cin's lunge minor should show special-dog-lunge")
	_check(arena._sprite_pose("rico", _fighter("attack", "minor", 20, {"minor": "multi"}), "attack", "minor", 20, 0) == "kick", "Sprites: multi minor's second hit should show kick")
	_check(arena._sprite_pose("bank", _fighter("stunned"), "stunned", "", 5, 0) == "dizzy", "Sprites: stunned should show dizzy")
	_check(arena._sprite_pose("bank", _fighter("down"), "down", "", 5, 0) == "ko", "Sprites: down should show ko")
	_check(arena._sprite_pose("bank", _fighter("getup"), "getup", "", 5, 0) == "getup", "Sprites: getup should show getup")
	_check(arena._sprite_pose("bank", _fighter("blockstun"), "blockstun", "", 5, 0) == "block", "Sprites: blockstun should show block")
	_check(arena._sprite_pose("bank", _fighter("jump"), "jump", "", 5, 0) == "jump", "Sprites: jump should show jump")
	arena._ctx_inputs = [{"move": -1}, {"move": 0}]
	_check(arena._sprite_pose("bank", _fighter("walk"), "walk", "", 5, 0) == "back", "Sprites: walking away from the opponent should show back")
	arena._ctx_inputs = [{"move": 1}, {"move": 0}]
	_check(arena._sprite_pose("bank", _fighter("walk"), "walk", "", 0, 0) == "walk-1", "Sprites: walking forward should cycle walk poses")
	# --- Scale law: one scale per form, from its idle anchor. ---
	_check(is_equal_approx(arena._sprite_scale("bank-sinatra"), 240.0 / 470.0), "Sprites: standard scale should derive from the 470 idle anchor")
	_check(is_equal_approx(arena._sprite_scale("rico-wolf"), 240.0 / 500.0), "Sprites: wolf scale should derive from its own 500 idle anchor")
	arena.free()
