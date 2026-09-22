extends "res://addons/gut/test.gd"

## Tests unitarios para la defensora especial Perrena, su proyectil Hacha Perrena
## y su ítem de refuerzo de invocación.

var DefensoraScene: PackedScene = preload("res://Entities/Defensora_Perrena/DefensoraPerrena.tscn")
var HachaScene: PackedScene = preload("res://Entities/Proyectil_Hacha_Perrena/HachaPerrena.tscn")
var IconoRefuerzoScene: PackedScene = preload("res://Entities/Item_Refuerzo_Perrena/IconoRefuerzoPerrena.tscn")

var _root_test: Node3D = null


func before_each() -> void:
	_root_test = Node3D.new()
	_root_test.name = "RootTestPerrena"
	get_tree().root.add_child(_root_test)
	get_tree().current_scene = _root_test


func after_each() -> void:
	if is_instance_valid(_root_test):
		_root_test.free()
	for n in get_tree().root.get_children():
		if n is DefensoraPerrena or n is HachaPerrenaProjectile or n is IconoRefuerzoPerrena:
			n.free()


func test_defensora_perrena_vida_inicial_es_3() -> void:
	# Arrange & Act
	var defensora: DefensoraPerrena = DefensoraScene.instantiate() as DefensoraPerrena
	_root_test.add_child(defensora)

	# Assert: Vida requerida de 3 HP
	assert_eq(defensora.vida_maxima, 3, "La vida máxima de Perrena debe ser 3")
	assert_eq(defensora.health, 3, "La vida inicial de Perrena debe ser 3")
	assert_false(defensora.es_inmune, "No debe iniciar siendo inmune")
	assert_not_null(defensora.hitbox_body, "Debe poseer HitboxBody para colisión de defensoras")
	assert_eq(defensora.hitbox_body.collision_layer, 2, "La hitbox de defensora debe estar en capa 2")
	if defensora.anim_player and defensora.anim_player.has_animation("Correr"):
		var a = defensora.anim_player.get_animation("Correr")
		assert_eq(a.loop_mode, Animation.LOOP_LINEAR, "La animación 'Correr' debe estar en LOOP_LINEAR para reproducirse continuamente")



func test_hacha_perrena_dano_base_y_bono_estructuras() -> void:
	# Arrange
	var hacha: HachaPerrenaProjectile = HachaScene.instantiate() as HachaPerrenaProjectile
	_root_test.add_child(hacha)

	# Assert constantes
	assert_eq(HachaPerrenaProjectile.DANO_BASE, 2.0, "El daño base del hacha de Perrena debe ser 2")
	assert_eq(HachaPerrenaProjectile.BONO_ESCUDOS_Y_PILAR, 3.0, "El bono contra escudos y pilar de Lonko debe ser +3")

	# Dummy enemigo básico
	var enemigo_normal := Node3D.new()
	enemigo_normal.name = "GoblinNormal"
	enemigo_normal.add_to_group("enemies")
	enemigo_normal.set_script(load("res://addons/gut/test.gd"))  # Script genérico para set/has_method
	var dano_recibido_normal: Array[float] = [0.0]
	enemigo_normal.set_meta("take_damage_callback", func(d: float): dano_recibido_normal[0] = d)
	# Agregar método fake via script o clase dummy
	_root_test.add_child(enemigo_normal)

	# Dummy escudo enemigo del escenario
	var escudo := StaticBody3D.new()
	escudo.name = "EscudoEnemigo"
	escudo.set_meta("es_escudo_enemigo", true)
	escudo.add_to_group("escudos")
	_root_test.add_child(escudo)

	# Dummy pilar lonko
	var pilar := StaticBody3D.new()
	pilar.name = "PilarLonko"
	pilar.set_meta("es_pilar_enemigo", true)
	_root_test.add_child(pilar)

	var hacha_dummy: HachaPerrenaProjectile = HachaScene.instantiate() as HachaPerrenaProjectile
	_root_test.add_child(hacha_dummy)

	# Act & Assert cálculo de daño
	# Escudo: 2 base + 3 bono = 5
	var dano_calculado_escudo: float = hacha_dummy.calcular_dano_para(escudo)
	assert_eq(dano_calculado_escudo, 5.0, "El daño contra escudos del escenario debe ser 5 (2 + 3)")

	# Pilar: 2 base + 3 bono = 5
	var dano_calculado_pilar: float = hacha_dummy.calcular_dano_para(pilar)
	assert_eq(dano_calculado_pilar, 5.0, "El daño contra el pilar de Lonko debe ser 5 (2 + 3)")


func test_hacha_perrena_fisica_parabolica_y_rotacion() -> void:
	# Arrange
	var hacha: HachaPerrenaProjectile = HachaScene.instantiate() as HachaPerrenaProjectile
	_root_test.add_child(hacha)
	hacha.global_position = Vector3(0, 5, 0)
	hacha.initialize(Vector3(1, 1, 0), 1.0, null)

	var y_inicial: float = hacha.global_position.y
	var vy_inicial: float = hacha.velocity.y

	# Act: Simular un paso de física
	hacha._physics_process(0.1)

	# Assert: Gravedad afecta la velocidad en Y
	assert_lt(hacha.velocity.y, vy_inicial, "La gravedad debe reducir la velocidad vertical")
	assert_gt(hacha.global_position.x, 0.0, "Debe desplazarse en X hacia la derecha")


func test_defensora_perrena_prioridades_apuntado() -> void:
	# Arrange
	var defensora: DefensoraPerrena = DefensoraScene.instantiate() as DefensoraPerrena
	_root_test.add_child(defensora)
	defensora.global_position = Vector3(0, 0, 0)

	# Enemigo Básico (Prioridad 0) en X=4
	var basico := Node3D.new()
	basico.name = "GoblinArquero"
	basico.add_to_group("enemies")
	_root_test.add_child(basico)
	basico.global_position = Vector3(4, 0, 0)

	# Enemigo Élite (Prioridad 1) en X=8
	var elite := Node3D.new()
	elite.name = "LonkoArquera"
	elite.add_to_group("enemies")
	elite.set("es_elite", true)
	_root_test.add_child(elite)
	elite.global_position = Vector3(8, 0, 0)

	# Escudo de escenario (Prioridad 2) en X=12
	var escudo := StaticBody3D.new()
	escudo.name = "EscudoEscenario"
	escudo.set_meta("es_escudo_enemigo", true)
	escudo.add_to_group("escudos")
	_root_test.add_child(escudo)
	escudo.global_position = Vector3(12, 0, 0)

	# Act 1: Con Escudo presente, debe seleccionar Prioridad 2 (escudo) pese a estar más lejos
	var obj1: Node = defensora._buscar_mejor_objetivo()
	assert_eq(obj1, escudo, "Perrena debe priorizar el escudo del escenario (Prioridad 2)")

	# Act 2: Al destruir el escudo, debe seleccionar a la Élite (Prioridad 1)
	escudo.queue_free()
	await get_tree().process_frame
	var obj2: Node = defensora._buscar_mejor_objetivo()
	assert_eq(obj2, elite, "Perrena debe priorizar el enemigo élite (Prioridad 1) sobre el básico")

	# Act 3: Al eliminar la élite, debe seleccionar el enemigo básico (Prioridad 0)
	elite.queue_free()
	await get_tree().process_frame
	var obj3: Node = defensora._buscar_mejor_objetivo()
	assert_eq(obj3, basico, "Perrena debe atacar al básico (Prioridad 0) cuando no hay prioridades mayores")


