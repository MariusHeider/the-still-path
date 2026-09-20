extends Control
## Closing screen.
##
## Deliberately offers nothing. No "play again", and no close button either:
## the game is played in a browser tab, where quitting is not something a page
## can do, and a button that does nothing is worse than no button. The last
## screen says its piece and then simply stays.

func _ready() -> void:
	$Lines.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_interval(0.6)
	tween.tween_property($Lines, "modulate:a", 1.0, 1.6)
