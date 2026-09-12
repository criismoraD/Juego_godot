@tool
class_name ControladorTrayectoriaEmbarcaciones
extends Node3D
## Controlador de rutas para embarcaciones en el nivel.
##
## Gestiona 4 puntos de trayectoria (cubos de colores) ordenados de izquierda a derecha:
##   1. Verde Fuerte: Spawn / Nacimiento de la Canoa Aliada (extremo izquierdo).
##   2. Verde Suave:  Destino / Parada de la Canoa Aliada.
##   3. Rojo Suave:   Destino / Parada de la Balsa Pirata.
##   4. Rojo Fuerte:  Spawn / Nacimiento de la Balsa Pirata (extremo derecho).
##
## Características principales:
##   - Sincronización Y/Z: Al mover CUALQUIER cubo en Y o Z en el editor, todos los demás
##     lo siguen instantáneamente para mantener la misma altura de agua y profundidad.
##   - Posiciones X independientes: Cada cubo se puede mover libremente en el eje X.
##   - Visibilidad: Los cubos son visibles en el editor para posicionarlos, y se ocultan
##     automáticamente durante el juego.
##   - Spawn dinámico: Al iniciar el juego, las embarcaciones se instancian en los cubos
##     fuertes y navegan meciéndose hacia los cubos suaves donde se detienen.

# === SEÑALES ===
signal canoa_ha_llegado
signal balsa_ha_llegado

# === ESCENAS PRECARGADAS ===
const ESCENA_CANOA: PackedScene = preload("res://Entities/Ambiente_Canoa_Aliada/CanoaAliada.tscn")
const ESCENA_BALSA: PackedScene = preload("res://Entities/Ambiente_Balsa_Pirata/BalsaPirata.tscn")

# === PUNTOS DE TRAYECTORIA (CUBOS) ===
@export_category("Puntos de Trayectoria")
@export var punto_verde_fuerte: Node3D = null
@export var punto_verde_suave: Node3D = null
@export var punto_rojo_suave: Node3D = null
@export var punto_rojo_fuerte: Node3D = null

# === SINCRONIZACIÓN Y / Z ===
@export_category("Sincronización Y / Z")
@export var sincronizar_y_z_en_editor: bool = true  ## Al mover cualquier cubo en Y o Z, los otros 3 lo siguen.

@export var y_comun: float = 0.0:
	set(val):
		y_comun = val
		_aplicar_y_a_todos(val)

@export var z_comun: float = 0.0:
	set(val):
		z_comun = val
		_aplicar_z_a_todos(val)

# === SPAWN DE EMBARCACIONES ===
@export_category("Spawn de Embarcaciones")
@export var spawn_al_iniciar: bool = false  ## Si true, spawnea canoa y balsa al iniciar el nivel (por defecto false, se activa en nivel 5)
@export var velocidad_canoa: float = 0.8  ## m/s (reducido a la mitad)
@export var velocidad_balsa: float = 0.7  ## m/s (reducido a la mitad)

# === VISUALIZACIÓN EN JUEGO ===
@export_category("Visualización")
@export var mostrar_cubos_en_juego: bool = false  ## Depuración: mantener visibles en runtime

# === ESTADO PRIVADO ===
var _ultimo_y: float = 0.0
var _ultimo_z: float = 0.0
var _posiciones_iniciadas: bool = false
var _sincronizando: bool = false

var _instancia_canoa: CanoaAliada = null
var _instancia_balsa: BalsaPirata = null
var _canoa_en_destino: bool = false
var _balsa_en_destino: bool = false


# === FUNCIONES BUILT-IN ===
func _ready() -> void:
	_vincular_puntos()

	if Engine.is_editor_hint():
		_inicializar_referencias_editor()
		return

	# === EN JUEGO (RUNTIME) ===
	_ocultar_todos_los_cubos()

	if spawn_al_iniciar:
		call_deferred("spawnear_ambas")


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint() and not _posiciones_iniciadas:
		return
	sincronizar_posiciones()


## Sincroniza las posiciones Y y Z de todos los puntos de trayectoria.
func sincronizar_posiciones() -> void:
	if not sincronizar_y_z_en_editor:
		return

	_vincular_puntos()
	var puntos: Array[Node3D] = _obtener_lista_puntos()
	if puntos.size() < 4:
		return

	if not _posiciones_iniciadas:
		_inicializar_referencias_editor()
		return

	if _sincronizando:
		return

	# Detectar si algún cubo cambió su Y o Z respecto a la última cota conocida
	var nuevo_y: float = _ultimo_y
	var nuevo_z: float = _ultimo_z
	var hubo_cambio_y: bool = false
	var hubo_cambio_z: bool = false

	for p in puntos:
		if not is_instance_valid(p):
			continue
		if not is_equal_approx(p.position.y, _ultimo_y):
			nuevo_y = p.position.y
			hubo_cambio_y = true
		if not is_equal_approx(p.position.z, _ultimo_z):
			nuevo_z = p.position.z
			hubo_cambio_z = true

	if hubo_cambio_y:
		_sincronizando = true
		_ultimo_y = nuevo_y
		y_comun = nuevo_y
		_aplicar_y_a_todos(nuevo_y)
		_sincronizando = false

	if hubo_cambio_z:
		_sincronizando = true
		_ultimo_z = nuevo_z
		z_comun = nuevo_z
		_aplicar_z_a_todos(nuevo_z)
		_sincronizando = false


