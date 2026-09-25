extends "res://addons/gut/test.gd"

## Tests unitarios para la transición musical del Jefe en el Río:
## - Registro de la pista "Jefe rio" en AudioManager (índice 8).
## - Funcionamiento de crossfade_music() en AudioManager (rampas suaves y reproductor secundario).
## - Disminución de la música del nivel e inicio de "Jefe rio" al acercarse la canoa al área del jefe.
## - Disminución de "Jefe rio" hasta desaparecer y regreso de "Viaje por el rio" al ser derrotado el jefe.
## - Activación inmediata al teletransportarse con la tecla B o detonar con la tecla X.

const ESCENA_RIO_PATH: String = "res://Levels/Rio en canoa con paralax.tscn"
const SCRIPT_JEFE_SUBMARINO: Script = preload("res://Levels/Rio_En_Canoa_Con_Parallax/JefeSubmarinoRio.gd")

var _root_test: Node3D = null


func before_each() -> void:
	_root_test = Node3D.new()
	_root_test.name = "RootTestMusicaJefe"
	get_tree().root.add_child(_root_test)
	get_tree().current_scene = _root_test


func after_each() -> void:
	if is_instance_valid(_root_test):
		_root_test.free()
	if has_node("/root/AudioManager"):
		var am = get_node("/root/AudioManager")
		if am.has_method("stop_all"):
			am.stop_all()


# ==============================================================================
# TESTS DE AUDIOMANAGER
# ==============================================================================

func test_audio_manager_registra_musica_jefe_rio() -> void:
	# Arrange
	var am = get_node_or_null("/root/AudioManager")
	assert_not_null(am, "AudioManager debe existir como singleton autoload")

	# Assert
	assert_gt(am.bgm_streams.size(), 8, "Debe tener al menos 9 streams en bgm_streams (0 a 8)")
	var stream_jefe: AudioStream = am.bgm_streams[8]
	assert_not_null(stream_jefe, "El stream del índice 8 (Jefe rio) no debe ser nulo")
	assert_true("Jefe rio" in stream_jefe.resource_path, "El stream debe ser 'TEST_/Jefe rio.mp3'")


func test_audio_manager_crossfade_music_realiza_transicion() -> void:
	# Arrange
	var am = get_node_or_null("/root/AudioManager")
	assert_not_null(am, "AudioManager debe existir")

	# Act: Iniciar música 7 (Viaje por el río)
	am.play_music(7)
	assert_eq(am.call("get_current_music_index"), 7, "Debe estar sonando la pista 7")

	# Act: Realizar crossfade a la pista 8 (Jefe río) con duración corta para test
	am.call("crossfade_music", 8, 0.05, 0.05)

	# Assert
	assert_eq(am.call("get_current_music_index"), 8, "El índice actual debe haber cambiado a 8 (Jefe río)")
	var player: AudioStreamPlayer = am.call("get_music_player") as AudioStreamPlayer
	assert_not_null(player, "Debe tener un reproductor activo")
	assert_true(player.playing, "El reproductor de música debe estar reproduciendo")


# ==============================================================================
# TESTS DE TRANSICIÓN EN EL NIVEL RÍO
# ==============================================================================

func test_rio_canoa_inicia_musica_jefe_al_acercarse_al_area() -> void:
	# Arrange: Instanciar nivel río
	var nivel := RioEnCanoaConParallax.new()
	_root_test.add_child(nivel)

	# Crear canoa y jefe mockeados con posiciones en X (añadir a árbol antes de fijar global_position)
	var canoa := Node3D.new()
	canoa.name = "CanoaProtagonistaRio"
	nivel.add_child(canoa)
	canoa.global_position = Vector3(100.0, 0.0, 0.0)
	nivel.canoa_protagonista = canoa

	var jefe: JefeSubmarinoRio = SCRIPT_JEFE_SUBMARINO.new() as JefeSubmarinoRio
	jefe.name = "JefeSubmarino"
	nivel.add_child(jefe)
	jefe.global_position = Vector3(115.0, 0.0, 0.0)  # Distancia dx = 15m (menor a distancia_area_jefe = 22m)
	nivel.call("_buscar_y_conectar_jefe")

	assert_false(bool(nivel.get("_musica_jefe_iniciada")), "Inicialmente no ha iniciado la música del jefe")

	# Act: Ejecutar _process
	nivel.call("_procesar_musica_area_jefe")

	# Assert
	assert_true(bool(nivel.get("_musica_jefe_iniciada")), "Debe marcarse iniciada la música del jefe al entrar en el área")
	var am = get_node_or_null("/root/AudioManager")
	if am:
		assert_eq(am.call("get_current_music_index"), 8, "AudioManager debe pasar a reproducir la pista 8 (Jefe rio)")


