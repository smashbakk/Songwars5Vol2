extends RefCounted

# Property of LiveLayer Technology LLC.
const Sim = preload("res://scripts/combat/fight_sim.gd")
const CPU = preload("res://scripts/combat/cpu_brain.gd")
static var failures: Array = []
static var checks: int = 0

static func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

static func run() -> Array:
	failures = []
	checks = 0
	_test_attempts_and_execution()
	_test_restore()
	print("CPU juggle: %d checks, %d failures." % [checks, failures.size()])
	return failures

static func _launched(index: int) -> RefCounted:
	var sim = Sim.new()
	sim.setup("bank", "bank", {}, {}, true, 6401)
	sim.countdown = 0
	sim.fighters[0].x = 500
	sim.fighters[1].x = 570
	var inputs: Array = [{}, {}]
	inputs[index] = {"attack": "heavy", "down": true}
	sim.step(inputs)
	for tick in 9:
		sim.step([{}, {}])
	return sim

static func _step(sim, index: int, action: Dictionary) -> void:
	var inputs: Array = [{}, {}]
	inputs[index] = action
	sim.step(inputs)

static func _test_attempts_and_execution() -> void:
	for difficulty in 3:
		for index in 2:
			var completed: int = 0
			var attempted: int = 0
			var mistakes: int = 0
			var clean_order: bool = true
			var after_confirm: bool = true
			for seed_value in range(1, 121):
				var sim = _launched(index)
				var brain = CPU.new()
				brain.setup(difficulty, seed_value)
				var did_attempt: bool = false
				for tick in 100:
					var foe: Dictionary = sim.fighters[1 - index]
					if int(foe.get("juggle_window", 0)) <= 0:
						completed += 1 if str(foe.state) == "stunned" else 0
						break
					var action: Dictionary = brain.decide(sim, index)
					if not str(action.attack).is_empty():
						did_attempt = true
						after_confirm = after_confirm and int(sim.hitstop) == 0 and int(foe.juggle_hits) in [1, 2, 3]
						if action.attack == "light":
							mistakes += 1
						else:
							var step: int = int(foe.juggle_hits)
							clean_order = clean_order and str(action.attack) == ["low", "heavy", "kick"][step - 1] and bool(action.down) == (step in [1, 3])
					_step(sim, index, action)
				attempted += 1 if did_attempt else 0
			_check(attempted > 0 and attempted < 120, "CPU dial %d side %d attempts only some launches" % [difficulty, index])
			_check(completed > 0 and completed < attempted, "CPU dial %d side %d can finish and can miss its juggle" % [difficulty, index])
			_check(mistakes > 0, "CPU dial %d side %d sometimes makes an execution error" % [difficulty, index])
			_check(clean_order, "CPU dial %d side %d uses low punch, standing heavy, then crouched kick" % [difficulty, index])
			_check(after_confirm, "CPU dial %d side %d waits for each hit confirmation and hitstop before pressing again" % [difficulty, index])

static func _test_restore() -> void:
	for index in 2:
		var sim = _launched(index)
		var brain = CPU.new()
		brain.setup(2, 127)
		_step(sim, index, brain.decide(sim, index))
		var copy_sim = Sim.new()
		copy_sim.restore(sim.snapshot())
		var copy_brain = CPU.new()
		copy_brain.restore(brain.snapshot())
		var matched: bool = true
		for tick in 100:
			var action: Dictionary = brain.decide(sim, index)
			var copy_action: Dictionary = copy_brain.decide(copy_sim, index)
			matched = matched and action == copy_action
			_step(sim, index, action)
			_step(copy_sim, index, copy_action)
		_check(matched and sim.snapshot() == copy_sim.snapshot() and brain.snapshot() == copy_brain.snapshot(), "CPU side %d restores its juggle attempt, delay and errors deterministically" % index)
