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
		_root_test.queue_free()
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


func test_defensora_perrena_habilidad_especial_cada_6_ataques() -> void:
	# Arrange
	var defensora: DefensoraPerrena = DefensoraScene.instantiate() as DefensoraPerrena
	_root_test.add_child(defensora)

	# Dummy enemigo para que intente atacar
	var dummy_enemy := Node3D.new()
	dummy_enemy.name = "ImpObjetivo"
	dummy_enemy.add_to_group("enemies")
	_root_test.add_child(dummy_enemy)
	dummy_enemy.global_position = Vector3(5, 0, 0)

	# Act: Simular 5 ataques normales acumulados
	defensora.contador_ataques = 5
	defensora._intentar_iniciar_ataque()

	# Assert: El 6to ataque activa la habilidad especial (CELEBRATING)
	assert_eq(defensora.current_state, DefensoraPerrena.State.CELEBRATING, "El 6to ataque debe activar la habilidad especial")
	assert_true(defensora.es_inmune, "Durante la celebración, Perrena debe ser inmune")
	assert_true(defensora.aura_vfx.visible, "El aura protectora debe estar visible durante la celebración")
	assert_eq(defensora.contador_ataques, 0, "El contador de ataques debe reiniciarse tras activar la habilidad")

	# Assert: Daño recibido durante la habilidad es ignorado por la inmunidad
	var vida_previa: int = defensora.health
	defensora.take_damage(2.0)
	assert_eq(defensora.health, vida_previa, "Perrena no debe recibir daño mientras es inmune")

	# Act: Completar celebración
	defensora._tiempo_en_estado = 2.0
	defensora._proceso_celebrando(0.1)

	# Assert: Pierde inmunidad, oculta aura y vuelve a IDLE
	assert_false(defensora.es_inmune, "Debe perder la inmunidad al finalizar la celebración")
	assert_false(defensora.aura_vfx.visible, "El aura debe ocultarse al finalizar la celebración")
	assert_eq(defensora.current_state, DefensoraPerrena.State.IDLE, "Debe retornar a IDLE")


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

	# Act 3: Orientar hacia la escalera / pared (-Z)
	defensora._orientar_modelo_escalera()
	var toe_pos_ladder: Vector3 = skel.global_transform * toe_rest.origin
	var foot_pos_ladder: Vector3 = skel.global_transform * foot_rest.origin
	# Assert 3: La punta del pie debe apuntar hacia la pared (-Z)
	assert_lt(toe_pos_ladder.z, foot_pos_ladder.z, "Al orientar a la escalera, la punta del pie debe apuntar hacia -Z (pared)")


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






