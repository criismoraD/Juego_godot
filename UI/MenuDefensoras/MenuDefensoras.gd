class_name MenuDefensoras
extends CanvasLayer

## Menú minimalista de configuración de defensoras en plataformas.
## Muestra las siluetas de las plataformas y de las defensoras (Arquera Celeste / Ballestera Naranja).
## Permite cambiar de piso con W/S o flechas y alternar de defensora con A/D o clic.

signal cerrado
signal configuracion_cambiada(config: Dictionary)

const TEXTO_ARQUERA: String = "Defensora arquera: Vida 2\nEficaz contra objetivos aéreos y en altura\nPuede utilizar diferentes tipos de flechas\nCadencia de disparo alta"
const TEXTO_BALLESTERA: String = "Defensora ballestera: Vida 4\nEficaz contra infantería enemiga básica \nCada 5 tiros puedes aplicar la habilidad “refuerzo de escudo” que otorga + 2 de vida a su escudo de piso  \nCadencia de disparo media"

const COLOR_ARQUERA := Color(0.22, 0.9, 0.95, 1.0)
const COLOR_BALLESTERA := Color(1.0, 0.55, 0.1, 1.0)

@onready var panel_raiz: Control = %PanelRaiz
@onready var tex_defensora_piso1: TextureRect = %TexDefensoraPiso1
@onready var tex_defensora_piso2: TextureRect = %TexDefensoraPiso2
@onready var panel_piso1: PanelContainer = %PanelPiso1
@onready var panel_piso2: PanelContainer = %PanelPiso2
@onready var lbl_titulo_defensora: Label = %LblTituloDefensora
@onready var lbl_descripcion_defensora: Label = %LblDescripcionDefensora
@onready var btn_volver: Button = %BtnVolver
@onready var btn_piso1_prev: Button = %BtnPiso1Prev
@onready var btn_piso1_next: Button = %BtnPiso1Next
@onready var btn_piso2_prev: Button = %BtnPiso2Prev
@onready var btn_piso2_next: Button = %BtnPiso2Next

var tex_arquera: Texture2D = preload("res://UI/MenuDefensoras/silueta_arquera_celeste.png")
var tex_ballestera: Texture2D = preload("res://UI/MenuDefensoras/silueta_ballestera_naranja.png")

var piso_seleccionado: int = 2  ## 2: Piso Superior, 1: Piso Inferior
var config_local: Dictionary = {
	1: "arquera",
	2: "arquera"
}


var style_selected: StyleBox = null
var style_normal: StyleBox = null


func _ready() -> void:
	visible = false
	if panel_piso2 and panel_piso2.has_theme_stylebox("panel"):
		style_selected = panel_piso2.get_theme_stylebox("panel")
	if panel_piso1 and panel_piso1.has_theme_stylebox("panel"):
		style_normal = panel_piso1.get_theme_stylebox("panel")
	_traducir_textos()
	_conectar_eventos()


func _traducir_textos() -> void:
	var lbl_tit: Label = find_child("Titulo", true, false) as Label
	if lbl_tit:
		lbl_tit.text = tr("MENU_DEFENSORAS_TITULO")

	var lbl_sub: Label = find_child("Subtitulo", true, false) as Label
	if lbl_sub:
		lbl_sub.text = tr("MENU_DEFENSORAS_SUBTITULO")

	if panel_piso2:
		var lbl_p2: Label = panel_piso2.find_child("LblPiso", true, false) as Label
		if lbl_p2:
			lbl_p2.text = tr("MENU_DEFENSORAS_PISO_SUPERIOR")

	if panel_piso1:
		var lbl_p1: Label = panel_piso1.find_child("LblPiso", true, false) as Label
		if lbl_p1:
			lbl_p1.text = tr("MENU_DEFENSORAS_PISO_INFERIOR")

	var lbl_ctrl: Label = find_child("LblControles", true, false) as Label
	if lbl_ctrl:
		lbl_ctrl.text = tr("MENU_DEFENSORAS_CONTROLES")

	if btn_volver:
		btn_volver.text = tr("BTN_CONFIRMAR_SALIR")


func _conectar_eventos() -> void:
	if btn_volver:
		btn_volver.pressed.connect(cerrar)

	if btn_piso1_prev:
		btn_piso1_prev.pressed.connect(func():
			_cambiar_piso(1)
			_alternar_defensora(1)
		)
	if btn_piso1_next:
		btn_piso1_next.pressed.connect(func():
			_cambiar_piso(1)
			_alternar_defensora(1)
		)

	if btn_piso2_prev:
		btn_piso2_prev.pressed.connect(func():
			_cambiar_piso(2)
			_alternar_defensora(2)
		)
	if btn_piso2_next:
		btn_piso2_next.pressed.connect(func():
			_cambiar_piso(2)
			_alternar_defensora(2)
		)

	if panel_piso1:
		panel_piso1.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				if piso_seleccionado != 1:
					_cambiar_piso(1)
				else:
					_alternar_defensora(1)
		)

	if panel_piso2:
		panel_piso2.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				if piso_seleccionado != 2:
					_cambiar_piso(2)
				else:
					_alternar_defensora(2)
		)