func test_defensora_perrena_habilidad_especial_cada_7_ataques() -> void:
	# Arrange
	var defensora: DefensoraPerrena = DefensoraScene.instantiate() as DefensoraPerrena
	_root_test.add_child(defensora)

	# Dummy enemigo para apuntar
	var dummy_enemy := Node3D.new()
	dummy_enemy.name = "ImpObjetivo"
	dummy_enemy.add_to_group("enemies")
	_root_test.add_child(dummy_enemy)
	dummy_enemy.global_position = Vector3(5, 0, 0)

	# Act 1: Simular 6 ataques normales lanzados (sin requerir impactos)
	for i in range(6):
		defensora._iniciar_ataque_normal()
		defensora._tiempo_en_estado = 0.35
		defensora._proceso_atacando(0.01)
		defensora._tiempo_en_estado = 0.75
		defensora._proceso_atacando(0.01)

	# Assert 1: Con 6 ataques completados, contador_ataques es 6
	assert_eq(defensora.contador_ataques, 6, "Debe haber lanzado 6 ataques")
	assert_eq(defensora.current_state, DefensoraPerrena.State.IDLE, "Debe estar en IDLE tras el 6to ataque")

	# Act 2: El 7mo ataque activa la habilidad especial / ulti
	defensora._intentar_iniciar_ataque()

	# Assert 2: Activa la habilidad especial (CELEBRATING) e inmunidad
	assert_eq(defensora.current_state, DefensoraPerrena.State.CELEBRATING, "El 7mo ataque debe activar el estado CELEBRATING")
	assert_true(defensora.es_inmune, "Durante la celebración, Perrena debe ser inmune")
	assert_true(defensora.aura_vfx.visible, "El aura protectora debe estar visible durante la celebración")

	# Assert 3: Daño recibido durante la habilidad es ignorado por la inmunidad
	var vida_previa: int = defensora.health
	defensora.take_damage(2.0)
	assert_eq(defensora.health, vida_previa, "Perrena no debe recibir daño mientras es inmune")

	# Act 3: Completar celebración y arrojar el hacha gigante
	defensora._tiempo_en_estado = 2.0
	defensora._proceso_celebrando(0.1)

	# Assert 4: Pierde inmunidad, oculta aura, reinicia contador_ataques a 0 y vuelve a IDLE
	assert_false(defensora.es_inmune, "Debe perder la inmunidad al finalizar la celebración")
	assert_false(defensora.aura_vfx.visible, "El aura debe ocultarse al finalizar la celebración")
	assert_eq(defensora.contador_ataques, 0, "El contador de ataques debe reiniciarse a 0 tras la ulti")
	assert_eq(defensora.current_state, DefensoraPerrena.State.IDLE, "Debe retornar a IDLE")

	# Assert 5: Se instanció exactamente 1 hacha gigante especial
	var hacha_especial: HachaPerrenaProjectile = null
	for n in _root_test.get_children():
		if n is HachaPerrenaProjectile and (n as HachaPerrenaProjectile).es_hacha_especial:
			hacha_especial = n as HachaPerrenaProjectile
			break
	assert_not_null(hacha_especial, "Debe instanciar el hacha gigante especial")
	if hacha_especial:
		assert_true(hacha_especial.es_hacha_especial, "El hacha lanzada debe ser especial")
		assert_gte(hacha_especial.scale.x, 1.8, "El hacha especial debe ser de mayor tamaño (escala >= 1.8)")


func test_defensora_perrena_especial_prioridad_1_cualquier_enemigo() -> void:
	# Arrange
	var defensora: DefensoraPerrena = DefensoraScene.instantiate() as DefensoraPerrena
	_root_test.add_child(defensora)
	defensora.global_position = Vector3(0, 0, 0)

	# Escudo enemigo del escenario (X=5)
	var escudo := StaticBody3D.new()
	escudo.name = "EscudoEscenario"
	escudo.set_meta("es_escudo_enemigo", true)
	escudo.add_to_group("escudos")
	_root_test.add_child(escudo)
	escudo.global_position = Vector3(5, 0, 0)

	# Enemigo Básico (X=8, más lejos que el escudo)
	var basico := Node3D.new()
	basico.name = "GoblinComun"
	basico.add_to_group("enemies")
	_root_test.add_child(basico)
	basico.global_position = Vector3(8, 0, 0)

	# Act 1: Ataque normal prefiere el escudo (Prioridad 2 > Prioridad 0)
	var obj_normal: Node = defensora._buscar_mejor_objetivo(false)
	assert_eq(obj_normal, escudo, "El ataque normal prioriza el escudo sobre el enemigo común")

	# Act 2: Ataque especial tiene Prioridad 1 contra CUALQUIER tipo de enemigo
	var obj_especial: Node = defensora._buscar_mejor_objetivo(true)
	assert_eq(obj_especial, basico, "El ataque especial debe tener Prioridad 1 contra cualquier enemigo sobre el escudo")


func test_hacha_perrena_especial_dano_y_efecto_flecha_explosiva() -> void:
	# Arrange
	var hacha_esp: HachaPerrenaProjectile = HachaScene.instantiate() as HachaPerrenaProjectile
	_root_test.add_child(hacha_esp)
	hacha_esp.initialize(Vector3.RIGHT, 1.0, null, true, null)

	# Assert escala mayor y daño
	assert_true(hacha_esp.es_hacha_especial, "Debe ser hacha especial")
	assert_almost_eq(hacha_esp.scale.x, 2.0, 0.05, "El hacha especial debe medir 2.0x de escala")

	var enemy_script := GDScript.new()
	enemy_script.source_code = "extends Node3D\nvar murio_por_explosion: bool = false\nfunc take_damage(_d: float) -> void: pass\n"
	enemy_script.reload()

	var dummy_enemy := Node3D.new()
	dummy_enemy.set_script(enemy_script)
	dummy_enemy.name = "EnemigoTest"
	dummy_enemy.add_to_group("enemies")
	_root_test.add_child(dummy_enemy)

	var escudo := StaticBody3D.new()
	escudo.name = "EscudoTest"
	escudo.set_meta("es_escudo_enemigo", true)
	escudo.add_to_group("escudos")
	_root_test.add_child(escudo)

	# Assert cálculo de daño: 3 base (enemigo), 9 estructuras (3 + 6)
	assert_eq(hacha_esp.calcular_dano_para(dummy_enemy), 3.0, "Daño a enemigo común debe ser 3.0 (como flecha explosiva)")
	assert_eq(hacha_esp.calcular_dano_para(escudo), 9.0, "Daño a escudo debe ser 9.0 (3 base + 6 bono estructuras)")

	# Act: Simular impacto
	hacha_esp._procesar_impacto(dummy_enemy, Vector3.ZERO, Vector3.UP)

	# Assert: murio_por_explosion = true para efecto de física especial sin explosión visual
	assert_true(dummy_enemy.get("murio_por_explosion"), "Debe marcar murio_por_explosion para el efecto cinético de la flecha explosiva")


func test_icono_refuerzo_perrena_invoca_y_cura_jugadora() -> void:
	# Arrange: Jugadora con 1 HP usando script dinámico para tipado
	var p_script := GDScript.new()
	p_script.source_code = "extends CharacterBody3D\nvar vida_maxima: int = 4\nvar health: int = 1\nfunc curar(cant: int) -> void: health = mini(vida_maxima, health + cant)\n"
	p_script.reload()

	var player := CharacterBody3D.new()
	player.set_script(p_script)
	player.name = "Player"
	player.add_to_group("player")
	_root_test.add_child(player)
	player.global_position = Vector3(0, 0, 0)

	var icono: IconoRefuerzoPerrena = IconoRefuerzoScene.instantiate() as IconoRefuerzoPerrena
	_root_test.add_child(icono)
	icono.global_position = Vector3(2, 0, 0)
	icono._armado = true

	var senal_recibida: Array[bool] = [false]
	icono.activada.connect(func(): senal_recibida[0] = true)

	# Act: Jugadora entra en contacto con el ítem
	icono._on_body_entered(player)

	# Assert 1: Emite señal
	assert_true(senal_recibida[0], "El ítem de refuerzo debe emitir la señal 'activada'")

	# Assert 2: Jugadora recupera vida completa (4 corazones)
	assert_eq(player.get("health"), 4, "El ítem de refuerzo debe llenar la vida de la jugadora")

	# Assert 3: Defensora Perrena fue instanciada en la escena con escala 0.3 (modelo jugable)
	var perrena_instanciada := _root_test.find_child("DefensoraPerrena", true, false)
	if not perrena_instanciada:
		perrena_instanciada = get_tree().root.find_child("DefensoraPerrena", true, false)
	assert_not_null(perrena_instanciada, "El ítem de refuerzo debe instanciar a DefensoraPerrena en la escena")
	assert_almost_eq(perrena_instanciada.scale.x, 0.3, 0.02, "Defensora Perrena debe tener escala 0.3 (mismo tamaño que el modelo jugable)")


func test_solo_un_icono_refuerzo_perrena_al_mismo_tiempo() -> void:
	# Arrange: Instanciar primer icono
	var icono1: IconoRefuerzoPerrena = IconoRefuerzoScene.instantiate() as IconoRefuerzoPerrena
	_root_test.add_child(icono1)

	# Act: Instanciar segundo icono
	var icono2: IconoRefuerzoPerrena = IconoRefuerzoScene.instantiate() as IconoRefuerzoPerrena
	_root_test.add_child(icono2)

	# Assert: El primer icono debe haber sido liberado (queue_free) para asegurar que solo exista 1
	assert_true(icono1.is_queued_for_deletion(), "El primer icono debe marcarse para eliminación al aparecer uno nuevo")
	assert_false(icono2.is_queued_for_deletion(), "El segundo icono debe permanecer activo")


