extends RefCounted

# Property of LiveLayer Technology LLC.
# Tests run the same deterministic step function used by the game.
const Sim = preload("res://scripts/combat/fight_sim.gd")
const Data = preload("res://scripts/combat/fighter_data.gd")
const CPU = preload("res://scripts/combat/cpu_brain.gd")
static var failures: Array = []
static var check_count: int = 0

static func run() -> Array:
	failures = []
	check_count = 0
	_test_roster()
	_test_regular_damage_and_timing()
	_test_blocking()
	_test_throws()
	_test_minor_specials()
	_test_big_specials()
	_test_movement()
	_test_combos_and_protection()
	_test_big_edges()
	_test_dog()
	_test_gestures_and_trade()
	_test_extended_combo_counts()
	_test_rounds_and_cpu()
	_test_determinism()
	print("Combat: %d checks, %d failures." % [check_count, failures.size()])
	return failures

static func _check(condition: bool, message: String) -> void:
	check_count += 1
	if not condition:
		failures.append(message)

static func _equal(actual: Variant, expected: Variant, message: String) -> void:
	_check(actual == expected, "%s: expected %s, got %s" % [message, str(expected), str(actual)])

static func _blank() -> Dictionary:
	return {"move": 0, "down": false, "jump": false, "attack": "", "block": false}

static func _tick(sim: RefCounted, one: Dictionary = {}, two: Dictionary = {}, count: int = 1) -> void:
	for unused in count:
		sim.step([one, two])

static func _fresh(one: String = "bank", two: String = "bank", training: bool = true) -> RefCounted:
	var sim = Sim.new()
	sim.setup(one, two, {}, {}, training, 1701)
	_tick(sim, {}, {}, 181)
	return sim

static func _test_roster() -> void:
	_equal(Data.IDS.size(), 4, "Exactly four fighters ship in the first pass")
	var health: Dictionary = {"cin": 200, "rico": 200, "hood": 210, "bank": 200}
	for id in Data.IDS:
		var fighter: Dictionary = Data.get_fighter(id)
		_equal(fighter.hp, health[id], id + " base health")
		var total: int = 0
		var blocked: int = 0
		for hit in fighter.big_hits:
			total += int(hit)
			blocked += int(hit) / 2
		_equal(total, 70 if id in ["cin", "rico"] else 68, id + " big special clean total")
		_equal(blocked, 35 if id in ["cin", "rico"] else 34, id + " big special per-hit halving total")

static func _test_determinism() -> void:
	var first = _fresh("rico", "bank", false)
	var second = _fresh("rico", "bank", false)
	var input_rng = RandomNumberGenerator.new()
	input_rng.seed = 415099
	var actions: Array = ["", "", "light", "low", "kick", "heavy", "throw", "special"]
	for frame in 1500:
		var inputs: Array = []
		for index in 2:
			inputs.append({"move": input_rng.randi_range(-1, 1), "down": input_rng.randi_range(0, 5) == 0,
				"jump": input_rng.randi_range(0, 50) == 0, "attack": actions[input_rng.randi_range(0, actions.size() - 1)],
				"block": input_rng.randi_range(0, 8) == 0})
		first.step(inputs)
		second.step(inputs)
	_equal(first.snapshot(), second.snapshot(), "Same seeded inputs reproduce the entire simulation")
	var restored = Sim.new()
	restored.restore(first.snapshot())
	_equal(restored.snapshot(), first.snapshot(), "Snapshot round-trip retains all simulation state")
	for frame in 240:
		first.step([{"move": 1, "attack": "light"}, {"move": -1, "attack": "kick"}])
		restored.step([{"move": 1, "attack": "light"}, {"move": -1, "attack": "kick"}])
	_equal(restored.snapshot(), first.snapshot(), "Restored fight continues identically")

static func _close(sim: RefCounted, distance: int = 70) -> void:
	sim.countdown = 0
	sim.fighters[0].x = 500
	sim.fighters[1].x = 500 + distance
	for fighter in sim.fighters:
		fighter.dog_cooldown = 100000

