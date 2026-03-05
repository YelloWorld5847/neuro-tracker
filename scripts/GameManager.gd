extends Node

#  Signaux 
signal round_result(won: bool)

#  Paramètres (modifiables dans les options) 
var settings := {
	"total_balls": 8,
	"target_balls": 2,        # nombre de balles à mémoriser
	"show_duration": 3.0,     # secondes d'affichage des cibles
	"move_duration": 5.0,     # secondes de mouvement
	"camera_rotate_duration": 4.0,
	"total_rounds": 10,
	"base_speed": 1.0,      # vitesse de base des balles
	"depth_ratio": 0.35,      # rapport mouvement profondeur vs XY
}

#  État de jeu 
var current_round: int = 0
var speed_level: float = 1.0
var rounds_won: Array[bool] = []
var current_phase: String = "menu"  # menu / show / move / rotate / select / result

var target_ball_ids: Array[int] = []
var selected_ball_ids: Array[int] = []

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

func record_result(won: bool) -> void:
	rounds_won.append(won)
	if won:
		speed_level = minf(speed_level + 0.2, 3.0)
	else:
		speed_level = maxf(speed_level - 0.15, 0.5)
	round_result.emit(won)

func is_game_over() -> bool:
	return current_round >= settings["total_rounds"]

func get_score() -> int:
	return rounds_won.count(true)