func test_defensora_perrena_despliegue_escaleras_y_posicion_escudo() -> void:
	# Arrange
	var defensora: DefensoraPerrena = DefensoraScene.instantiate() as DefensoraPerrena
	_root_test.add_child(defensora)

	# Assert escala de modelo jugable
	assert_almost_eq(defensora.scale.x, 0.3, 0.01, "La defensora debe tener escala 0.3")

	# Act: Iniciar despliegue
	defensora.desplegar_hacia_ultimo_piso(-11.5)
	assert_eq(defensora.current_state, DefensoraPerrena.State.DEPLOYING, "Debe estar en estado DEPLOYING durante la subida")
	assert_true(defensora.en_despliegue, "en_despliegue debe ser true")


func test_defensora_perrena_orientacion_frente_adelante() -> void:
	# Arrange
	var defensora: DefensoraPerrena = DefensoraScene.instantiate() as DefensoraPerrena
	_root_test.add_child(defensora)
	var skel = defensora.find_child("Skeleton3D", true, false) as Skeleton3D
	assert_not_null(skel, "Debe poseer Skeleton3D")

	var toe_idx: int = skel.find_bone("mixamorig_RightToeBase")
	var foot_idx: int = skel.find_bone("mixamorig_RightFoot")
	assert_ne(toe_idx, -1, "Debe tener hueso mixamorig_RightToeBase")
	assert_ne(foot_idx, -1, "Debe tener hueso mixamorig_RightFoot")

	var toe_rest = skel.get_bone_global_rest(toe_idx)
	var foot_rest = skel.get_bone_global_rest(foot_idx)

	# Act 1: Orientar hacia la derecha (+X)
	defensora._orientar_modelo_derecha()
	var toe_pos_right: Vector3 = skel.global_transform * toe_rest.origin
	var foot_pos_right: Vector3 = skel.global_transform * foot_rest.origin
	# Assert 1: La punta del pie debe estar más a la derecha (+X) que el tobillo (mira al frente)
	assert_gt(toe_pos_right.x, foot_pos_right.x, "Al orientar a la derecha, la punta del pie debe apuntar hacia +X (frente)")

	# Act 2: Orientar hacia la izquierda (-X)
	defensora._orientar_modelo_izquierda()
	var toe_pos_left: Vector3 = skel.global_transform * toe_rest.origin
	var foot_pos_left: Vector3 = skel.global_transform * foot_rest.origin
	# Assert 2: La punta del pie debe estar más a la izquierda (-X) que el tobillo
	assert_lt(toe_pos_left.x, foot_pos_left.x, "Al orientar a la izquierda, la punta del pie debe apuntar hacia -X")

	# Act 3: Orientar hacia la escalera / pared (-Z) y subir dando la espalda
	defensora._orientar_modelo_escalera()
	if defensora.anim_player and defensora.anim_player.has_animation("Escaleras"):
		defensora.anim_player.play("Escaleras")
		defensora.anim_player.advance(0.2)
		var toe_pose: Transform3D = skel.get_bone_global_pose(toe_idx)
		var foot_pose: Transform3D = skel.get_bone_global_pose(foot_idx)
		var toe_anim: Vector3 = skel.global_transform * toe_pose.origin
		var foot_anim: Vector3 = skel.global_transform * foot_pose.origin
		# La punta del pie apunta hacia la pared (-Z) y el talón/espalda hacia la cámara (+Z)
		assert_lt(toe_anim.z, foot_anim.z, "Al subir escaleras, Perrena debe dar la espalda a la cámara con la punta del pie hacia -Z")


func test_defensora_perrena_particulas_humo_pisadas_al_correr() -> void:
	# Arrange
	var defensora: DefensoraPerrena = DefensoraScene.instantiate() as DefensoraPerrena
	_root_test.add_child(defensora)

	# Assert existencia de partículas de pisadas y textura
	assert_not_null(defensora._particulas_pisada, "Debe instanciar _particulas_pisada")
	assert_false(defensora._particulas_pisada.emitting, "No debe emitir en IDLE")

	# Act: Simular desplazamiento en carrera durante despliegue
	defensora.en_despliegue = true
	defensora._play_anim("Correr")
	defensora.global_position.x += 0.5
	defensora._physics_process(0.016)

	# Assert: emite partículas al correr
	assert_true(defensora._particulas_pisada.emitting, "Debe emitir partículas de humo al correr durante el despliegue")

	# Act: Simular que trepa escalera
	defensora._play_anim("Escaleras")
	defensora._physics_process(0.016)

	# Assert: no emite en escalera
	assert_false(defensora._particulas_pisada.emitting, "No debe emitir humo de pisadas en escaleras")


func test_perrena_modo_canoa_usa_idle_sentada() -> void:
	# Arrange: defensora en reposo fuera de canoa
	var defensora: DefensoraPerrena = DefensoraScene.instantiate() as DefensoraPerrena
	_root_test.add_child(defensora)
	assert_false(defensora.en_canoa, "Sin canoa no debe estar en modo canoa")
	assert_eq(defensora._anim_reposo_nombres()[0], "Idle", "Fuera de canoa el reposo es Idle de pie")

	# Act: subir a la canoa del nivel del río
	defensora.fijar_modo_canoa(true)

	# Assert: reposo sentado y animación cambiada en el acto (está en IDLE)
	assert_true(defensora.en_canoa, "Debe activar el modo canoa")
	assert_true(defensora.restringir_ataque_a_camara, "En canoa solo ataca lo visible en cámara")
	assert_eq(defensora._anim_reposo_nombres()[0], defensora.anim_idle_canoa, "En canoa el reposo es el idle sentado")
	if defensora.anim_player and defensora.anim_player.has_animation(defensora.anim_idle_canoa):
		assert_true(defensora.anim_idle_canoa.to_lower() in defensora.anim_player.current_animation.to_lower(), "Debe estar reproduciendo el idle de canoa")

	# Act: bajar de la canoa vuelve al Idle de pie
	defensora.fijar_modo_canoa(false)
	assert_false(defensora.en_canoa, "Debe desactivar el modo canoa")
	assert_false(defensora.restringir_ataque_a_camara, "Fuera de canoa ataca sin restricción de cámara")
	assert_eq(defensora._anim_reposo_nombres()[0], "Idle", "Fuera de canoa vuelve al Idle de pie")


func test_perrena_sonido_ataque_cada_3_ataques() -> void:
	# Arrange
	var defensora: DefensoraPerrena = DefensoraScene.instantiate() as DefensoraPerrena
	_root_test.add_child(defensora)
	defensora.cada_cuantos_ataques_sonido = 3
	var dummy_enemy := Node3D.new()
	dummy_enemy.name = "ImpObjetivo"
	dummy_enemy.add_to_group("enemies")
	_root_test.add_child(dummy_enemy)
	dummy_enemy.global_position = Vector3(5, 0, 0)

	# Act 1-2: dos ataques normales sin grito
	for i in range(2):
		defensora._iniciar_ataque_normal()
		defensora._tiempo_en_estado = 0.35
		defensora._proceso_atacando(0.01)
		defensora._tiempo_en_estado = 0.75
		defensora._proceso_atacando(0.01)
	assert_eq(defensora.contador_ataques, 2, "Debe haber lanzado 2 ataques")
	assert_null(defensora.find_child("SfxAtaquePerrena", false, false), "Sin grito de ataque antes del 3er hachazo")

	# Act 3: tercer ataque con grito
	defensora._iniciar_ataque_normal()
	defensora._tiempo_en_estado = 0.35
	defensora._proceso_atacando(0.01)
	defensora._tiempo_en_estado = 0.75
	defensora._proceso_atacando(0.01)

	# Assert: contador en 3 y reproductor del grito instanciado
	assert_eq(defensora.contador_ataques, 3, "Debe haber lanzado 3 ataques")
	assert_not_null(defensora.find_child("SfxAtaquePerrena", false, false), "Cada 3 ataques debe sonar el grito de ataque")


