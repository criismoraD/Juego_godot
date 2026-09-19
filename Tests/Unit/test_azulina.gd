extends "res://addons/gut/test.gd"

## Tests unitarios de la enemiga Azulina y su lanza.
## Cubren instanciación, valores de combate, emergencia desde el agua,
## lanzamiento preciso y registro en WaveSpawner (id 11) para el botón Debug.

const ESCENA_AZULINA: String = "res://Entities/Enemigo_Azulina/Azulina.tscn"
const MARGEN_FLOAT: float = 0.01


func _crear_azulina() -> Azulina:
	var packed := load(ESCENA_AZULINA) as PackedScene
	assert_not_null(packed, "La escena de Azulina debe cargar correctamente")
	var azulina := packed.instantiate() as Azulina
	assert_not_null(azulina, "Debe instanciar una Azulina")
	add_child_autofree(azulina)
	return azulina


# === ESTRUCTURA Y VALORES ===
func test_instanciar_azulina_completa() -> void:
	# Arrange & Act
	var azulina := _crear_azulina()

	# Assert
	assert_true(azulina is EnemyBase, "Azulina debe ser un EnemyBase")
	assert_true(azulina.is_in_group("enemies"), "Debe estar en el grupo de enemigos")
	assert_not_null(azulina.find_child("AzulinaModel", true, false), "Debe tener el modelo GLB")
	assert_true(azulina.find_child("LanzaMano", true, false) != null or azulina.find_child("lanza giro parry", true, false) != null, "Debe llevar la lanza en mano")
	assert_not_null(azulina.find_child("CollisionShape3D", true, false), "Debe tener colisión")
	assert_eq(azulina.vida_maxima, 3, "3 de vida base")


func test_valores_combate_potentes_y_precisos() -> void:
	# Arrange & Act
	var azulina := _crear_azulina()

	# Assert: más potente y precisa que el tridente del imp (8 vel, 1.2 grav, 2.0 daño)
	assert_gt(azulina.velocidad_lanza, 8.0, "Lanza más rápida que el tridente")
	assert_lt(azulina.gravedad_lanza, 1.2, "Trayectoria más tensa que el tridente")
	assert_lt(azulina.dispersion_rad, 0.1, "Dispersión mínima: precisión alta")
	assert_eq(LanzaAzulinaProjectile.DANO_LANZA_AZULINA, 1.0, "Daño de lanza")


# === EMERGENCIA DEL AGUA ===
func test_emergencia_trayectoria_y_aterrizaje() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	azulina.aterrizar_en_centro = false
	var destino := Vector3(2.0, 0.5, 0.0)

	# Act
	azulina.emerger_en(destino)
	assert_true(azulina._emergiendo, "Debe estar emergiendo")
	var origen: Vector3 = azulina.global_position
	assert_gt(origen.x, destino.x - 0.01, "Nace a la derecha del destino")
	assert_lt(origen.y, destino.y, "Nace hundida bajo el destino")

	# Act: simular la emergencia completa
	var t: float = 0.0
	while azulina._emergiendo and t < 10.0:
		azulina._procesar_emergencia(0.1)
		t += 0.1

	# Assert: aterriza en el destino y retoma
	assert_false(azulina._emergiendo, "Debe terminar la emergencia")
	assert_almost_eq(azulina.global_position.x, destino.x, MARGEN_FLOAT, "Aterriza en X")
	assert_almost_eq(azulina.global_position.y, destino.y, MARGEN_FLOAT, "Aterriza en Y")
	assert_almost_eq(azulina.global_position.z, destino.z, MARGEN_FLOAT, "Cae hacia el fondo")
	_limpiar_lanzas()
	_limpiar_salpicaduras()


# === SALTO ACUÁTICO: ÁPICE (1), CAÍDA (2) Y REMATE ===
func test_apice_por_encima_de_origen_y_caida() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	var destino := Vector3(2.0, 0.5, 0.0)

	# Act
	azulina.emerger_en(destino)
	var apice: Vector3 = azulina.calcular_apice_salto()

	# Assert: el ápice supera tanto el agua (origen) como el terreno (caída)
	assert_gt(apice.y, destino.y, "El ápice debe estar sobre el punto de caída")
	assert_gt(apice.y, azulina.global_position.y, "El ápice debe estar sobre el punto de spawn en el agua")
	assert_almost_eq(apice.y, destino.y + 0.75, MARGEN_FLOAT, "Ápice = punto medio + altura del arco")
	_limpiar_salpicaduras()


func test_tramo_final_acelera_animacion() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	azulina.aterrizar_en_centro = false
	azulina.acelerar_tramo_final = true
	azulina.inicio_tramo_final = 0.55
	azulina.velocidad_tramo_final = 1.7
	var destino := Vector3(2.0, 0.5, 0.0)

	# Act: arrancar el salto (tramo inicial sin acelerar)
	azulina.emerger_en(destino)
	var base: float = azulina._velocidad_salto_base
	azulina._procesar_emergencia(0.1)

	# Assert: velocidad base antes del punto
	assert_almost_eq(azulina.anim_player.speed_scale, base, MARGEN_FLOAT, "Tramo inicial normal")

	# Act: avanzar pasado el punto de aceleración
	var t: float = 0.1
	while azulina._emergiendo and t < 10.0:
		azulina._procesar_emergencia(0.1)
		t += 0.1
		if t > azulina.duracion_emergencia * 0.6:
			break

	# Assert: acelerado y al aterrizar restaura
	assert_almost_eq(azulina.anim_player.speed_scale, base * 1.7, MARGEN_FLOAT, "Tramo final acelerado")
	while azulina._emergiendo and t < 20.0:
		azulina._procesar_emergencia(0.1)
		t += 0.1
	assert_almost_eq(azulina.anim_player.speed_scale, base, MARGEN_FLOAT, "Restaura al aterrizar")
	_limpiar_lanzas()
	_limpiar_salpicaduras()


func test_aterrizaje_dispara_lanza_de_inmediato() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.disparar_al_aterrizar = true

	# Act: simular la emergencia completa
	azulina.emerger_en(Vector3(2.0, 0.5, 0.0))
	var t: float = 0.0
	while azulina._emergiendo and t < 10.0:
		azulina._procesar_emergencia(0.1)
		t += 0.1

	# Assert: al caer (punto 2) pasa a SHOOTING y arranca el ataque sin pausa previa
	assert_eq(azulina.current_state, azulina.State.SHOOTING, "Al aterrizar entra en SHOOTING")
	assert_true(azulina._lanzando, "Al aterrizar inicia el ataque de lanza de inmediato")
	_limpiar_salpicaduras()


func test_sin_disparo_al_aterrizar_si_desactivado() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.disparar_al_aterrizar = false

	# Act
	azulina.emerger_en(Vector3(2.0, 0.5, 0.0))
	var t: float = 0.0
	while azulina._emergiendo and t < 10.0:
		azulina._procesar_emergencia(0.1)
		t += 0.1

	# Assert: retoma la marcha sin atacar
	assert_eq(azulina.current_state, azulina.State.WALKING, "Sin remate sigue caminando")
	assert_false(azulina._lanzando, "Sin remate no ataca al aterrizar")
	_limpiar_salpicaduras()





# === ATAQUE ===
func test_lanzar_lanza_genera_proyectil() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina._emergiendo = false
	var conteo_antes: int = 0
	for n in get_tree().root.get_children():
		if n is LanzaAzulinaProjectile:
			conteo_antes += 1

	# Act
	azulina._lanzar_lanza()

	# Assert: aparece una lanza con sus parámetros
	var encontradas: int = 0
	for n in get_tree().root.get_children():
		if n is LanzaAzulinaProjectile:
			encontradas += 1
			assert_almost_eq(n.velocidad, azulina.velocidad_lanza, MARGEN_FLOAT, "Velocidad configurada")
			assert_almost_eq(n.gravedad, azulina.gravedad_lanza, MARGEN_FLOAT, "Gravedad configurada")
	assert_eq(encontradas, conteo_antes + 1, "Debe spawnear exactamente una lanza")
	for n in get_tree().root.get_children():
		if n is LanzaAzulinaProjectile:
			n.queue_free()


func test_ataque_a_gran_altura_cambia_al_patron_imp() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina._emergiendo = false
	azulina.dispersion_imp_factor = 0.0

	var dummy_player := Node3D.new()
	dummy_player.name = "DummyPlayerAlto"
	add_child_autofree(dummy_player)
	# Posicionar al jugador en altura tipo torre (a 8m a la izquierda y 4m de altura)
	dummy_player.global_position = azulina.global_position + Vector3(-8.0, 4.0, 0.0)
	azulina.player_ref = dummy_player

	# Act: lanza hacia el jugador situado a gran altura
	azulina._lanzar_lanza()

	# Assert: Se genera la lanza con el patrón parabólico del Imp
	var lanza_encontrada: LanzaAzulinaProjectile = null
	for n in get_tree().root.get_children():
		if n is LanzaAzulinaProjectile and not n.is_queued_for_deletion():
			lanza_encontrada = n as LanzaAzulinaProjectile
			break

	assert_not_null(lanza_encontrada, "Se debe spawnear una lanza")
	if lanza_encontrada:
		# En el patrón del Imp, direction.y tiene un arco hacia arriba para sobrevolar la torre
		assert_gt(lanza_encontrada.direction.y, 0.3, "La dirección inicial apunta hacia arriba formando un arco parabólico")
		# Gravedad configurada para caída pronunciada
		assert_almost_eq(lanza_encontrada.gravedad, azulina.gravedad_lanza_imp, MARGEN_FLOAT, "Usa la gravedad del patrón Imp")
		# Velocidad en rango suficiente para alcanzar la cima
		assert_gte(lanza_encontrada.velocidad, azulina.velocidad_lanza_imp_min, "Velocidad mínima garantizada")
		assert_lte(lanza_encontrada.velocidad, azulina.velocidad_lanza_imp_max, "Velocidad dentro del límite máximo")
		lanza_encontrada.free()

	_limpiar_salpicaduras()