static func _attack(sim: RefCounted, move: String, defender: Dictionary = {}, ticks: int = 50) -> void:
	_tick(sim, {"attack": move}, defender)
	_tick(sim, {}, defender, ticks - 1)

static func _open_special(sim: RefCounted, big: bool = false) -> void:
	var direction: int = 1 if big else -1
	_tick(sim, {"attack": "special", "move": direction})
	_check(not sim.fighters[0].prompt.is_empty(), "Special shortcut opens a prompted move")
	if not sim.fighters[0].prompt.is_empty():
		var expected_kind: String = "big" if big else "minor"
		_equal(sim.fighters[0].prompt.kind, expected_kind, "Prompt selects correct special class")
		_tick(sim, {"attack": sim.fighters[0].prompt.button})

static func _test_regular_damage_and_timing() -> void:
	var actions: Array = ["light", "low", "kick", "heavy"]
	var damage: Array = [6, 8, 10, 14]
	var startup: Array = [5, 6, 8, 12]
	for id in Data.IDS:
		for index in actions.size():
			var sim = _fresh(id)
			_close(sim)
			var before: int = sim.fighters[1].hp
			_tick(sim, {"attack": actions[index]})
			_tick(sim, {}, {}, startup[index] - 2)
			_equal(sim.fighters[1].hp, before, "%s %s cannot hit before universal startup" % [id, actions[index]])
			_tick(sim)
			var expected: int = damage[index] + (2 if id == "hood" else 0)
			_equal(before - sim.fighters[1].hp, expected, "%s %s hits on universal startup with full class damage" % [id, actions[index]])
			_tick(sim, {}, {}, 24)
			_equal(before - sim.fighters[1].hp, expected, "An active attack cannot hit the same body twice")
			_equal(sim.fighters[0].meter, 4, "Each clean regular hit awards four meter")
			_equal(sim.fighters[1].meter, 0, "Taking regular damage awards no meter")

static func _test_blocking() -> void:
	var sim = _fresh()
	_close(sim)
	_attack(sim, "light", {"block": true})
	_equal(sim.fighters[1].hp, 200, "A correctly timed regular block deals zero chip")
	_equal(sim.fighters[1].meter, 10, "Timed block earns half a notch")
	_equal(sim.fighters[0].meter, 0, "Blocked attacks earn no attacker meter")
	_attack(sim, "light", {"block": true})
	_equal(sim.fighters[1].hp, 198, "A held regular block deals two chip")
	_equal(sim.fighters[1].meter, 10, "Continued block engagement earns no second award")
	sim = _fresh()
	_close(sim)
	_tick(sim, {}, {"block": true}, 20)
	_attack(sim, "heavy", {"block": true})
	_equal(sim.fighters[1].hp, 196, "Held Heavy Kick block deals four chip")
	sim = _fresh()
	_close(sim)
	_attack(sim, "low", {"block": true})
	_equal(sim.fighters[1].hp, 192, "Standing block does not stop low attacks")
	sim = _fresh()
	_close(sim)
	_attack(sim, "low", {"block": true, "down": true})
	_equal(sim.fighters[1].hp, 200, "Timed crouch block stops low attacks")
	sim = _fresh()
	_close(sim)
	_attack(sim, "light", {"block": true, "down": true})
	_equal(sim.fighters[1].hp, 194, "Crouch block does not stop high attacks")
	sim = _fresh("bank", "bank", false)
	_close(sim)
	sim.fighters[1].hp = 1
	_tick(sim, {}, {"block": true}, 20)
	_attack(sim, "light", {"block": true})
	_equal(sim.fighters[1].hp, 0, "Held regular chip can KO")

