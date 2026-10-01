extends "res://addons/gut/test.gd"

## Tests unitarios para el NPC Veera (patrulla, espada/cola equipadas,
## proximidad con tinte morado y diálogo de 2 viñetas con [E]).
## Espejo de test_orco_cerdo_dialogo.gd: mismo funcionamiento que OrcoCerdo.
## Estructura AAA (Arrange, Act, Assert) siguiendo las directrices de AGENTS.md.

const SCRIPT_VEERA: GDScript = preload("res://Entities/NPC_Veera/Veera.gd")
const SCENE_VEERA: PackedScene = preload("res://Entities/NPC_Veera/Veera.tscn")

var _veera: Veera = null


func before_each() -> void:
	_veera = SCENE_VEERA.instantiate() as Veera
	_veera.name = "Veera texto"
	_veera.dialogo_interactivo = true
	add_child_autofree(_veera)


func after_each() -> void:
	if is_instance_valid(_veera):
		_veera.queue_free()
	_veera = null


func test_inicializacion_componentes_dialogo() -> void:
	# Arrange & Act: ya instanciado en before_each
	# Assert
	assert_not_null(_veera, "Veera debe instanciarse")
	assert_true(_veera.es_dialogo_activo(), "El diálogo debe estar activo por nombre 'texto' y flag dialogo_interactivo")
	assert_false(_veera.esta_jugador_cerca(), "Inicialmente el jugador no debe estar cerca")
	assert_false(_veera.esta_hablando_dialogo(), "Inicialmente no debe estar hablando")
	assert_eq(_veera.obtener_indice_dialogo(), 0, "El índice inicial de diálogo debe ser 0")

	var prompt: Label3D = _veera.obtener_prompt_hablar()
	assert_not_null(prompt, "Debe existir el nodo PromptHablar")
	assert_eq(prompt.billboard, BaseMaterial3D.BILLBOARD_ENABLED, "El prompt debe tener billboard activado")

	var sb: SpeechBubbleComponent = _veera.obtener_speech_bubble()
	assert_not_null(sb, "Debe existir SpeechBubbleComponent")

	assert_eq(_veera.lineas_dialogo.size(), 2, "Debe tener 2 viñetas configuradas")
	assert_eq(_veera.lineas_dialogo[0], "VEERA_PUEBLO_1", "Viñeta 1 por clave de traducción")
	assert_eq(_veera.lineas_dialogo[1], "VEERA_PUEBLO_2", "Viñeta 2 por clave de traducción")


func test_deteccion_proximidad_y_tinte_morado() -> void:
	# Arrange
	watch_signals(_veera)
	assert_false(_veera.esta_jugador_cerca())

	# Act: Simular entrada del jugador
	_veera.fijar_jugador_cerca(true)

	# Assert
	assert_signal_emitted_with_parameters(_veera, "proximidad_jugador_cambiada", [true])
	assert_true(_veera.esta_jugador_cerca(), "Debe registrar jugador cerca")

	var tinte: StandardMaterial3D = _veera.obtener_material_tinte()
	assert_not_null(tinte, "Debe haberse configurado el StandardMaterial3D de tinte")

	# Act: Simular salida del jugador
	_veera.fijar_jugador_cerca(false)

	# Assert
	assert_signal_emitted_with_parameters(_veera, "proximidad_jugador_cambiada", [false])
	assert_false(_veera.esta_jugador_cerca(), "Debe registrar que el jugador se alejó")


func test_flujo_completo_dialogo_dos_vinetas_con_e() -> void:
	# Arrange
	watch_signals(_veera)
	_veera.fijar_jugador_cerca(true)
	var prompt: Label3D = _veera.obtener_prompt_hablar()
	var sb: SpeechBubbleComponent = _veera.obtener_speech_bubble()

	# Act 1: Primer pulsado de E / interactuar
	_veera.interactuar()

	# Assert 1
	assert_true(_veera.esta_hablando_dialogo(), "Debe estar en modo diálogo activo")
	assert_eq(_veera.obtener_indice_dialogo(), 1, "Debe estar en la viñeta 1")
	assert_signal_emitted_with_parameters(_veera, "dialogo_iniciado", ["VEERA_PUEBLO_1"])
	assert_true(sb.esta_hablando(), "El SpeechBubbleComponent debe estar activo con la viñeta 1")
	assert_false(prompt.visible, "El prompt [E] Hablar debe ocultarse mientras se habla")

	# Act 2: Segundo pulsado de E / avanzar a viñeta 2
	_veera.interactuar()

	# Assert 2
	assert_true(_veera.esta_hablando_dialogo(), "Debe seguir en modo diálogo activo")
	assert_eq(_veera.obtener_indice_dialogo(), 2, "Debe estar en la viñeta 2")
	assert_signal_emitted_with_parameters(_veera, "dialogo_avanzado", [2, "VEERA_PUEBLO_2"])
	assert_true(sb.esta_hablando(), "El SpeechBubbleComponent debe seguir activo con la viñeta 2")

	# Act 3: Tercer pulsado de E / cerrar diálogo
	_veera.interactuar()

	# Assert 3
	assert_false(_veera.esta_hablando_dialogo(), "El diálogo debe cerrarse tras la última viñeta")
	assert_eq(_veera.obtener_indice_dialogo(), 0, "El índice debe reiniciarse a 0")
	assert_signal_emitted(_veera, "dialogo_terminado")
	assert_false(sb.esta_hablando(), "El SpeechBubbleComponent debe cerrarse")


func test_espada_y_cola_equipadas_y_patrulla() -> void:
	# Arrange & Act: el _ready equipa espada y cola e inicia la caminata
	# Assert
	var espada: Node3D = _veera.obtener_espada()
	assert_not_null(espada, "La espada debe estar equipada")
	assert_true(espada.visible, "La espada debe estar visible")
	var attach_espada: BoneAttachment3D = espada.get_parent() as BoneAttachment3D
	assert_not_null(attach_espada, "La espada debe colgar de un BoneAttachment3D")
	assert_eq(attach_espada.bone_name, "mixamorig_RightHand", "La espada va en la mano derecha")
	assert_ne(attach_espada.bone_idx, -1, "El bone_idx de la espada debe resolverse en runtime")

	var cola: Node3D = _veera.obtener_cola()
	assert_not_null(cola, "La cola debe estar equipada")
	assert_true(cola.visible, "La cola debe estar visible")
	var attach_cola: BoneAttachment3D = cola.get_parent() as BoneAttachment3D
	assert_not_null(attach_cola, "La cola debe colgar de un BoneAttachment3D")
	assert_eq(attach_cola.bone_name, "mixamorig_Hips", "La cola va en la cadera")
	assert_ne(attach_cola.bone_idx, -1, "El bone_idx de la cola debe resolverse en runtime")

	assert_eq(_veera.obtener_estado(), Veera.Estado.CAMINANDO, "Debe patrullar caminando al iniciar")
	assert_gt(_veera.obtener_velocidad_actual(), 0.0, "La velocidad de patrulla debe ser positiva")
