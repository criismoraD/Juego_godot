extends Control

## UI Runtime para diseñar niveles. Solo para desarrollo.
## Permite configurar oleadas de enemigos y colocar objetos 3D.

const MAX_LEVELS: int = 30
const GRID_COLS: int = 6
const ENEMIGOS_DISPONIBLES: Array[Dictionary] = [
	{"nombre": "Goblin", "path": "res://Scenes/Characters/Goblin.tscn"},
	{"nombre": "Goblin Girl", "path": "res://Scenes/Characters/GoblinGirl.tscn"},
	{"nombre": "Imp", "path": "res://Scenes/Characters/ImpEnemy.tscn"},
	{"nombre": "Imp Estandarte", "path": "res://Scenes/Characters/ImpEnemyEstandarte.tscn"},
	{"nombre": "Imp Escudo", "path": "res://Scenes/Characters/ImpShieldGirl.tscn", "escudo": true},
	{"nombre": "Canonero", "path": "res://Scenes/Characters/Canonero.tscn"},
	{"nombre": "Arquera Aliada", "path": "res://Scenes/Characters/AllyArcher.tscn"},
]
const OBJETOS_DISPONIBLES: Array[Dictionary] = [
	{"nombre": "Plataforma", "path": "res://Scenes/Environment/Platform/Platform.tscn"},
	{"nombre": "Escaleras", "path": "res://Scenes/Environment/Ladder/Ladder.tscn"},
	{"nombre": "Torre", "path": "res://Scenes/Environment/TORRE.tscn"},
	{"nombre": "Pinchos", "path": "res://Scenes/Environment/SpikeTrap/SpikeTrap.tscn"},
	{"nombre": "Escudo", "path": "res://Scenes/Environment/Shield/Shield.tscn"},
	{"nombre": "Busto Bronce", "path": "res://Scenes/Environment/BUSTO_BRONCE/BUSTO_BRONCE.tscn"},
	{"nombre": "Yelmo", "path": "res://Scenes/Environment/Helmet/HELMET.tscn"},
	{"nombre": "Estátua", "path": "res://Scenes/Environment/Statue/STATUE.tscn"},
]

signal nivel_seleccionado(numero: int)
signal nivel_guardado(numero: int)
signal builder_cerrado

var nivel_actual: int = 1
var oleada_actual: int = -1
var modo_objetos: bool = false
var objetos_instanciados: Array[Node3D] = []

@onready var panel_principal: VBoxContainer = $Control/PanelPrincipal
@onready var grid_niveles: GridContainer = $Control/PanelPrincipal/GridNiveles
@onready var label_nivel: Label = $Control/PanelPrincipal/Header/LabelNivel
@onready var tab_container: TabContainer = $Control/PanelPrincipal/TabContainer
@onready var lista_oleadas: ItemList = $Control/PanelPrincipal/TabContainer/Oleadas/ListaOleadas
@onready var lista_enemigos: ItemList = $Control/PanelPrincipal/TabContainer/Enemigos/ListaEnemigos
@onready var lista_objetos: ItemList = $Control/PanelPrincipal/TabContainer/Objetos/ListaObjetos
@onready var spin_cantidad: SpinBox = $Control/PanelPrincipal/TabContainer/Enemigos/ConfigEnemigo/HBoxCantidad/SpinCantidad
@onready var spin_spawn_time: SpinBox = $Control/PanelPrincipal/TabContainer/Enemigos/ConfigEnemigo/HBoxSpawnTime/SpinSpawnTime
@onready var option_enemigo: OptionButton = $Control/PanelPrincipal/TabContainer/Enemigos/ConfigEnemigo/HBoxTipo/OptionEnemigo
@onready var option_objeto: OptionButton = $Control/PanelPrincipal/TabContainer/Objetos/ConfigObjeto/HBoxTipo/OptionObjeto
@onready var spin_tiempo_spawn_oleada: SpinBox = $Control/PanelPrincipal/TabContainer/Oleadas/ConfigOleada/HBoxTiempoSpawn/SpinTiempoSpawn
@onready var spin_tiempo_entre_oleadas: SpinBox = $Control/PanelPrincipal/TabContainer/Oleadas/ConfigOleada/HBoxTiempoOleada/SpinTiempoOleada
@onready var label_info: Label = $Control/PanelPrincipal/Footer/LabelInfo


func _ready() -> void:
	_crear_grid_niveles()
	_popular_option_enemigos()
	_popular_option_objetos()
	_seleccionar_nivel(1)
	$Control.visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_level_builder"):
		if $Control.visible:
			_cerrar_builder()
		else:
			abrir()
		get_viewport().set_input_as_handled()


# ═══════════════════════════════════════════════════════════════════
# NIVELES
# ═══════════════════════════════════════════════════════════════════


func _crear_grid_niveles() -> void:
	for child: Node in grid_niveles.get_children():
		child.queue_free()
	await get_tree().process_frame
	for i: int in range(0, MAX_LEVELS + 1):
		var btn := Button.new()
		btn.text = str(i)
		btn.custom_minimum_size = Vector2(40, 30)
		btn.toggle_mode = true
		btn.pressed.connect(_on_boton_nivel_pressed.bind(i))
		grid_niveles.add_child(btn)


