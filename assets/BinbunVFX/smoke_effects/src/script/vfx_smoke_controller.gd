@tool
class_name VFXSmokeController
extends Node3D

enum Alpha_Mode {
	SMOOTH,
	DITHER,
	CUT,
	HYBRID
}

## Works only in the editor. By default works like "emitting" on particles. When one_shot is enabled works as a button. 
@export var emitting: bool = true:
	set(value):
		emitting = value
		for p: GPUParticles3D in _get_particles():
			p.emitting = emitting
			if emitting and reset_particles:
				_reset_particles()

## Whether to reset particles when animation loops
@export var reset_particles: bool = false

@export_group("General")
@export var emission_amount: int = 48:
	set(value):
		emission_amount = value
		for p: GPUParticles3D in _get_particles():
			if p.is_in_group("ShadowCaster"):
				p.amount = maxi(1, emission_amount / 2)
			else:
				p.amount = emission_amount

@export var lifetime: float = 2.0:
	set(value):
		lifetime = value
		for p: GPUParticles3D in _get_particles():
			p.lifetime = lifetime

@export_range(0.0, 1.0, 0.05) var explosiveness: float = 0.0:
	set(value):
		explosiveness = value
		for p: GPUParticles3D in _get_particles():
			p.explosiveness = explosiveness

@export_range(0.0, 10.0, 0.01) var speed_scale: float = 1.0:
	set(value):
		speed_scale = value
		_set_shader_params("time_scale", speed_scale)
		for p: GPUParticles3D in _get_particles():
			if is_instance_valid(p):
				p.speed_scale = value

@export var local_coords: bool = false:
	set(value):
		local_coords = value
		for p: GPUParticles3D in _get_particles():
			if is_instance_valid(p):
				p.local_coords = value

@export_flags_3d_render var visual_layers: int = 1:
	set(value):
		visual_layers = value
		for p: GPUParticles3D in _get_particles():
			if is_instance_valid(p):
				p.layers = visual_layers

@export_group("Colors")
@export var primary_color: Color = Color(0.296, 0.296, 0.296, 1.0):
	set(value):
		primary_color = value
		_set_shader_params("primary_color", primary_color)

@export var secondary_color: Color = Color(0.294, 0.294, 0.294, 1.0):
	set(value):
		secondary_color = value
		_set_shader_params("secondary_color", secondary_color)

@export var tertiary_color: Color = Color(0.1, 0.093, 0.087, 1.0):
	set(value):
		tertiary_color = value
		_set_shader_params("tertiary_color", tertiary_color)

@export_group("Style")
@export var hard_clouds: bool = true:
	set(value):
		hard_clouds = value
		_set_shader_params("mask2_blend_mode", int(hard_clouds) * 9)

@export_range(0.0, 1.0, 0.01) var cloud_density: float = 0.7:
	set(value):
		cloud_density = value
		_set_shader_params("mask2_strength", cloud_density * 0.8 + 0.2)

@export_group("Shading")
@export_range(0.0, 1.0, 0.01) var normal_strength: float = 1.0:
	set(value):
		normal_strength = value
		_set_shader_params("normal_strength", normal_strength)

@export_range(0.0, 1.0, 0.01) var roughness: float = 0.8:
	set(value):
		roughness = value
		_set_shader_params("roughness", roughness)

## Emit transparent spheres to cast shadows.
@export var fake_shadows: bool = false:
	set(value):
		fake_shadows = value
		var sc: Node = get_node_or_null("ShadowCaster")
		if is_instance_valid(sc) and sc is Node3D:
			(sc as Node3D).visible = fake_shadows

@export_group("Transparency")
## Specifies how to handle transparency within shaders.
@export var alpha_mode: Alpha_Mode = Alpha_Mode.SMOOTH:
	set(value):
		alpha_mode = value
		_set_shader_params("alpha_mode", alpha_mode)

@export_range(0.0, 1.0, 0.01) var alpha_cutoff: float = 0.02:
	set(value):
		alpha_cutoff = value
		_set_shader_params("alpha_cutoff", alpha_cutoff)

