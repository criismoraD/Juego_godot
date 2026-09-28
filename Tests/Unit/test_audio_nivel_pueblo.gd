extends "res://addons/gut/test.gd"

## Test unitario para la música y configuración de sonido ambiente en Nivel Pueblo:
## Verifica el registro de Canción pueblo en AudioManager, eliminación del sonido ambiente del bosque
## y la reproducción automática de la canción al iniciar el nivel.

var audio_mgr: Node = null

func before_each():
	var audio_script = load("res://System/Core/AudioManager.gd")
	audio_mgr = audio_script.new()
	add_child(audio_mgr)


func after_each():
	if is_instance_valid(audio_mgr):
		audio_mgr.free()


func test_musica_pueblo_registrada_en_audio_manager():
	# Assert
	assert_eq(audio_mgr.MUSICA_PUEBLO, 10, "La constante MUSICA_PUEBLO debe ser 10")
	assert_gt(audio_mgr.bgm_streams.size(), 10, "AudioManager debe tener al menos 11 entradas en bgm_streams (0 a 10)")
	
	var stream: AudioStream = audio_mgr.bgm_streams[10]
	assert_not_null(stream, "El stream para Canción pueblo (índice 10) no debe ser nulo")
	assert_true(stream.resource_path.ends_with("Cancion pueblo.mp3"), "El recurso debe ser 'Cancion pueblo.mp3'")
	assert_true(audio_mgr.bgm_volume_offsets.has(10), "bgm_volume_offsets debe contener entrada para el índice 10")


func test_play_music_stream_metodo():
	# Arrange
	var stream: AudioStream = audio_mgr.bgm_streams[10]
	assert_not_null(stream)

	# Act
	audio_mgr.play_music_stream(stream, true, 0.0)

	# Assert
	assert_eq(audio_mgr.music_player.stream, stream, "music_player debe tener asignado el stream de la canción")
	assert_true(audio_mgr.music_player.playing, "music_player debe estar reproduciendo")


func test_nivel_pueblo_propiedades_audio_configuradas():
	# Arrange
	var scene: PackedScene = load("res://Levels/Nivel_Pueblo/NivelPueblo.tscn")
	assert_not_null(scene, "La escena NivelPueblo debe existir")

	# Act
	var nivel: Node = scene.instantiate()
	add_child_autofree(nivel)

	# Assert
	assert_false(nivel.get("reproducir_sonido_ambiente"), "reproducir_sonido_ambiente debe ser false en NivelPueblo")
	assert_eq(nivel.get("musica_inicial_indice"), 10, "musica_inicial_indice debe ser 10 (Canción pueblo)")
	assert_true(nivel.get("mantener_musica_nivel"), "mantener_musica_nivel debe ser true para que no salte a música de combate genérica")
