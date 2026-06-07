extends AnimatedSprite2D


enum State { IDLE, CHASE, TELEPORT_ATTACK, RAW_ATTACK, COOLDOWN, SUMMON, DASH_ATTACK, VANISH_SWEEP }
var current_state: State = State.IDLE


@export var speed: float = 140.0
@export var attack_range: float = 95.0
@export var skill_cooldown: float = 4.0
@export var teleport_distance: float = 60.0
@export var hit_box_range: float = 100.0


var summon_cooldown_timer: float = 16.0
var summon_cooldown_duration: float = 32.0
var active_minions: Array = []
const MINION_SCENE = preload("res://Entities/Enemies/UndeadMinion/undead_minion.tscn")


@onready var boss: CharacterBody2D = get_parent()
var player: CharacterBody2D = null


var cooldown_timer: float = 0.0
var cooldown_duration: float = 0.0
var teleports_remaining: int = 0
var is_striking: bool = false
var attack_has_damaged: bool = false
var is_backing_away: bool = false
var has_hit_during_combo: bool = false

func _ready() -> void:
	add_to_group("boss")

	play("idle")


	if sprite_frames:
		sprite_frames.set_animation_loop("attack", false)
		sprite_frames.set_animation_loop("skill1", false)


	_find_player()


	frame_changed.connect(_on_frame_changed)
	animation_finished.connect(_on_animation_finished)


func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player")
	if not player:

		var parent_node = boss.get_parent()
		if parent_node:
			for child in parent_node.get_children():
				if child is CharacterBody2D and child != boss and child.has_method("take_hit"):
					player = child
					break

func _physics_process(delta: float) -> void:

	if not player:
		_find_player()
		return


	if cooldown_timer > 0:
		cooldown_timer -= delta


	if summon_cooldown_timer > 0:
		summon_cooldown_timer -= delta

	match current_state:
		State.IDLE:

			boss.velocity = Vector2.ZERO
			play("idle")

			var dist = _get_visual_dist_to_player()

			flip_h = (player.global_position.x < boss.global_position.x)


			if summon_cooldown_timer <= 0:
				_clean_active_minions()
				if active_minions.size() < 2:
					start_summon()
					return


			if cooldown_timer <= 0:
				var is_player_far = (dist > 150.0)
				var is_player_passive = (player.current_state == 4)


				if dist >= 180.0 and randf() < 0.35:
					start_vanish_sweep()

				elif dist >= 120.0 and dist <= 240.0 and randf() < 0.45:
					start_dash_attack()
				elif is_player_far or is_player_passive:

					start_teleport_attack()
				elif dist <= attack_range:

					start_raw_attack()


			if dist > attack_range and (cooldown_timer > 0 or (dist <= 150.0 and player.current_state != 4)) and summon_cooldown_timer > 0:
				current_state = State.CHASE


			elif dist <= attack_range and cooldown_timer <= 0:
				start_raw_attack()

		State.CHASE:

			var to_player = (player.global_position - boss.global_position)
			var dist = _get_visual_dist_to_player()


			flip_h = (player.global_position.x < boss.global_position.x)


			if summon_cooldown_timer <= 0:
				_clean_active_minions()
				if active_minions.size() < 2:
					boss.velocity = Vector2.ZERO
					start_summon()
					return


			if cooldown_timer <= 0:
				var is_player_far = (dist > 150.0)
				var is_player_passive = (player.current_state == 4)

				if dist >= 180.0 and randf() < 0.35:
					boss.velocity = Vector2.ZERO
					start_vanish_sweep()
					return
				elif dist >= 120.0 and dist <= 240.0 and randf() < 0.45:
					boss.velocity = Vector2.ZERO
					start_dash_attack()
					return
				elif is_player_far or is_player_passive:
					boss.velocity = Vector2.ZERO
					start_teleport_attack()
					return

			if dist <= attack_range:

				if dist > 70.0:
					play("idle2")
					boss.velocity = to_player.normalized() * speed
					boss.move_and_slide()
				else:
					boss.velocity = Vector2.ZERO
					if cooldown_timer <= 0:
						start_raw_attack()
					else:
						current_state = State.IDLE
			else:

				play("idle2")
				boss.velocity = to_player.normalized() * speed
				boss.move_and_slide()

		State.TELEPORT_ATTACK:

			boss.velocity = Vector2.ZERO
			boss.move_and_slide()

		State.RAW_ATTACK:

			boss.velocity = Vector2.ZERO
			boss.move_and_slide()

		State.DASH_ATTACK:

			boss.velocity = Vector2.ZERO
			boss.move_and_slide()

		State.VANISH_SWEEP:

			boss.velocity = Vector2.ZERO
			boss.move_and_slide()

		State.SUMMON:

			boss.velocity = Vector2.ZERO
			boss.move_and_slide()

		State.COOLDOWN:

			if is_backing_away:

				play("idle2")
				var back_dir = (boss.global_position - player.global_position).normalized()
				boss.velocity = back_dir * (speed * 1.5)
				boss.move_and_slide()


				flip_h = (player.global_position.x < boss.global_position.x)
			else:

				var dist = _get_visual_dist_to_player()
				if dist < 75.0:
					var back_dir = (boss.global_position - player.global_position).normalized()
					boss.velocity = back_dir * (speed * 0.5)
					boss.move_and_slide()
				else:
					boss.velocity = Vector2.ZERO

				play("idle")


				flip_h = (player.global_position.x < boss.global_position.x)

			cooldown_duration -= delta
			if cooldown_duration <= 0:
				is_backing_away = false
				current_state = State.IDLE


