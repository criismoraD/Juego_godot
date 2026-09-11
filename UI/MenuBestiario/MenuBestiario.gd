class_name MenuBestiario
extends CanvasLayer

## Menú minimalista de Bestiario para la Torre de Configuración.
## Sigue el mismo estilo visual minimalista y tipografía que el Menú de Defensoras.
## Permite seleccionar enemigos de la lista izquierda y ver su ficha técnica a la derecha.

signal cerrado
signal enemigo_seleccionado(datos: Dictionary)

const ENEMIGOS_DEFAULT: Array[Dictionary] = [
	{
		"id": "imp_embajador",
		"numero": 1,
		"nombre": "Imp Embajador",
		"nombre_key": "BESTIARIO_IMP_EMBAJADOR_NOMBRE",
		"hp": "6",
		"att": "1",
		"item": "Disparo múltiple",
		"item_key": "BESTIARIO_ITEM_DISPARO_MULTIPLE",
		"descripcion": "Un imp con el máximo rango militar, carga con el estandarte de Vesara, atacarlo es como declarar la guerra",
		"descripcion_key": "BESTIARIO_IMP_EMBAJADOR_DESC",
		"imagen_path": "res://UI/MenuBestiario/Portraits/imp_embajador.png",
		"imagen": null
	},
	{
		"id": "imp",
		"numero": 2,
		"nombre": "Imp",
		"nombre_key": "BESTIARIO_IMP_NOMBRE",
		"hp": "1",
		"att": "1",
		"item": "Ninguno",
		"item_key": "BESTIARIO_ITEM_NINGUNO",
		"descripcion": "El eslabón más bajo de cualquier ejercito demoniaco, su corto alcance lo hacer un objetivo fácil",
		"descripcion_key": "BESTIARIO_IMP_DESC",
		"imagen_path": "res://UI/MenuBestiario/Portraits/imp.png",
		"imagen": null
	},
	{
		"id": "arquera_goblin",
		"numero": 3,
		"nombre": "Arquera Goblin",
		"nombre_key": "BESTIARIO_ARQUERA_GOBLIN_NOMBRE",
		"hp": "1",
		"att": "1",
		"item": "Ninguno",
		"item_key": "BESTIARIO_ITEM_NINGUNO",
		"descripcion": "Por si solas no representan ninguna amenaza, pero dado a su largo rango son letales como unidad de apoyo",
		"descripcion_key": "BESTIARIO_ARQUERA_GOBLIN_DESC",
		"imagen_path": "res://UI/MenuBestiario/Portraits/arquera_goblin.png",
		"imagen": null
	},
	{
		"id": "imp_escudera",
		"numero": 4,
		"nombre": "Imp Escudera",
		"nombre_key": "BESTIARIO_IMP_ESCUDERA_NOMBRE",
		"hp": "1",
		"att": "Ninguno",
		"item": "Poción curativa",
		"item_key": "BESTIARIO_ITEM_POCION_CURATIVA",
		"descripcion": "Posee un escudo rudimentario de madera con el cual protege a sus compañeros, su rápido escape la hace un objetivo difícil de alcanzar",
		"descripcion_key": "BESTIARIO_IMP_ESCUDERA_DESC",
		"imagen_path": "res://UI/MenuBestiario/Portraits/imp_escudera.png",
		"imagen": null
	},
	{
		"id": "ballestero_goblin",
		"numero": 5,
		"nombre": "Ballestero Goblin",
		"nombre_key": "BESTIARIO_BALLESTERO_GOBLIN_NOMBRE",
		"hp": "1",
		"att": "1",
		"item": "Flecha explosiva",
		"item_key": "BESTIARIO_ITEM_FLECHA_EXPLOSIVA",
		"descripcion": "El goblin es la unidad más reconocible de cualquier ejercito demoniaco, Su arma posee un alcance medio y gran precisión\nSiempre acude al llamado del cuerno",
		"descripcion_key": "BESTIARIO_BALLESTERO_GOBLIN_DESC",
		"imagen_path": "res://UI/MenuBestiario/Portraits/ballestero_goblin.png",
		"imagen": null
	},
	{
		"id": "guardiana_moradita",
		"numero": 6,
		"nombre": "Guardiana Moradita",
		"nombre_key": "BESTIARIO_GUARDIANA_MORADITA_NOMBRE",
		"hp": "10",
		"att": "1",
		"item": "Poción curativa",
		"item_key": "BESTIARIO_ITEM_POCION_CURATIVA",
		"descripcion": "Su escudo es un bastión capaz de resistir mucho castigo, pero la usuaria es vulnerable mientras ataca, un solo disparo cargado certero puede derribarla",
		"descripcion_key": "BESTIARIO_GUARDIANA_MORADITA_DESC",
		"imagen_path": "res://UI/MenuBestiario/Portraits/guardiana_moradita.png",
		"imagen": null
	},
	{
		"id": "goblin_rosada",
		"numero": 7,
		"nombre": "Goblin Rosada",
		"nombre_key": "BESTIARIO_GOBLIN_ROSADA_NOMBRE",
		"hp": "1",
		"att": "5 (dispara 5 proyectiles en rápida sucesión)",
		"item": "Disparo múltiple",
		"item_key": "BESTIARIO_ITEM_DISPARO_MULTIPLE",
		"descripcion": "Cuenta la leyenda que una chica goblin se alzara y dominara el campo de batalla, pose un aura capaz de desviar hasta 4 flechas, solo las explosiones son capaces de atravesarla",
		"descripcion_key": "BESTIARIO_GOBLIN_ROSADA_DESC",
		"imagen_path": "res://UI/MenuBestiario/Portraits/goblin_rosada.png",
		"imagen": null
	},
	{
		"id": "gargola",
		"numero": 8,
		"nombre": "Gargola",
		"nombre_key": "BESTIARIO_GARGOLA_NOMBRE",
		"hp": "1",
		"att": "1",
		"item": "Poción curativa",
		"item_key": "BESTIARIO_ITEM_POCION_CURATIVA",
		"descripcion": "Enemigo volador que solo aparece al atardecer, somete a sus presas con proyectiles de fuego",
		"descripcion_key": "BESTIARIO_GARGOLA_DESC",
		"imagen_path": "res://UI/MenuBestiario/Portraits/gargola.png",
		"imagen": null
	},
	{
		"id": "globo_aerostatico",
		"numero": 9,
		"nombre": "Globo Aerostático",
		"nombre_key": "BESTIARIO_GLOBO_AEROSTATICO_NOMBRE",
		"hp": "3",
		"att": "1",
		"item": "Disparo múltiple",
		"item_key": "BESTIARIO_ITEM_DISPARO_MULTIPLE",
		"descripcion": "Unidad Aérea que puede disparar en movimiento, su gran tamaño lo hace un blanco fácil para las arqueras defensoras, al ser destruido se precipita al suelo causando daño",
		"descripcion_key": "BESTIARIO_GLOBO_AEROSTATICO_DESC",
		"imagen_path": "res://UI/MenuBestiario/Portraits/globo_aerostatico.png",
		"imagen": null
	},
	{
		"id": "arquera_lonko",
		"numero": 10,
		"nombre": "Arquera Lonko",
		"nombre_key": "BESTIARIO_ARQUERA_LONKO_NOMBRE",
		"hp": "5",
		"att": "1",
		"item": "Flecha explosiva",
		"item_key": "BESTIARIO_ITEM_FLECHA_EXPLOSIVA",
		"descripcion": "Unidad de elite capaz de alzar un pilar para atacar desde lo alto, su habilidad especial le permite marcar al jugador la última posición del jugador como impacto seguro si este no se mueve\nSu pilar tiene 15 de vida, pero es vulnerable al daño explosivo\nSu ataque especial provoca el estado aturdimiento el cual impide que puedas atacar por 3 segundos (defensoras se ven afectada)\nEl ataque especial no provoca daño a las defensoras",
		"descripcion_key": "BESTIARIO_ARQUERA_LONKO_DESC",
		"imagen_path": "res://UI/MenuBestiario/Portraits/arquera_lonko.png",
		"imagen": null
	}
]

