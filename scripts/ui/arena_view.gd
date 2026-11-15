extends Control
## Property of LiveLayer Technology LLC.
## Procedural illustrated stand-ins; rendering never mutates fight state.

var sim: RefCounted
var scene_mode: String = "fight"
var gate_phase: int = 0
var fighter_ids: Array = ["cin", "bank"]
var _world_scale := Vector2.ONE
var _world_offset := Vector2.ZERO

const INK := Color("101426")
const SKY := Color("11152f")
const CREAM := Color("f3ead8")
const PALETTES := {
	"cin": [Color("28c5bc"), Color("ef799d"), Color("b97653"), Color("33242e")],
	"rico": [Color("d65055"), Color("d9d9e1"), Color("b88062"), Color("25283b")],
	"hood": [Color("e7b64b"), Color("fff1bb"), Color("865236"), Color("252638")],
	"bank": [Color("a692f0"), Color("edc96b"), Color("956044"), Color("26253e")],
}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _draw() -> void:
	if size.x <= 0 or size.y <= 0:
		return
	# Portrait keeps the complete arena in a centered, uniformly scaled strip.
	# Filling the rest with sky leaves room for the HUD and touch controls.
	draw_rect(Rect2(Vector2.ZERO, size), SKY)
	_world_scale = size / Vector2(1280, 720)
	_world_offset = Vector2.ZERO
	if size.y > size.x:
		_world_scale = Vector2.ONE * size.x / 1280.0
		_world_offset.y = maxf(160.0, (size.y - size.x * 720.0 / 1280.0) / 2.0 - 70.0)
	draw_set_transform(_world_offset, 0, _world_scale)
	_draw_rooftop()
	if scene_mode == "story" and gate_phase > 0:
		_draw_gate()
	elif scene_mode == "fight" and sim != null and sim.get("fighters") != null:
		_draw_fight()
	elif scene_mode == "story":
		_draw_story_fighters()
	else:
		_draw_menu_figures()
	draw_set_transform(Vector2.ZERO)

func _poly(points: Array, color: Color, outline: bool = true) -> void:
	var shape := PackedVector2Array(points)
	draw_colored_polygon(shape, color)
	if outline:
		shape.append(shape[0])
		draw_polyline(shape, INK, 3.0, true)

