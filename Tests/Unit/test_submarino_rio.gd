extends "res://addons/gut/test.gd"

## Tests unitarios para el Submarino del Nivel Río (SubmarinoRio)

var SubmarinoScene: PackedScene = preload("res://Levels/Rio_En_Canoa_Con_Parallax/SubmarinoRio.tscn")
var CanoaScene: PackedScene = preload("res://Levels/Rio_En_Canoa_Con_Parallax/CanoaProtagonistaRio.tscn")

var _root_test: Node3D = null


func before_each() -> void:
	_root_test = Node3D.new()
	_root_test.name = "RootTestSubmarino"
	get_tree().root.add_child(_root_test)
	get_tree().current_scene = _root_test


func after_each() -> void:
	if is_instance_valid(_root_test):
		_root_test.free()
	for n in get_tree().root.get_children():
		if n is SubmarinoRio or n is GoblinGirl or n is ImpEnemy:
			n.free()


## 1. El submarino debe iniciar sumergido por debajo de la altura de emergencia
func test_submarino_inicia_sumergido() -> void:
	# Arrange
	var submarino: SubmarinoRio = SubmarinoScene.instantiate() as SubmarinoRio
	submarino.position = Vector3(40.0, -0.5, -7.5)
	submarino.altura_emergido_y = -0.5
	submarino.profundidad_sumergido = 4.0
	submarino.activar_al_entrar_en_camara = false

	# Act
	_root_test.add_child(submarino)

	# Assert
	assert_eq(submarino.current_state, SubmarinoRio.State.SUMERGIDO, "Debe iniciar en estado SUMERGIDO")
	assert_almost_eq(submarino.position.y, -4.5, 0.01, "La posición Y inicial debe ser -0.5 - 4.0 = -4.5")


## 2. Al emerger, debe ascender verticalmente hasta altura_emergido_y
func test_submarino_emerge_a_altura_configurada() -> void:
	# Arrange
	var submarino: SubmarinoRio = SubmarinoScene.instantiate() as SubmarinoRio
	submarino.position = Vector3(40.0, 0.0, -7.5)
	submarino.altura_emergido_y = 0.0
	submarino.profundidad_sumergido = 2.0
	submarino.velocidad_emerger = 10.0
	submarino.activar_al_entrar_en_camara = false
	_root_test.add_child(submarino)

	# Act
	submarino.emerger()
	assert_eq(submarino.current_state, SubmarinoRio.State.EMERGIENDO, "Debe cambiar a EMERGIENDO")

	# Simular avance del ascenso
	submarino._process(0.3)

	# Assert
	assert_almost_eq(submarino.position.y, 0.0, 0.01, "Debe alcanzar la altura objetivo de 0.0")
	assert_eq(submarino.current_state, SubmarinoRio.State.EN_SUPERFICIE, "Debe pasar a EN_SUPERFICIE")
	assert_true(submarino.esta_en_superficie(), "esta_en_superficie() debe retornar true")


## 3. La plataforma de la cubierta (zona rosada) debe tener colisión sólida en capa 1
func test_submarino_plataforma_cubierta_tiene_colision() -> void:
	# Arrange
	var submarino: SubmarinoRio = SubmarinoScene.instantiate() as SubmarinoRio
	_root_test.add_child(submarino)

	# Assert
	assert_not_null(submarino.plataforma_cubierta, "Debe existir PlataformaCubierta")
	assert_eq(submarino.plataforma_cubierta.collision_layer, 1, "La plataforma de la cubierta debe estar en capa 1 (terreno/superficies)")

	var col := submarino.plataforma_cubierta.find_child("CollisionShape3D", true, false) as CollisionShape3D
	assert_not_null(col, "Debe poseer CollisionShape3D")
	assert_not_null(col.shape, "Debe tener una forma asignada")
	assert_true(col.shape is BoxShape3D, "La plataforma debe ser una caja BoxShape3D horizontal")

	# Casco
	var casco := submarino.find_child("CascoColision", true, false) as StaticBody3D
	assert_not_null(casco, "Debe existir colisión para el casco")
	assert_eq(casco.collision_layer, 1, "El casco debe colisionar en capa 1")


