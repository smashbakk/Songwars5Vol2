extends RefCounted

# Property of LiveLayer Technology LLC.
# Exercise the launcher string through the same one-tick inputs as keyboard/touch.
const Sim = preload("res://scripts/combat/fight_sim.gd")
const Data = preload("res://scripts/combat/fighter_data.gd")
static var failures: Array = []
static var checks: int = 0

static func run() -> Array:
	failures = []
	checks = 0
	_test_order_and_damage()
	_test_wrong_inputs_and_mashing()
	_test_press_order()
	_test_buffered_variant_and_prior_combo()
	_test_float_lifetime()
	_test_stun_and_followup()
	_test_repop_cap_and_restore()
	_test_defender_dog_cannot_escape()
	_test_low_kick_guard_and_damage()
	_test_window_deadline_both_sides()
	_test_landing_contact_both_sides()
	print("Juggle: %d checks, %d failures." % [checks, failures.size()])
	return failures

static func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

static func _fresh(id: String = "bank", index: int = 0) -> RefCounted:
	var sim = Sim.new()
	sim.setup(id if index == 0 else "bank", id if index == 1 else "bank", {}, {}, true, 1701)
	sim.countdown = 0
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

static func _flush_hitstop(sim: RefCounted) -> void:
	for tick in 20:
		if int(sim.hitstop) <= 0:
			return
		_step(sim)

static func _connect(sim: RefCounted, attack: String, index: int = 0, down: bool = false, other: Dictionary = {}) -> bool:
	var before: int = int(sim.fighters[1 - index].hp)
	_step(sim, {"attack": attack, "down": down}, index, 1, other)
	for tick in 60:
		if int(sim.fighters[1 - index].hp) < before:
			return true
		_step(sim, {}, index, 1, other)
	return false

static func _launch(sim: RefCounted, index: int = 0) -> bool:
	return _connect(sim, "heavy", index, true)

static func _complete(sim: RefCounted, index: int = 0) -> bool:
	return _launch(sim, index) and _connect(sim, "low", index) and _connect(sim, "heavy", index) and _connect(sim, "kick", index, true)

static func _test_order_and_damage() -> void:
	for id in Data.IDS:
		for index in 2:
			var sim = _fresh(id, index)
			var foe: Dictionary = sim.fighters[1 - index]
			var me: Dictionary = sim.fighters[index]
			var before: int = int(foe.hp)
			_check(_launch(sim, index), "%s side %d uppercut connects as launcher" % [id, index])
			_check(int(foe.get("juggle_hits", 0)) == 1 and int(foe.get("juggle_owner", -1)) == index, "Only uppercut establishes hit one and its owner")
			var total: int = int(Sim.MOVE_DATA.uppercut.damage) + (int(me.damage_rank) - 1) * 2
			_check(before - int(foe.hp) == total, "Launcher keeps normal class damage")
			var attacks: Array = ["low", "heavy", "kick"]
			var moves: Array = ["low", "heavy", "low_kick"]
			for step in 3:
				_check(_connect(sim, attacks[step], index, step == 2), "Correct juggle step %d connects" % (step + 2))
				_check(int(foe.get("juggle_hits", 0)) == step + 2, "Each correct fresh press advances exactly one juggle step")
				_check(str(me.move) == moves[step], "Step %d uses the intended distinct move" % (step + 2))
				if step < 2:
					_check(int(foe.get("juggle_window", 0)) == 24, "Each correct intermediate hit refreshes the brief float window")
				if Sim.MOVE_DATA.has(moves[step]):
					total += int(Sim.MOVE_DATA[moves[step]].damage) + (int(me.damage_rank) - 1) * 2
				_check(before - int(foe.hp) == total, "Juggle hit %d keeps full normal move damage without scaling" % (step + 2))
			_check(str(foe.state) == "stunned" and int(foe.stun) == 90, "Four hits apply distinct ninety-frame stun for every fighter and side")
	# Ordinary hits and blocked launchers never start the string.
	for attack in ["light", "low", "kick", "heavy"]:
		var sim = _fresh()
		_check(_connect(sim, attack), "Ordinary setup hit connects")
		_check(int(sim.fighters[1].get("juggle_hits", 0)) == 0, "Standing " + attack + " cannot establish a juggle")
	var blocked = _fresh()
	_step(blocked, {"attack": "heavy", "down": true}, 0, 1, {"block": true})
	_step(blocked, {}, 0, 14, {"block": true})
	_check(int(blocked.fighters[1].get("juggle_hits", 0)) == 0 and int(blocked.fighters[1].y) == 0, "Blocked uppercut has no juggle window")

