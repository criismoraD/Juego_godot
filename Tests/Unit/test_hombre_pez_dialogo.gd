extends "res://addons/gut/test.gd"

## Tests unitarios para el sistema de diálogo interactivo, iluminación morada,
## giro hacia el jugador y viñetas de HombrePez.
## Estructura AAA (Arrange, Act, Assert) siguiendo AGENTS.md.

const SCENE_HOMBRE_PEZ: PackedScene = preload("res://Entities/Ambiente_HombrePez/HombrePez.tscn")
const SCENE_PUEBLO: PackedScene = preload("res://Levels/Nivel_Pueblo/NivelPueblo.tscn")

var _pez: HombrePez = null


func before_each() -> void:
	_pez = SCENE_HOMBRE_PEZ.instantiate() as HombrePez
	add_child_autofree(_pez)


func after_each() -> void:
	if is_instance_valid(_pez):
		_pez.queue_free()
	_pez = null


func test_inicializacion_componentes_dialogo() -> void:
	# Arrange & Act (instanciado en before_each)
	# Assert
	assert_not_null(_pez, "HombrePez debe instanciarse")
	assert_true(_pez.es_dialogo_activo(), "El diálogo interactivo debe estar habilitado por defecto")
	assert_false(_pez.esta_jugador_cerca(), "Inicialmente el jugador no debe estar cerca")
	assert_false(_pez.esta_hablando_dialogo(), "Inicialmente no debe estar hablando")
	assert_eq(_pez.obtener_indice_dialogo(), 0, "El índice inicial de diálogo debe ser 0")

	var prompt: Label3D = _pez.obtener_prompt_hablar()
	assert_not_null(prompt, "Debe existir el nodo PromptHablar")
	assert_eq(prompt.text, "[E] " + tr("PERRENA_PROMPT_HABLAR"), "El prompt debe usar la clave traducida")
	assert_eq(prompt.billboard, BaseMaterial3D.BILLBOARD_ENABLED, "El prompt debe tener billboard activado")

	var sb: SpeechBubbleComponent = _pez.obtener_speech_bubble()
	assert_not_null(sb, "Debe existir SpeechBubbleComponent")
	assert_gt(sb.offset_cabeza.y, 0.5, "El offset de cabeza debe ser mayor a 0.5m")

	assert_eq(_pez.lineas_dialogo.size(), 2, "Debe tener 2 viñetas configuradas")
	assert_eq(_pez.lineas_dialogo[0], "HOMBREPEZ_PUEBLO_1", "Viñeta 1 debe ser clave de traducción")
	assert_eq(_pez.lineas_dialogo[1], "HOMBREPEZ_PUEBLO_2", "Viñeta 2 debe ser clave de traducción")
	assert_ne(tr("HOMBREPEZ_PUEBLO_1"), "HOMBREPEZ_PUEBLO_1", "HOMBREPEZ_PUEBLO_1 debe resolverse en el locale activo")
	assert_ne(tr("HOMBREPEZ_PUEBLO_2"), "HOMBREPEZ_PUEBLO_2", "HOMBREPEZ_PUEBLO_2 debe resolverse en el locale activo")


func test_deteccion_proximidad_y_tinte_morado() -> void:
	# Arrange
	watch_signals(_pez)
	assert_false(_pez.esta_jugador_cerca())

	# Act: Simular entrada del jugador
	_pez.fijar_jugador_cerca(true)

	# Assert
	assert_signal_emitted_with_parameters(_pez, "proximidad_jugador_cambiada", [true])
	assert_true(_pez.esta_jugador_cerca(), "Debe registrar jugador cerca")

	var tinte: StandardMaterial3D = _pez.obtener_material_tinte()
	assert_not_null(tinte, "Debe haberse configurado el StandardMaterial3D de tinte")
	assert_eq(tinte.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, "El tinte debe ser unshaded")
	assert_eq(tinte.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA, "El tinte debe tener transparencia alpha")
	assert_almost_eq(tinte.albedo_color.r, 0.78, 0.01, "El canal R debe ser morado (~0.78)")
	assert_almost_eq(tinte.albedo_color.g, 0.48, 0.01, "El canal G debe ser morado (~0.48)")
	assert_almost_eq(tinte.albedo_color.b, 0.95, 0.01, "El canal B debe ser morado (~0.95)")

	# Act 2: Simular salida del jugador
	_pez.fijar_jugador_cerca(false)

	# Assert 2
	assert_signal_emitted_with_parameters(_pez, "proximidad_jugador_cambiada", [false])
	assert_false(_pez.esta_jugador_cerca(), "Debe registrar que el jugador se alejó")


