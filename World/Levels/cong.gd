extends Sprite2D

@export var gate_id: String = "gate_1"
@export var is_open: bool = false

@onready var collision_shape: CollisionShape2D = $StaticBody2D/CollisionShape2D

func _ready() -> void:
	add_to_group("gates")

	is_open = GameManager.world_state.get(gate_id, is_open)

	if is_open:
		set_gate_opened_visuals()
	else:
		set_gate_closed_visuals()

func open_gate() -> void:
	if is_open:
		return

	is_open = true
	GameManager.world_state[gate_id] = true

	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)

	collision_shape.set_deferred("disabled", true)

func close_gate() -> void:
	if not is_open:
		return

	is_open = false
	GameManager.world_state[gate_id] = false

 	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)

	collision_shape.set_deferred("disabled", false)

func set_gate_opened_visuals() -> void:
	modulate.a = 0.0
	collision_shape.disabled = true

func set_gate_closed_visuals() -> void:
	modulate.a = 1.0
	collision_shape.disabled = false
