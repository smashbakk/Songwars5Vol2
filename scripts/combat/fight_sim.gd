# Property of LiveLayer Technology LLC.
# Integer-only 60 Hz simulation. Presentation never changes simulation state.
extends RefCounted

const Data = preload("res://scripts/combat/fighter_data.gd")
const MOVE_DATA = {
	"light": {"startup": 5, "active": 3, "recovery": 8, "hitstun": 12, "blockstun": 8, "hitstop": 2, "damage": 6, "range": 108},
	"low": {"startup": 6, "active": 3, "recovery": 10, "hitstun": 13, "blockstun": 9, "hitstop": 2, "damage": 8, "range": 115},
	"kick": {"startup": 8, "active": 4, "recovery": 12, "hitstun": 15, "blockstun": 10, "hitstop": 3, "damage": 10, "range": 140},
	"heavy": {"startup": 12, "active": 4, "recovery": 18, "hitstun": 18, "blockstun": 12, "hitstop": 5, "damage": 14, "range": 165},
	"uppercut": {"startup": 10, "active": 4, "recovery": 20, "hitstun": 20, "blockstun": 12, "hitstop": 5, "damage": 16, "range": 120}
}
const GRAB_RANGE = 100
const ROUND_FRAMES = 5940
const KNOCKDOWN_FRAMES = 48
const GETUP_FRAMES = 12
const JUMP_APEX = 110
const DOUBLE_JUMP_APEX = 160
var fighters: Array = []
var projectiles: Array = []
var events: Array = []
var frame: int = 0
var combat_frame: int = 0
var time_left: int = ROUND_FRAMES
var countdown: int = 180
var round_number: int = 1
var round_wins: Array = [0, 0]
var round_over: bool = false
var match_over: bool = false
var winner: int = -1
var round_wait: int = 0
var hitstop: int = 0
var training: bool = false
var rng_state: int = 1
var last_inputs: Array = [{}, {}]
var pending_contacts: Array = []

func setup(p1_id: String, p2_id: String, upgrades1: Dictionary = {}, upgrades2: Dictionary = {}, training_mode: bool = false, seed_value: int = 1) -> void:
	training = training_mode
	rng_state = maxi(1, seed_value & 0x7fffffff)
	fighters = [_make_fighter(p1_id, 0, upgrades1), _make_fighter(p2_id, 1, upgrades2)]
	frame = 0
	combat_frame = 0
	time_left = ROUND_FRAMES
	countdown = 180
	round_number = 1
	round_wins = [0, 0]
	round_over = false
	match_over = false
	winner = -1
	round_wait = 0
	hitstop = 0
	projectiles = []
	events = []
	last_inputs = [{}, {}]

func _make_fighter(id: String, index: int, upgrades: Dictionary) -> Dictionary:
	var f: Dictionary = Data.get_fighter(id)
	f["max_hp"] = mini(250, int(f.hp) + maxi(0, int(upgrades.get("hp", 0))) * 10)
	f["damage_rank"] = mini(2, ["Light", "Standard", "Power"].find(f.damage_class) + maxi(0, int(upgrades.get("damage", 0))))
	f["speed_rank"] = mini(2, ["Slow", "Standard", "Fast"].find(f.speed_class) + maxi(0, int(upgrades.get("speed", 0))))
	f["reach_percent"] = {"Short": 90, "Standard": 100, "Long": 110}[f.reach_class]
	f["index"] = index
	f["upgrades"] = upgrades.duplicate(true)
	_reset_fighter(f, index, 0)
	return f

func _reset_fighter(f: Dictionary, index: int, carry: int) -> void:
	f.merge({"hp": f.max_hp, "meter": mini(20, carry), "x": 390 if index == 0 else 890, "y": 0, "facing": 1 if index == 0 else -1,
		"state": "idle", "move": "", "attack_frame": 0, "timer": 0, "stun": 0, "connected": false, "can_cancel": false,
		"combo_hits": 0, "combo_damage": 0, "combo_timer": 0, "blocking": false, "down": false, "block_age": 999,
		"block_paid": false, "engagement": 0, "prev_move": 0, "prev_down": false, "prev_jump": false, "prev_block": false,
		"jump_frame": 0, "jump_origin": 0, "normal_jump": false, "double_jump_used": false,
		"walk_remainder": 0, "taps": [], "throw_ready": 0, "break_taps": [], "prompt": {}, "queued_attack": "",
		"attack_low": false, "contact_dog": false, "minor_low": false, "minor_hits": 0, "big_index": 0, "big_protected": false, "big_attempted": false,
		"big_holding": false, "big_owner": -1, "throw_target": -1, "throw_damage": 0,
		"dog_x": 340 if index == 0 else 940, "dog_cooldown": 100}, true)

