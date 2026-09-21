@tool
extends MeshInstance3D

@export var center_path: Path3D
@export var inner_path: Path3D
@export var outer_path: Path3D

@export var texture_length_repeat: float = 20.0 
@export var texture_width_repeat: float = 1.0   
@export var texture_width: float = 8.0         

@export var curve_points: int = 5
@export var geometry_resolution: int = 50 

# Ensure these match your Shader's noise settings!
@export var wave_height: float = 0.5
@export var wave_speed: float = 2.0
@export var wave_freq: float = 1.0

@export var generate_collision: bool = false:
	set(value):
		generate_collision = false 
		_build_collision()

# --- MEMORY FOR ALL NODES ---
var _last_center_transform: Transform3D
var _last_inner_transform: Transform3D
var _last_outer_transform: Transform3D
var _last_mesh_transform: Transform3D


func _ready():
	call_deferred("_build_track_mesh")
	
# --- THE SIGNAL MANAGER (LIVE UPDATES!) ---
func _process(delta):
	if center_path == null or inner_path == null or outer_path == null: return
	if center_path.curve == null or inner_path.curve == null or outer_path.curve == null: return
	
	if not center_path.curve.changed.is_connected(_build_track_mesh):
		center_path.curve.changed.connect(_build_track_mesh)
	if not inner_path.curve.changed.is_connected(_build_track_mesh):
		inner_path.curve.changed.connect(_build_track_mesh)
	if not outer_path.curve.changed.is_connected(_build_track_mesh):
		outer_path.curve.changed.connect(_build_track_mesh)
		
	# --- CATCH SCALING, MOVING, AND ROTATING FOR EVERYTHING ---
	var needs_update = false
	
	if center_path.global_transform != _last_center_transform:
		_last_center_transform = center_path.global_transform
		needs_update = true
		
	if inner_path.global_transform != _last_inner_transform:
		_last_inner_transform = inner_path.global_transform
		needs_update = true
		
	if outer_path.global_transform != _last_outer_transform:
		_last_outer_transform = outer_path.global_transform
		needs_update = true
		
	if global_transform != _last_mesh_transform:
		_last_mesh_transform = global_transform
		needs_update = true
		
	# If ANY node was touched, rebuild the mesh!
	if needs_update:
		_build_track_mesh()

func _build_track_mesh():
	if center_path == null or inner_path == null or outer_path == null: return
	if center_path.curve == null or inner_path.curve == null or outer_path.curve == null: return
	if inner_path.curve.get_point_count() == 0 or outer_path.curve.get_point_count() == 0: return

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var len_c = center_path.curve.get_baked_length()
	var len_i = inner_path.curve.get_baked_length()
	var len_o = outer_path.curve.get_baked_length()
	
	for strip in range(curve_points):
		var t_left = float(strip) / float(curve_points)
		var t_right = float(strip + 1) / float(curve_points)
		
		for i in range(geometry_resolution):
			var p_bottom = float(i) / float(geometry_resolution)
			var p_top = float(i + 1) / float(geometry_resolution)
			
			var d_i_b = inner_path.to_global(inner_path.curve.sample_baked(p_bottom * len_i))
			var d_c_b = center_path.to_global(center_path.curve.sample_baked(p_bottom * len_c))
			var d_o_b = outer_path.to_global(outer_path.curve.sample_baked(p_bottom * len_o))
			var current_width_b = d_i_b.distance_to(d_o_b)
			
			var d_i_t = inner_path.to_global(inner_path.curve.sample_baked(p_top * len_i))
			var d_c_t = center_path.to_global(center_path.curve.sample_baked(p_top * len_c))
			var d_o_t = outer_path.to_global(outer_path.curve.sample_baked(p_top * len_o))
			var current_width_t = d_i_t.distance_to(d_o_t)
			
			var q0_l_b = d_i_b.lerp(d_c_b, t_left)
			var q1_l_b = d_c_b.lerp(d_o_b, t_left)
			var bl = to_local(q0_l_b.lerp(q1_l_b, t_left)) 
			
			var q0_r_b = d_i_b.lerp(d_c_b, t_right)
			var q1_r_b = d_c_b.lerp(d_o_b, t_right)
			var br = to_local(q0_r_b.lerp(q1_r_b, t_right)) 
			
			var q0_l_t = d_i_t.lerp(d_c_t, t_left)
			var q1_l_t = d_c_t.lerp(d_o_t, t_left)
			var tl = to_local(q0_l_t.lerp(q1_l_t, t_left)) 
			
			var q0_r_t = d_i_t.lerp(d_c_t, t_right)
			var q1_r_t = d_c_t.lerp(d_o_t, t_right)
			var tr = to_local(q0_r_t.lerp(q1_r_t, t_right)) 
			
			var v_bottom = p_bottom * texture_length_repeat
			var v_top = p_top * texture_length_repeat
			
			var u_scale_b = (current_width_b / texture_width) * texture_width_repeat
			var u_scale_t = (current_width_t / texture_width) * texture_width_repeat
			
			var uv_bl = Vector2(t_left * u_scale_b, v_bottom)
			var uv_br = Vector2(t_right * u_scale_b, v_bottom)
			var uv_tl = Vector2(t_left * u_scale_t, v_top)
			var uv_tr = Vector2(t_right * u_scale_t, v_top)
			
			st.set_uv(uv_bl)
			st.add_vertex(bl)
			st.set_uv(uv_tl)
			st.add_vertex(tl)
			st.set_uv(uv_br)
			st.add_vertex(br)
			
			st.set_uv(uv_br)
			st.add_vertex(br)
			st.set_uv(uv_tl)
			st.add_vertex(tl)
			st.set_uv(uv_tr)
			st.add_vertex(tr)
			
	st.generate_normals()
	st.generate_tangents()
	mesh = st.commit()

