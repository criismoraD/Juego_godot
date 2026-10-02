extends "res://addons/gut/test.gd"

## La música del tutorial tiene pista e índice propios en el AudioManager
## y el nivel tutorial la usa como ambiente de arranque.

const SCRIPT_AUDIO: Script = preload("res://System/Core/AudioManager.gd")
const RUTA_MUSICA_TUTORIAL: String = "res://TEST_/Musica nivel tutorial A.mp3"


func test_musica_tutorial_tiene_indice_propio() -> void:
	# Assert
	assert_eq(SCRIPT_AUDIO.MUSICA_TUTORIAL, 11, "MUSICA_TUTORIAL debe ser el índice 11")


func test_musica_tutorial_archivo_existe() -> void:
	# Assert
	assert_true(
		FileAccess.file_exists(RUTA_MUSICA_TUTORIAL),
		"Debe existir el archivo Musica nivel tutorial.aac"
	)


func test_musica_tutorial_registrada_en_bgm() -> void:
	# Arrange: instancia sin árbol ( _load_all_sounds no requiere SceneTree )
	var am: Node = SCRIPT_AUDIO.new()

	# Act
	am._load_all_sounds()

	# Assert
	assert_gte(am.bgm_streams.size(), 12, "bgm_streams debe incluir el índice 11 del tutorial")
	assert_true(am.bgm_volume_offsets.has(11), "Debe existir offset de volumen para el índice 11")
	assert_not_null(am.bgm_streams[11], "La pista MP3 del tutorial debe cargarse (reimporta si es null)")
	am.free()