static func _test_throws() -> void:
	for id in Data.IDS:
		for notch in range(1, 4):
			var sim = _fresh(id)
			_close(sim, 55)
			sim.fighters[0].meter = notch * 20
			_attack(sim, "throw", {}, 50)
			_equal(200 - sim.fighters[1].hp, [0, 16, 22, 30][notch], "%s throw damage is universal at notch %d" % [id, notch])
			_equal(sim.fighters[0].meter, notch * 20, "Throw requires meter without spending it")
	var sim = _fresh()
	_close(sim, 55)
	_attack(sim, "throw")
	_equal(sim.fighters[1].hp, 200, "A zero-meter throw cannot damage")
	sim = _fresh()
	_close(sim, 55)
	sim.fighters[0].meter = 20
	_tick(sim, {"attack": "throw"})
	for frame in 12:
		if sim.fighters[1].state == "grabbed":
			break
		_tick(sim)
	_equal(sim.fighters[1].state, "grabbed", "Close throw captures defender after startup")
	_tick(sim, {}, {"tap": "back"})
	_tick(sim, {}, {"tap": "back"})
	_tick(sim, {}, {"tap": "down"})
	_tick(sim, {}, {}, 45)
	_equal(sim.fighters[1].hp, 200, "Back-back-down throw break prevents all damage")
	_check(sim.fighters[1].state != "grabbed", "Throw break releases defender")
	_check(abs(sim.fighters[0].x - sim.fighters[1].x) > 55, "Broken throw separates fighters")
	_check(sim.fighters[1].prompt.is_empty(), "Throw-break double back does not open minor-special prompt")
	sim = _fresh()
	_close(sim, 400)
	sim.fighters[0].meter = 20
	_tick(sim, {"attack": "throw"})
	var start_x: int = sim.fighters[0].x
	_tick(sim, {"move": 1, "block": true}, {}, 40)
	_equal(sim.fighters[0].x, start_x, "Whiffed throw locks attacker movement for 0.8 seconds")
	_tick(sim, {}, {}, 12)
	_check(sim.fighters[0].state != "throw", "Whiffed throw eventually recovers")

static func _test_minor_specials() -> void:
	for id in Data.IDS:
		var sim = _fresh(id)
		_close(sim, 65)
		sim.fighters[0].meter = 20
		_open_special(sim)
		_tick(sim, {}, {}, 100)
		_equal(200 - sim.fighters[1].hp, 20 if id == "rico" else 22, id + " minor special uses reduced damage on the larger health bar")
		_equal(sim.fighters[0].meter, 0, "Minor special spends exactly one notch and awards no hit meter")
		sim = _fresh(id)
		_close(sim, 65)
		sim.fighters[0].meter = 20
		_tick(sim, {"attack": "special", "move": -1}, {"block": true})
		if not sim.fighters[0].prompt.is_empty():
			_tick(sim, {"attack": sim.fighters[0].prompt.button}, {"block": true})
		_tick(sim, {}, {"block": true}, 100)
		_equal(200 - sim.fighters[1].hp, 4, id + " minor special held block has exactly four total chip")
		sim = _fresh(id)
		_close(sim, 65)
		sim.fighters[0].meter = 20
		_tick(sim, {"attack": "special", "move": -1})
		_tick(sim, {}, {}, 121)
		_equal(sim.fighters[0].meter, 20, "Missing a minor prompt window spends no meter")
		_check(sim.fighters[0].prompt.is_empty(), "Expired minor prompt clears")

static func _test_big_specials() -> void:
	for id in Data.IDS:
		var sim = _fresh(id)
		_close(sim, 400)
		sim.fighters[0].meter = 60
		_open_special(sim, true)
		_tick(sim, {}, {}, 180)
		_equal(200 - sim.fighters[1].hp, 70 if id in ["cin", "rico"] else 68, id + " big special captures at any distance for its full reduced damage")
		_equal(sim.fighters[0].meter, 0, "Landed big special spends three notches")
		# Defense input must start after the big cue; pre-held guard is not a tap.
		sim = _fresh(id)
		_close(sim, 400)
		sim.fighters[0].meter = 60
		_open_special(sim, true)
		_tick(sim, {}, {"block": true}, 180)
		_equal(200 - sim.fighters[1].hp, 35 if id in ["cin", "rico"] else 34, id + " successful held big defense halves every hit")
		sim = _fresh(id)
		_close(sim, 400)
		sim.fighters[0].meter = 60
		sim.fighters[1].hp = 2
		_open_special(sim, true)
		_tick(sim, {}, {"block": true}, 180)
		_equal(sim.fighters[1].hp, 1, "Holding successful big defense preserves at least one HP")
	var sim = _fresh()
	_close(sim)
	sim.fighters[0].meter = 60
	_tick(sim, {"attack": "special", "move": 1})
	_tick(sim, {}, {}, 121)
	_equal(sim.fighters[0].meter, 40, "Missing big-special prompt drops meter from three to two notches")
	sim = _fresh()
	_close(sim, 400)
	sim.fighters[0].meter = 60
	_open_special(sim, true)
	_tick(sim, {}, {}, 40)
	_tick(sim, {}, {"jump": true})
	_tick(sim, {}, {}, 180)
	_equal(sim.fighters[1].hp, 200, "Correctly timed jump evades big-special capture")
	_equal(sim.fighters[0].meter, 40, "Evaded big special refunds two notches")