func _build_collision():
	if center_path == null or inner_path == null or outer_path == null: return
		
	var body = get_node_or_null("TrackCollider")
	if body == null:
		body = StaticBody3D.new()
		body.name = "TrackCollider"
		add_child(body)
		body.owner = get_tree().edited_scene_root 
		
	var col_shape = body.get_node_or_null("Shape")
	if col_shape == null:
		col_shape = CollisionShape3D.new()
		col_shape.name = "Shape"
		body.add_child(col_shape)
		col_shape.owner = get_tree().edited_scene_root

	var faces = PackedVector3Array()
	var len_c = center_path.curve.get_baked_length()
	var len_i = inner_path.curve.get_baked_length()
	var len_o = outer_path.curve.get_baked_length()

	for strip in range(curve_points):
		var t_left = float(strip) / float(curve_points)
		var t_right = float(strip + 1) / float(curve_points)

		var strip_verts = [] 

		for i in range(geometry_resolution + 1):
			var p = float(i) / float(geometry_resolution)
			var d_i = inner_path.to_global(inner_path.curve.sample_baked(p * len_i))
			var d_c = center_path.to_global(center_path.curve.sample_baked(p * len_c))
			var d_o = outer_path.to_global(outer_path.curve.sample_baked(p * len_o))
			var q0_left = d_i.lerp(d_c, t_left)
			var q1_left = d_c.lerp(d_o, t_left)
			var final_left = to_local(q0_left.lerp(q1_left, t_left))
			var q0_right = d_i.lerp(d_c, t_right)
			var q1_right = d_c.lerp(d_o, t_right)
			var final_right = to_local(q0_right.lerp(q1_right, t_right))

			strip_verts.append(final_left)
			strip_verts.append(final_right)

		for v in range(0, strip_verts.size() - 2, 2):
			faces.append(strip_verts[v])
			faces.append(strip_verts[v + 1])
			faces.append(strip_verts[v + 2])
			if v + 3 < strip_verts.size():
				faces.append(strip_verts[v + 1])
				faces.append(strip_verts[v + 3])
				faces.append(strip_verts[v + 2])

	var concave_shape = ConcavePolygonShape3D.new()
	concave_shape.backface_collision = true 
	concave_shape.set_faces(faces)
	col_shape.shape = concave_shape
	print("Collision Baked!")

# This is the function your RigidBody is looking for
func get_water_surface_y(global_pos: Vector3) -> float:
	var time = Time.get_ticks_msec() / 1000.0
	
	# Simple Sine Wave math (The easiest "Moving Water" math)
	# This calculates a wave based on X position and Time
	var wave = sin(global_pos.x * wave_freq + time * wave_speed) * wave_height
	
	return global_position.y + wave