static func _test_wrong_inputs_and_mashing() -> void:
	for attack in ["light", "kick", "heavy", "uppercut", "low_kick", "throw"]:
		var sim = _fresh()
		_launch(sim)
		var foe: Dictionary = sim.fighters[1]
		var before: int = int(foe.hp)
		sim.fighters[0].meter = 60
		_step(sim, {"attack": attack})
		_step(sim, {}, 0, 18)
		_check(int(foe.hp) == before, "Wrong next input " + attack + " whiffs through float")
		_check(int(foe.get("juggle_hits", 0)) <= 1, "Wrong input cannot skip or advance a juggle step")
	# Repeating a connected low punch never becomes a high kick or low kick.
	var sim = _fresh()
	_launch(sim)
	_check(_connect(sim, "low"), "Low punch advances the string to two")
	var before: int = int(sim.fighters[1].hp)
	_step(sim, {"attack": "low"}, 0, 20)
	_check(int(sim.fighters[1].hp) == before, "Mashing low punch cannot connect again after step two")
	_check(int(sim.fighters[1].get("juggle_hits", 0)) <= 2 and str(sim.fighters[1].state) != "stunned", "Mashing one attack never completes or advances the string")
	# The pet and projectile paths also obey float immunity.
	sim = _fresh("cin")
	_launch(sim)
	_flush_hitstop(sim)
	before = int(sim.fighters[1].hp)
	sim.fighters[0].dog_x = int(sim.fighters[1].x)
	sim.fighters[0].dog_cooldown = 1
	_step(sim)
	_check(int(sim.fighters[1].hp) == before and int(sim.fighters[1].get("juggle_hits", 0)) == 1, "Automatic dog strike cannot damage or advance floating defender")
	sim = _fresh()
	_launch(sim)
	_flush_hitstop(sim)
	before = int(sim.fighters[1].hp)
	sim.projectiles.append({"x": int(sim.fighters[1].x) - 15, "y": int(sim.fighters[1].y), "owner": 0, "direction": 1, "life": 1, "low": false})
	_step(sim)
	_check(int(sim.fighters[1].hp) == before and int(sim.fighters[1].get("juggle_hits", 0)) == 1, "Projectile cannot bypass the required next manual input")
	# Both special molds reach the float but must not connect.
	for id in ["cin", "rico"]:
		sim = _fresh(id)
		_launch(sim)
		sim.fighters[0].meter = 60
		_flush_hitstop(sim)
		_step(sim, {"attack": "special", "move": -1})
		_check(str(sim.fighters[0].prompt.get("kind", "")) == "minor", id + " opens its actual minor-special prompt during float")
		if not sim.fighters[0].prompt.is_empty():
			_step(sim, {"attack": str(sim.fighters[0].prompt.get("button", ""))})
		_check(str(sim.fighters[0].move) == "minor", id + " executes its minor special during float")
		before = int(sim.fighters[1].hp)
		_step(sim, {}, 0, 15)
		_check(int(sim.fighters[1].hp) == before, id + " minor special cannot hit a juggle-protected float")

static func _test_press_order() -> void:
	# A press made before the launcher contacts must not be saved for step two.
	for early_frame in [5, 10]:
		var sim = _fresh()
		_step(sim, {"attack": "heavy", "down": true})
		for age in range(2, 11):
			_step(sim, {"attack": "low"} if age == early_frame else {})
		var after_launcher: int = int(sim.fighters[1].hp)
		_step(sim, {}, 0, 12)
		_check(int(sim.fighters[1].hp) == after_launcher and int(sim.fighters[1].get("juggle_hits", 0)) == 1, "Low punch pressed before/same tick as launcher contact cannot auto-advance")
	# A fresh post-contact press is valid even when sampled during hitstop.
	var sim = _fresh()
	_launch(sim)
	_check(int(sim.hitstop) > 0, "Launcher provides the normal hitstop input-buffer window")
	_check(_connect(sim, "low"), "A low punch pressed after launcher contact during hitstop connects")
	_check(int(sim.fighters[1].get("juggle_hits", 0)) == 2, "Post-contact hitstop input advances only its one correct step")
	# Earlier gesture/special shortcuts must not reinterpret a correct string input.
	sim = _fresh()
	_launch(sim)
	sim.fighters[0].meter = 60
	sim.fighters[0].throw_ready = 20
	_check(_connect(sim, "low") and int(sim.fighters[1].juggle_hits) == 2, "Required low punch takes priority over an armed throw gesture")
	_check(_connect(sim, "heavy"), "High kick follows low punch with gesture history")
	sim.fighters[0].prompt = {"kind": "minor", "button": "kick", "remaining": 120}
	_check(_connect(sim, "kick", 0, true) and str(sim.fighters[1].state) == "stunned", "Required low kick takes priority over an earlier special prompt")
	# A correct button still requires normal horizontal reach.
	sim = _fresh()
	_launch(sim)
	sim.fighters[0].x = 100
	var before: int = int(sim.fighters[1].hp)
	_step(sim, {"attack": "low"})
	_step(sim, {}, 0, 15)
	_check(int(sim.fighters[1].hp) == before and int(sim.fighters[1].get("juggle_hits", 0)) <= 1, "Correct next input outside move reach does not advance the string")