func test_ataque_jugador_altura_normal_conserva_patron_estandar() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina._emergiendo = false

	var dummy_player := Node3D.new()
	dummy_player.name = "DummyPlayerSuelo"
	add_child_autofree(dummy_player)
	# Posicionar al jugador en la misma cota del suelo
	dummy_player.global_position = azulina.global_position + Vector3(-6.0, 0.2, 0.0)
	azulina.player_ref = dummy_player

	# Act
	azulina._lanzar_lanza()

	# Assert: Usa velocidad y gravedad normales
	var lanza_encontrada: LanzaAzulinaProjectile = null
	for n in get_tree().root.get_children():
		if n is LanzaAzulinaProjectile and not n.is_queued_for_deletion():
			lanza_encontrada = n as LanzaAzulinaProjectile
			break

	assert_not_null(lanza_encontrada, "Se debe spawnear una lanza")
	if lanza_encontrada:
		assert_almost_eq(lanza_encontrada.velocidad, azulina.velocidad_lanza, MARGEN_FLOAT, "Velocidad estándar")
		assert_almost_eq(lanza_encontrada.gravedad, azulina.gravedad_lanza, MARGEN_FLOAT, "Gravedad estándar")
		lanza_encontrada.free()

	_limpiar_salpicaduras()


# === ESCALA Y ORIENTACIÓN ===
func test_escala_igual_que_ballestera_aliada() -> void:
	# Arrange & Act
	var azulina := _crear_azulina()
	var ballestera_scene := load("res://Entities/Aliada_Ballestera/AllyBallestera.tscn") as PackedScene
	var ballestera := ballestera_scene.instantiate() as Node3D
	add_child_autofree(ballestera)

	# Assert: escala acorde a Azulina (~0.9 de escala base)
	assert_almost_eq(azulina.scale.x, 0.9, MARGEN_FLOAT, "Azulina escala base 0.9")

	# Assert: altura visual ~0.9 m, par con la ballestera aliada en nivel (2.3 x 0.3)
	# y la arquera Lonko (~1 m por colisión). Malla cruda de 1.0 m x 0.9 de escala.
	var modelo := azulina.find_child("AzulinaModel", true, false) as Node3D
	var escala_azulina: float = modelo.transform.basis.x.length()
	assert_almost_eq(escala_azulina, 0.9, MARGEN_FLOAT, "Azulina a escala 0.9 (~0.9 m en mundo)")
	var modelo_ballestera := ballestera.find_child("BallesteraModel", true, false) as Node3D
	var altura_ballestera_nivel: float = modelo_ballestera.transform.basis.x.length() * 0.3
	assert_lt(absf(escala_azulina - altura_ballestera_nivel), 0.35, "Altura similar a la ballestera aliada en nivel")


func test_orientacion_enemiga_mira_a_la_izquierda() -> void:
	# Arrange & Act
	var azulina := _crear_azulina()
	var modelo := azulina.find_child("AzulinaModel", true, false) as Node3D

	# Assert: modelo presente y orientado
	assert_not_null(modelo, "Debe existir el modelo de Azulina")

	# Assert: la lanza va fijada a la mano derecha (sigue a la animación)
	var lanza := azulina.find_child("LanzaMano", true, false) as Node3D
	if lanza == null:
		lanza = azulina.find_child("lanza giro parry", true, false) as Node3D
	assert_not_null(lanza, "Debe llevar la lanza en mano")
	var fijacion := lanza.get_parent() as BoneAttachment3D
	assert_not_null(fijacion, "La lanza debe colgar de un BoneAttachment3D")
	assert_eq(fijacion.bone_name, "mixamorig_RightHand", "La lanza va posada en la mano derecha")


func test_colision_mantiene_tamano_de_mundo() -> void:
	# Arrange & Act
	var azulina := _crear_azulina()
	var colision := azulina.find_child("CollisionShape3D", true, false) as CollisionShape3D

	# Assert: cápsula acorde a una Azulina de ~0.9 m
	var capsula := colision.shape as CapsuleShape3D
	assert_almost_eq(capsula.radius, 0.152, MARGEN_FLOAT, "Radio de colisión acorde al tamaño")
	assert_almost_eq(capsula.height, 0.77, MARGEN_FLOAT, "Altura de colisión acorde al tamaño")
	assert_almost_eq(colision.position.y, 0.375, MARGEN_FLOAT, "Altura de colisión acorde al tamaño")


# === LANZA (ARMA REAL, NO FLECHA) ===
func test_lanza_disparada_muestra_arma_texturizada() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina._emergiendo = false
	var mat_lanza: Material = load("res://Entities/Enemigo_Azulina/LanzaAzulina_MAT.tres") as Material

	# Act
	azulina._lanzar_lanza()

	# Assert: el proyectil muestra la lanza texturizada (no el emisivo celeste del tridente)
	var lanza: LanzaAzulinaProjectile = null
	for n in get_tree().root.get_children():
		if n is LanzaAzulinaProjectile:
			lanza = n
			break
	assert_not_null(lanza, "Debe existir la lanza disparada")
	var mallas := lanza.find_children("*", "MeshInstance3D", true, false)
	assert_gt(mallas.size(), 0, "La lanza debe tener malla visible")
	for m in mallas:
		var mi := m as MeshInstance3D
		assert_eq(mi.material_override, mat_lanza, "La lanza usa su material texturizado (es lanza, no flecha)")
		assert_true(mi.visible, "La malla de la lanza debe ser visible")
	lanza.queue_free()


# === SALTO: DISPARO A MITAD Y SQUASH & STRETCH ===
func _contar_lanzas() -> int:
	var conteo: int = 0
	for n in get_tree().root.get_children():
		if n is LanzaAzulinaProjectile and not (n as Node).is_queued_for_deletion():
			conteo += 1
	return conteo


func _limpiar_lanzas() -> void:
	for n in get_tree().root.get_children():
		if n is LanzaAzulinaProjectile:
			(n as Node).free()


func _contar_salpicaduras() -> int:
	var conteo: int = 0
	for n in get_tree().root.get_children():
		if n is SalpicaduraAzulina and not (n as Node).is_queued_for_deletion():
			conteo += 1
	return conteo


func _limpiar_salpicaduras() -> void:
	for n in get_tree().root.get_children():
		if n is SalpicaduraAzulina:
			(n as Node).free()


func test_disparo_a_mitad_de_emergencia() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.momento_disparo_emergencia = 0.55
	var antes: int = _contar_lanzas()

	# Act: avanzar solo hasta pasado el punto de disparo, sin aterrizar
	azulina.emerger_en(Vector3(2.0, 0.5, 0.0))
	var t: float = 0.0
	while azulina._emergiendo and t < 10.0 and not azulina._lanzo_en_emergencia:
		azulina._procesar_emergencia(0.1)
		t += 0.1

	# Assert: dispara entrando, en pleno salto
	assert_true(azulina._lanzo_en_emergencia, "Dispara una vez a mitad de la emergencia")
	assert_eq(_contar_lanzas(), antes + 1, "El disparo de entrada genera su lanza")

	# Cleanup: completar el salto y liberar proyectiles
	while azulina._emergiendo and t < 20.0:
		azulina._procesar_emergencia(0.1)
		t += 0.1
	_limpiar_lanzas()
	_limpiar_salpicaduras()


func test_squash_estira_aplastay_recupera() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.squash_stretch = true
	var base: float = azulina._escala_modelo_base

	# Act: inicio del salto (fase de subida)
	azulina.emerger_en(Vector3(2.0, 0.5, 0.0))
	azulina._procesar_emergencia(0.1)

	# Assert: estirada al despegar (más alta y angosta)
	assert_gt(azulina._modelo.scale.y, base, "Al subir se estira en Y")
	assert_lt(azulina._modelo.scale.x, base, "Al subir se angosta en XZ")

	# Act: completar hasta el aterrizaje
	var t: float = 0.1
	while azulina._emergiendo and t < 10.0:
		azulina._procesar_emergencia(0.1)
		t += 0.1

	# Assert: aplastada al tocar suelo
	assert_lt(azulina._modelo.scale.y, base, "Al caer se aplasta en Y")
	assert_gt(azulina._modelo.scale.x, base, "Al caer se ensancha en XZ")

	# Act: recuperar la forma base
	azulina._recuperar_squash(1.0)

	# Assert: vuelve a la escala exacta
	assert_almost_eq(azulina._modelo.scale.y, base, MARGEN_FLOAT, "Recupera la altura base")
	assert_almost_eq(azulina._modelo.scale.x, base, MARGEN_FLOAT, "Recupera el ancho base")
	_limpiar_lanzas()
	_limpiar_salpicaduras()


# === SALPICADURA AL EMERGER ===
func test_salpicadura_estructura_como_fuego() -> void:
	# Arrange & Act
	var sal := preload("res://Entities/Enemigo_Azulina/SalpicaduraAzulina.tscn").instantiate() as SalpicaduraAzulina
	add_child_autofree(sal)

	# Assert: AnimatedSprite3D con tira de 13 cuadros a 12 FPS, sin bucle (un impacto)
	assert_true(sal is AnimatedSprite3D, "La salpicadura es un AnimatedSprite3D")
	assert_eq(sal.billboard, BaseMaterial3D.BILLBOARD_ENABLED, "Billboard para verse siempre de frente")
	assert_false(sal.shaded, "Sin sombras para emitir luz propia como el fuego")
	assert_not_null(sal.sprite_frames, "Debe generar sus SpriteFrames")
	assert_true(sal.sprite_frames.has_animation(&"default"), "Debe tener animación default")
	assert_eq(sal.sprite_frames.get_frame_count(&"default"), 13, "13 cuadros de la tira")
	assert_almost_eq(sal.sprite_frames.get_animation_speed(&"default"), 12.0, MARGEN_FLOAT, "12 FPS")
	assert_false(sal.sprite_frames.get_animation_loop(&"default"), "Un solo impacto, sin bucle")
	sal.queue_free()