static func _test_rounds_and_cpu() -> void:
	var sim = Sim.new()
	sim.setup("bank", "hood", {}, {}, false, 8)
	_equal(sim.countdown, 180, "Every round starts with a three-second countdown")
	_equal(sim.time_left, 99 * 60, "Rounds use ninety-nine seconds at sixty simulation frames per second")
	_tick(sim, {"move": 1, "attack": "heavy"}, {}, 179)
	_equal(sim.fighters[1].hp, 210, "Countdown prevents combat")
	_equal(sim.time_left, 99 * 60, "Round clock freezes through countdown")
	_tick(sim)
	_close(sim)
	sim.fighters[1].hp = 1
	sim.fighters[0].meter = 60
	_attack(sim, "light", {}, 10)
	_check(sim.round_over, "A KO ends the current round")
	_equal(sim.round_wins[0], 1, "First KO wins one round")
	_check(not sim.match_over, "One round does not end a best-of-three match")
	_tick(sim, {}, {}, 400)
	_check(sim.fighters[0].meter <= 20, "No more than one meter notch carries to next round")
	_equal(sim.fighters[1].hp, 210, "Next round restores base health")
	_close(sim)
	sim.fighters[1].hp = 1
	_attack(sim, "light", {}, 10)
	_check(sim.match_over, "Two round wins finish a best-of-three match")
	_equal(sim.winner, 0, "Winning side is recorded")
	sim = _fresh("bank", "hood", false)
	sim.countdown = 0
	sim.time_left = 1
	sim.fighters[0].hp = 60
	sim.fighters[1].hp = 50
	_tick(sim)
	_check(sim.round_over, "Timer reaching zero ends the round")
	_equal(sim.round_wins[0], 1, "Timeout awards the round to the side with more health")
	# Identical brain seeds and state must make identical decisions.
	var first_brain = CPU.new()
	var second_brain = CPU.new()
	first_brain.setup(2, 2305)
	second_brain.setup(2, 2305)
	sim = _fresh("rico", "bank", false)
	var same: bool = true
	for frame in 500:
		var first_input: Dictionary = first_brain.decide(sim, 0)
		var second_input: Dictionary = second_brain.decide(sim, 0)
		same = same and first_input == second_input
		sim.step([first_input, {}])
	_check(same, "CPU decisions are deterministic for the same seed and state")
	# Exercise every dial stop through a real CPU duel, including transitions.
	for difficulty in 3:
		sim = _fresh("rico", "hood", false)
		var player = CPU.new()
		var opponent = CPU.new()
		player.setup(difficulty, 921)
		opponent.setup(difficulty, 1233)
		var dealt_damage: bool = false
		var valid: bool = true
		for frame in 24000:
			sim.step([player.decide(sim, 0), opponent.decide(sim, 1)])
			for fighter in sim.fighters:
				dealt_damage = dealt_damage or fighter.hp < fighter.max_hp
				valid = valid and fighter.hp >= 0 and fighter.hp <= fighter.max_hp and fighter.meter >= 0 and fighter.meter <= 60
			if sim.match_over:
				break
		_check(dealt_damage, "CPU dial %d engages and deals damage" % difficulty)
		_check(valid, "CPU dial %d maintains legal health and meter bounds" % difficulty)
		_check(sim.match_over, "CPU dial %d completes an entire best-of-three match" % difficulty)

