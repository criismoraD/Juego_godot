@tool
class_name PuenteTutorial
extends Node3D

## Wrapper posicionable para el puente del tutorial (modelo TEST_/Puente).
## Aplica el material con textura a todas las mallas importadas del GLB,
## sin depender del nombre interno del nodo importado.
## Panel de capa visual en el inspector: elige en qué capa va
## (1 = frente nítido, 2 = fondo con desenfoque DOF, 3 = ambas, etc.).
## El nodo raíz queda libre para posicionarlo en el editor.

const MATERIAL_DEFECTO: Material = preload("res://Levels/NIVEL_TUTORIAL/PuenteTutorial_Mat.tres")

@export var material_puente: StandardMaterial3D:
	set(nuevo_material):
		material_puente = nuevo_material
		if is_node_ready():
			_aplicar_material()

@export_flags_3d_render var capa_visual: int = 1:
	set(nueva_capa):
		capa_visual = nueva_capa
		if is_node_ready():
			_aplicar_capa_visual(self)

## Excepciones de capa por nombre de hijo: permite mandar un modelo concreto
## a otra capa visual sin mover todo el puente (p. ej. {"Model6": 2} lo deja
## en la capa 2 de fondo con desenfoque DOF). Afecta al nodo y a sus hijos.
@export var capa_por_modelo: Dictionary = {"Model6": 2}:
	set(nueva_config):
		capa_por_modelo = nueva_config if nueva_config != null else {}
		if is_node_ready():
			_aplicar_capa_visual(self)

## Colisión del tablero: genera una plataforma fina (StaticBody3D en capa 1,
## la del jugador) que cubre todos los tramos para poder caminar sobre el puente.
@export var colision_tablero_activa: bool = true
@export_range(0.05, 1.0, 0.05) var grosor_tablero: float = 0.3
@export var nivel_piso_puente: float = 0.2  ## Altura Y mundial del tablero (a ras del suelo de piedra)


func _ready() -> void:
	if material_puente == null:
		material_puente = MATERIAL_DEFECTO
	_aplicar_material()
	_aplicar_capa_visual(self)
	if colision_tablero_activa and not Engine.is_editor_hint():
		_construir_colision_tablero()


## Aplica el material configurado a la instancia del modelo.
func aplicar_material() -> void:
	_aplicar_material()


func _aplicar_material() -> void:
	if material_puente == null:
		return
	_aplicar_a_instancias(self)


func _aplicar_a_instancias(nodo: Node) -> void:
	if nodo is MeshInstance3D:
		_aplicar_material_a_malla(nodo as MeshInstance3D)
	for hijo in nodo.get_children():
		_aplicar_a_instancias(hijo)


## El GLB trae material gris sin textura: se reemplaza siempre por
## la difusa (el modelo tiene UVs).
func _aplicar_material_a_malla(malla_instancia: MeshInstance3D) -> void:
	if material_puente == null:
		return
	if malla_instancia.mesh == null:
		return
	malla_instancia.material_override = material_puente
	for si in range(malla_instancia.mesh.get_surface_count()):
		malla_instancia.set_surface_override_material(si, material_puente)


func _aplicar_capa_visual(nodo: Node, capa_heredada: int = -1) -> void:
	if not is_instance_valid(nodo):
		return
	var capa: int = capa_heredada
	if capa < 0:
		capa = capa_visual
	if nodo != self and capa_por_modelo != null and capa_por_modelo.has(String(nodo.name)):
		capa = int(capa_por_modelo[String(nodo.name)])
	if nodo is VisualInstance3D and not (nodo is Light3D or nodo is Camera3D):
		(nodo as VisualInstance3D).layers = capa
	for hijo in nodo.get_children():
		_aplicar_capa_visual(hijo, capa)


## Crea (una sola vez) el StaticBody3D "PisoPuente" con una caja fina en capa 1
## que cubre en X/Z todos los tramos del puente y deja su cara superior a la
## altura de nivel_piso_puente. Sin esto el GLB (solo visual) se atraviesa y se cae.
func _construir_colision_tablero() -> void:
	if get_node_or_null("PisoPuente") != null:
		return
	var area := _calcular_aabb_global_modelos()
	if area.size.x <= 0.0 or area.size.z <= 0.0:
		return
	var caja := BoxShape3D.new()
	caja.size = Vector3(maxf(area.size.x, 0.5), grosor_tablero, maxf(area.size.z, 0.5))
	var cuerpo := StaticBody3D.new()
	cuerpo.name = "PisoPuente"
	cuerpo.collision_layer = 1
	cuerpo.collision_mask = 0
	# top_level: la caja queda en coordenadas mundiales sin heredar la escala
	# del puente (x5) que deformaría el colisionador.
	cuerpo.top_level = true
	cuerpo.position = Vector3(
		area.position.x + area.size.x * 0.5,
		nivel_piso_puente - grosor_tablero * 0.5,
		area.position.z + area.size.z * 0.5
	)
	var forma := CollisionShape3D.new()
	forma.shape = caja
	cuerpo.add_child(forma)
	add_child(cuerpo)


## AABB global combinado de todas las mallas de los tramos (esquinas
## transformadas a mano para no depender de helpers del motor).
func _calcular_aabb_global_modelos() -> AABB:
	var acumulado := AABB()
	var primero := true
	for hijo in get_children():
		if hijo is CollisionObject3D:
			continue
		for m in hijo.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			if (mi as VisualInstance3D).get_aabb().size == Vector3.ZERO:
				continue
			var actual := _aabb_global_de_malla(mi)
			if primero:
				acumulado = actual
				primero = false
			else:
				acumulado = acumulado.merge(actual)
	return acumulado


func _aabb_global_de_malla(mi: MeshInstance3D) -> AABB:
	var local: AABB = (mi as VisualInstance3D).get_aabb()
	var gt: Transform3D = mi.global_transform
	var p0: Vector3 = local.position
	var p1: Vector3 = local.position + local.size
	var minimo := Vector3(INF, INF, INF)
	var maximo := Vector3(-INF, -INF, -INF)
	for ex in [p0.x, p1.x]:
		for ey in [p0.y, p1.y]:
			for ez in [p0.z, p1.z]:
				var q: Vector3 = gt * Vector3(ex, ey, ez)
				minimo = minimo.min(q)
				maximo = maximo.max(q)
	return AABB(minimo, maximo - minimo)
