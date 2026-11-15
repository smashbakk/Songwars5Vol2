extends RefCounted

# Property of LiveLayer Technology LLC.
const Sim = preload("res://scripts/combat/fight_sim.gd")
const CPU = preload("res://scripts/combat/cpu_brain.gd")
const Data = preload("res://scripts/combat/fighter_data.gd")
static var failures: Array = []
static var checks: int = 0

static func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

static func run() -> Array:
	failures = []
	checks = 0
	_test_uppercut_decisions()
	_test_sparse_double_jumps()
	print("CPU mobility: %d checks, %d failures." % [checks, failures.size()])
	return failures

static func _fresh(id: String = "bank") -> RefCounted:
	var sim = Sim.new()
	sim.setup(id, id, {}, {}, true, 2305)
	sim.countdown = 0
	for fighter in sim.fighters:
		fighter.dog_cooldown = 100000
	return sim

static func _test_uppercut_decisions() -> void:
	for id in Data.IDS:
		for index in 2:
			var sim = _fresh(id)
			var me: Dictionary = sim.fighters[index]
			var foe: Dictionary = sim.fighters[1 - index]
			me.x = 500
			me.facing = 1 if index == 0 else -1
			foe.x = 500 + int(me.facing) * 80
			foe.state = "jump"
			foe.y = 100
			foe.jump_frame = 25
			var brain = CPU.new()
			brain.setup(1, 921)
			var action: Dictionary = brain.decide(sim, index)
			_check(action.attack == "heavy" and action.down, "%s CPU %d answers an in-range jump-in with crouched heavy" % [id, index])
			var inputs: Array = [{}, {}]
			inputs[index] = action
			sim.step(inputs)
			_check(me.move == "uppercut" and not me.attack_low, "%s CPU %d uses the same uppercut input path as the player" % [id, index])
			var before: int = int(foe.hp)
			for tick in 15:
				sim.step([{}, {}])
			_check(int(foe.hp) < before, "%s CPU %d uppercut connects with a descending jump-in" % [id, index])
	var sim = _fresh()
	var brain = CPU.new()
	brain.setup(2, 1)
	sim.fighters[1].x = int(sim.fighters[0].x) - 80
	sim.fighters[1].y = 100
	sim.fighters[1].state = "jump"
	var action: Dictionary = brain.decide(sim, 0)
	_check(not (action.attack == "heavy" and action.down), "CPU does not uppercut a jump-in behind its current facing")
	sim = _fresh()
	sim.fighters[0].state = "crouch"
	sim.fighters[0].down = true
	sim.fighters[1].x = int(sim.fighters[0].x) + 145
	var closes_distance: bool = true
	for seed_value in range(1, 101):
		brain.setup(2, seed_value)
		action = brain.decide(sim, 0)
		closes_distance = closes_distance and action.attack == "" and int(action.move) == 1
	_check(closes_distance, "Crouched CPU closes into uppercut range instead of whiffing a converted heavy")

static func _test_sparse_double_jumps() -> void:
	for difficulty in 3:
		var attempts: int = 0
		var invalid_edge: bool = false
		var double_count: int = 0
		for seed_value in range(1, 101):
			var sim = _fresh()
			# A real normal jump gives each seeded brain one airborne period.
			sim.step([{"jump": true}, {}])
			var brain = CPU.new()
			brain.setup(difficulty, seed_value)
			for tick in 100:
				var before: bool = bool(sim.fighters[0].double_jump_used)
				var action: Dictionary = brain.decide(sim, 0)
				if action.jump and int(sim.fighters[0].y) > 0:
					attempts += 1
					invalid_edge = invalid_edge or bool(sim.fighters[0].prev_jump) or before
				sim.step([action, {}])
				if not before and bool(sim.fighters[0].double_jump_used):
					double_count += 1
				if int(sim.fighters[0].y) == 0:
					break
		_check(attempts > 0 and attempts < 50, "CPU dial %d double jumps in a minority of 100 normal jumps" % difficulty)
		_check(not invalid_edge, "CPU dial %d requests only fresh, unused double-jump edges" % difficulty)
		_check(double_count == attempts, "CPU dial %d airborne jump requests start real double jumps" % difficulty)
	# Uppercut launches never give the CPU a second jump.
	var sim = _fresh()
	sim.fighters[0].y = 80
	sim.fighters[0].jump_frame = 10
	sim.fighters[0].state = "jump"
	sim.fighters[0].normal_jump = false
	var brain = CPU.new()
	brain.setup(2, 1)
	var launched_jump: bool = false
	for tick in 100:
		brain.think_in = 0
		launched_jump = launched_jump or bool(brain.decide(sim, 0).jump)
	_check(not launched_jump, "CPU does not double jump out of an uppercut launch")