func test_salpicadura_agua_usa_splash_png() -> void:
	# Arrange & Act
	var sal := preload("res://Entities/Enemigo_Azulina/SalpicaduraAgua.tscn").instantiate() as SalpicaduraAgua
	add_child_autofree(sal)

	# Assert: AnimatedSprite3D con los 10 cuadros de la tira alineada, sin bucle (un impacto)
	assert_true(sal is AnimatedSprite3D, "La salpicadura es un AnimatedSprite3D")
	assert_true(sal is SalpicaduraAzulina, "Sigue contando como salpicadura de azulina")
	assert_not_null(sal.sprite_frames, "Debe generar sus SpriteFrames")
	assert_true(sal.sprite_frames.has_animation(&"default"), "Debe tener animación default")
	assert_eq(sal.sprite_frames.get_frame_count(&"default"), 10, "10 cuadros del splash")
	assert_false(sal.sprite_frames.get_animation_loop(&"default"), "Un solo impacto, sin bucle")
	sal.queue_free()


func test_salpicadura_agua_disolucion_celeste() -> void:
	# Arrange & Act: instanciar salpicadura
	var sal := preload("res://Entities/Enemigo_Azulina/SalpicaduraAgua.tscn").instantiate() as SalpicaduraAgua
	add_child_autofree(sal)

	# Assert 1: Material con shader de disolución y color celeste configurado
	assert_true(sal.disolucion_celeste, "La disolución celeste está activa por defecto")
	assert_false(sal.reproduccion_en_bucle, "Un solo impacto, sin bucle permanente")
	assert_false(sal.sprite_frames.get_animation_loop(sal.ANIM_AGUA), "La animación no está en bucle")
	assert_not_null(sal._material_splash, "Debe tener un ShaderMaterial asignado")
	assert_eq(sal._material_splash.get_shader_parameter("glow_color"), Color(0.35, 0.85, 1.0, 1.0), "El borde de disolución es celeste")
	assert_not_null(sal._material_splash.get_shader_parameter("albedo_texture"), "La textura del cuadro actual está asignada al shader")

	# Assert 2: Tween iniciado en 1.0 y avanzando hacia 0.0
	assert_true(is_instance_valid(sal._tween_splash), "Debe tener tween de ciclo activo")
	sal._tween_splash.custom_step(0.10)
	var dis_mitad: float = float(sal._material_splash.get_shader_parameter("dissolve_amount"))
	assert_lt(dis_mitad, 1.0, "Disolución reduciéndose hacia 0 en la entrada")
	assert_gt(dis_mitad, 0.0, "Aún en proceso de materializarse")

	# Avanzar hasta el pico visible
	sal._tween_splash.custom_step(0.15)
	assert_almost_eq(float(sal._material_splash.get_shader_parameter("dissolve_amount")), 0.0, MARGEN_FLOAT, "Alcanza 0.0 (totalmente visible)")

	# Act 3: Avanzar hacia la salida de desintegración
	sal._tween_splash.custom_step(0.35)
	var dis_salida: float = float(sal._material_splash.get_shader_parameter("dissolve_amount"))
	assert_gt(dis_salida, 0.0, "Disolución aumentando hacia 1 en la salida")

	# Act 4: Completar desintegración y liberar
	sal._tween_splash.custom_step(0.30)
	assert_true(sal.is_queued_for_deletion(), "Se libera de memoria al completarse el impacto único")


func test_emerger_genera_salpicadura_en_origen() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	azulina.aterrizar_en_centro = false
	azulina.salpicadura_al_emerger = true
	_limpiar_salpicaduras()
	var destino := Vector3(2.0, 0.5, 0.0)

	# Act
	azulina.emerger_en(destino)

	# Assert: una salpicadura en el punto de rotura (XZ del origen, Y a nivel de orilla)
	assert_eq(_contar_salpicaduras(), 1, "Emerger genera su splash")
	var sal: SalpicaduraAzulina = null
	for n in get_tree().root.get_children():
		if n is SalpicaduraAzulina and not (n as Node).is_queued_for_deletion():
			sal = n
			break
	assert_not_null(sal, "Debe existir la salpicadura")
	assert_almost_eq(sal.global_position.x, azulina.global_position.x + azulina.desplazamiento_lateral_salpicadura, MARGEN_FLOAT, "Corrido lateral según export")
	assert_almost_eq(sal.global_position.z, azulina.global_position.z + azulina.adelanto_camara_salpicadura, MARGEN_FLOAT, "Adelantado a camara para no quedar tras el ledge")
	assert_almost_eq(sal.global_position.y, destino.y - azulina.profundidad_rotura, MARGEN_FLOAT, "Apenas bajo la orilla")
	_limpiar_salpicaduras()


func test_emergencia_en_zona_aleatoria() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = true
	azulina.aterrizar_en_centro = false
	azulina.usar_centro_zona_personalizado = false
	azulina.zona_extension = Vector3(4.0, 0.0, 1.5)
	var centro := Vector3(2.0, 0.5, 0.0)

	# Act & Assert: varios sorteos caen dentro de la zona y no repiten punto
	var primera: Vector3 = Vector3.ZERO
	var varia := false
	for i in range(10):
		azulina.emerger_en(centro)
		var t: float = 0.0
		while azulina._emergiendo and t < 10.0:
			azulina._procesar_emergencia(0.1)
			t += 0.1
		var caida: Vector3 = azulina.global_position
		assert_true(absf(caida.x - centro.x) <= 4.0 + MARGEN_FLOAT, "X dentro de la zona")
		assert_almost_eq(caida.y, centro.y, MARGEN_FLOAT, "Y de la zona")
		assert_true(absf(caida.z - centro.z) <= 1.5 + MARGEN_FLOAT, "Z dentro de la zona")
		if i == 0:
			primera = caida
		elif caida.distance_to(primera) > 0.01:
			varia = true
	assert_true(varia, "No cae siempre en el mismo lugar")
	_limpiar_lanzas()
	_limpiar_salpicaduras()


func test_aterrizaje_en_centro_del_eje() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = true
	azulina.aterrizar_en_centro = true
	azulina.centro_aterrizaje_x = 0.0
	azulina.usar_centro_zona_personalizado = false
	azulina.zona_extension = Vector3(4.0, 0.0, 0.0)

	# Act: emerger pidiendo otro punto e ir hasta el suelo
	azulina.emerger_en(Vector3(5.0, 1.0, 2.0))
	var t: float = 0.0
	while azulina._emergiendo and t < 10.0:
		azulina._procesar_emergencia(0.1)
		t += 0.1

	# Assert: cae en el centro del eje aunque emerja en la zona
	assert_false(azulina._emergiendo, "Debe terminar la emergencia")
	assert_almost_eq(azulina.global_position.x, 0.0, MARGEN_FLOAT, "Cae en el centro del eje 0")
	assert_almost_eq(azulina.global_position.y, 1.0, MARGEN_FLOAT, "Mantiene la altura pedida")
	assert_almost_eq(azulina.global_position.z, 2.0, MARGEN_FLOAT, "Mantiene el fondo pedido")
	_limpiar_lanzas()
	_limpiar_salpicaduras()


func test_sin_salpicadura_si_desactivada() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.salpicadura_al_emerger = false
	_limpiar_salpicaduras()

	# Act
	azulina.emerger_en(Vector3(2.0, 0.5, 0.0))

	# Assert
	assert_eq(_contar_salpicaduras(), 0, "Sin flag no hay splash")
	_limpiar_salpicaduras()


# === MUERTE ALEATORIA E IDLE ===
func test_muerte_aleatoria_entre_1_y_3() -> void:
	# Arrange
	var azulina := _crear_azulina()

	# Assert: configuración con las dos muertes pedidas
	assert_eq(azulina.animaciones_muerte.size(), 2, "Dos animaciones de muerte configuradas")
	assert_true(azulina.animaciones_muerte.has("Muerte 1"), "Incluye Muerte 1")
	assert_true(azulina.animaciones_muerte.has("Muerte 3"), "Incluye Muerte 3")

	# Act & Assert: el sorteo solo devuelve esas dos
	for i in 30:
		var elegida: String = azulina.elegir_animacion_muerte()
		assert_true(elegida == "Muerte 1" or elegida == "Muerte 3", "La muerte es 1 o 3 al azar")


func test_quieta_entre_ataques_y_reenganche() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina._emergiendo = false
	assert_eq(azulina.animacion_quieta, "Idle", "Idle natural por defecto")

	# Act: pausa agotada => reengancha el ataque
	azulina._lanzando = false
	azulina._pausa_lanzamiento = 0.0
	azulina._process_shooting(0.1)

	# Assert
	assert_true(azulina._lanzando, "Tras la pausa quieta vuelve a atacar")


func test_dano_reproduce_flinch_y_pausa_ataque() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	azulina._emergiendo = false
	azulina._change_state(azulina.State.SHOOTING)
	azulina._iniciar_ataque()
	var timer_antes: float = azulina._timer_lanzamiento

	# Act: impacto no letal en pleno ataque
	azulina.take_damage(1.0)

	# Assert: arranca el flinch con la animación de daño
	assert_gt(azulina._tiempo_flinch, 0.0, "El impacto abre ventana de flinch")
	assert_true(String(azulina.anim_player.current_animation).contains("Daño"), "Suena la animación de daño")

	# Act: el ciclo de ataque queda congelado durante el flinch
	azulina._process_shooting(0.2)

	# Assert: el temporizador no avanzó ni disparó
	assert_almost_eq(azulina._timer_lanzamiento, timer_antes, MARGEN_FLOAT, "El ataque se pausa en el flinch")
	assert_false(azulina._lanzo_proyectil, "No dispara durante el flinch")

	# Act: agotar el flinch fuera de ataque
	azulina._lanzando = false
	azulina._process_shooting(azulina._tiempo_flinch + 0.1)

	# Assert: vuelve a la quieta sin quedarse clavada
	assert_true(String(azulina.anim_player.current_animation).contains(azulina.animacion_quieta) or String(azulina.anim_player.current_animation).contains("Idle"), "Retoma la base al terminar")
	_limpiar_lanzas()
	_limpiar_salpicaduras()


