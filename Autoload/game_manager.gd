extends Node


enum GameState { MENU, PLAYING, PAUSED, GAME_OVER }
var current_state: GameState = GameState.MENU


var player: CharacterBody2D = null


var target_spawn_id: String = ""


var inventory: Array[String] = []
var quest_progress: Dictionary = {}
var world_state: Dictionary = {}
var defeated_enemies: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.player_spawned.connect(_on_player_spawned)
	EventBus.player_died.connect(_on_player_died)

func _on_player_spawned(player_node: CharacterBody2D) -> void:
	player = player_node
	current_state = GameState.PLAYING


	if target_spawn_id != "":
		var spawn_points = get_tree().get_nodes_in_group("spawn_points")
		var found_spawn = false

		for sp in spawn_points:
			if "spawn_id" in sp and sp.spawn_id == target_spawn_id:

				player.global_position = sp.global_position
				print("🧠 GameManager: Đã định vị Player tại SpawnPoint ID: ", target_spawn_id)
				found_spawn = true
				break

		if not found_spawn:
			print("🧠 GameManager Cảnh báo: Không tìm thấy SpawnPoint nào có ID: ", target_spawn_id)


		target_spawn_id = ""

func _on_player_died() -> void:
	current_state = GameState.GAME_OVER


func toggle_pause() -> void:
	if current_state == GameState.PLAYING:
		get_tree().paused = true
		current_state = GameState.PAUSED
	elif current_state == GameState.PAUSED:
		get_tree().paused = false
		current_state = GameState.PLAYING


func transition_to_level(level_path: String) -> void:
	EventBus.level_transition_started.emit(level_path)


	get_tree().paused = true


	await get_tree().create_timer(0.5).timeout


	var error = get_tree().change_scene_to_file(level_path)
	if error == OK:
		get_tree().paused = false
		var level_name = level_path.get_file().get_basename()
		EventBus.level_transition_completed.emit(level_name)
	else:
		print("Lỗi chuyển màn: ", error)
		get_tree().paused = false
