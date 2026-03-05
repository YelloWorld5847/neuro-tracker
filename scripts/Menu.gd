extends Control

@onready var btn_play: Button = $VBox/PlayButton
@onready var btn_settings: Button = $VBox/SettingsButton
@onready var btn_quit: Button = $VBox/QuitButton
@onready var settings_panel: Panel = $SettingsPanel

# Spinbox refs
@onready var spin_balls: SpinBox = $SettingsPanel/VBox/BallsRow/SpinBox
@onready var spin_targets: SpinBox = $SettingsPanel/VBox/TargetsRow/SpinBox
@onready var spin_show: SpinBox = $SettingsPanel/VBox/ShowRow/SpinBox
@onready var spin_move: SpinBox = $SettingsPanel/VBox/MoveRow/SpinBox
@onready var spin_rounds: SpinBox = $SettingsPanel/VBox/RoundsRow/SpinBox
@onready var btn_close_settings: Button = $SettingsPanel/VBox/CloseButton

func _ready() -> void:
	btn_play.pressed.connect(_on_play)
	btn_settings.pressed.connect(_on_settings)
	btn_quit.pressed.connect(_on_quit)
	btn_close_settings.pressed.connect(_on_close_settings)
	settings_panel.visible = false
	_load_settings_to_ui()

func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/GameScene.tscn")

func _on_settings() -> void:
	settings_panel.visible = true

func _on_close_settings() -> void:
	# Sauvegarde les paramètres
	GameManager.settings["total_balls"] = int(spin_balls.value)
	GameManager.settings["target_balls"] = int(spin_targets.value)
	GameManager.settings["show_duration"] = spin_show.value
	GameManager.settings["move_duration"] = spin_move.value
	GameManager.settings["total_rounds"] = int(spin_rounds.value)
	settings_panel.visible = false

func _on_quit() -> void:
	get_tree().quit()

func _load_settings_to_ui() -> void:
	spin_balls.value = GameManager.settings["total_balls"]
	spin_targets.value = GameManager.settings["target_balls"]
	spin_show.value = GameManager.settings["show_duration"]
	spin_move.value = GameManager.settings["move_duration"]
	spin_rounds.value = GameManager.settings["total_rounds"]