## 4. Despliegue de enemigos tipo GOBLIN_ARQUERA desde el SpawnPoint
func test_submarino_spawn_enemigos_goblin_arquera() -> void:
	# Arrange
	var submarino: SubmarinoRio = SubmarinoScene.instantiate() as SubmarinoRio
	submarino.altura_emergido_y = 0.0
	submarino.profundidad_sumergido = 0.0
	submarino.tipo_enemigo = SubmarinoRio.TipoEnemigo.GOBLIN_ARQUERA
	submarino.cantidad_enemigos = 2
	submarino.intervalo_spawn = 0.0
	submarino.activar_al_entrar_en_camara = false
	_root_test.add_child(submarino)

	# Act: emerger y procesar spawneo
	submarino.emerger()
	submarino._process(0.1)  # Pasa a EN_SUPERFICIE y spawnea primer enemigo
	submarino._process(0.1)  # Spawnea segundo enemigo
	submarino._process(0.1)  # Verifica fin de spawns

	# Assert
	var goblins := _root_test.find_children("*", "GoblinGirl", true, false)
	assert_eq(goblins.size(), 2, "Deben haberse spawneado 2 GoblinGirl")
	for g in goblins:
		var goblin := g as GoblinGirl
		assert_true(goblin.solo_atacar_en_pantalla, "Los enemigos del submarino deben tener solo_atacar_en_pantalla = true")
		assert_almost_eq(goblin.velocidad_caminar, 0.0, 0.01, "Deben permanecer como centinelas en la cubierta")


## 5. Despliegue de enemigos tipo IMP
func test_submarino_spawn_enemigos_imp() -> void:
	# Arrange
	var submarino: SubmarinoRio = SubmarinoScene.instantiate() as SubmarinoRio
	submarino.altura_emergido_y = 0.0
	submarino.profundidad_sumergido = 0.0
	submarino.tipo_enemigo = SubmarinoRio.TipoEnemigo.IMP
	submarino.cantidad_enemigos = 1
	submarino.intervalo_spawn = 0.0
	submarino.activar_al_entrar_en_camara = false
	_root_test.add_child(submarino)

	# Act
	submarino.emerger()
	submarino._process(0.1)

	# Assert
	var imps := _root_test.find_children("*", "ImpEnemy", true, false)
	assert_eq(imps.size(), 1, "Debe haberse spawneado 1 ImpEnemy")


## 6. Al morir todos los enemigos spawneados, el submarino se sumerge y desciende
func test_submarino_se_sumerge_al_morir_enemigos() -> void:
	# Arrange
	var submarino: SubmarinoRio = SubmarinoScene.instantiate() as SubmarinoRio
	submarino.altura_emergido_y = 0.0
	submarino.profundidad_sumergido = 2.0
	submarino.velocidad_emerger = 50.0
	submarino.velocidad_sumergir = 5.0
	submarino.cantidad_enemigos = 1
	submarino.intervalo_spawn = 0.0
	submarino.activar_al_entrar_en_camara = false
	submarino.canon_disparo_final = false  ## Sumersión directa sin despedida del cañón
	_root_test.add_child(submarino)

	# Act: emerger y spawnear
	submarino.emerger()
	submarino._process(0.1)
	submarino._process(0.1)
	assert_eq(submarino.current_state, SubmarinoRio.State.ESPERANDO_MUERTE)

	# Eliminar al enemigo simulando muerte
	var goblins := _root_test.find_children("*", "GoblinGirl", true, false)
	assert_eq(goblins.size(), 1)
	goblins[0].free()
	await get_tree().process_frame

	# Procesar submarino
	submarino._process(0.1)

	# Assert: debe haber pasado a SUMERGIENDOSE
	assert_eq(submarino.current_state, SubmarinoRio.State.SUMERGIENDOSE, "Debe comenzar a sumergirse tras morir los enemigos")

	# Avanzar sumersión
	var y_antes: float = submarino.position.y
	submarino._process(0.2)
	assert_lt(submarino.position.y, y_antes, "La posición Y debe estar descendiendo")