static func _test_movement() -> void:
	var traveled: Dictionary = {}
	for id in ["cin", "bank", "hood"]:
		var sim = _fresh(id)
		sim.countdown = 0
		var before: int = sim.fighters[0].x
		_tick(sim, {"move": 1}, {}, 10)
		traveled[id] = sim.fighters[0].x - before
	_check(traveled.cin > traveled.bank and traveled.bank > traveled.hood, "Movement speed classes preserve fast/standard/slow order")
	var sim = _fresh()
	sim.countdown = 0
	_tick(sim, {"jump": true, "move": 1})
	_check(sim.fighters[0].y > 0, "Up input starts a jump")
	_tick(sim, {"move": 1}, {}, 8)
	var apex_x: int = sim.fighters[0].x
	_tick(sim, {"move": -1}, {}, 8)
	_check(sim.fighters[0].x < apex_x, "Air steering can reverse horizontal direction mid-jump")
	_tick(sim, {}, {}, 30)
	_equal(sim.fighters[0].y, 0, "Jump returns to the rooftop after approximately forty-two frames")
	sim = _fresh()
	_close(sim)
	_attack(sim, "light", {"move": 1})
	_equal(sim.fighters[1].hp, 200, "Holding back guards without a separate regular block button")
	_equal(sim.fighters[1].meter, 10, "Holding back uses the same timed-block system")

static func _land_regular(sim: RefCounted, move: String) -> void:
	while sim.hitstop > 0:
		_tick(sim)
	var before: int = sim.fighters[1].hp
	_tick(sim, {"attack": move})
	for frame in 30:
		if sim.fighters[1].hp != before:
			return
		_tick(sim)
	_check(false, "Manual combo attack %s must connect" % move)

static func _test_combos_and_protection() -> void:
	var sim = _fresh()
	_close(sim)
	for move in ["light", "light", "low", "kick", "heavy"]:
		_land_regular(sim, move)
	_equal(200 - sim.fighters[1].hp, 44, "Manual mixed five-hit combo deals full 44 damage without scaling")
	_equal(sim.fighters[0].meter, 20, "Exactly five clean regular hits earn exactly one meter notch")
	_equal(sim.fighters[1].state, "down", "Fifth regular hit forces knockdown")
	var before: int = sim.fighters[1].hp
	_attack(sim, "heavy", {}, 40)
	_equal(sim.fighters[1].hp, before, "Knockdown protection prevents a sixth regular hit")
	# Protected get-up also rejects grabs and cannot offer an unblockable capture.
	sim = _fresh()
	_close(sim)
	sim.fighters[1].state = "getup"
	sim.fighters[1].timer = 12
	sim.fighters[0].meter = 60
	_tick(sim, {"attack": "special", "move": 1})
	_check(sim.fighters[0].prompt.is_empty(), "Big specials cannot be activated against protected get-up")
	_equal(sim.fighters[0].meter, 60, "Rejected big special costs no meter")
	_tick(sim, {"attack": "throw"})
	_tick(sim, {}, {}, 8)
	_check(sim.fighters[1].state != "grabbed", "Get-up cannot be grabbed")
	_equal(sim.fighters[1].hp, 200, "Get-up remains damage immune")
	# A minor entered before hit five completes its entire multi-hit sequence.
	sim = _fresh("rico")
	_close(sim)
	sim.fighters[0].meter = 20
	for move in ["light", "light", "low", "kick"]:
		_land_regular(sim, move)
	while sim.hitstop > 0:
		_tick(sim)
	_open_special(sim)
	_tick(sim, {}, {}, 60)
	_equal(200 - sim.fighters[1].hp, 50, "Minor special after four regular hits completes both full-damage hits past hit five")
	_equal(sim.fighters[0].meter, 16, "Special combo awards only the four regular-hit meter payments")
	# A hitstop input must survive until combat resumes.
	sim = _fresh()
	_close(sim)
	_land_regular(sim, "light")
	_check(sim.hitstop > 0, "Clean hit starts documented hitstop")
	_tick(sim, {"attack": "kick"})
	_tick(sim, {}, {}, 20)
	_equal(200 - sim.fighters[1].hp, 16, "Attack pressed during hitstop buffers into the next manual combo move")