func _on_boton_nivel_pressed(numero: int) -> void:
	_seleccionar_nivel(numero)


func _seleccionar_nivel(numero: int) -> void:
	nivel_actual = numero
	oleada_actual = -1
	_actualizar_ui_nivel()
	_actualizar_botones_nivel()
	nivel_seleccionado.emit(numero)


func _actualizar_botones_nivel() -> void:
	for i: int in range(grid_niveles.get_child_count()):
		var btn: Button = grid_niveles.get_child(i) as Button
		if btn:
			btn.button_pressed = (i == nivel_actual)


func _actualizar_ui_nivel() -> void:
	var data: LevelData = LevelDataStore.obtener_nivel(nivel_actual)
	label_nivel.text = "Nivel %02d: %s" % [data.nivel_numero, data.nombre_nivel]
	_actualizar_lista_oleadas()
	_actualizar_lista_objetos()
	if data.oleadas.size() > 0:
		oleada_actual = 0
		lista_oleadas.select(0)
		_actualizar_ui_oleada()
	else:
		oleada_actual = -1
		_limpiar_ui_oleada()
	_info("Nivel %d seleccionado" % nivel_actual)


# ═══════════════════════════════════════════════════════════════════
# OLEADAS
# ═══════════════════════════════════════════════════════════════════


func _actualizar_lista_oleadas() -> void:
	lista_oleadas.clear()
	var data: LevelData = LevelDataStore.obtener_nivel(nivel_actual)
	for oleada: OleadaData in data.oleadas:
		lista_oleadas.add_item("Oleada %d (%d enemigos)" % [oleada.numero, oleada.obtener_total_enemigos()])


func _on_btn_agregar_oleada_pressed() -> void:
	var data: LevelData = LevelDataStore.obtener_nivel(nivel_actual)
	data.agregar_oleada()
	_actualizar_lista_oleadas()
	oleada_actual = data.oleadas.size() - 1
	lista_oleadas.select(oleada_actual)
	_actualizar_ui_oleada()
	_info("Oleada %d agregada" % data.oleadas.size())


func _on_btn_eliminar_oleada_pressed() -> void:
	var data: LevelData = LevelDataStore.obtener_nivel(nivel_actual)
	if oleada_actual < 0 or oleada_actual >= data.oleadas.size():
		return
	data.eliminar_oleada(oleada_actual)
	oleada_actual = clampi(oleada_actual, 0, data.oleadas.size() - 1)
	_actualizar_lista_oleadas()
	if oleada_actual >= 0:
		lista_oleadas.select(oleada_actual)
		_actualizar_ui_oleada()
	else:
		_limpiar_ui_oleada()
	_info("Oleada eliminada")


func _on_lista_oleadas_item_selected(index: int) -> void:
	oleada_actual = index
	_actualizar_ui_oleada()


func _actualizar_ui_oleada() -> void:
	if oleada_actual < 0:
		_limpiar_ui_oleada()
		return
	var data: LevelData = LevelDataStore.obtener_nivel(nivel_actual)
	if oleada_actual >= data.oleadas.size():
		return
	var oleada: OleadaData = data.oleadas[oleada_actual]
	spin_tiempo_spawn_oleada.value = oleada.tiempo_entre_spawns
	spin_tiempo_entre_oleadas.value = oleada.tiempo_entre_oleadas
	_actualizar_lista_enemigos()


func _limpiar_ui_oleada() -> void:
	lista_enemigos.clear()


func _on_spin_tiempo_spawn_value_changed(value: float) -> void:
	var data: LevelData = LevelDataStore.obtener_nivel(nivel_actual)
	if oleada_actual < 0 or oleada_actual >= data.oleadas.size():
		return
	data.oleadas[oleada_actual].tiempo_entre_spawns = value


func _on_spin_tiempo_oleada_value_changed(value: float) -> void:
	var data: LevelData = LevelDataStore.obtener_nivel(nivel_actual)
	if oleada_actual < 0 or oleada_actual >= data.oleadas.size():
		return
	data.oleadas[oleada_actual].tiempo_entre_oleadas = value


# ═══════════════════════════════════════════════════════════════════
# ENEMIGOS
# ═══════════════════════════════════════════════════════════════════


func _popular_option_enemigos() -> void:
	option_enemigo.clear()
	for i: int in range(ENEMIGOS_DISPONIBLES.size()):
		option_enemigo.add_item(ENEMIGOS_DISPONIBLES[i]["nombre"], i)
		option_enemigo.set_item_metadata(i, ENEMIGOS_DISPONIBLES[i])


func _actualizar_lista_enemigos() -> void:
	lista_enemigos.clear()
	var data: LevelData = LevelDataStore.obtener_nivel(nivel_actual)
	if oleada_actual < 0 or oleada_actual >= data.oleadas.size():
		return
	var oleada: OleadaData = data.oleadas[oleada_actual]
	for enemigo: EnemigoData in oleada.enemigos:
		var tag: String = " [ESCUDO]" if enemigo.es_escudo else ""
		lista_enemigos.add_item(
			"%s x%d (%.1fs)%s" % [enemigo.obtener_nombre(), enemigo.quantity, enemigo.spawn_time, tag]
		)


