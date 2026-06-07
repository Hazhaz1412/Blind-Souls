extends CharacterBody2D


enum State { APPEAR, SKIRMISH, LUNGE, RETREAT, DEAD }
var current_state: State = State.APPEAR


@export var max_hp: float = 3.0
var hp: float = 3.0

@export var speed: float = 100.0
@export var lunge_speed: float = 235.0
@export var retreat_speed: float = 210.0


var skirmish_ideal_min: float = 100.0
var skirmish_ideal_max: float = 140.0


var skirmish_timer: float = 1.5
var retreat_timer: float = 0.0


@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var player: CharacterBody2D = null


var damage_dealt: bool = false


var is_invincible: bool = false
var invincibility_timer: float = 0.0

func _ready() -> void:
	add_to_group("enemies")
	hp = max_hp


	current_state = State.APPEAR
	animated_sprite.play("appear")


	animated_sprite.animation_finished.connect(_on_animation_finished)


	_find_player()

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player")
	if not player:

		var parent = get_parent()
		if parent:
			for child in parent.get_children():
				if child is CharacterBody2D and child != self and child.has_method("take_hit"):
					player = child
					break

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		velocity = Vector2.ZERO
		return

	if not player:
		_find_player()
		return


	if invincibility_timer > 0.0:
		invincibility_timer -= delta
		if invincibility_timer <= 0.0:
			is_invincible = false
			animated_sprite.modulate.a = 1.0


	if current_state != State.APPEAR:
		animated_sprite.flip_h = (player.global_position.x < global_position.x)

	match current_state:
		State.APPEAR:

			velocity = Vector2.ZERO
			move_and_slide()

		State.SKIRMISH:
			animated_sprite.play("idle")
			damage_dealt = false


			skirmish_timer -= delta


			var diff = player.global_position - global_position
			var dist = diff.length()
			var dir = diff.normalized()

			if dist < skirmish_ideal_min:

				velocity = -dir * speed
			elif dist > skirmish_ideal_max:

				velocity = dir * speed
			else:


				var tangent = Vector2(-dir.y, dir.x)
				velocity = tangent * (speed * 0.4)

			move_and_slide()


			if skirmish_timer <= 0.0:
				current_state = State.LUNGE
				damage_dealt = false

				skirmish_timer = randf_range(1.0, 2.0)

		State.LUNGE:
			animated_sprite.play("idle")

			var diff = player.global_position - global_position
			var dist = diff.length()
			var dir = diff.normalized()


			velocity = dir * lunge_speed
			move_and_slide()


			if dist <= 38.0 and not damage_dealt:
				damage_dealt = true
				if not player.is_invincible:
					player.take_hit(global_position, 200.0)

				start_retreat()


			if dist > 300.0:
				start_retreat()

		State.RETREAT:
			animated_sprite.play("idle")


			var diff = player.global_position - global_position
			var dir = diff.normalized()

			velocity = -dir * retreat_speed
			move_and_slide()


			retreat_timer -= delta
			if retreat_timer <= 0.0:
				current_state = State.SKIRMISH

				skirmish_timer = randf_range(1.2, 2.5)

func start_retreat() -> void:
	current_state = State.RETREAT
	retreat_timer = 0.6

func take_hit(source_position: Vector2, knockback_force: float = 300.0) -> void:
	if current_state == State.DEAD or current_state == State.APPEAR:
		return

	if is_invincible:
		return


	hp -= 1.0


	animated_sprite.modulate = Color(2.5, 0.5, 0.5, 1.0)
	get_tree().create_timer(0.12).timeout.connect(func():
		if current_state != State.DEAD:
			animated_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	)


	is_invincible = true
	invincibility_timer = 0.22


	if hp <= 0.0:
		trigger_death()
		return


	var knockback_dir = (global_position - source_position).normalized()
	if knockback_dir == Vector2.ZERO:
		knockback_dir = Vector2.LEFT if animated_sprite.flip_h else Vector2.RIGHT
	velocity = knockback_dir * knockback_force
	move_and_slide()




	if current_state == State.LUNGE:
		start_retreat()

func trigger_death() -> void:
	current_state = State.DEAD
	velocity = Vector2.ZERO

	collision_shape.set_deferred("disabled", true)


	animated_sprite.play("dead")

func _on_animation_finished() -> void:
	if animated_sprite.animation == "appear":
		current_state = State.SKIRMISH
		skirmish_timer = randf_range(1.0, 2.0)
	elif animated_sprite.animation == "dead":

		queue_free()
