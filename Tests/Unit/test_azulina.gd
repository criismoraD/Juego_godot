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
	assert_not_null(azulina.find_child("LanzaMano", true, false), "Debe llevar la lanza en mano")
	assert_not_null(azulina.find_child("CollisionShape3D", true, false), "Debe tener colisión")
	assert_eq(azulina.vida_maxima, 3, "3 de vida base")


func test_valores_combate_potentes_y_precisos() -> void:
	# Arrange & Act
	var azulina := _crear_azulina()

	# Assert: más potente y precisa que el tridente del imp (8 vel, 1.2 grav, 2.0 daño)
	assert_gt(azulina.velocidad_lanza, 8.0, "Lanza más rápida que el tridente")
	assert_lt(azulina.gravedad_lanza, 1.2, "Trayectoria más tensa que el tridente")
	assert_lt(azulina.dispersion_rad, 0.1, "Dispersión mínima: precisión alta")
	assert_eq(LanzaAzulinaProjectile.DANO_LANZA_AZULINA, 3.0, "Daño mayor que el tridente (2.0)")


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
	assert_gt(destino.x, origen.x - 0.01, "Nace a la derecha del destino")
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


# === ESCALA Y ORIENTACIÓN ===
func test_escala_igual_que_ballestera_aliada() -> void:
	# Arrange & Act
	var azulina := _crear_azulina()
	var ballestera_scene := load("res://Entities/Aliada_Ballestera/AllyBallestera.tscn") as PackedScene
	var ballestera := ballestera_scene.instantiate() as Node3D
	add_child_autofree(ballestera)

	# Assert: raíz sin escala extra (como la ballestera aliada y el resto de enemigos)
	assert_eq(azulina.scale, Vector3.ONE, "La raíz de Azulina no debe escalar (igual que la ballestera)")

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

	# Assert: convención enemiga (igual que Goblin/Imp): X apunta a -Z mundo y Z a +X mundo
	# (en la escena anterior miraba a +X como las aliadas; debe estar volteada 180° en Y)
	var base: Basis = modelo.transform.basis
	assert_lt(base.x.z, 0.0, "El eje X del modelo debe apuntar a -Z (convención enemiga)")
	assert_gt(base.z.x, 0.0, "El eje Z del modelo debe apuntar a +X (convención enemiga)")

	# Assert: la lanza va fijada a la mano derecha (sigue a la animación) y conserva escala
	var lanza := azulina.find_child("LanzaMano", true, false) as Node3D
	assert_not_null(lanza, "Debe llevar la lanza en mano")
	var fijacion := lanza.get_parent() as BoneAttachment3D
	assert_not_null(fijacion, "La lanza debe colgar de un BoneAttachment3D")
	assert_eq(fijacion.bone_name, "mixamorig_RightHand", "La lanza va posada en la mano derecha")
	assert_almost_eq(lanza.scale.x, 0.6, MARGEN_FLOAT, "La lanza conserva su escala")


func test_colision_mantiene_tamano_de_mundo() -> void:
	# Arrange & Act
	var azulina := _crear_azulina()
	var colision := azulina.find_child("CollisionShape3D", true, false) as CollisionShape3D

	# Assert: cápsula acorde a una Azulina de ~0.9 m (r 0.18, h 0.65, y 0.325)
	var capsula := colision.shape as CapsuleShape3D
	assert_almost_eq(capsula.radius, 0.18, MARGEN_FLOAT, "Radio de colisión acorde al tamaño")
	assert_almost_eq(capsula.height, 0.65, MARGEN_FLOAT, "Altura de colisión acorde al tamaño")
	assert_almost_eq(colision.position.y, 0.325, MARGEN_FLOAT, "Altura de colisión acorde al tamaño")


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
		if n is LanzaAzulinaProjectile:
			conteo += 1
	return conteo


func _limpiar_lanzas() -> void:
	for n in get_tree().root.get_children():
		if n is LanzaAzulinaProjectile:
			(n as Node).queue_free()


func _contar_salpicaduras() -> int:
	var conteo: int = 0
	for n in get_tree().root.get_children():
		if n is SalpicaduraAzulina and not (n as Node).is_queued_for_deletion():
			conteo += 1
	return conteo


func _limpiar_salpicaduras() -> void:
	for n in get_tree().root.get_children():
		if n is SalpicaduraAzulina:
			(n as Node).queue_free()


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
	azulina.zona_extension = Vector3(4.0, 0.0, 1.5)

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
	_limpiar_lanzas()
	_limpiar_salpicaduras()


# === PARRY DE LANZA ===
func test_parry_se_activa_cada_n_ataques() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
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
	_limpiar_salpicaduras()


func test_parry_multidisparo_inmediato() -> void:
	# Arrange
	var azulina := _crear_azulina()
	azulina.emerger_del_agua = false
	azulina.emergencia_en_zona_aleatoria = false
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