static func _test_big_edges() -> void:
	for damage in [0, 10, 20, 30, 40, 50, 90]:
		var sim = _fresh()
		_close(sim, 400)
		sim.fighters[0].meter = 60
		sim.fighters[0].combo_damage = damage
		sim.fighters[0].combo_timer = 200
		_tick(sim, {"attack": "special", "move": 1})
		var button: String = sim.fighters[0].prompt.button
		_tick(sim, {"attack": button})
		var window: int = 0
		for event in sim.events:
			if event.type == "big_start":
				window = event.window
		_equal(window, maxi(30, 60 - (damage / 10) * 6), "Big defense window shrinks by six frames per ten combo damage, floor thirty")
	var sim = _fresh()
	_close(sim, 400)
	sim.fighters[0].meter = 60
	_open_special(sim, true)
	_tick(sim, {}, {"block": true}, 70)
	var first_damage: int = 200 - sim.fighters[1].hp
	_check(first_damage > 0 and first_damage < 34, "First big-special hit has been defended before early release")
	_tick(sim, {}, {}, 1)
	_tick(sim, {}, {"block": true}, 100)
	_check(200 - sim.fighters[1].hp > 34, "Releasing big-special guard exposes remaining hits")
	_check(200 - sim.fighters[1].hp < 68, "Previously defended big-special hits remain reduced after release")
	# A jump should evade only when still airborne at capture, and whiff locks for ninety frames.
	sim = _fresh()
	_close(sim, 400)
	sim.fighters[0].meter = 60
	_open_special(sim, true)
	_tick(sim, {}, {}, 40)
	_tick(sim, {}, {"jump": true})
	var saw_whiff: bool = false
	for frame in 30:
		_tick(sim)
		for event in sim.events:
			if event.type == "big_whiff":
				saw_whiff = true
		if saw_whiff:
			break
	_check(saw_whiff, "Airborne-at-capture emits a big-special whiff")
	_equal(sim.fighters[0].timer, 90, "Whiffed big special locks attacker for ninety frames")
	var locked_x: int = sim.fighters[0].x
	_tick(sim, {"move": 1, "attack": "light", "block": true}, {}, 89)
	_equal(sim.fighters[0].x, locked_x, "Whiff recovery disallows movement and attacks through frame eighty-nine")
	_equal(sim.fighters[0].state, "recovery", "Whiff recovery lasts the full ninety frames")
	_tick(sim)
	_equal(sim.fighters[0].state, "idle", "Whiff recovery ends on frame ninety")

