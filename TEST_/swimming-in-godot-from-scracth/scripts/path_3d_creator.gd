@tool
extends Node3D

@export_category("Path References")
@export var master_path: Path3D
@export var target_inner_path: Path3D
@export var target_outer_path: Path3D
@export var target_lower_paths: Array[Path3D] = []

@export_category("expansions")
@export var horizontal_expansion: float = 8.0 
@export var vertical_drop_step: float = 4.0 

@export_category("generate")
@export var generate_parallel_paths: bool = false:
	set(value):
		generate_parallel_paths = false 
		_expand_all_paths()

func _expand_all_paths():
	# --- 1. SAFETY CHECKS ---
	if master_path == null or master_path.curve == null or master_path.curve.get_point_count() == 0:
		print("Setup your Master Path first!")
		return
		
	if target_inner_path == null or target_outer_path == null:
		print("Assign Inner and Outer paths in Inspector!")
		return

	# --- 2. PREPARE THE CURVES ---
	if target_inner_path.curve == null: target_inner_path.curve = Curve3D.new()
	if target_outer_path.curve == null: target_outer_path.curve = Curve3D.new()
	
	target_inner_path.curve.clear_points()
	target_outer_path.curve.clear_points()
	
	for lower_path in target_lower_paths:
		if lower_path != null:
			if lower_path.curve == null: lower_path.curve = Curve3D.new()
			lower_path.curve.clear_points()

	# --- 3. GENERATE ALL PATHS ---
	for i in range(master_path.curve.get_point_count()):
		# We work in Master Path's LOCAL space to keep things simple
		var p_pos = master_path.curve.get_point_position(i)
		var p_in = master_path.curve.get_point_in(i)
		var p_out = master_path.curve.get_point_out(i)
		
		# Use baked math to find the direction at this specific point
		var offset = master_path.curve.get_closest_offset(p_pos)
		var t = master_path.curve.sample_baked_with_rotation(offset)
		
		# --- THE ANTI-FLIP MATH ---
		var forward = -t.basis.z
		forward.y = 0.0 # Flatten the forward vector
		
		if forward.length() < 0.001:
			# Fallback if the path is pointing perfectly up/down
			forward = Vector3.FORWARD 
		else:
			forward = forward.normalized()
			
		# Cross product with World UP creates a perfect "Right" vector
		var sideways = forward.cross(Vector3.UP).normalized()
		
		# --- COORDINATE TRANSFORMATION ---
		# Convert the local Master point to Global, then to the Target's Local
		var m_to_g = master_path.global_transform
		
		# A. Inner Path
		var inner_local_pos = p_pos + (sideways * -horizontal_expansion)
		var inner_g = m_to_g * inner_local_pos
		target_inner_path.curve.add_point(target_inner_path.to_local(inner_g), p_in, p_out)
		
		# B. Outer Path
		var outer_local_pos = p_pos + (sideways * horizontal_expansion)
		var outer_g = m_to_g * outer_local_pos
		target_outer_path.curve.add_point(target_outer_path.to_local(outer_g), p_in, p_out)
		
		# C. Lower Paths
		for j in range(target_lower_paths.size()):
			var lp = target_lower_paths[j]
			if lp != null:
				var drop = Vector3(0, -vertical_drop_step * (j + 1), 0)
				var lower_g = m_to_g * (p_pos + drop)
				lp.curve.add_point(lp.to_local(lower_g), p_in, p_out)

	print("Success: Generated " + str(2 + target_lower_paths.size()) + " parallel paths!")