func _label(text: String, at: Vector2, font_size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw_rooftop() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), SKY)
	# Flat color shapes deliberately read as an illustrated set, rather than pixels.
	_poly([Vector2(0, 150), Vector2(420, 95), Vector2(1000, 140), Vector2(1280, 20), Vector2(1280, 360), Vector2(0, 360)], Color("191d3d"), false)
	draw_circle(Vector2(1017, 108), 56, Color("e2cda3"))
	draw_circle(Vector2(1000, 90), 56, Color("191d3d"))
	for star in range(32):
		var sx := float((star * 173 + 79) % 1250)
		var sy := float((star * 47 + 31) % 245)
		draw_circle(Vector2(sx, sy), 1.2 if star % 4 else 2.1, Color(0.68, 0.72, 0.87, 0.38))
	# Distant skyline.
	for i in range(24):
		var x := float(i * 59 - 23)
		var h := float(66 + (i * 37) % 128)
		var y := 388.0 - h
		draw_rect(Rect2(x, y, 51, h), Color("222846"))
		if i % 3 == 1:
			draw_line(Vector2(x + 26, y), Vector2(x + 26, y - 30), Color("313955"), 2)
		for wy in range(4):
			for wx in range(3):
				if (i + wy * 7 + wx * 3) % 4 != 0:
					draw_rect(Rect2(x + 8 + wx * 13, y + 17 + wy * 25, 5, 9), Color(0.86, 0.65, 0.48, 0.33))
	# Near skyline gives the rooftop its silhouette.
	_draw_building(11, 261, 151, 184, Color("292c46"), 1)
	_draw_building(205, 315, 121, 135, Color("2b3049"), 3)
	_draw_building(389, 223, 111, 227, Color("292d48"), 4)
	_draw_building(854, 285, 153, 165, Color("282c46"), 5)
	_draw_building(1081, 243, 199, 207, Color("242a43"), 6)
	# Cin City–colored neon is a stage decoration, never a combat hazard.
	draw_rect(Rect2(66, 291, 72, 54), Color("17223a"))
	draw_rect(Rect2(69, 294, 66, 48), Color("318f95"), false, 2)
	_label("SW5", Vector2(76, 326), 24, Color("6bd1cc"))
	draw_line(Vector2(0, 371), Vector2(1280, 353), Color("10162b"), 3)
	for wire in range(9):
		draw_line(Vector2(40 + wire * 155, 370 - wire * 2), Vector2(40 + wire * 155, 389 - wire * 2), Color("34334b"), 1)
	# Water tower and roof access.
	draw_line(Vector2(1149, 255), Vector2(1127, 406), INK, 8)
	draw_line(Vector2(1210, 255), Vector2(1231, 406), INK, 8)
	_poly([Vector2(1121, 223), Vector2(1179, 194), Vector2(1239, 223)], Color("3f3851"))
	draw_rect(Rect2(1124, 224, 111, 61), Color("423c54"))
	draw_line(Vector2(1124, 244), Vector2(1235, 244), Color("65546b"), 3)
	draw_line(Vector2(1124, 274), Vector2(1235, 274), INK, 5)
	_poly([Vector2(576, 410), Vector2(576, 327), Vector2(687, 311), Vector2(747, 339), Vector2(747, 411)], Color("343047"))
	_poly([Vector2(576, 327), Vector2(633, 303), Vector2(747, 339), Vector2(690, 363)], Color("4a3b50"))
	draw_rect(Rect2(609, 347, 39, 64), Color("242539"))
	draw_rect(Rect2(619, 358, 15, 17), Color("7f6c60"))
	draw_circle(Vector2(640, 391), 2, Color("ba9967"))
	# Parapet / roof plane.
	draw_rect(Rect2(0, 410, 1280, 28), Color("5e4551"))
	draw_rect(Rect2(0, 410, 1280, 6), Color("a16e6c"))
	draw_line(Vector2(0, 438), Vector2(1280, 438), INK, 4)
	_poly([Vector2(0, 440), Vector2(1280, 440), Vector2(1280, 720), Vector2(0, 720)], Color("302b3b"), false)
	_poly([Vector2(0, 513), Vector2(1280, 513), Vector2(1280, 720), Vector2(0, 720)], Color("252536"), false)
	for i in range(12):
		draw_line(Vector2(i * 128 - 130, 720), Vector2(640 + (i * 128 - 770) * 0.44, 440), Color("3b3447"), 2)
	for y in [480, 514, 561, 625, 708]:
		draw_line(Vector2(0, y), Vector2(1280, y), Color("3b3447"), 2)
	draw_line(Vector2(0, 513), Vector2(1280, 513), Color("b6786f"), 3)
	draw_line(Vector2(0, 517), Vector2(1280, 517), Color("67485a"), 2)
	# Physical set dressing sits behind the combat plane.
	draw_rect(Rect2(11, 418, 101, 52), Color("4b4353"))
	for vent in range(5):
		draw_line(Vector2(24, 429 + vent * 7), Vector2(98, 429 + vent * 7), Color("242739"), 3)
	draw_rect(Rect2(1036, 422, 163, 25), Color("453d4d"))
	draw_line(Vector2(1047, 422), Vector2(1188, 422), Color("8c646a"), 3)
	_label("ROOFTOP / SONG WARS 5", Vector2(36, 550), 12, Color("6e6075"))

