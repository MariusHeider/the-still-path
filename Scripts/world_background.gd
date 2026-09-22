extends CanvasLayer
## Viewport-fixed distant atmosphere. No physics, input, camera or audio ownership.
@export var transition_seconds := 5.0
var mountain_active := false
var _fade: Tween
var _wind_time := 0.0
## x, y, length, phase: deterministic, staggered wisps in viewport coordinates.
const WIND_STREAKS := [Vector4(-20,52,44,0), Vector4(98,102,38,1.8),
	Vector4(218,150,52,4.7), Vector4(360,72,46,7.3),
	Vector4(470,188,58,10.6), Vector4(540,122,36,13.9), Vector4(40,218,50,17.2)]
@onready var main: Node2D = $Main
@onready var mountain: Node2D = $Mountain
@onready var wind: Node2D = $Mountain/Wind

func _ready() -> void:
	main.draw.connect(_draw_main)
	mountain.draw.connect(_draw_mountain)
	wind.draw.connect(_draw_wind)
	get_viewport().size_changed.connect(_redraw)
	_redraw()

func enter_mountain(body: Node2D) -> void:
	if body is Seeker: _transition(true)

func leave_mountain(body: Node2D) -> void:
	if body is Seeker: _transition(false)

func _transition(inside: bool) -> void:
	if mountain_active == inside: return
	mountain_active = inside
	if _fade != null: _fade.kill()
	# An opaque main sky under the fading mountain layer avoids gray bleed-through.
	_fade = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fade.tween_property(mountain, "modulate:a", 1.0 if inside else 0.0, transition_seconds)

func _redraw() -> void:
	main.queue_redraw()
	mountain.queue_redraw()
	wind.queue_redraw()

func _process(delta: float) -> void:
	wind.visible = mountain.modulate.a > 0.001
	if wind.visible:
		_wind_time = fmod(_wind_time + delta, 22.0)
		wind.queue_redraw()

func _canvas(node: Node2D) -> void:
	node.draw_set_transform(Vector2.ZERO, 0.0, get_viewport().get_visible_rect().size / Vector2(640,360))

func _sky(node: Node2D, top: Color, middle: Color, bottom: Color) -> void:
	node.draw_rect(Rect2(0,0,640,360), top)
	node.draw_rect(Rect2(0,120,640,240), middle)
	node.draw_rect(Rect2(0,240,640,120), bottom)

func _cloud(node: Node2D, at: Vector2, width: float, color: Color) -> void:
	# Small stepped forms, drawn at native pixels without antialiasing.
	node.draw_rect(Rect2(at + Vector2(12,0), Vector2(width-28,4)), color)
	node.draw_rect(Rect2(at + Vector2(4,4), Vector2(width-10,6)), color)
	node.draw_rect(Rect2(at + Vector2(0,10), Vector2(width,4)), color)
	node.draw_rect(Rect2(at + Vector2(10,14), Vector2(width-20,2)), Color(color, color.a * 0.5))

func _draw_main() -> void:
	_canvas(main)
	_sky(main, Color("bdd5e0"), Color("c8dde3"), Color("d5e4e3"))
	_cloud(main, Vector2(62,58), 84, Color(0.94,0.97,0.96,0.35))
	_cloud(main, Vector2(330,98), 102, Color(0.94,0.97,0.96,0.28))
	_cloud(main, Vector2(538,42), 64, Color(0.94,0.97,0.96,0.25))
	main.draw_colored_polygon(PackedVector2Array([Vector2(0,254),Vector2(60,244),Vector2(128,220),Vector2(196,224),Vector2(288,258),Vector2(384,240),Vector2(470,230),Vector2(550,250),Vector2(640,234),Vector2(640,360),Vector2(0,360)]), Color("c0d4ce"))
	main.draw_colored_polygon(PackedVector2Array([Vector2(0,300),Vector2(100,282),Vector2(190,292),Vector2(290,268),Vector2(372,276),Vector2(490,302),Vector2(580,282),Vector2(640,288),Vector2(640,360),Vector2(0,360)]), Color("b8cec3"))

func _draw_mountain() -> void:
	_canvas(mountain)
	_sky(mountain, Color("cbdde9"), Color("d8e5ed"), Color("e4edef"))
	_cloud(mountain, Vector2(104,52), 116, Color(0.97,0.98,1,0.2))
	_cloud(mountain, Vector2(470,90), 84, Color(0.97,0.98,1,0.18))
	mountain.draw_colored_polygon(PackedVector2Array([Vector2(0,266),Vector2(92,196),Vector2(140,220),Vector2(248,130),Vector2(340,218),Vector2(388,188),Vector2(460,248),Vector2(550,172),Vector2(640,250),Vector2(640,360),Vector2(0,360)]), Color("c4d5df"))
	mountain.draw_colored_polygon(PackedVector2Array([Vector2(0,310),Vector2(114,248),Vector2(160,270),Vector2(258,226),Vector2(360,298),Vector2(474,240),Vector2(548,278),Vector2(640,236),Vector2(640,360),Vector2(0,360)]), Color("b8cdd7"))

func _draw_wind() -> void:
	_canvas(wind)
	for i in WIND_STREAKS.size():
		var streak: Vector4 = WIND_STREAKS[i]
		var age := fmod(_wind_time + streak.w, 22.0)
		if age > 7.0: continue
		var at := (Vector2(streak.x,streak.y) + Vector2(age * 14.0, age * 0.4)).floor()
		var opacity := sin(age / 7.0 * PI) * 0.24
		var thickness := 2.0 if i % 2 == 0 else 1.0
		wind.draw_rect(Rect2(at, Vector2(streak.z,thickness)), Color(0.45,0.58,0.66,opacity))
		wind.draw_rect(Rect2(at + Vector2(-10,1), Vector2(12,1)), Color(0.45,0.58,0.66,opacity * 0.4))
