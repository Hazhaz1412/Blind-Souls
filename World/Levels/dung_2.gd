extends Node2D

func _ready() -> void:

	if GameManager.world_state.get("lever_pulled", false):
		print("🧠 GameManager: Phát hiện cần gạt đã kích hoạt. Tiến hành gỡ bỏ TrapGai...")


		var trap = get_node_or_null("Sprite2D/TrapGai")
		if not trap:
			trap = get_node_or_null("Sprite2D/StaticBody2D2")
		if not trap:
			trap = find_child("TrapGai")

		if trap:
			trap.queue_free()
			print("🧠 [Hệ thống]: TrapGai đã được gỡ bỏ an toàn.")
		else:
			print("Cảnh báo: Không tìm thấy node TrapGai hoặc StaticBody2D2 trong scene để xóa!")