func step(inputs: Array) -> void:
	events = []
	frame += 1
	last_inputs = [{}, {}]
	for i in range(2):
		if i < inputs.size() and inputs[i] is Dictionary:
			last_inputs[i] = inputs[i].duplicate(true)
	if match_over:
		return
	if countdown > 0:
		countdown -= 1
		if countdown == 0:
			events.append({"type": "fight"})
		return
	if round_over:
		round_wait -= 1
		if round_wait <= 0:
			next_round()
		return
	if hitstop > 0:
		hitstop -= 1
		for i in range(2):
			var pressed: String = str(last_inputs[i].get("attack", ""))
			if not pressed.is_empty():
				# Preserve a crouched heavy pressed during the freeze, even if Down
				# is released before the queued move can start.
				fighters[i].queued_attack = "uppercut" if pressed == "heavy" and (bool(last_inputs[i].get("down", false)) or str(fighters[i].state) == "crouch") else pressed
		return
	combat_frame += 1
	if not training:
		time_left = maxi(0, time_left - 1)
	for i in range(2):
		_update_input(i, last_inputs[i])
	pending_contacts = []
	for i in range(2):
		_tick_fighter(i)
	# Resolve contacts after both animations advance, so simultaneous strikes trade.
	for contact in pending_contacts:
		if contact.kind == "regular":
			_hit_regular(int(contact.owner), str(contact.move), false, bool(contact.dog))
		else:
			_minor_hit(int(contact.owner), int(contact.damage), int(contact.chip), bool(contact.final), bool(contact.dog))
	pending_contacts = []
	_update_projectiles()
	_update_dogs()
	_update_facing_and_collision()
	_check_round_end()

func _update_input(i: int, input: Dictionary) -> void:
	var f: Dictionary = fighters[i]
	var move_axis: int = clampi(int(input.get("move", 0)), -1, 1)
	var down: bool = bool(input.get("down", false))
	var jump: bool = bool(input.get("jump", false))
	var block: bool = bool(input.get("block", false)) or move_axis == -int(f.facing)
	var block_edge: bool = block and not bool(f.prev_block)
	f.blocking = block and int(f.y) == 0 and _can_guard(f)
	f.down = down
	if block_edge:
		f.block_age = 0
	f.prev_block = block
	var explicit_tap: String = str(input.get("tap", ""))
	if not explicit_tap.is_empty():
		_record_tap(i, explicit_tap)
	else:
		if move_axis != 0 and move_axis != int(f.prev_move):
			_record_tap(i, "forward" if move_axis == int(f.facing) else "back")
		if down and not bool(f.prev_down):
			_record_tap(i, "down")
	f.prev_move = move_axis
	f.prev_down = down
	if int(f.big_owner) >= 0:
		if bool(f.big_protected) and not block:
			f.big_protected = false
		if f.prompt.get("kind", "") == "block" and block_edge and not bool(f.big_attempted) and int(f.y) == 0:
			f.big_attempted = true
			f.big_protected = true
			f.big_holding = true
			events.append({"type": "big_guard", "target": i})
	var attack: String = str(input.get("attack", ""))
	if attack.is_empty() and not str(f.queued_attack).is_empty():
		attack = str(f.queued_attack)
	f.queued_attack = ""
	if f.prompt.get("kind", "") in ["minor", "big"] and attack == str(f.prompt.get("button", "")):
		var kind: String = str(f.prompt.kind)
		f.prompt = {}
		if _can_act(f):
			if kind == "big":
				_start_big(i)
			else:
				_start_minor(i)
		attack = ""
	# A second jump changes the arc without cancelling an airborne punch/kick.
	if jump and not bool(f.prev_jump) and int(f.y) > 0 and bool(f.normal_jump) and not bool(f.double_jump_used) and int(f.stun) <= 0 and (str(f.state) == "jump" or (str(f.state) == "attack" and MOVE_DATA.has(str(f.move)))):
		f.jump_origin = int(f.y)
		f.jump_frame = 1
		f.double_jump_used = true
	if _can_act(f):
		if attack == "special":
			_offer_special(i, "minor" if move_axis == -int(f.facing) or int(f.meter) < 60 else "big")
		elif attack == "throw" or (attack in ["light", "low"] and int(f.throw_ready) > 0):
			_start_throw(i)
		elif MOVE_DATA.has(attack):
			_start_regular(i, attack)
		elif jump and not bool(f.prev_jump) and int(f.y) == 0:
			f.jump_frame = 1
			f.jump_origin = 0
			f.normal_jump = true
			f.double_jump_used = false
			f.state = "jump"
		elif int(f.y) == 0 and str(f.state) in ["idle", "walk", "crouch"]:
			f.state = "crouch" if down else ("walk" if move_axis != 0 else "idle")
		if str(f.state) in ["idle", "walk", "jump"] and not down:
			_walk(f, move_axis)
	elif int(f.y) > 0 and str(f.state) not in ["big_capture", "grabbed"]:
		_walk(f, move_axis)
	f.prev_jump = jump

