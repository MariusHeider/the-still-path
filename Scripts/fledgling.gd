extends Node2D
class_name Fledgling
## A chick that has come out of its nest. Picked up and carried on the head.
##
## It was briefly carried by the attention instead, which was worse: it made
## the moment abstract, and it needed the awareness mechanic to be available
## here rather than only at the canyon. Picking it up and climbing with it is
## plainer and asks more of the player, which suits what the moment is about.

## Where its feet rest on the seeker's head, relative to his feet.
@export var carry_offset := Vector2(0.0, -36.0)
## Idle and seated poses only; walking and airborne attachment stay unchanged.
const RESTING_DROP := 1.0
## Actual idle hair-top rows: 11, 10, 9, 10, 11 in the existing 56px frames.
const IDLE_HEAD_Y := [0.0, -1.0, -2.0, -1.0, 0.0]
## The seated head is lower; sit_down interpolates this single pose adjustment.
@export var sitting_head_drop := 7.5
## Small allowance for the seeker's forward/upward head position in the air.
@export var airborne_offset := Vector2(3.0, -2.0)

var carrier: Seeker = null
var delivered := false

var _home := Vector2.ZERO
@export var chirp_volume_db := -30.0
@onready var _sprite_rest_position: Vector2 = $Visual/Sprite.position
@onready var chirp_audio := Sound.local(self, Sound.CHICK, chirp_volume_db, "ChirpSound")

func chirp() -> void:
	chirp_audio.play()


func _ready() -> void:
	# Apply attachment after the existing animation has updated its body bob.
	process_priority = 1
	add_to_group("interactable")
	_home = global_position


func _process(_delta: float) -> void:
	$Visual/Sprite.position = _sprite_rest_position
	if carrier == null:
		return
	# A tiny lift on takeoff settles as the ascent slows. No accumulated offset,
	# so landing (or recovering from a fall) always restores the resting position.
	var lift := 0.0 if carrier.is_on_floor() else clampf(carrier.velocity.y * 0.005, -2.0, 0.0)
	var pose_offset := Vector2.ZERO if carrier.is_on_floor() else airborne_offset
	var idle := carrier.is_on_floor() and carrier._sprite.animation == &"idle" and not carrier.is_seated
	var resting_drop := RESTING_DROP if idle or carrier.is_seated else 0.0
	if idle:
		resting_drop += IDLE_HEAD_Y[carrier._sprite.frame % IDLE_HEAD_Y.size()]
		# Cancel only the chick body bob; the beak animation and chirp keep playing.
		$Visual/Sprite.position.y -= $Visual.position.y
	var head_drop := 0.0
	if carrier.is_seated:
		head_drop = sitting_head_drop
		if carrier._sprite.animation == &"sit_down":
			# Follow the lowering transition with one interpolated pose offset.
			head_drop *= (carrier._sprite.frame + carrier._sprite.frame_progress) / carrier._sprite.sprite_frames.get_frame_count("sit_down")
	global_position = carrier.global_position + Vector2(
		(carry_offset.x + pose_offset.x) * carrier.facing, carry_offset.y + pose_offset.y + lift + head_drop + resting_drop)
	$Visual.scale.x = carrier.facing


func interact_prompt() -> String:
	return "E to pick up"


func can_interact(player: Seeker) -> bool:
	return not delivered and carrier == null and player.carried == null


func interact(player: Seeker) -> void:
	if not can_interact(player):
		return
	carrier = player
	player.carried = self


## Put down somewhere specific, by the nest or by the seeker standing up.
func release(at: Vector2) -> void:
	if delivered:
		return
	if carrier != null:
		carrier.carried = null
	carrier = null
	global_position = at


func return_home() -> void:
	release(_home)

func deliver_to(at: Vector2) -> bool:
	if delivered or carrier == null:
		return false
	release(at)
	delivered = true
	remove_from_group("interactable")
	return true
