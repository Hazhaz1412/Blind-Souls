extends AnimatedSprite2D

func _ready() -> void:

	if sprite_frames:
		sprite_frames.set_animation_loop("default", false)


	speed_scale = 2.0
	play("default")

func _on_animation_finished() -> void:

	queue_free()