func start_raw_attack() -> void:
	current_state = State.RAW_ATTACK
	is_striking = true
	attack_has_damaged = false


	flip_h = (player.global_position.x < boss.global_position.x)


	play("attack")


func start_dash_attack() -> void:
	current_state = State.DASH_ATTACK
	is_striking = true
	attack_has_damaged = false


	flip_h = (player.global_position.x < boss.global_position.x)


	play("attack")
	speed_scale = 0.85



func start_vanish_sweep() -> void:
	current_state = State.VANISH_SWEEP
	is_striking = true

	for sweep_index in range(4):
		if current_state != State.VANISH_SWEEP or not player:
			break

		attack_has_damaged = false


		var fade_tween = create_tween()
		fade_tween.tween_property(self, "modulate:a", 0.0, 0.15)
		await fade_tween.finished

		if current_state != State.VANISH_SWEEP or not player:
			break



		var sweep_angle = randf_range(0.0, 2.0 * PI)
		var start_offset = Vector2.from_angle(sweep_angle) * 350.0
		var start_pos = player.global_position + start_offset
		var target_pos = player.global_position - start_offset.normalized() * 250.0


		boss.global_position = start_pos


		flip_h = (player.global_position.x < boss.global_position.x)


		var warning_line = Line2D.new()
		boss.get_parent().add_child(warning_line)

		warning_line.width = 90.0
		warning_line.default_color = Color(2.0, 0.2, 0.2, 0.10)
		warning_line.points = [start_pos, target_pos]


		var warning_tween = create_tween().set_loops(3)
		warning_tween.tween_property(warning_line, "default_color:a", 0.85, 0.08)
		warning_tween.tween_property(warning_line, "default_color:a", 0.10, 0.08)


		await get_tree().create_timer(0.5).timeout


		warning_line.queue_free()

		if current_state != State.VANISH_SWEEP or not player:
			break


		modulate.a = 1.0
		play("attack")
		speed_scale = 2.5


		var dash_tween = create_tween()
		dash_tween.tween_property(boss, "global_position", target_pos, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


		var start_time = Time.get_ticks_msec()
		while Time.get_ticks_msec() - start_time < 200:
			if not is_instance_valid(player) or attack_has_damaged:
				break

			if boss.global_position.distance_to(player.global_position) < 115.0:
				var is_player_rolling = (player.current_state == 3)
				if not is_player_rolling and not player.is_invincible:
					attack_has_damaged = true
					player.take_hit(boss.global_position, 480.0)
			await get_tree().process_frame


		await get_tree().create_timer(0.15).timeout


	modulate.a = 1.0
	is_striking = false
	speed_scale = 1.0
	cooldown_timer = skill_cooldown * 2.2
	current_state = State.COOLDOWN
	cooldown_duration = 1.2
	is_backing_away = false


func start_teleport_attack() -> void:
	current_state = State.TELEPORT_ATTACK

	teleports_remaining = randi_range(1, 4)
	has_hit_during_combo = false


	modulate.a = 0.0
	await get_tree().create_timer(0.15).timeout
	modulate.a = 1.0

	perform_next_teleport()


func perform_next_teleport() -> void:
	if not player:
		current_state = State.IDLE
		return

	if teleports_remaining <= 0:

		cooldown_timer = skill_cooldown
		current_state = State.COOLDOWN




		if not has_hit_during_combo:
			cooldown_duration = 0.8
			is_backing_away = true
		else:

			cooldown_duration = randf_range(0.25, 0.5)
			is_backing_away = false

		return

	teleports_remaining -= 1
	is_striking = true
	attack_has_damaged = false



	var is_left = (randf() < 0.5)
	var angle_offset = randf_range(-PI / 6, PI / 6)
	var random_angle = (PI + angle_offset) if is_left else (0.0 + angle_offset)
	var target_pos = player.global_position + Vector2.from_angle(random_angle) * teleport_distance


	boss.global_position = target_pos


	flip_h = (player.global_position.x < boss.global_position.x)


	modulate = Color(1.5, 1.2, 2.0, 1.0)


	play("attack")


	get_tree().create_timer(0.1).timeout.connect(func(): modulate = Color(1.0, 1.0, 1.0, 1.0))


func start_summon() -> void:
	current_state = State.SUMMON

	play("skill1")
	summon_cooldown_timer = summon_cooldown_duration


func spawn_minions() -> void:
	_clean_active_minions()
	var spawn_slots = [
		Vector2(-55, 15),
		Vector2(55, 15)
	]

	for slot in spawn_slots:
		if active_minions.size() >= 2:
			break
		var minion = MINION_SCENE.instantiate()
		minion.global_position = boss.global_position + slot


		var parent = boss.get_parent()
		if parent:
			parent.add_child(minion)
		else:
			get_tree().current_scene.add_child(minion)

		active_minions.append(minion)


func _clean_active_minions() -> void:
	var alive = []
	for minion in active_minions:
		if is_instance_valid(minion) and not minion.is_queued_for_deletion():
			alive.append(minion)
	active_minions = alive


func take_hit(source_position: Vector2, _knockback_force: float = 0.0) -> void:

	modulate = Color(2.5, 0.5, 0.5, 1.0)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)


