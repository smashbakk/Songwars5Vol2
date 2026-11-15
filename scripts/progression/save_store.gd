extends RefCounted
## Property of LiveLayer Technology LLC.
## Local-only PASS 1 progression. Fixed UTC 00:00/12:00 reset buckets are a
## device-clock substitute for the future authoritative server reset periods.

const VERSION := 1
const FIGHTERS := ["cin", "rico", "hood", "bank"]
const BASE := {
	"cin": {"hp": 100, "damage": 1, "speed": 2},
	"rico": {"hp": 100, "damage": 1, "speed": 1},
	"hood": {"hp": 105, "damage": 2, "speed": 0},
	"bank": {"hp": 100, "damage": 1, "speed": 1},
}
const DAMAGE_NAMES := ["Light", "Standard", "Power"]
const SPEED_NAMES := ["Slow", "Standard", "Fast"]
const OPPONENTS := ["bank", "rico", "hood"]

var data: Dictionary = fresh_data()
var save_path := "user://songwars_save.json"
var last_error := ""

static func fresh_data() -> Dictionary:
	var result := {
		"version": VERSION,
		"settings": {"layout": "", "subtitles": true, "muted": false,
			"portrait_fights": false, "tester_bypass": false},
		"fighters": {},
		"story": {"current": 0, "seen": {}, "unlocked_chapters": [],
			"attempts": {}, "completed": {}},
	}
	for id in FIGHTERS:
		result.fighters[id] = {"points": 0, "upgrades": {"hp": 0, "damage": 0, "speed": 0}}
	return result

func load_save(path: String = "user://songwars_save.json") -> bool:
	save_path = path
	data = fresh_data()
	last_error = ""
	var parsed = _read_valid(path)
	if parsed == null:
		parsed = _read_valid(path + ".bak")
		if parsed == null:
			if FileAccess.file_exists(path):
				last_error = "Save could not be read; fresh local progress is available."
			return false
		last_error = "Recovered local progress from backup."
	data = _sanitize(parsed)
	return true

func _read_valid(path: String):
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		return null
	var parsed = parser.data
	if not parsed is Dictionary:
		return null
	var version = parsed.get("version", -1)
	if (not version is int and not version is float) or not is_finite(float(version)) or int(version) != VERSION:
		return null
	if not parsed.get("settings") is Dictionary or not parsed.get("fighters") is Dictionary or not parsed.get("story") is Dictionary:
		return null
	return parsed

func _sanitize(raw: Dictionary) -> Dictionary:
	var clean := fresh_data()
	var settings: Dictionary = raw.settings
	var layout := str(settings.get("layout", ""))
	if layout in ["", "simplified", "traditional"]:
		clean.settings.layout = layout
	for key in ["subtitles", "muted", "portrait_fights", "tester_bypass"]:
		if settings.get(key) is bool:
			clean.settings[key] = settings[key]
	for id in FIGHTERS:
		var entry = raw.fighters.get(id, {})
		if not entry is Dictionary:
			continue
		clean.fighters[id].points = _safe_int(entry.get("points", 0), 0, 1000000)
		var upgrades = entry.get("upgrades", {})
		if upgrades is Dictionary:
			clean.fighters[id].upgrades.hp = _safe_int(upgrades.get("hp", 0), 0, (125 - int(BASE[id].hp)) / 5)
			clean.fighters[id].upgrades.damage = _safe_int(upgrades.get("damage", 0), 0, 2 - int(BASE[id].damage))
			clean.fighters[id].upgrades.speed = _safe_int(upgrades.get("speed", 0), 0, 2 - int(BASE[id].speed))
	var story: Dictionary = raw.story
	clean.story.current = _safe_int(story.get("current", 0), 0, 3)
	for key in ["seen", "completed"]:
		if story.get(key) is Dictionary:
			for entry in story[key]:
				if entry is String and story[key][entry] is bool:
					clean.story[key][entry] = story[key][entry]
	if story.get("unlocked_chapters") is Array:
		for id in story.unlocked_chapters:
			if id in OPPONENTS and not id in clean.story.unlocked_chapters:
				clean.story.unlocked_chapters.append(id)
	if story.get("attempts") is Dictionary:
		for key in story.attempts:
			var entry = story.attempts[key]
			if key is String and entry is Dictionary:
				clean.story.attempts[key] = {"period": _safe_int(entry.get("period", 0), 0, 1000000000), "used": _safe_int(entry.get("used", 0), 0, 3)}
	return clean

func _safe_int(value, minimum: int, maximum: int) -> int:
	if not value is int and not value is float:
		return minimum
	if not is_finite(float(value)):
		return minimum
	return clampi(int(value), minimum, maximum)

