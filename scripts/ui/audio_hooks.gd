extends Node
## SWAP POINTS: Replace each WAV in res://assets/audio/ with final audio using
## the same filename. These quiet tones are temporary placeholders, not voices.
const SOUND_PATHS := {
	"hit_light": "res://assets/audio/hit_light.wav",
	"hit_heavy": "res://assets/audio/hit_heavy.wav",
	"block": "res://assets/audio/block.wav",
	"throw": "res://assets/audio/throw.wav",
	"ko": "res://assets/audio/ko.wav",
	"round_call": "res://assets/audio/round_call.wav",
	"ui_move": "res://assets/audio/ui_move.wav",
	"ui_pick": "res://assets/audio/ui_pick.wav",
}
var player: AudioStreamPlayer

func _ready() -> void:
	player = AudioStreamPlayer.new()
	add_child(player)

func play_hook(hook: String, muted: bool = false) -> void:
	if muted or DisplayServer.get_name() == "headless" or not SOUND_PATHS.has(hook):
		return
	var stream := load(SOUND_PATHS[hook]) as AudioStream
	if stream != null:
		player.stream = stream
		player.play()
