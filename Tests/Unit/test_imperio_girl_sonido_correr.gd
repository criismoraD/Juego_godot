extends "res://addons/gut/test.gd"

## Imperio Girl suena como una armadura al correr: usa el mismo loop de la
## ballestera aliada, tanto en juego normal como en la entrada del tutorial.

const ImperioGirlScript: Script = preload("res://Entities/Jugador_ImperioGirl/ImperioGirl.gd")
const AllyBallesteraScript: Script = preload("res://Entities/Aliada_Ballestera/AllyBallestera.gd")
const ESCENA_IMPERIO_GIRL: PackedScene = preload("res://Entities/Jugador_ImperioGirl/ImperioGirl.tscn")


func test_usa_mismo_clip_que_ballestera() -> void:
	# Arrange
	var clip_imperio: AudioStream = ImperioGirlScript.STREAM_CORRER_ARMADURA
	var clip_ballestera: AudioStream = AllyBallesteraScript.STREAM_CORRER_ARMADURA

	# Assert
	assert_not_null(clip_imperio, "ImperioGirl debe pre-cargar el loop de armadura")
	assert_not_null(clip_ballestera, "La ballestera debe tener su loop de referencia")
	assert_eq(
		clip_imperio.resource_path, clip_ballestera.resource_path,
		"Imperio Girl debe reutilizar el mismo WAV de la ballestera aliada"
	)


func test_volumen_igual_que_ballestera() -> void:
	# Assert
	assert_eq(
		ImperioGirlScript.VOLUMEN_CORRER_DB, AllyBallesteraScript.VOLUMEN_CORRER_DB,
		"El volumen debe igualar al de la ballestera (fuente silenciosa)"
	)


func test_expone_api_forzada_para_cinematicas() -> void:
	# Arrange
	var ig: CharacterBody3D = ImperioGirlScript.new()

	# Assert
	assert_true(ig.has_method("iniciar_sonido_correr_forzado"), "Debe exponer inicio forzado (entrada tutorial)")
	assert_true(ig.has_method("detener_sonido_correr_forzado"), "Debe exponer detención forzada (entrada tutorial)")
	ig.free()


func test_forzado_activa_deteccion_sin_arbol() -> void:
	# Arrange: instancia fuera del árbol (sin suelo ni velocidad)
	var ig: CharacterBody3D = ImperioGirlScript.new()

	# Act
	ig.iniciar_sonido_correr_forzado()

	# Assert
	assert_true(ig._esta_corriendo(), "Forzado debe reportar carrera aunque velocity sea cero (tween de entrada)")

	# Act
	ig.detener_sonido_correr_forzado()

	# Assert
	assert_false(ig._forzar_sonido_correr, "Detener debe liberar el flag forzado")
	assert_false(ig._esta_corriendo(), "Quieta y sin forzar no debe reportar carrera")
	ig.free()


func test_actualizar_sin_reproductor_no_crashea() -> void:
	# Arrange
	var ig: CharacterBody3D = ImperioGirlScript.new()

	# Act & Assert: guarda nula, no debe romper el _process
	ig._actualizar_sonido_correr()
	assert_null(ig._sfx_correr, "Sin configurar no hay reproductor")
	ig.free()


func test_en_escena_suena_y_se_corta() -> void:
	# Arrange
	var ig: CharacterBody3D = ESCENA_IMPERIO_GIRL.instantiate()
	assert_not_null(ig, "La escena de Imperio Girl debe instanciarse")
	add_child_autofree(ig)
	await get_tree().process_frame

	# Assert: reproductor creado en _ready con el clip de la ballestera
	assert_not_null(ig._sfx_correr, "El _ready debe crear el loop de armadura")
	assert_eq(
		ig._sfx_correr.stream.resource_path,
		AllyBallesteraScript.STREAM_CORRER_ARMADURA.resource_path,
		"El reproductor debe usar el WAV de la ballestera"
	)

	# Act: entrada del tutorial (tween sin velocity)
	ig.iniciar_sonido_correr_forzado()

	# Assert
	assert_true(ig._sfx_correr.playing, "Al forzar debe sonar el loop de armadura")

	# Act: fin de la entrada
	ig.detener_sonido_correr_forzado()

	# Assert
	assert_false(ig._sfx_correr.playing, "Al terminar la entrada debe cortarse (quieta en el puesto)")


func test_hooks_siguen_decision_animacion() -> void:
	# Arrange: sin suelo no hay carrera real (el cuerpo cae en el vacío del test)
	var ig: CharacterBody3D = ESCENA_IMPERIO_GIRL.instantiate()
	add_child_autofree(ig)
	await get_tree().process_frame

	# Act: el Player decide idle (input 0) -> no debe sonar
	ig.update_locomotion_anim(0.0)

	# Assert
	assert_false(ig._sfx_correr.playing, "Con input cero (idle) no debe sonar armadura")

	# Act: forzado de cinemática + cambios de estado/anims -> sigue sonando
	ig.iniciar_sonido_correr_forzado()
	ig.set_motion_anim("air")
	ig.update_locomotion_anim(0.0)

	# Assert
	assert_true(ig._sfx_correr.playing, "Forzado debe sobrevivir a cambios de animación (tween de entrada)")

	# Act: salir del suelo sin forzar -> se corta
	ig.detener_sonido_correr_forzado()
	ig.set_motion_anim("air")

	# Assert
	assert_false(ig._sfx_correr.playing, "En aire sin forzar debe cortarse el loop")
