extends Node3D

@onready var balls_container: Node3D = $BallsContainer
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var box_mesh: MeshInstance3D = $BoxMesh

@onready var ui_phase_label: Label = $UI/PhaseLabel
@onready var ui_speed_label: Label = $UI/SpeedLabel
@onready var ui_timer_bar: ProgressBar = $UI/TimerBar
@onready var ui_confirm_btn: Button = $UI/ConfirmButton
@onready var ui_rounds_panel: VBoxContainer = $UI/RoundsPanel
@onready var ui_pause_btn: Button = $UI/PauseButton
@onready var ui_message: Label = $UI/MessageLabel

var balls: Array[Node] = []
var _phase_timer: float = 0.0
var _current_phase: String = ""
var _is_paused: bool = false
var _selected_count: int = 0

var _cam_yaw: float = 0.0
var _cam_pitch: float = 0.0
var _cam_yaw_speed: float = 0.0
var _cam_pitch_speed: float = 0.0

const BOX_HALF := Vector3(5.0, 4.0, 3.0)
const CAM_DIST := 13.0
const CAM_SPEED_SCALE := 0.3

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
	camera.position = Vector3(0.0, 0.0, CAM_DIST)
	camera.rotation_degrees = Vector3(0.0, 0.0, 0.0)
	camera_pivot.position = Vector3(0.0, 0.0, 0.0)
	var light1 := DirectionalLight3D.new()
	light1.light_color = Color(1.0, 0.97, 0.90)
	light1.light_energy = 0.9
	light1.shadow_enabled = false
	light1.rotation_degrees = Vector3(-35.0, 45.0, 0.0)
	add_child(light1)
	var light2 := DirectionalLight3D.new()
	light2.light_color = Color(0.6, 0.65, 0.75)
	light2.light_energy = 0.4
	light2.shadow_enabled = false
	light2.rotation_degrees = Vector3(30.0, -135.0, 0.0)
	add_child(light2)
	_randomize_cam_speed()
	await get_tree().process_frame
	_start_phase_show()


func _randomize_cam_speed() -> void:
	_cam_yaw_speed   = randf_range(0.12, 0.22) * (1.0 if randf() > 0.5 else -1.0) * CAM_SPEED_SCALE
	_cam_pitch_speed = randf_range(0.04, 0.09) * (1.0 if randf() > 0.5 else -1.0) * CAM_SPEED_SCALE

func _setup_box() -> void:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.55, 0.55, 0.6, 0.07)
	mat.metallic = 0.0
	mat.roughness = 0.1
	mat.emission_enabled = false
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	box_mesh.material_override = mat
	box_mesh.scale = BOX_HALF * 2.0
	_create_box_edges()


func _create_box_edges() -> void:
	var im := ImmediateMesh.new()
	var edge_node := MeshInstance3D.new()
	add_child(edge_node)
	edge_node.mesh = im
	var edge_mat := StandardMaterial3D.new()
	edge_mat.albedo_color = Color(0.55, 0.55, 0.55, 1.0)
	edge_mat.emission_enabled = true
	edge_mat.emission = Color(0.4, 0.4, 0.4)
	edge_mat.emission_energy_multiplier = 0.6
	edge_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	edge_node.material_override = edge_mat
	var h := BOX_HALF
	var corners := [
		Vector3(-h.x, -h.y, -h.z), Vector3( h.x, -h.y, -h.z),
		Vector3( h.x,  h.y, -h.z), Vector3(-h.x,  h.y, -h.z),
		Vector3(-h.x, -h.y,  h.z), Vector3( h.x, -h.y,  h.z),
		Vector3( h.x,  h.y,  h.z), Vector3(-h.x,  h.y,  h.z),
	]
	var edges := [
		[0,1],[1,2],[2,3],[3,0],
		[4,5],[5,6],[6,7],[7,4],
		[0,4],[1,5],[2,6],[3,7],
	]
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for e in edges:
		im.surface_add_vertex(corners[e[0]])
		im.surface_add_vertex(corners[e[1]])
	im.surface_end()


