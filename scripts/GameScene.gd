extends Node3D

# --- Références -----------------------------------------------------------
@onready var balls_container: Node3D = $BallsContainer
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var box_mesh: MeshInstance3D = $BoxMesh

# UI
@onready var ui_phase_label: Label = $UI/PhaseLabel
@onready var ui_speed_label: Label = $UI/SpeedLabel
@onready var ui_timer_bar: ProgressBar = $UI/TimerBar
@onready var ui_confirm_btn: Button = $UI/ConfirmButton
@onready var ui_rounds_panel: VBoxContainer = $UI/RoundsPanel
@onready var ui_pause_btn: Button = $UI/PauseButton
@onready var ui_message: Label = $UI/MessageLabel

#  Variables 
var balls: Array[Node] = []
var _phase_timer: float = 0.0
var _current_phase: String = ""
var _camera_angle: float = 0.0
var _is_paused: bool = false
var _selected_count: int = 0
var _camera_direction: float = 1.0  # 1.0 = sens horaire, -1.0 = anti-horaire
var _camera_returning: bool = false  # true = retour vers angle 0 après confirmation

const BOX_HALF := Vector3(5.0, 4.0, 3.0)
const CAMERA_DISTANCE := 12.0

#  Prêt 
func _ready() -> void:
	GameManager.reset_game()
	_setup_box()
	_spawn_balls()
	_update_rounds_ui()
	ui_confirm_btn.visible = false
	ui_confirm_btn.pressed.connect(_on_confirm_pressed)
	ui_pause_btn.pressed.connect(_on_pause_pressed)
	$UI/BackMenuButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Menu.tscn"))
	ui_message.visible = false
	# Caméra centrée sur la boîte
	camera.position = Vector3(0.0, 0.0, 13.0)
	camera.rotation_degrees = Vector3(0.0, 0.0, 0.0)
	camera_pivot.position = Vector3(0.0, 0.0, 0.0)
	await get_tree().process_frame
	_start_phase_show()

#  Création de la boîte 
func _setup_box() -> void:
	# La boîte transparente est créée via BoxMesh + shader transparent + arêtes
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.6, 0.85, 1.0, 0.08)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.7, 1.0)  # fond dans le jeu
	mat.emission_energy_multiplier = 0.15
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	box_mesh.material_override = mat
	box_mesh.scale = BOX_HALF * 2.0

	# Arêtes visibles via un MeshInstance3D séparé avec WireframeMesh simulé
	_create_box_edges()

func _create_box_edges() -> void:
	var im := ImmediateMesh.new()
	var edge_node := MeshInstance3D.new()
	add_child(edge_node)
	edge_node.mesh = im

	var edge_mat := StandardMaterial3D.new()
	edge_mat.albedo_color = Color(0.8, 0.8, 0.8, 0.9)
	edge_mat.emission_enabled = true
	edge_mat.emission = Color(0.6, 0.7, 0.7)
	edge_mat.emission_energy_multiplier = 1.0
	edge_node.material_override = edge_mat

	var h := BOX_HALF
	var corners := [
		Vector3(-h.x, -h.y, -h.z), Vector3( h.x, -h.y, -h.z),
		Vector3( h.x,  h.y, -h.z), Vector3(-h.x,  h.y, -h.z),
		Vector3(-h.x, -h.y,  h.z), Vector3( h.x, -h.y,  h.z),
		Vector3( h.x,  h.y,  h.z), Vector3(-h.x,  h.y,  h.z),
	]
	var edges := [
		[0,1],[1,2],[2,3],[3,0],  # face avant
		[4,5],[5,6],[6,7],[7,4],  # face arrière
		[0,4],[1,5],[2,6],[3,7],  # connexions
	]

	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for e in edges:
		im.surface_add_vertex(corners[e[0]])
		im.surface_add_vertex(corners[e[1]])
	im.surface_end()

#  Spawn des balles 
func _spawn_balls() -> void:
	for b in balls:
		b.queue_free()
	balls.clear()

	var total: int = GameManager.settings["total_balls"]
	var positions_used: Array[Vector3] = []
	var ball_script := load("res://scripts/Ball.gd")

	for i in total:
		# Crée le RigidBody3D et attache le script Ball
		var ball_node := RigidBody3D.new()
		ball_node.set_script(ball_script)
		balls_container.add_child(ball_node)
		# _ready() de Ball.gd s'est exécuté ici — les enfants existent
		ball_node.setup(i, BOX_HALF)

		var pos := _find_free_position(positions_used, 0.95)
		ball_node.position = pos
		positions_used.append(pos)
		balls.append(ball_node)

		# Pas de connexion ici — la sélection se fait via raycast dans _unhandled_input

