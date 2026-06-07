class_name TransitionTrigger
extends Area2D

@export_file("*.tscn") var target_level_path: String = ""
@export var target_spawn_id: String = ""

func _ready() -> void:

	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:

	if body.is_in_group("player"):
		if target_level_path == "":
			print("Cảnh báo: TransitionTrigger chưa cấu hình target_level_path!")
			return

		print("Player chạm vùng chuyển cảnh! Đi tới: ", target_level_path, " tại spawn_id: ", target_spawn_id)


		GameManager.target_spawn_id = target_spawn_id


		GameManager.transition_to_level(target_level_path)