func _draw_building(x: float, y: float, width: float, height: float, color: Color, pattern: int) -> void:
	draw_rect(Rect2(x, y, width, height), color)
	draw_rect(Rect2(x - 4, y - 5, width + 8, 9), color.lightened(0.06))
	for row in range(int(height / 29)):
		for col in range(int(width / 24)):
			var lit := (row * 7 + col * 5 + pattern) % 5 < 2
			draw_rect(Rect2(x + 11 + col * 24, y + 14 + row * 29, 9, 14), Color("bd8d74") if lit else Color("191f37"))

func _draw_fight() -> void:
	var tick := int(sim.get("frame"))
	var fighters: Array = sim.get("fighters")
	# Dogs share their partner's protection and HP; their separate pose is visual.
	for f in fighters:
		if str(f.get("id", "")) == "cin":
			_draw_dog(Vector2(float(f.get("dog_x", f.x - f.facing * 52)), 509), int(f.get("facing", 1)), tick, str(f.get("state", "")))
	for index in range(fighters.size()):
		var f: Dictionary = fighters[index]
		var id := str(f.get("id", fighter_ids[index]))
		var at := Vector2(float(f.get("x", 400 + index * 480)), 510 - float(f.get("y", 0)))
		var state := str(f.get("state", "idle"))
		_draw_fighter(id, at, int(f.get("facing", 1)), state, str(f.get("move", "")), tick, index == 1 and fighter_ids[0] == fighter_ids[1], f)
	var projectiles = sim.get("projectiles")
	if projectiles is Array:
		for shot in projectiles:
			if shot is Dictionary:
				_draw_projectile(shot, tick)
	_draw_hit_fx(tick)

func _draw_menu_figures() -> void:
	_draw_fighter("hood", Vector2(1070, 512), -1, "idle", "", 0, false, {})
	_draw_fighter("rico", Vector2(883, 512), -1, "block", "", 0, false, {})
	_draw_fighter("cin", Vector2(749, 512), 1, "idle", "", 0, false, {})
	_draw_dog(Vector2(688, 511), 1, 0, "idle")
	# The overlay makes menu copy easy to read while keeping the world visible.
	draw_rect(Rect2(0, 0, 650, 720), Color(0.035, 0.045, 0.10, 0.35))

func _draw_story_fighters() -> void:
	var left_id := str(fighter_ids[0]) if fighter_ids.size() > 0 else "cin"
	var right_id := str(fighter_ids[1]) if fighter_ids.size() > 1 else "bank"
	_draw_fighter(left_id, Vector2(305, 513), 1, "idle", "", 0, false, {})
	_draw_fighter(right_id, Vector2(925, 513), -1, "idle", "", 0, left_id == right_id, {})
	if left_id == "cin":
		_draw_dog(Vector2(240, 513), 1, 0, "idle")
	if right_id == "cin":
		_draw_dog(Vector2(990, 513), -1, 0, "idle")
	# Bracket is an environmental fiction motif, not a set of fighter stats.
	draw_rect(Rect2(494, 183, 290, 157), Color(0.07, 0.10, 0.20, 0.86))
	draw_rect(Rect2(494, 183, 290, 157), Color("617789"), false, 1)
	_label("THE ROAD TO SONGWARS", Vector2(519, 211), 16, Color("d3d9df"))
	for i in range(10):
		var dim := i == 7
		var xx := 518 + (i % 2) * 134
		var yy := 228 + int(i / 2) * 20
		draw_line(Vector2(xx, yy), Vector2(xx + 103, yy), Color("344255") if dim else Color("80bdbb"), 3)