const COLOR_TITULO_FICHA := Color(1.0, 0.84, 0.45, 1.0) # Dorado / ámbar de la versión anterior
const COLOR_STAT_KEY := Color(0.9, 0.72, 0.25, 1.0)     # Claves doradas (No, HP, ATT, ITEM)
const COLOR_ITEM_VAL := Color(0.4, 0.95, 0.75, 1.0)     # Turquesa / menta claro para items
const COLOR_NORMAL_TEXT := Color(0.85, 0.88, 0.95, 1.0)
const COLOR_SELECTED_TEXT := Color(1.0, 0.88, 0.5, 1.0)  # Dorado brillante para seleccionado
const COLOR_HOVER_TEXT := Color(1.0, 1.0, 1.0, 1.0)

@export var enemigos: Array[Dictionary] = []

@onready var panel_raiz: Control = %PanelRaiz
@onready var titulo: Label = %Titulo
@onready var lbl_titulo_lista: Label = %LblTituloLista
@onready var lista_contenedor: VBoxContainer = %ListaContenedor
@onready var scroll_lista: ScrollContainer = %ScrollLista
@onready var lbl_nombre_enemigo: Label = %LblNombreEnemigo
@onready var lbl_val_numero: Label = %LblValNumero
@onready var lbl_key_hp: Label = %LblKeyHP
@onready var lbl_val_hp: Label = %LblValHP
@onready var lbl_key_att: Label = %LblKeyATT
@onready var lbl_val_att: Label = %LblValATT
@onready var lbl_key_item: Label = %LblKeyITEM
@onready var lbl_val_item: Label = %LblValItem
@onready var tex_retrato_enemigo: TextureRect = %TexRetratoEnemigo
@onready var placeholder_retrato: Control = %PlaceholderRetrato
@onready var lbl_placeholder: Label = %LblPlaceholder
@onready var lbl_titulo_desc: Label = %LblTituloDesc
@onready var lbl_descripcion: Label = %LblDescripcion
@onready var lbl_controles: Label = %LblControles
@onready var btn_volver: Button = %BtnVolver

