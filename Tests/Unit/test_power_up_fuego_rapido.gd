extends "res://addons/gut/test.gd"

var PowerUpFuegoRapidoScript = load("res://Entities/Item_Fuego_Rapido/PowerUpFuegoRapido.gd")
var PlayerScript = load("res://Entities/Jugador_Arquera/Player.gd")
var BarraCircularFuegoRapidoScript = load("res://Entities/Jugador_Arquera/BarraCircularFuegoRapido.gd")
var AzulinaScript = load("res://Entities/Enemigo_Azulina/Azulina.gd")

var _power_up = null
var _player = null


func before_each():
	_power_up = PowerUpFuegoRapidoScript.new()
	_player = PlayerScript.new()
	_player.add_to_group("player")
	add_child_autofree(_power_up)
	add_child_autofree(_player)


func test_power_up_initialization():
	# Assert
	assert_not_null(_power_up, "El power-up de fuego rápido debe instanciarse correctamente")
	assert_eq(_power_up.duracion_buff, 15.0, "La duración del buff por defecto debe ser de 15.0 segundos")
	assert_eq(_power_up.tiempo_en_pantalla, 3.0, "El tiempo de auto-consumo debe ser de 3.0 segundos")
	assert_eq(_power_up.velocidad_rotacion_y, 3.0, "La velocidad de rotación continua debe ser de 3.0 rad/s")
	assert_true(_power_up.is_in_group("pickups"), "Debe pertenecer al grupo pickups")
	assert_true(_power_up.is_in_group("power_ups_fuego_rapido"), "Debe pertenecer al grupo power_ups_fuego_rapido")


func test_power_up_consumo_activa_fuego_rapido():
	# Arrange
	_player.fuego_rapido_activo = false
	_player.fuego_rapido_timer = 0.0

	# Act
	_power_up._auto_consumir()

	# Assert
	assert_true(_player.fuego_rapido_activo, "El jugador debe tener el buff fuego_rapido_activo = true")
	assert_eq(_player.fuego_rapido_timer, 15.0, "El temporizador debe iniciarse en 15.0 segundos")
	assert_eq(_power_up.current_state, PowerUpFuegoRapido.State.DISSOLVING, "El power-up debe pasar al estado DISSOLVING")


func test_sin_inmortalidad_durante_fuego_rapido():
	# Arrange
	_player.health = 5
	_player.activar_fuego_rapido(15.0)

	# Act: Intentar dañar al jugador mientras tiene el buff activo
	_player.recibir_dano(1)

	# Assert: Inmortalidad eliminada, el jugador recibe daño
	assert_eq(_player.health, 4, "El jugador SÍ debe recibir daño aunque fuego_rapido_activo sea true (inmortalidad eliminada)")

	# Act 2: Desactivar buff y volver a recibir daño
	_player.desactivar_fuego_rapido()
	_player.is_invulnerable = false
	_player.recibir_dano(1)

	# Assert: Debe recibir daño normal tras expirar el buff
	assert_eq(_player.health, 3, "El jugador debe seguir recibiendo daño normal al expirar fuego rápido")


func test_disparo_normal_sale_a_maxima_potencia_con_fuego_rapido():
	# Arrange: Activar fuego rápido y seleccionar munición normal sin cargar arco
	_player.activar_fuego_rapido(15.0)
	_player.municion_activa = Player.TipoMunicion.NORMAL
	_player.charge_time = 0.0
	_player.state_timer = 0.0

	# Act: Disparar sin tensar (tap fire)
	_player.start_shooting()

	# Assert: La potencia debe ser forzada al 100% (1.0)
	assert_eq(_player.last_charge_power, 1.0, "Los disparos normales con fuego rápido deben salir siempre al 100% de potencia")


func test_velocidad_disparo_aumentada_30_porciento():
	# Arrange: Sin buff
	_player.fuego_rapido_activo = false
	_player.multiplicador_velocidad_disparo = 1.0
	assert_almost_eq(_player._get_multiplicador_velocidad_disparo_total(), 1.0, 0.001, "Velocidad base debe ser 1.0")

	# Act: Activar fuego rápido
	_player.activar_fuego_rapido(15.0)

	# Assert: Multiplicador total debe ser 1.3 (+30%)
	assert_almost_eq(_player._get_multiplicador_velocidad_disparo_total(), 1.3, 0.001, "La velocidad de disparo debe ser 30% mayor (1.3x)")


