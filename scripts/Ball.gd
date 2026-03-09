extends RigidBody3D

var ball_id: int = 0
var is_target: bool = false
var is_selected: bool = false
var is_moving: bool = false

const BALL_RADIUS := 0.45
const BOUNCE_RANDOM := 0.12

const COLOR_NORMAL   := Color(0.92, 0.86, 0.08, 1.0)
const COLOR_TARGET   := Color(1.0,  0.30, 0.05, 1.0)
const COLOR_SELECTED := Color(0.10, 0.65, 1.0,  1.0)
const COLOR_CORRECT  := Color(0.10, 0.90, 0.20, 1.0)
const COLOR_WRONG    := Color(1.0,  0.10, 0.08, 1.0)
const COLOR_STRIPE   := Color(0.12, 0.10, 0.01, 1.0)

var _material: StandardMaterial3D
var _stripe_mat: StandardMaterial3D
var _box_half: Vector3 = Vector3(4.5, 3.5, 2.5)

var mesh_instance: MeshInstance3D
var _visual_root: Node3D
var _pulse_tween_ref: Tween


func _ready() -> void:
	_visual_root = Node3D.new()
	add_child(_visual_root)

	mesh_instance = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = BALL_RADIUS
	sphere.height = BALL_RADIUS * 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	mesh_instance.mesh = sphere
	_visual_root.add_child(mesh_instance)

	_material = StandardMaterial3D.new()
	_material.albedo_color = COLOR_NORMAL
	_material.roughness = 0.42
	_material.metallic = 0.0
	mesh_instance.material_override = _material

	_stripe_mat = StandardMaterial3D.new()
	_stripe_mat.albedo_color = COLOR_STRIPE
	_stripe_mat.roughness = 0.7

	_add_torus_vertical(0.0)
	_add_torus_vertical(90.0)
	_add_ring(0.14)
	_add_ring(-0.14)

	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = BALL_RADIUS
	col.shape = shape
	add_child(col)

	var area := Area3D.new()
	var area_col := CollisionShape3D.new()
	area_col.shape = shape
	area.add_child(area_col)
	add_child(area)

	gravity_scale = 0.0
	linear_damp = 0.0
	angular_damp = 0.5
	contact_monitor = true
	max_contacts_reported = 8
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = 0.85
	physics_material_override.friction = 0.1


func _add_torus_vertical(y_rot: float) -> void:
	var node := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = BALL_RADIUS - 0.008
	t.outer_radius = BALL_RADIUS + 0.008
	t.rings = 40
	t.ring_segments = 12
	node.mesh = t
	node.rotation_degrees = Vector3(90.0, y_rot, 0.0)
	node.material_override = _stripe_mat
	_visual_root.add_child(node)


func _add_ring(y_pos: float) -> void:
	var node := MeshInstance3D.new()
	var c := CylinderMesh.new()
	var r: float = sqrt(BALL_RADIUS * BALL_RADIUS - y_pos * y_pos)
	c.top_radius    = r
	c.bottom_radius = r
	c.height        = 0.02
	c.radial_segments = 96
	c.rings = 1
	node.mesh = c
	node.position.y = y_pos
	node.material_override = _stripe_mat
	_visual_root.add_child(node)

func setup(id: int, half_extents: Vector3) -> void:
	ball_id = id
	_box_half = half_extents - Vector3(BALL_RADIUS, BALL_RADIUS, BALL_RADIUS)


func get_area() -> Area3D:
	for child in get_children():
		if child is Area3D:
			return child
	return null


func launch(speed: float) -> void:
	is_moving = true
	freeze = false
	var depth_ratio: float = GameManager.settings["depth_ratio"]
	var dir := Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0),
		randf_range(-depth_ratio, depth_ratio)
	).normalized()
	linear_velocity = dir * speed
	# petite rotation initiale pour que les bandes tournent naturellement
	angular_velocity = Vector3(
		randf_range(-4.0, 4.0),
		randf_range(-4.0, 4.0),
		randf_range(-4.0, 4.0)
	)


func stop_moving() -> void:
	is_moving = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC


func _physics_process(_delta: float) -> void:
	if not is_moving:
		return
	var pos := position
	var vel := linear_velocity
	var bounced := false
	for axis in [0, 1, 2]:
		if pos[axis] > _box_half[axis]:
			pos[axis] = _box_half[axis]
			vel[axis] = -abs(vel[axis]) * randf_range(1.0 - BOUNCE_RANDOM, 1.0 + BOUNCE_RANDOM)
			bounced = true
		elif pos[axis] < -_box_half[axis]:
			pos[axis] = -_box_half[axis]
			vel[axis] = abs(vel[axis]) * randf_range(1.0 - BOUNCE_RANDOM, 1.0 + BOUNCE_RANDOM)
			bounced = true
	if bounced:
		position = pos
		var spd := linear_velocity.length()
		linear_velocity = vel.normalized() * spd if spd > 0.1 else vel


func handle_collision_with(other: RigidBody3D) -> void:
	if not is_moving:
		return
	var diff := position - other.position
	if diff.length_squared() < 0.001:
		diff = Vector3(randf_range(-1,1), randf_range(-1,1), randf_range(-1,1))
	var normal := diff.normalized()
	var spd := linear_velocity.length()
	# rebond : projette la vitesse sur la normale et inverse
	var dot := linear_velocity.dot(normal)
	if dot < 0.0:
		linear_velocity -= normal * dot * 2.0
	# garde la meme vitesse
	if linear_velocity.length() > 0.01:
		linear_velocity = linear_velocity.normalized() * spd


func set_state_normal() -> void:
	is_target = false
	is_selected = false
	_kill_pulse()
	_apply_color(COLOR_NORMAL)


func set_state_target() -> void:
	is_target = true
	_apply_color(COLOR_TARGET)
	_start_pulse()


func set_state_selected() -> void:
	is_selected = true
	_kill_pulse()
	_apply_color(COLOR_SELECTED)


func set_state_deselected() -> void:
	is_selected = false
	set_state_normal()


func set_state_correct() -> void:
	_kill_pulse()
	_apply_color(COLOR_CORRECT)


func set_state_wrong() -> void:
	_kill_pulse()
	_apply_color(COLOR_WRONG)


func _apply_color(col: Color) -> void:
	_material.albedo_color = col
	if col == COLOR_NORMAL or col == COLOR_TARGET:
		_stripe_mat.albedo_color = COLOR_STRIPE
	else:
		_stripe_mat.albedo_color = col.darkened(0.5)


func _kill_pulse() -> void:
	if _pulse_tween_ref:
		_pulse_tween_ref.kill()
		_pulse_tween_ref = null
	_visual_root.scale = Vector3.ONE


func _start_pulse() -> void:
	_kill_pulse()
	_pulse_tween_ref = create_tween().set_loops()
	_pulse_tween_ref.tween_property(_visual_root, "scale", Vector3(1.15, 1.15, 1.15), 0.45)
	_pulse_tween_ref.tween_property(_visual_root, "scale", Vector3(1.0, 1.0, 1.0), 0.45)
