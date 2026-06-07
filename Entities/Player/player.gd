extends CharacterBody2D

@export var speed : float = 300.0
@export var roll_speed : float = 350.0


@export var max_hp: float = 150.0
@export var hp: float = 150.0
@export var max_mana: float = 60.0
@export var mana: float = 60.0
@export var max_stamina: float = 100.0
@export var stamina: float = 100.0

@export var stamina_regen_rate: float = 35.0
@export var mana_regen_rate: float = 6.0

const DASH_EFFECT_SCENE = preload("res://VFX/DashEffect/DashEffect.tscn")
const PARRY_DODGE_VFX_SCENE = preload("res://VFX/ParryDodge/parry_dodge_vfx.tscn")


enum State { NORMAL, ATTACK_1, ATTACK_2, ROLL, HIT, BLOCK }
var current_state: State = State.NORMAL


var combo_next_attack_queued: bool = false


var roll_direction: Vector2 = Vector2.ZERO
var roll_time_elapsed: float = 0.0


var parry_window_timer: float = 0.0
var _time_freeze_active: bool = false


var is_invincible: bool = false


@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D
@onready var sound_manager: Node = $SoundManager


var shake_intensity: float = 0.0
var shake_decay: float = 12.0

func _ready() -> void:
	add_to_group("player")

	_setup_input_actions()


	if animated_sprite.sprite_frames.has_animation("block"):
		animated_sprite.sprite_frames.set_animation_loop("block", true)


	animated_sprite.frame_changed.connect(_on_frame_changed)
	animated_sprite.animation_finished.connect(_on_animation_finished)


	EventBus.player_spawned.emit(self)


	update_camera_limits()
	EventBus.level_transition_completed.connect(func(_level_name): update_camera_limits())


