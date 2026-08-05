extends "res://System/Core/Arrow.gd"
class_name AllyArrowProjectile

# === CONFIGURACIÓN VISUAL ===
@export_category("Estilo Celeste")
@export var color_celeste: Color = Color(0.3, 0.75, 1.0)
@export var energia_emision: float = 4.0


func _ready() -> void:
	super._ready()

	# Crear material celeste emisivo con outline para el proyectil
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color_celeste
	mat.emission_enabled = true
	mat.emission = color_celeste
	mat.emission_energy_multiplier = energia_emision
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var outline_shader = load("res://System/Shaders/TOON_PROYECTIL_LINEA.gdshader") as Shader
	if outline_shader:
		var outline_mat = ShaderMaterial.new()
		outline_mat.shader = outline_shader
		outline_mat.set_shader_parameter("outline_color", Color(0, 0, 0, 1))
		outline_mat.set_shader_parameter("outline_width", 20.0)
		mat.next_pass = outline_mat

	# Aplicar el material a todas las mallas de la flecha
	for mesh in _cached_mesh_instances:
		if is_instance_valid(mesh) and mesh is MeshInstance3D:
			mesh.material_override = mat

	# Configurar partículas de estela celestes
	var trail = get_node_or_null("TrailParticles") as GPUParticles3D
	if trail:
		# Material de las partículas (esferas emisivas celestes)
		var trail_mat := StandardMaterial3D.new()
		trail_mat.albedo_color = color_celeste
		trail_mat.emission_enabled = true
		trail_mat.emission = color_celeste
		trail_mat.emission_energy_multiplier = energia_emision
		trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		trail.material_override = trail_mat

		# Modificar el gradiente/color de las partículas para que sea celeste
		var proc_mat = trail.process_material as ParticleProcessMaterial
		if proc_mat:
			# Duplicar el material de proceso para no afectar el del jugador
			var dup_proc = proc_mat.duplicate() as ParticleProcessMaterial
			dup_proc.color = color_celeste

			# Si tiene una rampa de color, duplicarla y cambiar sus colores a celeste
			if dup_proc.color_ramp:
				var ramp_tex = dup_proc.color_ramp as GradientTexture1D
				if ramp_tex and ramp_tex.gradient:
					var dup_grad = ramp_tex.gradient.duplicate() as Gradient
					dup_grad.set_color(0, Color(color_celeste.r, color_celeste.g, color_celeste.b, 0.8))
					dup_grad.set_color(1, Color(color_celeste.r * 0.5, color_celeste.g * 0.6, color_celeste.b * 0.8, 0.0))

					var dup_ramp_tex = ramp_tex.duplicate() as GradientTexture1D
					dup_ramp_tex.gradient = dup_grad
					dup_proc.color_ramp = dup_ramp_tex

			trail.process_material = dup_proc
