class_name UIVidaJefe
extends CanvasLayer

## Barra superior de vida del jefe (Submarino, 43). Se muestra al emerger el
## jefe y se oculta al derrotarlo. Se conecta por código a las señales del jefe.

@export var nombre_jefe: String = "SUBMARINO"
@export var color_relleno: Color = Color(0.85, 0.15, 0.2, 1.0)
@export var color_fondo: Color = Color(0.1, 0.1, 0.12, 0.85)

var _barra: ProgressBar = null
var _etiqueta: Label = null
var _contenedor: Control = null
var _jefe: Node = null


func _ready() -> void:
	add_to_group("ui_vida_jefe")
	layer = 90
	_construir_ui()
	ocultar()
	_conectar_jefe_existente()


func _construir_ui() -> void:
	_contenedor = Control.new()
	_contenedor.name = "ContenedorVidaJefe"
	_contenedor.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_contenedor.offset_left = -260.0
	_contenedor.offset_right = 260.0
	_contenedor.offset_top = 16.0
	_contenedor.offset_bottom = 64.0
	add_child(_contenedor)
	_etiqueta = Label.new()
	_etiqueta.text = nombre_jefe
	_etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_etiqueta.add_theme_font_size_override("font_size", 20)
	_etiqueta.add_theme_color_override("font_color", Color.WHITE)
	_etiqueta.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_etiqueta.add_theme_constant_override("shadow_offset_x", 1)
	_etiqueta.add_theme_constant_override("shadow_offset_y", 1)
	_etiqueta.set_anchors_preset(Control.PRESET_FULL_RECT)
	_etiqueta.offset_bottom = 24.0
	_contenedor.add_child(_etiqueta)
	_barra = ProgressBar.new()
	_barra.min_value = 0.0
	_barra.max_value = 43.0
	_barra.value = 43.0
	_barra.show_percentage = false
	_barra.set_anchors_preset(Control.PRESET_FULL_RECT)
	_barra.offset_top = 26.0
	_contenedor.add_child(_barra)
	_aplicar_estilo()


func _aplicar_estilo() -> void:
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = color_fondo
	fondo.corner_radius_top_left = 6
	fondo.corner_radius_top_right = 6
	fondo.corner_radius_bottom_left = 6
	fondo.corner_radius_bottom_right = 6
	var relleno := StyleBoxFlat.new()
	relleno.bg_color = color_relleno
	relleno.corner_radius_top_left = 6
	relleno.corner_radius_top_right = 6
	relleno.corner_radius_bottom_left = 6
	relleno.corner_radius_bottom_right = 6
	_barra.add_theme_stylebox_override("background", fondo)
	_barra.add_theme_stylebox_override("fill", relleno)


func _conectar_jefe_existente() -> void:
	if get_tree() == null:
		return
	var jefe := get_tree().get_first_node_in_group("jefe_submarino") as Node
	if is_instance_valid(jefe):
		conectar_jefe(jefe)
	else:
		if not get_tree().node_added.is_connected(_on_node_added):
			get_tree().node_added.connect(_on_node_added)


func _on_node_added(nodo: Node) -> void:
	if is_instance_valid(_jefe):
		return
	if nodo.is_in_group("jefe_submarino"):
		conectar_jefe(nodo)


func conectar_jefe(jefe: Node) -> void:
	if not is_instance_valid(jefe):
		return
	_jefe = jefe
	if jefe.has_signal("vida_cambiada"):
		if not jefe.is_connected("vida_cambiada", _on_vida_cambiada):
			jefe.connect("vida_cambiada", _on_vida_cambiada)
	if jefe.has_signal("jefe_derrotado"):
		if not jefe.is_connected("jefe_derrotado", _on_jefe_derrotado):
			jefe.connect("jefe_derrotado", _on_jefe_derrotado)
	if jefe.has_signal("combate_iniciado"):
		if not jefe.is_connected("combate_iniciado", _on_combate_iniciado):
			jefe.connect("combate_iniciado", _on_combate_iniciado)
	if jefe.has_signal("emergido"):
		if not jefe.is_connected("emergido", _on_combate_iniciado):
			jefe.connect("emergido", _on_combate_iniciado)
	if "vida_actual_jefe" in jefe and "vida_maxima_jefe" in jefe:
		_actualizar_valores_barra(int(jefe.get("vida_actual_jefe")), int(jefe.get("vida_maxima_jefe")))
	var ya_en_combate: bool = false
	if "combate_activo" in jefe and bool(jefe.get("combate_activo")):
		ya_en_combate = true
	elif jefe.has_method("esta_en_superficie") and jefe.esta_en_superficie():
		ya_en_combate = true
	if ya_en_combate:
		mostrar()
	else:
		ocultar()


func _actualizar_valores_barra(actual: int, maxima: int) -> void:
	if not is_instance_valid(_barra):
		return
	_barra.max_value = float(maxi(1, maxima))
	_barra.value = float(maxi(0, actual))


func _on_combate_iniciado() -> void:
	mostrar()


func _on_vida_cambiada(actual: int, maxima: int) -> void:
	_actualizar_valores_barra(actual, maxima)
	if is_instance_valid(_jefe) and "combate_activo" in _jefe and bool(_jefe.get("combate_activo")):
		mostrar()
	elif actual < maxima and actual > 0:
		mostrar()


func mostrar() -> void:
	if is_instance_valid(_contenedor):
		_contenedor.visible = true


func ocultar() -> void:
	if is_instance_valid(_contenedor):
		_contenedor.visible = false


func _on_jefe_derrotado() -> void:
	ocultar()
