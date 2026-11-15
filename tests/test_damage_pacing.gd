extends RefCounted

# Property of LiveLayer Technology LLC.
# Compare damage tables using the same live simulation and CPU implementation.
# Legacy values are doubled along with HP, preserving the baseline percentages.
const Sim = preload("res://scripts/combat/fight_sim.gd")
const CPU = preload("res://scripts/combat/cpu_brain.gd")
const Data = preload("res://scripts/combat/fighter_data.gd")

class OldDamageSim:
	extends "res://scripts/combat/fight_sim.gd"

	const OLD_REGULAR = {"light": 8, "low": 10, "kick": 12, "heavy": 18, "uppercut": 16, "low_kick": 10}
	const OLD_BIG = {
		"cin": [8, 12, 10, 20, 40], "rico": [12, 12, 12, 14, 40],
		"hood": [20, 30, 40], "bank": [20, 20, 50]
	}

	var resolving_regular: String = ""

	func _make_fighter(id: String, index: int, upgrades: Dictionary) -> Dictionary:
		var fighter: Dictionary = super._make_fighter(id, index, upgrades)
		fighter.big_hits = OLD_BIG.get(fighter.id, fighter.big_hits).duplicate()
		return fighter

	func _damage(i: int, damage: int, kind: String, blocked: bool, minimum_hp: int = 0) -> void:
		var fighter: Dictionary = fighters[i]
		if kind == "hit":
			damage += int(OLD_REGULAR[resolving_regular]) - int(MOVE_DATA[resolving_regular].damage)
		elif kind == "minor_hit" and fighter.minor == "projectile":
			damage = 6 if blocked else 28
		elif kind == "big" and blocked:
			# Halve in the original units before doubling: original 7 -> 3 -> 6.
			damage -= damage % 2
			minimum_hp *= 2
		super._damage(i, damage, kind, blocked, minimum_hp)

	func _hit_regular(i: int, move_name: String, dog: bool, target_dog: bool = false) -> void:
		var first_event: int = events.size()
		resolving_regular = move_name
		super._hit_regular(i, move_name, dog, target_dog)
		resolving_regular = ""
		for event in events.slice(first_event):
			if event.type == "hit":
				fighters[i].combo_damage += int(OLD_REGULAR[move_name]) - int(MOVE_DATA[move_name].damage)

	func _tick_attack(i: int) -> void:
		super._tick_attack(i)
		if fighters[i].state == "throw_hold":
			fighters[i].throw_damage = {16: 20, 22: 30, 30: 40}[int(fighters[i].throw_damage)]

	func _minor_hit(i: int, damage: int, chip: int, final_hit: bool, target_dog: bool = false) -> void:
		var multi: bool = fighters[i].minor == "multi"
		super._minor_hit(i, 14 if multi else 28, (4 if final_hit else 2) if multi else 6, final_hit, target_dog)

	func _tick_big(i: int) -> void:
		var first_event: int = events.size()
		var hit_index: int = int(fighters[i].big_index)
		super._tick_big(i)
		for event in events.slice(first_event):
			if event.type == "big" and event.blocked:
				fighters[i].combo_damage -= (int(fighters[i].big_hits[hit_index]) / 2) % 2

	func _update_projectiles() -> void:
		var first_event: int = events.size()
		super._update_projectiles()
		for event in events.slice(first_event):
			if event.type == "minor_hit" and not event.blocked:
				fighters[int(event.attacker)].combo_damage += 6

static var failures: Array = []
static var check_count: int = 0

static func _check(condition: bool, message: String) -> void:
	check_count += 1
	if not condition:
		failures.append(message)

static func run() -> Array:
	failures = []
	check_count = 0
	_test_clean_heavy_barrage()
	_test_cpu_round_lengths()
	print("Damage pacing: %d checks, %d failures." % [check_count, failures.size()])
	return failures

static func _heavy_barrage(legacy: bool) -> Dictionary:
	var sim = OldDamageSim.new() if legacy else Sim.new()
	sim.setup("bank", "bank", {}, {}, false, 1701)
	sim.countdown = 0
	sim.fighters[0].x = 500
	sim.fighters[1].x = 570
	var hits: int = 0
	while not sim.round_over and sim.frame < 1200:
		var attack: String = "heavy" if sim.fighters[0].state == "idle" else ""
		sim.step([{"attack": attack}, {}])
		for event in sim.events:
			if event.type == "hit":
				hits += 1
	return {"frames": sim.frame, "hits": hits, "ko": sim.round_over and sim.fighters[1].hp == 0}

static func _test_clean_heavy_barrage() -> void:
	var old: Dictionary = _heavy_barrage(true)
	var current: Dictionary = _heavy_barrage(false)
	_check(old.ko and current.ko, "Both clean-heavy barrages finish by KO")
	_check(old.hits == 12 and current.hits == 15, "Reduced heavy damage requires fifteen clean hits instead of twelve")
	_check(current.frames >= 540, "Uncanceled clean-heavy barrage cannot KO before nine seconds")
	_check(current.frames > old.frames, "Clean-heavy time to KO increases against the old damage table")
	print("Clean heavy barrage: old %d frames (%d hits), new %d frames (%d hits)." % [old.frames, old.hits, current.frames, current.hits])

static func _cpu_round(one: String, two: String, difficulty: int, seed_value: int, legacy: bool) -> Dictionary:
	var sim = OldDamageSim.new() if legacy else Sim.new()
	sim.setup(one, two, {}, {}, false, seed_value)
	sim.countdown = 0
	var first = CPU.new()
	var second = CPU.new()
	first.setup(difficulty, seed_value * 7 + 31)
	second.setup(difficulty, seed_value * 11 + 19)
	while not sim.round_over and sim.frame < 10000:
		sim.step([first.decide(sim, 0), second.decide(sim, 1)])
	return {"frames": sim.frame, "ended": sim.round_over, "timeout": sim.time_left == 0}

static func _test_cpu_round_lengths() -> void:
	var old_total: int = 0
	var new_total: int = 0
	var samples: int = 0
	var completed: bool = true
	var timeouts: int = 0
	# Every roster pairing, every difficulty, and three seeds avoid one lucky duel.
	for one in range(Data.IDS.size()):
		for two in range(one + 1, Data.IDS.size()):
			for difficulty in 3:
				for seed_value in [921, 1701, 2305]:
					var old: Dictionary = _cpu_round(Data.IDS[one], Data.IDS[two], difficulty, seed_value, true)
					var current: Dictionary = _cpu_round(Data.IDS[one], Data.IDS[two], difficulty, seed_value, false)
					old_total += int(old.frames)
					new_total += int(current.frames)
					timeouts += 1 if current.timeout else 0
					completed = completed and old.ended and current.ended
					samples += 1
	_check(completed, "CPU pacing sample completes every old-table and new-table round")
	_check(new_total > old_total, "CPU average round length increases against the old damage table at identical seeds and difficulties")
	print("CPU pacing across %d rounds/table: old average %d frames, new average %d frames; %d new-table timeouts." % [samples, old_total / samples, new_total / samples, timeouts])
