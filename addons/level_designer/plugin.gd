@tool
extends EditorPlugin

const MAX_LEVELS: int = 30
const GRID_COLS: int = 6
const LEVELS_DIR: String = "res://Levels/"

var Panel_Principal: VBoxContainer
var Boton_Panel: Button
var store = null
var nivel_actual: int = 1
var oleada_actual: int = -1

# UI References
var grid_niveles: GridContainer
var label_nivel: Label
var tab_container: TabContainer
var lista_oleadas: ItemList
var lista_enemigos: ItemList
var lista_elementos: ItemList
var spin_tiempo_spawn: SpinBox
var spin_tiempo_oleada: SpinBox
var spin_probabilidad: SpinBox
var option_fondo: OptionButton
var label_info: Label
var file_enemigo: FileDialog
var file_elemento: FileDialog


func _enter_tree() -> void:
	_crear_ui()
	Boton_Panel = add_control_to_bottom_panel(Panel_Principal, "Level Designer")
	_inicializar_store()


func _exit_tree() -> void:
	if Panel_Principal:
		remove_control_from_bottom_panel(Panel_Principal)
		Panel_Principal.queue_free()
		Panel_Principal = null
	Boton_Panel = null


func _inicializar_store() -> void:
	await get_tree().process_frame
	store = get_node_or_null("/root/LevelDataStore")
	if store == null:
		store = load("res://addons/level_designer/level_data_store.gd").new()
		store._ready()
	_crear_grid_niveles()
	_seleccionar_nivel(1)


func _crear_ui() -> void:
	Panel_Principal = VBoxContainer.new()
	Panel_Principal.name = "Level Designer"

	# Header
	var header := HBoxContainer.new()
	Panel_Principal.add_child(header)

	label_nivel = Label.new()
	label_nivel.text = "Nivel 01"
	label_nivel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label_nivel)

	var btn_guardar := Button.new()
	btn_guardar.text = "Guardar"
	btn_guardar.pressed.connect(_on_guardar)
	header.add_child(btn_guardar)

	var btn_guardar_todos := Button.new()
	btn_guardar_todos.text = "Guardar Todo"
	btn_guardar_todos.pressed.connect(_on_guardar_todos)
	header.add_child(btn_guardar_todos)

	# Grid de niveles
	grid_niveles = GridContainer.new()
	grid_niveles.columns = GRID_COLS
	Panel_Principal.add_child(grid_niveles)

	# Tabs
	tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	Panel_Principal.add_child(tab_container)

	_crear_tab_oleadas()
	_crear_tab_enemigos()
	_crear_tab_elementos()
	_crear_tab_fondo()

	# Info
	var info_box := HBoxContainer.new()
	Panel_Principal.add_child(info_box)

	label_info = Label.new()
	label_info.text = "Listo"
	label_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.add_child(label_info)

	# FileDialogs
	file_enemigo = FileDialog.new()
	file_enemigo.title = "Seleccionar escena de enemigo"
	file_enemigo.access = FileDialog.ACCESS_FILESYSTEM
	file_enemigo.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_enemigo.filters = PackedStringArray(["*.tscn ; Escenas Godot", "*.glb ; Modelos GLB"])
	file_enemigo.file_selected.connect(_on_enemigo_archivo_seleccionado)
	Panel_Principal.add_child(file_enemigo)

	file_elemento = FileDialog.new()
	file_elemento.title = "Seleccionar elemento de escenario"
	file_elemento.access = FileDialog.ACCESS_FILESYSTEM
	file_elemento.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_elemento.filters = PackedStringArray(["*.tscn ; Escenas Godot", "*.glb ; Modelos GLB"])
	file_elemento.file_selected.connect(_on_elemento_archivo_seleccionado)
	Panel_Principal.add_child(file_elemento)


