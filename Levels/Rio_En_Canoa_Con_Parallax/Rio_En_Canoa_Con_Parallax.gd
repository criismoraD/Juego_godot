class_name RioEnCanoaConParallax
extends Node3D

## Controlador del escenario 'Rio en canoa con paralax'.
## Combina la iluminación, cámara, agua y peces de NIVEL01 con un sistema
## de fondo con doble profundidad parallax (cielo atardecer y terreno rocoso en loop)
## y una canoa aliada que transporta a la protagonista hacia la derecha.

# === CONSTANTES ===
const VELOCIDAD_CANOA_DEFECTO: float = 0.65
const VELOCIDAD_PARALLAX_DEFECTO: float = 1.0

# === EXPORTS ===
@export_category("Control de Travesía")
@export var velocidad_canoa: float = VELOCIDAD_CANOA_DEFECTO  ## Velocidad de avance de la canoa (m/s)
@export var velocidad_parallax: float = VELOCIDAD_PARALLAX_DEFECTO  ## Velocidad del fondo rocoso
@export var travesia_activa: bool = true  ## Si false, detiene el avance de la canoa y el parallax

# === ONREADY ===
@onready var parallax_fondo: Node3D = find_child("ParallaxFondo", true, false) as Node3D
@onready var canoa_protagonista: CanoaAliada = find_child("CanoaProtagonistaRio", true, false) as CanoaAliada
@onready var water_plane: Node3D = find_child("WaterPlane", true, false) as Node3D
@onready var pez_1: Node3D = find_child("Pez", true, false) as Node3D
@onready var pez_2: Node3D = find_child("Pez2", true, false) as Node3D


# === FUNCIONES BUILT-IN ===
func _ready() -> void:
	_inicializar_escenario()


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


# === FUNCIONES PRIVADAS ===
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
