@tool
extends Node3D # Changed to generic Node3D

@export_group("Test Tools")
@export var test_splash_trigger: bool = false:
	set(value):
		_manual_editor_splash()

@export_group("Splash Settings")
@export var splash_vfx_scene: PackedScene
@export var simulated_mass: float = 10.0 # Replaces the RigidBody 'mass' property
@export var min_speed_act_thereshold := 2.0 
@export var splash_scale_mult := 0.5
@export var splash_height_mult := 0.2
@export var deletion_timer:= 4.0

@export_group("References")
@export var probe_node: Marker3D
@export var water_node: MeshInstance3D 

var was_submerged := false
var last_pos : Vector3
var current_velocity : Vector3

func _process(delta):
	
	# 1. track velocity
	if delta > 0:
		current_velocity = (global_position - last_pos) / delta
	last_pos = global_position

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
		var impact_speed = abs(current_velocity.y)
		
		# Fallback for slow drags in the editor
		if Engine.is_editor_hint() and impact_speed < 1.0: 
			impact_speed = 5.0 
		
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
		print("No splash_node scene assigned!")
		return
		
	var splash_node = splash_vfx_scene.instantiate()
	var veritcal_pivots = splash_node.get_child(0)
	
	
	#add node
	get_parent().add_child(splash_node)
	
	if Engine.is_editor_hint():
		splash_node.owner = get_tree().edited_scene_root
	
	# Position 
	splash_node.global_position = Vector3(probe_node.global_position.x, y_pos, probe_node.global_position.z)
	
	# Scale 
	var width = simulated_mass * splash_scale_mult * 0.1
	var height = impact_speed * splash_height_mult * 0.1
	veritcal_pivots.scale = Vector3(width, height, width)
	print("scaled")
	
	
	#Play
	if splash_node.has_method("play_splash"):
		
		
		splash_node.play_splash()
		print("VFX Triggered via Controller")
	
	elif splash_node.has_node("AnimationPlayer"):
		var ap = splash_node.get_node("AnimationPlayer")
		ap.play("ripple") # Change "ripple" to your default name
		print("VFX Triggered via AnimationPlayer fallback")
	
	else:
		# Fallback to the old particle trigger logic
		if splash_node is CPUParticles3D or splash_node is GPUParticles3D:
			splash_node.emitting = true
		elif splash_node.get_child_count() > 0:
			for child in splash_node.get_children():
				if child is CPUParticles3D or child is GPUParticles3D:
					child.emitting = true
	
	# Cleanup
	var timer = get_tree().create_timer(deletion_timer)
	timer.timeout.connect(func(): if is_instance_valid(splash_node): splash_node.queue_free())
	