## 7. Flotación activa mece suavemente el pivot de flotación
func test_submarino_flotacion_suave() -> void:
	# Arrange
	var submarino: SubmarinoRio = SubmarinoScene.instantiate() as SubmarinoRio
	submarino.altura_emergido_y = 0.0
	submarino.profundidad_sumergido = 0.0
	submarino.flotacion_activa = true
	submarino.activar_al_entrar_en_camara = false
	_root_test.add_child(submarino)

	submarino.emerger()
	submarino._process(0.1)

	# Act
	var y_inicial: float = submarino.pivot_flotacion.position.y
	submarino._process(0.25)
	var y_floteo: float = submarino.pivot_flotacion.position.y

	# Assert
	assert_ne(y_floteo, y_inicial, "El pivot de flotación debe oscilar verticalmente en el agua")


## 8. Los enemigos desplegados pasan a SHOOTING y no se quedan caminando sin atacar
func test_submarino_enemigos_entran_en_modo_ataque() -> void:
	# Arrange
	var submarino: SubmarinoRio = SubmarinoScene.instantiate() as SubmarinoRio
	submarino.altura_emergido_y = 0.0
	submarino.profundidad_sumergido = 0.0
	submarino.tipo_enemigo = SubmarinoRio.TipoEnemigo.GOBLIN_ARQUERA
	submarino.cantidad_enemigos = 1
	submarino.intervalo_spawn = 0.0
	submarino.activar_al_entrar_en_camara = false
	_root_test.add_child(submarino)

	# Act
	submarino.emerger()
	submarino._process(0.1)  # Spawnea enemigo

	var goblins := _root_test.find_children("*", "GoblinGirl", true, false)
	assert_eq(goblins.size(), 1)
	var goblin := goblins[0] as GoblinGirl

	# Simular avance del tween (0.6s)
	await get_tree().create_timer(0.7).timeout

	# Assert: debe estar en modo SHOOTING y no dormida
	assert_false(goblin.get("_dormida_por_camara"), "El enemigo en cubierta no debe estar dormido")
	assert_eq(goblin.current_state, EnemyBase.State.SHOOTING, "El enemigo debe entrar en estado de disparo/ataque")


## 9. El submarino emerge únicamente al estar en el encuadre visible de la cámara
func test_submarino_emerge_cuando_camara_entra_en_rango_visible() -> void:
	# Arrange: cámara en 0, submarino en X = 20 (fuera de cámara)
	var cam := Camera3D.new()
	cam.name = "CamaraTestSub"
	cam.current = true
	_root_test.add_child(cam)
	cam.global_position = Vector3(0.0, 3.0, 30.0)

	var submarino: SubmarinoRio = SubmarinoScene.instantiate() as SubmarinoRio
	submarino.activar_al_entrar_en_camara = true
	submarino.distancia_activacion_x = 7.5
	_root_test.add_child(submarino)
	submarino.global_position = Vector3(20.0, -1.7, -7.5)

	# Act 1: submarino fuera de rango visible
	submarino._process(0.016)
	assert_eq(submarino.current_state, SubmarinoRio.State.SUMERGIDO, "Debe permanecer sumergido si la cámara está lejos")

	# Act 2: cámara se aproxima a X = 13.5 (dx = 6.5 <= 7.5, entra al encuadre)
	cam.global_position.x = 13.5
	submarino._process(0.016)

	# Assert
	assert_eq(submarino.current_state, SubmarinoRio.State.EMERGIENDO, "Debe comenzar a emerger al entrar en el encuadre visible de la cámara")