func test_acumulacion_reinicio_duracion():
	# Arrange: Buff a mitad de tiempo
	_player.activar_fuego_rapido(6.0)
	assert_eq(_player.fuego_rapido_timer, 6.0)

	# Act: Recoger otro power-up de fuego rápido
	_power_up.current_state = PowerUpFuegoRapido.State.IDLE
	_power_up._auto_consumir()

	# Assert: El temporizador se reinicia al valor completo de 15s
	assert_eq(_player.fuego_rapido_timer, 15.0, "Recoger otro power up debe refrescar la duración a 15 segundos")


func test_desactivar_fuego_rapido_limpia_aura_y_audio():
	# Arrange
	_player.activar_fuego_rapido(15.0)
	assert_true(_player.fuego_rapido_activo)

	# Act
	_player.desactivar_fuego_rapido()

	# Assert
	assert_false(_player.fuego_rapido_activo, "El flag activo debe ser false")
	assert_eq(_player.fuego_rapido_timer, 0.0, "El timer debe quedar en 0")
	assert_null(_player._aura_fuego_rapido_node, "El nodo del aura debe eliminarse y quedar en null")
	assert_null(_player._aura_fuego_rapido_audio, "El nodo de audio debe eliminarse y quedar en null")


func test_escena_real_instanciacion():
	# Arrange & Act: Cargar e instanciar la escena tscn real
	var escena: PackedScene = load("res://Entities/Item_Fuego_Rapido/PowerUpFuegoRapido.tscn")
	var pu = escena.instantiate()
	add_child_autofree(pu)

	# Assert
	assert_not_null(pu, "La escena PowerUpFuegoRapido.tscn debe instanciarse")
	var model_root = pu.get_node_or_null("ModelRoot")
	assert_not_null(model_root, "Debe contener ModelRoot")
	var fire_light = pu.get_node_or_null("FireLight")
	assert_not_null(fire_light, "Debe contener FireLight")
	var fire_particles = pu.get_node_or_null("FireParticles")
	assert_not_null(fire_particles, "Debe contener FireParticles")

	# Consumo real
	_player.fuego_rapido_activo = false
	pu._auto_consumir()
	assert_true(_player.fuego_rapido_activo, "El jugador debe recibir el buff desde la escena real")
	assert_eq(pu.current_state, PowerUpFuegoRapido.State.DISSOLVING)


func test_barra_circular_fuego_rapido_activa_y_desactiva():
	# Arrange
	_player.fuego_rapido_activo = false

	# Act: Activar fuego rápido
	_player.activar_fuego_rapido(15.0)

	# Assert
	assert_not_null(_player.barra_circular_fuego_rapido, "La barra circular debe estar instanciada")
	assert_true(_player.barra_circular_fuego_rapido.visible, "La barra circular debe ser visible durante el efecto")
	assert_eq(_player.barra_circular_fuego_rapido.progress, 1.0, "El progreso inicial debe ser 1.0 (100%)")
	assert_eq(_player.barra_circular_fuego_rapido.color_progreso, Color(1.0, 0.35, 0.8, 0.95), "El color de la barra debe ser rosado")

	# Act 2: Desactivar fuego rápido
	_player.desactivar_fuego_rapido()

	# Assert 2
	assert_false(_player.barra_circular_fuego_rapido.visible, "La barra circular debe ocultarse al desactivar el efecto")


