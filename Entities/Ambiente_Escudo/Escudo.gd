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
@export var parpadeos_rojo_enemigo: int = 1  ## Pulsos rojos por impacto en escudo enemigo (1 = un parpadeo)
@export var intervalo_parpadeo: float = 0.09  ## Segundos de cada fase del parpadeo
@export_category("Bando")
@export var es_escudo_enemigo: bool = false
@export_category("Profundidad 2.5D")
@export var auto_profundidad_aliado: bool = true  ## Mantiene el escudo en su plano Z detrás de defensores y protagonista
@export var plano_profundidad_aliado_z: float = -0.38  ## Plano Z seguro detrás de la protagonista (Z=0.05) y aliadas
@export_category("Colisión")
@export var bloquear_jugador: bool = false
@export var bloquear_flechas_jugador: bool = false
@export_category("Destrucción - Física")
@export var escena_escudo_roto: PackedScene = preload("res://Entities/Ambiente_Escudo/EscudoRoto.tscn")
@export var fuerza_explosion: float = 1.5
@export var fuerza_horizontal: float = 0.5  ## Dispersión horizontal de los trozos al explotar
@export var fuerza_vertical: float = 1.0
## Torque = fuerza de ROTACIÓN aplicada a cada trozo.
## Hace que las piezas giren mientras vuelan por el aire.
## Min/Max definen el rango aleatorio: valores más altos = giros más rápidos.
## Ejemplo: min=-4, max=4 → cada pieza gira en dirección aleatoria.
## Usar 0 en ambos para que las piezas no roten al salir disparadas.
@export var torque_min: float = -0.4
@export var torque_max: float = 0.4
@export_category("Destrucción - Tiempos")
@export var tiempo_congelar: float = 2.0  # Segundos antes de congelar piezas
@export var tiempo_antes_disolver: float = 1.5  # Segundos congeladas antes de disolverse
@export_category("Destrucción - Disolución")
@export var duracion_disolucion: float = 1.0
@export var color_borde_disolucion: Color = Color(1.0, 0.6, 0.2)
@export var intensidad_emision_disolucion: float = 3.0
@export_category("Destrucción - Partículas")
@export var particulas_cantidad: int = 80
@export var particulas_vida: float = 1.5
@export var particulas_caja: Vector3 = Vector3(0.3, 0.3, 0.1)
@export var particulas_dispersion: float = 25.0
@export var particulas_velocidad_min: float = 0.1
@export var particulas_velocidad_max: float = 0.8
@export var particulas_gravedad: Vector3 = Vector3(0, 0.1, 0)
@export var particulas_escala_min: float = 0.005
@export var particulas_escala_max: float = 0.02
@export_category("Sombra")
@export var sombra_tamano: Vector2 = Vector2(0.9, 0.9)  ## Tamaño de la sombra falsa circular
@export var sombra_opacidad: float = 1.0
@export var sombra_suavizado: float = 0.8
@export var sombra_offset_y: float = -0.01  ## Offset vertical (negativo = más pegada al suelo, bajo el modelo)
# Estado interno
var golpes_recibidos: int = 0
var mesh_instance: MeshInstance3D
var sombra_nodo: Node = null  ## Sombra falsa (excluida del parpadeo)
var _flash_gen: int = 0  ## Generación del flash: golpes seguidos no se pisan entre sí
var _punch_tween: Tween = null  ## Punch de escala del defensor (se mata para no acumular tamaño)
var _escala_base: Vector3 = Vector3.ZERO
var material_original: Material
var material_dano: StandardMaterial3D


