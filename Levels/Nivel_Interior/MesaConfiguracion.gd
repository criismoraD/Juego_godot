class_name MesaConfiguracion
extends StaticBody3D

## Controlador de la Mesa de Configuración en el cuarto interior.
## - Detecta la proximidad del jugador, animando un borde morado y el prompt "E".
## - Al presionar E abre el menú con opciones: DEFENSORAS, BESTIARIO, SALIR.
## - Conecta con el Menú Minimalista de Defensoras para configurar las aliadas.

signal defensoras_presionado
signal bestiario_presionado
signal salir_presionado

@onready var area_interaccion: Area3D = $AreaInteraccion
@onready var menu_canvas: CanvasLayer = $CanvasMenu
@onready var panel_menu: Control = %PanelMenu
@onready var btn_defensoras: Button = %BtnDefensoras
@onready var btn_bestiario: Button = %BtnBestiario
@onready var btn_salir: Button = %BtnSalir
@onready var prompt_e: Label3D = %PromptE
@onready var menu_defensoras: MenuDefensoras = %MenuDefensoras

var _jugador_cerca: bool = false
var _outline_mat: StandardMaterial3D = null
var _tween_efecto: Tween = null


func _ready() -> void:
	_configurar_outline_mesa()

	if prompt_e:
		prompt_e.text = "[E] " + tr("PROMPT_INTERACTUAR")
		prompt_e.modulate.a = 0.0
		prompt_e.outline_modulate.a = 0.0
		prompt_e.visible = false

	if area_interaccion:
		area_interaccion.body_entered.connect(_on_body_entered)
		area_interaccion.body_exited.connect(_on_body_exited)

	if btn_defensoras:
		btn_defensoras.text = tr("MENU_DEFENSORAS")
		btn_defensoras.pressed.connect(_on_btn_defensoras_pressed)

	if btn_bestiario:
		btn_bestiario.text = tr("MENU_BESTIARIO")
		btn_bestiario.pressed.connect(_on_btn_bestiario_pressed)

	if btn_salir:
		btn_salir.text = tr("MENU_SALIR")
		btn_salir.pressed.connect(_on_btn_salir_pressed)

	if menu_defensoras:
		menu_defensoras.cerrado.connect(_on_menu_defensoras_cerrado)

	_cerrar_menu(false)


func _configurar_outline_mesa() -> void:
	_outline_mat = StandardMaterial3D.new()
	_outline_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	_outline_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_outline_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_outline_mat.grow = true
	_outline_mat.grow_amount = 0.005
	_outline_mat.albedo_color = Color(0.75, 0.25, 1.0, 0.0)

	# El contorno morado solo debe ser en el borde exterior del mueble, no en su interior
	# (evitando que frascos, pociones, libros y caldero tengan líneas moradas).
	var nodo_contorno := Node3D.new()
	nodo_contorno.name = "ContornoExteriorMueble"
	add_child(nodo_contorno)

	# 1. Base del mueble (cuerpo inferior de la mesa)
	var box_base := BoxMesh.new()
	box_base.size = Vector3(0.305, 0.130, 0.190)
	var mi_base := MeshInstance3D.new()
	mi_base.name = "ContornoBase"
	mi_base.mesh = box_base
	mi_base.position = Vector3(0.0, 0.065, 0.0)
	mi_base.material_override = _outline_mat
	nodo_contorno.add_child(mi_base)

	# 2. Repisa superior (estante trasero)
	var box_repisa := BoxMesh.new()
	box_repisa.size = Vector3(0.305, 0.106, 0.095)
	var mi_repisa := MeshInstance3D.new()
	mi_repisa.name = "ContornoRepisa"
	mi_repisa.mesh = box_repisa
	mi_repisa.position = Vector3(0.0, 0.183, -0.048)
	mi_repisa.material_override = _outline_mat
	nodo_contorno.add_child(mi_repisa)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player_interior") or body is CharacterBody3D:
		_jugador_cerca = true
		_animar_proximidad(true)


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player_interior") or body is CharacterBody3D:
		_jugador_cerca = false
		_animar_proximidad(false)
		_cerrar_menu(true)
		if menu_defensoras and menu_defensoras.visible:
			menu_defensoras.cerrar()


