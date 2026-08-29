extends "res://addons/gut/test.gd"

var AllyBallesteraScript = load("res://Entities/Aliada_Ballestera/AllyBallestera.gd")
var EscenaBallestera: PackedScene = load("res://Entities/Aliada_Ballestera/AllyBallestera.tscn")
var EscenaPowerUpExplosivo: PackedScene = load("res://Entities/Item_Flecha_Explosiva/PowerUpFlechaExplosiva.tscn")

var _ballestera: AllyBallestera = null

class MockAudioManager extends Node:
	func play_sfx(_name, _boost = 0.0): pass
	func stop_bow_tension(): pass
	func reset_bow_hold(): pass

var _mock_audio_created: bool = false


func before_each():
	if not get_tree().root.has_node("AudioManager"):
		var mock_audio = MockAudioManager.new()
		mock_audio.name = "AudioManager"
		get_tree().root.add_child(mock_audio)
		_mock_audio_created = true


func after_each():
	if is_instance_valid(_ballestera):
		if _ballestera.get_parent():
			_ballestera.get_parent().remove_child(_ballestera)
		_ballestera.free()
		_ballestera = null

	var cleanup_containers: Array = [get_tree().root]
	if get_tree().current_scene and get_tree().current_scene != get_tree().root:
		cleanup_containers.append(get_tree().current_scene)

	for container in cleanup_containers:
		for child in container.get_children():
			if child is GoblinPiezaFisica or child.name == "ParticulasMuerteCeleste" or child.name == "BALLES_GOBLING":
				container.remove_child(child)
				child.free()

	if _mock_audio_created and get_tree().root.has_node("AudioManager"):
		var mock_audio = get_tree().root.get_node("AudioManager")
		get_tree().root.remove_child(mock_audio)
		mock_audio.free()
		_mock_audio_created = false


func _agregar_animacion_minima(ballestera: AllyBallestera) -> void:
	var anim_player := AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"

	var lib = AnimationLibrary.new()
	lib.add_animation("IDLE", Animation.new())
	lib.add_animation("DISPARO_01", Animation.new())
	lib.add_animation("DISPARO_AGACHADO", Animation.new())
	lib.add_animation("CAMINAR_01", Animation.new())
	lib.add_animation("CAMINAR_ESP", Animation.new())
	lib.add_animation("MUERTE_01", Animation.new())
	lib.add_animation("MUERTE02", Animation.new())
	lib.add_animation("VICTORIA", Animation.new())

	anim_player.add_animation_library("", lib)
	ballestera.add_child(anim_player)

	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	ballestera.add_child(skeleton)
	ballestera.skeleton = skeleton


func test_ballestera_mensajera_configuracion_sin_escudo():
	# Arrange
	_ballestera = AllyBallesteraScript.new()
	_agregar_animacion_minima(_ballestera)
	_ballestera.es_mensajera = true
	get_tree().root.add_child(_ballestera)

	# Act
	_ballestera._vincular_escudo_piso()
	_ballestera._aplicar_efecto_escudo_piso()

	# Assert: La mensajera no debe vincular ni generar escudos de piso
	assert_true(_ballestera.es_mensajera, "Debe ser marcada como mensajera")
	assert_null(_ballestera._escudo_piso_ref, "La mensajera no debe poseer escudo de piso asignado")
	assert_false(_ballestera._tiene_escudo_frente, "No debe marcar escudo frente")


func test_ballestera_movil_sin_escudo_ataca_enemigos():
	# Arrange
	_ballestera = AllyBallesteraScript.new()
	_agregar_animacion_minima(_ballestera)
	_ballestera.es_movil = true
	get_tree().root.add_child(_ballestera)
	_ballestera.global_position = Vector3(0, 0, 0)

	var enemigo = Node3D.new()
	enemigo.name = "EnemigoTest"
	enemigo.add_to_group("enemies")
	get_tree().root.add_child(enemigo)
	enemigo.global_position = Vector3(5, 0, 0)

	# Act
	_ballestera._vincular_escudo_piso()
	_ballestera._aplicar_efecto_escudo_piso()
	var puede_atacar = _ballestera._puede_atacar()

	# Assert
	assert_true(_ballestera.es_movil, "Debe ser marcada como defensora móvil")
	assert_null(_ballestera._escudo_piso_ref, "Defensora móvil no debe tener escudo")
	assert_true(puede_atacar, "Debe poder atacar libremente a enemigos sin depender de escudo")

	enemigo.queue_free()


func test_despliegue_plataforma_1_baja():
	# Arrange
	_ballestera = AllyBallesteraScript.new()
	_agregar_animacion_minima(_ballestera)
	get_tree().root.add_child(_ballestera)
	_ballestera.global_position = Vector3(-12.8, 0.185, 0.0)

	# Act: desplegar a plataforma 1
	_ballestera.desplegar_a_plataforma(1)
	await get_tree().process_frame

	# Assert: debe configurarse como móvil con 2 de vida, escala 0.3 y estar en despliegue
	assert_true(_ballestera.es_movil, "Debe estar en modo móvil")
	assert_eq(_ballestera.vida_maxima, 2, "La vida máxima debe ser 2 para defensoras móviles")
	assert_eq(_ballestera.health, 2, "La vida actual debe ser 2")
	assert_true(_ballestera.en_despliegue, "Debe estar en estado de despliegue activo")
	assert_almost_eq(_ballestera.scale.x, 0.3, 0.01, "La escala debe ser 0.3 como las defensoras fijas")


