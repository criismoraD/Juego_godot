extends "res://addons/gut/test.gd"

## Tests unitarios para el sistema de interacción, iluminación morada y diálogo de OrcoCerdo.
## Estructura AAA (Arrange, Act, Assert) siguiendo las directrices de AGENTS.md.

const SCRIPT_ORCO: GDScript = preload("res://Entities/NPC_OrcoCerdo/OrcoCerdo.gd")
const SCENE_ORCO: PackedScene = preload("res://Entities/NPC_OrcoCerdo/OrcoCerdo.tscn")
const SCENE_PUEBLO: PackedScene = preload("res://Levels/Nivel_Pueblo/NivelPueblo.tscn")

var _orco: OrcoCerdo = null


func before_each() -> void:
	_orco = SCENE_ORCO.instantiate() as OrcoCerdo
	_orco.name = "OrcoCerdo texto"
	_orco.dialogo_interactivo = true
	add_child_autofree(_orco)


func after_each() -> void:
	if is_instance_valid(_orco):
		_orco.queue_free()
	_orco = null


func test_inicializacion_componentes_dialogo() -> void:
	# Arrange & Act: ya instanciado en before_each
	# Assert
	assert_not_null(_orco, "OrcoCerdo debe instanciarse")
	assert_true(_orco.es_dialogo_activo(), "El diálogo debe estar activo por nombre 'texto' y flag dialogo_interactivo")
	assert_false(_orco.esta_jugador_cerca(), "Inicialmente el jugador no debe estar cerca")
	assert_false(_orco.esta_hablando_dialogo(), "Inicialmente no debe estar hablando")
	assert_eq(_orco.obtener_indice_dialogo(), 0, "El índice inicial de diálogo debe ser 0")

	var prompt: Label3D = _orco.obtener_prompt_hablar()
	assert_not_null(prompt, "Debe existir el nodo PromptHablar")
	assert_eq(prompt.text, "[E] " + tr("PERRENA_PROMPT_HABLAR"), "El prompt debe usar la clave traducida")
	assert_eq(prompt.billboard, BaseMaterial3D.BILLBOARD_ENABLED, "El prompt debe tener billboard activado")

	var sb: SpeechBubbleComponent = _orco.obtener_speech_bubble()
	assert_not_null(sb, "Debe existir SpeechBubbleComponent")
	assert_gt(sb.offset_cabeza.y, 0.5, "El offset de cabeza debe ser mayor a 0.5m sobre los pies")

	assert_eq(_orco.lineas_dialogo.size(), 2, "Debe tener 2 viñetas configuradas")
	assert_eq(_orco.lineas_dialogo[0], "ORCO_PUEBLO_1", "Viñeta 1 debe ser clave de traducción")
	assert_eq(_orco.lineas_dialogo[1], "ORCO_PUEBLO_2", "Viñeta 2 debe ser clave de traducción")
	assert_ne(tr("ORCO_PUEBLO_1"), "ORCO_PUEBLO_1", "ORCO_PUEBLO_1 debe resolverse en el locale activo")
	assert_ne(tr("ORCO_PUEBLO_2"), "ORCO_PUEBLO_2", "ORCO_PUEBLO_2 debe resolverse en el locale activo")


func test_deteccion_proximidad_y_tinte_morado() -> void:
	# Arrange
	watch_signals(_orco)
	assert_false(_orco.esta_jugador_cerca())

	# Act: Simular entrada del jugador
	_orco.fijar_jugador_cerca(true)

	# Assert
	assert_signal_emitted_with_parameters(_orco, "proximidad_jugador_cambiada", [true])
	assert_true(_orco.esta_jugador_cerca(), "Debe registrar jugador cerca")

	var tinte: StandardMaterial3D = _orco.obtener_material_tinte()
	assert_not_null(tinte, "Debe haberse configurado el StandardMaterial3D de tinte")
	assert_eq(tinte.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, "El tinte debe ser unshaded")
	assert_eq(tinte.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA, "El tinte debe tener transparencia alpha")
	assert_almost_eq(tinte.albedo_color.r, 0.78, 0.01, "El canal R debe ser morado (~0.78)")
	assert_almost_eq(tinte.albedo_color.g, 0.48, 0.01, "El canal G debe ser morado (~0.48)")
	assert_almost_eq(tinte.albedo_color.b, 0.95, 0.01, "El canal B debe ser morado (~0.95)")

	# Act: Simular salida del jugador
	_orco.fijar_jugador_cerca(false)

	# Assert
	assert_signal_emitted_with_parameters(_orco, "proximidad_jugador_cambiada", [false])
	assert_false(_orco.esta_jugador_cerca(), "Debe registrar que el jugador se alejó")


