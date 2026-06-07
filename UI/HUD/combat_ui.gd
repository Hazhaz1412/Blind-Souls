extends CanvasLayer

var player: CharacterBody2D = null

@onready var health_bar: TextureProgressBar = $MarginContainer/HBoxContainer/TextureRect/BarContainer/HealthBar
@onready var mana_bar: TextureProgressBar = $MarginContainer/HBoxContainer/TextureRect/BarContainer/ManaBar
@onready var stamina_bar: TextureProgressBar = $MarginContainer/HBoxContainer/TextureRect/BarContainer/Stamina

func _ready() -> void:

	await get_tree().process_frame

	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
		_setup_ui_bars()
	else:
		push_warning("CombatUI: Không tìm thấy người chơi thuộc nhóm 'player'!")

func _setup_ui_bars() -> void:
	if not player:
		return


	health_bar.max_value = player.max_hp
	mana_bar.max_value = player.max_mana
	stamina_bar.max_value = player.max_stamina


	health_bar.value = player.hp
	mana_bar.value = player.mana
	stamina_bar.value = player.stamina







	health_bar.custom_minimum_size.x = player.max_hp
	mana_bar.custom_minimum_size.x = player.max_mana
	stamina_bar.custom_minimum_size.x = player.max_stamina

	print("CombatUI: Đã thiết lập kích thước thanh tự động thành công! HP=%dpx, Stamina=%dpx, Mana=%dpx" % [player.max_hp, player.max_stamina, player.max_mana])

func _process(delta: float) -> void:
	if not player or not is_instance_valid(player):
		return


	health_bar.value = lerp(health_bar.value, player.hp, 15.0 * delta)
	mana_bar.value = lerp(mana_bar.value, player.mana, 15.0 * delta)
	stamina_bar.value = lerp(stamina_bar.value, player.stamina, 15.0 * delta)