func _walk(f: Dictionary, direction: int) -> void:
	var speed: int = [36, 40, 44][int(f.speed_rank)]
	f.walk_remainder = int(f.walk_remainder) + direction * speed
	var distance: int = int(int(f.walk_remainder) / 10)
	f.walk_remainder = int(f.walk_remainder) - distance * 10
	f.x = clampi(int(f.x) + distance, 65, 1215)

func _record_tap(i: int, direction: String) -> void:
	var f: Dictionary = fighters[i]
	if str(f.state) == "grabbed":
		f.break_taps.append(direction)
		if f.break_taps.size() > 3:
			f.break_taps.pop_front()
		if f.break_taps == ["back", "back", "down"]:
			_break_throw(i)
		return
	f.taps.append({"direction": direction, "frame": combat_frame})
	while f.taps.size() > 4:
		f.taps.pop_front()
	if f.taps.size() < 2 or not _can_act(f):
		return
	var a: Dictionary = f.taps[f.taps.size() - 2]
	var b: Dictionary = f.taps.back()
	if int(b.frame) - int(a.frame) > 24:
		return
	if a.direction == "back" and b.direction == "forward":
		f.throw_ready = 20
	elif a.direction == "back" and b.direction == "back":
		_offer_special(i, "minor")
	elif a.direction == "forward" and b.direction == "forward":
		_offer_special(i, "big")

func _offer_special(i: int, kind: String) -> void:
	var f: Dictionary = fighters[i]
	if not f.prompt.is_empty() or not _can_act(f):
		return
	if int(f.meter) < (60 if kind == "big" else 20):
		return
	if kind == "big" and _protected(fighters[1 - i]):
		return
	var buttons: Array = ["light", "kick"]
	f.prompt = {"kind": kind, "button": buttons[_rand() % buttons.size()], "remaining": 120}
	events.append({"type": "special_prompt", "attacker": i, "kind": kind})

func _can_act(f: Dictionary) -> bool:
	return int(f.stun) <= 0 and (str(f.state) in ["idle", "walk", "crouch", "jump"] or (str(f.state) == "attack" and bool(f.can_cancel)))

func _can_guard(f: Dictionary) -> bool:
	return str(f.state) in ["idle", "walk", "crouch", "hurt", "blockstun", "big_capture"] and (int(f.stun) <= 0 or str(f.state) in ["blockstun", "big_capture"])

func _protected(f: Dictionary) -> bool:
	return str(f.state) in ["down", "getup"] or int(f.hp) <= 0

func _start_regular(i: int, move_name: String) -> void:
	var f: Dictionary = fighters[i]
	if move_name == "heavy" and (bool(f.down) or str(f.state) == "crouch"):
		move_name = "uppercut"
	f.state = "attack"
	f.move = move_name
	f.attack_frame = 0
	f.connected = false
	f.can_cancel = false
	f.blocking = false
	f.attack_low = move_name == "low"
	events.append({"type": "attack", "attacker": i, "move": move_name})

func _start_throw(i: int) -> void:
	var f: Dictionary = fighters[i]
	if int(f.meter) < 20 or int(f.y) > 0:
		return
	_start_regular(i, "throw")
	f.throw_ready = 0

func _start_minor(i: int) -> void:
	var f: Dictionary = fighters[i]
	if int(f.meter) < 20:
		return
	_start_regular(i, "minor")
	f.meter = int(f.meter) - 20
	f.minor_low = bool(f.down)
	f.minor_hits = 0
	events.append({"type": "minor", "attacker": i, "mold": f.minor})

