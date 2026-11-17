extends RefCounted

# Property of LiveLayer Technology LLC.
const Sim = preload("res://scripts/combat/fight_sim.gd")
const Data = preload("res://scripts/combat/fighter_data.gd")
static var failures: Array = []
static var checks: int = 0

static func run() -> Array:
	failures = []
	checks = 0
	_test_uppercut()
	_test_launch_cap()
	_test_double_jump()
	_test_air_actions_and_restore()
	print("Air combat: %d checks, %d failures." % [checks, failures.size()])
	return failures

static func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

static func _fresh(id: String = "bank", index: int = 0, close: bool = false) -> RefCounted:
	var sim = Sim.new()
	sim.setup(id if index == 0 else "bank", id if index == 1 else "bank", {}, {}, true, 1701)
	sim.countdown = 0
	if close:
		sim.fighters[0].x = 500
		sim.fighters[1].x = 570
	for fighter in sim.fighters:
		fighter.dog_cooldown = 100000
	return sim

static func _step(sim: RefCounted, input: Dictionary = {}, index: int = 0, ticks: int = 1, other: Dictionary = {}) -> void:
	var inputs: Array = [{}, {}]
	inputs[index] = input
	inputs[1 - index] = other
	for tick in ticks:
		sim.step(inputs)

static func _test_uppercut() -> void:
	_check(Sim.MOVE_DATA.uppercut == {"startup": 10, "active": 4, "recovery": 20, "hitstun": 20, "blockstun": 12, "hitstop": 5, "range": 120, "damage": 16}, "Uppercut has the specified timing, range and rescaled damage")
	for id in Data.IDS:
		for index in 2:
			var sim = _fresh(id, index, true)
			var me: Dictionary = sim.fighters[index]
			var foe: Dictionary = sim.fighters[1 - index]
			_step(sim, {"down": true, "attack": "heavy"}, index)
			_check(me.move == "uppercut" and not me.attack_low, "%s side %d crouched heavy starts a high uppercut" % [id, index])
			_step(sim, {}, index, 8)
			_check(foe.hp == 200, "Uppercut cannot hit before frame ten")
			_step(sim, {}, index)
			_check(foe.hp == 200 - 16 - (2 if id == "hood" else 0), "Uppercut hits once on frame ten with class damage")
			_check(foe.y > 0 and foe.stun == 20 and not foe.normal_jump, "Uppercut hit starts an upward launch with normal hitstun")
			_step(sim, {}, index, 50)
			_check(me.move == "" and me.state == "idle", "Uppercut completes its recovery")
			_check(foe.hp == 200 - 16 - (2 if id == "hood" else 0), "Uppercut active frames do not repeat damage")
	# Both held Down and an existing crouch route heavy through the new move.
	var sim = _fresh()
	_step(sim, {"down": true})
	_step(sim, {"attack": "heavy"})
	_check(sim.fighters[0].move == "uppercut", "Heavy from an existing crouch remains an uppercut when Down releases")
	sim = _fresh()
	_step(sim, {"attack": "heavy"})
	_check(sim.fighters[0].move == "heavy" and not sim.fighters[0].attack_low, "Standing heavy stays a high heavy")
	sim = _fresh("bank", 0, true)
	_step(sim, {"down": true, "attack": "low"}, 0, 6)
	_check(sim.fighters[0].move == "low" and sim.fighters[0].attack_low and sim.fighters[1].y == 0, "Duck plus low punch keeps its drop-down move without launching")
	# Uppercut blocks high, and an ordinary low punch still blocks low.
	for crouch_guard in [false, true]:
		sim = _fresh("bank", 0, true)
		_step(sim, {"down": true, "attack": "heavy"}, 0, 1, {"block": true, "down": crouch_guard})
		_step(sim, {}, 0, 9, {"block": true, "down": crouch_guard})
		_check(sim.fighters[1].hp == (184 if crouch_guard else 200), "Uppercut respects high guard and defeats crouch guard")
		_check((sim.fighters[1].y > 0) == crouch_guard, "Blocked uppercuts never launch")
	# At its own double-jump height an opponent is above the old high hitbox.
	sim = _fresh("bank", 0, true)
	sim.fighters[1].y = 160
	sim.fighters[1].state = "jump"
	_step(sim, {"down": true, "attack": "heavy"})
	_step(sim, {}, 0, 9)
	_check(sim.fighters[1].hp == 184, "Uppercut connects above the ordinary 85-unit vertical reach")
	sim = _fresh("bank", 0, true)
	sim.fighters[1].x = 420
	sim.fighters[1].y = 100
	sim.fighters[1].state = "jump"
	_step(sim, {"down": true, "attack": "heavy"})
	_step(sim, {}, 0, 14)
	_check(sim.fighters[1].hp == 200, "Uppercut cannot hit behind its locked attack facing")
	sim = _fresh("bank", 0, true)
	sim.fighters[1].x = 625
	_step(sim, {"down": true, "attack": "heavy"})
	_step(sim, {}, 0, 14)
	_check(sim.fighters[1].hp == 200, "Uppercut cannot reach past its 120-unit range")
	# Hitstop buffering must preserve the crouched high-punch intent.
	sim = _fresh()
	sim.hitstop = 2
	_step(sim, {"down": true, "attack": "heavy"})
	_step(sim, {}, 0, 2)
	_check(sim.fighters[0].move == "uppercut", "Queued crouched heavy remains uppercut after releasing Down during hitstop")

