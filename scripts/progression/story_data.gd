extends RefCounted
## Property of LiveLayer Technology LLC.
## PASS 1 uses illustrated panels and text. Recorded dialogue and approved
## fighter signature tracks replace the clearly identified placeholders later.

static func prologue() -> Array:
	return [
		{"id": "prologue_0", "opponent": "bank", "title": "The Businessman", "scene": "businessman", "scenes_before": ["pull_in", "businessman"], "difficulty": 0, "stage": "rooftop", "parting": "Win or lose… it keeps the change."},
		{"id": "prologue_1", "opponent": "rico", "title": "The Wolf Smells It", "scene": "wolf", "scenes_before": ["wolf"], "difficulty": 0, "stage": "rooftop", "parting": "Heh. Wolf's gotta respect teeth. Go on — the big one's waiting, and he don't pace. He sits. Like it's a throne… or a post."},
		{"id": "prologue_2", "opponent": "hood", "title": "The Heavy Door", "scene": "heavy_door", "scenes_before": ["heavy_door"], "difficulty": 0, "stage": "rooftop", "parting": "Go on, then. He's awake now. We all heard the chain."},
	]

static func ending_scene() -> String:
	return "gate"

static func scenes() -> Dictionary:
	return {
		"pull_in": {
			"title": "THE PULL-IN", "skippable": false, "repeat_skip": true, "panels": [
				{"speaker": "", "text": "Night. A phone screen, a poster, a stage light — fragments of the real world, mid-moment. Then the sound bends: a crowd that isn't there, a bass note that doesn't stop.", "art": "city", "minimum_seconds": 1.5},
				{"speaker": "", "text": "Static crawls across everything like frost. Names flicker. For one frame, your fighter's name is gone. Then it's back, wrong somehow. Thinner.", "art": "static", "minimum_seconds": 1.5},
				{"speaker": "", "text": "The world comes back as illustration: a rooftop over a city that almost looks right. The sky is too still. No wind. No birds. Ten names hang in the sky — one already dimmer than the rest.", "art": "bracket", "minimum_seconds": 1.5},
				{"speaker": "THE WORLD", "text": "You were making noise. Something heard it.\n\nFight. Win your road to SongWars — November 22. Reach the end with your name still lit…\n\n…or stop being worth remembering. No songs. No name. Nobody waiting for you at home — because nobody will know you were ever there.", "art": "bracket", "minimum_seconds": 3.0},
			],
		},
		"businessman": {
			"title": "THE BUSINESSMAN", "skippable": true, "repeat_skip": true, "panels": [
				{"speaker": "", "text": "Bank Sinatra is already there, unbothered, like he got pulled in mid-schedule and decided to charge it to the game.", "art": "bank", "minimum_seconds": 1.2},
				{"speaker": "BANK SINATRA", "text": "You look lost. Everybody's lost. Difference is, I read the room.\n\nThis place runs on one currency — wins. You spend losses, you get… spent.\n\nSee the dim one? That's not a warning. That's a price tag.", "art": "bank", "minimum_seconds": 2.0},
				{"speaker": "BANK SINATRA", "text": "Nothing personal. Business is business — and right now, you're overhead.", "art": "bank", "minimum_seconds": 1.5},
			],
		},
		"wolf": {
			"title": "THE WOLF SMELLS IT", "skippable": true, "repeat_skip": true, "panels": [
				{"speaker": "", "text": "The same rooftop world, wronger: the lights hum at a pitch just under hearing. Rico Ruffino is pacing. Not waiting — circling.", "art": "rico", "minimum_seconds": 1.2},
				{"speaker": "RICO RUFFINO", "text": "You smell that? No? Course you don't. Prey never does.\n\nI been fighting whatever it puts in front of me since the lights went funny. You know what I figured out?\n\nIt ain't testing us. It's sorting us.", "art": "rico", "minimum_seconds": 2.0},
				{"speaker": "RICO RUFFINO", "text": "Run, stand — don't matter to me. The pack eats either way, and today… I'm the pack.", "art": "bracket", "minimum_seconds": 1.5},
			],
		},
		"heavy_door": {
			"title": "THE HEAVY DOOR", "skippable": true, "repeat_skip": true, "panels": [
				{"speaker": "", "text": "Big Hood Tha King fills the frame the way a door fills a doorway. He is not circling, not selling anything. He looks at you the way weather looks at a roof.", "art": "hood", "minimum_seconds": 1.2},
				{"speaker": "BIG HOOD THA KING", "text": "Two down. You think that makes you ready for what's past me?\n\nAin't nothing past me but the gate. And the gate got a keeper.", "art": "hood", "minimum_seconds": 2.0},
				{"speaker": "BIG HOOD THA KING", "text": "Everybody who got this far asked me the same thing — 'what's he like?' I told 'em: you'll hear him before you see him. And you'll wish you hadn't.", "art": "hood", "minimum_seconds": 2.0},
			],
		},
		"gate": {
			"title": "THE GATE", "skippable": false, "repeat_skip": true, "panels": [
				{"speaker": "", "text": "The rooftop ends at a gate that was never on any horizon before: too tall, too dark, lit from behind by a light with no source. Your fighter stops walking — the body decides before the mind does.", "art": "gate", "silhouette": false, "minimum_seconds": 2.0},
				{"speaker": "TYSHAWN SMASH — VOICE, UNSEEN", "text": "Free or forgotten, brothers — that's the whole menu.", "art": "gate", "silhouette": false, "minimum_seconds": 2.0, "audio_note": "Voice placeholder"},
				{"speaker": "", "text": "Nothing moves. The line hangs there — and it doesn't sound like a threat. It sounds like a man reading out his own sentence.", "art": "gate", "silhouette": false, "minimum_seconds": 2.0},
				{"speaker": "", "text": "The light behind the gate shifts. The biggest shape in the game sits at the gate like a post, chains running from him into the dark on both sides.", "art": "gate", "silhouette": true, "minimum_seconds": 2.0},
				{"speaker": "TYSHAWN SMASH", "text": "Win it all back — or join the quiet ones.", "art": "gate", "silhouette": true, "minimum_seconds": 2.0},
				{"speaker": "", "text": "One more name in the ten is a shade dimmer than it was.\n\nCHAPTER 1 STANDS OPEN\n\nEnd of Prologue", "art": "bracket", "silhouette": false, "minimum_seconds": 2.0},
			],
		},
	}