func _start_big(i: int) -> void:
	var f: Dictionary = fighters[i]
	var target: Dictionary = fighters[1 - i]
	if int(f.meter) < 60 or _protected(target):
		return
	f.meter = int(f.meter) - 60
	f.state = "big_start"
	f.move = "big"
	f.attack_frame = 0
	f.can_cancel = false
	f.blocking = false
	# Health/damage units doubled; each old five-point cue step is now ten.
	var reduction: int = mini(5, int(int(f.combo_damage) / 10)) * 6
	f.timer = 60 - reduction
	# Capture preserves the manual combo through the cue and every special hit.
	f.combo_timer = int(f.timer) + f.big_hits.size() * 17 + 10
	target.big_owner = i
	target.big_attempted = false
	target.big_protected = false
	target.big_holding = false
	if int(target.y) == 0:
		target.prompt = {"kind": "block", "button": "block", "remaining": f.timer}
	events.append({"type": "big_start", "attacker": i, "target": 1 - i, "name": f.big_name, "window": f.timer})

func _tick_fighter(i: int) -> void:
	var f: Dictionary = fighters[i]
	f.block_age = int(f.block_age) + 1
	f.throw_ready = maxi(0, int(f.throw_ready) - 1)
	if int(f.engagement) > 0:
		f.engagement = int(f.engagement) - 1
	elif int(f.stun) <= 0:
		f.block_paid = false
	if int(f.combo_timer) > 0:
		f.combo_timer = int(f.combo_timer) - 1
	else:
		f.combo_hits = 0
		f.combo_damage = 0
	if not f.prompt.is_empty() and f.prompt.get("kind", "") != "block":
		f.prompt.remaining = int(f.prompt.remaining) - 1
		if int(f.prompt.remaining) <= 0:
			if f.prompt.kind == "big":
				f.meter = mini(int(f.meter), 40)
			f.prompt = {}
	if int(f.jump_frame) > 0 and str(f.state) not in ["big_capture", "grabbed"]:
		var arc_frame: int = int(f.jump_frame)
		if bool(f.normal_jump) and bool(f.double_jump_used):
			# Continue the parabola below its takeoff height until landing. Its
			# peak is always 160, including an early or late second press.
			f.y = maxi(0, int(f.jump_origin) + int((DOUBLE_JUMP_APEX - int(f.jump_origin)) * arc_frame * (42 - arc_frame) / 441))
		else:
			f.y = maxi(0, int(arc_frame * (42 - arc_frame) / 4))
		f.jump_frame = int(f.jump_frame) + 1
		if int(f.y) == 0:
			f.y = 0
			f.jump_frame = 0
			f.jump_origin = 0
			f.normal_jump = false
			f.double_jump_used = false
			if str(f.state) == "jump":
				f.state = "landing"
				f.timer = 4
	if int(f.stun) > 0:
		f.stun = int(f.stun) - 1
		if int(f.stun) == 0 and str(f.state) in ["hurt", "blockstun"]:
			f.state = "jump" if int(f.y) > 0 else "idle"
		return
	match str(f.state):
		"attack":
			_tick_attack(i)
		"landing":
			f.timer = int(f.timer) - 1
			if int(f.timer) <= 0:
				f.state = "idle"
		"down":
			f.timer = int(f.timer) - 1
			if int(f.timer) <= 0:
				f.state = "getup"
				f.timer = GETUP_FRAMES
		"getup":
			f.timer = int(f.timer) - 1
			if int(f.timer) <= 0:
				f.state = "idle"
		"throw_hold":
			_tick_throw_hold(i)
		"big_start":
			_tick_big_start(i)
		"big":
			_tick_big(i)
		"recovery":
			f.timer = int(f.timer) - 1
			if int(f.timer) <= 0:
				f.state = "idle"