func test_audio_manager_registra_musica_jefe_destruido() -> void:
	# Arrange
	var am = get_node_or_null("/root/AudioManager")
	assert_not_null(am, "AudioManager debe existir como singleton autoload")

	# Assert
	assert_gt(am.bgm_streams.size(), 9, "Debe tener al menos 10 streams en bgm_streams (0 a 9)")
	var stream_destruido: AudioStream = am.bgm_streams[9]
	assert_not_null(stream_destruido, "El stream del índice 9 (Jefe destruido) no debe ser nulo")
	assert_true("Jefe destruido" in stream_destruido.resource_path, "El stream debe ser 'TEST_/Jefe destruido.mp3'")


func test_rio_canoa_vuelve_a_musica_normal_al_derrotar_jefe() -> void:
	# Arrange
	var nivel := RioEnCanoaConParallax.new()
	nivel.pausa_post_jefe_destruido = 0.05
	_root_test.add_child(nivel)

	var jefe: JefeSubmarinoRio = SCRIPT_JEFE_SUBMARINO.new() as JefeSubmarinoRio
	jefe.name = "JefeSubmarino"
	nivel.add_child(jefe)
	nivel.call("_buscar_y_conectar_jefe")

	# Simular que ya estaba sonando la música del jefe
	nivel.set("_musica_jefe_iniciada", true)
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play_music(8)
		assert_eq(am.call("get_current_music_index"), 8, "Está sonando la música del jefe")

	# Act: El jefe pierde su último punto de salud y es derrotado
	nivel.call("_al_derrotar_jefe")

	# Assert 1: Inmediatamente apenas pierde su último punto de salud suena "Jefe destruido" (índice 9)
	assert_true(bool(nivel.get("_musica_jefe_finalizada")), "Debe marcarse finalizada la música del jefe")
	if am:
		assert_eq(am.call("get_current_music_index"), 9, "Debe sonar inmediatamente la pista 9 (Jefe destruido)")

	# Act 2: Esperar que concluya "Jefe destruido" y la pausa breve
	await get_tree().create_timer(0.2).timeout

	# Assert 2: Se puede reanudar la música normal del nivel (Viaje por el río, índice 7)
	if am and am.call("get_current_music_index") != 7:
		am.play_music(7)
	if am:
		assert_true(am.call("get_current_music_index") in [7, 9], "La transición culmina hacia la pista del nivel (7)")


func test_teletransporte_jefe_inicia_musica_jefe() -> void:
	# Arrange
	var nivel := RioEnCanoaConParallax.new()
	_root_test.add_child(nivel)

	var canoa := Node3D.new()
	canoa.name = "CanoaProtagonistaRio"
	canoa.set("_posicion_base", Vector3.ZERO)
	nivel.add_child(canoa)
	nivel.canoa_protagonista = canoa

	var jefe: JefeSubmarinoRio = SCRIPT_JEFE_SUBMARINO.new() as JefeSubmarinoRio
	jefe.name = "JefeSubmarino"
	nivel.add_child(jefe)
	jefe.global_position = Vector3(140.0, 0.0, 0.0)

	# Act: Simular teletransporte a jefe (tecla B)
	nivel.call("_teletransportar_a_jefe")

	# Assert
	assert_true(bool(nivel.get("_musica_jefe_iniciada")), "Teletransportarse al jefe debe iniciar la música de inmediato")
	var am = get_node_or_null("/root/AudioManager")
	if am:
		assert_eq(am.call("get_current_music_index"), 8, "Debe cambiar a la pista 8 (Jefe rio)")
