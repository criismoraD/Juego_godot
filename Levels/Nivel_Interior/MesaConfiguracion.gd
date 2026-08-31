class_name MesaConfiguracion
extends StaticBody3D

## Controlador de la Mesa de Configuración en el cuarto interior.
## - Detecta la proximidad del jugador y abre el menú negro estilizado.
## - Ofrece 3 opciones: DEFENSORAS, BESTIARIO, SALIR (con localización).

signal defensoras_presionado
signal bestiario_presionado
signal salir_presionado

@onready var area_interaccion: Area3D = $AreaInteraccion
@onready var menu_canvas: CanvasLayer = $CanvasMenu
@onready var panel_menu: Control = %PanelMenu
@onready var btn_defensoras: Button = %BtnDefensoras
@onready var btn_bestiario: Button = %BtnBestiario
@onready var btn_salir: Button = %BtnSalir

var _jugador_cerca: bool = false


func _ready() -> void:
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

	_cerrar_menu(false)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player_interior") or body is CharacterBody3D:
		_jugador_cerca = true
		_abrir_menu()


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player_interior") or body is CharacterBody3D:
		_jugador_cerca = false
		_cerrar_menu(true)


func _abrir_menu() -> void:
	if not menu_canvas:
		return
	menu_canvas.visible = true
	if panel_menu:
		panel_menu.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(panel_menu, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)
	if btn_defensoras:
		btn_defensoras.grab_focus()


func _cerrar_menu(animado: bool = true) -> void:
	if not menu_canvas:
		return
	if animado and panel_menu:
		var tween := create_tween()
		tween.tween_property(panel_menu, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_SINE)
		await tween.finished
		if not _jugador_cerca:
			menu_canvas.visible = false
	else:
		menu_canvas.visible = false


func _on_btn_defensoras_pressed() -> void:
	defensoras_presionado.emit()


func _on_btn_bestiario_pressed() -> void:
	bestiario_presionado.emit()


func _on_btn_salir_pressed() -> void:
	salir_presionado.emit()
	_cerrar_menu(true)
