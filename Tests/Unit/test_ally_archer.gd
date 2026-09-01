extends "res://addons/gut/test.gd"

var AllyArcherScript = load("res://Entities/Aliada_Arquera/AllyArcher.gd")
var _ally: AllyArcher = null

# Mock para AudioManager
class MockAudioManager extends Node:
	func play_sfx(_name, _boost = 0.0): pass
	func stop_bow_tension(): pass
	func reset_bow_hold(): pass

var _mock_audio_created: bool = false

func before_each():
	_ally = AllyArcherScript.new()
	_agregar_animacion_minima(_ally)

	if not get_tree().root.has_node("AudioManager"):
		var mock_audio = MockAudioManager.new()
		mock_audio.name = "AudioManager"
		get_tree().root.add_child(mock_audio)
		_mock_audio_created = true

	get_tree().root.add_child(_ally)

func after_each():
	if is_instance_valid(_ally):
		if _ally.get_parent():
			_ally.get_parent().remove_child(_ally)
		_ally.free()

	if _mock_audio_created and get_tree().root.has_node("AudioManager"):
		var mock_audio = get_tree().root.get_node("AudioManager")
		get_tree().root.remove_child(mock_audio)
		mock_audio.free()
		_mock_audio_created = false

func _agregar_animacion_minima(ally: AllyArcher) -> void:
	var anim_player := AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	
	var lib = AnimationLibrary.new()
	lib.add_animation("IDLE", Animation.new())
	lib.add_animation("IDE", Animation.new())
	lib.add_animation("IDLE_EXAMINAR", Animation.new())
	lib.add_animation("IDLE_APUNTANDO", Animation.new())
	lib.add_animation("TOMAR_FLECHA", Animation.new())
	lib.add_animation("DISPARAR_FLECHA", Animation.new())
	lib.add_animation("MUERTE_01", Animation.new())
	lib.add_animation("MUERTE_02", Animation.new())
	lib.add_animation("AGACHARSE", Animation.new())
	lib.add_animation("ATERRIZAJE_POST_SALTO_01", Animation.new())
	lib.add_animation("LEVANTARSE", Animation.new())
	lib.add_animation("VICTORIA", Animation.new())
	lib.add_animation("ELECTROCUTAR", Animation.new())
	lib.add_animation("DAÑO_01", Animation.new())
	lib.add_animation("DAÑO_02", Animation.new())
	
	anim_player.add_animation_library("", lib)
	ally.add_child(anim_player)

func test_inicializacion_vida():
	assert_eq(_ally.vida_maxima, 2, "La vida máxima por defecto debería ser 2")
	assert_eq(_ally.health, 2, "La salud inicial debería coincidir con vida_maxima")

func test_recibir_dano_no_muere():
	_ally.recibir_dano(1)
	assert_eq(_ally.health, 1, "La salud debería reducirse a 1")
	assert_ne(_ally.current_state, _ally.State.DYING, "No debería estar muriendo con salud > 0")

func test_recibir_dano_muere_y_permanece():
	_ally.recibir_dano(2)
	assert_eq(_ally.health, 0, "La salud debería reducirse a 0")
	assert_eq(_ally.current_state, _ally.State.DYING, "El estado debería ser DYING al quedarse sin salud")
	
	# Simular el timer que pasa de DYING a DEAD
	# Llamamos directamente a la transición para evitar esperar en el test
	_ally._cambiar_estado(_ally.State.DEAD)
	assert_eq(_ally.current_state, _ally.State.DEAD, "El estado debería cambiar a DEAD")
	assert_true(is_instance_valid(_ally), "La arquera debería permanecer en la escena (no autodestruirse)")

func test_revivir_desde_muerta():
	# Forzar estado muerto
	_ally.health = 0
	_ally.current_state = _ally.State.DEAD
	_ally.set_process(false)
	if _ally.hitbox_body:
		_ally.hitbox_body.collision_layer = 0

	_ally.revivir()

	assert_eq(_ally.health, _ally.vida_maxima, "La salud debería restablecerse a vida_maxima")
	assert_eq(_ally.current_state, _ally.State.GETTING_UP, "El estado debería cambiar a GETTING_UP")
	assert_true(_ally.is_processing(), "El procesamiento del nodo debería estar activo")
	if _ally.hitbox_body:
		assert_eq(_ally.hitbox_body.collision_layer, 2, "El hitbox debería volver a la capa de colisión 2")

func test_revivir_rotacion_muerte_01():
	# Crear un model_root dummy para testear rotación
	var dummy_model = Node3D.new()
	dummy_model.name = "ArqueraModel"
	_ally.add_child(dummy_model)
	_ally.model_root = dummy_model
	_ally._original_model_y_rot = 0.0
	
	# Forzar muerte con MUERTE_01
	_ally.ultima_muerte_anim = "MUERTE_01"
	_ally.current_state = _ally.State.DEAD
	
	_ally.revivir()
	
	assert_almost_eq(dummy_model.rotation.y, deg_to_rad(90), 0.0001, "El modelo debería estar rotado 90 grados en Y durante GETTING_UP si la muerte fue MUERTE_01")
	
	# Transicionar fuera de GETTING_UP debería restaurar la rotación original
	_ally._cambiar_estado(_ally.State.IDLE)
	await wait_seconds(0.4)
	assert_eq(dummy_model.rotation.y, 0.0, "La rotación debería restaurarse al salir de GETTING_UP")