static func _single_apex() -> int:
	var sim = _fresh()
	_step(sim, {"jump": true})
	var apex: int = 0
	for frame in 50:
		apex = maxi(apex, int(sim.fighters[0].y))
		_step(sim)
	return apex

static func _test_launch_cap() -> void:
	var single_apex: int = _single_apex()
	_check(single_apex == 110, "Unchanged normal jump apex is 110 units")
	for start_height in [0, 40, 100, 110, 160]:
		var sim = _fresh("bank", 0, true)
		var foe: Dictionary = sim.fighters[1]
		foe.y = start_height
		foe.state = "jump" if start_height > 0 else "idle"
		# Include a fighter whose own double jump was already available/used.
		foe.normal_jump = start_height > 0
		foe.double_jump_used = start_height == 160
		_step(sim, {"down": true, "attack": "heavy"})
		_step(sim, {}, 0, 9)
		_check(foe.hp == 184 and not foe.normal_jump, "Uppercut replaces the target's prior jump with a launch")
		var apex: int = int(foe.y)
		var second_jump: bool = false
		var regained_control: bool = false
		for frame in 110:
			_step(sim, {"jump": frame % 2 == 0}, 1)
			apex = maxi(apex, int(foe.y))
			second_jump = second_jump or bool(foe.double_jump_used) or bool(foe.normal_jump)
			regained_control = regained_control or (int(foe.y) > 0 and int(foe.stun) == 0)
			if int(foe.y) == 0:
				break
		_check(apex <= single_apex, "Uppercut launch apex never exceeds a normal jump, including a target above it")
		_check(not second_jump, "Fresh jump presses cannot double jump out of an uppercut launch")
		_check(foe.y == 0 and foe.jump_frame == 0, "Uppercut launch lands without another jump")
		if start_height == 0:
			_check(regained_control, "Launched fighter regains ordinary control after hitstun while still airborne")

