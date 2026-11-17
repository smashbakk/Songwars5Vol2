# Property of LiveLayer Technology LLC.
extends RefCounted

# Launch roster: eight fighters, all playable — the Core Four (Smash, J.O
# NextLevel, Rico Ruffino, LMSCURT) plus Cin City, Big Hood Tha King,
# Bank Sinatra, and Hublo. The four added with the front door carry their
# real locked special names; their minor/big molds ride existing patterns
# as placeholders until the playstyle pass. Hublo's specials are not
# designed yet — neutral placeholder, flagged for the CEO.
const IDS = ["cin", "rico", "hood", "bank", "smash", "jo", "lmscurt", "hublo"]
const FIGHTERS = {
	"cin": {"name": "Cin City", "hp": 200, "damage_class": "Standard", "speed_class": "Fast", "reach_class": "Short", "minor": "lunge", "big_name": "Off The Leash", "big_hits": [6, 10, 8, 16, 30], "color": Color("f05d87")},
	"rico": {"name": "Rico Ruffino", "hp": 200, "damage_class": "Standard", "speed_class": "Standard", "reach_class": "Long", "minor": "multi", "big_name": "The Wolf Flip", "big_hits": [10, 10, 10, 10, 30], "color": Color("a58af9")},
	"hood": {"name": "Big Hood Tha King", "hp": 210, "damage_class": "Power", "speed_class": "Slow", "reach_class": "Long", "minor": "lunge", "big_name": "KING'S VERDICT", "big_hits": [16, 22, 30], "color": Color("f5bb57")},
	"bank": {"name": "Bank Sinatra", "hp": 200, "damage_class": "Standard", "speed_class": "Standard", "reach_class": "Standard", "minor": "projectile", "big_name": "Droppin Jewelz", "big_hits": [16, 16, 36], "color": Color("5ce0c4")},
	"smash": {"name": "Smash", "hp": 200, "damage_class": "Standard", "speed_class": "Fast", "reach_class": "Standard", "minor": "multi", "big_name": "System Shut Down", "big_hits": [16, 16, 36], "color": Color("4da3ff")},
	"jo": {"name": "J.O NextLevel", "hp": 200, "damage_class": "Standard", "speed_class": "Fast", "reach_class": "Standard", "minor": "lunge", "big_name": "Put The House On It", "big_hits": [16, 22, 30], "color": Color("ff9e57")},
	"lmscurt": {"name": "LMSCURT", "hp": 200, "damage_class": "Standard", "speed_class": "Standard", "reach_class": "Standard", "minor": "multi", "big_name": "Drops The BANK", "big_hits": [16, 22, 30], "color": Color("ffe066")},
	"hublo": {"name": "Hublo", "hp": 200, "damage_class": "Standard", "speed_class": "Standard", "reach_class": "Standard", "minor": "lunge", "big_name": "To Be Announced", "big_hits": [16, 16, 36], "color": Color("9fe870")}
}

# Artist-screen bios (CEO ruling, Nov 15, 2026): the roster shows a small
# bio and the Special — no game stats. Written from locked canon only.
const BIOS = {
	"cin": "The first lady of the Rooftop — and her little Yorkie fights right beside her, off the leash and into the fight.",
	"rico": "Song Wars 5's own co-presenter, pulled through the phone into the game. There's a wolf in him — fill the meter and it comes out.",
	"hood": "The biggest shadow on the Rooftop. When the King gives his verdict, nobody argues.",
	"bank": "First stop on the road to the gate. He doesn't chase the money — he drops jewels.",
	"smash": "The one who pulled them all into the game. Clear the whole road and you still have to go through him.",
	"jo": "The management mind of the Core Four — suit sharp, word sharper. He'll put the house on it.",
	"lmscurt": "Image is the weapon: he changes the outfit and turns the damage up. Push him too far and he drops the BANK.",
	"hublo": "Hood up, mask on, nothing given away. His special hasn't been announced — and neither has he."
}

static func get_fighter(id: String) -> Dictionary:
	var result: Dictionary = FIGHTERS.get(id, FIGHTERS["cin"]).duplicate(true)
	result["id"] = id if FIGHTERS.has(id) else "cin"
	result["bio"] = str(BIOS.get(result["id"], ""))
	return result