func test_lanza_se_oculta_al_arrojar_y_vuelve_en_idle() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	azulina._emergiendo = false
	azulina._change_state(azulina.State.SHOOTING)
	azulina._iniciar_ataque()

	# Act: dispara la lanza
	azulina._lanzar_lanza()

	# Assert: la mano queda vacía
	assert_true(azulina._lanza_arrojada, "Marca la lanza como arrojada")
	assert_false(azulina._mano.visible, "La mano queda vacía al arrojar")

	# Act: termina el ataque y vuelve a idle
	azulina._timer_lanzamiento = azulina._duracion_anim_ataque()
	azulina._process_shooting(0.1)

	# Assert: reaparece con disolución celeste
	assert_false(azulina._lanza_arrojada, "Limpia la marca al volver a idle")
	assert_true(azulina._mano.visible, "Vuelve a la mano")
	_limpiar_lanzas()
	_limpiar_salpicaduras()


# === PARRY DE LANZA ===
func test_parry_se_activa_cada_n_ataques() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	azulina.probabilidad_desvio_normal = 0.0
	azulina.ataques_para_parry_min = 4
	azulina.ataques_para_parry_max = 4
	azulina._emergiendo = false

	# Act: 3 impactos espaciados (fuera de la ventana multi) no activan
	assert_false(azulina.manejar_impacto_aura(null), "1er impacto pasa")
	azulina._impactos_recientes.clear()
	assert_false(azulina.manejar_impacto_aura(null), "2do impacto pasa")
	azulina._impactos_recientes.clear()
	assert_false(azulina.manejar_impacto_aura(null), "3er impacto pasa")
	azulina._impactos_recientes.clear()
	assert_false(azulina._parry_activo, "Aún no hay parry")

	# Act: el 4to activa y repele
	assert_true(azulina.manejar_impacto_aura(null), "4to impacto se repele")

	# Assert: giro visible con lanza por 3 segundos
	assert_true(azulina._parry_activo, "Parry activo")
	assert_true(azulina._mano.visible, "La lanza solo se ve en el parry")
	assert_almost_eq(azulina._mano.scale.x, azulina.escala_lanza_parry, MARGEN_FLOAT, "Asta agrandada en el giro")
	assert_almost_eq(azulina.anim_player.speed_scale, azulina.velocidad_parry, MARGEN_FLOAT, "Giro acelerado")
	_limpiar_salpicaduras()


func test_parry_alterna_normal_e_invertido() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	azulina.animacion_parry = "Giro de lanza parry"
	azulina.probabilidad_desvio_normal = 0.0
	azulina.ataques_para_parry_min = 1
	azulina.ataques_para_parry_max = 1
	azulina._emergiendo = false
	azulina.manejar_impacto_aura(null)
	assert_true(azulina._parry_activo, "Precondición: parry activo")
	var anim := azulina.anim_player.get_animation(azulina._anim_parry_loop)
	assert_not_null(anim, "Existe el giro duplicado")
	assert_eq(anim.loop_mode, Animation.LOOP_NONE, "Sin loop propio: lo alterna el código")

	# Act: llevar al borde del final y procesar
	azulina.anim_player.seek(anim.length - 0.01, true)
	azulina._procesar_parry(0.01)

	# Assert: congela el cuadro final sin cortar el parry
	assert_false(azulina.anim_player.is_playing(), "Congela el cuadro final")
	assert_gt(azulina._tiempo_hold_parry, 0.0, "Abre la ventana de hold")
	assert_true(azulina._parry_activo, "El parry continúa")

	# Act: agotar el hold y procesar
	azulina._procesar_parry(azulina.duracion_hold_parry + 0.1)

	# Assert: invierte sin cortarse
	assert_lt(azulina.anim_player.get_playing_speed(), 0.0, "Gira invertido")
	assert_true(azulina._parry_activo, "El parry continúa")

	# Act: llevar al borde del inicio y procesar
	azulina.anim_player.seek(0.01, true)
	azulina._procesar_parry(0.01)

	# Assert: vuelve a normal
	assert_gt(azulina.anim_player.get_playing_speed(), 0.0, "Vuelve al giro normal")
	_limpiar_salpicaduras()


func test_parry_humo_a_ambos_lados() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	azulina.probabilidad_desvio_normal = 0.0
	azulina.ataques_para_parry_min = 1
	azulina.ataques_para_parry_max = 1
	azulina._emergiendo = false
	var antes: int = get_tree().root.find_children("*", "GPUParticles3D", true, false).size()

	# Act
	azulina.manejar_impacto_aura(null)

	# Assert: una nube a cada lado
	var nubes := get_tree().root.find_children("*", "GPUParticles3D", true, false)
	assert_eq(nubes.size() - antes, 2, "Humo a ambos lados")
	for n in nubes:
		(n as Node).queue_free()
	_limpiar_salpicaduras()


func test_morir_suelta_lanza_voladora() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	azulina._emergiendo = false

	# Act: daño letal con la lanza en mano
	azulina.take_damage(99.0)

	# Assert: la lanza sale volando y la mano queda vacía
	var halladas := get_tree().root.find_children("*", "LanzaVoladora", true, false)
	assert_false(halladas.is_empty(), "La lanza sale volando al morir")
	assert_false(azulina._mano.visible, "La mano queda vacía")
	if not halladas.is_empty():
		var lv := halladas[0] as Node3D
		assert_gt(lv.global_basis.get_scale().x, 0.7, "La lanza voladora conserva escala visible en el mundo")
		var hijo_lanza := lv.find_child("lanza giro parry", true, false)
		assert_not_null(hijo_lanza, "El nodo 'lanza giro parry' se desacopló y viaja en LanzaVoladora")
	for n in halladas:
		(n as Node).queue_free()
	_limpiar_lanzas()
	_limpiar_salpicaduras()


func test_muerte_explosiva_impulsa_cadaver() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	azulina._emergiendo = false
	azulina.murio_por_explosion = true
	azulina.last_hit_position = azulina.global_position + Vector3(-1.0, 0.0, 0.0)

	# Act: daño letal marcado por flecha explosiva
	azulina.take_damage(99.0)

	# Assert: sale impulsado en parábola como la goblin arquera con física reactivada
	assert_true(azulina._impulso_explosivo_activo, "Activa el vuelo del cadáver")
	assert_true(azulina.is_physics_processing(), "La física del cuerpo debe reactivarse durante el vuelo")
	assert_gt(azulina.velocity.x, 0.0, "Empuje lateral hacia la derecha opuesto al impacto")
	assert_gt(azulina.velocity.y, 0.0, "Se eleva en el aire")
	assert_eq(azulina.velocity.z, 0.0, "Sin desvío en Z (2.5D)")
	assert_false(azulina.murio_por_explosion, "La bandera murio_por_explosion se limpia para permitir disolución normal")
	azulina._process_dying(0.1)
	assert_gt(absf(azulina.velocity.x), 0.0, "Conserva el empuje en el aire")
	_limpiar_lanzas()
	_limpiar_salpicaduras()


func test_lanza_voladora_vuelo_parabolico_como_arquera_goblin() -> void:
	# Arrange: LanzaVoladora hereda de GoblinPiezaFisica
	var voladora := LanzaVoladora.new()
	add_child_autofree(voladora)

	# Act: iniciar vuelo con impulso y rotación
	voladora.iniciar_vuelo(Vector3(2.5, 4.5, 0.0), 10.0)

	# Assert: se comporta exactamente igual que la pieza de la arquera goblin
	assert_true(voladora is GoblinPiezaFisica, "LanzaVoladora debe heredar de GoblinPiezaFisica")
	assert_true(voladora.active, "El vuelo debe quedar activo")
	assert_false(voladora.resting, "No debe estar en reposo al iniciar")
	assert_almost_eq(voladora.velocity.x, 2.5, MARGEN_FLOAT, "Velocidad horizontal asignada")
	assert_almost_eq(voladora.velocity.y, 4.5, MARGEN_FLOAT, "Velocidad vertical asignada")
	assert_almost_eq(voladora.rot_speed_z, 10.0, MARGEN_FLOAT, "Rotación asignada")
	assert_almost_eq(voladora.gravity, 14.0, MARGEN_FLOAT, "Gravedad estándar de piezas físicas")


func test_morir_desvanece_circulo_con_humo() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	azulina.probabilidad_desvio_normal = 0.0
	azulina.ataques_para_parry_min = 1
	azulina.ataques_para_parry_max = 1
	azulina._emergiendo = false
	azulina.manejar_impacto_aura(null)
	assert_true(azulina._circulo.visible, "Precondición: aro visible")
	var humo_antes: int = get_tree().root.find_children("*", "GPUParticles3D", true, false).size()

	# Act: daño letal con el aro puesto
	azulina.take_damage(99.0)

	# Assert: humo celeste a ambos lados y el aro inicia su fundido
	var humo_despues: int = get_tree().root.find_children("*", "GPUParticles3D", true, false).size()
	assert_eq(humo_despues - humo_antes, 2, "Humo a ambos lados al morir")
	assert_true(is_instance_valid(azulina._circulo), "El aro sigue en escena desvaneciéndose")
	for n in get_tree().root.find_children("*", "GPUParticles3D", true, false):
		(n as Node).queue_free()
	_limpiar_lanzas()
	_limpiar_salpicaduras()


func test_parry_multidisparo_inmediato() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	azulina.probabilidad_desvio_normal = 0.0
	azulina.ataques_para_parry_min = 5
	azulina.ataques_para_parry_max = 5
	azulina._emergiendo = false

	# Act: 2 impactos seguidos (misma ráfaga) activan sin esperar el conteo
	azulina.manejar_impacto_aura(null)
	assert_true(azulina.manejar_impacto_aura(null), "Ráfaga múltiple se repele")

	# Assert
	assert_true(azulina._parry_activo, "Multidisparo activa el parry")
	_limpiar_salpicaduras()