func _crear_tab_oleadas() -> void:
	var tab := VBoxContainer.new()
	tab.name = "Oleadas"
	tab_container.add_child(tab)

	var hbox := HBoxContainer.new()
	tab.add_child(hbox)

	var btn_agregar := Button.new()
	btn_agregar.text = "+ Oleada"
	btn_agregar.pressed.connect(_on_agregar_oleada)
	hbox.add_child(btn_agregar)

	var btn_eliminar := Button.new()
	btn_eliminar.text = "- Oleada"
	btn_eliminar.pressed.connect(_on_eliminar_oleada)
	hbox.add_child(btn_eliminar)

	lista_oleadas = ItemList.new()
	lista_oleadas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lista_oleadas.item_selected.connect(_on_oleada_seleccionada)
	tab.add_child(lista_oleadas)

	var hbox_tiempo := HBoxContainer.new()
	tab.add_child(hbox_tiempo)

	var label_spawn := Label.new()
	label_spawn.text = "T. Spawn:"
	hbox_tiempo.add_child(label_spawn)

	spin_tiempo_spawn = SpinBox.new()
	spin_tiempo_spawn.min_value = 0.5
	spin_tiempo_spawn.max_value = 30.0
	spin_tiempo_spawn.step = 0.5
	spin_tiempo_spawn.value = 3.0
	spin_tiempo_spawn.value_changed.connect(_on_tiempo_spawn_cambiado)
	hbox_tiempo.add_child(spin_tiempo_spawn)

	var label_oleada := Label.new()
	label_oleada.text = "T. Oleada:"
	hbox_tiempo.add_child(label_oleada)

	spin_tiempo_oleada = SpinBox.new()
	spin_tiempo_oleada.min_value = 1.0
	spin_tiempo_oleada.max_value = 60.0
	spin_tiempo_oleada.step = 1.0
	spin_tiempo_oleada.value = 5.0
	spin_tiempo_oleada.value_changed.connect(_on_tiempo_oleada_cambiado)
	hbox_tiempo.add_child(spin_tiempo_oleada)


func _crear_tab_enemigos() -> void:
	var tab := VBoxContainer.new()
	tab.name = "Enemigos"
	tab_container.add_child(tab)

	var hbox := HBoxContainer.new()
	tab.add_child(hbox)

	var btn_agregar := Button.new()
	btn_agregar.text = "+ Enemigo"
	btn_agregar.pressed.connect(_on_agregar_enemigo)
	hbox.add_child(btn_agregar)

	var btn_eliminar := Button.new()
	btn_eliminar.text = "- Enemigo"
	btn_eliminar.pressed.connect(_on_eliminar_enemigo)
	hbox.add_child(btn_eliminar)

	lista_enemigos = ItemList.new()
	lista_enemigos.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lista_enemigos.item_selected.connect(_on_enemigo_seleccionado)
	tab.add_child(lista_enemigos)

	var hbox_prob := HBoxContainer.new()
	tab.add_child(hbox_prob)

	var label_prob := Label.new()
	label_prob.text = "Probabilidad %:"
	hbox_prob.add_child(label_prob)

	spin_probabilidad = SpinBox.new()
	spin_probabilidad.min_value = 0.0
	spin_probabilidad.max_value = 100.0
	spin_probabilidad.step = 5.0
	spin_probabilidad.value_changed.connect(_on_probabilidad_cambiada)
	hbox_prob.add_child(spin_probabilidad)


func _crear_tab_elementos() -> void:
	var tab := VBoxContainer.new()
	tab.name = "Elementos"
	tab_container.add_child(tab)

	var hbox := HBoxContainer.new()
	tab.add_child(hbox)

	var btn_agregar := Button.new()
	btn_agregar.text = "+ Elemento"
	btn_agregar.pressed.connect(_on_agregar_elemento)
	hbox.add_child(btn_agregar)

	var btn_eliminar := Button.new()
	btn_eliminar.text = "- Elemento"
	btn_eliminar.pressed.connect(_on_eliminar_elemento)
	hbox.add_child(btn_eliminar)

	lista_elementos = ItemList.new()
	lista_elementos.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.add_child(lista_elementos)


func _crear_tab_fondo() -> void:
	var tab := VBoxContainer.new()
	tab.name = "Fondo"
	tab_container.add_child(tab)

	var hbox := HBoxContainer.new()
	tab.add_child(hbox)

	var label_fondo := Label.new()
	label_fondo.text = "Escena de Fondo:"
	hbox.add_child(label_fondo)

	option_fondo = OptionButton.new()
	option_fondo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option_fondo.item_selected.connect(_on_fondo_seleccionado)
	hbox.add_child(option_fondo)

	var btn_refrescar := Button.new()
	btn_refrescar.text = "Refrescar"
	btn_refrescar.pressed.connect(_on_refrescar_fondos)
	hbox.add_child(btn_refrescar)


func _crear_grid_niveles() -> void:
	for child in grid_niveles.get_children():
		child.queue_free()
	await get_tree().process_frame
	for i in range(1, MAX_LEVELS + 1):
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


