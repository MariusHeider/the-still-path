extends Node2D
## Foot contacts come from walk frames; recovery/mounting never count as landings.
@export var footsteps_db := -24.0
@export var landing_db := -18.0
@export var awareness_db := -13.0
@export var teleport_db := -13.0
@export var gong_db := -16.0
var _last_step := -1
var _air_time := 0.0
var _air_top := 0.0
var _down_speed := 0.0
var _suppress := 0.3
var _grounded_once := false
var _gong_played := false
@onready var seeker: Seeker = get_parent()
@onready var sprite: AnimatedSprite2D = seeker.get_node("AnimatedSprite2D")
@onready var steps := Sound.local(self, Sound.STEPS[0], footsteps_db, "Footsteps")
@onready var landing := Sound.local(self, Sound.LAND, landing_db, "LandingSound")
@onready var leaving := Sound.local(self, Sound.LEAVING, awareness_db, "LeavingSound")
@onready var teleport := Sound.local(self, Sound.TELEPORT, teleport_db, "TeleportSound")

func _ready() -> void:
	sprite.frame_changed.connect(_foot_contact)
	seeker.final_meditation_succeeded.connect(_final_success)
	seeker.get_node("Awareness").activated.connect(leaving.play)
	seeker.teleported.connect(teleport.play)
	seeker.movement_relocated.connect(_reset_landing)

func _reset_landing() -> void:
	_suppress = 0.3
	_air_time = 0.0
	_grounded_once = false

func _physics_process(delta: float) -> void:
	_suppress = maxf(0.0, _suppress - delta)
	if seeker.riding != null or seeker.is_seated or seeker._teleporting or _suppress > 0.0:
		_air_time = 0.0
		return
	if seeker.is_on_floor():
		if _grounded_once and _air_time > 0.16 and _down_speed > 100.0 and seeker.position.y - _air_top > 20.0:
			landing.play()
		_grounded_once = true
		_air_time = 0.0
		_air_top = seeker.position.y
	else:
		_air_time += delta
		_air_top = minf(_air_top, seeker.position.y)
		_down_speed = seeker.velocity.y

func _foot_contact() -> void:
	if sprite.animation != &"walk" or sprite.frame not in [0, 3]:
		return
	if not seeker.is_on_floor() or absf(seeker.velocity.x) < 5.0 or seeker.riding != null or seeker.is_seated:
		return
	_last_step = Sound.choose(Sound.STEPS, _last_step)
	steps.stream = Sound.stream(Sound.STEPS[_last_step])
	steps.play()

func _final_success() -> void:
	if not _gong_played:
		_gong_played = true
		Sound.final_gong(get_tree(), gong_db)
