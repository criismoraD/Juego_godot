@tool
class_name TorreDeAsedio
extends Node3D

## Torre de Asedio: Máquina de guerra móvil para el Nivel 5.
## Se desplaza hasta una posición X configurada, se detiene y genera
## enemigos (arqueras y ballesteros goblin) en su rampa que disparan
## desde ella y no pueden salir de sus límites.

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTES Y CONFIGURACIÓN
# ═══════════════════════════════════════════════════════════════════════════════
const MAT_TORRE: Material = preload("res://Entities/Torre_de_asedio/Torre_de_asedio_MAT.tres")
const ESCENA_GOBLIN_BALLESTERO: PackedScene = preload("res://Entities/Enemigo_Goblin/Goblin.tscn")
const ESCENA_GOBLIN_ARQUERA: PackedScene = preload("res://Entities/Enemigo_Goblin_Girl/GoblinGirl.tscn")

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
# ═══════════════════════════════════════════════════════════════════════════════
@export_category("Desplazamiento")
@export var se_desplaza: bool = true  ## Si es true, avanza hasta alcanzar x_detencion
@export var velocidad_desplazamiento: float = 1.6  ## Velocidad de traslación (unidades/s)
@export var x_detencion: float = 4.2  ## Coordenada X global donde se frena la torre
@export var mover_hacia_izquierda: bool = true  ## Avanza hacia -X si es true

@export_category("Generación en Rampa")
@export var max_enemigos_rampa: int = 5  ## Máximo de enemigos simultáneos en la rampa
@export var intervalo_respawn: float = 2.0  ## Segundos para spawnear tras la muerte de uno
@export var margen_limite_rampa_x: float = 0.2  ## Margen de seguridad sobre el collider

@export_category("Referencias de Nodos")
@export var punto_spawn: Node3D = null  ## Punto de spawn editable en la escena
@export var rampa_piso: StaticBody3D = null  ## Collider de la rampa que actúa como piso
@export var colision_rampa: CollisionShape3D = null  ## Forma del piso de la rampa
@export var limites_rampa: StaticBody3D = null  ## Barreras laterales y frontales

# ═══════════════════════════════════════════════════════════════════════════════
# VARIABLES DE ESTADO
# ═══════════════════════════════════════════════════════════════════════════════
var torre_activa: bool = false
var se_detuvo: bool = false
var posicion_inicial: Vector3 = Vector3.ZERO
var rotacion_inicial: Vector3 = Vector3.ZERO

var _enemigos_en_rampa: Array[Node3D] = []
var _timer_spawn: float = 0.0
var _proximo_tipo_arquera: bool = false


# ═══════════════════════════════════════════════════════════════════════════════
# CICLO DE VIDA
# ═══════════════════════════════════════════════════════════════════════════════
func _enter_tree() -> void:
	_aplicar_material_textura()


func _ready() -> void:
	_aplicar_material_textura()

	posicion_inicial = global_position
	rotacion_inicial = rotation

	# Obtener referencias fallback si no fueron asignadas por export
	if not punto_spawn:
		punto_spawn = get_node_or_null("Aparicion")
	if not punto_spawn:
		punto_spawn = get_node_or_null("PuntoSpawn")
	if not rampa_piso:
		rampa_piso = get_node_or_null("RampaPiso")
	if not colision_rampa and rampa_piso:
		colision_rampa = rampa_piso.get_node_or_null("CollisionShape3D")
	if not limites_rampa:
		limites_rampa = get_node_or_null("LimitesRampa")


	if Engine.is_editor_hint():
		return

	# Iniciar desactivada por defecto (solo visible y funcional en Oleada 5)
	desactivar_torre()


func _aplicar_material_textura() -> void:
	var modelo = get_node_or_null("ModeloTorre")
	if is_instance_valid(modelo):
		if modelo is MeshInstance3D:
			modelo.material_override = MAT_TORRE
			modelo.set_surface_override_material(0, MAT_TORRE)
		for child in modelo.find_children("*", "MeshInstance3D", true, false):
			if child is MeshInstance3D:
				child.material_override = MAT_TORRE
				child.set_surface_override_material(0, MAT_TORRE)




func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not torre_activa:
		return


	# 1. Movimiento hasta el punto de detención
	if not se_detuvo and se_desplaza:
		_procesar_desplazamiento(delta)

	# 2. Si ya está detenida, gestionar spawns y retención de enemigos en la rampa
	if se_detuvo:
		_procesar_spawner_rampa(delta)
		_restringir_enemigos_a_la_rampa()


# ═══════════════════════════════════════════════════════════════════════════════
# CONTROL DE ACTIVACIÓN Y VISIBILIDAD (NIVEL 5)
# ═══════════════════════════════════════════════════════════════════════════════
func activar_torre() -> void:
	torre_activa = true
	visible = true
	set_physics_process(true)
	se_detuvo = false
	_timer_spawn = 0.5  # Comienza a spawnear poco después de detenerse

	# Habilitar colisiones de la rampa
	_set_colisiones_activas(true)