# === FUNCIONES PÚBLICAS (SPAWN Y CONTROL) ===
## Retorna si hay al menos una embarcación viva instanciada en el nivel.
func esta_activo() -> bool:
	return is_instance_valid(_instancia_canoa) or is_instance_valid(_instancia_balsa)


## Despawnea y elimina ambas embarcaciones si existen y resetea el combate naval.
func despawnear_ambas() -> void:
	if is_instance_valid(_instancia_canoa):
		_instancia_canoa.queue_free()
		_instancia_canoa = null
	if is_instance_valid(_instancia_balsa):
		_instancia_balsa.queue_free()
		_instancia_balsa = null
	_canoa_en_destino = false
	_balsa_en_destino = false
	if is_inside_tree():
		get_tree().call_group("flechas_fondo_esteticas", "queue_free")


## Spawnea ambas embarcaciones en sus puntos de spawn (cubos fuertes) y las despacha.
func spawnear_ambas() -> void:
	spawnear_canoa()
	spawnear_balsa()


## Spawnea la Canoa Aliada en Verde Fuerte y navega hacia Verde Suave.
func spawnear_canoa() -> CanoaAliada:
	_vincular_puntos()
	if not is_instance_valid(punto_verde_fuerte) or not is_instance_valid(punto_verde_suave):
		push_warning("[ControladorTrayectoria] No se encontraron los puntos verdes para Canoa Aliada.")
		return null

	if is_instance_valid(_instancia_canoa):
		_instancia_canoa.queue_free()

	_instancia_canoa = ESCENA_CANOA.instantiate() as CanoaAliada
	if not _instancia_canoa:
		return null

	add_child(_instancia_canoa)

	var pos_inicio: Vector3 = obtener_posicion_punto(punto_verde_fuerte)
	var pos_destino: Vector3 = obtener_posicion_punto(punto_verde_suave)

	_canoa_en_destino = false
	_instancia_canoa.position = pos_inicio
	_instancia_canoa.fijar_posicion_base(pos_inicio)

	if not _instancia_canoa.destino_alcanzado.is_connected(_on_canoa_destino_alcanzado):
		_instancia_canoa.destino_alcanzado.connect(_on_canoa_destino_alcanzado)

	# Navega de izquierda a derecha hasta el cubo verde suave
	_instancia_canoa.navegar_hacia_x(pos_destino.x, velocidad_canoa)
	return _instancia_canoa


## Spawnea la Balsa Pirata en Rojo Fuerte y navega hacia Rojo Suave.
func spawnear_balsa() -> BalsaPirata:
	_vincular_puntos()
	if not is_instance_valid(punto_rojo_fuerte) or not is_instance_valid(punto_rojo_suave):
		push_warning("[ControladorTrayectoria] No se encontraron los puntos rojos para Balsa Pirata.")
		return null

	if is_instance_valid(_instancia_balsa):
		_instancia_balsa.queue_free()

	_instancia_balsa = ESCENA_BALSA.instantiate() as BalsaPirata
	if not _instancia_balsa:
		return null

	add_child(_instancia_balsa)

	var pos_inicio: Vector3 = obtener_posicion_punto(punto_rojo_fuerte)
	var pos_destino: Vector3 = obtener_posicion_punto(punto_rojo_suave)

	_balsa_en_destino = false
	_instancia_balsa.position = pos_inicio
	_instancia_balsa.fijar_posicion_base(pos_inicio)

	if not _instancia_balsa.destino_alcanzado.is_connected(_on_balsa_destino_alcanzado):
		_instancia_balsa.destino_alcanzado.connect(_on_balsa_destino_alcanzado)

	# Navega de derecha a izquierda hasta el cubo rojo suave
	_instancia_balsa.navegar_hacia_x(pos_destino.x, velocidad_balsa)
	return _instancia_balsa


## Retorna la posición efectiva de un punto (incluyendo offset de su cubo visual si existe).
func obtener_posicion_punto(punto: Node3D) -> Vector3:
	if not is_instance_valid(punto):
		return Vector3.ZERO
	var hijos := punto.find_children("*", "MeshInstance3D", false, false)
	for h in hijos:
		var hijo_mesh := h as MeshInstance3D
		if is_instance_valid(hijo_mesh) and hijo_mesh != punto and not hijo_mesh.position.is_zero_approx():
			return punto.position + hijo_mesh.position
	return punto.position


