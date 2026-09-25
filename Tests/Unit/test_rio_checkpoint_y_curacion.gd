extends "res://addons/gut/test.gd"

## Tests unitarios para el sistema de Checkpoint, curación completa y baile de victoria
## en el nivel del río ('Rio en canoa con paralax').

const SCRIPT_RIO: Script = preload("res://Levels/Rio_En_Canoa_Con_Parallax/Rio_En_Canoa_Con_Parallax.gd")
const SCRIPT_JEFE: Script = preload("res://Levels/Rio_En_Canoa_Con_Parallax/JefeSubmarinoRio.gd")
const SCRIPT_PERRENA: Script = preload("res://Entities/Defensora_Perrena/DefensoraPerrena.gd")
const ESCENA_CANOA: PackedScene = preload("res://Levels/Rio_En_Canoa_Con_Parallax/CanoaProtagonistaRio.tscn")

var _nivel: RioEnCanoaConParallax = null


func before_each() -> void:
	RioEnCanoaConParallax.reset_checkpoint()
	_nivel = SCRIPT_RIO.new()
	get_tree().root.add_child(_nivel)


func after_each() -> void:
	RioEnCanoaConParallax.reset_checkpoint()
	if is_instance_valid(_nivel):
		if _nivel.get_parent():
			_nivel.get_parent().remove_child(_nivel)
		_nivel.free()
	_nivel = null


func test_destruccion_barco_checkpoint_guarda_posicion_y_activa_estado() -> void:
	# Arrange
	var canoa: Node3D = ESCENA_CANOA.instantiate() as Node3D
	_nivel.add_child(canoa)
	_nivel.canoa_protagonista = canoa
	canoa.global_position.x = 125.5
	assert_false(RioEnCanoaConParallax.checkpoint_rio_activo, "Precondición: checkpoint inactivo")

	# Act: Simular destrucción del barco checkpoint
	_nivel._al_destruir_barco_checkpoint()

	# Assert
	assert_true(RioEnCanoaConParallax.checkpoint_rio_activo, "El checkpoint debe quedar activo tras destruir el barco")
	assert_almost_eq(RioEnCanoaConParallax.checkpoint_rio_pos_x, 125.5, 0.1, "La posición del checkpoint debe ser la posición X de la canoa")

	# Limpieza
	canoa.queue_free()


func test_notificacion_punto_guardado_texto_blanco_y_traduccion() -> void:
	# Arrange
	var texto_esperado: String = tr("Punto de guardado")
	assert_true(texto_esperado.length() > 0, "tr('Punto de guardado') no debe ser vacío")

	# Act: Ejecutar la notificación visual
	_nivel._mostrar_notificacion_checkpoint()

	# Assert: Buscar el CanvasLayer y Label generado
	var notif: CanvasLayer = _nivel.get_node_or_null("NotificacionCheckpoint") as CanvasLayer
	if not is_instance_valid(notif):
		notif = get_tree().root.get_node_or_null("NotificacionCheckpoint") as CanvasLayer
	assert_not_null(notif, "Debe instanciarse el CanvasLayer NotificacionCheckpoint")

	if is_instance_valid(notif):
		var label: Label = notif.find_child("LabelPuntoGuardado", true, false) as Label
		assert_not_null(label, "Debe existir LabelPuntoGuardado dentro de la notificación")
		if is_instance_valid(label):
			assert_eq(label.text, texto_esperado, "El texto del cartel debe coincidir con la traducción")
			var color_fuente: Color = label.get_theme_color("font_color")
			assert_eq(color_fuente, Color.WHITE, "El texto debe ser blanco puro (Color.WHITE)")
		notif.queue_free()


func test_aplicar_checkpoint_reubica_canoa_a_posicion_guardada() -> void:
	# Arrange
	var canoa: Node3D = ESCENA_CANOA.instantiate() as Node3D
	_nivel.add_child(canoa)
	_nivel.canoa_protagonista = canoa
	canoa.global_position.x = -6.7

	RioEnCanoaConParallax.checkpoint_rio_activo = true
	RioEnCanoaConParallax.checkpoint_rio_pos_x = 124.8

	# Act: Aplicar checkpoint
	_nivel._aplicar_checkpoint_rio()

	# Assert: La canoa debe haber sido teletransportada al punto de control
	assert_almost_eq(canoa.global_position.x, 124.8, 0.1, "La canoa debe aparecer en la posición guardada del checkpoint")
	assert_true(_nivel._barco_checkpoint_destruido, "El barco checkpoint debe considerarse destruido")

	# Limpieza
	canoa.queue_free()


func test_curar_jugador_y_perrena_al_derrotar_jefe() -> void:
	# Arrange: Instanciar canoa con jugadora y Perrena
	var canoa: Node3D = ESCENA_CANOA.instantiate() as Node3D
	_nivel.add_child(canoa)
	_nivel.canoa_protagonista = canoa

	var player = canoa.find_child("Protagonista", true, false)
	var perrena = canoa.find_child("DefensoraPerrena", true, false)
	assert_not_null(player, "La canoa debe contener la protagonista")
	assert_not_null(perrena, "La canoa debe contener a DefensoraPerrena")

	# Reducir vida de ambos
	if player:
		player.health = 1
		assert_eq(player.health, 1, "Precondición: jugadora herida")
	if perrena:
		perrena.health = 2
		assert_eq(perrena.health, 2, "Precondición: Perrena herida")

	# Act: Derrotar al jefe y disparar curación total
	_nivel.curar_jugador_y_perrena_al_derrotar_jefe()

	# Assert: Ambos deben tener salud completa
	if player:
		assert_eq(player.health, player.vida_maxima, "Los corazones del jugador deben rellenarse al 100%")
	if perrena:
		assert_eq(perrena.health, perrena.vida_maxima, "La vida de Perrena debe rellenarse al 100%")

	# Limpieza
	canoa.queue_free()


func test_duracion_baile_perrena_tras_hundimiento_es_1_punto_5_segundos() -> void:
	# Arrange / Act
	var jefe = SCRIPT_JEFE.new()
	get_tree().root.add_child(jefe)

	# Assert
	assert_eq(jefe.retraso_fin_baile_tras_hundirse, 1.5, "Perrena debe bailar exactamente 1.5 segundos tras finalizar la animación de destrucción del jefe")

	# Limpieza
	jefe.queue_free()


func test_reset_checkpoint_limpia_correctamente_el_estado() -> void:
	# Arrange
	RioEnCanoaConParallax.checkpoint_rio_activo = true
	RioEnCanoaConParallax.checkpoint_rio_pos_x = 126.0

	# Act
	RioEnCanoaConParallax.reset_checkpoint()

	# Assert
	assert_false(RioEnCanoaConParallax.checkpoint_rio_activo, "checkpoint_rio_activo debe ser false")
	assert_eq(RioEnCanoaConParallax.checkpoint_rio_pos_x, 0.0, "checkpoint_rio_pos_x debe ser 0.0")