func _find_free_position(used: Array[Vector3], min_dist: float) -> Vector3:
	var margin := Vector3(1.0, 1.0, 0.6)
	var half := BOX_HALF - margin
	for _attempt in 100:
		var p := Vector3(
			randf_range(-half.x, half.x),
			randf_range(-half.y, half.y),
			randf_range(-half.z, half.z)
		)
		var ok := true
		for u in used:
			if p.distance_to(u) < min_dist * 2.0:
				ok = false
				break
		if ok:
			return p
	return Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-1, 1))

#  PHASES DU JEU 

func _start_phase_show() -> void:
	_current_phase = "show"
	GameManager.start_round()

	# Choix aléatoire des cibles
	var indices: Array[int] = []
	for n in balls.size():
		indices.append(n)
	indices.shuffle()
	var target_count: int = GameManager.settings["target_balls"]
	GameManager.target_ball_ids.clear()
	for n in target_count:
		GameManager.target_ball_ids.append(indices[n])

	for b in balls:
		b.set_state_normal()
	for id in GameManager.target_ball_ids:
		balls[id].set_state_target()

	_set_phase_label("✦ MÉMORISE LES BALLES ✦")
	ui_confirm_btn.visible = false
	ui_message.visible = false
	_phase_timer = GameManager.settings["show_duration"]
	_update_speed_ui()

func _start_phase_move() -> void:
	_current_phase = "move"
	var speed := GameManager.get_current_speed()

	for b in balls:
		b.set_state_normal()
		b.launch(speed)

	_set_phase_label("▶ OBSERVE !")
	_phase_timer = GameManager.settings["move_duration"]

func _start_phase_rotate() -> void:
	_current_phase = "rotate"
	for b in balls:
		b.stop_moving()
		b.set_state_normal()

	_camera_angle = 0.0
	_camera_direction = 1.0
	_camera_returning = false
	_selected_count = 0

	_set_phase_label("↻ TOURNE ET SÉLECTIONNE LES BALLES")
	ui_confirm_btn.visible = true
	ui_confirm_btn.text = "CONFIRMER (0/%d)" % GameManager.settings["target_balls"]
	ui_timer_bar.visible = false
	ui_message.visible = false

func _start_phase_select() -> void:
	pass  # fusionnée dans _start_phase_rotate

func _start_phase_result(won: bool) -> void:
	_current_phase = "result"
	ui_confirm_btn.visible = false

	# Freeze toutes les balles — elles ne bougent plus du tout
	for b in balls:
		b.stop_moving()

	# Affichage visuel du résultat
	for id in GameManager.target_ball_ids:
		balls[id].set_state_correct()

	if not won:
		for id in GameManager.selected_ball_ids:
			if id not in GameManager.target_ball_ids:
				balls[id].set_state_wrong()

	GameManager.record_result(won)
	_update_rounds_ui()
	_update_speed_ui()

	ui_message.visible = true
	if won:
		ui_message.text = "✓ BONNE RÉPONSE !"
		ui_message.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
	else:
		ui_message.text = " ✕ RATÉ ! Les cibles étaient surlignées en vert."
		ui_message.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))

	_set_phase_label("")
	# Attendre 3s avec les balles colorées bien visibles et freezées
	await get_tree().create_timer(3.0).timeout

	if GameManager.is_game_over():
		_show_final_score()
	else:
		# Fade out des balles avant de les recréer
		_fade_out_balls()
		await get_tree().create_timer(0.5).timeout
		_spawn_balls()
		await get_tree().process_frame
		_start_phase_show()

func _fade_out_balls() -> void:
	# Tween l'alpha du matériau de chaque balle vers 0
	for b in balls:
		if b.mesh_instance and b._material:
			b._material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			var tw := create_tween()
			tw.tween_method(
				func(a: float): b._material.albedo_color.a = a,
				1.0, 0.0, 0.45
			)

func _show_final_score() -> void:
	_current_phase = "gameover"
	var score := GameManager.get_score()
	ui_message.text = "FIN ! Score : %d / %d\nNiveau estimé : %.1f" % [
		score, GameManager.settings["total_rounds"], GameManager.speed_level
	]
	ui_message.visible = true
	_set_phase_label("PARTIE TERMINÉE")

	# Bouton rejouer
	ui_confirm_btn.visible = true
	ui_confirm_btn.text = "↩ REJOUER"
	# Déconnecter l'ancien signal et reconnecter
	if ui_confirm_btn.pressed.is_connected(_on_confirm_pressed):
		ui_confirm_btn.pressed.disconnect(_on_confirm_pressed)
	ui_confirm_btn.pressed.connect(_on_replay_pressed)