func test_flujo_completo_dialogo_dos_vinetas_con_e() -> void:
	# Arrange
	watch_signals(_orco)
	_orco.fijar_jugador_cerca(true)
	var prompt: Label3D = _orco.obtener_prompt_hablar()
	var sb: SpeechBubbleComponent = _orco.obtener_speech_bubble()

	# Act 1: Primer pulsado de E / interactuar
	_orco.interactuar()

	# Assert 1
	assert_true(_orco.esta_hablando_dialogo(), "Debe estar en modo diálogo activo")
	assert_eq(_orco.obtener_indice_dialogo(), 1, "Debe estar en la viñeta 1")
	assert_signal_emitted_with_parameters(_orco, "dialogo_iniciado", ["ORCO_PUEBLO_1"])
	assert_true(sb.esta_hablando(), "El SpeechBubbleComponent debe estar activo con la viñeta 1")
	assert_false(prompt.visible, "El prompt [E] Hablar debe ocultarse mientras se habla")

	# Act 2: Segundo pulsado de E / avanzar a viñeta 2
	_orco.interactuar()

	# Assert 2
	assert_true(_orco.esta_hablando_dialogo(), "Debe seguir en modo diálogo activo")
	assert_eq(_orco.obtener_indice_dialogo(), 2, "Debe estar en la viñeta 2")
	assert_signal_emitted_with_parameters(_orco, "dialogo_avanzado", [2, "ORCO_PUEBLO_2"])
	assert_true(sb.esta_hablando(), "El SpeechBubbleComponent debe seguir activo con la viñeta 2")

	# Act 3: Tercer pulsado de E / cerrar diálogo
	_orco.interactuar()

	# Assert 3
	assert_false(_orco.esta_hablando_dialogo(), "El diálogo debe cerrarse tras la última viñeta")
	assert_eq(_orco.obtener_indice_dialogo(), 0, "El índice debe reiniciarse a 0")
	assert_signal_emitted(_orco, "dialogo_terminado")
	assert_false(sb.esta_hablando(), "El SpeechBubbleComponent debe cerrarse")
	assert_true(prompt.visible, "El prompt [E] Hablar debe volver a ser visible si el jugador sigue cerca")


func test_alejarse_durante_dialogo_cierra_y_reinicia() -> void:
	# Arrange
	_orco.fijar_jugador_cerca(true)
	_orco.interactuar()
	assert_true(_orco.esta_hablando_dialogo())
	assert_eq(_orco.obtener_indice_dialogo(), 1)

	# Act: El jugador se aleja mientras el NPC está hablando
	_orco.fijar_jugador_cerca(false)

	# Assert
	assert_false(_orco.esta_hablando_dialogo(), "El diálogo debe cerrarse al alejarse")
	assert_eq(_orco.obtener_indice_dialogo(), 0, "El índice debe reiniciarse a 0")


func test_autoavance_al_terminar_duracion_vineta() -> void:
	# Arrange
	_orco.fijar_jugador_cerca(true)
	_orco.interactuar()
	assert_eq(_orco.obtener_indice_dialogo(), 1)

	# Act: Se simula la señal dialogo_terminado de la viñeta 1 (timeout del speech bubble)
	_orco.call("_on_speech_bubble_dialogo_terminado")

	# Assert: Debe auto-avanzar a la viñeta 2
	assert_eq(_orco.obtener_indice_dialogo(), 2, "Debe auto-avanzar a la viñeta 2")
	assert_true(_orco.esta_hablando_dialogo(), "Debe seguir hablando en la viñeta 2")

	# Act: Se simula la señal dialogo_terminado de la viñeta 2 (última)
	_orco.call("_on_speech_bubble_dialogo_terminado")

	# Assert: Debe cerrarse
	assert_false(_orco.esta_hablando_dialogo(), "Debe cerrarse tras agotar la última viñeta")
	assert_eq(_orco.obtener_indice_dialogo(), 0, "El índice debe volver a 0")