func test_canoa_del_rio_fuerza_idle_canoa_en_perrena() -> void:
	# Arrange: canoa del río con su DefensoraPerrena a bordo (como en la escena del nivel)
	var CanoaScript = load("res://Levels/Rio_En_Canoa_Con_Parallax/CanoaProtagonistaRio.gd")
	var canoa: Node3D = CanoaScript.new()
	canoa.name = "CanoaProtagonistaRio"
	var defensora: DefensoraPerrena = DefensoraScene.instantiate() as DefensoraPerrena
	defensora.name = "DefensoraPerrena"
	canoa.add_child(defensora)

	# Act: entrar al árbol (readys: primero la defensora, luego la canoa que refuerza)
	_root_test.add_child(canoa)

	# Assert: Idle Canoa como reposo, por autodetección y por refuerzo de la canoa
	assert_true(defensora.en_canoa, "A bordo de la canoa debe estar en modo canoa")
	assert_eq(defensora._anim_reposo_nombres()[0], defensora.anim_idle_canoa, "En el nivel río el reposo debe ser Idle Canoa")


func test_defensora_perrena_fase_suelo_y_requisito_6_impactos() -> void:
	# Arrange
	var defensora: DefensoraPerrena = DefensoraScene.instantiate() as DefensoraPerrena
	_root_test.add_child(defensora)
	defensora.en_fase_escudo_suelo = true
	defensora.impactos_fase_suelo = 0

	var conteos: Array[int] = []
	defensora.impacto_registrado.connect(func(c: int): conteos.append(c))

	var ascenso_llamado: Array[bool] = [false]
	defensora.fase_ascenso_iniciada.connect(func(): ascenso_llamado[0] = true)

	# Dummy enemigo
	var enemy := Node3D.new()
	enemy.add_to_group("enemies")
	_root_test.add_child(enemy)

	# Dummy escudo enemigo
	var escudo := StaticBody3D.new()
	escudo.add_to_group("escudos")
	escudo.set_meta("es_escudo_enemigo", true)
	_root_test.add_child(escudo)

	# Dummy pilar enemigo
	var pilar := StaticBody3D.new()
	pilar.set_meta("es_pilar_enemigo", true)
	_root_test.add_child(pilar)

	# Act & Assert: Simular impactos del 1 al 5
	defensora._on_hacha_impacto(enemy)
	assert_eq(defensora.impactos_fase_suelo, 1, "Debe registrar 1 impacto tras golpear enemigo")
	assert_false(ascenso_llamado[0], "No debe subir con 1 impacto")

	defensora._on_hacha_impacto(escudo)
	assert_eq(defensora.impactos_fase_suelo, 2, "Debe registrar 2 impactos tras golpear escudo")
	assert_false(ascenso_llamado[0], "No debe subir con 2 impactos")

	defensora._on_hacha_impacto(pilar)
	assert_eq(defensora.impactos_fase_suelo, 3, "Debe registrar 3 impactos tras golpear pilar")
	assert_false(ascenso_llamado[0], "No debe subir con 3 impactos")

	defensora._on_hacha_impacto(enemy)
	defensora._on_hacha_impacto(enemy)
	assert_eq(defensora.impactos_fase_suelo, 5, "Debe tener 5 impactos acumulados")
	assert_false(ascenso_llamado[0], "No debe subir con 5 impactos")

	# 6to impacto: Cumple la condición requerida
	defensora._on_hacha_impacto(enemy)
	assert_eq(defensora.impactos_fase_suelo, 6, "Debe alcanzar los 6 impactos requeridos")
	assert_true(defensora._iniciando_ascenso, "Debe haber activado _iniciando_ascenso")


func test_hacha_perrena_ignora_plataformas_aliadas() -> void:
	# Arrange (gracia de lanzamiento: distancia 0 < 1.5m, atraviesa cobertura propia)
	var hacha: HachaPerrenaProjectile = HachaScene.instantiate() as HachaPerrenaProjectile
	_root_test.add_child(hacha)

	var plataforma := StaticBody3D.new()
	plataforma.name = "PlataformaOneway"
	_root_test.add_child(plataforma)

	var muro := StaticBody3D.new()
	muro.name = "Muro_Plataforma"
	_root_test.add_child(muro)

	# Assert
	assert_true(hacha._es_plataforma_aliada(plataforma), "Debe reconocer PlataformaOneway como plataforma aliada")
	assert_true(hacha._es_plataforma_aliada(muro), "Debe reconocer Muro_Plataforma como plataforma aliada")

	# Act: Simular impacto con plataforma
	hacha._procesar_impacto(plataforma, Vector3.ZERO, Vector3.UP)
	# Assert: No debe procesar impacto ni detenerse en la plataforma aliada
	assert_false(hacha._impacto_procesado, "El hacha no debe procesar impacto al chocar con plataformas aliadas")
	assert_false(hacha.is_stuck, "El hacha no debe clavarse en plataformas aliadas")


func test_hacha_perrena_se_clava_en_plataforma_lejana() -> void:
	# Arrange: hacha que ya voló más allá de la gracia (5m > 1.5m)
	var hacha: HachaPerrenaProjectile = HachaScene.instantiate() as HachaPerrenaProjectile
	_root_test.add_child(hacha)
	hacha._distancia_recorrida = 5.0

	var plataforma := StaticBody3D.new()
	plataforma.name = "PlataformaOneway"
	_root_test.add_child(plataforma)

	# Act: Impactar plataforma lejana
	hacha._procesar_impacto(plataforma, Vector3.ZERO, Vector3.UP)

	# Assert: se clava como en cualquier superficie con colisión (igual que las flechas)
	assert_true(hacha._impacto_procesado, "Fuera de la gracia debe procesar impacto en plataformas")
	assert_true(hacha.is_stuck, "Fuera de la gracia debe clavarse en la plataforma")
	assert_eq(hacha.velocity, Vector3.ZERO, "Su velocidad debe ser cero tras impactar")

	# Act: dejar correr los deferreds de emparentado a geometría estática
	await get_tree().process_frame
	await get_tree().process_frame

	# Assert: queda emparentada al cuerpo estático
	assert_eq(hacha.get_parent(), plataforma, "Clavada en geometría estática debe emparentarse a ella")


func test_hacha_perrena_no_se_emparenta_a_enemigos() -> void:
	# Arrange: impacto a enemigo (los cadáveres se liberan y se llevarían el hacha)
	var hacha: HachaPerrenaProjectile = HachaScene.instantiate() as HachaPerrenaProjectile
	_root_test.add_child(hacha)

	var enemy := Node3D.new()
	enemy.name = "GoblinTest"
	enemy.add_to_group("enemies")
	_root_test.add_child(enemy)

	# Act: Impactar enemigo
	hacha._procesar_impacto(enemy, Vector3.ZERO, Vector3.UP)
	assert_true(hacha.is_stuck, "Debe clavarse al impactar al enemigo")

	# Act: dejar correr los deferreds
	await get_tree().process_frame
	await get_tree().process_frame

	# Assert: NO emparentada al enemigo (queda fija en el mundo hasta desvanecerse)
	assert_eq(hacha.get_parent(), _root_test, "No debe emparentarse al enemigo para no desaparecer con el cadáver")


func test_hacha_desvanece_por_alfa_sin_encoger() -> void:
	# Arrange (como las flechas: fade gradual, nada de encogido raro)
	var hacha: HachaPerrenaProjectile = HachaScene.instantiate() as HachaPerrenaProjectile
	_root_test.add_child(hacha)
	var enemy := Node3D.new()
	enemy.name = "GoblinTest"
	enemy.add_to_group("enemies")
	_root_test.add_child(enemy)
	hacha._procesar_impacto(enemy, Vector3.ZERO, Vector3.UP)
	var escala_al_clavar: Vector3 = hacha.scale

	# Act: iniciar el desvanecido
	hacha._desvanecer_y_liberar()

	# Assert: no se encoge; funde el alfa de copias de material por hacha
	assert_true(hacha._desvaneciendose, "Debe marcar _desvaneciendose")
	assert_eq(hacha.scale, escala_al_clavar, "No debe encogerse al desaparecer")
	var con_alfa := 0
	for mi in hacha.find_children("*", "MeshInstance3D", true, false):
		var mat = (mi as MeshInstance3D).material_override
		if mat is StandardMaterial3D and (mat as StandardMaterial3D).transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
			con_alfa += 1
	assert_gt(con_alfa, 0, "Las mallas deben fundirse por alfa (materiales con TRANSPARENCY_ALPHA)")


func test_hacha_especial_levanta_piedras_en_terreno() -> void:
	# Arrange: Ult contra suelo estático
	var hacha: HachaPerrenaProjectile = HachaScene.instantiate() as HachaPerrenaProjectile
	_root_test.add_child(hacha)
	hacha.initialize(Vector3.RIGHT, 1.0, null, true, null)
	var terreno := StaticBody3D.new()
	terreno.name = "TerrenoSuelo"
	_root_test.add_child(terreno)

	# Act: impactar terreno
	hacha._procesar_impacto(terreno, Vector3.ZERO, Vector3.UP)

	# Assert: ráfaga de rocas del pilar Lonko
	assert_not_null(_root_test.find_child("ParticulasRocasHacha", true, false), "El Ult en terreno debe levantar pequeñas piedras")