static func _test_buffered_variant_and_prior_combo() -> void:
	var sim = _fresh()
	_launch(sim)
	_connect(sim, "low")
	_check(int(sim.hitstop) > 0, "Low punch contact supplies a real hitstop buffer")
	var before: int = int(sim.fighters[1].hp)
	# This standing high kick was pressed first. Holding Down on a later tick
	# must not rewrite the stored press into an uppercut before it starts.
	_step(sim, {"attack": "heavy"})
	for tick in 24:
		_step(sim, {"down": true})
		if int(sim.fighters[1].hp) < before:
			break
	_check(str(sim.fighters[0].move) == "heavy" and int(sim.fighters[1].get("juggle_hits", 0)) == 3, "Buffered standing high kick preserves its variant after later Down input")
	_check(before - int(sim.fighters[1].hp) == int(Sim.MOVE_DATA.heavy.damage), "Buffered standing high kick connects with its normal damage")
	# The separate five-hit rule must not truncate a launcher string just
	# because the attacker already connected ordinary hits before launching.
	sim = _fresh()
	for hit in 3:
		_check(_connect(sim, "light"), "Pre-launch ordinary hit connects")
	_check(int(sim.fighters[0].combo_hits) == 3, "Three earlier ordinary contacts share a live generic combo")
	_check(_complete(sim) and str(sim.fighters[1].state) == "stunned", "Launcher string finishes despite crossing five generic hits during the float")
	_check(int(sim.fighters[1].get("juggle_hits", 0)) == 4, "The launcher remains string hit one independently of generic combo count")

static func _test_float_lifetime() -> void:
	var sim = _fresh()
	_launch(sim)
	_flush_hitstop(sim)
	var foe: Dictionary = sim.fighters[1]
	var x: int = int(foe.x)
	var before: int = int(sim.fighters[0].hp)
	_step(sim, {}, 0, 21, {"move": 1, "down": true, "jump": true, "attack": "heavy", "block": true})
	_check(int(foe.x) == x and int(sim.fighters[0].hp) == before and not bool(foe.blocking), "Floating defender cannot steer, attack, jump or block even after ordinary hitstun")
	# Wait out the finite window while the launched arc is still airborne.
	for tick in 20:
		if int(foe.get("juggle_window", 0)) <= 0:
			break
		_step(sim)
	_check(int(foe.get("juggle_window", 0)) == 0 and int(foe.get("juggle_hits", 0)) == 0, "Window timeout clears the active chain")
	_check(int(foe.y) > 0, "Finite float window can expire before ordinary launch landing")
	# Another uppercut before landing cannot restart this airborne string.
	_connect(sim, "uppercut")
	_check(int(foe.get("juggle_hits", 0)) == 0, "A timed-out string cannot restart within the same launch")
	_step(sim, {}, 0, 80)
	_check(int(foe.y) == 0, "A failed chain eventually lands")
	# Landing cancels immediately, independently of remaining window duration.
	sim = _fresh()
	_launch(sim)
	_flush_hitstop(sim)
	foe = sim.fighters[1]
	foe.y = 1
	foe.jump_frame = 42
	_step(sim)
	_check(int(foe.get("juggle_window", 0)) == 0 and int(foe.get("juggle_hits", 0)) == 0 and int(foe.get("juggle_owner", -1)) == -1, "Landing immediately clears juggle owner, progress and window")
	# A fresh grounded launch gets one new string, including after a reset.
	_step(sim, {}, 0, 50)
	_check(_launch(sim) and int(foe.get("juggle_hits", 0)) == 1, "Landing allows a later independent uppercut string")
	sim.reset_training()
	_check(int(sim.fighters[1].get("juggle_hits", 0)) == 0 and int(sim.fighters[1].get("juggle_owner", -1)) == -1, "Training reset clears all active juggle progress")