func test_pausa_y_reanuda_caminata_al_dialogar() -> void:
	# Arrange
	_orco.configurar_patrulla(6.0, 2.0)
	_orco.iniciar_caminata()
	assert_eq(_orco.obtener_estado(), SCRIPT_ORCO.Estado.CAMINANDO)
	var ap: AnimationPlayer = _orco.obtener_animation_player()
	assert_not_null(ap, "Debe existir AnimationPlayer")
	assert_true(ap.is_playing(), "AnimationPlayer debe estar reproduciéndose al caminar")

	_orco.fijar_jugador_cerca(true)

	# Act: Iniciar diálogo mientras caminaba
	_orco.interactuar()

	# Assert: La velocidad debe detenerse en 0.0 y pausar el frame de animación
	assert_almost_eq(_orco.obtener_velocidad_actual(), 0.0, 0.01, "La velocidad debe ser 0 durante el diálogo")
	assert_false(ap.is_playing(), "AnimationPlayer debe pausarse (frame congelado) al dialogar")

	# Act 2: Procesar respiración sutil durante el diálogo
	var nodo_modelo: Node3D = _orco.obtener_nodo_modelo()
	var escala_base: Vector3 = _orco.obtener_escala_base_modelo()
	_orco._process(0.8)
	# Assert: Deformación sutil de respiración activa
	assert_ne(nodo_modelo.scale.y, escala_base.y, "Debe aplicar respiración sutil mientras dura el diálogo")

	# Act 3: Completar y cerrar diálogo
	_orco.interactuar()  # viñeta 2
	_orco.interactuar()  # cerrar

	# Assert: Debe reanudar su velocidad de caminata y su animación, restaurando la escala
	assert_almost_eq(_orco.obtener_velocidad_actual(), 2.0, 0.01, "La velocidad debe reanudarse al terminar")
	assert_true(ap.is_playing(), "AnimationPlayer debe reanudar su reproducción al cerrar diálogo")
	assert_almost_eq(nodo_modelo.scale.y, escala_base.y, 0.001, "La escala del modelo debe restaurarse")


func test_npc_gira_hacia_jugador_y_reanuda_ruta() -> void:
	# Arrange: Orco caminando hacia la izquierda (-X) con ángulo -90°
	_orco.configurar_patrulla(10.0, 1.8)
	_orco.direccion_inicial = SCRIPT_ORCO.Direccion.IZQUIERDA
	_orco.iniciar_caminata()
	assert_eq(_orco.obtener_direccion(), -1.0, "Debe iniciar caminando hacia la izquierda")
	assert_almost_eq(_orco.obtener_angulo_pivot(), -90.0, 0.1, "El pivot debe apuntar hacia la izquierda (-90°)")

	# Crear un dummy de jugador ubicado a su derecha (+X)
	var dummy_jugador := Node3D.new()
	dummy_jugador.name = "Player"
	dummy_jugador.add_to_group("player")
	add_child_autofree(dummy_jugador)
	dummy_jugador.global_position = _orco.global_position + Vector3(2.0, 0.0, 0.0)

	_orco.fijar_jugador_cerca(true)

	# Act: Iniciar diálogo cuando el jugador está a su derecha
	_orco.interactuar()

	# Assert: El orco debe haberse girado hacia el lado del jugador (hacia la derecha = 90°)
	_orco.orientar_hacia_jugador(false)
	assert_almost_eq(_orco.obtener_angulo_pivot(), 90.0, 0.1, "El NPC debe girarse hacia la derecha para mirar al jugador")
	assert_eq(_orco.obtener_direccion_previa_dialogo(), -1.0, "Debe recordar que su ruta era hacia la izquierda")

	# Act 2: Cerrar diálogo
	_orco.interactuar()  # viñeta 2
	_orco.interactuar()  # cerrar diálogo

	# Assert: Al terminar el diálogo, debe reanudar su ruta hacia la izquierda
	assert_eq(_orco.obtener_direccion(), -1.0, "Debe retomar su dirección de ruta (-1.0)")
	assert_almost_eq(_orco.obtener_velocidad_actual(), 1.8, 0.01, "Debe reanudar la velocidad de caminata")


func test_radio_interaccion_mas_cercano() -> void:
	# Arrange & Assert
	assert_lte(_orco.radio_interaccion, 1.5, "El radio de interacción debe requerir que la protagonista esté más cerca (<= 1.5m)")
	var sb: SpeechBubbleComponent = _orco.obtener_speech_bubble()
	assert_not_null(sb, "SpeechBubbleComponent debe existir")
	assert_lte(sb.offset_cabeza.y, 1.2, "El globo debe ubicarse casi sobre él (<= 1.2m)")


