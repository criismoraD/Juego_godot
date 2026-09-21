extends "res://addons/gut/test.gd"

## Tests unitarios para GoblinTripulante.
## Sigue la estructura AAA (Arrange, Act, Assert) y las normas de AGENTS.md.

const GoblinTripulanteScene = preload("res://Entities/Enemigo_GloboAerostatico/GoblinTripulante.tscn")
const GloboAerostaticoScene = preload("res://Entities/Enemigo_GloboAerostatico/GloboAerostatico.tscn")

var _tripulante: GoblinTripulante = null


func before_each() -> void:
	_tripulante = GoblinTripulanteScene.instantiate() as GoblinTripulante
	_tripulante.auto_disparar = false  # Desactivar loop automático en tests
	get_tree().root.add_child(_tripulante)


func after_each() -> void:
	if is_instance_valid(_tripulante):
		_tripulante.queue_free()
	_tripulante = null


func test_instanciacion_tripulante() -> void:
	# Assert
	assert_not_null(_tripulante, "GoblinTripulante debe instanciarse correctamente")
	assert_false(_tripulante.is_dead, "El tripulante debe iniciar con is_dead == false")
	assert_false(_tripulante.is_reloading, "El tripulante debe iniciar con is_reloading == false")


func test_disparar_emite_senal_y_recarga() -> void:
	# Arrange
	watch_signals(_tripulante)

	# Act
	_tripulante.disparar()

	# Assert
	assert_signal_emitted(_tripulante, "disparo_realizado", "Debe emitir la señal disparo_realizado")
	assert_true(_tripulante.is_reloading, "Debe entrar en estado is_reloading == true tras disparar")


func test_morir_activa_desmembramiento_y_marca_muerto() -> void:
	# Arrange
	watch_signals(_tripulante)

	# Act
	_tripulante.morir()

	# Assert
	assert_signal_emitted(_tripulante, "muerto", "Debe emitir la señal muerto al morir")
	assert_true(_tripulante.is_dead, "Debe quedar marcado con is_dead == true")


func test_globo_integra_tripulante_y_lo_mata_al_destruirse() -> void:
	# Arrange
	var globo: GloboAerostatico = GloboAerostaticoScene.instantiate() as GloboAerostatico
	get_tree().root.add_child(globo)
	var tripulante_en_globo := globo.find_children("*", "GoblinTripulante", true, false).front() as GoblinTripulante

	# Assert
	assert_not_null(tripulante_en_globo, "GloboAerostatico debe tener a GoblinTripulante dentro de su jerarquía")

	# Act: El globo recibe daño fatal
	globo.take_damage(globo.vida_maxima)

	# Assert
	assert_true(tripulante_en_globo.is_dead, "El tripulante debe morir y desmembrarse cuando el globo es destruido")

	# Cleanup
	if is_instance_valid(globo):
		globo.queue_free()


func test_partes_explotadas_ocultas_mientras_vivo() -> void:
	# Arrange & Assert
	var partes := _tripulante.get_node_or_null("PartesExplotadas") as Node3D
	assert_not_null(partes, "Debe existir el nodo PartesExplotadas")
	assert_false(partes.visible, "Las partes de muerte deben estar ocultas mientras el tripulante esté vivo")


func test_partes_explotadas_ocultas_en_globo_vivo() -> void:
	# Arrange
	var globo: GloboAerostatico = GloboAerostaticoScene.instantiate() as GloboAerostatico
	get_tree().root.add_child(globo)

	# Assert
	var partes := globo.find_children("PartesExplotadas", "Node3D", true, false).front() as Node3D
	assert_not_null(partes, "Debe existir el nodo PartesExplotadas en el globo")
	assert_false(partes.visible, "Las partes de muerte no deben ser visibles sobrepuestas en el globo vivo")

	# Cleanup
	if is_instance_valid(globo):
		globo.queue_free()


func test_tripulante_contiene_disparo_con_globo_dormido() -> void:
	# Arrange: tripulante a bordo de un globo dormido fuera de cámara
	var globo = GloboAerostaticoScene.instantiate()
	get_tree().root.add_child(globo)
	globo._dormido_por_camara = true
	_tripulante.auto_disparar = true
	_tripulante.shoot_timer = 0.0
	var padre_previo := _tripulante.get_parent()
	if padre_previo:
		padre_previo.remove_child(_tripulante)
	globo.add_child(_tripulante)

	# Act: ciclo con el timer vencido
	_tripulante._physics_process(0.016)

	# Assert: no dispara ni recarga hasta que el globo aparezca
	assert_false(_tripulante.is_reloading, "Con globo dormido no debe disparar")
	assert_eq(_tripulante.shoot_timer, 0.0, "El timer no debe correr fuera de cámara")

	# Cleanup (el after_each libera al tripulante)
	if is_instance_valid(globo):
		globo.queue_free()