func _tick_attack(i: int) -> void:
	var f: Dictionary = fighters[i]
	f.attack_frame = int(f.attack_frame) + 1
	var age: int = int(f.attack_frame)
	var move_name: String = str(f.move)
	if MOVE_DATA.has(move_name):
		var data: Dictionary = MOVE_DATA[move_name]
		if age >= int(data.startup) and age < int(data.startup) + int(data.active) and not bool(f.connected):
			var reach: int = int(int(data.range) * int(f.reach_percent) / 100)
			if _in_attack_range(i, reach, bool(f.attack_low), move_name == "uppercut"):
				f.connected = true
				f.can_cancel = true
				pending_contacts.append({"kind": "regular", "owner": i, "move": move_name, "dog": f.contact_dog})
		if age >= int(data.startup) + int(data.active) + int(data.recovery):
			f.state = "jump" if int(f.y) > 0 else "idle"
			f.move = ""
	elif move_name == "throw":
		if age >= 6 and age < 9 and not bool(f.connected):
			var target: Dictionary = fighters[1 - i]
			if not _protected(target) and int(target.y) == 0 and str(target.state) not in ["big", "big_start", "big_capture", "grabbed", "throw_hold"] and absi(int(f.x) - int(target.x)) <= GRAB_RANGE:
				f.connected = true
				f.state = "throw_hold"
				f.timer = 36
				f.throw_target = 1 - i
				f.throw_damage = [0, 16, 22, 30][mini(3, int(int(f.meter) / 20))]
				f.combo_timer = 40
				target.state = "grabbed"
				target.stun = 0
				target.break_taps = []
				target.prompt = {"kind": "throw_break", "button": "back → back → down", "remaining": 36}
				events.append({"type": "grab", "attacker": i, "target": 1 - i})
		if age >= 48 and str(f.state) == "attack":
			f.state = "idle"
			f.move = ""
	elif move_name == "minor":
		_tick_minor(i)

func _in_attack_range(i: int, reach: int, low: bool, rising: bool = false) -> bool:
	var f: Dictionary = fighters[i]
	var target: Dictionary = fighters[1 - i]
	if _protected(target) or str(target.state) in ["big_capture", "grabbed"]:
		return false
	if low and int(target.y) > 25:
		return false
	var vertical_ok: bool = absi(int(f.y) - int(target.y)) <= 85
	if rising:
		vertical_ok = int(target.y) >= int(f.y) - 85 and int(target.y) <= int(f.y) + 180
	var behind_allowance: int = 0 if rising else -35
	var body: bool = vertical_ok and absi(int(f.x) - int(target.x)) <= reach and (int(target.x) - int(f.x)) * int(f.facing) >= behind_allowance
	var dog: bool = str(target.id) == "cin" and int(f.y) < 65 and absi(int(f.x) - int(target.dog_x)) <= reach and (int(target.dog_x) - int(f.x)) * int(f.facing) >= behind_allowance
	f.contact_dog = dog
	return body or dog

func _guard_matches(target: Dictionary, low: bool) -> bool:
	return bool(target.blocking) and int(target.y) == 0 and bool(target.down) == low

func _hit_regular(i: int, move_name: String, dog: bool, target_dog: bool = false) -> void:
	var f: Dictionary = fighters[i]
	var target: Dictionary = fighters[1 - i]
	if _protected(target):
		return
	var data: Dictionary = MOVE_DATA[move_name]
	var damage: int = 6 if dog else int(data.damage) + (int(f.damage_rank) - 1) * 2
	var low: bool = dog or bool(f.attack_low)
	var blocked: bool = _guard_matches(target, low) and not target_dog
	if blocked:
		var timed: bool = int(target.block_age) <= 15
		var chip: int = 0 if timed else (4 if move_name in ["heavy", "uppercut"] else 2)
		if timed and not bool(target.block_paid):
			target.meter = mini(60, int(target.meter) + 10)
			target.block_paid = true
			events.append({"type": "timed_block", "target": 1 - i})
		target.engagement = 45
		_damage(i, chip, "block", true)
		_stagger(1 - i, int(data.blockstun), true)
		f.combo_hits = 0
		f.combo_damage = 0
		f.combo_timer = 0
	else:
		_damage(i, damage, "dog" if dog else "hit", false)
		f.meter = mini(60, int(f.meter) + (2 if dog else 4))
		f.combo_hits = int(f.combo_hits) + 1
		f.combo_damage = int(f.combo_damage) + damage
		f.combo_timer = int(data.hitstun) + 3
		_stagger(1 - i, int(data.hitstun), false)
		if move_name == "uppercut" and not dog:
			_launch_uppercut(1 - i)
		if int(f.combo_hits) >= 5:
			_knockdown(1 - i)
			f.combo_timer = 0
	hitstop = maxi(hitstop, int(data.hitstop))

func _launch_uppercut(index: int) -> void:
	var target: Dictionary = fighters[index]
	if str(target.state) in ["big", "big_start", "big_capture"]:
		return
	# Rejoin the rising half of the normal arc. Even a double-jumping target
	# above it is capped at the normal apex, and a launch cannot double jump.
	var height: int = mini(JUMP_APEX, int(target.y))
	var launch_frame: int = 1
	while launch_frame < 21 and int(launch_frame * (42 - launch_frame) / 4) < height:
		launch_frame += 1
	target.y = int(launch_frame * (42 - launch_frame) / 4)
	target.jump_frame = launch_frame
	target.jump_origin = 0
	target.normal_jump = false
	target.double_jump_used = false