static func _test_stun_and_followup() -> void:
	var sim = _fresh()
	_check(_complete(sim), "The four-hit string completes through real attacks")
	_flush_hitstop(sim)
	var foe: Dictionary = sim.fighters[1]
	var height: int = int(foe.y)
	var x: int = int(foe.x)
	var before: int = int(sim.fighters[0].hp)
	_step(sim, {}, 0, 89, {"attack": "heavy", "block": true, "down": true, "jump": true, "move": 1})
	_check(str(foe.state) == "stunned" and int(foe.stun) == 1, "Completion stun lasts ninety combat frames")
	_check(int(foe.y) == height and int(foe.x) == x and int(sim.fighters[0].hp) == before and not bool(foe.blocking), "Stun suspends the target and prevents every defensive/action input")
	_step(sim)
	_check(str(foe.state) != "stunned", "Stun expires on its ninetieth unfrozen combat frame")
	before = int(sim.fighters[0].hp)
	var escaped_fall: bool = false
	var fell_down: bool = false
	for tick in 45:
		_step(sim, {}, 0, 1, {"attack": "heavy", "block": true, "down": true, "jump": tick % 2 == 0, "move": 1})
		escaped_fall = escaped_fall or int(foe.x) != x or str(foe.state) == "attack" or bool(foe.normal_jump) or bool(foe.blocking)
		if int(foe.y) == 0:
			fell_down = str(foe.state) == "down"
			break
	_check(not escaped_fall and int(sim.fighters[0].hp) == before, "After stun expires the forced fall still prevents attack, jump, guard and steering")
	_check(fell_down, "Uninterrupted post-stun fall enters the existing down state on landing")
	var recovered_down: bool = str(foe.state) == "down"
	var recovered_getup: bool = false
	for tick in 140:
		_step(sim)
		recovered_down = recovered_down or str(foe.state) == "down"
		recovered_getup = recovered_getup or str(foe.state) == "getup"
	_check(recovered_down and recovered_getup and int(foe.y) == 0 and str(foe.state) == "idle", "Expired stun falls through existing knockdown and getup recovery")
	# The next hit lands at suspended height regardless of high/low guard.
	for attack in ["light", "low", "kick", "heavy", "low_kick", "uppercut"]:
		sim = _fresh()
		_complete(sim)
		foe = sim.fighters[1]
		before = int(foe.hp)
		_check(_connect(sim, attack, 0, false, {"block": true, "down": true}), "Stunned defender gives a free " + attack + " followup")
		if Sim.MOVE_DATA.has(attack):
			_check(before - int(foe.hp) == int(Sim.MOVE_DATA[attack].damage), "Free followup keeps normal " + attack + " damage")
		_check(str(foe.state) != "stunned" and int(foe.get("juggle_window", 0)) == 0, "Free hit consumes stun without opening another string")

static func _test_repop_cap_and_restore() -> void:
	for start_height in [0, 100, 110, 160]:
		var sim = _fresh()
		var foe: Dictionary = sim.fighters[1]
		foe.y = start_height
		foe.state = "jump" if start_height > 0 else "idle"
		_check(_launch(sim), "Uppercut starts string from height %d" % start_height)
		for attack in ["low", "heavy", "low_kick"]:
			var before: int = int(foe.hp)
			_step(sim, {"attack": attack})
			for tick in 45:
				_check(int(foe.y) <= Sim.JUMP_APEX, "Every re-pop tick stays beneath the normal jump apex")
				if int(foe.hp) < before:
					break
				_step(sim)
			_check(int(foe.hp) < before, "Capped re-pop still permits the next intended move")
		_check(str(foe.state) == "stunned", "Apex cap does not prevent completion")
	# Snapshot restores owner/progress, buffered presses and the eventual stun.
	var sim = _fresh()
	_launch(sim)
	_connect(sim, "low")
	var restored = Sim.new()
	restored.restore(sim.snapshot())
	_check(restored.snapshot() == sim.snapshot(), "Snapshot preserves active string and post-contact hitstop exactly")
	for attack in ["heavy", "low_kick"]:
		_connect(sim, attack)
		_connect(restored, attack)
	_check(restored.snapshot() == sim.snapshot() and str(restored.fighters[1].state) == "stunned", "Restored active string completes deterministically")
	_step(sim, {}, 0, 160)
	_step(restored, {}, 0, 160)
	_check(restored.snapshot() == sim.snapshot(), "Restored stun, fall and getup remain deterministic")