func _ready():
	add_to_group("escudos")
	# NOTA: _escala_base NO se captura aquí. Si el escudo se coloca/regenera por
	# código, su escala definitiva se aplica DESPUÉS de add_child y este _ready
	# guardaría la escala del prefab (1.0): el punch del impacto "restauraría"
	# esa escala obsoleta y el escudo quedaría gigante. Se captura de forma
	# perezosa en _flash_dano(), en el momento del primer impacto, cuando la
	# escala ya es la definitiva (ver también AllyBallestera._regenerar_escudo_piso).

	# En perspectiva 2.5D, los escudos aliados deben permanecer detrás de la protagonista y defensoras
	# para evitar que la malla 3D atraviese o corte al personaje que se mueva por la plataforma
	if not es_escudo_enemigo and auto_profundidad_aliado:
		if global_position.z > plano_profundidad_aliado_z:
			global_position.z = plano_profundidad_aliado_z

	# Configurar colisiones
	# Layer 2: escudo (los goblins pueden detectarlo)
	# Mask: solo enemigos/flechas enemigas si no bloquea jugador
	if not bloquear_jugador:
		collision_layer = 2  # Layer del escudo
		collision_mask = 0  # No detecta nada activamente

	# Asegurar que todas las mallas del escudo estén en la Capa 1 (renderizado frontal junto a personajes y entorno)
	for mi in _recolectar_mallas():
		mi.layers = 1

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
			# Heredar sombreado y outline: los escudos usan UNSHADED con un
			# next_pass de línea negra (TOON_LINEANEGRA). Sombrearlos de nuevo
			# los vuelve negros en escenas con poca luz (mapa debug).
			material_dano.shading_mode = material_original.shading_mode
			material_dano.next_pass = material_original.next_pass
		material_dano.emission_enabled = true
		material_dano.emission = color_dano
		material_dano.emission_energy_multiplier = 0.0

	# Sombra falsa circular (igual que la de los enemigos), SOLO en los escudos enemigos
	if es_escudo_enemigo:
		var _sombra := SombraPersonaje.new()
		_sombra.tamano = sombra_tamano
		_sombra.opacidad = sombra_opacidad
		_sombra.suavizado = sombra_suavizado
		_sombra.offset_y = sombra_offset_y
		# Prioridad mínima: la sombra se dibuja ANTES que cualquier otro
		# transparente y siempre queda POR DEBAJO del modelo 3D.
		_sombra.prioridad_render = -128
		add_child(_sombra)
		sombra_nodo = _sombra


func _find_mesh_instance(node: Node):
	for child in node.get_children():
		if child is MeshInstance3D and mesh_instance == null:
			mesh_instance = child
			return
		_find_mesh_instance(child)


## Recolecta TODAS las mallas del escudo (las barricadas tienen varias piezas)
func _recolectar_mallas() -> Array[MeshInstance3D]:
	var lista: Array[MeshInstance3D] = []
	_agregar_mallas(self, lista)
	return lista


func _agregar_mallas(nodo: Node, lista: Array[MeshInstance3D]) -> void:
	for child in nodo.get_children():
		if child == sombra_nodo:
			continue  # La sombra falsa no parpadea
		if child.is_in_group("flechas") or child.is_in_group("projectiles") or child.name.begins_with("Arrow") or child.name.begins_with("FLECHA"):
			continue  # Las flechas clavadas en el escudo no parpadean
		if child is MeshInstance3D:
			lista.append(child)
		_agregar_mallas(child, lista)


# Estado Gris Metálico (Reflejante)
const TEXTURA_ICONO_ESCUDO: Texture2D = preload("res://Entities/Ambiente_Escudo/Icono_escudo_gis.png")
@export_category("Icono Potenciado")
@export var altura_icono_potenciado: float = 2.05  ## Altura Y del icono flotante sobre el escudo para no tapar el borde superior
var es_metalico: bool = false
var aguante_metalico: int = 0
var material_metalico: StandardMaterial3D = null
var _icono_potenciado: Sprite3D = null
var _icono_tween: Tween = null


func _process(_delta: float) -> void:
	if es_metalico and _icono_potenciado and _icono_potenciado.visible:
		var t := Time.get_ticks_msec() / 1000.0
		_icono_potenciado.position.y = altura_icono_potenciado + sin(t * 3.5) * 0.06


## Activa el modo metálico gris: refleja flechas y absorbe hasta 2 golpes (no acumulable)
func activar_modo_metalico(aguante: int = 2) -> void:
	es_metalico = true
	aguante_metalico = min(aguante, 2)  # No acumulable: máximo 2 de aguante
	_crear_material_metalico()
	_aplicar_visual_metalico()
	_mostrar_icono_potenciado()


## Desactiva el modo metálico y regresa al material original de madera
func desactivar_modo_metalico() -> void:
	es_metalico = false
	aguante_metalico = 0
	_actualizar_visual_dano()
	_ocultar_icono_potenciado()


func es_reflejante() -> bool:
	return es_metalico and aguante_metalico > 0


func _setup_icono_potenciado() -> void:
	if _icono_potenciado:
		return

	_icono_potenciado = Sprite3D.new()
	_icono_potenciado.name = "IconoEscudoPotenciado"
	_icono_potenciado.texture = TEXTURA_ICONO_ESCUDO
	_icono_potenciado.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icono_potenciado.pixel_size = 0.0013  # Icono pequeño, nítido y estilizado
	_icono_potenciado.shaded = false
	_icono_potenciado.no_depth_test = false
	_icono_potenciado.render_priority = 6
	_icono_potenciado.position = Vector3(0.0, altura_icono_potenciado, 0.0)  # Flotando sobre la parte superior del escudo
	_icono_potenciado.modulate = Color(1.2, 1.2, 1.3, 0.0)
	_icono_potenciado.visible = false
	add_child(_icono_potenciado)


