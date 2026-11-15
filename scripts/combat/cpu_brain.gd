# Property of LiveLayer Technology LLC.
extends RefCounted

const ATTACK_RANGES = {"light": 108, "low": 115, "kick": 140, "heavy": 165, "uppercut": 120, "low_kick": 140}

# One deterministic brain. Difficulty changes reaction, defense and execution;
# the opponent's remaining health never changes its behavior.
var difficulty: int = 0
var rng_state: int = 1
var ticks: int = 0
var think_in: int = 0
var intent: Dictionary = {}
var prompt_kind: String = ""
var prompt_button: String = ""
var prompt_wait: int = 0
var prompt_answer: bool = false
var defend_special: bool = false
var grab_ticks: int = 0
var break_throw: bool = false
var last_cancel_start: int = -1
var juggle_active: bool = false
var juggle_attempt: bool = false
var juggle_step: int = 0
var juggle_wait: int = 0
var juggle_sent: bool = false

func setup(level: int = 0, seed_value: int = 1) -> void:
	difficulty = clampi(level, 0, 2)
	rng_state = maxi(1, seed_value % 2147483647)
	ticks = 0
	think_in = 0
	intent = _neutral()
	prompt_kind = ""
	prompt_button = ""
	prompt_wait = 0
	prompt_answer = false
	defend_special = false
	grab_ticks = 0
	break_throw = false
	last_cancel_start = -1
	juggle_active = false
	juggle_attempt = false
	juggle_step = 0
	juggle_wait = 0
	juggle_sent = false

func _random(limit: int) -> int:
	rng_state = (rng_state * 48271) % 2147483647
	return rng_state % maxi(1, limit)

func _neutral() -> Dictionary:
	return {"move": 0, "down": false, "jump": false, "attack": "", "block": false, "tap": ""}

func decide(sim, index: int) -> Dictionary:
	ticks += 1
	if sim.match_over or sim.round_over or sim.countdown > 0:
		intent = _neutral()
		think_in = 0
		prompt_kind = ""
		defend_special = false
		juggle_active = false
		return _neutral()
	var me: Dictionary = sim.fighters[index]
	var foe: Dictionary = sim.fighters[1 - index]
	var result: Dictionary = intent.duplicate(true)
	result["attack"] = ""
	result["jump"] = false
	result["tap"] = ""
	var state: String = str(me.get("state", "idle"))
	if state == "grabbed":
		if grab_ticks == 0:
			break_throw = _random(100) < [15, 40, 72][difficulty]
		grab_ticks += 1
		result = _neutral()
		if break_throw:
			var delay: int = [10, 7, 4][difficulty]
			if grab_ticks == delay or grab_ticks == delay + 6:
				result["tap"] = "back"
			elif grab_ticks == delay + 12:
				result["tap"] = "down"
		return result
	grab_ticks = 0
	# A launch is an opportunity, not a guaranteed conversion. React to each
	# confirmed hit separately; hitstop never consumes the reaction delay or
	# queues an input ahead of the next step.
	if int(foe.get("juggle_owner", -1)) == index and int(foe.get("juggle_window", 0)) > 0 and int(foe.get("juggle_hits", 0)) in [1, 2, 3]:
		intent = _neutral()
		return _follow_juggle(sim, index)
	juggle_active = false
	if bool(me.get("can_cancel", false)):
		var started_at: int = int(sim.combat_frame) - int(me.get("attack_frame", 0))
		if started_at != last_cancel_start:
			last_cancel_start = started_at
			if _random(100) < [15, 50, 85][difficulty]:
				think_in = mini(think_in, [10, 5, 1][difficulty])
	var prompt: Dictionary = me.get("prompt", {})
	var kind: String = str(prompt.get("kind", ""))
	var button: String = str(prompt.get("button", ""))
	if not kind.is_empty():
		if kind != prompt_kind or button != prompt_button:
			prompt_kind = kind
			prompt_button = button
			prompt_wait = [24, 15, 7][difficulty] + _random([16, 10, 5][difficulty])
			prompt_answer = _random(100) < ([40, 70, 94][difficulty] if kind == "block" else [72, 88, 100][difficulty])
			# A held ordinary guard must be released before the fresh timed tap.
			defend_special = false
		prompt_wait -= 1
		if kind == "block":
			result = _neutral()
			result["block"] = prompt_answer and prompt_wait <= 0
			defend_special = result["block"]
			return result
		elif prompt_wait <= 0 and prompt_answer:
			result = _neutral()
			result["attack"] = button
			return result
	else:
		prompt_kind = ""
		prompt_button = ""
	# Continue holding a successful special defense until capture ends.
	if defend_special:
		if state in ["big_capture", "captured", "big_block", "special_captured"]:
			result = _neutral()
			result["block"] = true
			return result
		defend_special = false
	think_in -= 1
	if think_in > 0:
		return result
	think_in = [25, 16, 9][difficulty] + _random([10, 6, 4][difficulty])
	result = _neutral()
	var distance: int = absi(int(foe["x"]) - int(me["x"]))
	var toward: int = 1 if int(foe["x"]) > int(me["x"]) else -1
	var foe_move: String = str(foe.get("move", ""))
	var foe_state: String = str(foe.get("state", "idle"))
	var danger: bool = foe_state in ["attack", "minor", "big_start", "big", "throw_hold"] or not foe_move.is_empty()
	var ready: bool = int(me.get("stun", 0)) <= 0 and (state in ["idle", "walk", "crouch", "jump"] or bool(me.get("can_cancel", false)))
	var uppercut_reach: int = int(int(ATTACK_RANGES.uppercut) * int(me.get("reach_percent", 100)) / 100)
	var jump_in: bool = int(foe["y"]) > 0 and int(foe["y"]) <= 170 and (int(foe["x"]) - int(me["x"])) * int(me["facing"]) > 0
	if ready and int(me["y"]) == 0 and jump_in and distance <= uppercut_reach:
		result["attack"] = "heavy"
		result["down"] = true
	elif danger and distance < 240 and _random(100) < [20, 46, 75][difficulty]:
		result["move"] = -toward
		result["block"] = true
		result["down"] = bool(foe.get("attack_low", false)) if _random(100) < [35, 65, 90][difficulty] else _random(2) == 0
	elif int(me["meter"]) >= 60 and _random(100) < [18, 36, 58][difficulty] and not foe_state in ["down", "getup"]:
		result["attack"] = "special"
		result["move"] = toward
	elif int(me["meter"]) >= 20 and distance < 360 and _random(100) < [12, 26, 40][difficulty]:
		result["attack"] = "special"
		result["move"] = -toward
	elif distance < 85 and int(me["meter"]) >= 20 and _random(100) < [10, 20, 30][difficulty]:
		result["attack"] = "throw"
	elif distance < 175:
		var attacks: Array = ["light", "low", "kick", "heavy"]
		var chosen: String = attacks[_random(attacks.size())]
		var ranged_move: String = "uppercut" if chosen == "heavy" and state == "crouch" else chosen
		var reach: int = int(int(ATTACK_RANGES[ranged_move]) * int(me.get("reach_percent", 100)) / 100)
		# Commit only inside the selected attack's reach: starting an attack
		# prevents walking, so repeated out-of-range jabs would never close.
		if distance > reach - 8:
			result["move"] = toward
		else:
			result["attack"] = chosen
			result["down"] = chosen == "low"
	else:
		result["move"] = toward
		if int(me["y"]) == 0 and not bool(me.get("prev_jump", false)) and distance > 250 and _random(100) < [8, 14, 20][difficulty]:
			result["jump"] = true
	# A second jump is a deliberate fresh press, with a small chance at each
	# normal reaction interval. Launches caused by an uppercut are ineligible.
	if ready and state == "jump" and int(me["y"]) > 0 and bool(me.get("normal_jump", false)) and not bool(me.get("double_jump_used", false)) and not bool(me.get("prev_jump", false)) and str(result["attack"]).is_empty():
		result["jump"] = _random(100) < [6, 10, 14][difficulty]
	intent = result.duplicate(true)
	intent["attack"] = ""
	intent["jump"] = false
	intent["tap"] = ""
	return result