static func _test_double_jump() -> void:
	var single_apex: int = _single_apex()
	for id in Data.IDS:
		for index in 2:
			for delay in [2, 20, 39]:
				var sim = _fresh(id, index)
				var me: Dictionary = sim.fighters[index]
				_step(sim, {"jump": true}, index, delay)
				_check(not me.double_jump_used, "Holding jump never spends the second jump")
				_step(sim, {}, index)
				var takeoff: int = int(me.y)
				_step(sim, {"jump": true}, index)
				_check(me.double_jump_used and me.jump_frame == 2 and me.jump_origin == takeoff and me.y > takeoff, "One fresh airborne press starts the second arc from the current height")
				var apex: int = int(me.y)
				var extra_jump: bool = false
				for frame in 100:
					var before: int = int(me.jump_frame)
					_step(sim, {"jump": frame % 2 == 0}, index)
					apex = maxi(apex, int(me.y))
					if int(me.y) == 0:
						break
					extra_jump = extra_jump or int(me.jump_frame) != before + 1
				_check(not extra_jump, "Repeated fresh jump presses cannot start a third arc")
				_check(apex * 10 >= single_apex * 14 and apex * 10 <= single_apex * 15, "Early, apex and late double jumps all reach 1.4 to 1.5 times normal height")
				_check(me.y == 0 and not me.double_jump_used and not me.normal_jump, "Landing resets second-jump eligibility")
				_step(sim, {}, index, 5)
				_step(sim, {"jump": true}, index)
				_step(sim, {}, index, 3)
				_step(sim, {"jump": true}, index)
				_check(me.double_jump_used, "A new airborne period allows a new double jump")

static func _test_air_actions_and_restore() -> void:
	for index in 2:
		var crossing = _fresh("bank", index, true)
		var direction: int = 1 if index == 0 else -1
		_step(crossing, {"jump": true, "move": direction}, index)
		_step(crossing, {"move": direction}, index, 10)
		_step(crossing, {"jump": true, "move": direction}, index)
		var crossed_high: bool = false
		for frame in 35:
			_step(crossing, {"move": direction}, index)
			var me: Dictionary = crossing.fighters[index]
			var foe: Dictionary = crossing.fighters[1 - index]
			if (int(me.x) - int(foe.x)) * direction > 0:
				crossed_high = int(me.y) > Sim.JUMP_APEX
				break
		_check(crossed_high, "Double jump clears and crosses the opponent above the single-jump apex from either side")
	var sim = _fresh()
	_step(sim, {"jump": true, "move": 1})
	_step(sim, {"move": 1}, 0, 10)
	_step(sim, {"jump": true, "move": 1})
	var x: int = int(sim.fighters[0].x)
	_step(sim, {"move": -1}, 0, 3)
	_check(sim.fighters[0].x < x and sim.fighters[0].y > 0, "Air steering works after the second jump")
	_step(sim, {"attack": "kick", "move": -1})
	_check(sim.fighters[0].state == "attack" and sim.fighters[0].move == "kick", "Air attacks work after the second jump")
	x = int(sim.fighters[0].x)
	_step(sim, {"move": 1}, 0, 3)
	_check(sim.fighters[0].x > x, "Air steering still works during the second jump's attack")
	var restored = Sim.new()
	restored.restore(sim.snapshot())
	_check(restored.snapshot() == sim.snapshot(), "Snapshot preserves second-jump arc, origin and eligibility")
	for frame in 100:
		var input: Dictionary = {"jump": frame % 2 == 0, "move": 1 if frame < 10 else -1}
		_step(sim, input)
		_step(restored, input)
	_check(restored.snapshot() == sim.snapshot(), "Restored double jump continues deterministically through landing")
	# Double jumping during a regular air attack keeps the attack in progress.
	sim = _fresh()
	_step(sim, {"jump": true})
	_step(sim, {"attack": "heavy"})
	_step(sim, {"jump": true})
	_check(sim.fighters[0].double_jump_used and sim.fighters[0].move == "heavy" and sim.fighters[0].attack_frame == 2, "A fresh double jump preserves an airborne regular attack")
	# Reset and old snapshots also initialize the new per-airborne-period state.
	var old: Dictionary = sim.snapshot()
	for fighter in old.fighters:
		for key in ["jump_origin", "normal_jump", "double_jump_used"]:
			fighter.erase(key)
	restored.restore(old)
	_step(restored)
	_check(restored.fighters[0].has("normal_jump"), "Pre-feature snapshots restore with safe jump-state defaults")
	sim.reset_training()
	_check(not sim.fighters[0].double_jump_used and not sim.fighters[0].normal_jump, "Training reset clears jump state")
	sim.fighters[0].double_jump_used = true
	sim.next_round()
	_check(not sim.fighters[0].double_jump_used and not sim.fighters[0].normal_jump, "Round reset clears jump state")