func _setup_input_actions() -> void:
	var actions = {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"roll": [KEY_SPACE, KEY_SHIFT],
		"block": [KEY_F]
	}
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		else:
			InputMap.action_erase_events(action)

		for key in actions[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

func _physics_process(delta: float) -> void:

	if current_state != State.ROLL:
		stamina = min(max_stamina, stamina + stamina_regen_rate * delta)
	mana = min(max_mana, mana + mana_regen_rate * delta)


	if shake_intensity > 0.0:
		shake_intensity = move_toward(shake_intensity, 0.0, shake_decay * delta)
		if camera:
			camera.offset = Vector2(
				randf_range(-shake_intensity, shake_intensity),
				randf_range(-shake_intensity, shake_intensity)
			)
		if shake_intensity <= 0.0 and camera:
			camera.offset = Vector2.ZERO

	if current_state == State.NORMAL:

		var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")

		if direction != Vector2.ZERO:
			velocity = direction * speed

			animated_sprite.play("run")


			if direction.x < 0:
				animated_sprite.flip_h = true
			elif direction.x > 0:
				animated_sprite.flip_h = false
		else:
			velocity = velocity.move_toward(Vector2.ZERO, speed)

			animated_sprite.play("idle")
	elif current_state == State.ROLL:

		velocity = roll_direction * roll_speed
		roll_time_elapsed += delta
	elif current_state == State.BLOCK:

		velocity = Vector2.ZERO
		if parry_window_timer > 0.0:
			parry_window_timer -= delta


		if not Input.is_action_pressed("block"):
			current_state = State.NORMAL
			animated_sprite.play("idle")
	elif current_state == State.HIT:

		pass
	else:

		velocity = velocity.move_toward(Vector2.ZERO, speed * 2)

	move_and_slide()

func _input(event: InputEvent) -> void:

	if event.is_action_pressed("roll"):
		if current_state == State.NORMAL or current_state == State.BLOCK:

			if stamina >= 25.0:
				stamina -= 25.0
				current_state = State.ROLL
				is_invincible = true
				roll_time_elapsed = 0.0



				var move_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
				if move_dir != Vector2.ZERO:
					roll_direction = move_dir.normalized()
				else:
					roll_direction = Vector2.LEFT if animated_sprite.flip_h else Vector2.RIGHT


				animated_sprite.play("roll")
				_spawn_dash_effect()
				if sound_manager:
					sound_manager.play_dash()


				if roll_direction.x < 0:
					animated_sprite.flip_h = true
				elif roll_direction.x > 0:
					animated_sprite.flip_h = false

				return


	if event.is_action_pressed("block"):
		if current_state == State.NORMAL:
			current_state = State.BLOCK
			parry_window_timer = 0.20
			animated_sprite.play("block")
			return


	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if current_state == State.NORMAL or current_state == State.BLOCK:

			if stamina >= 15.0:
				stamina -= 15.0
				current_state = State.ATTACK_1
				combo_next_attack_queued = false
				animated_sprite.play("attack")
				animated_sprite.frame = 0
				if sound_manager:
					sound_manager.play_sword_1()
		elif current_state == State.ATTACK_1:


			combo_next_attack_queued = true


func take_hit(source_position: Vector2, knockback_force: float = 500.0) -> void:

	if current_state == State.ROLL:
		if roll_time_elapsed <= 0.15:
			_trigger_perfect_dodge()
		return


	if current_state == State.BLOCK:

		var facing_dir = Vector2.LEFT if animated_sprite.flip_h else Vector2.RIGHT

		var to_attacker = (source_position - global_position).normalized()



		var dot_product = facing_dir.dot(to_attacker)

		if dot_product >= 0.38:
			if parry_window_timer > 0.0:
				_trigger_parry()
			else:
				_trigger_normal_block()
			return




	if is_invincible:
		return


	hp = max(0.0, hp - 25.0)
	if hp <= 0.0:
		_handle_player_death()
		return


	current_state = State.HIT
	is_invincible = true


	var knockback_direction = (global_position - source_position).normalized()
	if knockback_direction == Vector2.ZERO:
		knockback_direction = Vector2.LEFT if animated_sprite.flip_h else Vector2.RIGHT


	velocity = knockback_direction * knockback_force


	if animated_sprite.sprite_frames.has_animation("get_hit"):
		animated_sprite.play("get_hit")


	_flash_invincibility(1.0)


	await get_tree().create_timer(0.2).timeout
	if current_state == State.HIT:
		current_state = State.NORMAL
		animated_sprite.play("idle")


	await get_tree().create_timer(0.8).timeout
	is_invincible = false


func _flash_invincibility(duration: float) -> void:
	var flash_timer = 0.0
	var flash_interval = 0.1
	while flash_timer < duration:
		if not is_invincible:
			break

		animated_sprite.modulate.a = 0.3 if animated_sprite.modulate.a == 1.0 else 1.0
		await get_tree().create_timer(flash_interval).timeout
		flash_timer += flash_interval
	animated_sprite.modulate.a = 1.0

func _handle_player_death() -> void:
	print("Player Died! Đang tải lại màn chơi...")
	current_state = State.HIT
	is_invincible = true
	velocity = Vector2.ZERO
	if animated_sprite.sprite_frames.has_animation("get_hit"):
		animated_sprite.play("get_hit")


	await get_tree().create_timer(1.5).timeout
	get_tree().reload_current_scene()



func _trigger_perfect_dodge() -> void:

	_spawn_parry_dodge_vfx()

	_trigger_time_freeze(0.25, 0.2)
	print("Perfect Dodge!")

func _trigger_parry() -> void:

	_spawn_parry_dodge_vfx()

	_trigger_time_freeze(0.15, 0.35)
	if sound_manager:
		sound_manager.play_sword_critical()
	print("Parry!")

func _trigger_normal_block() -> void:

	stamina = max(0.0, stamina - 15.0)
	var block_knockback = Vector2.RIGHT if animated_sprite.flip_h else Vector2.LEFT
	velocity = block_knockback * 150.0
	move_and_slide()
	print("Normal Block!")

func _spawn_parry_dodge_vfx() -> void:
	if not PARRY_DODGE_VFX_SCENE:
		return
	var vfx = PARRY_DODGE_VFX_SCENE.instantiate()

	vfx.global_position = global_position + Vector2(0, -10)

	vfx.flip_h = animated_sprite.flip_h

	var parent = get_parent()
	if parent:
		parent.add_child(vfx)
	else:
		get_tree().current_scene.add_child(vfx)

func _trigger_time_freeze(time_scale: float, duration: float) -> void:
	if _time_freeze_active:
		return
	_time_freeze_active = true
	Engine.time_scale = time_scale

	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_time_freeze_active = false

func _perform_sword_hit_sweep() -> void:

	var attack_range: float = 85.0


	var facing_dir = Vector2.LEFT if animated_sprite.flip_h else Vector2.RIGHT


	var targets = []
	targets.append_array(get_tree().get_nodes_in_group("enemies"))
	targets.append_array(get_tree().get_nodes_in_group("boss"))

	var hit_connected: bool = false
	for target in targets:
		if target == self or not is_instance_valid(target):
			continue


		var diff = target.global_position - global_position
		var diff_visual = Vector2(diff.x, diff.y * 0.6)
		var dist = diff_visual.length()


		var dot = facing_dir.dot(diff_visual.normalized())

		if dist <= attack_range and dot >= 0.1:
			if target.has_method("take_hit"):

				target.take_hit(global_position, 280.0)
				hit_connected = true

	if hit_connected:

		shake_intensity = 3.5
		_trigger_time_freeze(0.04, 0.06)

func _on_frame_changed() -> void:
	if animated_sprite.animation == "attack":
		if current_state == State.ATTACK_1:

			if animated_sprite.frame == 2:
				_perform_sword_hit_sweep()

			elif animated_sprite.frame == 5:
				if combo_next_attack_queued and stamina >= 15.0:
					stamina -= 15.0

					current_state = State.ATTACK_2
					combo_next_attack_queued = false

					if sound_manager:
						sound_manager.play_sword_2()
				else:

					current_state = State.NORMAL
					animated_sprite.play("idle")
		elif current_state == State.ATTACK_2:

			if animated_sprite.frame == 8:
				_perform_sword_hit_sweep()

			elif animated_sprite.frame == 0:
				current_state = State.NORMAL
				animated_sprite.play("idle")
	elif animated_sprite.animation == "roll":


		if animated_sprite.frame == 9:
			is_invincible = false

		elif animated_sprite.frame == 11:
			current_state = State.NORMAL
			is_invincible = false
			animated_sprite.play("idle")

func _on_animation_finished() -> void:

	if animated_sprite.animation == "attack" or animated_sprite.animation == "roll":
		current_state = State.NORMAL
		is_invincible = false
		animated_sprite.play("idle")


func _spawn_dash_effect() -> void:
	if not DASH_EFFECT_SCENE:
		return
	var effect = DASH_EFFECT_SCENE.instantiate()
	var parent = get_parent()
	if parent:
		parent.add_child(effect)
	else:
		get_tree().current_scene.add_child(effect)



	var offset_dist = 24.0
	effect.global_position = global_position - roll_direction * offset_dist + Vector2(0, 10)
	effect.flip_h = animated_sprite.flip_h


func update_camera_limits() -> void:
	if not is_inside_tree() or not camera:
		return


	await get_tree().process_frame

	if not is_inside_tree():
		return


	var limit_nodes = get_tree().get_nodes_in_group("camera_limit")
	if limit_nodes.size() > 0:
		var limit_node = limit_nodes[0]
		if limit_node is Sprite2D:
			_set_camera_limits_from_sprite(limit_node)
			return
		elif limit_node is ReferenceRect:
			camera.limit_left = int(limit_node.global_position.x)
			camera.limit_top = int(limit_node.global_position.y)
			camera.limit_right = int(limit_node.global_position.x + limit_node.size.x * limit_node.global_scale.x)
			camera.limit_bottom = int(limit_node.global_position.y + limit_node.size.y * limit_node.global_scale.y)
			print("📸 Camera: Đã cập nhật giới hạn từ ReferenceRect")
			return


	var current_scene = get_tree().current_scene
	if not current_scene:
		return

	var map_sprite = _find_map_sprite(current_scene)
	if map_sprite:
		_set_camera_limits_from_sprite(map_sprite)

func _find_map_sprite(node: Node) -> Sprite2D:
	if node is Sprite2D and node.texture != null:

		if node.texture.get_width() > 200:
			return node
	for child in node.get_children():
		var found = _find_map_sprite(child)
		if found:
			return found
	return null

func _set_camera_limits_from_sprite(sprite: Sprite2D) -> void:
	var texture = sprite.texture
	if not texture:
		return

	var sprite_size = texture.get_size() * sprite.scale

	if sprite.centered:
		camera.limit_left = int(sprite.global_position.x - sprite_size.x / 2)
		camera.limit_top = int(sprite.global_position.y - sprite_size.y / 2)
		camera.limit_right = int(sprite.global_position.x + sprite_size.x / 2)
		camera.limit_bottom = int(sprite.global_position.y + sprite_size.y / 2)
	else:
		camera.limit_left = int(sprite.global_position.x)
		camera.limit_top = int(sprite.global_position.y)
		camera.limit_right = int(sprite.global_position.x + sprite_size.x)
		camera.limit_bottom = int(sprite.global_position.y + sprite_size.y)

	print("📸 Camera: Tự động giới hạn theo Sprite2D (", sprite.name, "): ",
		  "L:", camera.limit_left, " T:", camera.limit_top,
		  " R:", camera.limit_right, " B:", camera.limit_bottom)