var indice_seleccionado: int = 0
var botones_enemigos: Array[Button] = []

# Estilos reutilizables para los botones de la lista (Minimalistas)
var style_btn_normal: StyleBoxFlat = null
var style_btn_hover: StyleBoxFlat = null
var style_btn_selected: StyleBoxFlat = null


func _ready() -> void:
	visible = false
	_inicializar_estilos()
	_traducir_textos()

	if enemigos.is_empty():
		_cargar_enemigos_default()

	_crear_botones_lista()

	if btn_volver:
		btn_volver.pressed.connect(cerrar)


func _inicializar_estilos() -> void:
	# Estilo normal de botón minimalista (acorde a MenuDefensoras)
	style_btn_normal = StyleBoxFlat.new()
	style_btn_normal.bg_color = Color(0.06, 0.07, 0.11, 0.85)
	style_btn_normal.set_border_width_all(1)
	style_btn_normal.border_color = Color(0.25, 0.28, 0.4, 0.7)
	style_btn_normal.set_corner_radius_all(6)
	style_btn_normal.content_margin_left = 14
	style_btn_normal.content_margin_right = 14
	style_btn_normal.content_margin_top = 8
	style_btn_normal.content_margin_bottom = 8

	# Estilo hover
	style_btn_hover = StyleBoxFlat.new()
	style_btn_hover.bg_color = Color(0.16, 0.18, 0.26, 0.95)
	style_btn_hover.set_border_width_all(1)
	style_btn_hover.border_color = Color(0.6, 0.75, 1.0, 0.9)
	style_btn_hover.set_corner_radius_all(6)
	style_btn_hover.content_margin_left = 14
	style_btn_hover.content_margin_right = 14
	style_btn_hover.content_margin_top = 8
	style_btn_hover.content_margin_bottom = 8

	# Estilo seleccionado (borde dorado como la versión anterior)
	style_btn_selected = StyleBoxFlat.new()
	style_btn_selected.bg_color = Color(0.12, 0.14, 0.22, 0.95)
	style_btn_selected.set_border_width_all(2)
	style_btn_selected.border_color = Color(0.95, 0.76, 0.3, 1.0)
	style_btn_selected.set_corner_radius_all(6)
	style_btn_selected.shadow_size = 4
	style_btn_selected.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	style_btn_selected.content_margin_left = 14
	style_btn_selected.content_margin_right = 14
	style_btn_selected.content_margin_top = 8
	style_btn_selected.content_margin_bottom = 8


func _cargar_enemigos_default() -> void:
	enemigos.clear()
	for e in ENEMIGOS_DEFAULT:
		enemigos.append(e.duplicate(true))