func test_parry_repele_y_expira() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	azulina.probabilidad_desvio_normal = 0.0
	azulina.ataques_para_parry_min = 1
	azulina.ataques_para_parry_max = 1
	azulina._emergiendo = false
	azulina.manejar_impacto_aura(null)
	assert_true(azulina._parry_activo, "Precondición: parry activo")

	# Act: más proyectiles rebotan sin daño ni extensión
	assert_true(azulina.manejar_impacto_aura(null), "Repele durante el giro")

	# Act: agotar los 3 segundos
	azulina._procesar_parry(azulina.duracion_parry + 0.1)

	# Assert: termina, oculta la lanza y deja pasar
	assert_false(azulina._parry_activo, "El parry expira")
	assert_false(azulina._mano.visible, "La lanza se oculta al terminar")
	assert_false(azulina.manejar_impacto_aura(null), "Sin parry el impacto pasa")
	_limpiar_salpicaduras()


func test_parry_enfriamiento_impide_reactivacion() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	azulina.probabilidad_desvio_normal = 0.0
	azulina.ataques_para_parry_min = 1
	azulina.ataques_para_parry_max = 1
	azulina.enfriamiento_parry = 5.0
	azulina._emergiendo = false
	azulina.manejar_impacto_aura(null)
	assert_true(azulina._parry_activo, "Precondición: parry activo")
	azulina._procesar_parry(azulina.duracion_parry + 0.1)
	assert_false(azulina._parry_activo, "Precondición: parry expirado")

	# Act: impactos durante el enfriamiento no reactivan aunque cumplan el conteo
	for i in range(5):
		azulina._impactos_recientes.clear()
		assert_false(azulina.manejar_impacto_aura(null), "En enfriamiento el impacto pasa")

	# Assert: sigue vulnerable
	assert_false(azulina._parry_activo, "No se reactiva en enfriamiento")

	# Act: agotado el enfriamiento, el siguiente impacto activa
	azulina._procesar_parry(5.0)
	assert_true(azulina.manejar_impacto_aura(null), "Tras el enfriamiento repele")

	# Assert
	assert_true(azulina._parry_activo, "Vuelve a activar tras el enfriamiento")
	_limpiar_salpicaduras()


func test_parry_congela_piernas_y_gira_brazos() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	azulina.animacion_parry = "Giro de lanza parry"
	azulina.congelar_piernas_en_parry = true
	azulina.probabilidad_desvio_normal = 0.0
	azulina.ataques_para_parry_min = 1
	azulina.ataques_para_parry_max = 1
	azulina._emergiendo = false
	azulina.manejar_impacto_aura(null)
	assert_true(azulina._parry_activo, "Precondición: parry activo")

	# Assert: piernas resueltas con postura capturada
	assert_false(azulina._huesos_piernas.is_empty(), "Resuelve huesos de piernas")
	assert_eq(azulina._huesos_piernas.size(), azulina._pose_piernas_fija.size(), "Una postura por hueso")

	# Act: aplicar la fijación directamente (el diferido corre al final del cuadro)
	azulina._aplicar_piernas_estaticas()

	# Assert: cada pierna queda en su postura capturada
	for i in range(azulina._huesos_piernas.size()):
		var idx: int = azulina._huesos_piernas[i]
		assert_eq(azulina._esqueleto.get_bone_pose_rotation(idx), azulina._pose_piernas_fija[i], "Pierna fija")
	_limpiar_salpicaduras()


func test_barrido_agarre_mueve_lanza() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	azulina.probabilidad_desvio_normal = 0.0
	azulina.ataques_para_parry_min = 1
	azulina.ataques_para_parry_max = 1
	azulina.barrer_agarre_debug = true
	azulina.velocidad_barrido = 0.6
	azulina._emergiendo = false
	azulina.manejar_impacto_aura(null)
	assert_true(azulina._parry_activo, "Precondición: parry activo")
	var eje_antes: Vector3 = azulina._mano.transform.basis.x

	# Act: el barrido rota el agarre
	azulina._procesar_parry(0.5)

	# Assert
	assert_ne(azulina._mano.transform.basis.x, eje_antes, "El barrido rota la lanza")
	_limpiar_salpicaduras()


func test_circulo_visible_y_gira_en_parry() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	azulina.probabilidad_desvio_normal = 0.0
	azulina.ataques_para_parry_min = 1
	azulina.ataques_para_parry_max = 1
	azulina._emergiendo = false
	assert_true(is_instance_valid(azulina._circulo), "Crea el aro al iniciar")
	assert_false(azulina._circulo.visible, "Oculto fuera del parry")

	# Act: activar y avanzar
	azulina.manejar_impacto_aura(null)
	assert_true(azulina._parry_activo, "Precondición: parry activo")
	if azulina._circulo.sprite_frames == null:
		assert_false(azulina._circulo.visible, "Sin PNG no se muestra (sin romper)")
		_limpiar_salpicaduras()
		return
	assert_true(azulina._circulo.visible, "Visible durante el giro")
	assert_true(azulina._circulo.is_playing(), "Animando los 9 aros")
	assert_eq(azulina._circulo.sprite_frames.get_frame_count(&"giro"), 9, "9 cuadros del círculo")
	if azulina._tween_circulo != null and azulina._tween_circulo.is_valid():
		azulina._tween_circulo.custom_step(0.4)
	assert_almost_eq(azulina._circulo.modulate.a, azulina.opacidad_circulo, MARGEN_FLOAT, "Opacidad aplicada tras fade-in")
	assert_almost_eq(azulina._circulo.position.x, azulina.offset_circulo.x, MARGEN_FLOAT, "Aro en offset manual X")
	assert_almost_eq(azulina._circulo.position.y, azulina.offset_circulo.y, MARGEN_FLOAT, "Aro en offset manual Y")
	assert_almost_eq(azulina._circulo.position.z, azulina.offset_circulo.z, MARGEN_FLOAT, "Aro en offset manual Z")
	assert_true(is_instance_valid(azulina._luz_circulo), "Crea su luz celeste")
	assert_true(azulina._luz_circulo.visible, "Brilla durante el giro")
	azulina._procesar_parry(azulina.duracion_parry + 0.1)
	if azulina._tween_circulo != null and azulina._tween_circulo.is_valid():
		azulina._tween_circulo.custom_step(0.5)
	assert_false(azulina._circulo.visible, "Se oculta tras fade-out al terminar")
	_limpiar_salpicaduras()


func test_parry_animacion_usa_lanza_casteo() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	azulina.probabilidad_desvio_normal = 0.0
	azulina.ataques_para_parry_min = 1
	azulina.ataques_para_parry_max = 1
	azulina._emergiendo = false

	# Assert: por defecto la animación de parry es Lanza casteo
	assert_eq(azulina.animacion_parry, "Lanza casteo", "La animación de parry por defecto es Lanza casteo")

	# Act: activar parry
	azulina.manejar_impacto_aura(null)

	# Assert
	assert_true(azulina._parry_activo, "Parry activo")
	assert_eq(azulina._anim_parry_loop, "Lanza casteo", "La animación seleccionada es Lanza casteo")
	assert_eq(azulina.anim_player.current_animation, "Lanza casteo", "AnimationPlayer reproduce directamente Lanza casteo")
	var anim := azulina.anim_player.get_animation("Lanza casteo")
	assert_not_null(anim, "Existe la animación Lanza casteo en AnimationPlayer")
	assert_eq(anim.loop_mode, Animation.LOOP_NONE, "Lanza casteo NO se repite en loop (LOOP_NONE)")

	# Act: procesar tiempo hasta el final de la animación de 2.0s
	azulina.anim_player.seek(anim.length, true)
	azulina._procesar_parry(0.5)

	# Assert: se mantiene congelada en el último frame hasta terminar la habilidad (3.0s)
	assert_true(azulina._parry_activo, "Parry sigue activo tras completar los 2.0s de la animación")
	assert_almost_eq(azulina.anim_player.current_animation_position, anim.length, MARGEN_FLOAT, "Se mantiene congelada en el último frame")
	_limpiar_salpicaduras()


func test_circulo_protector_posicionado_al_fondo_detras() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false

	# Assert
	assert_lt(azulina.offset_circulo.z, 0.0, "El offset Z del círculo es negativo (más al fondo, detrás de ella)")
	assert_almost_eq(azulina.offset_circulo.x, -0.04, MARGEN_FLOAT, "El círculo se centra sobre el torso y eje corporal en X")
	assert_almost_eq(azulina.offset_circulo.y, 0.60, MARGEN_FLOAT, "El círculo se sitúa centrado sobre el torso y lanza en Y")
	if is_instance_valid(azulina._circulo):
		assert_almost_eq(azulina._circulo.position.z, azulina.offset_circulo.z, MARGEN_FLOAT, "Posición Z coincide")
		assert_almost_eq(azulina._circulo.position.x, azulina.offset_circulo.x, MARGEN_FLOAT, "Posición X coincide")
		assert_almost_eq(azulina._circulo.position.y, azulina.offset_circulo.y, MARGEN_FLOAT, "Posición Y coincide")
		assert_lt(azulina._circulo.sorting_offset, 0.0, "Sorting offset negativo para ordenar detrás del modelo 3D")
	_limpiar_salpicaduras()


func test_destello_celeste_lanza_al_desviar_o_desintegrar() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	azulina._emergiendo = false
	azulina._activar_parry()

	var mallas := azulina._obtener_mallas_lanza()
	assert_false(mallas.is_empty(), "Azulina tiene mallas asociadas a su lanza")

	var flecha := preload("res://Entities/Proyectil_Flecha/Arrow.tscn").instantiate() as ArrowProjectile
	add_child_autofree(flecha)
	flecha.initialize(Vector3.LEFT, 15.0)

	# Act: La flecha impacta en parry
	var bloqueado := azulina.manejar_impacto_aura(flecha)

	# Assert: El proyectil es bloqueado y la lanza activa su destello celeste
	assert_true(bloqueado, "El proyectil fue repelido/bloqueado")
	assert_not_null(azulina._tween_destello_lanza, "Se crea un tween para el destello celeste")
	assert_true(azulina._tween_destello_lanza.is_valid(), "El tween de destello celeste está activo")

	var malla_lanza: MeshInstance3D = mallas[0]
	assert_true(malla_lanza.material_override is StandardMaterial3D, "El material de destello es un StandardMaterial3D")
	var mat_flash := malla_lanza.material_override as StandardMaterial3D
	assert_true(mat_flash.emission_enabled, "La emisión está habilitada para el destello")
	assert_almost_eq(mat_flash.emission.r, 0.35, MARGEN_FLOAT, "Color de emisión celeste (R)")
	assert_almost_eq(mat_flash.emission.g, 0.85, MARGEN_FLOAT, "Color de emisión celeste (G)")
	assert_almost_eq(mat_flash.emission.b, 1.0, MARGEN_FLOAT, "Color de emisión celeste (B)")

	# Act 2: Completar la interpolación del destello
	azulina._tween_destello_lanza.custom_step(0.25)

	# Assert 2: Se restaura el material original de la lanza
	assert_eq(malla_lanza.material_override, azulina.MATERIAL_LANZA, "Se restaura el material original de la lanza tras el destello")
	_limpiar_salpicaduras()