func _actualizar_botones_nivel() -> void:
	for i in range(grid_niveles.get_child_count()):
		var btn: Button = grid_niveles.get_child(i) as Button
		if btn:
			btn.button_pressed = (i + 1 == nivel_actual)


func _actualizar_ui_nivel() -> void:
	if store == null:
		return
	var data = store.obtener_nivel(nivel_actual)
	if data == null:
		return
	label_nivel.text = "Nivel %02d: %s" % [data.nivel_numero, data.nombre_nivel]
	_actualizar_lista_oleadas()
	_actualizar_lista_elementos()
	_actualizar_opciones_fondo()
	if data.oleadas.size() > 0:
		oleada_actual = 0
		_actualizar_ui_oleada()
	else:
		oleada_actual = -1
		_limpiar_ui_oleada()
	_actualizar_info("Nivel %d seleccionado" % nivel_actual)


func _actualizar_lista_oleadas() -> void:
	lista_oleadas.clear()
	var data = store.obtener_nivel(nivel_actual)
	for oleada in data.oleadas:
		lista_oleadas.add_item("Oleada %d (%d enemigos)" % [oleada.numero, oleada.enemigos.size()])


func _actualizar_ui_oleada() -> void:
	if oleada_actual < 0:
		_limpiar_ui_oleada()
		return
	var data = store.obtener_nivel(nivel_actual)
	if oleada_actual >= data.oleadas.size():
		return
	var oleada = data.oleadas[oleada_actual]
	spin_tiempo_spawn.value = oleada.tiempo_entre_spawns
	spin_tiempo_oleada.value = oleada.tiempo_entre_oleadas
	_actualizar_lista_enemigos()


func _limpiar_ui_oleada() -> void:
	lista_enemigos.clear()
	spin_probabilidad.value = 0.0


func _actualizar_lista_enemigos() -> void:
	lista_enemigos.clear()
	var data = store.obtener_nivel(nivel_actual)
	if oleada_actual < 0 or oleada_actual >= data.oleadas.size():
		return
	var oleada = data.oleadas[oleada_actual]
	for enemigo in oleada.enemigos:
		lista_enemigos.add_item("%s (%.0f%%)" % [enemigo.obtener_nombre(), enemigo.probabilidad * 100])


func _actualizar_lista_elementos() -> void:
	lista_elementos.clear()
	var data = store.obtener_nivel(nivel_actual)
	for elem_path in data.elementos_escenario:
		var partes: PackedStringArray = elem_path.split("/")
		lista_elementos.add_item(partes[-1])


func _actualizar_opciones_fondo() -> void:
	option_fondo.clear()
	option_fondo.add_item("(Default)")
	var fondos: Array[String] = _buscar_escenas_en_directorio("res://Scenes/Environment/")
	for fondo in fondos:
		option_fondo.add_item(fondo)
	var data = store.obtener_nivel(nivel_actual)
	if data.escena_fondo != "":
		for i in range(option_fondo.item_count):
			if option_fondo.get_item_text(i) == data.escena_fondo:
				option_fondo.selected = i
				break


func _buscar_escenas_en_directorio(path: String) -> Array[String]:
	var resultado: Array[String] = []
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return resultado
	dir.list_dir_begin()
	var nombre: String = dir.get_next()
	while nombre != "":
		if not dir.current_is_dir():
			if nombre.ends_with(".tscn") or nombre.ends_with(".glb"):
				resultado.append(path + nombre)
		nombre = dir.get_next()
	dir.list_dir_end()
	return resultado


func _on_guardar() -> void:
	if store:
		store.guardar_nivel(nivel_actual)
		_actualizar_info("Nivel %d guardado" % nivel_actual)


func _on_guardar_todos() -> void:
	if store:
		store.guardar_todos()
		_actualizar_info("Todos los niveles guardados")


func _on_agregar_oleada() -> void:
	if store == null:
		return
	var data = store.obtener_nivel(nivel_actual)
	data.agregar_oleada()
	_actualizar_lista_oleadas()
	oleada_actual = data.oleadas.size() - 1
	lista_oleadas.select(oleada_actual)
	_actualizar_ui_oleada()
	_actualizar_info("Oleada %d agregada" % data.oleadas.size())