func test_barra_circular_fuego_rapido_dibujado():
	# Arrange
	var barra = BarraCircularFuegoRapidoScript.new()
	add_child_autofree(barra)
	barra.progress = 0.5
	barra.tiempo_restante = 7.5

	# Act & Assert
	assert_eq(barra.progress, 0.5)
	assert_eq(barra.size, Vector2(40.0, 40.0))
	assert_eq(barra.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_flecha_fuego_rapido_meta_y_no_se_desvia_en_azulina():
	# Arrange: Crear Azulina
	var azulina = AzulinaScript.new()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	azulina.probabilidad_desvio_normal = 1.0  # Forzar 100% de probabilidad de desvío
	azulina.ataques_para_parry_min = 4
	azulina.ataques_para_parry_max = 4
	azulina._emergiendo = false
	add_child_autofree(azulina)

	# Crear flecha simulada con meta fuego_rapido
	var flecha_fr := Node3D.new()
	flecha_fr.set_meta("fuego_rapido", true)
	add_child_autofree(flecha_fr)

	# Flecha normal sin fuego_rapido
	var flecha_normal := Node3D.new()
	add_child_autofree(flecha_normal)

	# Act & Assert 1: La flecha normal con 100% prob SI se desvía
	var repelido_normal: bool = azulina.manejar_impacto_aura(flecha_normal)
	assert_true(repelido_normal, "La flecha normal debe ser desviada con 100% prob de desvío")

	# Resetear estado de desvío
	azulina._desviando_giro = false
	azulina._impactos_recientes.clear()
	azulina._contador_ataques = 0

	# Act & Assert 2: La flecha con fuego_rapido NUNCA se desvía con giro lanza parry
	var repelido_fr: bool = azulina.manejar_impacto_aura(flecha_fr)
	assert_false(repelido_fr, "La flecha de fuego rápido NO debe desviarse con giro lanza parry")
	assert_false(azulina._desviando_giro, "No debe iniciar la animación de desvío")

	# Act & Assert 3: Flechas sucesivas con fuego rápido NO incrementan contador ni activan lanza casteo
	for i in range(10):
		var resultado: bool = azulina.manejar_impacto_aura(flecha_fr)
		assert_false(resultado, "Impacto múltiple con fuego rápido no debe ser repelido")
		assert_false(azulina._parry_activo, "Fuego rápido no debe desencadenar lanza casteo (_parry_activo)")
	assert_eq(azulina._contador_ataques, 0, "El contador de ataques no debe incrementarse con fuego rápido")


func test_azulina_drop_fuego_rapido_probabilidad_y_ejecucion():
	# Arrange: Instanciar Azulina
	var azulina = AzulinaScript.new()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	azulina._emergiendo = false
	add_child_autofree(azulina)

	# Assert 1: Configuración base
	assert_not_null(azulina.power_up_fuego_rapido_scene, "Debe tener configurada la escena de fuego rápido")
	assert_eq(azulina.probabilidad_drop_fuego_rapido, 0.05, "La probabilidad de drop base debe ser del 5% (0.05)")

	# Act & Assert 2: Con probabilidad 0%, no debe spawnear nada
	azulina.probabilidad_drop_fuego_rapido = 0.0
	var hijos_antes: int = get_tree().root.get_child_count()
	azulina._dropear_power_up()
	var hijos_despues: int = get_tree().root.get_child_count()
	assert_eq(hijos_despues, hijos_antes, "Con probabilidad 0.0 no debe instanciar el drop")

	# Act & Assert 3: Con probabilidad 1.0 (forzada para el test), debe spawnear en el árbol
	var azulina2 = AzulinaScript.new()
	azulina2.emerger_del_agua = false
	azulina2.emergencia_en_zona_aleatoria = false
	azulina2._emergiendo = false
	azulina2.probabilidad_drop_fuego_rapido = 1.0
	add_child_autofree(azulina2)

	azulina2._dropear_power_up()
	assert_true(azulina2._drop_realizado, "_drop_realizado debe ser true tras ejecutar el drop")

	var drops := get_tree().get_nodes_in_group("power_ups_fuego_rapido")
	assert_gt(drops.size(), 0, "Debe haberse instanciado un nodo de Fuego Rápido en la escena")
	for d in drops:
		if d != _power_up:
			d.queue_free()


func test_fuego_rapido_no_afecta_otros_power_ups():
	# Arrange: Activar fuego rápido
	_player.activar_fuego_rapido(15.0)
	_player.health = 5

	# Act & Assert 1: Con munición NORMAL, velocidad es 1.3x
	_player.municion_activa = Player.TipoMunicion.NORMAL
	assert_almost_eq(_player._get_multiplicador_velocidad_disparo_total(), 1.3, 0.001, "Disparo normal debe tener 1.3x")

	# Act & Assert 2: Con munición EXPLOSIVA, velocidad vuelve a 1.0 (sin efecto en comportamiento)
	_player.municion_activa = Player.TipoMunicion.EXPLOSIVA
	_player.flechas_explosivas = 5
	assert_almost_eq(_player._get_multiplicador_velocidad_disparo_total(), 1.0, 0.001, "Flecha explosiva no debe verse acelerada por fuego rápido (1.0x)")

	# Ya no es inmortal
	_player.recibir_dano(2)
	assert_eq(_player.health, 3, "Recibe daño normalmente aún con flechas explosivas activas")

	# Mantiene aura activa
	assert_true(_player.fuego_rapido_activo, "Fuego rápido sigue activo")
	assert_not_null(_player._aura_fuego_rapido_node, "El nodo del aura sigue presente")

	# Act & Assert 3: Con munición MULTIPLE, velocidad vuelve a 1.0 (sin efecto en comportamiento)
	_player.municion_activa = Player.TipoMunicion.MULTIPLE
	_player.flechas_multiples = 5
	assert_almost_eq(_player._get_multiplicador_velocidad_disparo_total(), 1.0, 0.001, "Flecha múltiple no debe verse acelerada por fuego rápido (1.0x)")

	# Ya no es inmortal con munición múltiple
	_player.is_invulnerable = false
	_player.recibir_dano(2)
	assert_eq(_player.health, 1, "Recibe daño normalmente aún con flechas múltiples activas")


