class_name EscudoDestruible
extends StaticBody3D
# Escudo destruible con daño visual progresivo
signal destruido
@export_category("Vida")
@export var golpes_para_destruir: int = 3
@export_category("Visual de Daño")
@export var color_dano: Color = Color(1.0, 0.2, 0.2)
@export var intensidad_tinte_dano: float = 0.5
@export var duracion_flash: float = 0.1
@export var intensidad_flash: float = 3.0
@export_category("Colisión")
@export var bloquear_jugador: bool = false
@export var bloquear_flechas_jugador: bool = false
@export_category("Destrucción - Física")
@export var escena_escudo_roto: PackedScene = preload("res://Scenes/Environment/EscudoRoto.tscn")
@export var fuerza_explosion: float = 1.5
@export var fuerza_horizontal: float = 0.5  ## Dispersión horizontal de los trozos al explotar
@export var fuerza_vertical: float = 1.0
## Torque = fuerza de ROTACIÓN aplicada a cada trozo.
## Hace que las piezas giren mientras vuelan por el aire.
## Min/Max definen el rango aleatorio: valores más altos = giros más rápidos.
## Ejemplo: min=-4, max=4 → cada pieza gira en dirección aleatoria.
## Usar 0 en ambos para que las piezas no roten al salir disparadas.
@export var torque_min: float = -4.0
@export var torque_max: float = 4.0
@export_category("Destrucción - Tiempos")
@export var tiempo_congelar: float = 2.0  # Segundos antes de congelar piezas
@export var tiempo_antes_disolver: float = 1.5  # Segundos congeladas antes de disolverse
@export_category("Destrucción - Disolución")
@export var duracion_disolucion: float = 1.0
@export var color_borde_disolucion: Color = Color(1.0, 0.6, 0.2)
@export var intensidad_emision_disolucion: float = 3.0
@export_category("Destrucción - Partículas")
@export var particulas_cantidad: int = 60
@export var particulas_vida: float = 1.5
@export var particulas_caja: Vector3 = Vector3(0.3, 0.3, 0.1)
@export var particulas_dispersion: float = 25.0
@export var particulas_velocidad_min: float = 0.1
@export var particulas_velocidad_max: float = 0.8
@export var particulas_gravedad: Vector3 = Vector3(0, 0.1, 0)
@export var particulas_escala_min: float = 0.01
@export var particulas_escala_max: float = 0.03
# Estado interno
var golpes_recibidos: int = 0
var mesh_instance: MeshInstance3D
var material_original: Material
var material_dano: StandardMaterial3D


func _ready():
	add_to_group("escudos")

	# Configurar colisiones
	# Layer 2: escudo (los goblins pueden detectarlo)
	# Mask: solo enemigos/flechas enemigas si no bloquea jugador
	if not bloquear_jugador:
		collision_layer = 2  # Layer del escudo
		collision_mask = 0  # No detecta nada activamente

	# Buscar el MeshInstance3D
	_find_mesh_instance(self)

	if mesh_instance:
		# Guardar material original
		if mesh_instance.get_surface_override_material(0):
			material_original = mesh_instance.get_surface_override_material(0)
		elif mesh_instance.mesh and mesh_instance.mesh.surface_get_material(0):
			material_original = mesh_instance.mesh.surface_get_material(0)

		# Crear material para mostrar daño
		material_dano = StandardMaterial3D.new()
		if material_original is StandardMaterial3D:
			# Copiar propiedades del original
			material_dano.albedo_texture = material_original.albedo_texture
			material_dano.albedo_color = material_original.albedo_color
		material_dano.emission_enabled = true
		material_dano.emission = color_dano
		material_dano.emission_energy_multiplier = 0.0


func _find_mesh_instance(node: Node):
	for child in node.get_children():
		if child is MeshInstance3D and mesh_instance == null:
			mesh_instance = child
			return
		_find_mesh_instance(child)


func recibir_golpe():
	golpes_recibidos += 1

	# Reproducir sonido de daño al escudo
	AudioManager.play_shield_hit()

	# Actualizar visual de daño
	_actualizar_visual_dano()

	# Siempre hacer flash blanco (incluyendo el golpe final)
	_flash_dano()

	# Verificar si debe destruirse (después del flash)
	if golpes_recibidos >= golpes_para_destruir:
		await get_tree().create_timer(duracion_flash).timeout
		_destruir()


