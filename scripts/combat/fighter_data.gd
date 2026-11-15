# Property of LiveLayer Technology LLC.
extends RefCounted

const IDS = ["cin", "rico", "hood", "bank"]
const FIGHTERS = {
	"cin": {"name": "Cin City", "hp": 100, "damage_class": "Standard", "speed_class": "Fast", "reach_class": "Short", "minor": "lunge", "big_name": "Off The Leash", "big_hits": [4, 6, 5, 10, 20], "color": Color("f05d87")},
	"rico": {"name": "Rico Ruffino", "hp": 100, "damage_class": "Standard", "speed_class": "Standard", "reach_class": "Long", "minor": "multi", "big_name": "The Wolf Flip", "big_hits": [6, 6, 6, 7, 20], "color": Color("a58af9")},
	"hood": {"name": "Big Hood Tha King", "hp": 105, "damage_class": "Power", "speed_class": "Slow", "reach_class": "Long", "minor": "lunge", "big_name": "KING'S VERDICT", "big_hits": [10, 15, 20], "color": Color("f5bb57")},
	"bank": {"name": "Bank Sinatra", "hp": 100, "damage_class": "Standard", "speed_class": "Standard", "reach_class": "Standard", "minor": "projectile", "big_name": "Droppin Jewelz", "big_hits": [10, 10, 25], "color": Color("5ce0c4")}
}

static func get_fighter(id: String) -> Dictionary:
	var result: Dictionary = FIGHTERS.get(id, FIGHTERS["cin"]).duplicate(true)
	result["id"] = id if FIGHTERS.has(id) else "cin"
	return result
