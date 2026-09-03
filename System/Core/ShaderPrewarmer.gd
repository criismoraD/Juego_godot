class_name ShaderPrewarmer
extends RefCounted
## ShaderPrewarmer - Precalienta shaders y pipelines de Vulkan antes de iniciar la partida.
##
## En Godot 4, la primera vez que un shader/material entra en cámara, el driver
## compila el pipeline (PSO) de forma síncrona en el hilo principal, causando
## micro-congelamientos. Esta clase instancia y renderiza las escenas críticas
## durante 2 fotogramas dentro de un SubViewport invisible durante la pantalla de carga.

const ESCENAS_CRITICAS: Array[String] = [
	"res://Entities/Proyectil_Flecha/Arrow.tscn",
	"res://Entities/Flecha_Explosiva/FlechaExplosiva.tscn",
	"res://Entities/Proyectil_Flecha_Aliada/AllyArrow.tscn",
	"res://Entities/Proyectil_Virote_Aliado/AllyBolt.tscn",
	"res://Entities/Flecha_Explosiva/ExplosionFlechaExplosiva.tscn",
	"res://assets/BinbunVFX_Vol2/ExplosionFX/effects/ground/vfx_ground_explosion_01.tscn",
	"res://assets/BinbunVFX_Vol2/ExplosionFX/effects/air/vfx_air_explosion_01.tscn",
	"res://assets/BinbunVFX/magic_areas/effects/basic_area/basic_area_vfx_04.tscn",
	"res://VFX/Scenes/BloodSplashNormal.tscn",
	"res://VFX/Scenes/BloodSplashEmbajador.tscn"
]

const MATERIALES_CRITICOS: Array[String] = [
	"res://VFX/Shaders/s_Disolver_advanced.tres",
	"res://System/Shaders/cortinilla_circular.gdshader",
	"res://System/Shaders/TOON_PROYECTIL_LINEA.gdshader"
]


## Ejecuta el ciclo de precalentamiento. Debe invocarse con await mientras la pantalla de carga está visible.
static func prewarm(tree: SceneTree, on_progress: Callable = Callable()) -> void:
	if not tree or not tree.root:
		return

	# 1. Crear SubViewport aislado fuera de la vista del usuario
	var viewport := SubViewport.new()
	viewport.size = Vector2i(64, 64)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = true

	var camera := Camera3D.new()
	camera.current = true
	camera.position = Vector3(0.0, 0.0, 2.5)
	viewport.add_child(camera)

	var contenedor := Node3D.new()
	viewport.add_child(contenedor)

	tree.root.add_child(viewport)

	var total_items: int = ESCENAS_CRITICAS.size() + MATERIALES_CRITICOS.size()
	var processed_items: int = 0

	# 2. Instanciar y renderizar escenas críticas
	for path in ESCENAS_CRITICAS:
		if ResourceLoader.exists(path):
			var packed := load(path) as PackedScene
			if packed:
				var instance = packed.instantiate()
				if instance and instance is Node:
					# Silenciar audio del prewarm: las escenas de VFX traen
					# AudioStreamPlayer con autoplay y sonaban al cargar
					_silenciar_audio(instance)
					contenedor.add_child(instance)
					if instance is Node3D:
						instance.position = Vector3(0.0, 0.0, 0.0)
					_activar_particulas_y_mallas(instance)

		processed_items += 1
		if on_progress.is_valid():
			on_progress.call(float(processed_items) / float(total_items))

	# 3. Renderizar mallas con materiales/shaders sueltos
	for mat_path in MATERIALES_CRITICOS:
		if ResourceLoader.exists(mat_path):
			var res: Resource = load(mat_path)
			var quad := MeshInstance3D.new()
			var plane := PlaneMesh.new()
			plane.size = Vector2(1.0, 1.0)
			quad.mesh = plane
			quad.rotation_degrees = Vector3(90.0, 0.0, 0.0)

			if res is Material:
				quad.material_override = res
			elif res is Shader:
				var sh_mat := ShaderMaterial.new()
				sh_mat.shader = res
				quad.material_override = sh_mat

			contenedor.add_child(quad)

		processed_items += 1
		if on_progress.is_valid():
			on_progress.call(float(processed_items) / float(total_items))

	# 4. Esperar 2 fotogramas para que el renderizador de Vulkan procese y compile los pipelines
	await tree.process_frame
	await tree.process_frame

	# 5. Liberar todos los nodos de prueba y el SubViewport
	for child in contenedor.get_children():
		child.queue_free()

	viewport.queue_free()
	await tree.process_frame


static func _activar_particulas_y_mallas(node: Node) -> void:
	if node is GPUParticles3D:
		node.emitting = true
	elif node is CPUParticles3D:
		node.emitting = true

	for child in node.get_children():
		_activar_particulas_y_mallas(child)


## Quita el stream y el autoplay de todo AudioStreamPlayer dentro de la escena
## para que el precalentamiento sea completamente mudo.
static func _silenciar_audio(node: Node) -> void:
	for audio in node.find_children("*", "AudioStreamPlayer*", true, false):
		if audio is AudioStreamPlayer3D:
			var p3d := audio as AudioStreamPlayer3D
			p3d.autoplay = false
			p3d.stream = null
		elif audio is AudioStreamPlayer:
			var p := audio as AudioStreamPlayer
			p.autoplay = false
			p.stream = null
	# AudioPlayers con autoplay en el propio nodo raíz
	if node is AudioStreamPlayer3D:
		(node as AudioStreamPlayer3D).autoplay = false
		(node as AudioStreamPlayer3D).stream = null
	elif node is AudioStreamPlayer:
		(node as AudioStreamPlayer).autoplay = false
		(node as AudioStreamPlayer).stream = null