func test_despliegue_plataforma_3_mas_alta():
	# Arrange
	_ballestera = AllyBallesteraScript.new()
	_agregar_animacion_minima(_ballestera)
	get_tree().root.add_child(_ballestera)
	_ballestera.global_position = Vector3(-12.8, 0.185, 0.0)

	# Act: simular despliegue a plataforma 3 más alta
	_ballestera.desplegar_a_plataforma(3)
	await get_tree().process_frame

	# Assert
	assert_true(_ballestera.es_movil, "Debe estar en modo móvil para plataforma más alta")
	assert_eq(_ballestera.vida_maxima, 2, "La vida máxima debe ser 2")
	assert_almost_eq(_ballestera.scale.x, 0.3, 0.01, "La escala debe ser 0.3 como las defensoras fijas")


func test_muerte_ballestera_movil_desprende_ballesta_y_particulas():
	# Arrange
	_ballestera = AllyBallesteraScript.new()
	_agregar_animacion_minima(_ballestera)
	_ballestera.es_movil = true

	# Añadir ballesta mock en BoneAttachment3D
	var attachment := BoneAttachment3D.new()
	attachment.name = "BoneAttachment3D"
	_ballestera.skeleton.add_child(attachment)

	var ballesta_mock := Node3D.new()
	ballesta_mock.name = "BALLES_GOBLING"
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	ballesta_mock.add_child(mesh)
	attachment.add_child(ballesta_mock)

	get_tree().root.add_child(_ballestera)
	_ballestera.health = 1

	# Act: recibir daño mortal
	_ballestera.recibir_dano(1)

	# Assert
	assert_eq(_ballestera.health, 0, "La salud debe ser 0")
	assert_eq(_ballestera.current_state, _ballestera.State.DYING, "Debe entrar en estado DYING")

	await get_tree().process_frame


func test_retirada_ballestera_movil_fin_oleada():
	# Arrange
	_ballestera = AllyBallesteraScript.new()
	_agregar_animacion_minima(_ballestera)
	get_tree().root.add_child(_ballestera)
	_ballestera.global_position = Vector3(-8.85, 4.60, _ballestera.plano_profundidad_z)
	_ballestera.plataforma_asignada = 3
	_ballestera.es_movil = true

	# Act: oleada completada
	_ballestera._on_oleada_completada(5)
	await get_tree().process_frame

	# Assert
	assert_true(_ballestera.en_despliegue, "Debe activar en_despliegue durante la retirada")
	assert_almost_eq(_ballestera.global_position.z, 0.02, 0.01, "Debe estar en el plano prioritario Z = 0.02 frente a las arqueras")


func test_item_refuerzo_cura_completamente_jugador():
	# Arrange: Jugador con vida_maxima y salud dañada
	var player_script = load("res://Entities/Jugador_Arquera/Player.gd")
	var player = player_script.new()
	player.vida_maxima = 3
	player.health = 1
	player.add_to_group("player")

	var icono_script = load("res://Entities/Item_Mensajera/IconoMensajeraFX.gd")
	var icono: Area3D = icono_script.new()
	add_child_autofree(icono)
	icono._armado = true

	# Act: El jugador entra en el área del item refuerzo
	icono._on_body_entered(player)

	# Assert: Debe restaurar todos los corazones a vida_maxima (3)
	assert_eq(player.health, 3, "El item refuerzo debe llenar al completo los corazones de la jugadora")
	player.free()


func test_icono_mensajera_particulas_moradas_al_activar():
	# Arrange
	var icono_script = load("res://Entities/Item_Mensajera/IconoMensajeraFX.gd")
	var icono: Area3D = icono_script.new()
	add_child_autofree(icono)
	icono._armado = true

	var player_script = load("res://Entities/Jugador_Arquera/Player.gd")
	var player = player_script.new()
	player.vida_maxima = 3
	player.health = 3
	player.add_to_group("player")

	# Act: Activar
	icono._on_body_entered(player)
	await get_tree().process_frame

	# Assert: Verificar que se instanció el nodo de partículas moradas en la escena
	var root = get_tree().current_scene if get_tree().current_scene else get_tree().root
	var found_particles: GPUParticles3D = null
	for child in root.get_children():
		if child is GPUParticles3D and child.name.contains("ParticulasDisolucionMoradas"):
			found_particles = child
			break

	assert_not_null(found_particles, "Debe generar partículas moradas al activarse")
	if found_particles and found_particles.process_material is ParticleProcessMaterial:
		var pmat = found_particles.process_material as ParticleProcessMaterial
		assert_not_null(pmat.color_ramp, "Las partículas deben tener rampa de color morada")
	player.free()
