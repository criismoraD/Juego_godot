@tool
class_name BraceroPilar
extends Node3D

## Wrapper posicionable para el bracero pilar en el nivel del rio.
## Aplica el material con textura a todas las mallas importadas del GLB,
## sin depender del nombre interno del nodo importado.
## Soporta un efecto de transparencia dinámica (activable por instancia)
## para que el pilar se vuelva semitransparente cuando un personaje
## pase cerca de él en el eje X, evitando que tape a enemigos o aliados.

const INDICE_SUPERFICIE_PRINCIPAL: int = 0

@export var material_bracero: StandardMaterial3D:
	set(nuevo_material):
		material_bracero = nuevo_material
		if is_node_ready():
			_aplicar_material()

@export var fuego_activo: bool = true:
	set(v):
		fuego_activo = v
		_actualizar_estado_fuego()

# --- Transparencia dinámica (desactivada por defecto en todas las instancias) ---
@export_group("Transparencia Dinámica")
## Activa el efecto de fade al detectar personajes cerca en el eje X.
## Habilitarlo SOLO en la instancia deseada desde el inspector del nivel.
@export var transparencia_activa: bool = false
## Nivel de alpha cuando el pilar está oculto (0 = invisible, 1 = opaco).
@export_range(0.0, 1.0, 0.05) var alpha_transparente: float = 0.25
## Distancia en el eje X a partir de la cual el pilar se vuelve transparente.
@export var radio_deteccion_x: float = 4.0
## Velocidad del fundido (unidades de alpha por segundo).
@export var velocidad_fade: float = 5.0

@onready var modelo: Node3D = $Model
@onready var fuego_nodo: Node3D = get_node_or_null("Fuego2D") as Node3D

var _mallas_transparentes: Array[MeshInstance3D] = []
var _alpha_objetivo: float = 1.0
var _alpha_actual: float = 1.0


func _ready() -> void:
	_aplicar_material()
	_actualizar_estado_fuego()
	if transparencia_activa and not Engine.is_editor_hint():
		_preparar_materiales_unicos()
		set_process(true)
	else:
		set_process(false)


func _process(delta: float) -> void:
	_alpha_objetivo = _calcular_alpha_objetivo()
	_alpha_actual = move_toward(_alpha_actual, _alpha_objetivo, velocidad_fade * delta)
	_aplicar_alpha(_alpha_actual)


## Retorna la instancia de Fuego2D asociada al bracero.
func obtener_fuego() -> Fuego2D:
	if not is_instance_valid(fuego_nodo):
		fuego_nodo = find_child("Fuego2D", true, false) as Node3D
	return fuego_nodo as Fuego2D


func aplicar_material() -> void:
	_aplicar_material()


func _actualizar_estado_fuego() -> void:
	var f := obtener_fuego()
	if is_instance_valid(f):
		if f.has_method("set_fuego_activo"):
			f.call("set_fuego_activo", fuego_activo)
		else:
			f.visible = fuego_activo


## Aplica el material configurado a la instancia del modelo.
func _aplicar_material() -> void:
	if material_bracero == null:
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
		malla_instancia.material_override = material_bracero
		if malla_instancia.mesh != null and malla_instancia.mesh.get_surface_count() > INDICE_SUPERFICIE_PRINCIPAL:
			malla_instancia.set_surface_override_material(INDICE_SUPERFICIE_PRINCIPAL, material_bracero)
	for hijo in nodo.get_children():
		_aplicar_a_instancias(hijo)


# ---------------------------------------------------------------------------
# Métodos privados — Sistema de transparencia dinámica
# ---------------------------------------------------------------------------

## Duplica el material compartido en cada MeshInstance3D para que este
## pilar tenga su propia copia (y no afecte al resto de instancias).
## Activa transparencia alpha en los materiales duplicados.
func _preparar_materiales_unicos() -> void:
	_mallas_transparentes.clear()
	var raiz: Node = modelo
	if not is_instance_valid(raiz):
		raiz = find_child("Model", true, false)
	if raiz == null:
		return
	_recolectar_mallas(raiz)
	for malla: MeshInstance3D in _mallas_transparentes:
		# Obtener el material actual (override tiene prioridad)
		var mat: StandardMaterial3D = malla.material_override as StandardMaterial3D
		if mat == null:
			mat = malla.get_active_material(0) as StandardMaterial3D
		if mat == null:
			continue
		# Clonar para que los cambios de alpha no afecten a otros pilares
		var mat_unico: StandardMaterial3D = mat.duplicate() as StandardMaterial3D
		mat_unico.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		malla.material_override = mat_unico


func _recolectar_mallas(nodo: Node) -> void:
	if nodo is MeshInstance3D:
		_mallas_transparentes.append(nodo as MeshInstance3D)
	for hijo: Node in nodo.get_children():
		_recolectar_mallas(hijo)


## Recorre los grupos "player", "allies" y "enemies".
## Si algún nodo está dentro del radio en X, devuelve alpha_transparente.
func _calcular_alpha_objetivo() -> float:
	var arbol := get_tree()
	if arbol == null:
		return 1.0
	var grupos: Array[StringName] = [&"player", &"allies", &"enemies"]
	var pos_x: float = global_position.x
	for grupo: StringName in grupos:
		for nodo: Node in arbol.get_nodes_in_group(grupo):
			if not nodo is Node3D:
				continue
			var n3d: Node3D = nodo as Node3D
			if absf(n3d.global_position.x - pos_x) <= radio_deteccion_x:
				return alpha_transparente
	return 1.0


func _aplicar_alpha(alpha: float) -> void:
	for malla: MeshInstance3D in _mallas_transparentes:
		if not is_instance_valid(malla):
			continue
		var mat := malla.material_override as StandardMaterial3D
		if mat == null:
			continue
		var color: Color = mat.albedo_color
		color.a = alpha
		mat.albedo_color = color