func _damage(i: int, damage: int, kind: String, blocked: bool, minimum_hp: int = 0) -> void:
	var target: Dictionary = fighters[1 - i]
	if _protected(target) and kind != "big":
		return
	var actual: int = mini(damage, maxi(0, int(target.hp) - minimum_hp))
	target.hp = maxi(minimum_hp, int(target.hp) - damage)
	events.append({"type": kind, "attacker": i, "target": 1 - i, "damage": actual, "blocked": blocked, "x": target.x, "y": target.y})

func _stagger(index: int, duration: int, blocked: bool) -> void:
	var target: Dictionary = fighters[index]
	if str(target.state) in ["big", "big_start", "big_capture"]:
		return
	if str(target.state) == "throw_hold":
		_release_throw(index)
	target.state = "blockstun" if blocked else "hurt"
	target.stun = duration
	target.move = ""
	target.can_cancel = false

func _knockdown(index: int) -> void:
	var f: Dictionary = fighters[index]
	if str(f.state) in ["big_start", "big"]:
		return
	f.state = "down"
	f.timer = KNOCKDOWN_FRAMES
	f.stun = 0
	f.y = 0
	f.jump_frame = 0
	f.jump_origin = 0
	f.normal_jump = false
	f.double_jump_used = false
	f.move = ""
	f.blocking = false
	f.can_cancel = false
	f.prompt = {}
	events.append({"type": "knockdown", "target": index})

func _tick_minor(i: int) -> void:
	var f: Dictionary = fighters[i]
	var age: int = int(f.attack_frame)
	if str(f.minor) == "projectile":
		if age == 12:
			projectiles.append({"x": int(f.x) + int(f.facing) * 60, "y": 55 if not bool(f.minor_low) else 20, "owner": i, "direction": f.facing, "life": 100, "low": f.minor_low})
		if age >= 28:
			f.state = "idle"
			f.move = ""
	elif str(f.minor) == "lunge":
		if age >= 9 and age <= 27:
			f.x = clampi(int(f.x) + int(f.facing) * 13, 65, 1215)
			if not bool(f.connected) and _in_attack_range(i, 120, bool(f.minor_low)):
				f.connected = true
				pending_contacts.append({"kind": "minor", "owner": i, "damage": 22, "chip": 4, "final": true, "dog": f.contact_dog})
		if age >= 43:
			f.state = "idle"
			f.move = ""
	else:
		if age in [10, 18] and _in_attack_range(i, 160, bool(f.minor_low)):
			pending_contacts.append({"kind": "minor", "owner": i, "damage": 10, "chip": 2, "final": age == 18, "dog": f.contact_dog})
		if age >= 34:
			f.state = "idle"
			f.move = ""

func _minor_hit(i: int, damage: int, chip: int, final_hit: bool, target_dog: bool = false) -> void:
	var f: Dictionary = fighters[i]
	var target: Dictionary = fighters[1 - i]
	if _protected(target):
		return
	var blocked: bool = _guard_matches(target, bool(f.minor_low)) and not target_dog
	_damage(i, chip if blocked else damage, "minor_hit", blocked)
	_stagger(1 - i, 10 if blocked else 14, blocked)
	if not blocked:
		f.combo_hits = int(f.combo_hits) + 1
		f.combo_damage = int(f.combo_damage) + damage
		f.combo_timer = 20
	if final_hit and not blocked:
		_knockdown(1 - i)
		f.combo_timer = 0
	hitstop = maxi(hitstop, 3)

func _update_projectiles() -> void:
	for n in range(projectiles.size() - 1, -1, -1):
		var p: Dictionary = projectiles[n]
		p.x = int(p.x) + int(p.direction) * 15
		p.life = int(p.life) - 1
		var target: Dictionary = fighters[1 - int(p.owner)]
		var body: bool = absi(int(p.x) - int(target.x)) <= 50 and absi(int(target.y) - int(p.y)) < 90
		var dog: bool = str(target.id) == "cin" and absi(int(p.x) - int(target.dog_x)) <= 42
		if (body or dog) and not _protected(target) and str(target.state) not in ["grabbed", "big_capture"]:
			# Attack height is stored with the projectile, independent of owner's next input.
			var blocked: bool = _guard_matches(target, bool(p.low)) and not dog
			_damage(int(p.owner), 4 if blocked else 22, "minor_hit", blocked)
			_stagger(1 - int(p.owner), 10 if blocked else 14, blocked)
			if not blocked:
				fighters[int(p.owner)].combo_hits = int(fighters[int(p.owner)].combo_hits) + 1
				fighters[int(p.owner)].combo_damage = int(fighters[int(p.owner)].combo_damage) + 22
				_knockdown(1 - int(p.owner))
			hitstop = maxi(hitstop, 3)
			projectiles.remove_at(n)
		elif int(p.life) <= 0 or int(p.x) < 0 or int(p.x) > 1280:
			projectiles.remove_at(n)