func test_invulnerable_durante_getting_up():
	_ally.health = 2
	_ally.current_state = _ally.State.GETTING_UP
	_ally.take_damage(1.0)
	assert_eq(_ally.health, 2, "No debería recibir daño durante el estado GETTING_UP")

func test_enemigos_minimos_es_uno():
	assert_eq(_ally.enemigos_minimos, 1, "Las arqueras aliadas deben empezar a disparar con al menos 1 enemigo")


func test_celebracion_victoria_activacion_y_rotacion():
	var dummy_model = Node3D.new()
	dummy_model.name = "ArqueraModel"
	_ally.add_child(dummy_model)
	_ally.model_root = dummy_model
	_ally._original_model_y_rot = 0.0
	_ally.anim_player = _ally.find_child("AnimationPlayer", true, false)

	_ally.celebrar_victoria()

	assert_eq(_ally.current_state, _ally.State.CELEBRATING, "El estado debe cambiar a CELEBRATING")
	assert_gt(_ally._loops_victoria_restantes, 0, "Debe tener loops de victoria asignados")

	# Simular un frame de proceso para verificar rotación de victoria
	_ally._process(0.1)
	assert_gt(dummy_model.rotation.y, 0.0, "El modelo debe rotar suavemente hacia la derecha durante la celebración")


func test_celebracion_victoria_loops_y_retorno_idle():
	_ally.anim_player = _ally.find_child("AnimationPlayer", true, false)
	_ally.celebrar_victoria()
	_ally._loops_victoria_restantes = 2

	# Simular fin de primer loop
	_ally.state_timer = 0.0
	_ally._process_celebrating(0.01)
	assert_eq(_ally._loops_victoria_restantes, 1, "Debe decrementar a 1 loop restante")
	assert_eq(_ally.current_state, _ally.State.CELEBRATING, "Debe permanecer en CELEBRATING")

	# Simular fin del último loop
	_ally.state_timer = 0.0
	_ally._process_celebrating(0.01)
	assert_eq(_ally._loops_victoria_restantes, 0, "Los loops restantes deben ser 0")
	assert_eq(_ally.current_state, _ally.State.IDLE, "Debe volver a IDLE tras completar la celebración")


func test_on_oleada_completada_activa_celebracion():
	_ally.anim_player = _ally.find_child("AnimationPlayer", true, false)
	_ally._on_oleada_completada(1)

	assert_eq(_ally.current_state, _ally.State.CELEBRATING, "El evento de oleada completada debe activar la celebración de victoria")


func test_ataque_suelta_flecha_al_segundo_3():
	_ally.anim_player = _ally.find_child("AnimationPlayer", true, false)
	_ally._cambiar_estado(_ally.State.SHOOTING)
	assert_eq(_ally.current_state, _ally.State.SHOOTING, "Debe entrar en estado SHOOTING")
	assert_false(_ally._flecha_soltada, "La flecha no debe haberse soltado al inicio del ataque")

	# Simular 2 segundos de animación (aún no llega al segundo 3)
	_ally._process_shooting(2.0)
	assert_false(_ally._flecha_soltada, "La flecha todavía no debe haberse soltado en t=2.0s")

	# Simular 1 segundo más (t=3.0s, momento exacto de suelta)
	_ally._process_shooting(1.0)
	assert_true(_ally._flecha_soltada, "La flecha debe haberse soltado al alcanzar el segundo 3.0")


func test_on_oleada_iniciada_activa_idle():
	_ally.anim_player = _ally.find_child("AnimationPlayer", true, false)
	_ally._on_oleada_iniciada(1)

	assert_eq(_ally.current_state, _ally.State.IDLE, "El estado debe ser IDLE al iniciar la oleada")
	assert_eq(_ally.anim_player.current_animation, "IDE", "Debe reproducir la animación IDE al inicio de la oleada")


func test_idle_examinar_ciclo_fuera_de_combate():
	_ally.anim_player = _ally.find_child("AnimationPlayer", true, false)
	_ally._cambiar_estado(_ally.State.IDLE)
	assert_eq(_ally.anim_player.current_animation, "IDE", "Debe iniciar en IDE")
	assert_false(_ally._examinando, "No debe estar examinando inicialmente")

	# Forzar fin del temporizador de examinar
	_ally._tiempo_para_examinar = 0.0
	_ally._process_idle(0.1)

	assert_true(_ally._examinando, "Debe pasar a estado examinando")
	assert_eq(_ally.anim_player.current_animation, "IDLE_EXAMINAR", "Debe reproducir IDLE_EXAMINAR")

	# Simular que termina la animación de examinar
	_ally.state_timer = 0.0
	_ally._process_idle(0.1)

	assert_false(_ally._examinando, "Debe regresar del modo examinar")
	assert_eq(_ally.anim_player.current_animation, "IDE", "Debe volver a la animación IDE")

