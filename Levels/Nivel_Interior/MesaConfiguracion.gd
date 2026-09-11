class_name MesaConfiguracion
extends StaticBody3D

## Controlador de la Mesa de Configuración en el cuarto interior.
## - Detecta la proximidad del jugador, animando un borde morado y el prompt "E".
## - Al presionar E abre el menú con opciones: DEFENSORAS, BESTIARIO, SALIR.
## - Conecta con el Menú Minimalista de Defensoras para configurar las aliadas.

signal defensoras_presionado
signal bestiario_presionado
signal salir_presionado

const MenuBestiarioClass = preload("res://UI/MenuBestiario/MenuBestiario.gd")

@onready var area_interaccion: Area3D = $AreaInteraccion
@onready var menu_canvas: CanvasLayer = $CanvasMenu
@onready var panel_menu: Control = %PanelMenu
@onready var btn_defensoras: Button = %BtnDefensoras
@onready var btn_bestiario: Button = %BtnBestiario
@onready var btn_salir: Button = %BtnSalir
@onready var prompt_e: Label3D = %PromptE
@onready var menu_defensoras: MenuDefensoras = %MenuDefensoras
@onready var menu_bestiario: MenuBestiarioClass = %MenuBestiario

var _jugador_cerca: bool = false
var _tint_mat: StandardMaterial3D = null
var _tween_efecto: Tween = null
var _opcion_foco: int = 0
var _botones_menu: Array[Button] = []


func _ready() -> void:
	_configurar_tinte_mueble()

	if prompt_e:
		prompt_e.text = "[E] " + tr("PROMPT_INTERACTUAR")
		prompt_e.modulate = Color(1.0, 1.0, 1.0, 0.0)
		prompt_e.outline_modulate = Color(0.05, 0.05, 0.08, 0.0)
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

	## Hover = normal y el foco es el único resaltado: el ratón no pinta
	## su propia marca (toma el foco en mouse_entered), así nunca hay dos
	## opciones marcadas; manda el último input usado.
	for par in [
		[btn_defensoras, 0],
		[btn_bestiario, 1],
		[btn_salir, 2],
	]:
		var boton := par[0] as Button
		if boton == null:
			continue
		boton.add_theme_stylebox_override("hover", boton.get_theme_stylebox("normal"))
		boton.mouse_entered.connect(_on_mouse_entra_opcion_menu.bind(boton))
		boton.focus_entered.connect(_on_foco_opcion_menu.bind(par[1]))
		_botones_menu.append(boton)

	if menu_defensoras:
		menu_defensoras.cerrado.connect(_on_menu_defensoras_cerrado)

	if menu_bestiario:
		menu_bestiario.cerrado.connect(_on_menu_bestiario_cerrado)

	_cerrar_menu(false)


func _configurar_tinte_mueble() -> void:
	# El mueble cambia sutilmente de color a un tono morado claro con transparencia
	# al interactuar con él (sin líneas de contorno).
	_tint_mat = StandardMaterial3D.new()
	_tint_mat.cull_mode = BaseMaterial3D.CULL_BACK
	_tint_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tint_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_tint_mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	_tint_mat.albedo_color = Color(0.78, 0.48, 0.95, 0.0)

	var model_node: Node = get_node_or_null("Model")
	if model_node:
		var meshes: Array[MeshInstance3D] = _obtener_mesh_instances(model_node)
		for mi in meshes:
			mi.material_overlay = _tint_mat


func _obtener_mesh_instances(nodo: Node) -> Array[MeshInstance3D]:
	var lista: Array[MeshInstance3D] = []
	if nodo is MeshInstance3D:
		lista.append(nodo)
	for hijo in nodo.get_children():
		lista.append_array(_obtener_mesh_instances(hijo))
	return lista


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
		if menu_bestiario and menu_bestiario.visible:
			menu_bestiario.cerrar()
		_set_player_movimiento(true)


func _animar_proximidad(activo: bool) -> void:
	if _tween_efecto and _tween_efecto.is_valid():
		_tween_efecto.kill()

	_tween_efecto = create_tween().set_parallel(true)
	var duracion := 0.3 if activo else 0.25
	var target_alpha := 1.0 if activo else 0.0
	var tint_target_alpha := 0.22 if activo else 0.0

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

	if _tint_mat:
		_tween_efecto.tween_method(
			func(alpha: float):
				_tint_mat.albedo_color = Color(0.78, 0.48, 0.95, alpha),
			_tint_mat.albedo_color.a,
			tint_target_alpha,
			duracion
		).set_trans(Tween.TRANS_SINE)


