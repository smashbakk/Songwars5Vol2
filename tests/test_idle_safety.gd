extends RefCounted

# Property of LiveLayer Technology LLC.
# CEO rulings, Nov 15 2026: standing idle must never cost health on its own.
# Cin City's dog bite is a kept feature at exactly 2 damage (down from 6).

const Sim = preload("res://scripts/combat/fight_sim.gd")

static var failures: Array = []
static var check_count: int = 0

static func _check(condition: bool, message: String) -> void:
	check_count += 1
	if not condition:
		failures.append(message)

static func run() -> Array:
	failures = []
	check_count = 0
	_test_idle_vs_cin(true)
	_test_idle_vs_cin(false)
	_test_idle_without_cin()
	print("Idle safety: %d checks, %d failures." % [check_count, failures.size()])
	return failures

static func _idle_drops(training: bool, frames: int) -> Dictionary:
	var sim = Sim.new()
	sim.setup("cin", "rico", {}, {}, training, 4242)
	sim.countdown = 0
	var drops: Array = []
	var prev: int = int(sim.fighters[1].hp)
	var cin_min: int = int(sim.fighters[0].hp)
	for n in frames:
		sim.step([{}, {}])
		var hp: int = int(sim.fighters[1].hp)
		if hp < prev:
			drops.append(prev - hp)
		prev = hp
		cin_min = mini(cin_min, int(sim.fighters[0].hp))
	return {"drops": drops, "cin_min": cin_min, "cin_max": int(sim.fighters[0].max_hp)}

static func _test_idle_vs_cin(training: bool) -> void:
	var mode: String = "training" if training else "versus"
	var result: Dictionary = _idle_drops(training, 1800)
	var drops: Array = result.drops
	_check(drops.size() >= 5, "Idle vs Cin (%s): the dog still bites (kept feature), saw %d bites" % [mode, drops.size()])
	var only_twos: bool = true
	for d in drops:
		if int(d) != 2:
			only_twos = false
	_check(only_twos, "Idle vs Cin (%s): every idle health drop is exactly 2 (dog bite), saw %s" % [mode, str(drops.slice(0, 5))])
	_check(int(result.cin_min) == int(result.cin_max), "Idle vs Cin (%s): Cin herself loses no health standing still" % mode)

static func _test_idle_without_cin() -> void:
	var sim = Sim.new()
	sim.setup("rico", "bank", {}, {}, false, 4242)
	sim.countdown = 0
	for n in 3600:
		sim.step([{}, {}])
	_check(int(sim.fighters[0].hp) == int(sim.fighters[0].max_hp), "Idle without Cin: fighter 1 loses no health in 3600 frames")
	_check(int(sim.fighters[1].hp) == int(sim.fighters[1].max_hp), "Idle without Cin: fighter 2 loses no health in 3600 frames")