func abrir() -> void:
	_set_player_movimiento(false)

	# Cargar configuración global si existe
	if GameUI.defensoras_config != null and GameUI.defensoras_config is Dictionary:
		config_local[1] = GameUI.defensoras_config.get(1, "arquera")
		config_local[2] = GameUI.defensoras_config.get(2, "arquera")

	_actualizar_vistas_defensoras()
	_cambiar_piso(piso_seleccionado)

	visible = true
	if panel_raiz:
		panel_raiz.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(panel_raiz, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)


func cerrar() -> void:
	if not visible:
		return

	# Guardar en estado global
	GameUI.defensoras_config[1] = config_local.get(1, "arquera")
	GameUI.defensoras_config[2] = config_local.get(2, "arquera")
	configuracion_cambiada.emit(config_local.duplicate())

	if panel_raiz:
		var tween := create_tween()
		tween.tween_property(panel_raiz, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_SINE)
		await tween.finished

	visible = false
	_set_player_movimiento(true)
	cerrado.emit()


func _cambiar_piso(nuevo_piso: int) -> void:
	piso_seleccionado = clamp(nuevo_piso, 1, 2)

	# Actualizar resaltado de paneles
	if panel_piso1 and style_selected and style_normal:
		panel_piso1.add_theme_stylebox_override("panel", style_selected if piso_seleccionado == 1 else style_normal)
	if panel_piso2 and style_selected and style_normal:
		panel_piso2.add_theme_stylebox_override("panel", style_selected if piso_seleccionado == 2 else style_normal)

	_actualizar_panel_descripcion()


func _set_player_movimiento(permitir: bool) -> void:
	var player = get_tree().get_first_node_in_group("player_interior")
	if player and "puede_moverse" in player:
		player.puede_moverse = permitir


func _alternar_defensora(piso: int) -> void:
	var actual: String = config_local.get(piso, "arquera")
	var nueva: String = "ballestera" if actual == "arquera" else "arquera"
	config_local[piso] = nueva

	# Sonido sutil si AudioManager está disponible
	if Engine.has_singleton("AudioManager"):
		AudioManager.play_sfx("res://Assets/Audio/SFX/click.wav")

	_actualizar_vistas_defensoras()
	_actualizar_panel_descripcion()


func _actualizar_vistas_defensoras() -> void:
	# Piso 1 (inferior)
	var tipo1: String = config_local.get(1, "arquera")
	if tex_defensora_piso1:
		tex_defensora_piso1.texture = tex_ballestera if tipo1 == "ballestera" else tex_arquera

	# Piso 2 (superior)
	var tipo2: String = config_local.get(2, "arquera")
	if tex_defensora_piso2:
		tex_defensora_piso2.texture = tex_ballestera if tipo2 == "ballestera" else tex_arquera


func _actualizar_panel_descripcion() -> void:
	var tipo: String = config_local.get(piso_seleccionado, "arquera")

	if lbl_titulo_defensora:
		if tipo == "ballestera":
			lbl_titulo_defensora.text = tr("DEFENSORA_BALLESTERA_TITULO")
			lbl_titulo_defensora.modulate = COLOR_BALLESTERA
		else:
			lbl_titulo_defensora.text = tr("DEFENSORA_ARQUERA_TITULO")
			lbl_titulo_defensora.modulate = COLOR_ARQUERA

	if lbl_descripcion_defensora:
		lbl_descripcion_defensora.text = tr("DESC_DEFENSORA_BALLESTERA") if tipo == "ballestera" else tr("DESC_DEFENSORA_ARQUERA")


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_W, KEY_UP:
				_cambiar_piso(2)
				get_viewport().set_input_as_handled()
			KEY_S, KEY_DOWN:
				_cambiar_piso(1)
				get_viewport().set_input_as_handled()
			KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT:
				_alternar_defensora(piso_seleccionado)
				get_viewport().set_input_as_handled()
			KEY_ESCAPE, KEY_ENTER:
				cerrar()
				get_viewport().set_input_as_handled()
			KEY_E:
				# Cerrar con E para flujo natural de interacción
				cerrar()
				get_viewport().set_input_as_handled()