func _unhandled_input(event: InputEvent) -> void:
	if not _jugador_cerca:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		# Con el menú propio abierto: W/S navega, E activa, ESC sale
		# (los submenús de defensoras/bestiario consumen su propio input).
		if menu_canvas and menu_canvas.visible and not _otro_submenu_abierto():
			match event.keycode:
				KEY_W, KEY_UP:
					_mover_foco(-1)
					get_viewport().set_input_as_handled()
				KEY_S, KEY_DOWN:
					_mover_foco(1)
					get_viewport().set_input_as_handled()
				KEY_E, KEY_ENTER:
					_activar_foco()
					get_viewport().set_input_as_handled()
				KEY_ESCAPE:
					_cerrar_menu(true)
					get_viewport().set_input_as_handled()
			return
		# Si algún submenú está visible, dejar que consuman su input
		if _otro_submenu_abierto():
			return

		if event.keycode == KEY_E or event.keycode == KEY_ENTER:
			_abrir_menu()
			get_viewport().set_input_as_handled()


## True si defensoras o bestiario están abiertos (ellos gestionan su
## propio input).
func _otro_submenu_abierto() -> bool:
	return (menu_defensoras and menu_defensoras.visible) or (menu_bestiario and menu_bestiario.visible)


## Navegación W/S con vuelta al llegar al extremo, como el menú de la torre.
func _mover_foco(direccion: int) -> void:
	if _botones_menu.is_empty():
		return
	_opcion_foco = wrapi(_opcion_foco + direccion, 0, _botones_menu.size())
	_botones_menu[_opcion_foco].grab_focus()


## Activa con E/ENTER la opción con foco (el ratón sigue igual).
func _activar_foco() -> void:
	if _botones_menu.is_empty():
		return
	_botones_menu[_opcion_foco].emit_signal("pressed")


func _abrir_menu() -> void:
	if not menu_canvas:
		return
	_set_player_movimiento(false)
	AudioManager.play_sfx("seleccion_menu")
	if prompt_e:
		prompt_e.visible = false

	menu_canvas.visible = true
	if panel_menu:
		panel_menu.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(panel_menu, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)
	_opcion_foco = 0
	if btn_defensoras:
		btn_defensoras.grab_focus()


func _cerrar_menu(animado: bool = true) -> void:
	if not menu_canvas:
		return
	var otro_menu_abierto: bool = (menu_defensoras and menu_defensoras.visible) or (menu_bestiario and menu_bestiario.visible)
	if animado and panel_menu:
		var tween := create_tween()
		tween.tween_property(panel_menu, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_SINE)
		await tween.finished
		if not _jugador_cerca or otro_menu_abierto:
			menu_canvas.visible = false
	else:
		menu_canvas.visible = false

	if not otro_menu_abierto:
		_set_player_movimiento(true)

	if _jugador_cerca and not otro_menu_abierto and prompt_e:
		prompt_e.visible = true


func _on_btn_defensoras_pressed() -> void:
	AudioManager.play_sfx("seleccion_menu")
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
	AudioManager.play_sfx("seleccion_menu")
	bestiario_presionado.emit()
	_cerrar_menu(false)
	if menu_bestiario:
		menu_bestiario.abrir()


func _on_menu_bestiario_cerrado() -> void:
	if _jugador_cerca:
		_abrir_menu()
	else:
		_set_player_movimiento(true)


func _on_btn_salir_pressed() -> void:
	AudioManager.play_sfx("seleccion_menu")
	salir_presionado.emit()
	_cerrar_menu(true)
	_set_player_movimiento(true)


## El ratón selecciona al entrar en una opción (le roba el foco al
## teclado): una sola marca a la vez; manda el último input usado.
func _on_mouse_entra_opcion_menu(boton: Button) -> void:
	if not _jugador_cerca or not (menu_canvas and menu_canvas.visible):
		return
	boton.grab_focus()


func _on_foco_opcion_menu(indice: int) -> void:
	_opcion_foco = indice


func _set_player_movimiento(permitir: bool) -> void:
	var player = get_tree().get_first_node_in_group("player_interior")
	if player and "puede_moverse" in player:
		player.puede_moverse = permitir