func _draw_gate() -> void:
	# The shape is deliberately absent during the first, voice-only beat.
	_poly([Vector2(586, 483), Vector2(586, 180), Vector2(638, 104), Vector2(960, 104), Vector2(1012, 180), Vector2(1012, 483)], Color("080d1e"))
	_poly([Vector2(612, 483), Vector2(612, 192), Vector2(655, 133), Vector2(944, 133), Vector2(985, 192), Vector2(985, 483)], Color("666171"))
	_poly([Vector2(633, 483), Vector2(633, 201), Vector2(667, 153), Vector2(930, 153), Vector2(964, 201), Vector2(964, 483)], Color("23223a"))
	draw_rect(Rect2(657, 174, 284, 310), Color("37334c"))
	for r in range(7):
		draw_line(Vector2(654, 201 + r * 41), Vector2(948, 201 + r * 41), Color("4b435a"), 2)
	for b in range(9):
		var x := 651 + b * 37
		draw_line(Vector2(x, 157), Vector2(x, 484), Color("12182b"), 9)
	draw_line(Vector2(612, 273), Vector2(984, 273), Color("14172a"), 9)
	_label("S O N G W A R S", Vector2(679, 121), 22, Color("a9a4ae"))
	if gate_phase >= 2:
		# Seated, bound silhouette. No additional reveal or dialogue.
		_poly([Vector2(717, 431), Vector2(723, 327), Vector2(740, 291), Vector2(777, 277), Vector2(818, 277), Vector2(853, 291), Vector2(875, 327), Vector2(883, 431)], Color("080d1b"))
		draw_circle(Vector2(800, 251), 33, Color("080d1b"))
		_poly([Vector2(746, 360), Vector2(722, 451), Vector2(765, 461), Vector2(798, 384), Vector2(828, 461), Vector2(878, 451), Vector2(851, 359)], Color("080d1b"))
		for side in [-1, 1]:
			for link in range(8):
				var at := Vector2(800 + side * (58 + link * 25), 335 + link * 9)
				draw_arc(at, 7, 0, TAU, 16, Color("766976"), 3)
	_draw_fighter(str(fighter_ids[0]) if fighter_ids.size() > 0 else "cin", Vector2(365, 515), 1, "idle", "", 0, false, {})
	_label("LiveLayer Technology LLC", Vector2(653, 506), 13, Color("97889b"))

