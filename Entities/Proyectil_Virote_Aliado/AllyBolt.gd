extends "res://System/Core/Arrow.gd"
class_name AllyBoltProjectile

## Virote de Ballesta Aliada: Mismo modelo procedimental que el Goblin Ballestero,
## pero con acabado celeste brillante y estela de partículas celeste.
## Vuelo recto y atraviesa escudos aliados.

@export_category("Estilo Celeste")
@export var color_celeste: Color = Color(0.25, 0.8, 1.0)
@export var energia_emision: float = 4.5


func _ready() -> void:
	# Configurar para que vuele recto como el virote goblin
	escala_gravedad = 0.0
	tipo_dueño = TipoFlecha.JUGADOR

	super._ready()

	# Ignorar escudos aliados al spawnear
	for esc in get_tree().get_nodes_in_group("escudos"):
		if is_instance_valid(esc):
			if "es_escudo_enemigo" not in esc or not esc.es_escudo_enemigo:
				if _ray_ccd:
					_ray_ccd.add_exception(esc)

	# Crear material celeste emisivo con outline toon
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

	# Aplicar el material a todas las mallas de la flecha/virote
	for mesh in _cached_mesh_instances:
		if is_instance_valid(mesh) and mesh is MeshInstance3D:
			mesh.material_override = mat

	# Configurar partículas de estela celestes
	var trail = get_node_or_null("TrailParticles") as GPUParticles3D
	if trail:
		var trail_mat := StandardMaterial3D.new()
		trail_mat.albedo_color = color_celeste
		trail_mat.emission_enabled = true
		trail_mat.emission = color_celeste
		trail_mat.emission_energy_multiplier = energia_emision
		trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		trail.material_override = trail_mat

		var proc_mat = trail.process_material as ParticleProcessMaterial
		if proc_mat:
			var dup_proc = proc_mat.duplicate() as ParticleProcessMaterial
			dup_proc.color = color_celeste
			trail.process_material = dup_proc