static func chapter_lineups() -> Array:
	# Locked opponent order; these optional chapters require the later roster.
	return [
		{"fighter": "zayy", "name": "Zayy Bizz", "title": "The dart learns patience", "opponents": ["ali", "rico", "hood"], "difficulty": [0, 1, 2]},
		{"fighter": "ali", "name": "Rock Out Ali", "title": "Keep them off the stage", "opponents": ["jo", "cin", "loe"], "difficulty": [0, 1, 2]},
		{"fighter": "jo", "name": "J.O NextLevel", "title": "Speed meets its limits", "opponents": ["zayy", "lmscurt", "rico"], "difficulty": [0, 1, 2]},
		{"fighter": "cin", "name": "Cin City", "title": "Two against the world", "opponents": ["lmscurt", "jo", "loe"], "difficulty": [0, 1, 2]},
		{"fighter": "rico", "name": "Rico Ruffino", "title": "Hold the range", "opponents": ["bank", "zayy", "loe"], "difficulty": [0, 1, 2]},
		{"fighter": "bank", "name": "Bank Sinatra", "title": "Business is business", "opponents": ["ali", "rico", "lmscurt"], "difficulty": [0, 1, 2]},
		{"fighter": "lmscurt", "name": "LMSCURT", "title": "Break everything first", "opponents": ["zayy", "cin", "hood"], "difficulty": [0, 1, 2]},
		{"fighter": "loe", "name": "Loe Budda", "title": "The mountain moves slowly", "opponents": ["bank", "hood", "jo"], "difficulty": [0, 1, 2]},
		{"fighter": "hood", "name": "Big Hood Tha King", "title": "The crown is heavy", "opponents": ["ali", "lmscurt", "cin"], "difficulty": [0, 1, 2]},
		{"fighter": "smash", "name": "Tyshawn Smash", "title": "The freed guard", "opponents": ["rico", "bank", "smash"], "difficulty": [0, 1, 2], "requires_finale": true},
	]

static func fighter_names() -> Dictionary:
	return {"zayy": "Zayy Bizz", "ali": "Rock Out Ali", "jo": "J.O NextLevel", "cin": "Cin City", "rico": "Rico Ruffino", "bank": "Bank Sinatra", "lmscurt": "LMSCURT", "loe": "Loe Budda", "hood": "Big Hood Tha King", "smash": "Tyshawn Smash"}