func _draw_fighter(id: String, at: Vector2, facing: int, state: String, move: String, tick: int, alternate: bool, f: Dictionary) -> void:
	var palette: Array = PALETTES.get(id, PALETTES.bank)
	var coat: Color = palette[0]
	var accent: Color = palette[1]
	var skin: Color = palette[2]
	var dark: Color = palette[3]
	if alternate:
		coat = Color.from_hsv(fmod(coat.h + 0.38, 1.0), coat.s, coat.v)
		accent = Color.from_hsv(fmod(accent.h + 0.26, 1.0), accent.s, accent.v)
	var tall := 1.13 if id == "hood" else 1.0
	var broad := 1.30 if id == "hood" else (1.05 if id == "rico" else 0.94)
	var down := state in ["knockdown", "down", "getup", "ko"]
	var uppercut := move == "uppercut" and state == "attack"
	var uppercut_age := int(f.get("attack_frame", 0))
	var crouch := uppercut_age < 8 if uppercut else (bool(f.get("down", false)) or state == "crouch" or move in ["low", "low_kick"])
	var block := state in ["block", "blocking", "blockstun"] or bool(f.get("blocking", false))
	var hurt := state in ["hurt", "hitstun", "captured", "grabbed", "juggle", "stunned"]
	var walk := state == "walk" or state == "walking"
	var attack := move in ["light", "low", "kick", "low_kick", "heavy", "uppercut", "throw", "minor", "big"] and not down
	var bob := sin(float(tick) * 0.13) * 2.0 if not down else 0.0
	if uppercut and uppercut_age >= 8:
		bob -= 12.0
	draw_set_transform(_world_offset, 0, _world_scale)
	draw_set_transform(_world_offset + Vector2(at.x, 512) * _world_scale, 0, _world_scale)
	_ellipse(Rect2(-42 * broad, -5, 84 * broad, 12), Color(0.035, 0.035, 0.08, 0.55))
	draw_set_transform(_world_offset + (at + Vector2(0, bob + (22 if crouch else 0))) * _world_scale, -0.10 * facing if hurt else 0.0, Vector2(facing * broad, tall) * _world_scale)
	if down:
		_draw_fallen(coat, accent, skin, dark, state)
		draw_set_transform(_world_offset, 0, _world_scale)
		return
	# Back leg / back arm.
	var gait := sin(float(tick) * 0.30) * 11 if walk else 0.0
	var rear_knee := Vector2(-17 - gait, -29 if not crouch else -17)
	var rear_foot := Vector2(-28 - gait, -3 if not crouch else -22)
	_limb([Vector2(-13, -53), rear_knee, rear_foot], 17, dark)
	_limb([Vector2(-22, -98), Vector2(-32, -70), Vector2(-17, -58)], 13, coat.darkened(0.20))
	# Coat / body.
	_poly([Vector2(-26, -105), Vector2(23, -105), Vector2(28, -70), Vector2(19, -50), Vector2(-23, -50), Vector2(-30, -75)], coat)
	_poly([Vector2(-11, -102), Vector2(12, -102), Vector2(17, -60), Vector2(-9, -60)], CREAM if id == "cin" else dark, false)
	if id == "bank":
		_poly([Vector2(0, -98), Vector2(6, -91), Vector2(3, -69), Vector2(-3, -75)], accent, false)
		_poly([Vector2(-26, -104), Vector2(-6, -104), Vector2(-15, -85)], coat.lightened(0.20), false)
	elif id == "hood":
		_label("KING", Vector2(-21, -75), 15, accent)
	elif id == "rico":
		_poly([Vector2(-29, -104), Vector2(26, -106), Vector2(24, -91), Vector2(-26, -88)], accent)
		_poly([Vector2(-19, -97), Vector2(-28, -57), Vector2(-8, -61), Vector2(-5, -99)], accent, false)
	else:
		draw_line(Vector2(-23, -82), Vector2(-20, -57), accent, 3)
	# Front leg kick or grounded stance.
	var front_knee := Vector2(18 + gait, -28 if not crouch else -10)
	var front_foot := Vector2(30 + gait, -2 if not crouch else -20)
	if attack and move in ["kick", "heavy", "low_kick"]:
		front_knee = Vector2(48, -10 if move == "low_kick" else (-54 if move == "kick" else -33))
		front_foot = Vector2(103, -8 if move == "low_kick" else (-63 if move == "kick" else -22))
	_limb([Vector2(10, -52), front_knee, front_foot], 17, dark.lightened(0.07))
	_limb([rear_foot + Vector2(-8, 0), rear_foot + Vector2(7, 0)], 11, accent)
	_limb([front_foot + Vector2(-8, 0), front_foot + Vector2(11, 0)], 11, accent)
	# Neck and head.
	draw_rect(Rect2(-9, -117, 19, 15), skin)
	draw_circle(Vector2(-1, -126), 22, INK)
	draw_circle(Vector2(-1, -126), 19, skin)
	_poly([Vector2(-19, -129), Vector2(-22, -145), Vector2(-2, -153), Vector2(18, -143), Vector2(18, -133), Vector2(9, -139), Vector2(-6, -138)], dark)
	if id == "cin":
		_poly([Vector2(-18, -142), Vector2(-32, -142), Vector2(-39, -107), Vector2(-30, -89), Vector2(-20, -114)], Color("4d313c"))
		draw_arc(Vector2(-1, -128), 22, PI, TAU, 18, accent, 4)
	elif id == "bank":
		_poly([Vector2(-23, -145), Vector2(-15, -165), Vector2(12, -162), Vector2(20, -145)], dark)
		_limb([Vector2(-28, -144), Vector2(29, -144)], 7, coat)
	elif id == "hood":
		_poly([Vector2(-20, -144), Vector2(-24, -161), Vector2(-10, -155), Vector2(0, -168), Vector2(10, -154), Vector2(24, -161), Vector2(20, -144)], coat)
		draw_circle(Vector2(0, -150), 3, accent)
	else:
		_poly([Vector2(-20, -137), Vector2(-27, -151), Vector2(-10, -149), Vector2(0, -159), Vector2(13, -146), Vector2(23, -145), Vector2(15, -132)], accent)
	# Face / jaw.
	draw_line(Vector2(5, -130), Vector2(14, -129), INK, 3)
	draw_line(Vector2(3, -117), Vector2(12, -118), dark, 2)
	if id in ["rico", "hood", "bank"]:
		draw_arc(Vector2(0, -126), 18, 0.10, 2.90, 14, dark, 5)
	if id == "bank":
		draw_rect(Rect2(-10, -133, 25, 7), INK)
	# Foreground arm is the main readable action silhouette.
	var elbow := Vector2(31, -78)
	var fist := Vector2(33, -104)
	if block:
		elbow = Vector2(32, -98)
		fist = Vector2(20, -133)
	elif hurt:
		elbow = Vector2(34, -77)
		fist = Vector2(55, -69)
	elif uppercut:
		# Coil low, then extend the fist above the head through the active frames.
		var rise := clampf(float(uppercut_age - 4) / 6.0, 0.0, 1.0)
		if uppercut_age > 16:
			rise = maxf(0.0, 1.0 - float(uppercut_age - 16) / 18.0)
		elbow = Vector2(34, -76).lerp(Vector2(41, -133), rise)
		fist = Vector2(38, -71).lerp(Vector2(47, -184), rise)
	elif attack and move in ["light", "low", "throw", "minor", "big"]:
		elbow = Vector2(55, -97 if move != "low" else -65)
		fist = Vector2(103 if move != "throw" else 76, -98 if move != "low" else -64)
	_limb([Vector2(21, -99), elbow, fist], 14, coat)
	draw_circle(fist, 10, INK)
	draw_circle(fist, 7.5, skin)
	if block:
		draw_arc(Vector2(27, -103), 39, -1.12, 1.12, 24, Color(0.48, 0.89, 0.94, 0.6), 3)
	if uppercut and uppercut_age in range(8, 17):
		draw_arc(Vector2(10, -121), 67, -1.10, 0.90, 24, Color(accent, 0.75), 5)
	# Belt and small accent preserve fighter identity without stat labels.
	draw_line(Vector2(-23, -53), Vector2(20, -53), accent, 5)
	if attack and move in ["minor", "big"]:
		draw_arc(Vector2(38, -81), 62, -1.4, 1.2, 28, Color(coat, 0.66), 5)
	draw_set_transform(_world_offset, 0, _world_scale)

