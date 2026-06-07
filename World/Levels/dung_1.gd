extends Node2D

const DIALOGUE_BOX_SCENE = preload("res://UI/Dialogue/DialogueBox.tscn")

var bruna_npc: CharacterBody2D = null

func _ready() -> void:

	bruna_npc = get_node_or_null("Bruna")
	if not bruna_npc:
		bruna_npc = find_child("Bruna")


	if GameManager.world_state.get("dung_1_bruna_event_completed", false):
		print("🧠 GameManager: Sự kiện Bruna đã hoàn thành từ trước. Đang dọn dẹp map...")


		var door = get_node_or_null("PlayerDoor")
		if not door:
			door = get_node_or_null("Sprite2D/PlayerDoor")
		if not door:
			door = find_child("PlayerDoor")
		if door:
			door.queue_free()
			print("🧠 [Hệ thống]: Cửa đã được mở sẵn.")


		if bruna_npc:
			bruna_npc.queue_free()
		return


	if bruna_npc:
		bruna_npc.hide()
		print("Đã tìm thấy Bruna thủ công trong Scene. Ẩn chuẩn bị spawn...")
	else:
		print("Cảnh báo: Chưa kéo thả node Bruna vào màn chơi dung_1!")

	print("Màn chơi khởi động. Chờ 3 giây...")

	await get_tree().create_timer(3.0).timeout

	start_bruna_walk_in()

func start_bruna_walk_in() -> void:
	if not is_instance_valid(bruna_npc):
		print("Không tìm thấy node Bruna hợp lệ để chạy cutscene!")
		return

	print("Bắt đầu di chuyển Bruna từ góc phải vào...")


	var player = get_tree().get_first_node_in_group("player")
	var player_pos = Vector2(-271, -197)
	if player:
		player_pos = player.global_position


	var spawn_point = find_child("SpawnPoint_FromDung2")
	if spawn_point:
		bruna_npc.global_position = spawn_point.global_position
		print("Spawn Bruna tại vị trí: ", spawn_point.global_position)

	bruna_npc.show()


	var target_pos = Vector2(player_pos.x + 60, bruna_npc.global_position.y)
	bruna_npc.walk_to(target_pos)


	if not bruna_npc.arrived.is_connected(_on_bruna_arrived):
		bruna_npc.arrived.connect(_on_bruna_arrived)

func _on_bruna_arrived() -> void:
	print("Bruna đã đi tới đích! Bắt đầu hội thoại...")
	trigger_dialogue()

func trigger_dialogue() -> void:

	var bruna_avatar = AtlasTexture.new()
	bruna_avatar.atlas = load("res://Entities/NPC/Bruna/Assets/SeveredFangIdle001-Sheet.png")
	bruna_avatar.region = Rect2(0, 0, 128, 128)


	var lines: Array[Dictionary] = [
		{
			"name": "Bruna",
			"text": "Chào cậu, tôi là Bruna. Đội trưởng đội kỵ sĩ, theo lệnh của đức vua ân xá thì tôi đến để giải thoát cho cậu!",
			"avatar": bruna_avatar
		},
		{
			"name": "Bruna",
			"text": "Sau khi có được tự do, nhiệm vụ của cậu là đi tìm và giải cứu công chúa.",
			"avatar": bruna_avatar
		},
		{
			"name": "Bruna",
			"text": "Tôi sẽ mở cửa ngay bây giờ, hành trình phía trước hãy bảo trọng nhé.",
			"avatar": bruna_avatar
		}
	]


	var dialogue_box = DIALOGUE_BOX_SCENE.instantiate()
	add_child(dialogue_box)


	dialogue_box.start_dialogue(lines)


	dialogue_box.line_displayed.connect(func(idx: int):
		if idx == lines.size() - 1:

			dialogue_box.next_line_allowed = false


			start_door_opening_sequence(dialogue_box)
	)


	dialogue_box.dialogue_finished.connect(func():

		dialogue_box.queue_free()
		print("Hội thoại kết thúc hoàn toàn. Người chơi bắt đầu di chuyển.")
	)

func start_door_opening_sequence(dialogue_box: CanvasLayer) -> void:

	if bruna_npc.arrived.is_connected(_on_bruna_arrived):
		bruna_npc.arrived.disconnect(_on_bruna_arrived)


	var door = get_node_or_null("PlayerDoor")
	if not door:
		door = get_node_or_null("Sprite2D/PlayerDoor")
	if not door:
		door = find_child("PlayerDoor")

	if door:
		print("Bruna đang đi tới trước rào chắn để mở cửa...")


		var target_x = door.global_position.x
		var sprite = door.find_child("HangRao2")
		if sprite:
			target_x = sprite.global_position.x


		var target_pos = Vector2(target_x + 50, bruna_npc.global_position.y)
		bruna_npc.walk_to(target_pos)


		await bruna_npc.arrived

		print("Bruna đã tới trước rào chắn. Đứng nhìn rào chắn để hóa giải phép thuật...")

		await get_tree().create_timer(1.0).timeout


		door.queue_free()
		print("🧠 [Hệ thống]: Rào chắn PlayerDoor đã được hóa giải! Cửa đã mở.")


		GameManager.world_state["dung_1_bruna_event_completed"] = true


		await get_tree().create_timer(0.5).timeout

	else:

		GameManager.world_state["dung_1_bruna_event_completed"] = true


	await bruna_leave()


	if is_instance_valid(dialogue_box):
		dialogue_box.next_line_allowed = true

func bruna_leave() -> void:
	if not is_instance_valid(bruna_npc):
		return

	print("Bruna đang rời đi về phía bên phải...")


	bruna_npc.ignore_collision = true


	bruna_npc.walk_to(Vector2(550, bruna_npc.global_position.y))


	await bruna_npc.arrived

	print("Bruna đã rời khỏi bản đồ. Đang giải phóng nhân vật...")
	bruna_npc.queue_free()

