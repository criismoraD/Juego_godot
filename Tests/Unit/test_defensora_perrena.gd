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
	# Arrange
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