func test_desvio_disparo_normal_con_giro_lanza() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	azulina._emergiendo = false
	azulina.probabilidad_desvio_normal = 1.0  # Forzar 100% para verificar la ejecución del desvío

	# Act
	var desviado := azulina.manejar_impacto_aura(null)

	# Assert: desvía sin activar el casteo prolongado
	assert_true(desviado, "El disparo normal se desvía")
	assert_true(azulina._desviando_giro, "Estado de desvío con giro activo")
	assert_false(azulina._parry_activo, "No activa el casteo prolongado")
	assert_true(azulina._mano.visible, "Muestra la lanza para el giro")
	assert_true(azulina.anim_player.current_animation.contains("Giro"), "Ejecuta Giro de lanza parry")

	# Act: avanzar tiempo del desvío
	azulina._procesar_desvio(azulina.duracion_desvio_giro + 0.1)

	# Assert: finaliza el desvío y oculta la lanza
	assert_false(azulina._desviando_giro, "Finaliza el giro de desvío")
	assert_false(azulina._mano.visible, "La lanza se oculta al finalizar")
	_limpiar_salpicaduras()


func test_disparo_sobrecarga_morada_max_no_se_desvia() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	azulina._emergiendo = false
	azulina.probabilidad_desvio_normal = 1.0

	var flecha_morada := Node.new()
	flecha_morada.set_meta("sobrecarga_max", true)
	add_child_autofree(flecha_morada)

	# Act 1: fuera de parry
	var repelido := azulina.manejar_impacto_aura(flecha_morada)

	# Assert
	assert_false(repelido, "Flecha cargada con barra morada al máximo NO se puede desviar")
	assert_false(azulina._desviando_giro, "No ejecuta giro de desvío")

	# Act 2: durante parry casteo activo
	azulina.probabilidad_desvio_normal = 0.0
	azulina.ataques_para_parry_min = 1
	azulina.ataques_para_parry_max = 1
	azulina._activar_parry()
	assert_true(azulina._parry_activo, "Precondición: parry casteo activo")
	var repelido_en_parry := azulina.manejar_impacto_aura(flecha_morada)

	# Assert
	assert_false(repelido_en_parry, "La sobrecarga morada al máximo penetra incluso durante el parry")
	assert_false(azulina._parry_activo, "El impacto potente cancela el parry/casteo")
	_limpiar_salpicaduras()


# === WAVESPAWNER Y DEBUG ===
func test_wavespawner_resuelve_azulina_id_11() -> void:
	# Arrange (sin árbol: el resolver solo lee configuración)
	var spawner := WaveSpawner.new()
	spawner.escena_azulina = load("res://Entities/Enemigo_Azulina/Azulina.tscn") as PackedScene
	spawner.forzar_tipo_enemigo = 11

	# Act
	var escena: PackedScene = spawner._elegir_escena_probabilidades()

	# Assert
	assert_not_null(escena, "El id 11 debe resolver una escena")
	assert_eq(escena, spawner.escena_azulina, "Debe ser la escena de Azulina")
	spawner.free()


func test_sonido_entrada_azulina_registrado() -> void:
	# Assert: AudioManager tiene registrado el stream de entrada_azulina
	assert_true(AudioManager.sfx_streams.has("entrada_azulina"), "AudioManager tiene registrado 'entrada_azulina'")
	var stream := AudioManager.obtener_stream_sfx("entrada_azulina")
	assert_not_null(stream, "Stream de audio cargado correctamente para 'entrada_azulina'")


# === MEJORAS PARRY: DAÑO ÚNICO, AURA CELESTE Y DEGRADADO DE CÍRCULO ===
func test_animacion_dano_no_se_repite_dos_veces() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	azulina._emergiendo = false
	azulina._change_state(azulina.State.SHOOTING)

	# Act 1: primer impacto
	azulina.take_damage(1.0)

	# Assert
	assert_gt(azulina._tiempo_flinch, 0.0, "Activa el tiempo de flinch")
	assert_true(String(azulina.anim_player.current_animation).contains("Daño"), "Reproduce animación de Daño")
	var tiempo_flinch_inicial := azulina._tiempo_flinch

	# Act 2: segundo impacto consecutivo mientras aún dura el flinch
	azulina.take_damage(1.0)

	# Assert: no reinicia el flinch duplicando la animación
	assert_almost_eq(azulina._tiempo_flinch, tiempo_flinch_inicial, MARGEN_FLOAT, "No reinicia el flinch mientras está activo")

	# Act 3: procesar varios frames de shooting durante el flinch
	azulina._process_shooting(0.1)

	# Assert: procesar shooting NO reinicia la animación de Daño
	assert_lt(azulina._tiempo_flinch, tiempo_flinch_inicial, "El flinch se va consumiendo normalmente")

	# Act 4: agotar flinch
	azulina._process_shooting(azulina._tiempo_flinch + 0.05)

	# Assert: retoma la pose quieta limpiamente
	assert_true(String(azulina.anim_player.current_animation).contains(azulina.animacion_quieta) or String(azulina.anim_player.current_animation).contains("Idle"), "Retoma reposo sin repetir daño")
	_limpiar_salpicaduras()


func test_aura_celeste_parry_reducida_y_activa() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	azulina._emergiendo = false

	# Assert 1: instanciación y propiedades del aura
	assert_not_null(azulina._aura_vfx, "El nodo del aura celeste existe")
	assert_eq(azulina._aura_vfx.name, "AuraCelesteParry", "Nombre del nodo de aura")
	assert_almost_eq(azulina.escala_aura_celeste.x, 0.42, MARGEN_FLOAT, "Escala reducida en comparación con arquera rosa (0.65)")
	assert_almost_eq(azulina.color_aura_celeste_primario.b, 1.0, MARGEN_FLOAT, "Tono azul/celeste en primario")
	assert_almost_eq(azulina.offset_aura_celeste.x, -0.08, MARGEN_FLOAT, "Aura centrada en el cuerpo del personaje en X")
	assert_false(azulina._aura_vfx.visible, "El aura nace oculta")

	# Act 2: activar parry
	azulina._activar_parry()
	if azulina._tween_aura != null and azulina._tween_aura.is_valid():
		azulina._tween_aura.custom_step(0.35)

	# Assert 2: activa y escala hacia escala_aura_celeste
	assert_true(azulina._aura_vfx.visible, "El aura se hace visible durante el parry")
	assert_almost_eq(azulina._aura_vfx.position.x, -0.08, MARGEN_FLOAT, "Posición del aura centrada en el personaje")
	assert_almost_eq(azulina._aura_vfx.scale.x, azulina.escala_aura_celeste.x, MARGEN_FLOAT, "Escala al tamaño configurado")
	if is_instance_valid(azulina._aura_anim_player):
		assert_true(azulina._aura_anim_player.is_playing(), "AnimationPlayer del aura reproduce su animación")

	# Act 3: desactivar parry
	azulina._desactivar_parry()
	if azulina._tween_aura != null and azulina._tween_aura.is_valid():
		azulina._tween_aura.custom_step(0.35)

	# Assert 3: se oculta y escala a cero
	assert_false(azulina._aura_vfx.visible, "El aura se oculta al finalizar el parry")
	assert_almost_eq(azulina._aura_vfx.scale.x, 0.0, MARGEN_FLOAT, "Escala vuelve a cero")
	_limpiar_salpicaduras()


func test_circulo_protector_fade_gradiente() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	azulina._emergiendo = false

	# Act 1: mostrar círculo con disolución celeste
	azulina._mostrar_circulo(true)

	# Assert 1: material con shader de disolución y tween activo
	assert_not_null(azulina._material_circulo, "Tiene material de disolución asignado")
	assert_eq(azulina._material_circulo.get_shader_parameter("glow_color"), Color(0.35, 0.85, 1.0), "Borde de disolución en color celeste")
	assert_true(is_instance_valid(azulina._tween_circulo), "Crea tween de disolución")
	assert_almost_eq(float(azulina._material_circulo.get_shader_parameter("dissolve_amount")), 1.0, MARGEN_FLOAT, "Inicia en disolución máxima (1.0)")

	# Act: avanzar a mitad del proceso de materialización
	azulina._tween_circulo.custom_step(0.20)
	var dis_mitad: float = float(azulina._material_circulo.get_shader_parameter("dissolve_amount"))
	assert_lt(dis_mitad, 1.0, "La disolución va reduciéndose hacia 0")
	assert_gt(dis_mitad, 0.0, "Aún está en proceso de materializarse")

	# Act: completar materialización
	azulina._tween_circulo.custom_step(0.30)
	assert_almost_eq(float(azulina._material_circulo.get_shader_parameter("dissolve_amount")), 0.0, MARGEN_FLOAT, "Alcanza disolución 0.0 (totalmente nítido y visible)")

	# Act 2: ocultar círculo (disolución celeste hacia afuera)
	azulina._mostrar_circulo(false)
	assert_true(azulina._circulo.visible, "Sigue visible mientras se desintegra")
	assert_true(azulina._circulo.is_playing(), "El círculo no se congela: continúa girando en bucle mientras se desintegra")

	# Act: avanzar mitad de la disolución
	azulina._tween_circulo.custom_step(0.15)
	var dis_salida: float = float(azulina._material_circulo.get_shader_parameter("dissolve_amount"))
	assert_gt(dis_salida, 0.0, "La disolución va creciendo hacia 1")
	assert_lt(dis_salida, 1.0, "Aún no termina de desvanecerse")

	# Act: completar disolución
	azulina._tween_circulo.custom_step(0.20)
	assert_false(azulina._circulo.visible, "Se oculta al completarse la disolución celeste")
	_limpiar_salpicaduras()