func _draw_fallen(coat: Color, accent: Color, skin: Color, dark: Color, state: String) -> void:
	var lift := -17.0 if state == "getup" else -5.0
	_limb([Vector2(-19, lift), Vector2(23, lift - 5), Vector2(54, lift + 1)], 24, coat)
	_limb([Vector2(42, lift), Vector2(76, lift + 2)], 17, dark)
	_limb([Vector2(72, lift), Vector2(85, lift)], 12, accent)
	draw_circle(Vector2(-37, lift - 5), 21, INK)
	draw_circle(Vector2(-37, lift - 5), 18, skin)
	_limb([Vector2(-11, lift - 4), Vector2(8, lift - 16), Vector2(29, lift - 9)], 11, skin)

func _limb(points: Array, width: float, color: Color) -> void:
	var packed := PackedVector2Array(points)
	draw_polyline(packed, INK, width + 5, true)
	draw_polyline(packed, color, width, true)
	for point in points:
		draw_circle(point, width / 2.0, color)

func _draw_dog(at: Vector2, facing: int, tick: int, state: String) -> void:
	draw_set_transform(_world_offset + at * _world_scale, 0, Vector2(facing, 1) * _world_scale)
	var down := state in ["knockdown", "down", "getup", "ko"]
	var bob := sin(float(tick) * 0.3) * 2
	_ellipse(Rect2(-30, -5, 66, 9), Color(0.035, 0.035, 0.08, 0.45))
	var fur := Color("d6a16b")
	if down:
		_poly([Vector2(-28, -4), Vector2(-21, -21), Vector2(15, -19), Vector2(30, -9), Vector2(29, -2)], fur)
	else:
		_limb([Vector2(-17, -21), Vector2(-22, -3)], 7, fur)
		_limb([Vector2(16, -21), Vector2(21, -3)], 7, fur)
		_limb([Vector2(-26, -27), Vector2(-40, -41 + bob)], 8, fur)
		_poly([Vector2(-28, -30), Vector2(14, -33), Vector2(27, -22), Vector2(22, -11), Vector2(-22, -12)], fur)
		draw_circle(Vector2(25, -38 + bob), 16, INK)
		draw_circle(Vector2(25, -38 + bob), 13, fur)
		_poly([Vector2(13, -44 + bob), Vector2(10, -62 + bob), Vector2(25, -48 + bob)], Color("6e4943"))
		_poly([Vector2(31, -44 + bob), Vector2(37, -60 + bob), Vector2(41, -40 + bob)], Color("6e4943"))
		_poly([Vector2(30, -37 + bob), Vector2(47, -32 + bob), Vector2(43, -22 + bob), Vector2(26, -25 + bob)], fur.lightened(0.15))
		draw_circle(Vector2(43, -32 + bob), 4, INK)
		draw_circle(Vector2(30, -40 + bob), 2.5, INK)
		draw_line(Vector2(15, -25 + bob), Vector2(31, -23 + bob), Color("ef799d"), 5)
	draw_set_transform(_world_offset, 0, _world_scale)

