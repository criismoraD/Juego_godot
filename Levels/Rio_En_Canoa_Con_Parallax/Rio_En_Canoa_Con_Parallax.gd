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
const MUSICA_VIAJE_RIO: int = 7  ## Índice en AudioManager de "Viaje por el rio"

# === EXPORTS ===
@export_category("Control de Travesía")
@export var velocidad_canoa: float = VELOCIDAD_CANOA_DEFECTO  ## Velocidad de avance de la canoa (m/s)
@export var velocidad_parallax: float = VELOCIDAD_PARALLAX_DEFECTO  ## Velocidad del fondo rocoso
@export var travesia_activa: bool = true  ## Si false, detiene el avance de la canoa y el parallax
@export var camara_sigue_canoa: bool = true  ## Si true, la cámara principal sigue el avance de la canoa aliada
@export var musica_viaje_rio: bool = true  ## Si true, suena "Viaje por el rio" al entrar al nivel
@export var focos_fijos_a_camara: bool = true  ## Si true, todos los focos LuzCentroPiso*/LuzTorre* acompañan a la cámara en X como un sol fijo mientras la cordillera hace scroll

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
var _focos_fijos: Array[SpotLight3D] = []
var _offsets_focos_x: Array[float] = []
var _segmentos_agua: Array[Node3D] = []


# === FUNCIONES BUILT-IN ===
func _ready() -> void:
	if is_instance_valid(canoa_protagonista):
		var canoa_x: float = canoa_protagonista.global_position.x
		if is_instance_valid(camara_principal):
			_offset_camara_x = camara_principal.global_position.x - canoa_x
		if is_instance_valid(water_plane):
			_offset_water_x = water_plane.global_position.x - canoa_x
	_inicializar_focos_fijos()

	if is_instance_valid(parallax_fondo):
		if parallax_fondo.has_method("fijar_camara_referencia") and is_instance_valid(camara_principal):
			parallax_fondo.call("fijar_camara_referencia", camara_principal)
		if parallax_fondo.has_method("_inicializar_capa_piso_aliado"):
			parallax_fondo.call("_inicializar_capa_piso_aliado")
		if parallax_fondo.has_method("_inicializar_capa_agua_textura"):
			parallax_fondo.call("_inicializar_capa_agua_textura")
		if parallax_fondo.has_method("_inicializar_capa_reflejo"):
			parallax_fondo.call("_inicializar_capa_reflejo")
		if parallax_fondo.has_method("_inicializar_capa_casa_boneta"):
			parallax_fondo.call("_inicializar_capa_casa_boneta")
		if parallax_fondo.has_method("_inicializar_capa_bosque_rojo"):
			parallax_fondo.call("_inicializar_capa_bosque_rojo")
		if parallax_fondo.has_method("aplicar_capas_fondo"):
			parallax_fondo.call("aplicar_capas_fondo")

	_inicializar_agua()
	_inicializar_escenario()


func _process(_delta: float) -> void:
	if camara_sigue_canoa and is_instance_valid(canoa_protagonista):
		var canoa_x: float = canoa_protagonista.global_position.x
		if is_instance_valid(camara_principal):
			camara_principal.global_position.x = canoa_x + _offset_camara_x
		if is_instance_valid(water_plane):
			water_plane.global_position.x = canoa_x + _offset_water_x
	_actualizar_focos_fijos()


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


## Retorna los focos que acompañan a la cámara como sol fijo.
func obtener_focos_fijos() -> Array[SpotLight3D]:
	return _focos_fijos


## Retorna el foco del piso 2 si existe en la escena.
func obtener_luz_piso2() -> SpotLight3D:
	return find_child("LuzCentroPiso2", true, false) as SpotLight3D


## Retorna los segmentos de agua que componen el río infinito en repetición.
func obtener_segmentos_agua() -> Array[Node3D]:
	return _segmentos_agua


## Retorna los segmentos de piso aliado sincronizados con la cordillera.
func obtener_segmentos_piso_aliado() -> Array[Node3D]:
	if is_instance_valid(parallax_fondo) and parallax_fondo.has_method("obtener_segmentos_piso_aliado"):
		return parallax_fondo.call("obtener_segmentos_piso_aliado")
	return []


func _inicializar_focos_fijos() -> void:
	_focos_fijos.clear()
	_offsets_focos_x.clear()
	if not is_instance_valid(camara_principal):
		return
	var candidatos: Array[Node] = find_children("*", "SpotLight3D", true, false)
	for candidato in candidatos:
		var foco: SpotLight3D = candidato as SpotLight3D
		if foco == null or not _es_foco_fijo(foco):
			continue
		_focos_fijos.append(foco)
		_offsets_focos_x.append(foco.global_position.x - camara_principal.global_position.x)


func _actualizar_focos_fijos() -> void:
	if not focos_fijos_a_camara or not is_instance_valid(camara_principal):
		return
	var camara_x: float = camara_principal.global_position.x
	for i in range(_focos_fijos.size()):
		var foco: SpotLight3D = _focos_fijos[i]
		if is_instance_valid(foco):
			foco.global_position.x = camara_x + _offsets_focos_x[i]


func _es_foco_fijo(foco: SpotLight3D) -> bool:
	var nombre: String = foco.name.to_lower()
	if nombre.begins_with("luzcentropiso"):
		return true
	if nombre.begins_with("luztorre"):
		return true
	return false


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
	if musica_viaje_rio:
		AudioManager.play_music(MUSICA_VIAJE_RIO)

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