func _animar_proximidad(activo: bool) -> void:
	if _tween_efecto and _tween_efecto.is_valid():
		_tween_efecto.kill()

	_tween_efecto = create_tween().set_parallel(true)
	var duracion := 0.3 if activo else 0.25
	var target_alpha := 1.0 if activo else 0.0

	if prompt_e:
		if activo:
			prompt_e.visible = true
		_tween_efecto.tween_property(prompt_e, "modulate:a", target_alpha, duracion).set_trans(Tween.TRANS_SINE)
		_tween_efecto.tween_property(prompt_e, "outline_modulate:a", target_alpha, duracion).set_trans(Tween.TRANS_SINE)
		if not activo:
			_tween_efecto.chain().tween_callback(func():
				if not _jugador_cerca and prompt_e:
					prompt_e.visible = false
			)

	if _outline_mat:
		_tween_efecto.tween_method(
			func(alpha: float):
				_outline_mat.albedo_color = Color(0.75, 0.25, 1.0, alpha),
			_outline_mat.albedo_color.a,
			target_alpha,
			duracion
		).set_trans(Tween.TRANS_SINE)


func _unhandled_input(event: InputEvent) -> void:
	if not _jugador_cerca:
		return

	# Si algún menú está visible, dejar que los menús consuman el input
	if (menu_canvas and menu_canvas.visible) or (menu_defensoras and menu_defensoras.visible):
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.keycode == KEY_ENTER:
			_abrir_menu()
			get_viewport().set_input_as_handled()


func _abrir_menu() -> void:
	if not menu_canvas:
		return
	_set_player_movimiento(false)
	_reproducir_sfx_interaccion()
	if prompt_e:
		prompt_e.visible = false

	menu_canvas.visible = true
	if panel_menu:
		panel_menu.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(panel_menu, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)
	if btn_defensoras:
		btn_defensoras.grab_focus()


func _reproducir_sfx_interaccion() -> void:
	var stream: AudioStream = load("res://TEST_/Sonido interactuar mueble.mp3")
	if not stream:
		return
	var asp := AudioStreamPlayer.new()
	asp.stream = stream
	asp.bus = "Master"
	add_child(asp)
	asp.play()
	asp.finished.connect(asp.queue_free)


func _cerrar_menu(animado: bool = true) -> void:
	if not menu_canvas:
		return
	if animado and panel_menu:
		var tween := create_tween()
		tween.tween_property(panel_menu, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_SINE)
		await tween.finished
		if not _jugador_cerca or (menu_defensoras and menu_defensoras.visible):
			menu_canvas.visible = false
	else:
		menu_canvas.visible = false

	if not (menu_defensoras and menu_defensoras.visible):
		_set_player_movimiento(true)

	if _jugador_cerca and not (menu_defensoras and menu_defensoras.visible) and prompt_e:
		prompt_e.visible = true


func _on_btn_defensoras_pressed() -> void:
	defensoras_presionado.emit()
	_cerrar_menu(false)
	if menu_defensoras:
		menu_defensoras.abrir()


func _on_menu_defensoras_cerrado() -> void:
	if _jugador_cerca:
		_abrir_menu()
	else:
		_set_player_movimiento(true)


func _on_btn_bestiario_pressed() -> void:
	bestiario_presionado.emit()


func _on_btn_salir_pressed() -> void:
	salir_presionado.emit()
	_cerrar_menu(true)
	_set_player_movimiento(true)


func _set_player_movimiento(permitir: bool) -> void:
	var player = get_tree().get_first_node_in_group("player_interior")
	if player and "puede_moverse" in player:
		player.puede_moverse = permitir