func _follow_juggle(sim, index: int) -> Dictionary:
	var result: Dictionary = _neutral()
	var me: Dictionary = sim.fighters[index]
	var foe: Dictionary = sim.fighters[1 - index]
	if not juggle_active:
		juggle_active = true
		juggle_attempt = _random(100) < [25, 45, 65][difficulty]
		juggle_step = 0
	if not juggle_attempt:
		return result
	var confirmed: int = int(foe.juggle_hits)
	if confirmed != juggle_step:
		juggle_step = confirmed
		juggle_wait = [5, 3, 1][difficulty] + _random([4, 3, 3][difficulty])
		juggle_sent = false
	if int(sim.hitstop) > 0 or juggle_sent:
		return result
	juggle_wait -= 1
	var ready: bool = int(me.get("stun", 0)) <= 0 and (str(me.state) in ["idle", "walk", "crouch", "jump"] or bool(me.get("can_cancel", false)))
	if juggle_wait > 0 or not ready:
		return result
	juggle_sent = true
	var correct: bool = _random(100) < [65, 80, 92][difficulty]
	result.attack = ["low", "heavy", "kick"][confirmed - 1] if correct else "light"
	result.down = correct and confirmed in [1, 3]
	return result

func snapshot() -> Dictionary:
	return {"difficulty": difficulty, "rng_state": rng_state, "ticks": ticks,
		"think_in": think_in, "intent": intent.duplicate(true), "prompt_kind": prompt_kind,
		"prompt_button": prompt_button, "prompt_wait": prompt_wait,
		"prompt_answer": prompt_answer, "defend_special": defend_special,
		"grab_ticks": grab_ticks, "break_throw": break_throw,
		"last_cancel_start": last_cancel_start, "juggle_active": juggle_active,
		"juggle_attempt": juggle_attempt, "juggle_step": juggle_step,
		"juggle_wait": juggle_wait, "juggle_sent": juggle_sent}

func restore(saved: Dictionary) -> void:
	for key in saved:
		set(key, saved[key].duplicate(true) if saved[key] is Dictionary else saved[key])