func test_flujo_completo_dialogo_dos_vinetas() -> void:
	# Arrange
	watch_signals(_pez)
	_pez.fijar_jugador_cerca(true)
	var prompt: Label3D = _pez.obtener_prompt_hablar()
	var sb: SpeechBubbleComponent = _pez.obtener_speech_bubble()

	# Act 1: Primer pulsado de E / interactuar
	_pez.interactuar()

	# Assert 1
	assert_true(_pez.esta_hablando_dialogo(), "Debe estar en modo diálogo activo")
	assert_eq(_pez.obtener_indice_dialogo(), 1, "Debe estar en la viñeta 1")
	assert_signal_emitted_with_parameters(_pez, "dialogo_iniciado", ["HOMBREPEZ_PUEBLO_1"])
	assert_true(sb.esta_hablando(), "El SpeechBubbleComponent debe estar activo con la viñeta 1")
	assert_false(prompt.visible, "El prompt [E] Hablar debe ocultarse mientras se habla")

	# Act 2: Segundo pulsado de E / avanzar a viñeta 2
	_pez.interactuar()

	# Assert 2
	assert_true(_pez.esta_hablando_dialogo(), "Debe seguir en modo diálogo activo")
	assert_eq(_pez.obtener_indice_dialogo(), 2, "Debe estar en la viñeta 2")
	assert_signal_emitted_with_parameters(_pez, "dialogo_avanzado", [2, "HOMBREPEZ_PUEBLO_2"])
	assert_true(sb.esta_hablando(), "El SpeechBubbleComponent debe seguir activo con la viñeta 2")

	# Act 3: Tercer pulsado de E / cerrar diálogo
	_pez.interactuar()

	# Assert 3
	assert_false(_pez.esta_hablando_dialogo(), "El diálogo debe cerrarse tras la última viñeta")
	assert_eq(_pez.obtener_indice_dialogo(), 0, "El índice debe reiniciarse a 0")
	assert_signal_emitted(_pez, "dialogo_terminado")
	assert_false(sb.esta_hablando(), "El SpeechBubbleComponent debe cerrarse")
	assert_true(prompt.visible, "El prompt [E] Hablar debe volver a ser visible si el jugador sigue cerca")


func test_hombre_pez_mantiene_orientacion_fija_sin_giro() -> void:
	# Arrange: Jugador ubicado a su derecha (+X)
	var rot_base: float = _pez.obtener_rotacion_base_modelo()

	var dummy_jugador := Node3D.new()
	dummy_jugador.name = "Player"
	dummy_jugador.add_to_group("player")
	add_child_autofree(dummy_jugador)
	dummy_jugador.global_position = _pez.global_position + Vector3(2.0, 0.0, 0.0)

	_pez.fijar_jugador_cerca(true)

	# Act 1: Iniciar diálogo
	_pez.interactuar()

	# Assert 1: HombrePez debe permanecer mirando en su orientación fija original
	assert_almost_eq(_pez.modelo.rotation_degrees.y, rot_base, 0.01, "HombrePez debe mantenerse en su orientación fija sin girarse")

	# Act 2: Avanzar viñeta
	_pez.interactuar()  # viñeta 2
	assert_almost_eq(_pez.modelo.rotation_degrees.y, rot_base, 0.01, "En viñeta 2 debe mantener la misma orientación")

	# Act 3: Intentar orientar manualmente
	_pez.orientar_hacia_jugador(false)
	assert_almost_eq(_pez.modelo.rotation_degrees.y, rot_base, 0.01, "HombrePez no debe cambiar de orientación al llamar orientar_hacia_jugador")

	# Act 4: Cerrar diálogo
	_pez.interactuar()  # cerrar
	assert_almost_eq(_pez.modelo.rotation_degrees.y, rot_base, 0.01, "Al cerrar diálogo la orientación debe seguir idéntica")


func test_deteccion_en_distinto_plano_de_profundidad_z() -> void:
	# Arrange: HombrePez en Z=1.17, Jugador en el plano de caminata Z=3.5 (diferencia de 2.33m en Z)
	_pez.global_position = Vector3(0.8, 0.6, 1.17)

	var dummy_jugador := Node3D.new()
	dummy_jugador.name = "Player"
	dummy_jugador.add_to_group("player")
	add_child_autofree(dummy_jugador)
	# Jugador parado exactamente frente a él en X (X=0.8), pero en el plano Z=3.5
	dummy_jugador.global_position = Vector3(0.8, 0.57, 3.5)

	# Act: Procesar proximidad
	_pez._procesar_proximidad_jugador(0.016)

	# Assert: Debe detectarlo como cerca porque está delante de él en X
	assert_true(_pez.esta_jugador_cerca(), "Debe detectar al jugador estando delante de él a pesar del plano Z diferente")

	# Act 2: Jugador se aleja en el eje X (X=4.0) manteniéndose en Z=3.5
	dummy_jugador.global_position = Vector3(4.0, 0.57, 3.5)
	_pez._procesar_proximidad_jugador(0.016)

	# Assert 2: Ya no debe estar cerca
	assert_false(_pez.esta_jugador_cerca(), "Al alejarse en X debe dejar de estar cerca")


func test_respiracion_durante_dialogo() -> void:
	# Arrange
	_pez.fijar_jugador_cerca(true)
	_pez.interactuar()
	assert_true(_pez.esta_hablando_dialogo())

	# Act: Ejecutar varios frames de _process
	var y_inicial: float = _pez.modelo.scale.y
	_pez._process(0.8)

	# Assert: La respiración procedural debe seguir activa y modulando la escala
	assert_gt(_pez.modelo.scale.y, 0.0, "La escala del modelo debe ser positiva y válida")


func test_hombre_pez_en_nivel_pueblo() -> void:
	# Arrange & Act: Cargar NivelPueblo
	var pueblo: Node = SCENE_PUEBLO.instantiate()
	add_child_autofree(pueblo)

	var npc: HombrePez = pueblo.find_child("HombrePez", true, false) as HombrePez

	# Assert
	assert_not_null(npc, "HombrePez debe existir en NivelPueblo.tscn")
	assert_true(npc.es_dialogo_activo(), "Debe tener el diálogo activo en pueblo")
	assert_eq(npc.lineas_dialogo[0], "HOMBREPEZ_PUEBLO_1", "Viñeta 1 en pueblo debe ser clave de traducción")
	assert_eq(npc.lineas_dialogo[1], "HOMBREPEZ_PUEBLO_2", "Viñeta 2 en pueblo debe ser clave de traducción")
