extends GutTest

var LonkoScript = load("res://Entities/Enemigo_Lonko/Lonko.gd")
var _lonko: Lonko = null
var _anim_player: AnimationPlayer = null

func before_each() -> void:
	_lonko = LonkoScript.new()
	_lonko.name = "LonkoTest"
	get_tree().root.add_child(_lonko)

	_anim_player = AnimationPlayer.new()
	_anim_player.name = "AnimationPlayer"
	var lib = AnimationLibrary.new()
	var anim_idle = Animation.new()
	anim_idle.length = 5.0
	var anim_hit1 = Animation.new()
	anim_hit1.length = 0.8
	var anim_hit2 = Animation.new()
	anim_hit2.length = 0.7
	var anim_pilar = Animation.new()
	anim_pilar.length = 12.0
	var anim_recarga = Animation.new()
	anim_recarga.length = 0.8
	var anim_disparo = Animation.new()
	anim_disparo.length = 0.5

	lib.add_animation("IDLE", anim_idle)
	lib.add_animation("HIT_01", anim_hit1)
	lib.add_animation("HIT_02", anim_hit2)
	lib.add_animation("PILAR_SUBIDA", anim_pilar)
	lib.add_animation("RECARGA", anim_recarga)
	lib.add_animation("DISPARO", anim_disparo)

	_anim_player.add_animation_library("", lib)
	_lonko.add_child(_anim_player)
	_lonko.anim_player = _anim_player

func after_each() -> void:
	if is_instance_valid(_lonko):
		if _lonko.get_parent():
			_lonko.get_parent().remove_child(_lonko)
		_lonko.free()
		_lonko = null

# ═══════════════════════════════════════════════════════════════════════════════
# TESTS: ANIMACIONES DE IMPACTO / HIT
# ═══════════════════════════════════════════════════════════════════════════════

func test_resolucion_directa_hit_01_y_hit_02():
	# Arrange
	_lonko.anim_player = _anim_player

	# Act 1
	_lonko._play_animation("HIT_01")
	# Assert 1
	assert_eq(_anim_player.current_animation, "HIT_01", "Debe reproducir directamente HIT_01")

	# Act 2
	_lonko._play_animation("HIT_02")
	# Assert 2
	assert_eq(_anim_player.current_animation, "HIT_02", "Debe reproducir directamente HIT_02")


func test_compatibilidad_alias_impacto_a_hit():
	# Arrange: Solo existe HIT_01 y HIT_02 en la librería
	_lonko.anim_player = _anim_player

	# Act 1: Solicitar IMPACTO_01 debe resolver a HIT_01
	_lonko._play_animation("IMPACTO_01")
	# Assert 1
	assert_eq(_anim_player.current_animation, "HIT_01", "IMPACTO_01 debe mapear automáticamente a HIT_01")

	# Act 2: Solicitar IMPACTO_02 debe resolver a HIT_02
	_lonko._play_animation("IMPACTO_02")
	# Assert 2
	assert_eq(_anim_player.current_animation, "HIT_02", "IMPACTO_02 debe mapear automáticamente a HIT_02")


func test_take_damage_reproduce_hit_01_o_hit_02():
	# Arrange
	_lonko.anim_player = _anim_player
	_lonko.health = 6

	# Act
	_lonko.take_damage(1.0)

	# Assert
	var anim_actual: String = _anim_player.current_animation
	assert_true(anim_actual in ["HIT_01", "HIT_02"], "Al recibir daño debe reproducir HIT_01 o HIT_02 (actual: %s)" % anim_actual)
	assert_true(_lonko._is_taking_damage, "Debe marcar el estado de estar recibiendo daño")


# ═══════════════════════════════════════════════════════════════════════════════
# TESTS: ELIMINACIÓN DE ESCALAS EN ANIMACIONES DE LONKO
# ═══════════════════════════════════════════════════════════════════════════════

func test_speed_scale_de_anim_player_es_1_0():
	# Arrange & Act
	_lonko._on_enemy_ready()

	# Assert
	assert_eq(_anim_player.speed_scale, 1.0, "La escala global de velocidad de anim_player debe ser 1.0 (sin escala)")


func test_pilar_subida_reproduce_a_velocidad_1_0():
	# Arrange
	_lonko.anim_player = _anim_player

	# Act
	_lonko._play_animation("PILAR_SUBIDA", 0.2, 1.0)

	# Assert
	assert_eq(_anim_player.current_animation, "PILAR_SUBIDA", "Debe reproducir PILAR_SUBIDA")
	assert_almost_eq(_anim_player.get_playing_speed(), 1.0, 0.01, "PILAR_SUBIDA debe reproducirse a velocidad 1.0 sin escala")


func test_recarga_reproduce_a_velocidad_1_0():
	# Arrange
	_lonko.anim_player = _anim_player

	# Act
	_lonko._play_animation("RECARGA", 0.35, 1.0)

	# Assert
	assert_eq(_anim_player.current_animation, "RECARGA", "Debe reproducir RECARGA")
	assert_almost_eq(_anim_player.get_playing_speed(), 1.0, 0.01, "RECARGA debe reproducirse a velocidad 1.0 sin escala de estiramiento")


func test_idle_no_espeja_escala_negativa_ni_rotacion_anormal():
	# Arrange
	var modelo_dummy := Node3D.new()
	modelo_dummy.name = "LONKO"
	_lonko.add_child(modelo_dummy)
	_lonko._lonko_modelo = modelo_dummy
	_lonko._escala_original_modelo = Vector3(0.85, 0.85, 0.85)
	modelo_dummy.scale = _lonko._escala_original_modelo

	# Act: Ejecutar proceso con IDLE activo
	_lonko._correccion_idle_activa = true
	_lonko._aplicar_yaw_suave(0.1)

	# Assert 1: La escala X NUNCA debe ser negativa en IDLE
	assert_gt(modelo_dummy.scale.x, 0.0, "La escala X en IDLE debe ser positiva (sin espejo invertido)")
	assert_almost_eq(modelo_dummy.scale.x, 0.85, 0.01, "Debe conservar su escala original de 0.85")

	# Assert 2: El yaw objetivo debe ser YAW_BASE_IZQUIERDA (-90 grados, hacia la jugadora)
	assert_almost_eq(_lonko._obtener_yaw_objetivo_grados(), -90.0, 0.1, "En IDLE debe apuntar de frente a la jugadora (-90°)")