func test_hacha_normal_no_levanta_piedras_en_terreno() -> void:
	# Arrange: hacha normal contra el mismo suelo
	var hacha: HachaPerrenaProjectile = HachaScene.instantiate() as HachaPerrenaProjectile
	_root_test.add_child(hacha)
	var terreno := StaticBody3D.new()
	terreno.name = "TerrenoSuelo"
	_root_test.add_child(terreno)

	# Act: impactar terreno
	hacha._procesar_impacto(terreno, Vector3.ZERO, Vector3.UP)

	# Assert: sin rocas (efecto exclusivo del Ult)
	assert_null(_root_test.find_child("ParticulasRocasHacha", true, false), "El hacha normal no debe levantar piedras")


func _crear_enemigo_con_vida() -> Node3D:
	var escript := GDScript.new()
	escript.source_code = "extends Node3D\nvar health: int = 1\nfunc take_damage(d: float) -> void:\n\thealth -= int(d)\n"
	escript.reload()
	var enemy := Node3D.new()
	enemy.set_script(escript)
	enemy.name = "GoblinTest"
	enemy.add_to_group("enemies")
	_root_test.add_child(enemy)
	return enemy


func test_hacha_especial_suena_reventado_si_mata() -> void:
	# Arrange: Ult contra enemigo de 1 HP
	var hacha: HachaPerrenaProjectile = HachaScene.instantiate() as HachaPerrenaProjectile
	_root_test.add_child(hacha)
	hacha.initialize(Vector3.RIGHT, 1.0, null, true, null)
	var enemy := _crear_enemigo_con_vida()

	# Act: el Ult lo mata (3 de daño)
	hacha._procesar_impacto(enemy, Vector3.ZERO, Vector3.UP)

	# Assert: suena el reventado
	assert_eq(enemy.get("health"), -2, "El Ult debe dejar al enemigo sin vida")
	assert_not_null(_root_test.find_child("SfxReventadoUlt", true, false), "Si el Ult mata debe sonar Sonido reventado")


func test_hacha_normal_no_suena_reventado_si_mata() -> void:
	# Arrange: hacha normal contra enemigo de 1 HP
	var hacha: HachaPerrenaProjectile = HachaScene.instantiate() as HachaPerrenaProjectile
	_root_test.add_child(hacha)
	var enemy := _crear_enemigo_con_vida()

	# Act: lo mata con hacha normal (2 de daño)
	hacha._procesar_impacto(enemy, Vector3.ZERO, Vector3.UP)

	# Assert: sin reventado (exclusivo del Ult)
	assert_lt(int(enemy.get("health")), 1, "El hacha normal debe dejarlo sin vida")
	assert_null(_root_test.find_child("SfxReventadoUlt", true, false), "El hacha normal no debe sonar reventado")


func test_hacha_flota_en_agua_hasta_desvanecerse() -> void:
	# Arrange: plano de agua en y=0 y hacha cayendo al foso
	var agua := Node3D.new()
	agua.name = "AguaTest"
	agua.add_to_group("agua")
	_root_test.add_child(agua)
	var mi := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(60, 60)
	mi.mesh = plano
	agua.add_child(mi)
	var hacha: HachaPerrenaProjectile = HachaScene.instantiate() as HachaPerrenaProjectile
	_root_test.add_child(hacha)
	hacha.global_position = Vector3(0, 3, 0)
	hacha.velocity = Vector3(2, -2, 0)

	# Act: pasos de física hasta cruzar la superficie
	for i in range(60):
		if hacha.is_stuck:
			break
		hacha._physics_process(0.016)
		await get_tree().physics_frame

	# Assert: flota en superficie sin efectos, hasta el fade
	assert_true(hacha.is_stuck, "Al caer al agua debe detenerse flotando")
	assert_almost_eq(hacha.global_position.y, 0.03, 0.05, "Flota sobre la superficie")
	assert_eq(hacha.get_parent(), _root_test, "Sin emparentados raros")
	assert_true(is_instance_valid(hacha), "Sigue visible hasta desvanecerse")


func test_hacha_especial_fallida_en_terreno_suena_fallo_tierra() -> void:
	# Arrange: Ult contra suelo (sin enemigos)
	var hacha: HachaPerrenaProjectile = HachaScene.instantiate() as HachaPerrenaProjectile
	_root_test.add_child(hacha)
	hacha.initialize(Vector3.RIGHT, 1.0, null, true, null)
	var terreno := StaticBody3D.new()
	terreno.name = "TerrenoSuelo"
	_root_test.add_child(terreno)

	# Act: el Ult impacta en terreno
	hacha._procesar_impacto(terreno, Vector3.ZERO, Vector3.UP)

	# Assert: suena el fallo a tierra
	assert_not_null(_root_test.find_child("SfxFalloTierraUlt", true, false), "El Ult fallido en terreno debe sonar impacto fallo tierra")


func test_hacha_especial_en_pilar_lonko_suena_fallo_tierra() -> void:
	# Arrange: Ult contra el pilar de la arquera Lonko
	var hacha: HachaPerrenaProjectile = HachaScene.instantiate() as HachaPerrenaProjectile
	_root_test.add_child(hacha)
	hacha.initialize(Vector3.RIGHT, 1.0, null, true, null)
	var pilar := StaticBody3D.new()
	pilar.name = "PilarLonko"
	pilar.set_meta("es_pilar_enemigo", true)
	_root_test.add_child(pilar)

	# Act: el Ult impacta en el pilar (no es enemigo)
	hacha._procesar_impacto(pilar, Vector3.ZERO, Vector3.UP)

	# Assert: suena el fallo a tierra (el pilar no cuenta como enemigo)
	assert_not_null(_root_test.find_child("SfxFalloTierraUlt", true, false), "El Ult en el pilar de Lonko debe sonar impacto fallo tierra")


func test_hacha_especial_en_enemigo_no_suena_fallo_tierra() -> void:
	# Arrange: Ult contra enemigo vivo (no lo mata: 10 HP)
	var hacha: HachaPerrenaProjectile = HachaScene.instantiate() as HachaPerrenaProjectile
	_root_test.add_child(hacha)
	hacha.initialize(Vector3.RIGHT, 1.0, null, true, null)
	var escript := GDScript.new()
	escript.source_code = "extends Node3D\nvar health: int = 10\nfunc take_damage(d: float) -> void:\n\thealth -= int(d)\n"
	escript.reload()
	var enemy := Node3D.new()
	enemy.set_script(escript)
	enemy.name = "GoblinTest"
	enemy.add_to_group("enemies")
	_root_test.add_child(enemy)

	# Act: impacta al enemigo sin matarlo
	hacha._procesar_impacto(enemy, Vector3.ZERO, Vector3.UP)

	# Assert: sin fallo (sí dio en un enemigo) y sin reventado (no murió)
	assert_gt(int(enemy.get("health")), 0, "El enemigo debe seguir vivo")
	assert_null(_root_test.find_child("SfxFalloTierraUlt", true, false), "El Ult que da en enemigo no debe sonar fallo")
	assert_null(_root_test.find_child("SfxReventadoUlt", true, false), "Sin muerte no debe sonar reventado")


func test_hacha_perrena_tiempo_pegada_3_segundos() -> void:
	# Arrange
	var hacha: HachaPerrenaProjectile = HachaScene.instantiate() as HachaPerrenaProjectile
	_root_test.add_child(hacha)

	# Assert constante / export de tiempo de clavado
	assert_eq(hacha.tiempo_pegada, 3.0, "El hacha debe permanecer clavada durante 3 segundos")

	# Dummy enemigo
	var enemy := Node3D.new()
	enemy.add_to_group("enemies")
	_root_test.add_child(enemy)

	# Act: Impactar enemigo
	hacha._procesar_impacto(enemy, Vector3.ZERO, Vector3.UP)

	# Assert: Se clava y detiene
	assert_true(hacha.is_stuck, "Debe marcar is_stuck = true")
	assert_eq(hacha.velocity, Vector3.ZERO, "Su velocidad debe ser cero tras impactar")
	assert_false(hacha._desvaneciendose, "No debe desvanecerse de inmediato")