func _actualizar_visual_dano():
	if not mesh_instance or not material_dano:
		return

	# Calcular progreso de daño (0.0 a 1.0)
	var progreso = float(golpes_recibidos) / float(golpes_para_destruir)

	# Mezclar color original con rojo según el daño
	if material_original is StandardMaterial3D:
		material_dano.albedo_color = material_original.albedo_color.lerp(
			color_dano, progreso * intensidad_tinte_dano
		)
	else:
		material_dano.albedo_color = Color.WHITE.lerp(color_dano, progreso * intensidad_tinte_dano)

	# Aplicar material
	mesh_instance.set_surface_override_material(0, material_dano)


func _flash_dano():
	if not mesh_instance:
		return

	# Flash blanco rápido
	var flash_mat = StandardMaterial3D.new()
	flash_mat.emission_enabled = true
	flash_mat.emission = Color.WHITE
	flash_mat.emission_energy_multiplier = intensidad_flash

	mesh_instance.set_surface_override_material(0, flash_mat)

	await get_tree().create_timer(duracion_flash).timeout

	# Volver al material de daño
	if mesh_instance and material_dano:
		mesh_instance.set_surface_override_material(0, material_dano)


func _destruir():
	destruido.emit()
	AudioManager.play_shield_break()

	# Instanciar el escudo roto
	if escena_escudo_roto:
		var escudo_roto = escena_escudo_roto.instantiate()

		# Pasar el estado de daño visual (nivel del PENÚLTIMO golpe)
		var progreso_previo = float(golpes_recibidos - 1) / float(golpes_para_destruir)
		escudo_roto.color_dano_heredado = color_dano
		escudo_roto.progreso_dano = progreso_previo
		escudo_roto.intensidad_tinte_heredado = intensidad_tinte_dano

		# Pasar parámetros de física
		escudo_roto.fuerza_explosion = fuerza_explosion
		escudo_roto.fuerza_horizontal = fuerza_horizontal
		escudo_roto.fuerza_vertical = fuerza_vertical
		escudo_roto.torque_min = torque_min
		escudo_roto.torque_max = torque_max

		# Pasar parámetros de tiempos
		escudo_roto.tiempo_congelar = tiempo_congelar
		escudo_roto.tiempo_antes_disolver = tiempo_antes_disolver

		# Pasar parámetros de disolución
		escudo_roto.duracion_disolucion = duracion_disolucion
		escudo_roto.color_borde_disolucion = color_borde_disolucion
		escudo_roto.intensidad_emision = intensidad_emision_disolucion

		# Pasar parámetros de partículas
		escudo_roto.particulas_cantidad = particulas_cantidad
		escudo_roto.particulas_vida = particulas_vida
		escudo_roto.particulas_caja = particulas_caja
		escudo_roto.particulas_dispersion = particulas_dispersion
		escudo_roto.particulas_velocidad_min = particulas_velocidad_min
		escudo_roto.particulas_velocidad_max = particulas_velocidad_max
		escudo_roto.particulas_gravedad = particulas_gravedad
		escudo_roto.particulas_escala_min = particulas_escala_min
		escudo_roto.particulas_escala_max = particulas_escala_max

		# Añadir al root de la escena (NO al padre directo) para evitar que
		# los RigidBody3D de los trozos queden como hijos de un AnimatableBody3D
		# (PlataformaOneway), lo que haría que Godot excluya la colisión entre ellos.
		var target_parent = get_tree().current_scene
		if target_parent:
			target_parent.add_child(escudo_roto)
		else:
			get_parent().add_child(escudo_roto)

		# Posicionar el EscudoRoto en la posición del escudo
		escudo_roto.global_position = global_position

		# Encontrar el nodo del modelo visual intacto y aplicar su transform EXACTA
		# al modelo de partes rotas. Así las piezas tienen el mismo tamano/posición/rotación.
		var model_node: Node3D = null
		for child in get_children():
			if not (child is CollisionShape3D) and child is Node3D:
				model_node = child
				break

		var escudo_partes = escudo_roto.get_node_or_null("escudo_partes")
		if escudo_partes and model_node:
			escudo_partes.global_transform = model_node.global_transform

	# Desactivar colisión inmediatamente
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)

	# Limpiar materiales antes de queue_free para evitar
	# "Parameter 'material' is null" en el RenderingServer
	if mesh_instance:
		mesh_instance.material_override = null
		if mesh_instance.mesh:
			for si in range(mesh_instance.mesh.get_surface_count()):
				mesh_instance.set_surface_override_material(si, null)
		mesh_instance.visible = false

	# Ocultar visualmente este escudo
	visible = false

	# Eliminar este objeto
	queue_free()