func _crear_botones_lista() -> void:
	if not lista_contenedor:
		return

	for child in lista_contenedor.get_children():
		child.queue_free()
	botones_enemigos.clear()

	for i in range(enemigos.size()):
		var datos: Dictionary = enemigos[i]
		var btn := Button.new()
		btn.name = "BtnEnemigo_%d" % i
		btn.text = "%02d. %s" % [datos.get("numero", i + 1), _obtener_nombre_enemigo(datos)]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 44)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.focus_mode = Control.FOCUS_ALL

		# Tipografía estándar de Godot idéntica a MenuDefensoras
		btn.add_theme_font_size_override("font_size", 16)
		btn.add_theme_color_override("font_color", COLOR_NORMAL_TEXT)
		btn.add_theme_color_override("font_hover_color", COLOR_HOVER_TEXT)
		btn.add_theme_color_override("font_focus_color", COLOR_HOVER_TEXT)
		btn.add_theme_color_override("font_pressed_color", Color.WHITE)

		btn.add_theme_stylebox_override("normal", style_btn_normal)
		btn.add_theme_stylebox_override("hover", style_btn_hover)
		btn.add_theme_stylebox_override("focus", style_btn_selected)
		btn.add_theme_stylebox_override("pressed", style_btn_selected)

		var idx := i
		btn.pressed.connect(func():
			seleccionar_enemigo(idx)
			_reproducir_sfx_click()
		)
		btn.focus_entered.connect(func():
			if indice_seleccionado != idx:
				seleccionar_enemigo(idx)
		)

		lista_contenedor.add_child(btn)
		botones_enemigos.append(btn)


func abrir() -> void:
	_set_player_movimiento(false)
	visible = true
	_traducir_textos()

	if botones_enemigos.is_empty():
		_crear_botones_lista()

	seleccionar_enemigo(indice_seleccionado)

	if indice_seleccionado >= 0 and indice_seleccionado < botones_enemigos.size():
		botones_enemigos[indice_seleccionado].grab_focus()

	if panel_raiz:
		panel_raiz.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(panel_raiz, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)


func cerrar() -> void:
	if not visible:
		return

	_reproducir_sfx_click()

	if panel_raiz:
		var tween := create_tween()
		tween.tween_property(panel_raiz, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_SINE)
		await tween.finished

	visible = false
	_set_player_movimiento(true)
	cerrado.emit()


func seleccionar_enemigo(idx: int) -> void:
	if idx < 0 or idx >= enemigos.size():
		return

	indice_seleccionado = idx
	var datos: Dictionary = enemigos[idx]

	# Actualizar estilos y textos de los botones
	for i in range(botones_enemigos.size()):
		var b := botones_enemigos[i]
		var num: int = int(enemigos[i].get("numero", i + 1))
		var nom: String = _obtener_nombre_enemigo(enemigos[i])
		if i == idx:
			b.text = "▶ %02d. %s" % [num, nom]
			b.add_theme_stylebox_override("normal", style_btn_selected)
			b.add_theme_color_override("font_color", COLOR_SELECTED_TEXT)
		else:
			b.text = "   %02d. %s" % [num, nom]
			b.add_theme_stylebox_override("normal", style_btn_normal)
			b.add_theme_color_override("font_color", COLOR_NORMAL_TEXT)

	# Actualizar Nombre
	if lbl_nombre_enemigo:
		lbl_nombre_enemigo.text = _obtener_nombre_enemigo(datos).to_upper()
		lbl_nombre_enemigo.add_theme_color_override("font_color", COLOR_TITULO_FICHA)

	# Actualizar Stats
	if lbl_val_numero:
		lbl_val_numero.text = "N° %d" % int(datos.get("numero", idx + 1))
	if lbl_val_hp:
		lbl_val_hp.text = str(datos.get("hp", "1"))
	if lbl_val_att:
		var att_str: String = str(datos.get("att", "1"))
		if att_str.strip_edges().to_lower() == "ninguno":
			lbl_val_att.text = tr("BESTIARIO_ITEM_NINGUNO")
		else:
			lbl_val_att.text = att_str
	if lbl_val_item:
		lbl_val_item.text = _obtener_item_enemigo(datos)

	# Actualizar Retrato del Enemigo
	_actualizar_retrato(datos)

	# Actualizar Descripción
	if lbl_descripcion:
		lbl_descripcion.text = _obtener_descripcion_enemigo(datos)

	# Asegurar que el botón seleccionado sea visible en el scroll
	if scroll_lista and idx >= 0 and idx < botones_enemigos.size():
		var btn_target := botones_enemigos[idx]
		scroll_lista.ensure_control_visible(btn_target)

	enemigo_seleccionado.emit(datos)