func test_flechas_bloqueadas_circulo_se_desintegran_sin_dano_rebote() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	azulina._emergiendo = false
	azulina._activar_parry()

	var flecha := preload("res://Entities/Proyectil_Flecha/Arrow.tscn").instantiate() as ArrowProjectile
	add_child_autofree(flecha)
	flecha.initialize(Vector3.LEFT, 15.0)

	# Act: impactar a Azulina mientras el círculo protector está activo
	var repelido := azulina.manejar_impacto_aura(flecha)

	# Assert: El proyectil es repelido y desintegrado de inmediato
	assert_true(repelido, "El impacto es repelido durante el círculo protector")
	assert_true(flecha.desintegrando_celeste, "La flecha activa el estado de desintegración celeste")
	assert_true(flecha._destroying, "La flecha entra en estado destroying para no causar daño")
	assert_false(flecha.esta_rebotando, "No rebota como proyectil activo")
	assert_almost_eq(flecha.velocity.length(), 0.0, MARGEN_FLOAT, "La velocidad se anula para disolverse en el sitio")

	# Act 2: Avanzar el tiempo para que termine la disolución
	await get_tree().create_timer(0.45).timeout

	# Assert 2: La flecha queda liberada de memoria
	assert_false(is_instance_valid(flecha), "La flecha fue completamente liberada tras desintegrarse")
	_limpiar_salpicaduras()


func test_flecha_colision_cuerpo_durante_parry_se_desintegra_sin_dano_a_azulina() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	azulina._emergiendo = false
	azulina._activar_parry()
	var vida_inicial: float = azulina.health

	var flecha := preload("res://Entities/Proyectil_Flecha/Arrow.tscn").instantiate() as ArrowProjectile
	add_child_autofree(flecha)
	flecha.initialize(Vector3.LEFT, 15.0)

	# Act: el proyectil entra en colisión con el cuerpo de Azulina
	flecha._on_body_entered(azulina)

	# Assert: Azulina no recibe daño y la flecha se desintegra sin rebotar
	assert_almost_eq(azulina.health, vida_inicial, MARGEN_FLOAT, "Azulina no recibe daño alguno durante el parry")
	assert_true(flecha.desintegrando_celeste, "La flecha entra en estado de desintegración")
	assert_true(flecha._destroying, "La flecha está en destrucción activa")
	assert_false(flecha.esta_rebotando, "No genera proyectil de rebote activo")

	await get_tree().create_timer(0.45).timeout
	assert_false(is_instance_valid(flecha), "La flecha se disuelve y libera de memoria")
	_limpiar_salpicaduras()


# === REPOSICIONAMIENTO CON PIQUERO TRAS 5 ATAQUES ===
func test_reposicion_se_activa_tras_5_ataques() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	azulina._emergiendo = false
	azulina.reposicionamiento_habilitado = true
	azulina.ataques_para_reposicion = 5
	azulina._change_state(azulina.State.SHOOTING)

	# Act: Simular 4 ataques completados
	for i in range(4):
		azulina._iniciar_ataque()
		azulina._timer_lanzamiento = azulina._duracion_anim_ataque()
		azulina._process_shooting(0.01)
		assert_false(azulina._reposicionando, "Con menos de 5 ataques no inicia piquero")

	assert_eq(azulina._contador_ataques_realizados, 4, "Lleva 4 ataques registrados")

	# Act: 5to ataque completado
	azulina._iniciar_ataque()
	azulina._timer_lanzamiento = azulina._duracion_anim_ataque()
	azulina._process_shooting(0.01)

	# Assert: Se activa el reposicionamiento de piquero y se reinicia el contador
	assert_true(azulina._reposicionando, "Al 5to ataque inicia el salto de piquero")
	assert_eq(azulina._contador_ataques_realizados, 0, "El contador se reinicia a 0")
	assert_true(String(azulina.anim_player.current_animation).contains("Piquero"), "Reproduce animación Piquero")
	_limpiar_lanzas()
	_limpiar_salpicaduras()


func test_iniciar_reposicion_piquero_configura_arco_animacion_y_rotacion() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	azulina._emergiendo = false
	var pos_inicial := Vector3(2.0, 0.5, 0.0)
	azulina.global_position = pos_inicial

	# Act
	azulina.iniciar_reposicion_piquero()

	# Assert
	assert_true(azulina._reposicionando, "Pasa a estado de reposicionando")
	assert_false(azulina._bajo_agua_esperando, "Aún no está esperando bajo el agua")
	assert_almost_eq(azulina._origen_piquero.x, pos_inicial.x, MARGEN_FLOAT, "Origen X correcto")
	assert_almost_eq(azulina._origen_piquero.y, pos_inicial.y, MARGEN_FLOAT, "Origen Y correcto")
	# Vector hacia el destino en ángulo de 230° (-X y -Y)
	var delta_destino: Vector3 = azulina._destino_piquero - azulina._origen_piquero
	assert_lt(delta_destino.x, 0.0, "Destino X hacia la izquierda (-X)")
	assert_lt(delta_destino.y, 0.0, "Destino Y hacia abajo en el agua (-Y)")
	var angulo_deg: float = rad_to_deg(atan2(delta_destino.y, delta_destino.x))
	if angulo_deg < 0.0:
		angulo_deg += 360.0
	assert_almost_eq(angulo_deg, 230.0, 0.1, "El ángulo de salida es exactamente 230 grados")
	assert_true(String(azulina.anim_player.current_animation).contains("Piquero"), "Animación de Piquero activa")
	# El modelo conserva su orientación natural mirando a la izquierda (-X) para el piquero a 230°
	assert_almost_eq(azulina._modelo.rotation.y, azulina._rotacion_modelo_base_y, MARGEN_FLOAT, "Modelo orientado hacia la izquierda")
	_limpiar_salpicaduras()


func test_piquero_sumersion_sale_a_230_grados() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	azulina._emergiendo = false
	azulina.global_position = Vector3(2.0, 0.5, 0.0)
	_limpiar_salpicaduras()
	azulina.iniciar_reposicion_piquero()

	# Act 1: Avanzar hasta superar la fase de despegue (momento_submersion_piquero)
	var t_submersion: float = azulina.duracion_piquero * azulina.momento_submersion_piquero + 0.05
	azulina._procesar_reposicion_piquero(t_submersion)

	# Act 2: Procesar dos pasos dentro de la fase de sumersión
	var pos1: Vector3 = azulina.global_position
	azulina._procesar_reposicion_piquero(0.1)
	var pos2: Vector3 = azulina.global_position

	# Assert: El vector de desplazamiento en XY tiene ángulo de 230°
	var delta: Vector3 = pos2 - pos1
	assert_lt(delta.x, 0.0, "Avanza hacia la izquierda (-X)")
	assert_lt(delta.y, 0.0, "Desciende hacia el fondo (-Y)")
	var angulo_mov: float = rad_to_deg(atan2(delta.y, delta.x))
	if angulo_mov < 0.0:
		angulo_mov += 360.0
	assert_almost_eq(angulo_mov, 230.0, 0.1, "Al sumergirse desciende en un ángulo de exactamente 230 grados")
	_limpiar_salpicaduras()


func test_piquero_no_genera_salpicadura_al_entrar_al_agua() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	azulina._emergiendo = false
	azulina.salpicadura_al_emerger = true
	_limpiar_salpicaduras()
	azulina.iniciar_reposicion_piquero()
	assert_eq(_contar_salpicaduras(), 0, "Al despegar aún no hay salpicadura")

	# Act: Simular avance hasta que desciende en el arco
	var t: float = 0.0
	while azulina._reposicionando and t < azulina.duracion_piquero * 0.75:
		azulina._procesar_reposicion_piquero(0.05)
		t += 0.05

	# Assert: No genera salpicadura al sumergirse
	assert_eq(_contar_salpicaduras(), 0, "No genera salpicadura al sumergirse en piquero")
	_limpiar_salpicaduras()


func test_sumersion_fuera_de_camara_y_espera() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	azulina._emergiendo = false
	azulina.iniciar_reposicion_piquero()

	# Act: Completar el salto completo de piquero hasta sumergirse por completo
	var t: float = 0.0
	while azulina._reposicionando and t < 10.0:
		azulina._procesar_reposicion_piquero(0.05)
		t += 0.05

	# Assert: Queda sumergida, invisible fuera de cuadro y esperando bajo el agua
	assert_false(azulina._reposicionando, "Termina el salto de piquero")
	assert_true(azulina._bajo_agua_esperando, "Pasa a estado esperando bajo el agua")
	assert_false(azulina.visible, "Se oculta de la cámara fuera de cuadro")
	assert_eq(azulina.collision_layer, 0, "Colisión desactivada mientras está bajo agua")
	assert_almost_eq(azulina._timer_bajo_agua, azulina.tiempo_bajo_agua, MARGEN_FLOAT, "Inicia el temporizador bajo agua")
	assert_almost_eq(azulina._modelo.rotation.y, azulina._rotacion_modelo_base_y, MARGEN_FLOAT, "Restaura la rotación base del modelo")
	_limpiar_salpicaduras()


func test_reemergencia_tras_reposicionamiento_vuelve_a_entrar_normal() -> void:
	# Arrange: Azulina sumergida esperando
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	azulina._emergiendo = false
	azulina.iniciar_reposicion_piquero()
	var t: float = 0.0
	while azulina._reposicionando and t < 10.0:
		azulina._procesar_reposicion_piquero(0.05)
		t += 0.05
	assert_true(azulina._bajo_agua_esperando, "Precondición: sumergida")

	# Act: Consumir el tiempo de espera bajo el agua
	azulina._procesar_reposicion_piquero(azulina.tiempo_bajo_agua + 0.1)

	# Assert: Vuelve a emerger de la forma normal
	assert_false(azulina._bajo_agua_esperando, "Termina la espera bajo el agua")
	assert_true(azulina.visible, "Vuelve a ser visible")
	assert_true(azulina._emergiendo, "Inicia la emergencia normal desde el agua")
	assert_true(String(azulina.anim_player.current_animation).contains("Ataque salto del agua"), "Reproduce la animación de salto de entrada normal")
	assert_eq(azulina.collision_layer, 4, "Capas de colisión restauradas")

	# Act: Completar la emergencia normal
	var te: float = 0.0
	while azulina._emergiendo and te < 10.0:
		azulina._procesar_emergencia(0.05)
		te += 0.05

	# Assert: Aterrizó y reanudó combate
	assert_false(azulina._emergiendo, "Completa el aterrizaje normal")
	_limpiar_lanzas()
	_limpiar_salpicaduras()