func test_defensora_perrena_muerte_efecto_particulas_ballesteras() -> void:
	# Arrange
	var defensora: DefensoraPerrena = DefensoraScene.instantiate() as DefensoraPerrena
	_root_test.add_child(defensora)

	# Act: Provocar muerte
	defensora._morir()

	# Assert: Estado DYING y búsqueda de las partículas creadas idénticas a las ballesteras
	assert_eq(defensora.current_state, DefensoraPerrena.State.DYING, "Debe entrar en estado DYING")
	var particulas := _root_test.find_child("ParticulasMuerteCeleste", true, false)
	if not particulas:
		particulas = defensora.find_child("ParticulasMuerteCeleste", true, false)
	assert_not_null(particulas, "Debe instanciar las partículas 'ParticulasMuerteCeleste' de las ballesteras al morir")


func test_hacha_perrena_especial_100_por_ciento_acierto_guiado() -> void:
	# Arrange
	var hacha: HachaPerrenaProjectile = HachaScene.instantiate() as HachaPerrenaProjectile
	_root_test.add_child(hacha)
	hacha.global_position = Vector3(0, 0, 0)

	var target_enemy := Node3D.new()
	target_enemy.name = "EnemyElevado"
	target_enemy.add_to_group("enemies")
	_root_test.add_child(target_enemy)
	# Enemigo posicionado arriba a la derecha (requiere corrección de trayectoria)
	target_enemy.global_position = Vector3(6.0, 3.0, 0.0)

	# Inicializar con disparo recto horizontal hacia +X pero con target fijado arriba
	hacha.initialize(Vector3.RIGHT, 1.0, null, true, target_enemy)

	# Act: Simular pasos de física de guiado
	for i in range(15):
		if hacha._impacto_procesado:
			break
		hacha._physics_process(0.05)

	# Assert: El guiado corrigió la trayectoria hacia arriba (+Y) y alcanzó con éxito el objetivo
	assert_true(hacha.is_stuck or hacha._impacto_procesado, "El hacha especial debe impactar el objetivo con 100% de acierto")


func test_hacha_perrena_especial_sin_efecto_dorado() -> void:
	# Arrange & Act
	var hacha: HachaPerrenaProjectile = HachaScene.instantiate() as HachaPerrenaProjectile
	_root_test.add_child(hacha)
	hacha.initialize(Vector3.RIGHT, 1.0, null, true, null)

	# Assert: No debe poseer luces ni estelas de partículas doradas
	assert_null(hacha.find_child("SpecialAxeLight", true, false), "No debe crearse ninguna luz dorada en el hacha especial")
	assert_null(hacha.find_child("SpecialAxeTrail", true, false), "No debe crearse ninguna estela de partículas doradas en el hacha especial")


func test_hacha_perrena_dano_imp_escudo_y_guardiana_moradita() -> void:
	# Arrange
	var hacha: HachaPerrenaProjectile = HachaScene.instantiate() as HachaPerrenaProjectile
	_root_test.add_child(hacha)

	var imp_escudo := ImpShieldGirl.new()
	imp_escudo.name = "ImpShieldGirl"
	imp_escudo.add_to_group("enemies")
	imp_escudo.add_to_group("shield_imps")
	_root_test.add_child(imp_escudo)

	var guardiana := GuardianaMoradita.new()
	guardiana.name = "GuardianaMoradita"
	guardiana.add_to_group("enemies")
	guardiana.add_to_group("guardians")
	_root_test.add_child(guardiana)

	# Act & Assert 1: Hacha normal hace 2 base + 3 bono = 5 a imp de escudo y guardiana moradita
	assert_eq(hacha.calcular_dano_para(imp_escudo), 5.0, "Hacha normal debe hacer 5 de daño (2 + 3 bono) a ImpShieldGirl")
	assert_eq(hacha.calcular_dano_para(guardiana), 5.0, "Hacha normal debe hacer 5 de daño (2 + 3 bono) a GuardianaMoradita")

	# Act & Assert 2: Hacha especial hace 3 base + 6 bono = 9 a ambas
	var hacha_esp: HachaPerrenaProjectile = HachaScene.instantiate() as HachaPerrenaProjectile
	_root_test.add_child(hacha_esp)
	hacha_esp.initialize(Vector3.RIGHT, 1.0, null, true, null)
	assert_eq(hacha_esp.calcular_dano_para(imp_escudo), 9.0, "Hacha especial debe hacer 9 de daño (3 + 6 bono) a ImpShieldGirl")
	assert_eq(hacha_esp.calcular_dano_para(guardiana), 9.0, "Hacha especial debe hacer 9 de daño (3 + 6 bono) a GuardianaMoradita")


func test_hacha_perrena_no_ignora_guardiana_en_defensa() -> void:
	# Arrange
	var hacha: HachaPerrenaProjectile = HachaScene.instantiate() as HachaPerrenaProjectile
	_root_test.add_child(hacha)

	var guardiana := GuardianaMoradita.new()
	guardiana.name = "GuardianaMoradita"
	guardiana.add_to_group("enemies")
	guardiana.add_to_group("guardians")
	guardiana.health = 10
	_root_test.add_child(guardiana)

	# Act & Assert:
	guardiana.current_state = GuardianaMoradita.State.DEFENDING
	assert_false(hacha._es_entidad_a_ignorar(guardiana), "No debe ignorar a GuardianaMoradita cuando está en estado DEFENDING")

	guardiana.current_state = GuardianaMoradita.State.SHIELD_HIT
	assert_false(hacha._es_entidad_a_ignorar(guardiana), "No debe ignorar a GuardianaMoradita cuando está en estado SHIELD_HIT")

	guardiana.current_state = GuardianaMoradita.State.RUNNING
	assert_false(hacha._es_entidad_a_ignorar(guardiana), "No debe ignorar a GuardianaMoradita cuando está en estado RUNNING")

	guardiana.current_state = GuardianaMoradita.State.ATTACKING
	assert_false(hacha._es_entidad_a_ignorar(guardiana), "No debe ignorar a GuardianaMoradita cuando está en estado ATTACKING")

	guardiana.current_state = GuardianaMoradita.State.DYING
	assert_true(hacha._es_entidad_a_ignorar(guardiana), "Debe ignorar a GuardianaMoradita cuando está en estado DYING")

	guardiana.current_state = GuardianaMoradita.State.DEAD
	assert_true(hacha._es_entidad_a_ignorar(guardiana), "Debe ignorar a GuardianaMoradita cuando está en estado DEAD")


func test_hacha_perrena_impacto_fisico_guardiana_en_defensa() -> void:
	# Arrange
	var guardiana_scene := load("res://Entities/Enemigo_Goblina_Escudo_Pesado/GuardianaMoradita.tscn") as PackedScene
	var guardiana: GuardianaMoradita = guardiana_scene.instantiate() as GuardianaMoradita
	_root_test.add_child(guardiana)
	guardiana.global_position = Vector3(4.0, 0.185, 0.0)
	guardiana.current_state = GuardianaMoradita.State.DEFENDING
	var hp_inicial: int = guardiana.health

	# Esperar a que la física registre a la guardiana en el espacio
	await get_tree().physics_frame
	await get_tree().physics_frame

	# Crear hacha volando hacia Guardiana a la altura de su pecho/escudo
	var hacha: HachaPerrenaProjectile = HachaScene.instantiate() as HachaPerrenaProjectile
	_root_test.add_child(hacha)
	hacha.gravedad_escala = 0.0
	hacha._gravity = 0.0
	hacha.global_position = Vector3(3.0, 0.58, 0.0)
	hacha.velocity = Vector3(15.0, 0.0, 0.0)

	# Act: avanzar física
	for i in range(25):
		if hacha._impacto_procesado:
			break
		hacha._physics_process(0.016)
		await get_tree().physics_frame

	# Assert: El hacha debe haber impactado y dañado a Guardiana
	assert_true(hacha.is_stuck or hacha._impacto_procesado, "El hacha debe impactar a Guardiana en estado DEFENDING")
	assert_lt(guardiana.health, hp_inicial, "Guardiana debe haber recibido daño del hacha")




