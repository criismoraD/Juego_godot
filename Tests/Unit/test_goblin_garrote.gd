extends "res://addons/gut/test.gd"
## Tests unitarios del enemigo Goblin con Garrote (GoblinGarrote).
## Valida instanciación, valores por defecto, animaciones, lógica de bloqueo melee al 25%,
## inmunidad del bloqueo a ataques no-melee, y desmembramiento explosivo soltando el garrote.

const ESCENA_GOBLIN_GARROTE := preload("res://Entities/Enemigo_Goblin_Garrote/GoblinGarrote.tscn")
const SCRIPT_GOBLIN_GARROTE := preload("res://Entities/Enemigo_Goblin_Garrote/GoblinGarrote.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# TESTS DE INICIALIZACIÓN Y ESTRUCTURA
# ═══════════════════════════════════════════════════════════════════════════════

func test_instanciacion_y_valores_iniciales() -> void:
	# Arrange & Act
	var goblin := ESCENA_GOBLIN_GARROTE.instantiate() as GoblinGarrote
	add_child(goblin)

	# Assert
	assert_not_null(goblin, "La escena GoblinGarrote debe instanciarse correctamente")
	assert_eq(goblin.estado_melee, GoblinGarrote.EstadoMelee.CORRIENDO, "El goblin garrote debe iniciar en estado CORRIENDO")
	assert_eq(goblin.velocidad_correr, 2.4, "La velocidad de correr debe ser 2.4")
	assert_eq(goblin.probabilidad_bloqueo, 0.25, "La probabilidad de bloqueo melee por defecto debe ser 25% (0.25)")
	assert_eq(goblin.alcance_melee, 1.35, "El alcance melee por defecto debe ser 1.35")
	assert_eq(goblin.dano_cuerpo_a_cuerpo, 1, "El daño cuerpo a cuerpo por defecto debe ser 1")

	# Verificar que el garrote está fijado a la mano derecha
	var garrote := goblin.find_child("GarroteGoblin", true, false)
	assert_not_null(garrote, "Debe tener el nodo GarroteGoblin en su jerarquía")

	# Verificar que tiene PartesExplotadas para desmembramiento
	var partes := goblin.find_child("PartesExplotadas", true, false)
	assert_not_null(partes, "Debe tener el nodo PartesExplotadas para desmembramiento")

	goblin.queue_free()


func test_animaciones_requeridas_disponibles() -> void:
	# Arrange
	var goblin := ESCENA_GOBLIN_GARROTE.instantiate() as GoblinGarrote
	add_child(goblin)

	# Act
	var anim_player := goblin.find_child("AnimationPlayer", true, false) as AnimationPlayer

	# Assert
	assert_not_null(anim_player, "Debe existir un AnimationPlayer en el modelo")
	assert_true(anim_player.has_animation("correr con garrote") or anim_player.has_animation("Correr"),
		"Debe tener la animación 'correr con garrote' o 'Correr'")
	assert_true(anim_player.has_animation("Ataque melee"), "Debe tener la animación 'Ataque melee'")
	assert_true(anim_player.has_animation("Bloqueo"), "Debe tener la animación 'Bloqueo'")
	assert_true(anim_player.has_animation("Idle"), "Debe tener la animación 'Idle'")

	goblin.queue_free()


func test_animacion_correr_garrote_activada_correctamente() -> void:
	# Arrange
	var goblin := ESCENA_GOBLIN_GARROTE.instantiate() as GoblinGarrote
	add_child(goblin)

	# Act
	goblin._forzar_animacion_correr()

	# Assert
	var anim_player := goblin.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert_not_null(anim_player, "Debe tener AnimationPlayer")
	var anim_activa: String = anim_player.current_animation.to_lower()
	assert_true("correr" in anim_activa, "Debe estar reproduciendo animación de correr")
	if anim_player.has_animation("correr con garrote"):
		assert_eq(anim_player.current_animation, "correr con garrote",
			"Debe reproducir específicamente 'correr con garrote'")

	goblin.queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# TESTS DE BLOQUEO CUERPO A CUERPO (MELEE)
# ═══════════════════════════════════════════════════════════════════════════════

func test_bloqueo_melee_exitoso_anula_dano_y_activa_estado_bloqueo() -> void:
	# Arrange: Forzar probabilidad de bloqueo al 100%
	var goblin := ESCENA_GOBLIN_GARROTE.instantiate() as GoblinGarrote
	add_child(goblin)
	goblin.probabilidad_bloqueo = 1.0
	var vida_inicial: int = goblin.health

	# Act: Simular golpe cuerpo a cuerpo
	var bloqueado: bool = goblin.recibir_golpe_melee(1, null)

	# Assert: El daño debe ser completamente anulado y pasar a BLOQUEANDO
	assert_true(bloqueado, "El ataque melee debe ser reportado como bloqueado")
	assert_eq(goblin.health, vida_inicial, "La salud no debe disminuir al bloquear un ataque")
	assert_eq(goblin.estado_melee, GoblinGarrote.EstadoMelee.BLOQUEANDO, "El estado debe cambiar a BLOQUEANDO")

	goblin.queue_free()


func test_bloqueo_melee_fallido_aplica_dano() -> void:
	# Arrange: Forzar probabilidad de bloqueo al 0%
	var goblin := ESCENA_GOBLIN_GARROTE.instantiate() as GoblinGarrote
	add_child(goblin)
	goblin.probabilidad_bloqueo = 0.0
	var vida_inicial: int = goblin.health

	# Act: Simular golpe cuerpo a cuerpo sin éxito en el bloqueo
	var bloqueado: bool = goblin.recibir_golpe_melee(1, null)

	# Assert: El daño debe aplicarse y no bloquearse
	assert_false(bloqueado, "El ataque melee no debe bloquearse si la probabilidad falla")
	assert_eq(goblin.health, vida_inicial - 1, "La salud debe reducirse en la cantidad de daño recibida")

	goblin.queue_free()


func test_ataques_no_melee_no_pueden_ser_bloqueados() -> void:
	# Arrange: Goblin con 100% de probabilidad de bloqueo melee
	var goblin := ESCENA_GOBLIN_GARROTE.instantiate() as GoblinGarrote
	add_child(goblin)
	goblin.probabilidad_bloqueo = 1.0
	var vida_inicial: int = goblin.health

	# Act: Daño a distancia (proyectil/flecha, es_melee = false)
	goblin.take_damage(1.0, false)

	# Assert: El bloqueo NO debe actuar contra ataques a distancia
	assert_eq(goblin.health, vida_inicial - 1, "Ataques que no son melee deben infligir daño directo sin bloqueo")
	assert_ne(goblin.estado_melee, GoblinGarrote.EstadoMelee.BLOQUEANDO, "El goblin no debe bloquear ataques a distancia")

	goblin.queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# TESTS DE MUERTE EXPLOSIVA Y SUELTA DE GARROTE
# ═══════════════════════════════════════════════════════════════════════════════

func test_muerte_explosiva_suelta_garrote_con_fisica_y_desmiembra() -> void:
	# Arrange
	var goblin := ESCENA_GOBLIN_GARROTE.instantiate() as GoblinGarrote
	add_child(goblin)
	goblin.murio_por_explosion = true

	# Act: Ejecutar la rutina de muerte
	goblin._on_state_dying()

	# Assert: El goblin debe haber pasado a muriendo y soltado el garrote
	assert_eq(goblin.estado_melee, GoblinGarrote.EstadoMelee.MURIENDO, "El goblin debe estar en estado MURIENDO")

	# Las colisiones del cuerpo deben haberse desactivado
	assert_eq(goblin.collision_layer, 0, "La capa de colisión del goblin debe ser 0 tras explotar")
	assert_eq(goblin.collision_mask, 0, "La máscara de colisión del goblin debe ser 0 tras explotar")

	goblin.queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# TESTS DE LÍMITES Y ENTRADAS INVÁLIDAS (BOUNDARY CONDITIONS)
# ═══════════════════════════════════════════════════════════════════════════════

func test_recibir_golpe_melee_con_dano_cero_o_negativo() -> void:
	# Arrange
	var goblin := ESCENA_GOBLIN_GARROTE.instantiate() as GoblinGarrote
	add_child(goblin)
	goblin.probabilidad_bloqueo = 0.0
	var vida_inicial: int = goblin.health

	# Act: Aplicar daño 0 y daño negativo
	goblin.recibir_golpe_melee(0, null)
	goblin.recibir_golpe_melee(-5, null)

	# Assert: La salud no debe cambiar negativamente
	assert_eq(goblin.health, vida_inicial, "Daño 0 o negativo no debe reducir ni incrementar salud")

	goblin.queue_free()


func test_recibir_golpe_melee_cuando_ya_esta_muerto() -> void:
	# Arrange
	var goblin := ESCENA_GOBLIN_GARROTE.instantiate() as GoblinGarrote
	add_child(goblin)
	goblin.health = 0
	goblin.current_state = GoblinGarrote.State.DEAD
	goblin.estado_melee = GoblinGarrote.EstadoMelee.DEAD

	# Act
	var resultado: bool = goblin.recibir_golpe_melee(1, null)

	# Assert
	assert_false(resultado, "No debe procesar ni bloquear golpes cuando ya está muerto")

	goblin.queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# TESTS DE SANGRE LETAL Y SILENCIADO DE AUDIO
# ═══════════════════════════════════════════════════════════════════════════════

func test_sangre_letal_se_spawnea_al_morir() -> void:
	# Arrange
	var goblin := ESCENA_GOBLIN_GARROTE.instantiate() as GoblinGarrote
	add_child(goblin)
	assert_false(goblin._sangre_letal_spawneada, "Inicialmente no debe haber spawneado sangre letal")

	# Act
	goblin._on_state_dying()

	# Assert
	assert_true(goblin._sangre_letal_spawneada, "Al entrar en estado dying debe activarse _sangre_letal_spawneada")

	goblin.queue_free()


func test_sangre_letal_no_duplica_en_multiples_llamadas() -> void:
	# Arrange
	var goblin := ESCENA_GOBLIN_GARROTE.instantiate() as GoblinGarrote
	add_child(goblin)

	# Act
	goblin._crear_splash_sangre_letal()
	var conteo_hijos_antes: int = get_child_count()
	goblin._crear_splash_sangre_letal()
	var conteo_hijos_despues: int = get_child_count()

	# Assert
	assert_eq(conteo_hijos_antes, conteo_hijos_despues, "Llamar a _crear_splash_sangre_letal múltiples veces no debe duplicar instancias")

	goblin.queue_free()


func test_silenciar_audio_evita_reproducir_sfx() -> void:
	# Arrange
	var goblin := ESCENA_GOBLIN_GARROTE.instantiate() as GoblinGarrote
	add_child(goblin)
	goblin.silenciar_audio = true

	# Act & Assert: No debe causar error ni intentar reproducir en AudioManager
	goblin._play_sfx("cualquier_sfx")
	assert_true(goblin.silenciar_audio, "silenciar_audio debe permanecer en true")

	goblin.queue_free()