func _spawn_balls() -> void:
	for b in balls:
		b.queue_free()
	balls.clear()
	var total: int = GameManager.settings["total_balls"]
	var positions_used: Array[Vector3] = []
	var ball_script := load("res://scripts/Ball.gd")
	for i in total:
		var ball_node := RigidBody3D.new()
		ball_node.set_script(ball_script)
		balls_container.add_child(ball_node)
		ball_node.setup(i, BOX_HALF)
		var pos := _find_free_position(positions_used, 0.95)
		ball_node.position = pos
		positions_used.append(pos)
		balls.append(ball_node)


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


func _start_phase_show() -> void:
	_current_phase = "show"
	_cam_yaw = 0.0
	_cam_pitch = 0.0
	camera_pivot.rotation.y = 0.0
	camera_pivot.rotation.x = 0.0
	GameManager.start_round()
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
	_set_phase_label("Memorise les balles")
	ui_confirm_btn.visible = false
	ui_message.visible = false
	ui_pause_btn.visible = false
	_phase_timer = GameManager.settings["show_duration"]
	_update_speed_ui()


func _start_phase_move() -> void:
	_current_phase = "move"
	var speed := GameManager.get_current_speed()
	for b in balls:
		b.set_state_normal()
		b.launch(speed)
	_set_phase_label("Observe !")
	ui_pause_btn.visible = false
	_phase_timer = GameManager.settings["move_duration"]


func _start_phase_rotate() -> void:
	_current_phase = "rotate"
	for b in balls:
		b.stop_moving()
		b.set_state_normal()
	_selected_count = 0
	_randomize_cam_speed()
	_set_phase_label("Tourne et selectionne les balles")
	ui_confirm_btn.visible = true
	ui_confirm_btn.text = "Confirmer (0/%d)" % GameManager.settings["target_balls"]
	ui_timer_bar.visible = false
	ui_message.visible = false
	ui_pause_btn.visible = true


func _start_phase_result(errors: int) -> void:
	_current_phase = "result"
	ui_confirm_btn.visible = false
	ui_pause_btn.visible = false
	for b in balls:
		b.stop_moving()
	for id in GameManager.target_ball_ids:
		balls[id].set_state_correct()
	for id in GameManager.selected_ball_ids:
		if id not in GameManager.target_ball_ids:
			balls[id].set_state_wrong()
	var won: bool = (errors == 0)
	GameManager.record_result_with_errors(won, errors)
	_update_rounds_ui()
	_update_speed_ui()
	ui_message.visible = true
	if won:
		ui_message.text = "Bonne reponse !"
		ui_message.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
	else:
		ui_message.text = "%d erreur(s) sur %d balles" % [errors, GameManager.settings["target_balls"]]
		ui_message.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
	_set_phase_label("")
	await get_tree().create_timer(3.0).timeout
	if GameManager.is_game_over():
		_show_final_score()
	else:
		_fade_out_balls()
		await get_tree().create_timer(0.5).timeout
		_spawn_balls()
		await get_tree().process_frame
		_start_phase_show()


func _fade_out_balls() -> void:
	for b in balls:
		if b.mesh_instance and b._material:
			b._material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			b._stripe_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			var tw := create_tween()
			tw.tween_method(func(a: float):
				b._material.albedo_color.a = a
				b._stripe_mat.albedo_color.a = a
			, 1.0, 0.0, 0.45)


func _show_final_score() -> void:
	_current_phase = "gameover"
	var score := GameManager.get_score()
	ui_message.text = "Score : %d / %d  -  Niveau : %.1f" % [
		score, GameManager.settings["total_rounds"], GameManager.speed_level
	]
	ui_message.visible = true
	_set_phase_label("Partie terminee")
	ui_confirm_btn.visible = true
	ui_confirm_btn.text = "Rejouer"
	if ui_confirm_btn.pressed.is_connected(_on_confirm_pressed):
		ui_confirm_btn.pressed.disconnect(_on_confirm_pressed)
	ui_confirm_btn.pressed.connect(_on_replay_pressed)