## 10. Al comenzar la sumersión, el submarino debe dejar de contar como enemigo inmediatamente para que la canoa pueda avanzar sin frenarse
func test_submarino_deja_de_contar_como_enemigo_al_hundirse_para_que_canoa_avance() -> void:
	# Arrange
	var canoa: CanoaProtagonistaRio = CanoaScene.instantiate() as CanoaProtagonistaRio
	_root_test.add_child(canoa)
	canoa.global_position = Vector3(0.0, 0.0, -7.5)

	var submarino: SubmarinoRio = SubmarinoScene.instantiate() as SubmarinoRio
	_root_test.add_child(submarino)
	submarino.global_position = Vector3(2.0, 0.0, -7.5)
	submarino.canon_disparo_final = false  ## Sumersión directa sin despedida del cañón

	# El submarino emerge a la superficie
	submarino.current_state = SubmarinoRio.State.EN_SUPERFICIE
	submarino.add_to_group("enemies")
	submarino.add_to_group("enemigos")

	# Act 1: La canoa detecta al submarino emergido como enemigo
	canoa._actualizar_reaccion_enemigos()

	# Assert 1: La canoa se detiene por contacto/presencia del submarino
	assert_true(canoa.esta_detenida_por_enemigo(), "La canoa debe detenerse ante el submarino emergido")
	assert_eq(canoa.obtener_factor_velocidad_actual(), 0.0, "La velocidad de la canoa debe ser 0.0")

	# Act 2: Todos los enemigos mueren y el submarino inicia su sumersión
	submarino._iniciar_sumersion()

	# Assert 2: El submarino ya no está en superficie ni es considerado enemigo activo
	assert_eq(submarino.current_state, SubmarinoRio.State.SUMERGIENDOSE)
	assert_false(submarino.esta_en_superficie(), "No debe estar en superficie al sumergirse")
	assert_false(submarino.es_enemigo_activo(), "No debe ser enemigo activo al sumergirse")
	assert_false(submarino.is_in_group("enemies"), "Debe removerse del grupo enemies al sumergirse")
	assert_false(submarino.is_in_group("enemigos"), "Debe removerse del grupo enemigos al sumergirse")

	# Act 3: La canoa actualiza su reacción a enemigos
	canoa._actualizar_reaccion_enemigos()

	# Assert 3: La canoa reanuda su marcha inmediatamente sin esperar que el submarino desaparezca
	assert_false(canoa.esta_detenida_por_enemigo(), "La canoa ya no debe estar detenida")
	assert_eq(canoa.obtener_factor_velocidad_actual(), 1.0, "La canoa debe avanzar a velocidad completa (1.0)")


func test_emerger_reproduce_sonido_submarino_emergiendo() -> void:
	# Arrange: submarino sumergido
	var submarino: SubmarinoRio = SubmarinoScene.instantiate() as SubmarinoRio
	submarino.position = Vector3(40.0, 0.0, -7.5)
	submarino.altura_emergido_y = 0.0
	submarino.profundidad_sumergido = 2.0
	submarino.activar_al_entrar_en_camara = false
	_root_test.add_child(submarino)

	# Act: iniciar emergencia
	submarino.emerger()

	# Assert: estado + sonido posicionado
	assert_eq(submarino.current_state, SubmarinoRio.State.EMERGIENDO, "Debe cambiar a EMERGIENDO")
	assert_not_null(_root_test.find_child("SfxEmergiendo", true, false), "Al emerger debe sonar submarino_emergiendo")