func test_camara_juego_resuelve_camara_frente() -> void:
	# Arrange: Crear una escena ficticia con CamaraFrente y PRESPECTIVA
	var root_dummy := Node3D.new()
	var cam_frente := Camera3D.new()
	cam_frente.name = "CamaraFrente"
	var cam_presp := Camera3D.new()
	cam_presp.name = "PRESPECTIVA"
	cam_presp.current = true
	root_dummy.add_child(cam_frente)
	root_dummy.add_child(cam_presp)
	add_child_autofree(root_dummy)

	# Act
	var cam_resuelta: Camera3D = CameraUtils.obtener_camara_juego(cam_frente)

	# Assert: Debe dar prioridad a CamaraFrente
	assert_not_null(cam_resuelta, "CameraUtils debe encontrar una cámara")
	assert_eq(cam_resuelta.name, "CamaraFrente", "CameraUtils debe priorizar CamaraFrente sobre PRESPECTIVA")


func test_orco_cerdo_texto_en_nivel_pueblo() -> void:
	# Arrange & Act: Cargar NivelPueblo
	var pueblo: Node = SCENE_PUEBLO.instantiate()
	add_child_autofree(pueblo)

	var npc: OrcoCerdo = pueblo.find_child("OrcoCerdo texto", true, false) as OrcoCerdo

	# Assert
	assert_not_null(npc, "OrcoCerdo texto debe existir en NivelPueblo.tscn")
	assert_true(npc.es_dialogo_activo(), "Debe tener el diálogo activo")
	assert_eq(npc.lineas_dialogo[0], "ORCO_PUEBLO_1", "Viñeta 1 en pueblo debe ser clave de traducción")
	assert_eq(npc.lineas_dialogo[1], "ORCO_PUEBLO_2", "Viñeta 2 en pueblo debe ser clave de traducción")


func test_pasos_armadura_condiciones_y_reproduccion() -> void:
	# Arrange
	_orco.iniciar_caminata()
	var dummy_jugador := Node3D.new()
	dummy_jugador.name = "Player"
	dummy_jugador.add_to_group("player")
	add_child_autofree(dummy_jugador)

	# 1. Jugador cerca (a 3 metros) -> debe poder sonar
	dummy_jugador.global_position = _orco.global_position + Vector3(3.0, 0.0, 0.0)
	assert_true(_orco.puede_sonar_pasos(), "Debe poder sonar pasos cuando el jugador está cerca")

	# 2. Jugador lejos (a 25 metros) -> no debe sonar
	dummy_jugador.global_position = _orco.global_position + Vector3(25.0, 0.0, 0.0)
	assert_false(_orco.puede_sonar_pasos(), "No debe sonar pasos cuando el jugador está lejos")

	# 3. Jugador cerca pero pasos_armadura_activos = false
	dummy_jugador.global_position = _orco.global_position + Vector3(2.0, 0.0, 0.0)
	_orco.pasos_armadura_activos = false
	assert_false(_orco.puede_sonar_pasos(), "No debe sonar si pasos_armadura_activos es false")
	_orco.pasos_armadura_activos = true

	# 4. Jugador cerca pero Orco estático
	_orco.pausar()
	assert_false(_orco.puede_sonar_pasos(), "No debe sonar pasos si el orco está estático")
	_orco.reanudar()

	# 5. Reproductor de pasos creado y configurado
	var player_audio: AudioStreamPlayer = _orco.obtener_reproductor_pasos()
	assert_not_null(player_audio, "Debe existir AudioStreamPlayer para pasos de armadura")
	assert_not_null(player_audio.stream, "El reproductor de pasos debe tener asignado el stream de audio")

	# 6. Verificación de reproducción activa cuando el jugador está cerca
	dummy_jugador.global_position = _orco.global_position + Vector3(2.0, 0.0, 0.0)
	_orco._procesar_caminata(0.016)
	assert_true(player_audio.playing, "Debe estar reproduciendo el audio de armadura cuando camina cerca del jugador")

	# 7. Verificación de parada cuando el jugador se aleja
	dummy_jugador.global_position = _orco.global_position + Vector3(20.0, 0.0, 0.0)
	_orco._procesar_caminata(0.016)
	assert_false(player_audio.playing, "Debe detenerse el audio cuando el jugador se aleja")
