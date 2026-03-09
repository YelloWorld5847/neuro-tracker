extends Node

signal round_result(won: bool)

const SAVE_PATH := "user://settings.cfg"

var settings := {
	"total_balls": 8,
	"target_balls": 2,
	"show_duration": 3.0,
	"move_duration": 5.0,
	"camera_rotate_duration": 4.0,
	"total_rounds": 10,
	"base_speed": 1.0,
	"depth_ratio": 0.35,
}

var current_round: int = 0
var speed_level: float = 1.0
var speed_append: float = 0.3
var rounds_won: Array[bool] = []
var current_phase: String = "menu"
var win_streak: int = 0

var target_ball_ids: Array[int] = []
var selected_ball_ids: Array[int] = []


func _ready() -> void:
	load_settings()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in settings:
		cfg.set_value("settings", key, settings[key])
	cfg.save(SAVE_PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for key in settings:
		if cfg.has_section_key("settings", key):
			settings[key] = cfg.get_value("settings", key)


func reset_game() -> void:
	current_round = 0
	speed_level = 1.0
	rounds_won.clear()
	target_ball_ids.clear()
	selected_ball_ids.clear()
	current_phase = "menu"


func start_round() -> void:
	current_round += 1
	selected_ball_ids.clear()
	target_ball_ids.clear()


func get_current_speed() -> float:
	return settings["base_speed"] * speed_level


func record_result_with_errors(won: bool, errors: int) -> void:
	rounds_won.append(won)
	if won:
		set_win_streak(true)
		speed_level = minf(speed_level + (speed_append * win_streak), 5.0)
	else:
		set_win_streak(false)
		var target_count: int = settings["target_balls"]
		var ratio: float = float(errors) / float(max(target_count, 1))
		var penalty: float = 0.05 + ratio * 0.20
		speed_level = maxf(speed_level - penalty, 0.5)
	round_result.emit(won)


func record_result(won: bool) -> void:
	record_result_with_errors(won, 0 if won else 1)


func is_game_over() -> bool:
	return current_round >= settings["total_rounds"]


func get_score() -> int:
	return rounds_won.count(true)

func set_win_streak(result: bool):
	if result == true:
		win_streak += 1
	else:
		win_streak = 0