func _on_frame_changed() -> void:
	if animation == "skill1" and current_state == State.SUMMON:

		if frame == 6:
			spawn_minions()

	elif animation == "attack" and frame == 1 and current_state == State.DASH_ATTACK:
		pause()


		modulate = Color(2.5, 1.2, 0.4, 1.0)

		if player:
			var target_dir = (player.global_position - boss.global_position).normalized()


			await get_tree().create_timer(0.4).timeout

			if current_state == State.DASH_ATTACK:
				modulate = Color(1.0, 1.0, 1.0, 1.0)


				play("attack")
				speed_scale = 2.2



				var dash_target = player.global_position + target_dir * 30.0
				var tween = create_tween()
				tween.tween_property(boss, "global_position", dash_target, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	elif animation == "attack" and is_striking and not attack_has_damaged:

		if frame >= 6 and frame <= 9:
			if player:

				var check_range = hit_box_range * 1.2 if current_state == State.DASH_ATTACK else hit_box_range
				var to_player_visual = _get_visual_vector_to_player()
				var dist = to_player_visual.length()


				var facing_dir = Vector2.LEFT if flip_h else Vector2.RIGHT


				var dot_product = facing_dir.dot(to_player_visual.normalized())


				var required_dot = -0.3 if current_state == State.DASH_ATTACK else -0.1

				if dot_product >= required_dot and dist <= check_range:
					var is_player_rolling = (player.current_state == 3)

					if not is_player_rolling:
						attack_has_damaged = true
						has_hit_during_combo = true


						if not player.is_invincible:
							player.take_hit(boss.global_position, 400.0 if current_state == State.DASH_ATTACK else 350.0)


func _on_animation_finished() -> void:
	if animation == "skill1" and current_state == State.SUMMON:
		current_state = State.COOLDOWN
		cooldown_duration = 0.6

	elif animation == "attack":
		if current_state == State.TELEPORT_ATTACK:
			is_striking = false


			var tween = create_tween()
			tween.tween_property(self, "modulate:a", 0.0, 0.1)


			await get_tree().create_timer(0.25).timeout


			modulate.a = 1.0
			if current_state == State.TELEPORT_ATTACK:
				perform_next_teleport()

		elif current_state == State.RAW_ATTACK or current_state == State.DASH_ATTACK:
			is_striking = false
			speed_scale = 1.0

			if current_state == State.DASH_ATTACK:

				cooldown_timer = skill_cooldown * 0.95
				current_state = State.COOLDOWN
				cooldown_duration = 0.8
				is_backing_away = false
			else:

				if not attack_has_damaged:
					cooldown_timer = skill_cooldown * 0.5
					current_state = State.COOLDOWN
					cooldown_duration = 0.8
					is_backing_away = true
				else:

					cooldown_timer = skill_cooldown * 0.4
					current_state = State.COOLDOWN
					cooldown_duration = randf_range(0.25, 0.5)


func _get_visual_dist_to_player() -> float:
	if not player:
		return 9999.0
	var diff = player.global_position - boss.global_position

	var diff_visual = Vector2(diff.x, diff.y * 0.6)
	return diff_visual.length()


func _get_visual_vector_to_player() -> Vector2:
	if not player:
		return Vector2.ZERO
	var diff = player.global_position - boss.global_position
	return Vector2(diff.x, diff.y * 0.6)
