extends "res://addons/gut/test.gd"

## Tests unitarios para el gruñido de diálogo del OrcoCerdo (sonido_cerdo.mp3).
## Estructura AAA (Arrange, Act, Assert) siguiendo las directrices de AGENTS.md.

const SCRIPT_ORCO: GDScript = preload("res://Entities/NPC_OrcoCerdo/OrcoCerdo.gd")
const SCENE_ORCO: PackedScene = preload("res://Entities/NPC_OrcoCerdo/OrcoCerdo.tscn")
const AUDIO_CERDO: AudioStreamMP3 = preload("res://Entities/NPC_OrcoCerdo/Audio/sonido_cerdo.mp3")

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


func test_audio_cerdo_existe_y_configurado() -> void:
	# Arrange & Act: recurso y reproductor ya construidos en _ready
	# Assert
	assert_not_null(AUDIO_CERDO, "sonido_cerdo.mp3 debe estar en Entities/NPC_OrcoCerdo/Audio/")
	var rep: AudioStreamPlayer = _orco.obtener_reproductor_cerdo()
	assert_not_null(rep, "Debe existir el reproductor SonidoCerdo")
	assert_eq(rep.name, "SonidoCerdo", "El reproductor debe llamarse 'SonidoCerdo'")
	assert_eq(rep.stream, AUDIO_CERDO, "El reproductor debe usar sonido_cerdo.mp3")
	assert_eq(rep.bus, "Master", "El bus debe ser 'Master'")
	assert_false(rep.stream.loop, "El gruñido debe ser one-shot (sin bucle)")
	assert_true(_orco.sonido_cerdo_activo, "El gruñido debe estar activo por defecto")


func test_grunido_suena_al_iniciar_dialogo() -> void:
	# Arrange
	_orco.fijar_jugador_cerca(true)
	var rep: AudioStreamPlayer = _orco.obtener_reproductor_cerdo()
	assert_false(rep.playing, "No debe sonar antes de interactuar")

	# Act: presionar [E] inicia el diálogo
	_orco.interactuar()

	# Assert
	assert_true(_orco.esta_hablando_dialogo(), "Debe estar en modo diálogo activo")
	assert_true(rep.playing, "El gruñido debe reproducirse al iniciar el diálogo")


func test_grunido_no_suena_si_esta_desactivado() -> void:
	# Arrange
	_orco.sonido_cerdo_activo = false
	_orco.fijar_jugador_cerca(true)
	var rep: AudioStreamPlayer = _orco.obtener_reproductor_cerdo()

	# Act
	_orco.interactuar()

	# Assert
	assert_true(_orco.esta_hablando_dialogo(), "El diálogo debe iniciar igual aunque el sonido esté off")
	assert_false(rep.playing, "No debe sonar si sonido_cerdo_activo es false")


func test_grunido_respeta_volumen_configurado() -> void:
	# Arrange
	_orco.volumen_sonido_cerdo_db = -6.0

	# Act
	_orco.reproducir_sonido_cerdo()

	# Assert
	var rep: AudioStreamPlayer = _orco.obtener_reproductor_cerdo()
	assert_almost_eq(rep.volume_db, -6.0, 0.01, "El reproductor debe aplicar el volumen configurado")
	assert_true(rep.playing, "Debe reproducirse al llamar reproducir_sonido_cerdo()")