@export_range(0.0, 1.0, 0.01) var dither_cutoff: float = 0.8:
	set(value):
		dither_cutoff = value
		_set_shader_params("dither_cutoff", dither_cutoff)

@export var proximity_fade: bool = false:
	set(value):
		proximity_fade = value
		_set_shader_params("proximity_fade", proximity_fade)

@export var proximity_fade_distance: float = 1.0:
	set(value):
		proximity_fade_distance = value
		_set_shader_params("proximity_fade_distance", proximity_fade_distance)

@export_group("LODs")
@export var mesh_resolutions: int = 16:
	set(value):
		mesh_resolutions = value
		_set_mesh_resolutions(mesh_resolutions)


func _ready() -> void:
	_apply_all_properties()


func _apply_all_properties() -> void:
	for p: GPUParticles3D in _get_particles():
		if is_instance_valid(p):
			p.layers = visual_layers

	_set_shader_params("primary_color", primary_color)
	_set_shader_params("secondary_color", secondary_color)
	_set_shader_params("tertiary_color", tertiary_color)
	_set_shader_params("time_scale", speed_scale)
	_set_shader_params("mask2_blend_mode", int(hard_clouds) * 9)
	_set_shader_params("mask2_strength", cloud_density * 0.8 + 0.2)
	_set_shader_params("normal_strength", normal_strength)
	_set_shader_params("roughness", roughness)
	_set_shader_params("alpha_mode", alpha_mode)
	_set_shader_params("alpha_cutoff", alpha_cutoff)
	_set_shader_params("dither_cutoff", dither_cutoff)
	_set_shader_params("proximity_fade", proximity_fade)
	_set_shader_params("proximity_fade_distance", proximity_fade_distance)
	
	var sc: Node = get_node_or_null("ShadowCaster")
	if is_instance_valid(sc) and sc is Node3D:
		(sc as Node3D).visible = fake_shadows


func _get_particles() -> Array[GPUParticles3D]:
	var result: Array[GPUParticles3D] = []
	for p: Node in get_children():
		if p is GPUParticles3D:
			result.append(p as GPUParticles3D)
	return result


func _get_meshinstances() -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for m: Node in get_children():
		if m is MeshInstance3D:
			result.append(m as MeshInstance3D)
	return result


func _get_meshes() -> Array[Mesh]:
	var result: Array[Mesh] = []
	for p: GPUParticles3D in _get_particles():
		if is_instance_valid(p) and p.draw_pass_1 != null:
			result.append(p.draw_pass_1)
	for m: MeshInstance3D in _get_meshinstances():
		if is_instance_valid(m) and m.mesh != null:
			result.append(m.mesh)
	return result


func _set_light_prop(pname: String, value: Variant) -> void:
	var light: Node = get_node_or_null("Light")
	if light != null:
		light.set(pname, value)


func _reset_particles() -> void:
	for p: GPUParticles3D in _get_particles():
		p.restart()


func _set_shader_params(param_name: String, value: Variant) -> void:
	for p: GPUParticles3D in _get_particles():
		if not is_instance_valid(p):
			continue
		if p.material_override is ShaderMaterial:
			(p.material_override as ShaderMaterial).set_shader_parameter(param_name, value)
	for m: MeshInstance3D in _get_meshinstances():
		if not is_instance_valid(m):
			continue
		if m.material_override is ShaderMaterial:
			(m.material_override as ShaderMaterial).set_shader_parameter(param_name, value)


func _set_mesh_resolutions(value: int) -> void:
	for m: Mesh in _get_meshes():
		if not is_instance_valid(m):
			continue
		if m is SphereMesh:
			var sm: SphereMesh = m as SphereMesh
			sm.radial_segments = value
			sm.rings = maxi(1, value / 2)
		elif m is CylinderMesh:
			var cm: CylinderMesh = m as CylinderMesh
			cm.radial_segments = value
		elif m is PlaneMesh:
			var pm: PlaneMesh = m as PlaneMesh
			pm.subdivide_width = value
			pm.subdivide_depth = value