func _tick_throw_hold(i: int) -> void:
	var f: Dictionary = fighters[i]
	var target: Dictionary = fighters[1 - i]
	if str(target.state) != "grabbed":
		f.state = "idle"
		return
	f.timer = int(f.timer) - 1
	target.prompt.remaining = f.timer
	if int(f.timer) <= 0:
		_damage(i, int(f.throw_damage), "throw", false)
		f.combo_hits = int(f.combo_hits) + 1
		f.combo_damage = int(f.combo_damage) + int(f.throw_damage)
		f.combo_timer = 0
		_knockdown(1 - i)
		f.state = "recovery"
		f.timer = 12
		f.move = ""

func _break_throw(index: int) -> void:
	var attacker: Dictionary = fighters[1 - index]
	var target: Dictionary = fighters[index]
	if str(attacker.state) != "throw_hold":
		return
	attacker.state = "idle"
	attacker.move = ""
	attacker.can_cancel = false
	attacker.combo_timer = 0
	target.state = "idle"
	target.prompt = {}
	target.break_taps = []
	attacker.x = clampi(int(attacker.x) - int(attacker.facing) * 55, 65, 1215)
	target.x = clampi(int(target.x) + int(attacker.facing) * 55, 65, 1215)
	events.append({"type": "throw_break", "target": index})

func _release_throw(index: int) -> void:
	var target: Dictionary = fighters[1 - index]
	if str(target.state) == "grabbed":
		target.state = "idle"
		target.prompt = {}
		events.append({"type": "throw_interrupt", "target": 1 - index})

func _tick_big_start(i: int) -> void:
	var f: Dictionary = fighters[i]
	var target: Dictionary = fighters[1 - i]
	f.attack_frame = int(f.attack_frame) + 1
	f.timer = int(f.timer) - 1
	if target.prompt.get("kind", "") == "block":
		target.prompt.remaining = f.timer
	if int(f.timer) > 0:
		return
	target.prompt = {}
	if int(target.y) > 0:
		f.meter = mini(60, int(f.meter) + 40)
		f.state = "recovery"
		f.timer = 90
		target.big_owner = -1
		target.big_protected = false
		events.append({"type": "big_whiff", "attacker": i})
		return
	f.state = "big"
	f.attack_frame = 0
	f.big_index = 0
	target.state = "big_capture"
	target.stun = 0
	target.move = ""
	target.y = 0
	target.jump_frame = 0
	target.jump_origin = 0
	target.normal_jump = false
	target.double_jump_used = false
	events.append({"type": "big_capture", "attacker": i, "target": 1 - i})

func _tick_big(i: int) -> void:
	var f: Dictionary = fighters[i]
	var target: Dictionary = fighters[1 - i]
	f.attack_frame = int(f.attack_frame) + 1
	if int(f.attack_frame) % 14 != 6:
		return
	var hit_index: int = int(f.big_index)
	var hits: Array = f.big_hits
	if hit_index >= hits.size():
		return
	var guarded: bool = bool(target.big_protected) and bool(target.prev_block)
	var damage: int = int(int(hits[hit_index]) / 2) if guarded else int(hits[hit_index])
	_damage(i, damage, "big", guarded, 1 if guarded else 0)
	f.combo_hits = int(f.combo_hits) + 1
	f.combo_damage = int(f.combo_damage) + damage
	f.combo_timer = 120
	f.big_index = hit_index + 1
	hitstop = 3
	if int(f.big_index) >= hits.size():
		target.big_owner = -1
		target.big_protected = false
		target.big_holding = false
		_knockdown(1 - i)
		f.state = "recovery"
		f.timer = 20
		f.combo_timer = 0