static func _test_defender_dog_cannot_escape() -> void:
	for index in 2:
		for phase in ["float", "stunned", "fall"]:
			# Bank launches Cin; her autonomous partner must not interrupt Bank.
			var sim = _fresh("cin", 1 - index)
			if phase == "float":
				_check(_launch(sim, index), "Bank launches Cin for defender-pet regression")
			else:
				_check(_complete(sim, index), "Bank completes string on Cin for defender-pet regression")
			_flush_hitstop(sim)
			if phase == "fall":
				_step(sim, {}, index, 90)
			var bank: Dictionary = sim.fighters[index]
			var cin: Dictionary = sim.fighters[1 - index]
			var hp: int = int(bank.hp)
			var state: String = str(bank.state)
			var move: String = str(bank.move)
			cin.dog_cooldown = 1
			cin.dog_x = int(bank.x)
			_step(sim)
			_check(int(bank.hp) == hp and str(bank.state) == state and str(bank.move) == move, "Cin's defender dog cannot damage or interrupt attacker during " + phase + " on side " + str(index))

static func _test_low_kick_guard_and_damage() -> void:
	for id in Data.IDS:
		for guard in ["none", "high", "low"]:
			var sim = _fresh(id)
			var defender: Dictionary = {"block": guard != "none", "down": guard == "low"}
			var before: int = int(sim.fighters[1].hp)
			_step(sim, {"attack": "kick", "down": true}, 0, 1, defender)
			_check(str(sim.fighters[0].move) == "low_kick" and bool(sim.fighters[0].attack_low), id + " Down + Kick is a distinct low attack outside the string")
			_step(sim, {}, 0, int(Sim.MOVE_DATA.low_kick.startup) - 2, defender)
			_check(int(sim.fighters[1].hp) == before, "Low kick respects its normal startup before " + guard + " guard contact")
			_step(sim, {}, 0, 1, defender)
			var damage: int = 0 if guard == "low" else int(Sim.MOVE_DATA.low_kick.damage) + (int(sim.fighters[0].damage_rank) - 1) * 2
			_check(before - int(sim.fighters[1].hp) == damage, id + " low kick deals normal class damage and respects " + guard + " guard")
			_check(int(sim.fighters[1].y) == 0 and int(sim.fighters[1].get("juggle_hits", 0)) == 0, "Low kick alone never launches or starts a string")
			if guard == "low":
				_check(int(sim.fighters[1].meter) == 10, "Timed crouch guard stops low kick and earns the existing guard reward")

static func _test_window_deadline_both_sides() -> void:
	# Startup reaches its first active tick on the last positive window frame
	# after 17 idle ticks, or exactly on expiration after 18. Resolve both slots
	# identically so defender tick order cannot create an extra contact frame.
	for delay in [17, 18]:
		var damage_by_side: Array = []
		for index in 2:
			var sim = _fresh("bank", index)
			_launch(sim, index)
			_flush_hitstop(sim)
			_step(sim, {}, index, delay)
			var before: int = int(sim.fighters[1 - index].hp)
			_step(sim, {"attack": "low"}, index)
			_step(sim, {}, index, 5)
			var damage: int = before - int(sim.fighters[1 - index].hp)
			damage_by_side.append(damage)
			_check(damage == (int(Sim.MOVE_DATA.low.damage) if delay == 17 else 0), "Window deadline applies normal damage only before expiry on side %d after delay %d" % [index, delay])
			_check(int(sim.fighters[1 - index].get("juggle_hits", 0)) == (2 if delay == 17 else 0), "Window deadline advances or expires equally for each slot")
		_check(damage_by_side[0] == damage_by_side[1], "Juggle expiration has the same contact result for both player slots")

static func _test_landing_contact_both_sides() -> void:
	# Contact is collected before the other slot's arc may land. Once the
	# float ends, both slots must apply ordinary vertical attack geometry.
	for attacker_height in [0, 110]:
		var damage_by_side: Array = []
		for index in 2:
			var sim = _fresh("bank", index)
			_launch(sim, index)
			_flush_hitstop(sim)
			_step(sim, {"attack": "low"}, index)
			_step(sim, {}, index, 4)
			var attacker: Dictionary = sim.fighters[index]
			var defender: Dictionary = sim.fighters[1 - index]
			var before: int = int(defender.hp)
			attacker.y = attacker_height
			defender.y = 1
			defender.jump_frame = 42
			_step(sim)
			var damage: int = before - int(defender.hp)
			damage_by_side.append(damage)
			_check(damage == (int(Sim.MOVE_DATA.low.damage) if attacker_height == 0 else 0), "Landing contact applies ordinary low-punch height and damage on side %d at attacker height %d" % [index, attacker_height])
			_check(int(defender.y) == 0 and int(defender.get("juggle_hits", 0)) == 0 and int(defender.get("juggle_window", 0)) == 0, "A defender landing on the contact tick ends the juggle without advancing it")
		_check(damage_by_side[0] == damage_by_side[1], "Landing on the contact tick has identical results for both fighter slots")