func test_hacha_perrena_impacta_siempre_por_el_lado_del_filo() -> void:
	# Arrange: Hacha volando en diagonal hacia abajo y derecha
	var hacha: HachaPerrenaProjectile = HachaScene.instantiate() as HachaPerrenaProjectile
	_root_test.add_child(hacha)
	var dir := Vector3(1.0, -0.5, 0.0).normalized()
	hacha.velocity = dir * 15.0

	var dummy := Node3D.new()
	dummy.name = "TargetDummy"
	dummy.add_to_group("enemies")
	_root_test.add_child(dummy)

	# Act: Simular impacto
	hacha._procesar_impacto(dummy, Vector3.ZERO, Vector3.UP)

	# Assert: Orientación angular en Z debe alinear el filo exactamente con la dirección de impacto
	var ang_esperado: float = atan2(dir.y, dir.x) - deg_to_rad(73.35)
	assert_almost_eq(hacha._modelo_hacha.rotation.z, ang_esperado, 0.001, "El hacha debe orientar su filo (+X corregido) exactamente hacia la trayectoria de impacto")


func test_hacha_perrena_no_se_traba_con_barreras_limite() -> void:
	# Arrange
	var hacha: HachaPerrenaProjectile = HachaScene.instantiate() as HachaPerrenaProjectile
	_root_test.add_child(hacha)
	hacha.initialize(Vector3.RIGHT, 1.0, null, true, null)
	hacha.global_position = Vector3(-6.0, 2.0, 0.0)

	var barrera := StaticBody3D.new()
	barrera.name = "LIMITZONE"
	barrera.add_to_group("barreras_limite")
	barrera.collision_layer = 512
	_root_test.add_child(barrera)

	# Act 1: Intentar impactar la barrera límite
	hacha._procesar_impacto(barrera, Vector3(-5.7, 2.0, 0.0), Vector3.LEFT)

	# Assert 1: La barrera debe ser ignorada, el proyectil no se clava ni detiene
	assert_false(hacha._impacto_procesado, "El hacha no debe procesar impacto en barreras límite")
	assert_false(hacha.is_stuck, "El hacha no debe quedarse trabada en barreras límite")
	assert_ne(hacha.velocity, Vector3.ZERO, "La velocidad no debe anularse al topar una barrera")

	# Act 2: Avanzar pasos de física en dirección a la barrera
	var pos_x_inicial: float = hacha.global_position.x
	hacha._physics_process(0.05)
	assert_gt(hacha.global_position.x, pos_x_inicial, "El hacha debe continuar avanzando en X sin trabarse flotando en el aire")








# === TESTS DE OBJETIVO LIBERADO (DEFENSIVA ANTI-CRASH) ===
func test_lanzar_hacha_con_objetivo_liberado_no_rompe() -> void:
	# Arrange: defensora lista y un blanco que muere antes del lanzamiento	
	var defensora: DefensoraPerrena = DefensoraScene.instantiate() as DefensoraPerrena	
	_root_test.add_child(defensora)
	defensora.global_position = Vector3.ZERO	
	var blanco := Node3D.new()
	_root_test.add_child(blanco)
	blanco.free()  # Simula enemigo liberado entre adquisicion y disparo	
	assert_false(is_instance_valid(blanco), "Precondici�n: el blanco debe estar liberado")
	var hachas_antes: int = 0	
	for n in _root_test.get_children():
		if n is HachaPerrenaProjectile:
			hachas_antes += 1	
		# Act: con el parametro antes tipado esto rompia en el binding	
	defensora._lanzar_hacha_hacia_objetivo(blanco)	
		# Assert: lanza igual (tiro de fallback hacia adelante) sin errores	
	var hachas_despues: int = 0	
	for n in _root_test.get_children():
		if n is HachaPerrenaProjectile:
			hachas_despues += 1	
	assert_eq(hachas_despues, hachas_antes + 1, "Debe generar el hacha aunque el blanco este liberado")
func test_proceso_atacando_reapunta_si_objetivo_muere() -> void:
	# Arrange: a mitad de animacion con objetivo muerto + otro vivo al alcance	
	var defensora: DefensoraPerrena = DefensoraScene.instantiate() as DefensoraPerrena	
	_root_test.add_child(defensora)
	defensora.global_position = Vector3.ZERO	
	var muerto := Node3D.new()	
	_root_test.add_child(muerto)
	muerto.free()	
	var vivo := Node3D.new()	
	vivo.name = "GoblinVivo"
	vivo.add_to_group("enemies")
	_root_test.add_child(vivo)
	vivo.global_position = Vector3(5.0, 0.0, 0.0)
	defensora._objetivo_actual = muerto	
	defensora._hacha_arrojada_en_ciclo = false	
	defensora._tiempo_en_estado = 0.35	
		# Act	
	defensora._proceso_atacando(0.016)	
		# Assert: revalido al vivo y disparo	
	assert_true(defensora._hacha_arrojada_en_ciclo, "Debe completar el ciclo de lanzamiento")
	assert_eq(defensora._objetivo_actual, vivo, "Debe reapuntar al enemigo vivo")
func test_initialize_hacha_con_objetivo_liberado_no_rompe() -> void:
	# Arrange	
	var hacha: HachaPerrenaProjectile = HachaScene.instantiate() as HachaPerrenaProjectile	
	_root_test.add_child(hacha)	
	var blanco := Node3D.new()	
	_root_test.add_child(blanco)	
	blanco.free()	
		# Act	
	hacha.initialize(Vector3.RIGHT, 1.0, hacha, false, blanco)	
		# Assert: lo guarda sin romper; el homing lo filtra con is_instance_valid	
	assert_false(is_instance_valid(hacha.objetivo_fijado), "El objetivo fijado debe seguir invalido")


func test_defensora_perrena_respeta_escala_colocada_en_escena() -> void:
	# Arrange (bug canoa del río: el _ready pisaba el 0.18 colocado en el editor con 0.3
	# y Perrena se veía ~67% más grande en juego que en el editor)
	var defensora: DefensoraPerrena = DefensoraScene.instantiate() as DefensoraPerrena
	defensora.scale = Vector3(0.18, 0.18, 0.18)
	_root_test.add_child(defensora)

	# Assert: la escala colocada se conserva tras el _ready
	assert_almost_eq(defensora.scale.x, 0.18, 0.001, "Debe conservar la escala 0.18 colocada en la escena (canoa)")
	assert_almost_eq(defensora.scale.y, 0.18, 0.001, "Debe conservar la escala 0.18 colocada en la escena (canoa)")


func test_defensora_perrena_normaliza_escala_identidad_a_03() -> void:
	# Arrange: instancia a escala identidad (ej. creada por código del ítem de refuerzo)
	var defensora: DefensoraPerrena = DefensoraScene.instantiate() as DefensoraPerrena
	defensora.scale = Vector3.ONE
	_root_test.add_child(defensora)

	# Assert: se normaliza a la paridad visual del modelo jugable (0.3)
	assert_almost_eq(defensora.scale.x, 0.3, 0.001, "A escala identidad debe normalizarse a 0.3")


func test_sonido_perrena_ult_en_habilidad_especial() -> void:
	# Arrange
	var defensora: DefensoraPerrena = DefensoraScene.instantiate() as DefensoraPerrena
	_root_test.add_child(defensora)

	# Assert constante y recurso
	assert_eq(DefensoraPerrena.SFX_ULT, "res://TEST_/Perrena ult.mp3", "La constante SFX_ULT debe apuntar a Perrena ult.mp3")
	assert_true(ResourceLoader.exists(DefensoraPerrena.SFX_ULT), "El archivo Perrena ult.mp3 debe existir en disco")

	# Act: Iniciar habilidad especial / ult
	defensora._iniciar_habilidad_especial()

	# Assert: Debe crear y reproducir el nodo de sonido de ult
	assert_gte(defensora.volumen_ult_db, 10.0, "El volumen base configurado para ult debe ser >= 10.0 dB")
	var audio_ult: AudioStreamPlayer3D = defensora.find_child("SfxUltPerrena", true, false) as AudioStreamPlayer3D
	assert_not_null(audio_ult, "Debe instanciar el AudioStreamPlayer3D para el ult")
	if audio_ult:
		assert_not_null(audio_ult.stream, "El reproductor de audio del ult debe tener stream asignado")
		assert_true(audio_ult.playing, "El sonido de ult debe estar reproduciéndose")
		assert_gte(audio_ult.volume_db, 10.0, "El volumen de reproducción debe ser potente (>= 10.0 dB)")


func test_velocidades_despliegue_reducidas_caminar_y_escaleras() -> void:
	# Arrange
	var defensora: DefensoraPerrena = DefensoraScene.instantiate() as DefensoraPerrena
	_root_test.add_child(defensora)

	# Assert: Las velocidades por defecto al ser invocada con su ítem deben ser menores
	# que los valores originales hardcodeados (2.8 correr, 1.5 escaleras)
	assert_lt(defensora.velocidad_caminar, 2.0, "La velocidad al correr/caminar debe ser menor a 2.0 (reducida)")
	assert_lt(defensora.velocidad_escaleras, 1.0, "La velocidad en escaleras debe ser menor a 1.0 (reducida)")
	assert_almost_eq(defensora.velocidad_caminar, 1.4, 0.01, "Velocidad caminar configurada en 1.4")
	assert_almost_eq(defensora.velocidad_escaleras, 0.7, 0.01, "Velocidad escaleras configurada en 0.7")