## 12. Los enemigos que salen del submarino caminan con animación, se orientan en la dirección de marcha y se detienen antes de atacar
func test_submarino_enemigos_caminan_se_orientan_y_se_detienen_para_atacar() -> void:
	# Arrange: Submarino con 2 enemigos (uno irá hacia proa -X y otro hacia popa +X)
	var submarino: SubmarinoRio = SubmarinoScene.instantiate() as SubmarinoRio
	submarino.altura_emergido_y = 0.0
	submarino.profundidad_sumergido = 0.0
	submarino.tipo_enemigo = SubmarinoRio.TipoEnemigo.GOBLIN_ARQUERA
	submarino.cantidad_enemigos = 2
	submarino.intervalo_spawn = 0.0
	submarino.activar_al_entrar_en_camara = false
	_root_test.add_child(submarino)

	# Act 1: emerger y desplegar ambos enemigos
	submarino.emerger()
	submarino._process(0.016)  # Primer enemigo (proa, delta_x < 0)
	submarino._process(0.016)  # Segundo enemigo (popa, delta_x > 0)

	var goblins := _root_test.find_children("*", "GoblinGirl", true, false)
	assert_eq(goblins.size(), 2, "Deben haberse instanciado 2 enemigos")
	var gob_proa := goblins[0] as GoblinGirl
	var gob_popa := goblins[1] as GoblinGirl

	# Assert 1: Durante el desplazamiento deben estar en WALKING
	assert_eq(gob_proa.current_state, EnemyBase.State.WALKING, "El enemigo hacia proa debe iniciar caminando (WALKING)")
	assert_eq(gob_popa.current_state, EnemyBase.State.WALKING, "El enemigo hacia popa debe iniciar caminando (WALKING)")

	# Assert 2: Orientación - el que va a popa (+X) debe mirar a la derecha (PI), el de proa a la izquierda (0)
	assert_almost_eq(gob_proa.rotation.y, 0.0, 0.01, "El enemigo que camina a proa (-X) debe mirar hacia la izquierda")
	assert_almost_eq(gob_popa.rotation.y, PI, 0.01, "El enemigo que camina a popa (+X) debe girar y mirar hacia la derecha")

	# Act 2: Esperar a que completen su caminata sobre la cubierta y la pausa de detención
	await get_tree().create_timer(1.5).timeout

	# Assert 3: Ambos deben haber llegado a su destino, detenerse y encarar hacia el jugador (-X / 0.0) para atacar (SHOOTING)
	assert_almost_eq(gob_proa.rotation.y, 0.0, 0.01, "Al llegar, el enemigo de proa debe encarar hacia el jugador (0.0)")
	assert_almost_eq(gob_popa.rotation.y, 0.0, 0.01, "Al llegar, el enemigo de popa debe voltearse hacia el jugador (0.0)")
	assert_eq(gob_proa.current_state, EnemyBase.State.SHOOTING, "El enemigo de proa debe detenerse e iniciar SHOOTING")
	assert_eq(gob_popa.current_state, EnemyBase.State.SHOOTING, "El enemigo de popa debe detenerse e iniciar SHOOTING")


## 13. Al sumergirse, el submarino reproduce el mismo sonido de emerger pero más despacio (pitch menor a 1.0)
func test_sumersion_reproduce_sonido_emerger_mas_despacio() -> void:
	# Arrange: submarino en superficie
	var submarino: SubmarinoRio = SubmarinoScene.instantiate() as SubmarinoRio
	_root_test.add_child(submarino)
	submarino.current_state = SubmarinoRio.State.EN_SUPERFICIE
	submarino.canon_disparo_final = false  ## Sumersión directa sin despedida del cañón

	# Act: iniciar sumersión
	submarino._iniciar_sumersion()

	# Assert: debe generarse SfxSumergiendose con un pitch_scale más lento/grave (< 1.0)
	var sfx := _root_test.find_child("SfxSumergiendose", true, false) as AudioStreamPlayer3D
	assert_not_null(sfx, "Al sumergirse debe sonar SfxSumergiendose")
	assert_lt(sfx.pitch_scale, 1.0, "El sonido de sumersión debe reproducirse a una velocidad/tono más lento (pitch < 1.0)")
	assert_almost_eq(sfx.pitch_scale, submarino.pitch_sonido_sumersion, 0.01, "El pitch debe coincidir con pitch_sonido_sumersion configurado")


func test_puestos_esquivan_vela_y_no_se_enciman() -> void:
	# Arrange: despliegue completo de 6 como en el nivel
	var submarino: SubmarinoRio = SubmarinoScene.instantiate() as SubmarinoRio
	_root_test.add_child(submarino)
	var lo: float = submarino.vela_x_min - submarino.margen_vela
	var hi: float = submarino.vela_x_max + submarino.margen_vela

	# Act: calcular los 6 puestos en orden de despliegue
	var xs: Array = []
	for i in range(6):
		var off: float = submarino._calcular_offset_deck_x(i, 6)
		xs.append(submarino.spawn_point.position.x + off)

	# Assert: ninguno en la vela, todos en cubierta y separados
	for x in xs:
		assert_true(float(x) < lo or float(x) > hi, "Ningún puesto puede quedar tras la vela")
		assert_gte(float(x), -3.55, "Dentro de cubierta por proa")
		assert_lte(float(x), 1.5, "Dentro de cubierta por popa")
	for i in range(xs.size()):
		for j in range(i + 1, xs.size()):
			assert_gte(absf(float(xs[i]) - float(xs[j])), 0.59, "Los puestos no deben encimarse")