#  PROCESS 
func _process(delta: float) -> void:
	if _is_paused:
		return

	match _current_phase:
		"show":
			_phase_timer -= delta
			ui_timer_bar.visible = true
			ui_timer_bar.value = (_phase_timer / GameManager.settings["show_duration"]) * 100.0
			if _phase_timer <= 0.0:
				ui_timer_bar.visible = false
				_start_phase_move()

		"move":
			_phase_timer -= delta
			ui_timer_bar.visible = true
			ui_timer_bar.value = (_phase_timer / GameManager.settings["move_duration"]) * 100.0
			if _phase_timer <= 0.0:
				ui_timer_bar.visible = false
				_start_phase_rotate()

		"rotate":
			if _camera_returning:
				# Retour doux vers 0 avec lerp — vitesse constante, pas de saut
				var speed := TAU * 0.1 * delta
				if abs(_camera_angle) <= speed + 0.001:
					_camera_angle = 0.0
					camera_pivot.rotation.y = 0.0
					_camera_returning = false
					_do_result()
				else:
					# Avance vers 0 à vitesse fixe dans le bon sens
					_camera_angle -= sign(_camera_angle) * speed
					camera_pivot.rotation.y = _camera_angle
			else:
				# Rotation aller-retour en boucle — TAU * 0.05 par seconde
				_camera_angle += delta * TAU * 0.015 * _camera_direction
				camera_pivot.rotation.y = _camera_angle
				# Demi-tour à ±60 degrés (PI/3)
				if abs(_camera_angle) >= PI / 3.0:
					_camera_direction *= -1.0

#  INTERACTIONS 
func _unhandled_input(event: InputEvent) -> void:
	# Filtre : seulement clic gauche souris ou touch, seulement en phase select/rotate
	var is_click: bool = event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	var is_touch: bool = event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed
	if not (is_click or is_touch):
		return
	if _current_phase != "select" and _current_phase != "rotate":
		return
	if _camera_returning:
		return

	# Coordonnées du point de clic
	var click_pos: Vector2
	if is_click:
		click_pos = (event as InputEventMouseButton).position
	else:
		click_pos = (event as InputEventScreenTouch).position

	# Raycast depuis la caméra
	var space := get_world_3d().direct_space_state
	var ray_origin := camera.project_ray_origin(click_pos)
	var ray_dir := camera.project_ray_normal(click_pos)
	var ray_end := ray_origin + ray_dir * 100.0

	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var result := space.intersect_ray(query)

	if result.is_empty():
		return

	# Trouve quelle balle correspond à l'Area3D touchée
	var hit_area: Object = result["collider"]
	for i in balls.size():
		var area: Area3D = balls[i].get_area()
		if area and area == hit_area:
			_on_ball_tapped(i)
			get_viewport().set_input_as_handled()
			return

func _on_ball_tapped(ball_id: int) -> void:
	# Phase déjà vérifiée dans _unhandled_input

	var ball = balls[ball_id]
	var target_count: int = GameManager.settings["target_balls"]

	if ball.is_selected:
		ball.set_state_deselected()
		GameManager.selected_ball_ids.erase(ball_id)
		_selected_count -= 1
	else:
		if _selected_count >= target_count:
			return  # Déjà assez sélectionné
		ball.set_state_selected()
		GameManager.selected_ball_ids.append(ball_id)
		_selected_count += 1

	ui_confirm_btn.text = "CONFIRMER (%d/%d)" % [_selected_count, target_count]

func _on_confirm_pressed() -> void:
	if _current_phase != "rotate":
		return
	if _selected_count != GameManager.settings["target_balls"]:
		ui_message.visible = true
		ui_message.text = "Sélectionne exactement %d balle(s) !" % GameManager.settings["target_balls"]
		ui_message.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
		return

	# Cache le bouton et lance le retour caméra
	ui_confirm_btn.visible = false
	ui_message.visible = false
	_camera_returning = true

func _do_result() -> void:
	var selected := GameManager.selected_ball_ids.duplicate()
	var targets := GameManager.target_ball_ids.duplicate()
	selected.sort()
	targets.sort()
	var won := (selected == targets)
	_start_phase_result(won)

func _on_pause_pressed() -> void:
	_is_paused = !_is_paused
	for b in balls:
		b.is_moving = !_is_paused
		if _is_paused:
			b.freeze = true
		else:
			b.freeze = false
	ui_pause_btn.text = "REPRENDRE" if _is_paused else "PAUSE"

func _on_replay_pressed() -> void:
	get_tree().reload_current_scene()

#  UI HELPERS 
func _set_phase_label(text: String) -> void:
	ui_phase_label.text = text

func _update_speed_ui() -> void:
	ui_speed_label.text = "Vitesse : %.1f" % GameManager.speed_level

func _update_rounds_ui() -> void:
	for child in ui_rounds_panel.get_children():
		child.queue_free()
	for i in GameManager.rounds_won.size():
		var lbl := Label.new()
		if GameManager.rounds_won[i]:
			lbl.text = "Manche %d ✓" % (i + 1)
			lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
		else:
			lbl.text = "Manche %d ✕" % (i + 1)
			lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
		lbl.add_theme_font_size_override("font_size", 16)
		ui_rounds_panel.add_child(lbl)
