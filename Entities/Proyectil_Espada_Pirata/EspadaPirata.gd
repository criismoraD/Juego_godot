class_name EspadaPirataProjectile
extends ImpTridentProjectile

## Proyectil del Pirata Goblin: espada arrojadiza que gira como el hacha de Perrena.
## Hereda TODO lo del tridente del Imp (daño a jugadora/aliadas, clavado en
## escudos y superficies, parábola con gravedad y compatibilidad con el pool).
## Diferencias:
## - No orienta la raíz hacia la dirección: gira el modelo (rápido en vuelo,
##   muy lento al caer, como molinete).
## - Visual con textura propia (MAT_ESPADA_PIRATA) en vez del material de emisión.

const MAT_ESPADA: Material = preload("res://Entities/Proyectil_Espada_Pirata/MAT_ESPADA_PIRATA.tres")
const VELOCIDAD_GIRO_VUELO: float = 16.0  ## Igual que el hacha de Perrena (rad/s)

@export_category("Giro Espada")
@export var velocidad_giro_vuelo: float = VELOCIDAD_GIRO_VUELO  ## Giro rápido en vuelo/sube
@export var velocidad_orientacion_caida: float = 8.0  ## Rapidez para ponerse con la punta abajo al caer
@export var punta_signo: float = 1.0  ## Extremo de la punta: 1.0 = +X, -1.0 = -X
@export var factor_gravedad: float = 0.6  ## Cae más lento (más tiempo en el aire para predecir la caída)

@export_category("Estela Fantasma")
@export var estela_activa: bool = true  ## Rastro morado sutil con la forma de la espada
@export var intervalo_estela: float = 0.05  ## Segundos entre fantasmas
@export var vida_estela: float = 0.35  ## Duración del desvanecido de cada fantasma
@export var color_estela: Color = Color(0.6, 0.2, 1.0, 0.3)  ## Morado transparente y sutil

var _modelo_espada: Node3D = null
var _tiempo_estela: float = 0.0


func _init() -> void:
	color_proyectil = Color(0.75, 0.8, 0.75)
	offscreen_margin_x = 400.0
	offscreen_margin_top = 2000.0
	offscreen_margin_bottom = 300.0


func _ready() -> void:
	_modelo_espada = find_child("EspadaModel", true, false) as Node3D
	_aplicar_material_espada()
	super._ready()


func _actualizar_movimiento(delta: float) -> void:
	_aplicar_movimiento_parabolico(delta, velocidad, gravedad * factor_gravedad)
	if not _modelo_espada or not is_instance_valid(_modelo_espada):
		return
	if direction.y < 0.0:
		# Cayendo: deja de girar y cae siempre con la punta hacia abajo.
		var objetivo: float = -punta_signo * PI * 0.5
		_modelo_espada.rotation.z = lerp_angle(_modelo_espada.rotation.z, objetivo, minf(1.0, velocidad_orientacion_caida * delta))
	else:
		_modelo_espada.rotate_z(-velocidad_giro_vuelo * delta)
	_actualizar_estela(delta)


func initialize(shoot_direction: Vector3, potencia: float = 1.0) -> void:
	super.initialize(shoot_direction, potencia)
	_tiempo_estela = 0.0


## Deja fantasmas morados con la silueta exacta de la espada mientras vuela.
func _actualizar_estela(delta: float) -> void:
	if not estela_activa or is_stuck:
		return
	if not is_inside_tree() or get_tree() == null:
		return
	_tiempo_estela += delta
	if _tiempo_estela < intervalo_estela:
		return
	_tiempo_estela = 0.0
	_generar_fantasma_estela()


func _generar_fantasma_estela() -> void:
	var raiz: Node = _modelo_espada if is_instance_valid(_modelo_espada) else self
	var padre: Node = get_parent()
	if padre == null:
		return
	for m in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var fantasma := mi.duplicate() as MeshInstance3D
		fantasma.name = "EstelaEspada"
		fantasma.add_to_group("estela_espada")
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = color_estela
		fantasma.material_override = mat
		fantasma.set_surface_override_material(0, null)
		padre.add_child(fantasma)
		fantasma.global_transform = mi.global_transform
		_desvanecer_fantasma(fantasma, mat)


func _desvanecer_fantasma(fantasma: MeshInstance3D, mat: StandardMaterial3D) -> void:
	var tw := fantasma.create_tween()
	tw.tween_method(
		func(alfa: float):
			if is_instance_valid(mat):
				var c := mat.albedo_color
				c.a = alfa
				mat.albedo_color = c
	, color_estela.a, 0.0, maxf(vida_estela, 0.05))
	tw.tween_callback(fantasma.queue_free)


## La espada gira como molinete, no apunta con la dirección (la raíz conserva
## la orientación del lanzamiento y solo el modelo rota).
func _actualizar_rotacion_por_direccion() -> void:
	pass


## Textura propia del .tscn: no crear material de emisión.
func _preparar_visuales() -> void:
	pass


func _aplicar_visuales_cacheados() -> void:
	for mesh in _cached_mesh_instances:
		if is_instance_valid(mesh) and mesh is MeshInstance3D:
			(mesh as MeshInstance3D).visible = true


## En cada reutilización del pool, restaurar la textura (el pickup/limpieza
## puede haber anulado overrides) y la visibilidad.
func _restaurar_visuales_desde_pool() -> void:
	_aplicar_material_espada()
	for mesh in _cached_mesh_instances:
		if is_instance_valid(mesh) and mesh is MeshInstance3D:
			(mesh as MeshInstance3D).visible = true


func _aplicar_material_espada() -> void:
	if not MAT_ESPADA:
		return
	var raiz: Node = _modelo_espada if is_instance_valid(_modelo_espada) else self
	for m in raiz.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_override = MAT_ESPADA