func _draw_projectile(shot: Dictionary, tick: int) -> void:
	var x := float(shot.get("x", 0))
	var y := 510.0 - float(shot.get("y", 80))
	var direction := int(shot.get("direction", shot.get("dir", shot.get("facing", 1))))
	var owner := int(shot.get("owner", 0))
	var id := str(fighter_ids[clampi(owner, 0, fighter_ids.size() - 1)])
	var color: Color = PALETTES.get(id, PALETTES.bank)[0]
	for i in range(4):
		draw_circle(Vector2(x - direction * i * 14, y), 14 - i * 2, Color(color, 0.30 - i * 0.06))
	var points := [Vector2(x - 17, y - 11), Vector2(x + 17, y - 7), Vector2(x + 11, y + 13), Vector2(x - 15, y + 9)]
	_poly(points, Color("e7c770"))
	draw_circle(Vector2(x, y), 5, color.darkened(0.2))
	if tick % 10 < 5:
		draw_line(Vector2(x - 26 * direction, y - 5), Vector2(x - 46 * direction, y - 5), color, 2)

func _draw_hit_fx(tick: int) -> void:
	var events = sim.get("events")
	if not events is Array:
		return
	for event in events:
		if not event is Dictionary:
			continue
		var event_type := str(event.get("type", ""))
		if event_type not in ["hit", "block", "dog_hit", "special_hit", "throw", "throw_break", "knockdown"]:
			continue
		var target := int(event.get("target", 1))
		var fighters: Array = sim.get("fighters")
		if target < 0 or target >= fighters.size():
			continue
		var at := Vector2(float(fighters[target].get("x", 640)), 426 - float(fighters[target].get("y", 0)))
		var color := Color("8ce3e5") if event_type == "block" else Color("ffe2a0")
		for ray in range(8):
			var angle := float(ray) / 8 * TAU + float(tick % 3) * 0.3
			var direction := Vector2(cos(angle), sin(angle))
			draw_line(at + direction * 9, at + direction * (25 if ray % 2 else 36), color, 3)
		draw_circle(at, 5, CREAM)

func _ellipse(rect: Rect2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(32):
		var angle := float(i) / 32.0 * TAU
		points.append(rect.get_center() + Vector2(cos(angle), sin(angle)) * rect.size * 0.5)
	draw_colored_polygon(points, color)