func _process(delta: float) -> void:
	if _is_paused:
		return

	if _current_phase == "rotate": # or _current_phase == "result":
		_cam_yaw   += delta * _cam_yaw_speed
		_cam_pitch += delta * _cam_pitch_speed
		_cam_pitch = clamp(_cam_pitch, -0.35, 0.35)
		if abs(_cam_pitch) >= 0.35:
			_cam_pitch_speed *= -1.0
		camera_pivot.rotation.y = _cam_yaw
		camera_pivot.rotation.x = _cam_pitch

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
			_check_ball_collisions()


func _check_ball_collisions() -> void:
	for i in balls.size():
		var a = balls[i]
		if not a.is_moving:
			continue
		for j in range(i + 1, balls.size()):
			var b = balls[j]
			if not b.is_moving:
				continue
			var dist: float = a.position.distance_to(b.position)
			if dist < a.BALL_RADIUS * 2.1:
				a.handle_collision_with(b)
				b.handle_collision_with(a)


func _unhandled_input(event: InputEvent) -> void:
	var is_click: bool = event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	var is_touch: bool = event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed
	if not (is_click or is_touch):
		return
	if _current_phase != "rotate":
		return
	var click_pos: Vector2
	if is_click:
		click_pos = (event as InputEventMouseButton).position
	else:
		click_pos = (event as InputEventScreenTouch).position
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
	var hit_area: Object = result["collider"]
	for i in balls.size():
		var area: Area3D = balls[i].get_area()
		if area and area == hit_area:
			_on_ball_tapped(i)
			get_viewport().set_input_as_handled()
			return


func _on_ball_tapped(ball_id: int) -> void:
	var ball = balls[ball_id]
	var target_count: int = GameManager.settings["target_balls"]
	if ball.is_selected:
		ball.set_state_deselected()
		GameManager.selected_ball_ids.erase(ball_id)
		_selected_count -= 1
	else:
		if _selected_count >= target_count:
			return
		ball.set_state_selected()
		GameManager.selected_ball_ids.append(ball_id)
		_selected_count += 1
	ui_confirm_btn.text = "Confirmer (%d/%d)" % [_selected_count, target_count]


func _on_confirm_pressed() -> void:
	if _current_phase != "rotate":
		return
	if _selected_count != GameManager.settings["target_balls"]:
		ui_message.visible = true
		ui_message.text = "Selectionne %d balle(s)" % GameManager.settings["target_balls"]
		ui_message.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
		return
	ui_confirm_btn.visible = false
	ui_message.visible = false
	_do_result()


func _do_result() -> void:
	var selected := GameManager.selected_ball_ids.duplicate()
	var targets := GameManager.target_ball_ids.duplicate()
	selected.sort()
	targets.sort()
	var errors: int = 0
	for id in selected:
		if id not in targets:
			errors += 1
	_start_phase_result(errors)


func _on_pause_pressed() -> void:
	_is_paused = !_is_paused
	for b in balls:
		b.is_moving = !_is_paused
		if _is_paused:
			b.freeze = true
		else:
			b.freeze = false
	ui_pause_btn.text = "Reprendre" if _is_paused else "Pause"


func _on_replay_pressed() -> void:
	get_tree().reload_current_scene()


func _set_phase_label(text: String) -> void:
	ui_phase_label.text = text


func _update_speed_ui() -> void:
	ui_speed_label.text = "Vitesse : %.1f" % GameManager.speed_level


func _update_rounds_ui() -> void:
	for child in ui_rounds_panel.get_children():
		child.queue_free()
	var total: int = GameManager.settings["total_rounds"]
	for i in total:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(16, 16)
		if i < GameManager.rounds_won.size():
			dot.color = Color(0.15, 0.9, 0.25) if GameManager.rounds_won[i] else Color(0.9, 0.2, 0.15)
		else:
			dot.color = Color(0.35, 0.35, 0.35)
		ui_rounds_panel.add_child(dot)
