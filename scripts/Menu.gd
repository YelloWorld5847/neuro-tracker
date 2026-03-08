extends Control

@onready var btn_play: Button = $VBox/PlayButton
@onready var btn_settings: Button = $VBox/SettingsButton
@onready var btn_quit: Button = $VBox/QuitButton
@onready var settings_panel: Panel = $SettingsPanel
@onready var title_label: Label = $TitleLabel
@onready var subtitle_label: Label = $SubTitle
@onready var vbox: VBoxContainer = $VBox

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
	_adapt_to_screen()
	get_viewport().size_changed.connect(_adapt_to_screen)


func _adapt_to_screen() -> void:
	var sw := get_viewport().get_visible_rect().size.x
	var sh := get_viewport().get_visible_rect().size.y
	var scale_factor: float = min(sw / 1280.0, sh / 720.0)

	title_label.add_theme_font_size_override("font_size", int(52 * scale_factor))
	subtitle_label.add_theme_font_size_override("font_size", int(20 * scale_factor))

	var btn_h := int(60 * scale_factor)
	var btn_w := int(300 * scale_factor)
	var btn_font := int(24 * scale_factor)
	for btn in [btn_play, btn_settings, btn_quit]:
		btn.custom_minimum_size = Vector2(btn_w, btn_h)
		btn.add_theme_font_size_override("font_size", btn_font)
		btn.alignment = HORIZONTAL_ALIGNMENT_CENTER

	vbox.add_theme_constant_override("separation", int(20 * scale_factor))
	var half_w: float = btn_w / 2.0 + 10.0
	vbox.set_anchor(SIDE_LEFT, 0.5)
	vbox.set_anchor(SIDE_RIGHT, 0.5)
	vbox.offset_left = -half_w
	vbox.offset_right = half_w

	var panel_w := int(560 * scale_factor)
	var panel_h := int(560 * scale_factor)
	settings_panel.set_anchor(SIDE_LEFT, 0.5)
	settings_panel.set_anchor(SIDE_RIGHT, 0.5)
	settings_panel.set_anchor(SIDE_TOP, 0.5)
	settings_panel.set_anchor(SIDE_BOTTOM, 0.5)
	settings_panel.offset_left = -panel_w / 2.0
	settings_panel.offset_right = panel_w / 2.0
	settings_panel.offset_top = -panel_h / 2.0
	settings_panel.offset_bottom = panel_h / 2.0

	var lbl_font := int(17 * scale_factor)
	for row_path in [
		"SettingsPanel/VBox/BallsRow/Label",
		"SettingsPanel/VBox/TargetsRow/Label",
		"SettingsPanel/VBox/ShowRow/Label",
		"SettingsPanel/VBox/MoveRow/Label",
		"SettingsPanel/VBox/RoundsRow/Label",
		"SettingsPanel/VBox/SettingsTitle",
	]:
		var node := get_node_or_null(row_path)
		if node:
			node.add_theme_font_size_override("font_size", lbl_font)


func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/GameScene.tscn")


func _on_settings() -> void:
	settings_panel.visible = true


func _on_close_settings() -> void:
	GameManager.settings["total_balls"] = int(spin_balls.value)
	GameManager.settings["target_balls"] = int(spin_targets.value)
	GameManager.settings["show_duration"] = spin_show.value
	GameManager.settings["move_duration"] = spin_move.value
	GameManager.settings["total_rounds"] = int(spin_rounds.value)
	GameManager.save_settings()
	settings_panel.visible = false


func _on_quit() -> void:
	get_tree().quit()


func _load_settings_to_ui() -> void:
	spin_balls.value = GameManager.settings["total_balls"]
	spin_targets.value = GameManager.settings["target_balls"]
	spin_show.value = GameManager.settings["show_duration"]
	spin_move.value = GameManager.settings["move_duration"]
	spin_rounds.value = GameManager.settings["total_rounds"]
