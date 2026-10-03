@tool
class_name ZonaKillBatalla
extends Area3D

## Zona de eliminación para unidades de batalla cosmética de fondo.
##
## Coloca este Area3D fuera de los límites de pantalla (izquierda o derecha).
## Cualquier unidad del grupo "batalla_cosmetica" que entre en esta zona
## es eliminada limpiamente para que el BattleSpawnerCosmetic pueda
## reciclarla y mantener el ciclo de batalla continuo.
##
## El nodo dispara la señal "died" si la unidad la tiene, o llama
## queue_free() directamente como fallback.
##
## Uso en escena:
##   - Agrega un ZonaKillBatalla a la izquierda (para ImperioGirls que sobrepasan)
##   - Agrega otro ZonaKillBatalla a la derecha (para GoblinsGarrote que sobrepasan)
##   - Ajusta el CollisionShape3D para cubrir toda la altura y profundidad de batalla.

# === CONFIGURACIÓN ===
@export_category("Zona Kill")
## Si true, muestra una caja visual en el editor para posicionarla fácilmente.
@export var mostrar_debug_en_editor: bool = true

## Color del volumen de debug en el editor.
@export var color_debug: Color = Color(1.0, 0.0, 0.0, 0.35)

## Si true, la zona elimina cualquier nodo del grupo batalla_cosmetica.
## Si false, solo las del bando especificado en `bando_objetivo`.
@export var eliminar_todos_los_bandos: bool = true

## Bando específico a eliminar ("azul" o "rojo"). Solo si eliminar_todos_los_bandos = false.
@export_enum("azul", "rojo") var bando_objetivo: String = "azul"

# === REFERENCIAS PRIVADAS ===
var _mesh_debug: MeshInstance3D = null


# === BUILT-IN ===
func _ready() -> void:
	_construir_visual_debug()

	if Engine.is_editor_hint():
		return

	collision_mask = 0xFFFFFFFF

	# Conectar señal de colisión
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)


func _on_body_entered(body: Node3D) -> void:
	_procesar_colision(body)


func _on_area_entered(area: Node3D) -> void:
	_procesar_colision(area)


# === LÓGICA DE ELIMINACIÓN ===
## Elimina limpiamente la unidad si pertenece a la batalla cosmética.
func _procesar_colision(nodo: Node3D) -> void:
	if not is_instance_valid(nodo):
		return

	if not nodo.is_in_group("batalla_cosmetica"):
		return

	# Filtro de bando si está habilitado
	if not eliminar_todos_los_bandos:
		if not nodo.is_in_group("battle_" + bando_objetivo):
			return

	_eliminar_unidad(nodo)


## Elimina la unidad disparando "died" si existe, o con queue_free() directamente.
func _eliminar_unidad(unidad: Node3D) -> void:
	if not is_instance_valid(unidad):
		return
	if unidad.is_queued_for_deletion():
		return

	# Intentar matar via método de daño letal (muerte con animación)
	if unidad.has_method("take_damage"):
		unidad.call("take_damage", 99999.0)
		return

	# Fallback: emitir señal died si existe
	if unidad.has_signal("died"):
		unidad.emit_signal("died")

	# Eliminación directa si la unidad sigue viva
	if is_instance_valid(unidad) and not unidad.is_queued_for_deletion():
		unidad.queue_free()


# === VISUAL EDITOR ===
func _construir_visual_debug() -> void:
	# Limpiar debug anterior
	var old: Node = get_node_or_null("DebugKillZone")
	if is_instance_valid(old):
		old.queue_free()

	if not mostrar_debug_en_editor or not Engine.is_editor_hint():
		return

	# Buscar el CollisionShape3D para mimetizar su tamaño
	var col_shape: CollisionShape3D = null
	for hijo in get_children():
		if hijo is CollisionShape3D:
			col_shape = hijo as CollisionShape3D
			break

	var size := Vector3(1.0, 4.0, 6.0)
	if is_instance_valid(col_shape) and col_shape.shape is BoxShape3D:
		size = (col_shape.shape as BoxShape3D).size

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = color_debug

	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	box_mesh.material = mat

	_mesh_debug = MeshInstance3D.new()
	_mesh_debug.name = "DebugKillZone"
	_mesh_debug.mesh = box_mesh
	add_child(_mesh_debug)