func save() -> bool:
	last_error = ""
	var directory := ProjectSettings.globalize_path(save_path.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		last_error = "Cannot create the local save folder."
		return false
	var temporary := save_path + ".tmp"
	var backup := save_path + ".bak"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_error = "Cannot write local progress."
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		last_error = "Local progress write failed."
		return false
	# Keep only a valid previous generation. A damaged primary never replaces a
	# good backup; this makes recovery survive an interrupted first recovery save.
	if FileAccess.file_exists(save_path):
		if _read_valid(save_path) != null:
			if FileAccess.file_exists(backup):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(backup))
			if DirAccess.rename_absolute(ProjectSettings.globalize_path(save_path), ProjectSettings.globalize_path(backup)) != OK:
				last_error = "Cannot rotate the local save backup."
				return false
		else:
			var damaged := save_path + ".corrupt"
			if FileAccess.file_exists(damaged):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(damaged))
			if DirAccess.rename_absolute(ProjectSettings.globalize_path(save_path), ProjectSettings.globalize_path(damaged)) != OK:
				last_error = "Cannot preserve the damaged local save."
				return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(save_path)) != OK:
		last_error = "Cannot finalize local progress; previous backup remains."
		return false
	return true

func set_setting(key: String, value) -> bool:
	if not data.settings.has(key):
		return false
	if key == "layout":
		if not value in ["simplified", "traditional"]:
			return false
	elif not value is bool:
		return false
	var previous = data.settings[key]
	data.settings[key] = value
	if not save():
		data.settings[key] = previous
		return false
	return true

func get_points(id: String) -> int:
	if not data.fighters.has(id):
		return 0
	return int(data.fighters[id].points)

func get_upgrades(id: String) -> Dictionary:
	if not data.fighters.has(id):
		return {"hp": 0, "damage": 0, "speed": 0}
	return data.fighters[id].upgrades.duplicate(true)

func quote_upgrade(id: String, stat: String) -> Dictionary:
	var quote := {"allowed": false, "cost": 0, "before": "", "after": "", "reason": "Unknown upgrade."}
	if not id in FIGHTERS or not stat in ["hp", "damage", "speed"]:
		return quote
	var steps := int(data.fighters[id].upgrades[stat])
	var current := int(BASE[id][stat]) + steps * (5 if stat == "hp" else 1)
	var ceiling := 125 if stat == "hp" else 2
	quote.cost = 1 if stat == "hp" else 3
	if stat == "hp":
		quote.before = "%d HP" % current
		quote.after = "%d HP" % mini(current + 5, 125)
	else:
		var labels: Array = DAMAGE_NAMES if stat == "damage" else SPEED_NAMES
		quote.before = labels[current]
		quote.after = labels[mini(current + 1, 2)]
	if current >= ceiling:
		quote.reason = "Maximum reached."
	elif get_points(id) < quote.cost:
		quote.reason = "Needs %d fighter-specific points." % quote.cost
	else:
		quote.allowed = true
		quote.reason = "Spend %d point%s: %s → %s." % [quote.cost, "" if quote.cost == 1 else "s", quote.before, quote.after]
	return quote

func purchase_upgrade(id: String, stat: String) -> bool:
	var quote := quote_upgrade(id, stat)
	if not quote.allowed:
		return false
	var previous: Dictionary = data.duplicate(true)
	data.fighters[id].points -= quote.cost
	data.fighters[id].upgrades[stat] += 1
	if not save():
		data = previous
		return false
	return true

func _period(now: int) -> int:
	var timestamp := int(Time.get_unix_time_from_system()) if now < 0 else now
	return int(floor(float(timestamp) / 43200.0))

func attempts_remaining(match_id: String, now: int = -1) -> int:
	if data.settings.tester_bypass:
		return 3
	var entry: Dictionary = data.story.attempts.get(match_id, {})
	if int(entry.get("period", -1)) != _period(now):
		return 3
	return maxi(0, 3 - int(entry.get("used", 0)))

func begin_attempt(match_id: String, now: int = -1) -> bool:
	if attempts_remaining(match_id, now) <= 0:
		return false
	if data.settings.tester_bypass:
		return true
	var previous: Dictionary = data.duplicate(true)
	var entry: Dictionary = data.story.attempts.get(match_id, {})
	var used := int(entry.get("used", 0)) if int(entry.get("period", -1)) == _period(now) else 0
	data.story.attempts[match_id] = {"period": _period(now), "used": used + 1}
	if not save():
		data = previous
		return false
	return true

func record_win(id: String, match_id: String, opponent_id: String) -> void:
	if not id in FIGHTERS:
		return
	var index := -1
	for i in range(OPPONENTS.size()):
		if match_id == "prologue_%d" % i and opponent_id == OPPONENTS[i]:
			index = i
	if index < 0 or index > int(data.story.current):
		return
	var previous: Dictionary = data.duplicate(true)
	data.fighters[id].points += 1
	data.story.completed[match_id] = true
	if not opponent_id in data.story.unlocked_chapters:
		data.story.unlocked_chapters.append(opponent_id)
	if index == int(data.story.current):
		data.story.current = mini(3, index + 1)
	if not save():
		data = previous

func mark_seen(scene_id: String) -> void:
	var previous: Dictionary = data.duplicate(true)
	data.story.seen[scene_id] = true
	if not save():
		data = previous

func has_seen(scene_id: String) -> bool:
	return bool(data.story.seen.get(scene_id, false))
