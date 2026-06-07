extends AnimatedSprite2D

func _ready() -> void:

	if sprite_frames:
		sprite_frames.set_animation_loop("default", false)


	speed_scale = 1.8


	play("default")


	var tween = create_tween()

	tween.tween_property(self, "modulate:a", 0.0, 0.22)

func _on_animation_finished() -> void:

	queue_free()
