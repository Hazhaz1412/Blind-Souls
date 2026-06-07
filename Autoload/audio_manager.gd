extends Node

var bgm_player: AudioStreamPlayer = null
var current_bgm_path: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Music"
	add_child(bgm_player)


func play_bgm(music_path: String, volume_db: float = 0.0, loop: bool = true) -> void:
	if current_bgm_path == music_path:
		return

	var stream = load(music_path)
	if stream:
		bgm_player.stop()
		bgm_player.stream = stream
		bgm_player.volume_db = volume_db
		bgm_player.play()
		current_bgm_path = music_path
	else:
		print("Không thể tải nhạc nền: ", music_path)


func stop_bgm() -> void:
	bgm_player.stop()
	current_bgm_path = ""


func play_sfx(sfx_path: String, volume_db: float = 0.0) -> void:
	var stream = load(sfx_path)
	if stream:
		var sfx_player = AudioStreamPlayer.new()
		sfx_player.stream = stream
		sfx_player.volume_db = volume_db
		sfx_player.bus = "SFX"
		add_child(sfx_player)
		sfx_player.play()


		sfx_player.finished.connect(func():
			sfx_player.queue_free()
		)
	else:
		print("Không thể tải âm thanh SFX: ", sfx_path)
