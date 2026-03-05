extends RigidBody3D

#  Propriétés 
var ball_id: int = 0
var is_target: bool = false
var is_selected: bool = false
var is_moving: bool = false

const BALL_RADIUS := 0.45
const BOUNCE_RANDOM := 0.15

const COLOR_NORMAL   := Color(0.9, 0.85, 0.1, 1.0)
const COLOR_TARGET   := Color(1.0, 0.95, 0.0, 1.0)
const COLOR_SELECTED := Color(0.2, 0.8, 1.0, 1.0)
const COLOR_CORRECT  := Color(0.1, 1.0, 0.2, 1.0)
const COLOR_WRONG    := Color(1.0, 0.15, 0.1, 1.0)

var _material: StandardMaterial3D
var _box_half: Vector3 = Vector3(4.5, 3.5, 2.5)

# Références créées dans _ready()
var mesh_instance: MeshInstance3D
var glow_omni: OmniLight3D

#  Init 
func _ready() -> void:
	# --- Mesh ---
	mesh_instance = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = BALL_RADIUS
	sphere.height = BALL_RADIUS * 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	mesh_instance.mesh = sphere
	add_child(mesh_instance)

	# --- Matériau ---
	_material = StandardMaterial3D.new()
	_material.albedo_color = COLOR_NORMAL
	_material.roughness = 0.55
	_material.metallic = 0.0
	_material.emission_enabled = true
	_material.emission = COLOR_NORMAL * 0.3
	_material.emission_energy_multiplier = 0.5
	mesh_instance.material_override = _material

	# --- Lumière de glow ---
	glow_omni = OmniLight3D.new()
	glow_omni.light_color = COLOR_NORMAL
	glow_omni.light_energy = 0.0
	glow_omni.omni_range = 2.5
	add_child(glow_omni)

	# --- Collision ---
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = BALL_RADIUS
	col.shape = shape
	add_child(col)

	# --- Area3D pour le tap ---
	var area := Area3D.new()
	var area_col := CollisionShape3D.new()
	area_col.shape = shape
	area.add_child(area_col)
	add_child(area)

	# Physique
	gravity_scale = 0.0
	linear_damp = 0.0
	angular_damp = 0.8
	contact_monitor = true
	max_contacts_reported = 4

func setup(id: int, half_extents: Vector3) -> void:
	ball_id = id
	_box_half = half_extents - Vector3(BALL_RADIUS, BALL_RADIUS, BALL_RADIUS)

func get_area() -> Area3D:
	for child in get_children():
		if child is Area3D:
			return child
	return null

#  Mouvement 
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

func stop_moving() -> void:
	is_moving = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC

#  Rebonds dans la boîte 
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
		if spd > 0.1:
			linear_velocity = vel.normalized() * spd
		else:
			linear_velocity = vel

#  États visuels 
func set_state_normal() -> void:
	is_target = false
	is_selected = false
	_set_color(COLOR_NORMAL, 0.3)
	glow_omni.light_energy = 0.0

func set_state_target() -> void:
	is_target = true
	_set_color(COLOR_TARGET, 1.2)
	glow_omni.light_color = Color(1.0, 0.9, 0.0)
	glow_omni.light_energy = 2.5
	_pulse_tween()

func set_state_selected() -> void:
	is_selected = true
	_set_color(COLOR_SELECTED, 0.8)
	glow_omni.light_color = COLOR_SELECTED
	glow_omni.light_energy = 2.0

func set_state_deselected() -> void:
	is_selected = false
	set_state_normal()

func set_state_correct() -> void:
	_set_color(COLOR_CORRECT, 1.5)
	glow_omni.light_color = COLOR_CORRECT
	glow_omni.light_energy = 3.0

func set_state_wrong() -> void:
	_set_color(COLOR_WRONG, 1.5)
	glow_omni.light_color = COLOR_WRONG
	glow_omni.light_energy = 3.0

func _set_color(col: Color, emission_mult: float) -> void:
	_material.albedo_color = col
	_material.emission = col * emission_mult
	_material.emission_energy_multiplier = emission_mult

func _pulse_tween() -> void:
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(glow_omni, "light_energy", 4.0, 0.5)
	tw.tween_property(glow_omni, "light_energy", 1.5, 0.5)