func _mostrar_icono_potenciado() -> void:
	_setup_icono_potenciado()
	if not _icono_potenciado:
		return

	_icono_potenciado.visible = true
	if _icono_tween and _icono_tween.is_valid():
		_icono_tween.kill()

	_icono_potenciado.scale = Vector3.ZERO
	_icono_potenciado.modulate.a = 0.0

	_icono_tween = create_tween().set_parallel(true)
	_icono_tween.tween_property(_icono_potenciado, "scale", Vector3.ONE * 0.8, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_icono_tween.tween_property(_icono_potenciado, "modulate:a", 1.0, 0.2)


func _ocultar_icono_potenciado() -> void:
	if not _icono_potenciado or not _icono_potenciado.visible:
		return

	if _icono_tween and _icono_tween.is_valid():
		_icono_tween.kill()

	_icono_tween = create_tween().set_parallel(true)
	_icono_tween.tween_property(_icono_potenciado, "scale", Vector3.ZERO, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_icono_tween.tween_property(_icono_potenciado, "modulate:a", 0.0, 0.2)
	_icono_tween.chain().tween_callback(func():
		if is_instance_valid(_icono_potenciado):
			_icono_potenciado.visible = false
	)


## Recibe un impacto reflejante de flecha enemiga
func recibir_golpe_reflejo(_flecha: Node = null) -> void:
	if not es_reflejante():
		recibir_golpe(1)
		return

	# Reducir aguante metálico
	aguante_metalico -= 1
	AudioManager.play_sfx("parry")

	# Destello plateado de bloqueo
	_flash_metalico()

	if aguante_metalico <= 0:
		desactivar_modo_metalico()


func _crear_material_metalico() -> void:
	if material_metalico:
		return
	material_metalico = StandardMaterial3D.new()
	if material_original is StandardMaterial3D:
		material_metalico.shading_mode = material_original.shading_mode
		material_metalico.next_pass = material_original.next_pass
	# Color gris metálico acerado visible e inconfundible (sin textura de madera)
	material_metalico.albedo_color = Color(0.70, 0.72, 0.76, 1.0)
	material_metalico.metallic = 0.85
	material_metalico.roughness = 0.25
	material_metalico.emission_enabled = true
	material_metalico.emission = Color(0.35, 0.38, 0.45)
	material_metalico.emission_energy_multiplier = 0.35


func _aplicar_visual_metalico() -> void:
	_crear_material_metalico()
	if not material_metalico:
		return
	var mallas: Array[MeshInstance3D] = _recolectar_mallas()
	for mi in mallas:
		var num_sups: int = mi.mesh.get_surface_count() if mi.mesh else 1
		for si in range(num_sups):
			mi.set_surface_override_material(si, material_metalico)


func _flash_metalico() -> void:
	var mallas: Array[MeshInstance3D] = _recolectar_mallas()
	if mallas.is_empty():
		return
	var flash_mat := StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.emission_enabled = true
	flash_mat.emission = Color(0.8, 0.95, 1.0)
	flash_mat.emission_energy_multiplier = 4.0
	for mi in mallas:
		var num_sups: int = mi.mesh.get_surface_count() if mi.mesh else 1
		for si in range(num_sups):
			mi.set_surface_override_material(si, flash_mat)

	await get_tree().create_timer(duracion_flash).timeout
	if is_instance_valid(self):
		if es_metalico and aguante_metalico > 0:
			_aplicar_visual_metalico()
		else:
			_actualizar_visual_dano()


func recibir_golpe(amount: int = 1):
	if es_metalico and aguante_metalico > 0:
		recibir_golpe_reflejo(null)
		return

	golpes_recibidos += amount

	# Reproducir sonido de daño al escudo
	AudioManager.play_shield_hit()

	# Actualizar visual de daño
	_actualizar_visual_dano()

	# Parpadeo (enemigo: rojo múltiple; defensor: blanco único) y luego destruir si toca
	await _flash_dano()

	# Verificar si debe destruirse (tras el parpadeo)
	if golpes_recibidos >= golpes_para_destruir:
		_destruir()


func _actualizar_visual_dano():
	if es_metalico and aguante_metalico > 0:
		_aplicar_visual_metalico()
		return

	var mallas: Array[MeshInstance3D] = _recolectar_mallas()
	if mallas.is_empty() or not material_dano:
		return

	# Calcular progreso de daño (0.0 a 1.0)
	var progreso: float = clampf(float(golpes_recibidos) / float(golpes_para_destruir), 0.0, 1.0)

	# Mezclar color original con rojo según el daño
	if material_original is StandardMaterial3D:
		material_dano.albedo_color = material_original.albedo_color.lerp(
			color_dano, progreso * intensidad_tinte_dano
		)
	else:
		material_dano.albedo_color = Color.WHITE.lerp(color_dano, progreso * intensidad_tinte_dano)

	var mat_aplicar: Material = material_dano if progreso > 0.001 else material_original
	for mi in mallas:
		var num_sups: int = mi.mesh.get_surface_count() if mi.mesh else 1
		for si in range(num_sups):
			mi.set_surface_override_material(si, mat_aplicar)


func _flash_dano() -> void:
	var mallas := _recolectar_mallas()
	if mallas.is_empty():
		return

	_flash_gen += 1
	var gen_actual: int = _flash_gen

	# Punch de escala: expansión y contracción al recibir impacto (tanto escudos aliados como enemigos).
	# Se mata el punch anterior y se parte siempre de la base: los golpes seguidos no pueden acumular tamaño.
	# La base se re-adoptar de la escala actual si no hay punch en vuelo: así la
	# escala capturada es siempre la real colocada (evita escudos gigantes cuando
	# la escala definitiva se aplicó después del _ready).
	if _punch_tween and _punch_tween.is_valid():
		_punch_tween.kill()
	else:
		_escala_base = scale
	scale = _escala_base
	_punch_tween = create_tween()
	_punch_tween.tween_property(self, "scale", _escala_base * 1.08, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_punch_tween.tween_property(self, "scale", _escala_base, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Parpadeo rojo vívido visible e inconfundible en todos los escudos
	var flash_rojo := _crear_material_flash(Color(1.0, 0.08, 0.08, 1.0), intensidad_flash)
	var previos_rojo := _tomar_previos(mallas)
	var repeticiones: int = maxi(parpadeos_rojo_enemigo, 2)
	for _rep in range(repeticiones):
		if gen_actual != _flash_gen or not is_inside_tree():
			return
		_aplicar_material(previos_rojo, flash_rojo)
		await get_tree().create_timer(intervalo_parpadeo).timeout
		if gen_actual != _flash_gen or not is_inside_tree():
			return
		_restaurar_flash(previos_rojo)
		await get_tree().create_timer(intervalo_parpadeo).timeout


func _crear_material_flash(color: Color, intensidad: float) -> StandardMaterial3D:
	var flash_mat := StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.albedo_color = color
	flash_mat.emission_enabled = true
	flash_mat.emission = color
	flash_mat.emission_energy_multiplier = intensidad
	return flash_mat


## Guarda los overrides actuales de todas las superficies
func _tomar_previos(mallas: Array[MeshInstance3D]) -> Array:
	var previos: Array = []
	for mi in mallas:
		var num_sups: int = mi.mesh.get_surface_count() if mi.mesh else 1
		for si in range(num_sups):
			previos.append([mi, si, mi.get_surface_override_material(si)])
	return previos


## Aplica el material de flash y devuelve los previos guardados
func _aplicar_flash(mallas: Array[MeshInstance3D], flash_mat: Material) -> Array:
	var previos := _tomar_previos(mallas)
	_aplicar_material(previos, flash_mat)
	return previos


func _aplicar_material(previos: Array, flash_mat: Material) -> void:
	for p in previos:
		var mi_prev: MeshInstance3D = p[0] as MeshInstance3D
		if is_instance_valid(mi_prev):
			mi_prev.set_surface_override_material(int(p[1]), flash_mat)


## Restaura los overrides previos (un golpe posterior no corta el destello ajeno)
func _restaurar_flash(previos: Array) -> void:
	for p in previos:
		var mi_prev: MeshInstance3D = p[0] as MeshInstance3D
		if is_instance_valid(mi_prev):
			mi_prev.set_surface_override_material(int(p[1]), p[2] as Material)


func _destruir():
	_ocultar_icono_potenciado()
	destruido.emit()
	AudioManager.play_shield_break()

	# Humo de salto a ambos lados al romperse el escudo
	VFXFactory.spawn_shield_break_smoke(self, global_position)

	# Instanciar el escudo roto
	if escena_escudo_roto:
		var escudo_roto = escena_escudo_roto.instantiate()

		# Pasar el estado de daño visual (nivel del PENÚLTIMO golpe, acotado entre 0.0 y 1.0)
		var progreso_previo: float = clampf(float(golpes_recibidos - 1) / float(golpes_para_destruir), 0.0, 1.0)
		escudo_roto.color_dano_heredado = color_dano
		escudo_roto.progreso_dano = progreso_previo
		escudo_roto.intensidad_tinte_heredado = minf(intensidad_tinte_dano, 0.35)

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

		var escudo_partes: Node3D = null
		for child in escudo_roto.get_children():
			if child is Node3D:
				escudo_partes = child
				break
		
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