func test_reposicionamiento_desactivado_no_salta() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	azulina._emergiendo = false
	azulina.reposicionamiento_habilitado = false
	azulina.ataques_para_reposicion = 5
	azulina._change_state(azulina.State.SHOOTING)

	# Act: Simular 5 ataques
	for i in range(5):
		azulina._iniciar_ataque()
		azulina._timer_lanzamiento = azulina._duracion_anim_ataque()
		azulina._process_shooting(0.01)

	# Assert: No activa reposicionamiento
	assert_false(azulina._reposicionando, "Con reposicionamiento_habilitado = false no salta")
	assert_false(azulina._bajo_agua_esperando, "No va bajo el agua")
	_limpiar_lanzas()
	_limpiar_salpicaduras()


func test_dano_en_piquero_no_corta_con_flinch() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	azulina._emergiendo = false
	azulina.iniciar_reposicion_piquero()
	var vida_antes: int = azulina.health

	# Act: Recibe daño no letal en pleno salto
	azulina.take_damage(1.0)

	# Assert: Recibe daño pero no interrumpe el piquero con la animación de flinch
	assert_eq(azulina.health, vida_antes - 1, "Recibe el daño")
	assert_true(azulina._reposicionando, "El salto de piquero continúa")
	assert_true(String(azulina.anim_player.current_animation).contains("Piquero"), "Sigue en animación Piquero")
	_limpiar_salpicaduras()


func test_dano_cancela_ataque_y_recupera_a_idle_antes_de_atacar() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	azulina._emergiendo = false
	azulina._change_state(azulina.State.SHOOTING)
	_limpiar_lanzas()

	# Act 1: Iniciar ataque y avanzar a mitad de preparación (0.4s)
	azulina._iniciar_ataque()
	azulina._process_shooting(0.4)
	assert_true(azulina._lanzando, "Está en pleno ataque")
	assert_false(azulina._lanzo_proyectil, "Aún no lanza la lanza")

	# Act 2: Recibe impacto no letal
	azulina.take_damage(1.0)
	assert_gt(azulina._tiempo_flinch, 0.0, "Entra en flinch de daño")
	assert_true(String(azulina.anim_player.current_animation).contains("Daño"), "Reproduce animación de Daño")

	# Act 3: Consumir el tiempo de flinch
	azulina._process_shooting(azulina._tiempo_flinch + 0.05)

	# Assert: Recupera a Idle, el ataque interrumpido fue cancelado sin disparar a ciegas
	assert_false(azulina._lanzando, "El ataque previo fue cancelado limpiamente")
	assert_false(azulina._lanzo_proyectil, "No disparó proyectil mientras recibía daño")
	assert_true(String(azulina.anim_player.current_animation).contains(azulina.animacion_quieta) or String(azulina.anim_player.current_animation).contains("Idle"), "Transiciona con calma a Idle")
	assert_eq(_contar_lanzas(), 0, "No se arrojó ninguna lanza fantasma")

	# Act 4: Consumir la pausa natural en Idle para iniciar un ataque nuevo
	azulina._process_shooting(azulina._pausa_lanzamiento + 0.05)

	# Assert: Ahora sí inicia un nuevo ataque limpio con su animación completa
	assert_true(azulina._lanzando, "Inicia nuevo ataque tras el reposo")
	assert_true(String(azulina.anim_player.current_animation).contains("Ataque"), "Muestra la animación Ataque con viento completo")
	_limpiar_lanzas()
	_limpiar_salpicaduras()


func test_piquero_sin_splash_al_sumergirse() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	azulina._emergiendo = false
	azulina.salpicadura_al_emerger = true
	azulina.global_position = Vector3(2.0, 0.2, 0.0)
	_limpiar_salpicaduras()
	azulina.iniciar_reposicion_piquero()

	# Act: Avanzar a lo largo de todo el salto de piquero hasta sumergirse
	var t: float = 0.0
	while azulina._reposicionando and t < 5.0:
		azulina._procesar_reposicion_piquero(0.05)
		t += 0.05

	# Assert: El piquero se completó sin generar salpicadura alguna
	assert_true(azulina._bajo_agua_esperando, "Pasa al estado de espera bajo el agua")
	var conteo_splash: int = 0
	var raiz: Node = azulina.get_tree().current_scene if azulina.get_tree().current_scene != null else azulina.get_tree().root
	for child in raiz.get_children():
		if child is SalpicaduraAgua:
			conteo_splash += 1
	assert_eq(conteo_splash, 0, "No se genera salpicadura al sumergirse en piquero")
	_limpiar_salpicaduras()


func test_desvio_normal_maximo_dos_proyectiles() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	azulina._emergiendo = false
	azulina.probabilidad_desvio_normal = 0.0  # Controlamos manualmente la activación

	# Act 1: Activar el giro de desvío
	azulina._ejecutar_desvio_giro()
	assert_true(azulina._desviando_giro, "Giro de desvío activo")
	assert_eq(azulina._contador_desvios_giro, 1, "Primer proyectil contabilizado al iniciar desvío")

	# Act 2: Segundo proyectil impacta durante el mismo giro
	var dummy_flecha2 := Node3D.new()
	add_child_autofree(dummy_flecha2)
	var resultado2: bool = azulina.manejar_impacto_aura(dummy_flecha2)

	# Assert 2: Segundo proyectil sí es desviado
	assert_true(resultado2, "El segundo proyectil es desviado con éxito")
	assert_eq(azulina._contador_desvios_giro, 2, "Contador llega al máximo de 2 desvíos")

	# Act 3: Tercer proyectil impacta durante el mismo giro
	var dummy_flecha3 := Node3D.new()
	add_child_autofree(dummy_flecha3)
	var resultado3: bool = azulina.manejar_impacto_aura(dummy_flecha3)

	# Assert 3: Tercer proyectil NO se desvía (límite alcanzado)
	assert_false(resultado3, "El tercer proyectil no se desvía y penetra la defensa")


func test_lanza_voladora_gira_y_se_clava_con_punta_hacia_abajo() -> void:
	# Arrange
	var lanza_voladora := LanzaVoladora.new()
	add_child_autofree(lanza_voladora)
	lanza_voladora.global_position = Vector3(0.0, 2.0, 0.0)

	# Act 1: Iniciar vuelo con rotación para girar en el aire
	lanza_voladora.iniciar_vuelo(Vector3(3.0, 5.0, 0.0), -10.0)
	assert_true(lanza_voladora.active, "Lanza activa en vuelo")
	assert_ne(lanza_voladora.rot_speed_z, 0.0, "Tiene velocidad angular para girar en el aire")

	# Act 2: Simular aterrizaje y clavado en el suelo
	var pos_impacto := Vector3(2.5, 0.0, 0.0)
	lanza_voladora._clavar_en_suelo(pos_impacto)

	# Assert 2: La lanza detiene su movimiento y queda clavada
	assert_true(lanza_voladora._clavada, "Marcada como clavada")
	assert_false(lanza_voladora.active, "Ya no está activa en vuelo")
	assert_true(lanza_voladora.resting, "En estado de reposo")
	assert_eq(lanza_voladora.velocity, Vector3.ZERO, "Velocidad en cero")
	assert_eq(lanza_voladora.rot_speed_z, 0.0, "Rotación detenida")

	# Assert 3: Punta hacia abajo (rotación en Z cercana a PI o -PI = 180°)
	assert_almost_eq(absf(lanza_voladora.rotation.z), PI, 0.35, "Rotada ~180° para apuntar la punta hacia abajo")

	# Assert 4: La punta (eje local +Y) queda ligeramente enterrada bajo el nivel del suelo
	var offset_punta: Vector3 = lanza_voladora.global_transform.basis * Vector3(0.0, 1.0, 0.0)
	var punta_mundo: Vector3 = lanza_voladora.global_position + offset_punta
	assert_lte(punta_mundo.y, pos_impacto.y, "La punta queda enterrada en o bajo el suelo")







class FlechaFalsa:
	extends Node3D
	var es_explosiva: bool = false


func _crear_flecha_falsa(explosiva: bool) -> Node3D:
	var f := FlechaFalsa.new()
	f.es_explosiva = explosiva
	add_child_autofree(f)
	return f


func test_explosiva_no_se_desvia() -> void:
	# Arrange: desv�o garantizado para normales
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	azulina.probabilidad_desvio_normal = 1.0
	azulina._emergiendo = false
	var flecha := _crear_flecha_falsa(true)

	# Act
	var resultado: bool = azulina.manejar_impacto_aura(flecha)

	# Assert: pasa de largo para detonar al impactar
	assert_false(resultado, "La explosiva no se desv�a")
	assert_false(azulina._desviando_giro, "No inicia desv�o")
	_limpiar_salpicaduras()


func test_explosiva_atraviesa_parry_activo() -> void:
	# Arrange: parry activo
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
	azulina.ataques_para_parry_min = 1
	azulina.ataques_para_parry_max = 1
	azulina._emergiendo = false
	azulina.manejar_impacto_aura(null)
	assert_true(azulina._parry_activo, "Precondici�n: parry activo")

	# Act: llega una explosiva en pleno giro
	var resultado: bool = azulina.manejar_impacto_aura(_crear_flecha_falsa(true))

	# Assert: penetra (detonar� al impactar el cuerpo)
	assert_false(resultado, "La explosiva atraviesa el parry")
	_limpiar_salpicaduras()

