@tool
class_name BarcoMercado
extends Node3D

## Barco mercado de ambientación: flota sobre el agua con un bamboleo sutil.
##
## Aplica automáticamente el material y textura al modelo del barco importado
## y genera la animación por código combinando oscilaciones sinusoidales:
##   - Flotación (Y): sube y baja respecto a la línea de flotación.
##   - Balanceo (Roll Z): se mece de costado.
##   - Cabeceo (Pitch X): proa y popa suben alternadamente.

# ─────────────────────────────────────────────
# CONSTANTES
# ─────────────────────────────────────────────
const FASE_ALEATORIA: float = -1.0  ## Centinela: genera fase aleatoria al iniciar
const MATERIAL_DEFECTO: StandardMaterial3D = preload("res://Entities/Ambiente_BarcoMercado/BarcoMercado_Mat.tres")

# ─────────────────────────────────────────────
# EXPORTS – Material y Textura
# ─────────────────────────────────────────────
@export_category("Material y Textura")
@export var material_barco: StandardMaterial3D = MATERIAL_DEFECTO:
	set(nuevo_material):
		material_barco = nuevo_material
		_aplicar_material()

# ─────────────────────────────────────────────
# EXPORTS – Flotación Vertical (Y)
# ─────────────────────────────────────────────
@export_category("Flotación Vertical (Y)")
@export var amplitud_flotacion: float = 0.03  ## Amplitud del sube y baja (metros)
@export var frecuencia_flotacion: float = 0.28  ## Velocidad oscilación vertical (Hz)
@export var fase_flotacion: float = FASE_ALEATORIA  ## Fase inicial (radianes). -1 = aleatoria

# ─────────────────────────────────────────────
# EXPORTS – Balanceo Lateral (Roll Z)
# ─────────────────────────────────────────────
@export_category("Balanceo Lateral (Roll Z)")
@export var amplitud_balanceo: float = 1.2  ## Amplitud del balanceo lateral (grados)
@export var frecuencia_balanceo: float = 0.22  ## Velocidad del balanceo (Hz)
@export var fase_balanceo: float = FASE_ALEATORIA  ## Fase inicial (radianes). -1 = aleatoria

# ─────────────────────────────────────────────
# EXPORTS – Cabeceo Frontal (Pitch X)
# ─────────────────────────────────────────────
@export_category("Cabeceo Frontal (Pitch X)")
@export var amplitud_cabeceo: float = 0.7  ## Amplitud del cabeceo proa-popa (grados)
@export var frecuencia_cabeceo: float = 0.35  ## Velocidad del cabeceo (Hz)
@export var fase_cabeceo: float = FASE_ALEATORIA  ## Fase inicial (radianes). -1 = aleatoria

# ─────────────────────────────────────────────
# EXPORTS – Comportamiento
# ─────────────────────────────────────────────
@export_category("Comportamiento")
@export var capa_visual: int = 2:  ## Capa de renderizado (Fondo DOF = 2, Frente = 1)
	set(nueva_capa):
		capa_visual = nueva_capa
		_aplicar_capa_visual()

@export var flotar_al_iniciar: bool = true  ## Si true, anima desde el primer frame
@export var escala_tiempo: float = 1.0  ## Multiplicador global de velocidad de animación

# ─────────────────────────────────────────────
# VARIABLES PRIVADAS
# ─────────────────────────────────────────────
var _posicion_base: Vector3 = Vector3.ZERO
var _animando: bool = false
var _tiempo_acumulado: float = 0.0
var _fase_flotacion_real: float = 0.0
var _fase_balanceo_real: float = 0.0
var _fase_cabeceo_real: float = 0.0

# ─────────────────────────────────────────────
# BUILT-INS
# ─────────────────────────────────────────────
func _ready() -> void:
	_posicion_base = position
	_aplicar_material()
	_aplicar_capa_visual()
	
	if Engine.is_editor_hint():
		return
		
	_inicializar_fases()
	if flotar_al_iniciar:
		_animando = true


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not _animando:
		return
	_tiempo_acumulado += delta * maxf(escala_tiempo, 0.0)
	_aplicar_flotacion()


# ─────────────────────────────────────────────
# PUBLICAS
# ─────────────────────────────────────────────

## Activa la animación de flotación.
func iniciar_flotacion() -> void:
	_posicion_base = position
	_animando = true


## Detiene la animación y restaura la posición/rotación base.
func detener_flotacion() -> void:
	_animando = false
	position = _posicion_base
	rotation_degrees = Vector3.ZERO


## Calcula el desplazamiento vertical puro (sin modificar el nodo).
func calcular_desplazamiento_y(tiempo: float) -> float:
	return sin(TAU * frecuencia_flotacion * tiempo + _fase_flotacion_real) * amplitud_flotacion


## Calcula el roll (grados) puro.
func calcular_roll_grados(tiempo: float) -> float:
	return sin(TAU * frecuencia_balanceo * tiempo + _fase_balanceo_real) * amplitud_balanceo


## Calcula el pitch (grados) puro.
func calcular_pitch_grados(tiempo: float) -> float:
	return sin(TAU * frecuencia_cabeceo * tiempo + _fase_cabeceo_real) * amplitud_cabeceo


## Aplica el material configurado a todas las mallas hijas.
func aplicar_material() -> void:
	_aplicar_material()


# ─────────────────────────────────────────────
# PRIVADAS
# ─────────────────────────────────────────────

func _inicializar_fases() -> void:
	_fase_flotacion_real = _resolver_fase(fase_flotacion)
	_fase_balanceo_real  = _resolver_fase(fase_balanceo)
	_fase_cabeceo_real   = _resolver_fase(fase_cabeceo)


func _resolver_fase(fase: float) -> float:
	if fase == FASE_ALEATORIA:
		return randf() * TAU
	return fase


func _aplicar_flotacion() -> void:
	var t: float = _tiempo_acumulado
	position.y = _posicion_base.y + calcular_desplazamiento_y(t)
	rotation_degrees.z = calcular_roll_grados(t)
	rotation_degrees.x = calcular_pitch_grados(t)


func _aplicar_material() -> void:
	if material_barco == null:
		return
	_aplicar_material_recursivo(self)


func _aplicar_material_recursivo(nodo: Node) -> void:
	if nodo is MeshInstance3D:
		var mi: MeshInstance3D = nodo as MeshInstance3D
		mi.material_override = material_barco
		if mi.mesh != null and mi.mesh.get_surface_count() > 0:
			mi.set_surface_override_material(0, material_barco)
	for hijo: Node in nodo.get_children():
		_aplicar_material_recursivo(hijo)


func _aplicar_capa_visual() -> void:
	_asignar_capa_visual_recursiva(self, capa_visual)


func _asignar_capa_visual_recursiva(nodo: Node, capa: int) -> void:
	if nodo is VisualInstance3D:
		(nodo as VisualInstance3D).layers = capa
	for hijo: Node in nodo.get_children():
		_asignar_capa_visual_recursiva(hijo, capa)