func desactivar_torre() -> void:
	torre_activa = false
	visible = false
	set_physics_process(false)
	se_detuvo = false

	# Limpiar enemigos que hayan quedado en la rampa
	_limpiar_enemigos_rampa()

	# Deshabilitar colisiones para que no interfieran en otras oleadas
	_set_colisiones_activas(false)

	# Regresar a la posición inicial configurada
	if posicion_inicial != Vector3.ZERO:
		global_position = posicion_inicial


# ═══════════════════════════════════════════════════════════════════════════════
# DESPLAZAMIENTO
# ═══════════════════════════════════════════════════════════════════════════════
func _procesar_desplazamiento(delta: float) -> void:
	var direccion: float = -1.0 if mover_hacia_izquierda else 1.0
	global_position.x += direccion * velocidad_desplazamiento * delta

	# Comprobar si alcanzó la posición de detención
	var llego_a_destino: bool = false
	if mover_hacia_izquierda and global_position.x <= x_detencion:
		llego_a_destino = true
		global_position.x = x_detencion
	elif not mover_hacia_izquierda and global_position.x >= x_detencion:
		llego_a_destino = true
		global_position.x = x_detencion

	if llego_a_destino:
		se_detuvo = true
		_timer_spawn = 0.3  # Empieza a generar defensores en la rampa


# ═══════════════════════════════════════════════════════════════════════════════
# SPAWNER Y GESTIÓN DE LA RAMPA
# ═══════════════════════════════════════════════════════════════════════════════
func _procesar_spawner_rampa(delta: float) -> void:
	# Filtrar enemigos que ya hayan muerto o sido liberados
	_filtrar_enemigos_vivos()

	if _enemigos_en_rampa.size() >= max_enemigos_rampa:
		return

	_timer_spawn -= delta
	if _timer_spawn <= 0.0:
		_timer_spawn = intervalo_respawn
		_spawnear_enemigo_en_rampa()


func _spawnear_enemigo_en_rampa() -> void:
	if not punto_spawn or not is_instance_valid(punto_spawn):
		return

	var escena_a_instanciar: PackedScene = ESCENA_GOBLIN_ARQUERA if _proximo_tipo_arquera else ESCENA_GOBLIN_BALLESTERO
	_proximo_tipo_arquera = not _proximo_tipo_arquera

	var nuevo_enemigo = escena_a_instanciar.instantiate() as Node3D
	if not nuevo_enemigo:
		return

	# Añadir al nivel
	var parent_destino = get_parent() if get_parent() else self
	parent_destino.add_child(nuevo_enemigo)

	# Ubicación en el punto de spawn dentro de la sala interior de la torre
	nuevo_enemigo.global_position = Vector3(punto_spawn.global_position.x, punto_spawn.global_position.y + 0.05, punto_spawn.global_position.z)

	# Añadir colisionador de profundidad en Z (Hitbox 2.5D) para que las flechas de la protagonista
	# (que viajan en el plano Z de juego) impacten a la unidad con precisión sin alterar su movimiento en la rampa
	var hitbox_25d := CollisionShape3D.new()
	hitbox_25d.name = "Hitbox25D_Torre"
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(0.5, 0.7, 3.5)
	hitbox_25d.shape = box_shape
	hitbox_25d.position = Vector3(0.0, 0.35, 1.25)
	nuevo_enemigo.add_child(hitbox_25d)

	# Asignar configuración especial para que sepa que está asignado a la rampa
	nuevo_enemigo.set_meta("es_enemigo_torre_asedio", true)
	nuevo_enemigo.set_meta("torre_origen", self)

	# Los enemigos que salen del spawn de la torre van sin sombra falsa activada
	# (la sombra real proyectada se mantiene)
	if nuevo_enemigo.has_method("desactivar_sombra"):
		nuevo_enemigo.desactivar_sombra()

	# Asignar una ranura (slot) de posición a lo largo del puente de madera
	var slot: int = _obtener_siguiente_slot_libre()
	var destino_x: float = _obtener_x_para_enemigo(slot)
	nuevo_enemigo.set_meta("slot_rampa", slot)
	nuevo_enemigo.set_meta("destino_rampa_x", destino_x)

	# Ajustar la distancia de caminata requerida para llegar a su estación en el puente
	var dist_a_caminar: float = max(0.4, abs(punto_spawn.global_position.x - destino_x))
	if "distancia_minima_caminar" in nuevo_enemigo:
		nuevo_enemigo.distancia_minima_caminar = dist_a_caminar
	if "distancia_maxima_caminar" in nuevo_enemigo:
		nuevo_enemigo.distancia_maxima_caminar = dist_a_caminar + 0.4
	if "target_walk_distance" in nuevo_enemigo:
		nuevo_enemigo.target_walk_distance = dist_a_caminar
	if "distancia_minima_entre_enemigos" in nuevo_enemigo:
		nuevo_enemigo.distancia_minima_entre_enemigos = 0.2

	_enemigos_en_rampa.append(nuevo_enemigo)


func _obtener_siguiente_slot_libre() -> int:
	var slots_ocupados: Array[int] = []
	for e in _enemigos_en_rampa:
		if is_instance_valid(e) and e.is_inside_tree() and e.has_meta("slot_rampa"):
			slots_ocupados.append(e.get_meta("slot_rampa"))
	for i in range(max_enemigos_rampa):
		if not slots_ocupados.has(i):
			return i
	return 0


