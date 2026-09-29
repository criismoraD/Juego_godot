@tool
class_name DummyBoya
extends Node3D

## Muñeco de pruebas con flotación suave de boya oceánica.
## Aplica el material con textura a las mallas del GLB y balancea solo
## el modelo visual (el origen queda fijo para posicionarlo con precisión).

const INDICE_SUPERFICIE_PRINCIPAL: int = 0

# ─────────────────────────────────────────────
# EXPORTS – Configuración Visual
# ─────────────────────────────────────────────
@export_category("Configuración Visual")
@export_flags_3d_render var capa_visual: int = 1:  ## Selector de capa visual de renderizado 3D (Capa 1 = Frente, Capa 2 = Fondo DOF)
	set(nueva_capa):
		capa_visual = nueva_capa
		_aplicar_capa_visual()

@export var material_dummy: StandardMaterial3D:
	set(nuevo_material):
		material_dummy = nuevo_material
		if is_node_ready():
			_aplicar_material()

# ─────────────────────────────────────────────
# EXPORTS – Flotación Boya
# ─────────────────────────────────────────────
@export_category("Flotación boya")
@export_group("Flotación boya")
@export_range(0.0, 1.0, 0.01) var amplitud_floteo: float = 0.15  ## Sube/baja en metros
@export_range(0.0, 4.0, 0.05) var velocidad_floteo: float = 1.2  ## Ritmo del vaivén
@export_range(0.0, 15.0, 0.5) var amplitud_balanceo: float = 4.0  ## Inclinación lateral en grados
@export var flotacion_activa: bool = true

@onready var modelo: Node3D = $Model

var _tiempo: float = 0.0
var _base_y: float = 0.0
var _base_rot_z: float = 0.0
var _factor_movimiento: float = 1.0
var _tween_frenado: Tween = null
var _esta_detenido: bool = false


func _ready() -> void:
	add_to_group("dummy_boya")
	if "fondo" in name.to_lower():
		capa_visual = 2
	_aplicar_material()
	_aplicar_capa_visual()
	if is_instance_valid(modelo):
		_base_y = modelo.position.y
		_base_rot_z = modelo.rotation.z


func _process(delta: float) -> void:
	if not flotacion_activa or delta <= 0.0:
		return
	if not is_instance_valid(modelo):
		return

	if _factor_movimiento <= 0.0001:
		modelo.position.y = move_toward(modelo.position.y, _base_y, delta * 0.5)
		modelo.rotation.z = move_toward(modelo.rotation.z, _base_rot_z, delta * deg_to_rad(5.0))
		return

	_tiempo += delta * velocidad_floteo * _factor_movimiento
	var offset_y: float = sin(_tiempo * TAU) * amplitud_floteo * _factor_movimiento
	var offset_rot_z: float = deg_to_rad(amplitud_balanceo) * sin(_tiempo * TAU * 0.8) * _factor_movimiento
	modelo.position.y = _base_y + offset_y
	modelo.rotation.z = _base_rot_z + offset_rot_z


## Frena lentamente el vaivén del dummy hasta detenerse completamente en su posición neutra.
func detener_suavemente(duracion: float = 1.2) -> void:
	_esta_detenido = true
	if _tween_frenado and _tween_frenado.is_valid():
		_tween_frenado.kill()
	_tween_frenado = create_tween()
	_tween_frenado.tween_property(self, "_factor_movimiento", 0.0, maxf(duracion, 0.1))\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)


## Reanuda gradualmente el movimiento y balanceo del dummy.
func reanudar_suavemente(duracion: float = 1.0) -> void:
	_esta_detenido = false
	if _tween_frenado and _tween_frenado.is_valid():
		_tween_frenado.kill()
	_tween_frenado = create_tween()
	_tween_frenado.tween_property(self, "_factor_movimiento", 1.0, maxf(duracion, 0.1))\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)


## Retorna true si el dummy está en estado detenido o frenando.
func esta_detenido() -> bool:
	return _esta_detenido


## Retorna el factor actual de movimiento (1.0 = normal, 0.0 = estático).
func obtener_factor_movimiento() -> float:
	return _factor_movimiento


## Aplica el material configurado a la instancia del modelo.
func aplicar_material() -> void:
	_aplicar_material()


func _aplicar_material() -> void:
	if material_dummy == null:
		return
	var raiz_modelo: Node = modelo
	if not is_instance_valid(raiz_modelo):
		raiz_modelo = find_child("Model", true, false)
		if raiz_modelo == null:
			return
	_aplicar_a_instancias(raiz_modelo)


func _aplicar_a_instancias(nodo: Node) -> void:
	if nodo is MeshInstance3D:
		var malla_instancia: MeshInstance3D = nodo as MeshInstance3D
		malla_instancia.material_override = material_dummy
		if malla_instancia.mesh != null and malla_instancia.mesh.get_surface_count() > INDICE_SUPERFICIE_PRINCIPAL:
			malla_instancia.set_surface_override_material(INDICE_SUPERFICIE_PRINCIPAL, material_dummy)
	for hijo in nodo.get_children():
		_aplicar_a_instancias(hijo)


## Aplica la capa visual de renderizado 3D a todos los VisualInstance3D hijos.
func aplicar_capa_visual() -> void:
	_aplicar_capa_visual()


func _aplicar_capa_visual() -> void:
	_asignar_capa_visual_recursiva(self, capa_visual)


func _asignar_capa_visual_recursiva(nodo: Node, capa: int) -> void:
	if not is_instance_valid(nodo):
		return
	if nodo is VisualInstance3D:
		(nodo as VisualInstance3D).layers = capa
	for hijo in nodo.get_children():
		_asignar_capa_visual_recursiva(hijo, capa)

