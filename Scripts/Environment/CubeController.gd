@tool
extends Node3D
## Exposed read-only property showing current mesh dimensions
@export var mesh_size := Vector3(2.0, 2.0, 2.0):
	set(value):
		mesh_size = value
		_sync_all()
@export var subdivide_width: int = 50:
	set(value):
		subdivide_width = value
		_sync_all()
@export var subdivide_height: int = 50:
	set(value):
		subdivide_height = value
		_sync_all()
@export var subdivide_depth: int = 50:
	set(value):
		subdivide_depth = value
		_sync_all()
## UV Offset for texture positioning
@export var uv_offset := Vector2(0.0, 0.0):
	set(value):
		uv_offset = value
		_sync_all()
## UV Scale for Sides (Stone)
@export var uv_scale_sides := Vector2(2.0, 2.0):
	set(value):
		uv_scale_sides = value
		_sync_all()
## UV Scale for Top (Grass)
@export var uv_scale_top := Vector2(2.0, 2.0):
	set(value):
		uv_scale_top = value
		_sync_all()
## UV Rotation (Degrees)
@export_range(0.0, 360.0) var uv_rotation_degrees := 0.0:
	set(value):
		uv_rotation_degrees = value
		_sync_all()
## Blend Sharpness between top and sides
@export_range(0.1, 500.0) var blend_sharpness := 5.0:
	set(value):
		blend_sharpness = value
		_sync_all()
## Normal map intensity (0 = flat, 1 = normal, 2 = strong)
@export_range(0.0, 2.0) var normal_intensity := 1.0:
	set(value):
		normal_intensity = value
		_sync_all()
## Displacement scale for Y axis (vertical)
@export_range(0.0, 1.0) var displacement_scale_y := 0.1:
	set(value):
		displacement_scale_y = value
		_sync_all()
## Displacement scale for X and Z axes (horizontal)
@export_range(0.0, 1.0) var displacement_scale_xz := 0.1:
	set(value):
		displacement_scale_xz = value
		_sync_all()
@export_range(0.0, 1.0) var roughness := 0.8:
	set(value):
		roughness = value
		_sync_all()
@export_range(0.0, 1.0) var metallic := 0.0:
	set(value):
		metallic = value
		_sync_all()
@export_range(0.0, 2.0) var bevel_radius := 0.0:
	set(value):
		bevel_radius = value
		_sync_all()


func _ready():
	_make_resources_unique()
	_sync_all()


func _process(_delta):
	if Engine.is_editor_hint():
		_sync_all()


func _make_resources_unique():
	if not has_node("MeshInstance3D"):
		print_debug("Node MeshInstance3D not found")
		return

	var mesh_inst = $MeshInstance3D

	# Duplicate Mesh to make it unique per instance (Required for resizing/subdividing)
	if mesh_inst.mesh and mesh_inst.mesh is BoxMesh:
		if !mesh_inst.mesh.resource_path.is_empty():
			mesh_inst.mesh = mesh_inst.mesh.duplicate()
		elif mesh_inst.mesh.resource_local_to_scene == false:
			mesh_inst.mesh = mesh_inst.mesh.duplicate(true)

	# CRITICAL OPTIMIZATION: Do NOT duplicate the material.
	# Sharing the material prevents driver crashes on exit.
	# We use set_instance_shader_parameter instead.

	# Duplicate Collision Shape (Cheap and necessary)
	if has_node("StaticBody3D/CollisionShape3D"):
		var col_shape = $StaticBody3D/CollisionShape3D
		if col_shape.shape is BoxShape3D:
			col_shape.shape = col_shape.shape.duplicate()


func _sync_all():
	if not has_node("MeshInstance3D"):
		return

	var mesh_inst = $MeshInstance3D

	if not mesh_inst.mesh is BoxMesh:
		return

	# 1. Update Mesh Size & Subdivisions (Unique Mesh)
	if mesh_inst.mesh.size != mesh_size:
		mesh_inst.mesh.size = mesh_size

	if mesh_inst.mesh.subdivide_width != subdivide_width:
		mesh_inst.mesh.subdivide_width = subdivide_width

	if mesh_inst.mesh.subdivide_height != subdivide_height:
		mesh_inst.mesh.subdivide_height = subdivide_height

	if mesh_inst.mesh.subdivide_depth != subdivide_depth:
		mesh_inst.mesh.subdivide_depth = subdivide_depth

	# 2. Sync Hitbox
	if has_node("StaticBody3D/CollisionShape3D"):
		var col_shape = $StaticBody3D/CollisionShape3D
		if col_shape.shape is BoxShape3D:
			if col_shape.shape.size != mesh_size:
				col_shape.shape.size = mesh_size

	# 3. Sync Shader Params using INSTANCE PARAMETERS (No duplication)
	# This sets the values on the MeshInstance3D, overriding the shared material defaults
	mesh_inst.set_instance_shader_parameter("mesh_size", mesh_size)
	mesh_inst.set_instance_shader_parameter("uv_offset", uv_offset)
	mesh_inst.set_instance_shader_parameter("uv_scale_sides", uv_scale_sides)
	mesh_inst.set_instance_shader_parameter("uv_scale_top", uv_scale_top)
	mesh_inst.set_instance_shader_parameter("uv_rotation_degrees", uv_rotation_degrees)
	mesh_inst.set_instance_shader_parameter("blend_sharpness", blend_sharpness)
	mesh_inst.set_instance_shader_parameter("normal_intensity", normal_intensity)
	mesh_inst.set_instance_shader_parameter("displacement_scale_y", displacement_scale_y)
	mesh_inst.set_instance_shader_parameter("displacement_scale_xz", displacement_scale_xz)
	mesh_inst.set_instance_shader_parameter("roughness", roughness)
	mesh_inst.set_instance_shader_parameter("metallic", metallic)
	mesh_inst.set_instance_shader_parameter("bevel_radius", bevel_radius)