func _obtener_x_para_enemigo(slot: int) -> float:
	var borde_frontal: float = _obtener_borde_frontal_rampa_x()
	var spawn_x: float = punto_spawn.global_position.x if punto_spawn else global_position.x
	# Espaciar a los defensores a lo largo del puente:
	# El slot 0 va a la punta del puente (borde_frontal + 0.15)
	# Los siguientes slots se posicionan sucesivamente más atrás
	var longitud_rampa: float = max(0.8, abs(spawn_x - borde_frontal))
	var paso: float = (longitud_rampa * 0.8) / float(max(1, max_enemigos_rampa - 1))
	return borde_frontal + 0.15 + (float(slot) * paso)


func _filtrar_enemigos_vivos() -> void:
	var lista_vivos: Array[Node3D] = []
	for e in _enemigos_en_rampa:
		if is_instance_valid(e) and e.is_inside_tree():
			if "current_state" in e:
				# Excluir si está muriendo o muerto
				var state_val = e.get("current_state")
				if state_val != 2 and state_val != 3:  # 2: DYING, 3: DEAD en EnemyBase
					lista_vivos.append(e)
			else:
				lista_vivos.append(e)
	_enemigos_en_rampa = lista_vivos


## Garantiza que los enemigos en la rampa avancen hasta su estación asignada sin salir del puente,
## y permanezcan alineados en el carril Z de la rampa.
func _restringir_enemigos_a_la_rampa() -> void:
	var limite_izq_x: float = _obtener_borde_frontal_rampa_x()
	var limite_der_x: float = _obtener_borde_trasero_rampa_x()
	var z_rampa: float = punto_spawn.global_position.z if punto_spawn else global_position.z

	for e in _enemigos_en_rampa:
		if not is_instance_valid(e) or not e.is_inside_tree():
			continue

		# Forzar que se mantengan en el carril Z de la rampa/puente
		e.global_position.z = z_rampa

		# Destino específico de este enemigo en el puente
		var destino_x: float = e.get_meta("destino_rampa_x", limite_izq_x)

		# Si el enemigo alcanza o supera su posición asignada hacia la izquierda (-X)
		if e.global_position.x <= destino_x:
			e.global_position.x = destino_x
			if "velocity" in e:
				e.velocity.x = 0.0

			# Forzarlo a detenerse y disparar desde su posición en el puente
			if e.has_method("_change_state") and "State" in e:
				var state_enum = e.get("State")
				if "SHOOTING" in state_enum and e.get("current_state") == state_enum["WALKING"]:
					e._change_state(state_enum["SHOOTING"])

		# Si retrocede más allá del origen de la rampa (+X)
		elif e.global_position.x >= limite_der_x:
			e.global_position.x = limite_der_x
			if "velocity" in e:
				e.velocity.x = 0.0


func _calcular_bounds_mundo_rampa_x(forma: BoxShape3D) -> Vector2:
	var xf := colision_rampa.global_transform
	var ext := forma.size * 0.5
	var min_x := INF
	var max_x := -INF
	for cx in [-ext.x, ext.x]:
		for cy in [-ext.y, ext.y]:
			for cz in [-ext.z, ext.z]:
				var px: float = (xf * Vector3(cx, cy, cz)).x
				min_x = min(min_x, px)
				max_x = max(max_x, px)
	return Vector2(min_x, max_x)


func _obtener_borde_frontal_rampa_x() -> float:
	if colision_rampa and is_instance_valid(colision_rampa):
		var forma := colision_rampa.shape as BoxShape3D
		if forma:
			var bounds := _calcular_bounds_mundo_rampa_x(forma)
			# En el modelo 3D, el puente de madera transitable comienza en bounds.x + 0.95
			return max(bounds.x + 0.95, bounds.x + margen_limite_rampa_x)
	if punto_spawn:
		return punto_spawn.global_position.x - 2.0
	return global_position.x - 2.0


func _obtener_borde_trasero_rampa_x() -> float:
	if colision_rampa and is_instance_valid(colision_rampa):
		var forma := colision_rampa.shape as BoxShape3D
		if forma:
			var bounds := _calcular_bounds_mundo_rampa_x(forma)
			return bounds.y - margen_limite_rampa_x
	if punto_spawn:
		return punto_spawn.global_position.x + 0.8
	return global_position.x + 0.8



func _limpiar_enemigos_rampa() -> void:
	for e in _enemigos_en_rampa:
		if is_instance_valid(e) and e.is_inside_tree():
			e.queue_free()
	_enemigos_en_rampa.clear()


func _set_colisiones_activas(activo: bool) -> void:
	if rampa_piso and is_instance_valid(rampa_piso):
		for child in rampa_piso.get_children():
			if child is CollisionShape3D:
				child.set_deferred("disabled", not activo)
	if limites_rampa and is_instance_valid(limites_rampa):
		for child in limites_rampa.get_children():
			if child is CollisionShape3D:
				child.set_deferred("disabled", not activo)