func _on_eliminar_oleada() -> void:
	if store == null:
		return
	var data = store.obtener_nivel(nivel_actual)
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
	_actualizar_info("Oleada eliminada")


func _on_oleada_seleccionada(index: int) -> void:
	oleada_actual = index
	_actualizar_ui_oleada()


func _on_agregar_enemigo() -> void:
	if store == null:
		return
	var data = store.obtener_nivel(nivel_actual)
	if oleada_actual < 0 or oleada_actual >= data.oleadas.size():
		_actualizar_info("Primero crea una oleada")
		return
	file_enemigo.popup_centered(Vector2i(600, 400))


func _on_enemigo_archivo_seleccionado(path: String) -> void:
	if store == null:
		return
	var data = store.obtener_nivel(nivel_actual)
	if oleada_actual < 0 or oleada_actual >= data.oleadas.size():
		return
	data.agregar_enemigo_a_oleada(oleada_actual, path, 0.0)
	_actualizar_lista_enemigos()
	_actualizar_lista_oleadas()
	_actualizar_info("Enemigo agregado: %s" % path.get_file())


func _on_eliminar_enemigo() -> void:
	if store == null:
		return
	var data = store.obtener_nivel(nivel_actual)
	if oleada_actual < 0 or oleada_actual >= data.oleadas.size():
		return
	var oleada = data.oleadas[oleada_actual]
	var idx: PackedInt32Array = lista_enemigos.get_selected_items()
	if idx.size() == 0:
		return
	oleada.eliminar_enemigo(idx[0])
	_actualizar_lista_enemigos()
	_actualizar_lista_oleadas()
	_actualizar_info("Enemigo eliminado")


func _on_enemigo_seleccionado(index: int) -> void:
	if store == null:
		return
	var data = store.obtener_nivel(nivel_actual)
	if oleada_actual < 0 or oleada_actual >= data.oleadas.size():
		return
	var oleada = data.oleadas[oleada_actual]
	if index >= 0 and index < oleada.enemigos.size():
		spin_probabilidad.value = oleada.enemigos[index].probabilidad * 100


func _on_probabilidad_cambiada(valor: float) -> void:
	if store == null:
		return
	var data = store.obtener_nivel(nivel_actual)
	if oleada_actual < 0 or oleada_actual >= data.oleadas.size():
		return
	var oleada = data.oleadas[oleada_actual]
	var idx: PackedInt32Array = lista_enemigos.get_selected_items()
	if idx.size() == 0:
		return
	oleada.set_probabilidad(idx[0], valor / 100.0)
	_actualizar_lista_enemigos()


func _on_tiempo_spawn_cambiado(valor: float) -> void:
	if store == null:
		return
	var data = store.obtener_nivel(nivel_actual)
	if oleada_actual < 0 or oleada_actual >= data.oleadas.size():
		return
	data.oleadas[oleada_actual].tiempo_entre_spawns = valor


func _on_tiempo_oleada_cambiado(valor: float) -> void:
	if store == null:
		return
	var data = store.obtener_nivel(nivel_actual)
	if oleada_actual < 0 or oleada_actual >= data.oleadas.size():
		return
	data.oleadas[oleada_actual].tiempo_entre_oleadas = valor


func _on_agregar_elemento() -> void:
	file_elemento.popup_centered(Vector2i(600, 400))


func _on_elemento_archivo_seleccionado(path: String) -> void:
	if store == null:
		return
	var data = store.obtener_nivel(nivel_actual)
	data.agregar_elemento(path)
	_actualizar_lista_elementos()
	_actualizar_info("Elemento agregado: %s" % path.get_file())


func _on_eliminar_elemento() -> void:
	if store == null:
		return
	var data = store.obtener_nivel(nivel_actual)
	var idx: PackedInt32Array = lista_elementos.get_selected_items()
	if idx.size() == 0:
		return
	data.eliminar_elemento(idx[0])
	_actualizar_lista_elementos()
	_actualizar_info("Elemento eliminado")


func _on_refrescar_fondos() -> void:
	_actualizar_opciones_fondo()
	_actualizar_info("Fondos actualizados")


func _on_fondo_seleccionado(index: int) -> void:
	if store == null:
		return
	var data = store.obtener_nivel(nivel_actual)
	if index == 0:
		data.escena_fondo = ""
	else:
		data.escena_fondo = option_fondo.get_item_text(index)


func _actualizar_info(mensaje: String) -> void:
	label_info.text = mensaje