func _update_dogs() -> void:
	for i in range(2):
		var f: Dictionary = fighters[i]
		if str(f.id) != "cin":
			continue
		var target: Dictionary = fighters[1 - i]
		var desired: int = int(target.x) - int(f.facing) * 60
		f.dog_x = clampi(int(f.dog_x) + clampi(desired - int(f.dog_x), -5, 5), 45, 1235)
		f.dog_cooldown = int(f.dog_cooldown) - 1
		if int(f.dog_cooldown) <= 0:
			f.dog_cooldown = 100
			if not _protected(target) and str(target.state) not in ["big_capture", "grabbed"] and int(target.y) < 40 and absi(int(f.dog_x) - int(target.x)) <= 95:
				_hit_regular(i, "light", true)

func _update_facing_and_collision() -> void:
	var a: Dictionary = fighters[0]
	var b: Dictionary = fighters[1]
	if int(a.x) != int(b.x):
		for i in range(2):
			var f: Dictionary = fighters[i]
			if str(f.state) in ["idle", "walk", "crouch", "jump", "hurt", "blockstun"]:
				f.facing = 1 if int(fighters[1 - i].x) > int(f.x) else -1
	if absi(int(a.x) - int(b.x)) < 70 and absi(int(a.y) - int(b.y)) < 90 and str(a.state) != "big_capture" and str(b.state) != "big_capture":
		var push: int = int((70 - absi(int(a.x) - int(b.x))) / 2)
		var dir: int = 1 if int(a.x) <= int(b.x) else -1
		a.x = clampi(int(a.x) - push * dir, 65, 1215)
		b.x = clampi(int(b.x) + push * dir, 65, 1215)

func _check_round_end() -> void:
	if training:
		for i in range(2):
			if int(fighters[i].hp) <= 0:
				fighters[i].hp = fighters[i].max_hp
				_knockdown(i)
		return
	# A captured sequence resolves every hit even if a partner hit causes a KO.
	for f in fighters:
		if str(f.state) in ["big_start", "big"]:
			return
	if int(fighters[0].hp) > 0 and int(fighters[1].hp) > 0 and time_left > 0:
		return
	winner = 2
	if int(fighters[0].hp) > int(fighters[1].hp):
		winner = 0
	elif int(fighters[1].hp) > int(fighters[0].hp):
		winner = 1
	if winner < 2:
		round_wins[winner] = int(round_wins[winner]) + 1
	round_over = true
	round_wait = 150
	match_over = int(round_wins[0]) >= 2 or int(round_wins[1]) >= 2
	projectiles = []
	events.append({"type": "match_end" if match_over else "round_end", "winner": winner, "round": round_number})

func next_round() -> void:
	if match_over:
		return
	for i in range(2):
		var carry: int = mini(20, int(fighters[i].meter))
		_reset_fighter(fighters[i], i, carry)
	projectiles = []
	round_over = false
	winner = -1
	round_wait = 0
	round_number += 1
	time_left = ROUND_FRAMES
	countdown = 180
	hitstop = 0
	events.append({"type": "next_round", "round": round_number})

func reset_training() -> void:
	for i in range(2):
		_reset_fighter(fighters[i], i, 0)
	projectiles = []
	time_left = ROUND_FRAMES
	countdown = 0
	hitstop = 0
	events = []

func _rand() -> int:
	rng_state = (rng_state * 1103515245 + 12345) & 0x7fffffff
	return rng_state

func snapshot() -> Dictionary:
	return {"fighters": fighters.duplicate(true), "projectiles": projectiles.duplicate(true), "frame": frame, "combat_frame": combat_frame,
		"time_left": time_left, "countdown": countdown, "round_number": round_number, "round_wins": round_wins.duplicate(), "round_over": round_over,
		"match_over": match_over, "winner": winner, "round_wait": round_wait, "hitstop": hitstop, "training": training, "rng_state": rng_state,
		"last_inputs": last_inputs.duplicate(true), "events": events.duplicate(true)}

func restore(data: Dictionary) -> void:
	fighters = data.fighters.duplicate(true)
	for fighter in fighters:
		fighter.merge({"jump_origin": 0, "normal_jump": int(fighter.jump_frame) > 0, "double_jump_used": false})
	projectiles = data.projectiles.duplicate(true)
	frame = int(data.frame)
	combat_frame = int(data.combat_frame)
	time_left = int(data.time_left)
	countdown = int(data.countdown)
	round_number = int(data.round_number)
	round_wins = data.round_wins.duplicate()
	round_over = bool(data.round_over)
	match_over = bool(data.match_over)
	winner = int(data.winner)
	round_wait = int(data.round_wait)
	hitstop = int(data.hitstop)
	training = bool(data.training)
	rng_state = int(data.rng_state)
	last_inputs = data.last_inputs.duplicate(true)
	events = data.events.duplicate(true)
