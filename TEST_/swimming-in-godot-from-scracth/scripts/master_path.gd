@tool
extends Path3D

@export var center_path: Path3D
@export var inner_path: Path3D
@export var outer_path: Path3D

# Fixed: Slider is restricted so it can never hit 0 or negative!
@export_range(0.01, 10.0) var width_scale: float = 1.0:
	set(value):
		width_scale = value
		_apply_master_transform()

@export var reset_baseline: bool = false:
	set(value):
		reset_baseline = false
		_build_baseline()

var _is_updating = false
var inner_memory = []
var outer_memory = []
var center_memory = []

func _process(delta):
	if curve and not curve.changed.is_connected(_apply_master_transform):
		curve.changed.connect(_apply_master_transform)
	if inner_path and inner_path.curve and not inner_path.curve.changed.is_connected(_memorize_children):
		inner_path.curve.changed.connect(_memorize_children)
	if outer_path and outer_path.curve and not outer_path.curve.changed.is_connected(_memorize_children):
		outer_path.curve.changed.connect(_memorize_children)
	if center_path and center_path.curve and not center_path.curve.changed.is_connected(_memorize_children):
		center_path.curve.changed.connect(_memorize_children)

	# THE AMNESIA FIX: If memory is empty, rebuild it instantly to prevent panics!
	if curve and inner_path and inner_path.curve:
		if inner_memory.size() != curve.get_point_count() and not _is_updating:
			_memorize_children()

func _memorize_children():
	if _is_updating: return
	if inner_path == null or outer_path == null or center_path == null or curve == null: return
	if curve.get_point_count() < 2: return 
	if inner_path.curve == null or inner_path.curve.get_point_count() != curve.get_point_count(): return

	inner_memory.clear()
	outer_memory.clear()
	center_memory.clear()

	for i in range(curve.get_point_count()):
		var m_pos = curve.get_point_position(i)
		var offset = curve.get_closest_offset(m_pos)
		var m_trans_local = curve.sample_baked_with_rotation(offset)
		
		# THE DRIFT FIX: Lock it to absolute coordinates
		m_trans_local.origin = m_pos 
		
		# THE DESYNC FIX: Use 100% Local Math
		var i_pos_master = inner_path.transform * inner_path.curve.get_point_position(i)
		var o_pos_master = outer_path.transform * outer_path.curve.get_point_position(i)
		var c_pos_master = center_path.transform * center_path.curve.get_point_position(i)
		
		var i_custom_offset = m_trans_local.inverse() * i_pos_master
		var o_custom_offset = m_trans_local.inverse() * o_pos_master
		var c_custom_offset = m_trans_local.inverse() * c_pos_master
		
		i_custom_offset.x /= width_scale
		o_custom_offset.x /= width_scale
		#c_custom_offset.x /= width_scale
		
		inner_memory.append(i_custom_offset)
		outer_memory.append(o_custom_offset)
		center_memory.append(c_custom_offset)

func _apply_master_transform():
	if _is_updating: return
	if curve == null or inner_memory.size() != curve.get_point_count(): return
	if curve.get_point_count() < 2: return 

	_is_updating = true 

	inner_path.curve.set_block_signals(true)
	outer_path.curve.set_block_signals(true)
	center_path.curve.set_block_signals(true)

	for i in range(curve.get_point_count()):
		var m_pos = curve.get_point_position(i)
		var offset = curve.get_closest_offset(m_pos)
		var m_trans_local = curve.sample_baked_with_rotation(offset)
		m_trans_local.origin = m_pos
		
		var applied_i_offset = inner_memory[i] * Vector3(width_scale, 1.0, 1.0)
		var applied_o_offset = outer_memory[i] * Vector3(width_scale, 1.0, 1.0)
		var applied_c_offset = center_memory[i]
		
		var new_i_pos_master = m_trans_local * applied_i_offset
		var new_o_pos_master = m_trans_local * applied_o_offset
		var new_c_pos_master = m_trans_local * applied_c_offset
		
		# Convert safely back down to child local space
		var new_i_local = inner_path.transform.affine_inverse() * new_i_pos_master
		var new_o_local = outer_path.transform.affine_inverse() * new_o_pos_master
		var new_c_local = center_path.transform.affine_inverse() * new_c_pos_master
		
		var m_in = curve.get_point_in(i)
		var m_out = curve.get_point_out(i)
		
		inner_path.curve.set_point_position(i, new_i_local)
		inner_path.curve.set_point_in(i, m_in)
		inner_path.curve.set_point_out(i, m_out)
		
		outer_path.curve.set_point_position(i, new_o_local)
		outer_path.curve.set_point_in(i, m_in)
		outer_path.curve.set_point_out(i, m_out)
		
		center_path.curve.set_point_position(i, new_c_local)
		center_path.curve.set_point_in(i, m_in)
		center_path.curve.set_point_out(i, m_out)

	inner_path.curve.set_block_signals(false)
	outer_path.curve.set_block_signals(false)
	center_path.curve.set_block_signals(false)

	inner_path.curve.changed.emit()
	_is_updating = false

func _build_baseline():
	if inner_path == null or outer_path == null or center_path == null or curve == null: return
	_is_updating = true
	
	if inner_path.curve == null: inner_path.curve = Curve3D.new()
	if outer_path.curve == null: outer_path.curve = Curve3D.new()
	if center_path.curve == null: center_path.curve = Curve3D.new()
	
	inner_path.curve.clear_points()
	outer_path.curve.clear_points()
	center_path.curve.clear_points()
	
	for i in range(curve.get_point_count()):
		var pos = curve.get_point_position(i)
		var p_in = curve.get_point_in(i)
		var p_out = curve.get_point_out(i)
		
		var offset = curve.get_closest_offset(pos)
		var m_trans = curve.sample_baked_with_rotation(offset)
		m_trans.origin = pos
		
		var i_pos_master = m_trans * Vector3(-4.0, 0, 0)
		var o_pos_master = m_trans * Vector3(4.0, 0, 0)
		
		var i_local = inner_path.transform.affine_inverse() * i_pos_master
		var o_local = outer_path.transform.affine_inverse() * o_pos_master
		var c_local = center_path.transform.affine_inverse() * pos
		
		inner_path.curve.add_point(i_local, p_in, p_out)
		outer_path.curve.add_point(o_local, p_in, p_out)
		center_path.curve.add_point(c_local, p_in, p_out)
		
	_is_updating = false
	_memorize_children()