static func _test_dog() -> void:
	var sim = _fresh("bank", "cin")
	_close(sim, 400)
	sim.fighters[1].dog_x = 555
	_attack(sim, "light", {"block": true}, 10)
	_equal(sim.fighters[1].hp, 194, "Separately targetable dog takes shared damage and cannot block with Cin")
	sim = _fresh("bank", "cin")
	_close(sim)
	sim.fighters[1].dog_x = 555
	_attack(sim, "light", {}, 12)
	_equal(sim.fighters[1].hp, 194, "One attack touching Cin and dog damages shared HP only once")
	sim = _fresh("cin", "bank")
	_close(sim, 400)
	sim.fighters[0].dog_x = 840
	sim.fighters[0].dog_cooldown = 0
	sim.fighters[0].state = "down"
	sim.fighters[0].timer = 48
	_tick(sim)
	_equal(sim.fighters[1].hp, 194, "Dog attacks automatically while Cin is knocked down")
	_equal(sim.fighters[0].meter, 2, "Dog regular hit pays half meter")
	_equal(sim.fighters[0].combo_hits, 1, "Dog shares Cin's regular combo count")
	sim = _fresh("bank", "cin")
	_close(sim, 400)
	sim.fighters[1].dog_x = 555
	sim.fighters[1].state = "getup"
	sim.fighters[1].timer = 12
	_attack(sim, "light", {}, 10)
	_equal(sim.fighters[1].hp, 200, "Dog shares Cin's get-up damage protection")
	sim = _fresh("bank", "cin")
	_close(sim, 75)
	sim.fighters[0].meter = 20
	_tick(sim, {"attack": "throw"}, {}, 6)
	_equal(sim.fighters[1].state, "grabbed", "Throw captures Cin for dog interrupt scenario")
	sim.fighters[1].dog_x = sim.fighters[0].x + 60
	sim.fighters[1].dog_cooldown = 0
	_tick(sim)
	_check(sim.fighters[1].state != "grabbed", "Dog can interrupt a regular throw and free Cin")
	_equal(sim.fighters[1].hp, 200, "Dog throw interruption prevents grab damage")
	_equal(sim.fighters[0].hp, 194, "Dog interruption damages the grabber")
	# A captured Cin still has an attacking partner. Damage is allowed; the
	# big special must retain control and complete its entire locked sequence.
	sim = _fresh("bank", "cin")
	_close(sim, 400)
	sim.fighters[0].meter = 60
	_open_special(sim, true)
	for frame in 100:
		if sim.fighters[1].state == "big_capture":
			break
		_tick(sim)
	_equal(sim.fighters[1].state, "big_capture", "Dog capture scenario reaches the actual big-special capture")
	sim.fighters[1].dog_x = sim.fighters[0].x + 60
	sim.fighters[1].dog_cooldown = 0
	_tick(sim)
	_equal(sim.fighters[0].hp, 194, "Dog keeps dealing damage while Cin is captured")
	_equal(sim.fighters[1].meter, 2, "Dog hit while Cin is captured still earns half meter")
	_equal(sim.fighters[0].state, "big", "Dog damage cannot cancel, stagger, or knock down the active big special")
	_equal(sim.fighters[1].state, "big_capture", "Dog damage cannot release Cin from big-special capture")
	_tick(sim, {}, {}, 100)
	_equal(sim.fighters[1].hp, 132, "Big special completes all sixty-eight damage despite captured Cin's dog attack")
	# The same continuity rule holds when the partner hit drops the attacker to
	# zero HP: resolve the special before awarding the round, with no lost hits.
	sim = _fresh("bank", "cin", false)
	_close(sim, 400)
	sim.fighters[0].meter = 60
	sim.fighters[0].hp = 1
	_open_special(sim, true)
	for frame in 100:
		if sim.fighters[1].state == "big_capture":
			break
		_tick(sim)
	sim.fighters[1].dog_x = sim.fighters[0].x + 60
	sim.fighters[1].dog_cooldown = 0
	_tick(sim)
	_equal(sim.fighters[0].hp, 0, "Captured Cin's dog can reduce the big-special attacker to zero HP")
	_equal(sim.fighters[0].state, "big", "A partner-caused KO still cannot cancel the captured big-special sequence")
	_check(not sim.round_over, "Partner-caused KO defers round results while the big sequence remains active")
	for frame in 120:
		if sim.round_over:
			break
		_tick(sim)
	_equal(sim.fighters[1].hp, 132, "All sixty-eight big-special damage resolves before a partner-caused KO ends the round")
	_check(sim.round_over and sim.winner == 1, "Partner-caused KO awards the round only after the big finisher completes")