func test_emerger_deja_casco_humedo_que_se_seca() -> void:
	# Arrange: submarino sumergido con material estándar en el casco
	var submarino: SubmarinoRio = SubmarinoScene.instantiate() as SubmarinoRio
	submarino.position = Vector3(40.0, 0.0, -7.5)
	submarino.altura_emergido_y = 0.0
	submarino.profundidad_sumergido = 2.0
	submarino.activar_al_entrar_en_camara = false
	_root_test.add_child(submarino)
	var mi: MeshInstance3D = null
	for m in submarino.find_children("*", "MeshInstance3D", true, false):
		var cand := m as MeshInstance3D
		if cand == null:
			continue
		var base: Material = cand.material_override
		if base == null and cand.mesh and cand.mesh.get_surface_count() > 0:
			base = cand.mesh.surface_get_material(0)
		if base is StandardMaterial3D:
			mi = cand
			break
	assert_not_null(mi, "Precondición: casco con material estándar")
	var mat_seco := mi.material_override as StandardMaterial3D
	if mat_seco == null and mi.mesh and mi.mesh.get_surface_count() > 0:
		mat_seco = mi.mesh.surface_get_material(0) as StandardMaterial3D
	assert_not_null(mat_seco, "Precondición: material seco legible")
	var rugosa_seco: float = mat_seco.roughness
	var albedo_seco: Color = mat_seco.albedo_color

	# Act: emerger mojado
	submarino.emerger()

	# Assert: oscuro y brillante
	assert_false(submarino._mats_humedos.is_empty(), "Debe duplicar materiales del casco")
	var mojado := mi.material_override as StandardMaterial3D
	assert_not_null(mojado, "Debe asignar duplicado mojado")
	assert_almost_eq(mojado.roughness, 0.12, 0.001, "Mojado es brillante (roughness 0.12)")
	assert_lt(mojado.albedo_color.v, albedo_seco.v, "Mojado es más oscuro")

	# Act: secado completo
	submarino._aplicar_secado(1.0)

	# Assert: vuelve a lo seco
	assert_almost_eq(mojado.roughness, rugosa_seco, 0.001, "Seco recupera roughness original")
	assert_eq(mojado.albedo_color, albedo_seco, "Seco recupera albedo original")


func test_emerger_genera_onda_del_splash_nuevo() -> void:
	# Arrange: sumergido con onda activada
	var submarino: SubmarinoRio = SubmarinoScene.instantiate() as SubmarinoRio
	submarino.position = Vector3(40.0, 0.0, -7.5)
	submarino.altura_emergido_y = 0.0
	submarino.profundidad_sumergido = 2.0
	submarino.velocidad_emerger = 50.0
	submarino.activar_al_entrar_en_camara = false
	_root_test.add_child(submarino)

	# Act: emerger hasta superficie
	submarino.emerger()
	submarino._process(0.3)

	# Assert: anillo de onda del efecto nuevo (solo capa 1)
	assert_eq(submarino.current_state, SubmarinoRio.State.EN_SUPERFICIE, "Debe estar en superficie")
	var onda: Node = null
	for n in _root_test.get_children():
		if is_instance_valid(n) and n.has_method("play_splash"):
			onda = n
			break
	assert_not_null(onda, "Al emerger debe generar la onda")
	var capas: Array = onda.get("vfx_layers")
	if capas.size() >= 6:
		assert_true((capas[1] as Node3D).visible, "Anillo visible")
		assert_false((capas[4] as Node3D).visible, "Pilar oculto en la onda")


func test_canoa_frena_antes_del_casco_con_margen() -> void:
	# Arrange: canoa y submarino en superficie separados 7.4m (contacto con margen 5+2.4)
	var canoa: CanoaProtagonistaRio = CanoaScene.instantiate() as CanoaProtagonistaRio
	_root_test.add_child(canoa)
	canoa.global_position = Vector3(0.0, 0.0, -7.5)
	var submarino: SubmarinoRio = SubmarinoScene.instantiate() as SubmarinoRio
	_root_test.add_child(submarino)
	submarino.global_position = Vector3(7.4, 0.0, -7.5)
	submarino.current_state = SubmarinoRio.State.EN_SUPERFICIE
	submarino.add_to_group("enemies")
	submarino.add_to_group("enemigos")

	# Act: la canoa evalúa al submarino
	canoa._actualizar_reaccion_enemigos()

	# Assert: detenida por el casco completo, no por su centro
	assert_true(canoa.esta_detenida_por_enemigo(), "Debe detenerse antes de tocar el casco")
	assert_eq(canoa.obtener_factor_velocidad_actual(), 0.0, "Velocidad 0 ante el casco")

	# Act: forzar la base más allá y aplicar el freno absoluto
	canoa._posicion_base.x = 9.0
	canoa._aplicar_freno_contacto_enemigos()

	# Assert: la proa queda fuera del casco (7.4m del centro)
	assert_almost_eq(canoa._posicion_base.x, 0.0, 0.01, "El freno la devuelve fuera del casco")


