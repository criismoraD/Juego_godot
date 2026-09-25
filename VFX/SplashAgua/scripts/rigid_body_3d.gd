@tool
extends RigidBody3D

@export_group("Test Tools")
@export var test_splash_trigger: bool = false:
	set(value):
		_manual_editor_splash()

@export_group("Splash Settings")
@export var splash_vfx_scene: PackedScene
@export var min_speed_act_thereshold := 2.0 #
@export var splash_scale_mult := 0.5
@export var splash_height_mult := 0.2
@export var deletion_timer:= 4

@export_group("References")
@export var probe_node: Marker3D
@export var water_node: MeshInstance3D 

var was_submerged := false
var last_editor_pos : Vector3
var current_editor_velocity : Vector3

func _process(delta):
	# 1. ALWAYS track editor velocity if in tool mode
	if Engine.is_editor_hint():
		var movement = global_position - last_editor_pos
		if delta > 0:
			current_editor_velocity = movement / delta
		last_editor_pos = global_position

	# 2. Safety Checks
	if water_node == null or probe_node == null:
		return
	
	# 3. Get water level
	var surface_y = water_node.global_position.y
	if water_node.has_method("get_water_surface_y"):
		surface_y = water_node.get_water_surface_y(probe_node.global_position)
	
	var is_submerged = probe_node.global_position.y < surface_y
	
	# 4. TRIGGER LOGIC
	if is_submerged and not was_submerged:
		var impact_speed : float = 0.0
		
		if Engine.is_editor_hint():
			impact_speed = abs(current_editor_velocity.y)
			# Fallback for slow drags in editor
			if impact_speed < 1.0: impact_speed = 5.0 
		else:
			impact_speed = abs(linear_velocity.y)
		
		# Only block by threshold during actual gameplay
		if not Engine.is_editor_hint() and impact_speed < min_speed_act_thereshold:
			was_submerged = is_submerged # Still update state
			return
			
		spawn_splash(surface_y, impact_speed)
			
	was_submerged = is_submerged

func _manual_editor_splash():
	if water_node != null and splash_vfx_scene != null:
		spawn_splash(water_node.global_position.y, 10.0)

func spawn_splash(y_pos: float, impact_speed: float):
	if splash_vfx_scene == null: 
		print("No splash scene assigned!")
		return
		
	var splash = splash_vfx_scene.instantiate()
	get_parent().add_child(splash)
	
	if Engine.is_editor_hint():
		splash.owner = get_tree().edited_scene_root
	
	# Position at the probe's X/Z but the water's Y
	splash.global_position = Vector3(probe_node.global_position.x, y_pos, probe_node.global_position.z)
	
	# Scale math
	var width = mass * splash_scale_mult * 0.1
	var height = impact_speed * splash_height_mult * 0.1
	splash.scale = Vector3(width, height, width)
	
	# Trigger particles (works for both CPU and GPU versions)
	if splash is CPUParticles3D or splash is GPUParticles3D:
		splash.emitting = true
	elif splash.get_child_count() > 0:
		# If the particles are a child of the root Node3D
		for child in splash.get_children():
			if child is CPUParticles3D or child is GPUParticles3D:
				child.emitting = true
	
	# Cleanup
	var timer = get_tree().create_timer(deletion_timer)
	timer.timeout.connect(func(): if is_instance_valid(splash): splash.queue_free())
	