## Retorna la referencia viva a la Canoa Aliada instanciada.
func obtener_canoa() -> CanoaAliada:
	return _instancia_canoa


## Retorna la referencia viva a la Balsa Pirata instanciada.
func obtener_balsa() -> BalsaPirata:
	return _instancia_balsa


## Ordena la destrucción con explosiones y hundimiento de la balsa pirata enemiga.
func destruir_balsa_enemiga() -> void:
	if is_instance_valid(_instancia_balsa) and _instancia_balsa.has_method("destruir_balsa"):
		_instancia_balsa.destruir_balsa()


## Oculta y despawnea inmediatamente la Canoa Aliada para que no aparezca en la cinemática de Perrena ni tras la oleada 5.
func ocultar_o_despawnear_canoa() -> void:
	if is_instance_valid(_instancia_canoa):
		if _instancia_canoa.has_method("ocultar_y_desactivar"):
			_instancia_canoa.ocultar_y_desactivar()
		else:
			_instancia_canoa.visible = false
		_instancia_canoa.queue_free()
		_instancia_canoa = null
	_canoa_en_destino = false
	if is_inside_tree():
		get_tree().call_group("flechas_fondo_esteticas", "queue_free")


func despawnear_canoa() -> void:
	ocultar_o_despawnear_canoa()


# === FUNCIONES PRIVADAS ===
func _vincular_puntos() -> void:
	if not is_instance_valid(punto_verde_fuerte):
		punto_verde_fuerte = _buscar_nodo(["PuntoVerdeFuerte", "%PuntoVerdeFuerte"])
	if not is_instance_valid(punto_verde_suave):
		punto_verde_suave = _buscar_nodo(["PuntoVerdeSuave", "%PuntoVerdeSuave"])
	if not is_instance_valid(punto_rojo_suave):
		punto_rojo_suave = _buscar_nodo(["PuntoRojoSuave", "%PuntoRojoSuave"])
	if not is_instance_valid(punto_rojo_fuerte):
		punto_rojo_fuerte = _buscar_nodo(["PuntoRojoFuerte", "%PuntoRojoFuerte"])


func _buscar_nodo(nombres: Array[String]) -> Node3D:
	for nom in nombres:
		if nom.begins_with("%"):
			var nodo_u := get_node_or_null(nom) as Node3D
			if is_instance_valid(nodo_u):
				return nodo_u
		else:
			var nodo_d := get_node_or_null(nom) as Node3D
			if is_instance_valid(nodo_d):
				return nodo_d
			var nodo_f := find_child(nom, true, false) as Node3D
			if is_instance_valid(nodo_f):
				return nodo_f
	return null


func _obtener_lista_puntos() -> Array[Node3D]:
	var lista: Array[Node3D] = []
	if is_instance_valid(punto_verde_fuerte):
		lista.append(punto_verde_fuerte)
	if is_instance_valid(punto_verde_suave):
		lista.append(punto_verde_suave)
	if is_instance_valid(punto_rojo_suave):
		lista.append(punto_rojo_suave)
	if is_instance_valid(punto_rojo_fuerte):
		lista.append(punto_rojo_fuerte)
	return lista


func _inicializar_referencias_editor() -> void:
	var puntos := _obtener_lista_puntos()
	if puntos.is_empty():
		return
	_ultimo_y = puntos[0].position.y
	_ultimo_z = puntos[0].position.z
	y_comun = _ultimo_y
	z_comun = _ultimo_z
	_posiciones_iniciadas = true


func _aplicar_y_a_todos(val_y: float) -> void:
	for p in _obtener_lista_puntos():
		if is_instance_valid(p):
			p.position.y = val_y


func _aplicar_z_a_todos(val_z: float) -> void:
	for p in _obtener_lista_puntos():
		if is_instance_valid(p):
			p.position.z = val_z


func _ocultar_todos_los_cubos() -> void:
	if mostrar_cubos_en_juego:
		return

	# Ocultar exclusivamente los 4 puntos de trayectoria y sus cubos visuales
	for p in _obtener_lista_puntos():
		if not is_instance_valid(p):
			continue
		p.visible = false
		for m in p.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if is_instance_valid(mi):
				mi.visible = false


func _on_canoa_destino_alcanzado() -> void:
	_canoa_en_destino = true
	canoa_ha_llegado.emit()
	_verificar_inicio_combate()


func _on_balsa_destino_alcanzado() -> void:
	_balsa_en_destino = true
	balsa_ha_llegado.emit()
	_verificar_inicio_combate()


func _verificar_inicio_combate() -> void:
	if _canoa_en_destino and _balsa_en_destino:
		if is_instance_valid(_instancia_canoa) and _instancia_canoa.has_method("iniciar_combate_tripulacion"):
			_instancia_canoa.iniciar_combate_tripulacion()
		if is_instance_valid(_instancia_balsa) and _instancia_balsa.has_method("iniciar_combate_tripulacion"):
			_instancia_balsa.iniciar_combate_tripulacion()

