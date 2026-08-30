extends "res://addons/gut/test.gd"

## Tests unitarios para el sistema de globos de diálogo (SpeechBubbleComponent & UI).
## Sigue la estructura AAA (Arrange, Act, Assert) y las normas de AGENTS.md.

var SpeechBubbleComponentScript = load("res://Components/Dialogue/SpeechBubbleComponent.gd")
var SpeechBubbleUIScript = load("res://Components/Dialogue/SpeechBubbleUI.gd")
var AllyArcherScript = load("res://Entities/Aliada_Arquera/AllyArcher.gd")

var _component: SpeechBubbleComponent = null
var _node: Node3D = null


func before_each():
	_node = Node3D.new()
	get_tree().root.add_child(_node)
	_component = SpeechBubbleComponentScript.new()
	_node.add_child(_component)


func after_each():
	if is_instance_valid(_node):
		_node.queue_free()
	_node = null
	_component = null


func test_inicializacion_componente():
	# Arrange & Act: _component creado en before_each
	# Assert
	assert_not_null(_component, "El componente debe instanciarse correctamente")
	assert_eq(_component.offset_cabeza, Vector3(0.0, 2.2, 0.0), "El offset por defecto de la cabeza debe ser (0, 2.2, 0)")
	assert_false(_component.esta_hablando(), "No debe estar hablando inicialmente")


func test_decir_inicia_dialogo():
	# Arrange
	watch_signals(_component)

	# Act
	_component.decir("DIALOGO_ARQUERA_ARRIBA_HOLA", 2.0)

	# Assert
	assert_signal_emitted(_component, "dialogo_iniciado", "Debe emitir la señal dialogo_iniciado")
	assert_true(_component.esta_hablando(), "El componente debe reportar esta_hablando() == true")


func test_ocultar_dialogo():
	# Arrange
	_component.decir("Texto de prueba", 5.0)
	assert_true(_component.esta_hablando(), "Debe estar hablando antes de ocultar")

	# Act
	_component.ocultar()

	# Assert
	assert_false(_component.esta_hablando(), "Debe dejar de hablar al llamar ocultar()")


func test_traduccion_clave():
	# Arrange
	var ui_scene: PackedScene = load("res://Components/Dialogue/SpeechBubbleUI.tscn")
	var ui: SpeechBubbleUI = ui_scene.instantiate() as SpeechBubbleUI
	get_tree().root.add_child(ui)

	# Act: Mostrar clave de traducción de arriba
	ui.mostrar_dialogo("DIALOGO_ARQUERA_ARRIBA_HOLA", 1.0)
	assert_eq(ui.label_texto.text, "[center]%s[/center]" % tr("DIALOGO_ARQUERA_ARRIBA_HOLA"), "El texto mostrado debe coincidir con la traducción centrada")

	# Act: Mostrar clave de traducción de abajo
	ui.mostrar_dialogo("DIALOGO_ARQUERA_ABAJO_TEST", 1.0)
	assert_eq(ui.label_texto.text, "[center]%s[/center]" % tr("DIALOGO_ARQUERA_ABAJO_TEST"), "El texto mostrado debe coincidir con la traducción centrada")

	# Cleanup
	ui.queue_free()


func test_arquera_integra_speech_bubble():
	# Arrange
	var archer: AllyArcher = AllyArcherScript.new()
	var comp: SpeechBubbleComponent = SpeechBubbleComponentScript.new()
	comp.name = "SpeechBubbleComponent"
	archer.add_child(comp)
	get_tree().root.add_child(archer)

	# Act
	archer.decir("DIALOGO_ARQUERA_ARRIBA_HOLA", 1.0)

	# Assert
	assert_true(archer.esta_hablando(), "La arquera debe estar hablando mediante su componente integrado")

	# Cleanup
	archer.queue_free()


func test_dos_arqueras_independientes():
	# Arrange: Crear dos arqueras con configuraciones distintas
	var archer1: AllyArcher = AllyArcherScript.new()
	var comp1: SpeechBubbleComponent = SpeechBubbleComponentScript.new()
	comp1.name = "SpeechBubbleComponent"
	comp1.pitch_voz = 1.2
	archer1.add_child(comp1)
	get_tree().root.add_child(archer1)

	var archer2: AllyArcher = AllyArcherScript.new()
	var comp2: SpeechBubbleComponent = SpeechBubbleComponentScript.new()
	comp2.name = "SpeechBubbleComponent"
	comp2.pitch_voz = 0.8
	archer2.add_child(comp2)
	get_tree().root.add_child(archer2)

	# Act: Solo la arquera 1 habla
	archer1.decir("DIALOGO_ARQUERA_ARRIBA_HOLA", 2.0)

	# Assert: Cada arquera mantiene su estado y propiedades de forma independiente
	assert_true(archer1.esta_hablando(), "Arquera 1 debe estar hablando")
	assert_false(archer2.esta_hablando(), "Arquera 2 no debe estar hablando cuando solo habla arquera 1")
	assert_almost_eq(comp1.pitch_voz, 1.2, 0.01, "Arquera 1 debe mantener su pitch de 1.2")
	assert_almost_eq(comp2.pitch_voz, 0.8, 0.01, "Arquera 2 debe mantener su pitch de 0.8")

	# Cleanup
	archer1.queue_free()
	archer2.queue_free()
