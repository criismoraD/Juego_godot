extends "res://addons/gut/test.gd"

var GoblinScene: PackedScene = preload("res://Entities/Enemigo_Goblin/Goblin.tscn")
var goblin: Goblin = null


func before_each():
	goblin = GoblinScene.instantiate() as Goblin
	goblin.drop_chance_flecha_explosiva = 0.0  # Desactivar drops aleatorios durante tests
	add_child_autofree(goblin)


func after_each():
	if is_instance_valid(goblin) and not goblin.is_queued_for_deletion():
		goblin.queue_free()


func test_goblin_initial_state() -> void:
	# Arrange & Assert
	assert_not_null(goblin, "El nodo goblin debe instanciarse correctamente")
	assert_false(goblin.murio_por_explosion, "murio_por_explosion debe ser falso por defecto")
	assert_eq(goblin.current_state, EnemyBase.State.WALKING, "El estado inicial debe ser WALKING")


func test_goblin_muerte_por_explosion_triggers_explosive_behavior() -> void:
	# Arrange
	goblin.murio_por_explosion = true
	goblin.last_hit_position = Vector3(1.0, 0.0, 0.0)

	# Act
	goblin._on_state_dying()

	# Assert
	var model = goblin.get_node_or_null("GOBLING_REMASTER_ANIMACIONES")
	if is_instance_valid(model):
		assert_false(model.visible, "El modelo intacto debe ocultarse al desmembrarse por explosión")

	# Verificar que un reproductor de audio esté activo con el sonido
	var audio_mgr: Node = AudioManager
	if audio_mgr and "sfx_pool" in audio_mgr:
		var has_stream_playing: bool = false
		for p in audio_mgr.sfx_pool:
			if p.playing and p.stream != null:
				has_stream_playing = true
				break
		assert_true(has_stream_playing, "Debe haberse emitido un sonido de muerte explosiva")


func test_muerte_por_explosion_lanza_la_ballesta() -> void:
	# Arrange
	goblin.murio_por_explosion = true
	var piezas_antes := get_tree().root.find_children("*", "GoblinPiezaFisica", true, false).size()

	# Act
	goblin._on_state_dying()
	await get_tree().process_frame
	await get_tree().process_frame

	# Assert: se generan piezas físicas y la ballesta viaja en una de ellas
	var piezas := get_tree().root.find_children("*", "GoblinPiezaFisica", true, false)
	assert_gt(piezas.size(), piezas_antes, "La muerte explosiva debe lanzar piezas físicas")

	var ballesta_lanzada: bool = false
	for p in piezas:
		if p.find_child("BALLES_GOBLING", true, false):
			ballesta_lanzada = true
			break
	assert_true(ballesta_lanzada, "La ballesta debe salir volando en una pieza física")
