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

static func get_fighter(id: String) -> Dictionary:
	var result: Dictionary = FIGHTERS.get(id, FIGHTERS["cin"]).duplicate(true)
	result["id"] = id if FIGHTERS.has(id) else "cin"
	return result