func _on_btn_agregar_enemigo_pressed() -> void:
	var data: LevelData = LevelDataStore.obtener_nivel(nivel_actual)
	if oleada_actual < 0 or oleada_actual >= data.oleadas.size():
		_info("Primero crea una oleada")
		return

	var idx: int = option_enemigo.get_item_index(option_enemigo.selected)
	if idx < 0:
		return

	var meta: Dictionary = option_enemigo.get_item_metadata(idx)
	var qty: int = int(spin_cantidad.value)
	var spawn_t: float = spin_spawn_time.value
	var is_escudo: bool = meta.get("escudo", false)

	data.agregar_enemigo_a_oleada(oleada_actual, meta["path"], spawn_t, Vector3.ZERO, qty, is_escudo)
	_actualizar_lista_enemigos()
	_actualizar_lista_oleadas()
	_info("Enemigo agregado: %s x%d" % [meta["nombre"], qty])


func _on_btn_eliminar_enemigo_pressed() -> void:
	var data: LevelData = LevelDataStore.obtener_nivel(nivel_actual)
	if oleada_actual < 0 or oleada_actual >= data.oleadas.size():
		return
	var oleada: OleadaData = data.oleadas[oleada_actual]
	var selected: PackedInt32Array = lista_enemigos.get_selected_items()
	if selected.size() == 0:
		return
	oleada.eliminar_enemigo(selected[0])
	_actualizar_lista_enemigos()
	_actualizar_lista_oleadas()
	_info("Enemigo eliminado")


# ═══════════════════════════════════════════════════════════════════
# OBJETOS
# ═══════════════════════════════════════════════════════════════════


func _popular_option_objetos() -> void:
	option_objeto.clear()
	for i: int in range(OBJETOS_DISPONIBLES.size()):
		option_objeto.add_item(OBJETOS_DISPONIBLES[i]["nombre"], i)
		option_objeto.set_item_metadata(i, OBJETOS_DISPONIBLES[i])


func _actualizar_lista_objetos() -> void:
	lista_objetos.clear()
	var data: LevelData = LevelDataStore.obtener_nivel(nivel_actual)
	for obj: ObjetoData in data.objetos_escenario:
		lista_objetos.add_item("%s (%s)" % [obj.obtener_nombre(), str(obj.posicion)])


func _on_btn_agregar_objeto_pressed() -> void:
	var idx: int = option_objeto.get_item_index(option_objeto.selected)
	if idx < 0:
		return

	var meta: Dictionary = option_objeto.get_item_metadata(idx)
	var data: LevelData = LevelDataStore.obtener_nivel(nivel_actual)
	data.agregar_objeto(meta["path"])
	_actualizar_lista_objetos()
	_info("Objeto agregado: %s" % meta["nombre"])


func _on_btn_eliminar_objeto_pressed() -> void:
	var data: LevelData = LevelDataStore.obtener_nivel(nivel_actual)
	var selected: PackedInt32Array = lista_objetos.get_selected_items()
	if selected.size() == 0:
		return
	data.eliminar_objeto(selected[0])
	_actualizar_lista_objetos()
	_info("Objeto eliminado")


func _on_btn_colocar_objeto_pressed() -> void:
	modo_objetos = true
	_info("Modo colocación: clic en el mapa para colocar objeto")
	# TODO: activar raycast para colocar objetos en el mundo


# ═══════════════════════════════════════════════════════════════════
# GUARDAR / CARGAR
# ═══════════════════════════════════════════════════════════════════


func _on_btn_guardar_pressed() -> void:
	LevelDataStore.guardar_nivel(nivel_actual)
	nivel_guardado.emit(nivel_actual)
	_info("Nivel %d guardado" % nivel_actual)


func _on_btn_guardar_todo_pressed() -> void:
	LevelDataStore.guardar_todos()
	_info("Todos los niveles guardados")


func _on_btn_probar_pressed() -> void:
	var data: LevelData = LevelDataStore.obtener_nivel(nivel_actual)
	if data.oleadas.size() == 0:
		_info("Sin oleadas para probar")
		return
	var spawners: Array[Node] = get_tree().get_nodes_in_group("wave_spawners")
	if spawners.size() > 0:
		var spawner: WaveSpawner = spawners[0] as WaveSpawner
		spawner.iniciar_desde_data(data)
		_info("Probando nivel %d con %d oleadas" % [nivel_actual, data.oleadas.size()])
	else:
		_info("No se encontró WaveSpawner en la escena")


func _on_btn_cerrar_pressed() -> void:
	_cerrar_builder()


func _cerrar_builder() -> void:
	$Control.visible = false
	builder_cerrado.emit()


func abrir() -> void:
	$Control.visible = true
	_actualizar_ui_nivel()


func _info(msg: String) -> void:
	label_info.text = msg