func test_submarino_emerge_centrado_no_al_borde() -> void:
	# Arrange: cámara en x=0 y submarino sumergido al borde (dx=6)
	var cam := Camera3D.new()
	get_tree().root.add_child(cam)
	cam.global_position = Vector3.ZERO
	cam.make_current()
	var submarino: SubmarinoRio = SubmarinoScene.instantiate() as SubmarinoRio
	_root_test.add_child(submarino)
	submarino.global_position = Vector3(6.0, -2.0, -7.5)
	submarino.current_state = SubmarinoRio.State.SUMERGIDO
	submarino.activar_al_entrar_en_camara = true

	# Act: con la cámara lejos del centro no emerge
	submarino._process(0.1)

	# Assert: sigue sumergido al borde del cuadro
	assert_eq(submarino.current_state, SubmarinoRio.State.SUMERGIDO, "Al borde no debe emerger aún")

	# Act: cámara ya centrada (dx=2)
	submarino.global_position.x = 2.0
	submarino._process(0.1)

	# Assert: ahora sí emerge para apreciarse completo
	assert_eq(submarino.current_state, SubmarinoRio.State.EMERGIENDO, "Centrada la cámara debe emerger")

	# Cleanup
	cam.queue_free()


func test_sumersion_genera_misma_onda_que_emerger() -> void:
	# Arrange: en superficie
	var submarino: SubmarinoRio = SubmarinoScene.instantiate() as SubmarinoRio
	submarino.position = Vector3(40.0, 0.0, -7.5)
	submarino.altura_emergido_y = 0.0
	submarino.profundidad_sumergido = 2.0
	submarino.activar_al_entrar_en_camara = false
	_root_test.add_child(submarino)
	submarino.current_state = SubmarinoRio.State.EN_SUPERFICIE
	submarino.canon_disparo_final = false  ## Sumersión directa sin despedida del cañón

	# Act: inicia sumersión
	submarino._iniciar_sumersion()

	# Assert: misma onda que al emerger
	assert_eq(submarino.current_state, SubmarinoRio.State.SUMERGIENDOSE, "Debe estar sumergiéndose")
	var onda: Node = null
	for n in _root_test.get_children():
		if is_instance_valid(n) and n.has_method("play_splash"):
			onda = n
			break
	assert_not_null(onda, "Al sumergirse debe generar la misma onda")


func test_emerger_gotea_cubierta_hasta_secarse() -> void:
	# Arrange: sumergido con goteo activado
	var submarino: SubmarinoRio = SubmarinoScene.instantiate() as SubmarinoRio
	submarino.position = Vector3(40.0, 0.0, -7.5)
	submarino.altura_emergido_y = 0.0
	submarino.profundidad_sumergido = 2.0
	submarino.activar_al_entrar_en_camara = false
	_root_test.add_child(submarino)
	assert_not_null(submarino._goteo_cubierta, "Debe crear el emisor de goteo")
	assert_false(submarino._goteo_cubierta.emitting, "Apagado antes de emerger")

	# Act: emerger
	submarino.emerger()

	# Assert: goteando mientras está mojado
	assert_true(submarino._goteo_cubierta.emitting, "Al emerger la cubierta gotea")
	assert_gt(submarino._goteo_cubierta.amount, 0, "Con gotas configuradas")

	# Act: secado completo
	submarino._aplicar_secado(1.0)

	# Assert: deja de gotear al secarse
	assert_false(submarino._goteo_cubierta.emitting, "Al secarse deja de gotear")



