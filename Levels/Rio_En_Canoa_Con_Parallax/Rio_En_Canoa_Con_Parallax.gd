class_name RioEnCanoaConParallax
extends Node3D

## Controlador del escenario 'Rio en canoa con paralax'.
## Combina la iluminación, cámara, agua y peces de NIVEL01 con un sistema
## de fondo con doble profundidad parallax (cielo atardecer y terreno rocoso en loop)
## y una canoa aliada que transporta a la protagonista hacia la derecha.

# === CONSTANTES ===
const VELOCIDAD_CANOA_DEFECTO: float = 0.65
const VELOCIDAD_PARALLAX_DEFECTO: float = 1.0
const ANCHO_AGUA_AMPLIADO: float = 120.0

# === EXPORTS ===
@export_category("Control de Travesía")
@export var velocidad_canoa: float = VELOCIDAD_CANOA_DEFECTO  ## Velocidad de avance de la canoa (m/s)
@export var velocidad_parallax: float = VELOCIDAD_PARALLAX_DEFECTO  ## Velocidad del fondo rocoso
@export var travesia_activa: bool = true  ## Si false, detiene el avance de la canoa y el parallax
@export var camara_sigue_canoa: bool = true  ## Si true, la cámara principal sigue el avance de la canoa aliada

# === ONREADY ===
@onready var parallax_fondo: Node3D = find_child("ParallaxFondo", true, false) as Node3D
@onready var canoa_protagonista: CanoaAliada = find_child("CanoaProtagonistaRio", true, false) as CanoaAliada
@onready var camara_principal: Camera3D = find_child("CamaraPrincipal", true, false) as Camera3D
@onready var water_plane: Node3D = find_child("WaterPlane", true, false) as Node3D
@onready var pez_1: Node3D = find_child("Pez", true, false) as Node3D
@onready var pez_2: Node3D = find_child("Pez2", true, false) as Node3D

# === VARIABLES PRIVADAS ===
var _offset_camara_x: float = 2.9400935
var _offset_water_x: float = 0.0675573
var _segmentos_agua: Array[Node3D] = []


# === FUNCIONES BUILT-IN ===
func _ready() -> void:
	if is_instance_valid(canoa_protagonista):
		var canoa_x: float = canoa_protagonista.global_position.x
		if is_instance_valid(camara_principal):
			_offset_camara_x = camara_principal.global_position.x - canoa_x
		if is_instance_valid(water_plane):
			_offset_water_x = water_plane.global_position.x - canoa_x

	if is_instance_valid(parallax_fondo):
		if parallax_fondo.has_method("fijar_camara_referencia") and is_instance_valid(camara_principal):
			parallax_fondo.call("fijar_camara_referencia", camara_principal)
		if parallax_fondo.has_method("_inicializar_capa_piso_aliado"):
			parallax_fondo.call("_inicializar_capa_piso_aliado")

	_inicializar_agua()
	_inicializar_escenario()


func _process(_delta: float) -> void:
	if camara_sigue_canoa and is_instance_valid(canoa_protagonista):
		var canoa_x: float = canoa_protagonista.global_position.x
		if is_instance_valid(camara_principal):
			camara_principal.global_position.x = canoa_x + _offset_camara_x
		if is_instance_valid(water_plane):
			water_plane.global_position.x = canoa_x + _offset_water_x


# === FUNCIONES PÚBLICAS ===
## Configura la velocidad conjunta de navegación y desplazamiento parallax.
func fijar_velocidad_travesia(nueva_vel_canoa: float, nueva_vel_parallax: float) -> void:
	velocidad_canoa = nueva_vel_canoa
	velocidad_parallax = nueva_vel_parallax

	if is_instance_valid(canoa_protagonista):
		canoa_protagonista.set("velocidad_avance", nueva_vel_canoa)
		if travesia_activa and canoa_protagonista.has_method("iniciar_travesia"):
			canoa_protagonista.call("iniciar_travesia", nueva_vel_canoa)

	if is_instance_valid(parallax_fondo):
		parallax_fondo.set("velocidad_terroso", nueva_vel_parallax)


## Pausa o reanuda la travesía del nivel.
func set_travesia_activa(activo: bool) -> void:
	travesia_activa = activo

	if is_instance_valid(canoa_protagonista):
		if activo:
			if canoa_protagonista.has_method("flotar"):
				canoa_protagonista.call("flotar")
			if canoa_protagonista.has_method("iniciar_travesia"):
				canoa_protagonista.call("iniciar_travesia", velocidad_canoa)
		else:
			if canoa_protagonista.has_method("detener"):
				canoa_protagonista.call("detener")

	if is_instance_valid(parallax_fondo) and parallax_fondo.has_method("set_desplazamiento_activo"):
		parallax_fondo.call("set_desplazamiento_activo", activo)


## Retorna la referencia viva a la canoa de la protagonista.
func obtener_canoa() -> CanoaAliada:
	return canoa_protagonista


## Retorna la referencia al controlador de parallax de fondo.
func obtener_parallax() -> Node3D:
	return parallax_fondo


## Retorna la referencia a la cámara principal del escenario.
func obtener_camara() -> Camera3D:
	return camara_principal


## Retorna la referencia al plano de agua principal.
func obtener_water_plane() -> Node3D:
	return water_plane


## Retorna los segmentos de agua que componen el río infinito en repetición.
func obtener_segmentos_agua() -> Array[Node3D]:
	return _segmentos_agua


## Retorna los segmentos de piso aliado sincronizados con la cordillera.
func obtener_segmentos_piso_aliado() -> Array[Node3D]:
	if is_instance_valid(parallax_fondo) and parallax_fondo.has_method("obtener_segmentos_piso_aliado"):
		return parallax_fondo.call("obtener_segmentos_piso_aliado")
	return []


func _inicializar_agua() -> void:
	_segmentos_agua.clear()
	# Asegurar que solo el WaterPlane principal esté activo y amplio
	for hijo in get_children():
		if hijo is Node3D and hijo.name.begins_with("WaterPlane"):
			if hijo == water_plane or hijo.name == "WaterPlane":
				hijo.visible = true
				hijo.scale.x = 4.0  # 120 metros de cauce sin cortes
				hijo.scale.z = 3.2  # Extensión hasta la base de la cordillera
				_segmentos_agua.append(hijo)
			else:
				# Desactivar planos duplicados para evitar cortes visuales
				hijo.visible = false

	if is_instance_valid(water_plane):
		water_plane.visible = true
		water_plane.scale.x = 4.0
		water_plane.scale.z = 3.2
		if not _segmentos_agua.has(water_plane):
			_segmentos_agua.append(water_plane)


func _inicializar_escenario() -> void:
	if is_instance_valid(canoa_protagonista):
		canoa_protagonista.set("velocidad_avance", velocidad_canoa)
		if travesia_activa:
			if canoa_protagonista.has_method("iniciar_travesia"):
				canoa_protagonista.call("iniciar_travesia", velocidad_canoa)
		else:
			if canoa_protagonista.has_method("detener"):
				canoa_protagonista.call("detener")

	if is_instance_valid(parallax_fondo):
		parallax_fondo.set("velocidad_terroso", velocidad_parallax)
		if parallax_fondo.has_method("set_desplazamiento_activo"):
			parallax_fondo.call("set_desplazamiento_activo", travesia_activa)
