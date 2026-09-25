extends "res://addons/gut/test.gd"

var JefeScript = load("res://Levels/Rio_En_Canoa_Con_Parallax/JefeSubmarinoRio.gd")
var SubmarinoNormalScript = load("res://Levels/Rio_En_Canoa_Con_Parallax/SubmarinoRio.gd")
var UIVidaJefeScript = load("res://UI/UIVidaJefe.gd")

var _ui: CanvasLayer = null
var _jefe = null


func before_each() -> void:
	_jefe = JefeScript.new()
	get_tree().root.add_child(_jefe)
	_ui = UIVidaJefeScript.new()
	get_tree().root.add_child(_ui)


func after_each() -> void:
	if is_instance_valid(_ui):
		if _ui.get_parent():
			_ui.get_parent().remove_child(_ui)
		_ui.free()
	_ui = null

	if is_instance_valid(_jefe):
		if _jefe.get_parent():
			_jefe.get_parent().remove_child(_jefe)
		_jefe.free()
	_jefe = null


func test_barra_vida_oculta_al_inicio() -> void:
	# Arrange: el jefe está sumergido y no en combate al cargar la escena
	# Act: la UI ya se conectó al jefe en _ready
	var contenedor: Control = _ui.get_node_or_null("ContenedorVidaJefe") as Control

	# Assert: la barra debe iniciar oculta antes de llegar al jefe
	assert_not_null(contenedor, "El contenedor de la UI debe existir")
	assert_false(contenedor.visible, "La barra de vida debe estar oculta mientras el jefe está sumergido")
	assert_false(_jefe.combate_activo, "El combate no debe estar activo al iniciar")


func test_barra_vida_aparece_al_emerger_jefe() -> void:
	# Arrange: jefe sumergido y UI conectada pero oculta
	var contenedor: Control = _ui.get_node_or_null("ContenedorVidaJefe") as Control
	assert_false(contenedor.visible, "Inicia oculta")

	# Act: el jefe inicia su emergencia (inicia el combate)
	_jefe.emerger()

	# Assert: emite combate_iniciado y la UI se hace visible
	assert_true(_jefe.combate_activo, "El jefe marca combate_activo = true")
	assert_true(contenedor.visible, "La barra de vida se muestra al iniciar el combate con el jefe")


func test_submarino_normal_no_muestra_barra_jefe() -> void:
	# Arrange: UI oculta y un submarino normal (que no es el jefe)
	var contenedor: Control = _ui.get_node_or_null("ContenedorVidaJefe") as Control
	var submarino_normal = SubmarinoNormalScript.new()
	get_tree().root.add_child(submarino_normal)

	# Act: el submarino normal emerge
	submarino_normal.emerger()

	# Assert: la barra de vida del jefe debe seguir oculta
	assert_false(contenedor.visible, "El submarino normal no debe mostrar la barra de vida del jefe")
	submarino_normal.free()


func test_barra_vida_se_oculta_al_derrotar_al_jefe() -> void:
	# Arrange: jefe en combate en superficie
	var contenedor: Control = _ui.get_node_or_null("ContenedorVidaJefe") as Control
	_jefe.emerger()
	_jefe.current_state = 2  # EN_SUPERFICIE
	_jefe._altura_objetivo_y = 12.0
	assert_true(contenedor.visible, "La barra está visible durante el combate")

	# Act: el jefe recibe daño letal y muere
	_jefe.take_damage(43.0)

	# Assert: la barra se oculta al morir el jefe
	assert_false(contenedor.visible, "La barra de vida se oculta al derrotar al jefe submarino")
	assert_false(_jefe.combate_activo, "combate_activo se desactiva al morir")