func _actualizar_retrato(datos: Dictionary) -> void:
	var tex: Texture2D = datos.get("imagen", null)

	if tex == null:
		var path: String = str(datos.get("imagen_path", ""))
		if not path.is_empty() and ResourceLoader.exists(path):
			tex = load(path) as Texture2D

	if tex_retrato_enemigo:
		if tex != null:
			tex_retrato_enemigo.texture = tex
			tex_retrato_enemigo.visible = true
			if placeholder_retrato:
				placeholder_retrato.visible = false
		else:
			tex_retrato_enemigo.texture = null
			tex_retrato_enemigo.visible = false
			if placeholder_retrato:
				placeholder_retrato.visible = true
			if lbl_placeholder:
				lbl_placeholder.text = "[ %s ]\n\n(Coloca la imagen PNG en:\n%s)" % [
					_obtener_nombre_enemigo(datos),
					datos.get("imagen_path", "")
				]


func _traducir_textos() -> void:
	if titulo:
		titulo.text = tr("MENU_BESTIARIO")
	if lbl_titulo_lista:
		lbl_titulo_lista.text = tr("BESTIARIO_LISTADO_ENEMIGOS")
	if lbl_key_hp:
		lbl_key_hp.text = tr("BESTIARIO_KEY_HP")
	if lbl_key_att:
		lbl_key_att.text = tr("BESTIARIO_KEY_ATT")
	if lbl_key_item:
		lbl_key_item.text = tr("BESTIARIO_KEY_ITEM")
	if lbl_titulo_desc:
		lbl_titulo_desc.text = tr("BESTIARIO_TITULO_DESC")
	if lbl_controles:
		lbl_controles.text = tr("BESTIARIO_CONTROLES")
	if btn_volver:
		btn_volver.text = tr("BTN_CONFIRMAR_SALIR")


func _obtener_nombre_enemigo(datos: Dictionary) -> String:
	var key: String = datos.get("nombre_key", "")
	if not key.is_empty():
		return tr(key)
	return str(datos.get("nombre", "Desconocido"))


func _obtener_item_enemigo(datos: Dictionary) -> String:
	var key: String = datos.get("item_key", "")
	if not key.is_empty():
		return tr(key)
	return str(datos.get("item", "Ninguno"))


func _obtener_descripcion_enemigo(datos: Dictionary) -> String:
	var key: String = datos.get("descripcion_key", "")
	if not key.is_empty():
		return tr(key)
	return str(datos.get("descripcion", ""))


func _reproducir_sfx_click() -> void:
	var audio_mgr: Node = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.call("play_sfx", "res://Assets/Audio/SFX/click.wav")
		return

	var stream: AudioStream = load("res://TEST_/Sonido interactuar mueble.wav")
	if stream:
		var asp := AudioStreamPlayer.new()
		asp.stream = stream
		asp.bus = "Master"
		add_child(asp)
		asp.play()
		asp.finished.connect(asp.queue_free)


func _set_player_movimiento(permitir: bool) -> void:
	var player = get_tree().get_first_node_in_group("player_interior")
	if player and "puede_moverse" in player:
		player.puede_moverse = permitir


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_W, KEY_UP:
				var nuevo_idx := posmod(indice_seleccionado - 1, enemigos.size())
				seleccionar_enemigo(nuevo_idx)
				if nuevo_idx >= 0 and nuevo_idx < botones_enemigos.size():
					botones_enemigos[nuevo_idx].grab_focus()
				get_viewport().set_input_as_handled()
			KEY_S, KEY_DOWN:
				var nuevo_idx := posmod(indice_seleccionado + 1, enemigos.size())
				seleccionar_enemigo(nuevo_idx)
				if nuevo_idx >= 0 and nuevo_idx < botones_enemigos.size():
					botones_enemigos[nuevo_idx].grab_focus()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE, KEY_E, KEY_BACKSPACE:
				cerrar()
				get_viewport().set_input_as_handled()