func _crear_pilar_dummy(vida: float) -> PilarLonkoBody:
	var pilar := PilarLonkoBody.new()
	pilar.name = "PilarLonko"
	_root_test.add_child(pilar)
	pilar.vida_pilar = vida
	return pilar


func test_perrena_ignora_pilar_destruido() -> void:
	# Arrange (bug debug: destruía un pilar que no debería ser visible/atacable)
	var defensora: DefensoraPerrena = DefensoraScene.instantiate() as DefensoraPerrena
	_root_test.add_child(defensora)
	defensora.global_position = Vector3.ZERO
	var pilar := _crear_pilar_dummy(0.0)
	pilar.global_position = Vector3(5, 0, 0)
	var basico := Node3D.new()
	basico.name = "GoblinArquero"
	basico.add_to_group("enemies")
	_root_test.add_child(basico)
	basico.global_position = Vector3(8, 0, 0)

	# Act 1: pilar destruido no es objetivo aunque sea Prioridad 2
	var obj1: Node = defensora._buscar_mejor_objetivo()
	assert_eq(obj1, basico, "El pilar destruido (vida 0) no debe seleccionarse")

	# Act 2: pilar con vida sí es Prioridad 2 sobre el básico
	pilar.vida_pilar = 5.0
	var obj2: Node = defensora._buscar_mejor_objetivo()
	assert_eq(obj2, pilar, "El pilar con vida debe priorizarse (P2)")


func test_perrena_ignora_escudo_invisible() -> void:
	# Arrange: escudo enemigo oculto + básico visible
	var defensora: DefensoraPerrena = DefensoraScene.instantiate() as DefensoraPerrena
	_root_test.add_child(defensora)
	defensora.global_position = Vector3.ZERO
	var escudo := StaticBody3D.new()
	escudo.name = "EscudoEnemigo"
	escudo.set_meta("es_escudo_enemigo", true)
	escudo.add_to_group("escudos")
	_root_test.add_child(escudo)
	escudo.global_position = Vector3(5, 0, 0)
	escudo.visible = false
	var basico := Node3D.new()
	basico.name = "GoblinArquero"
	basico.add_to_group("enemies")
	_root_test.add_child(basico)
	basico.global_position = Vector3(8, 0, 0)

	# Act 1: escudo invisible no es objetivo
	var obj1: Node = defensora._buscar_mejor_objetivo()
	assert_eq(obj1, basico, "El escudo invisible no debe seleccionarse")

	# Act 2: al visibilizarse vuelve a ser Prioridad 2
	escudo.visible = true
	var obj2: Node = defensora._buscar_mejor_objetivo()
	assert_eq(obj2, escudo, "El escudo visible debe priorizarse (P2)")


func test_hacha_especial_perrena_no_se_parrea_ni_desvia_por_azulina() -> void:
	# Arrange
	var azulina := Azulina.new()
	_root_test.add_child(azulina)
	azulina.parry_habilitado = true
	azulina._parry_activo = true

	var hacha_esp: HachaPerrenaProjectile = HachaScene.instantiate() as HachaPerrenaProjectile
	_root_test.add_child(hacha_esp)
	hacha_esp.initialize(Vector3.RIGHT, 1.0, null, true, azulina)

	# Act 1: Azulina intenta parrear con parry activo
	var repelido_parry: bool = azulina.manejar_impacto_aura(hacha_esp)

	# Assert 1: El parry activo NO debe repeler el hacha gigante
	assert_false(repelido_parry, "Azulina con parry activo NO debe repeler el ult de Perrena")

	# Act 2: Azulina con giro de desvío activo
	azulina._parry_activo = false
	azulina._desviando_giro = true
	var repelido_desvio: bool = azulina.manejar_impacto_aura(hacha_esp)

	# Assert 2: El giro de desvío NO debe desviar el hacha gigante
	assert_false(repelido_desvio, "Azulina con giro de desvío NO debe desviar el ult de Perrena")

	# Act 3: Procesar impacto directo de hacha especial en Azulina
	hacha_esp._procesar_impacto(azulina, azulina.global_position, Vector3.LEFT)
	assert_false(hacha_esp.is_queued_for_deletion(), "El hacha especial no debe destruirse por parry")
	assert_true(hacha_esp.is_stuck, "El hacha especial debe clavarse e impactar")


func test_hacha_especial_perrena_rompe_aura_rosa_sin_rebotar() -> void:
	# Arrange
	var arquera := ArqueraRosa.new()
	_root_test.add_child(arquera)
	arquera.aura_vida = 3

	var hacha_esp: HachaPerrenaProjectile = HachaScene.instantiate() as HachaPerrenaProjectile
	_root_test.add_child(hacha_esp)
	hacha_esp.initialize(Vector3.RIGHT, 1.0, null, true, arquera)

	# Act: comprobar manejo de aura
	var repelido: bool = arquera.manejar_impacto_aura(hacha_esp)

	# Assert: Debe romper el aura y no repeler el proyectil
	assert_false(repelido, "El ult de Perrena NO debe ser repelido por el aura de Arquera Rosa")
	assert_lte(arquera.aura_vida, 0, "El ult de Perrena debe romper el aura de Arquera Rosa como flecha explosiva")


func test_hacha_normal_perrena_si_rebota_con_aura() -> void:
	# Arrange
	var arquera := ArqueraRosa.new()
	_root_test.add_child(arquera)
	arquera.aura_vida = 3

	var hacha_norm: HachaPerrenaProjectile = HachaScene.instantiate() as HachaPerrenaProjectile
	_root_test.add_child(hacha_norm)
	hacha_norm.initialize(Vector3.RIGHT, 1.0, null, false, arquera)

	# Act: el hacha normal sí es repelida por el aura activa
	var repelido: bool = arquera.manejar_impacto_aura(hacha_norm)
	assert_true(repelido, "El hacha normal de Perrena SÍ debe ser repelida por el aura activa")


func _limpiar_estelas_hacha() -> void:
	for n in get_tree().get_nodes_in_group("estela_hacha"):
		if is_instance_valid(n):
			n.free()


func test_hacha_ult_deja_estela_morada() -> void:
	# Arrange: hacha gigante del ult en vuelo
	_limpiar_estelas_hacha()
	var hacha_esp: HachaPerrenaProjectile = HachaScene.instantiate() as HachaPerrenaProjectile
	_root_test.add_child(hacha_esp)
	hacha_esp.global_position = Vector3(0.0, 5.0, 0.0)
	hacha_esp.initialize(Vector3.RIGHT, 1.0, null, true, null)

	# Act: 6 frames en vuelo
	for i in range(6):
		hacha_esp._physics_process(0.016)

	# Assert: fantasmas morados con la forma del hacha
	var fantasmas := get_tree().get_nodes_in_group("estela_hacha")
	assert_gt(fantasmas.size(), 0, "El ult debe dejar estela")
	var mat := (fantasmas[0] as MeshInstance3D).material_override as StandardMaterial3D
	assert_not_null(mat, "El fantasma debe tener material propio")
	assert_almost_eq(mat.albedo_color.r, 0.6, 0.05, "Tono morado R")
	assert_almost_eq(mat.albedo_color.b, 1.0, 0.05, "Tono morado B")
	assert_lte(mat.albedo_color.a, 0.35, "Transparente y sutil")

	# Cleanup
	_limpiar_estelas_hacha()
	hacha_esp.free()


func test_hacha_normal_no_deja_estela() -> void:
	# Arrange: hacha normal en vuelo
	_limpiar_estelas_hacha()
	var hacha: HachaPerrenaProjectile = HachaScene.instantiate() as HachaPerrenaProjectile
	_root_test.add_child(hacha)
	hacha.global_position = Vector3(0.0, 5.0, 0.0)
	hacha.initialize(Vector3.RIGHT, 1.0, null, false, null)

	# Act: 6 frames en vuelo
	for i in range(6):
		hacha._physics_process(0.016)

	# Assert: la normal vuela limpia, sin fantasmas
	assert_eq(get_tree().get_nodes_in_group("estela_hacha").size(), 0, "El hacha normal no debe dejar estela")

	# Cleanup
	_limpiar_estelas_hacha()
	hacha.free()
