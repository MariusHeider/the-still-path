extends RefCounted
class_name Sound
## Shared stream references and small local players; no global music framework.
const MENU = preload("res://Assets/Audio/Music/northindianbeat.mp3")
const AMBIENCE = preload("res://Assets/Audio/SFX/Ambience/Ambience_SP_Hackathon_09-2026.ogg")
const MOUNTAIN = preload("res://Assets/Audio/SFX/Ambience/mountain_wind.wav")
const LAND = preload("res://Assets/Audio/SFX/Character/jumpland.mp3")
const CHICK = preload("res://Assets/Audio/SFX/chick_chirp.ogg")
const BIRD = preload("res://Assets/Audio/SFX/adult_bird_chirp.ogg")
const GROWTH = preload("res://Assets/Audio/SFX/growth_spell.ogg")
const FOG = preload("res://Assets/Audio/SFX/fog_reveal.ogg")
const LEAVING = preload("res://Assets/Audio/SFX/leaving_body.ogg")
const TELEPORT = preload("res://Assets/Audio/SFX/teleport.ogg")
const GONG = preload("res://Assets/Audio/SFX/gong.ogg")
const STEPS = [
	preload("res://Assets/Audio/SFX/Character/Footsteps/FootstepGrass01.wav"),
	preload("res://Assets/Audio/SFX/Character/Footsteps/FootstepGrass02.wav"),
	preload("res://Assets/Audio/SFX/Character/Footsteps/FootstepGrass03.wav"),
	preload("res://Assets/Audio/SFX/Character/Footsteps/FootstepGrass04.wav"),
	preload("res://Assets/Audio/SFX/Character/Footsteps/FootstepGrass05.wav"),
	preload("res://Assets/Audio/SFX/Character/Footsteps/FootstepGrass06.wav"),
	preload("res://Assets/Audio/SFX/Character/Footsteps/FootstepGrass07.wav"),
	preload("res://Assets/Audio/SFX/Character/Footsteps/FootstepGrass08.wav"),
	preload("res://Assets/Audio/SFX/Character/Footsteps/FootstepGrass09.wav"),
]
const SPLASHES = [
	preload("res://Assets/Audio/SFX/Water_Footsteps_Elephant/0.ogg"),
	preload("res://Assets/Audio/SFX/Water_Footsteps_Elephant/1.ogg"),
	preload("res://Assets/Audio/SFX/Water_Footsteps_Elephant/2.ogg"),
	preload("res://Assets/Audio/SFX/Water_Footsteps_Elephant/3.ogg"),
	preload("res://Assets/Audio/SFX/Water_Footsteps_Elephant/4.ogg"),
]

static func stream(source: AudioStream, loop := false) -> AudioStream:
	# Each asset has one consistent loop policy; players own playback separately.
	var result: AudioStream = source
	if result is AudioStreamWAV:
		result.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
		if loop:
			result.loop_begin = 0
			result.loop_end = int(result.get_length() * result.mix_rate)
	else:
		result.set("loop", loop)
	return result

static func local(parent: Node, source: AudioStream, db: float, node_name: String) -> AudioStreamPlayer2D:
	var audio := AudioStreamPlayer2D.new()
	audio.name = node_name
	audio.stream = stream(source)
	audio.volume_db = db
	audio.max_distance = 700.0
	parent.add_child(audio)
	return audio

static func choose(samples: Array, previous: int) -> int:
	if previous < 0:
		return randi_range(0, samples.size() - 1)
	var index := randi_range(0, samples.size() - 2)
	return index + 1 if index >= previous and previous >= 0 else index

static func final_gong(tree: SceneTree, db: float) -> void:
	# Root ownership lets the natural tail survive the ending scene transition.
	var audio := AudioStreamPlayer.new()
	audio.name = "FinalGong"
	audio.stream = stream(GONG)
	audio.volume_db = db
	tree.root.add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()