static func _test_gestures_and_trade() -> void:
	var sim = _fresh()
	_close(sim)
	sim.fighters[0].meter = 20
	_tick(sim, {"tap": "back"})
	_tick(sim, {"tap": "back"})
	_equal(sim.fighters[0].prompt.get("kind", ""), "minor", "Double-back gesture offers a minor special")
	sim = _fresh()
	_close(sim)
	sim.fighters[0].meter = 60
	_tick(sim, {"tap": "forward"})
	_tick(sim, {"tap": "forward"})
	_equal(sim.fighters[0].prompt.get("kind", ""), "big", "Double-forward gesture offers a big special")
	sim = _fresh()
	_close(sim)
	sim.fighters[0].meter = 20
	_tick(sim, {"tap": "back"})
	_tick(sim, {"tap": "forward"})
	_attack(sim, "light", {}, 50)
	_equal(sim.fighters[1].hp, 184, "Back-forward-punch performs a real throw rather than a regular punch")
	for id in Data.IDS:
		sim = _fresh(id)
		_close(sim, 95)
		sim.fighters[0].meter = 20
		_attack(sim, "throw")
		_equal(sim.fighters[1].hp, 184, id + " throw connects at the same universal grab distance")
		sim = _fresh(id)
		_close(sim, 105)
		sim.fighters[0].meter = 20
		_attack(sim, "throw")
		_equal(sim.fighters[1].hp, 200, id + " long reach cannot extend universal grab distance")
	sim = _fresh()
	_close(sim)
	_tick(sim, {"attack": "light"}, {"attack": "light"}, 5)
	_equal(sim.fighters[0].hp, 194, "Simultaneous same-frame attacks can hit player one")
	_equal(sim.fighters[1].hp, 194, "Simultaneous same-frame attacks trade without player-one priority")
	# Airborne fighters use the same attacks, but can never guard.
	sim = _fresh()
	_close(sim)
	for fighter in sim.fighters:
		fighter.y = 98
		fighter.jump_frame = 14
		fighter.state = "jump"
	_attack(sim, "light", {"block": true}, 10)
	_equal(sim.fighters[1].hp, 194, "Holding guard in the air never blocks a regular attack")
	sim = _fresh()
	_close(sim, 400)
	sim.fighters[0].meter = 60
	sim.fighters[1].y = 98
	sim.fighters[1].jump_frame = 14
	sim.fighters[1].state = "jump"
	_open_special(sim, true)
	_check(sim.fighters[1].prompt.is_empty(), "Airborne defenders receive no big-special Block prompt")
	for id in Data.IDS:
		sim = _fresh(id)
		_close(sim, 70)
		sim.fighters[0].meter = 20
		_tick(sim, {"attack": "special", "move": -1}, {"block": true})
		var button: String = sim.fighters[0].prompt.button
		_tick(sim, {"attack": button, "down": true}, {"block": true})
		_tick(sim, {}, {"block": true}, 100)
		_equal(sim.fighters[1].hp, 180 if id == "rico" else 178, id + " wrong-position guard takes full minor-special damage")

static func _test_extended_combo_counts() -> void:
	var sim = _fresh("rico")
	_close(sim)
	sim.fighters[0].meter = 20
	for move in ["light", "light", "low", "kick"]:
		_land_regular(sim, move)
	while sim.hitstop > 0:
		_tick(sim)
	_tick(sim, {"attack": "throw"})
	var connected: bool = false
	for frame in 60:
		_tick(sim)
		for event in sim.events:
			if event.type == "throw":
				connected = true
		if connected:
			break
	_check(connected, "Manual regular combo can cancel into an unbroken throw")
	_equal(sim.fighters[0].combo_hits, 5, "Throw's break window preserves the prior four regular hits in its combo count")
	_equal(sim.fighters[1].hp, 154, "Throw after four regular hits retains full universal damage")
	sim = _fresh("rico")
	_close(sim)
	sim.fighters[0].meter = 60
	for move in ["light", "light", "low", "kick"]:
		_land_regular(sim, move)
	while sim.hitstop > 0:
		_tick(sim)
	_open_special(sim, true)
	var finished: bool = false
	for frame in 220:
		_tick(sim)
		if sim.fighters[0].state == "recovery" and sim.fighters[0].big_index == 5:
			finished = true
			break
	_check(finished, "Regular combo can cancel into a complete big-special sequence")
	_equal(sim.fighters[0].combo_hits, 9, "Big cue and hit sequence preserve four regular plus five special combo hits")
	_equal(sim.fighters[1].hp, 100, "Comboed big special adds full seventy without scaling")
