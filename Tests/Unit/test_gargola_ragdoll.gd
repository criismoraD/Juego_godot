extends "res://addons/gut/test.gd"

const GARGOLA_SCENE: PackedScene = preload("res://Entities/Enemigo_Gargola/Gargola.tscn")

var gargola: Node3D = null


func before_each():
	gargola = GARGOLA_SCENE.instantiate()
	add_child(gargola)
	
	# Mockear el esqueleto físico en el test si no está preconfigurado en la escena.
	# Esto permite probar la lógica de activación del script en aislamiento de la configuración manual del editor.
	var scripted := gargola as Gargola
	if scripted and scripted.skeleton:
		var has_simulator := false
		for child in scripted.skeleton.get_children():
			if child is PhysicalBoneSimulator3D:
				has_simulator = true
				break
		if not has_simulator:
			var sim := PhysicalBoneSimulator3D.new()
			sim.name = "PhysicalBoneSimulator3D"
			scripted.skeleton.add_child(sim)
			
			var pb := PhysicalBone3D.new()
			pb.name = "PB_root"
			pb.bone_name = "root_ref.x"
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_NONE
			sim.add_child(pb)


func after_each():
	if is_instance_valid(gargola):
		gargola.free()


# ═══════════════════════════════════════════════════════════════════════════════
# 1. Configuración de variables básicas
# ═══════════════════════════════════════════════════════════════════════════════

func test_tiempo_espera_disolucion_trapo_default_es_2p5():
	var scripted := gargola as Gargola
	assert_almost_eq(scripted.tiempo_espera_disolucion_trapo, 2.5, 0.01,
		"tiempo_espera_disolucion_trapo debe ser 2.5 por defecto")


func test_impulso_horizontal_positivo():
	var scripted := gargola as Gargola
	assert_gt(scripted.impulso_horizontal_ragdoll, 0.0,
		"impulso_horizontal_ragdoll debe ser mayor a 0")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. Inicialización y activación del Ragdoll manual
# ═══════════════════════════════════════════════════════════════════════════════

func test_ragdoll_simulator_se_detecta_al_morir():
	await get_tree().process_frame
	var scripted := gargola as Gargola
	scripted.health = 0
	scripted._change_state(scripted.State.DYING)
	assert_not_null(scripted.ragdoll_simulator,
		"ragdoll_simulator debe encontrarse al entrar al estado de muerte")
	assert_true(
		scripted.ragdoll_simulator is PhysicalBoneSimulator3D,
		"ragdoll_simulator debe ser un PhysicalBoneSimulator3D"
	)


func test_huesos_fisicos_recolectados_al_morir():
	await get_tree().process_frame
	var scripted := gargola as Gargola
	scripted.health = 0
	scripted._change_state(scripted.State.DYING)
	assert_gt(
		scripted.huesos_fisicos_creados.size(),
		0,
		"Debe recolectar los huesos físicos hijos del simulador"
	)


func test_collider_desactivado_en_ragdoll():
	await get_tree().process_frame
	var scripted := gargola as Gargola
	scripted.health = 0
	scripted._change_state(scripted.State.DYING)
	assert_eq(
		scripted.collision_layer, 0,
		"collision_layer del CharacterBody debe ser 0 durante el ragdoll"
	)
	assert_eq(
		scripted.collision_mask, 0,
		"collision_mask del CharacterBody debe ser 0 durante el ragdoll"
	)


# ═══════════════════════════════════════════════════════════════════════════════
# 3. Temporizador de disolución tras ragdoll
# ═══════════════════════════════════════════════════════════════════════════════

func test_disolucion_no_ocurre_antes_del_timer():
	await get_tree().process_frame
	var scripted := gargola as Gargola
	scripted.health = 0
	scripted._change_state(scripted.State.DYING)
	# Simular delta menor que el tiempo de espera
	scripted._physics_process(scripted.tiempo_espera_disolucion_trapo * 0.5)
	assert_false(
		scripted.ragdoll_listo_para_disolucion,
		"ragdoll_listo_para_disolucion no debe activarse antes de tiempo_espera_disolucion_trapo"
	)


func test_disolucion_ocurre_tras_timer():
	await get_tree().process_frame
	var scripted := gargola as Gargola
	scripted.health = 0
	scripted._change_state(scripted.State.DYING)
	# Simular delta >= el tiempo de espera
	scripted._physics_process(scripted.tiempo_espera_disolucion_trapo + 0.1)
	assert_true(
		scripted.ragdoll_listo_para_disolucion,
		"ragdoll_listo_para_disolucion debe ser true tras tiempo_espera_disolucion_trapo"
	)


# ═══════════════════════════════════════════════════════════════════════════════
# 4. Hips global position = primer hueso del ragdoll o fallback
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_hips_no_es_zero():
	await get_tree().process_frame
	var scripted := gargola as Gargola
	var pos := scripted._get_hips_global_position()
	assert_ne(
		pos, Vector3.ZERO,
		"_get_hips_global_position no debe retornar Vector3.ZERO"
	)


# ═══════════════════════════════════════════════════════════════════════════════
# 5. Anti-estiramiento: cuerpo anclado al trapo y corrección angular con tope
# ═══════════════════════════════════════════════════════════════════════════════

func test_simulacion_activa_ancla_cuerpo_al_trapo():
	await get_tree().process_frame
	var scripted := gargola as Gargola
	scripted.health = 0
	scripted._change_state(scripted.State.DYING)
	scripted._physics_process(1.0 / 60.0)
	assert_true(
		scripted.ragdoll_simulacion_activa,
		"Tras arrancar la simulación, el cuerpo debe pasar a modo anclado al ragdoll"
	)
	assert_almost_eq(
		scripted.global_position.distance_to(scripted._get_hips_global_position()),
		0.0, 0.01,
		"El CharacterBody debe quedar pegado al centro del trapo (sin doble caída)"
	)


func test_tope_velocidad_angular_correctora_configurado():
	var scripted := gargola as Gargola
	assert_gt(
		scripted.MAX_VELOCIDAD_ANGULAR_CORRECCION, 0.0,
		"El tope de corrección angular debe ser positivo"
	)
	assert_lt(
		scripted.MAX_VELOCIDAD_ANGULAR_CORRECCION, 30.0,
		"El tope debe ser moderado para evitar azotes que estiren el modelo"
	)


# ═══════════════════════════════════════════════════════════════════════════════
# 6. Sin destello al morir
# ═══════════════════════════════════════════════════════════════════════════════

func test_golpe_letal_no_genera_destello():
	await get_tree().process_frame
	var scripted := gargola as Gargola
	scripted.health = 2
	var antes := _contar_destellos()

	scripted.take_damage(10.0)

	assert_eq(scripted.current_state, scripted.State.DYING, "El golpe debe resultar letal")
	assert_eq(
		_contar_destellos(), antes,
		"Al morir NO debe aparecer el destello de explosión"
	)


func test_golpe_no_letal_mantiene_destello_de_impacto():
	await get_tree().process_frame
	var scripted := gargola as Gargola
	scripted.health = 5
	var antes := _contar_destellos()

	scripted.take_damage(1.0)

	assert_ne(scripted.current_state, scripted.State.DYING, "El golpe no debe matar")
	assert_eq(
		_contar_destellos(), antes + 1,
		"Los golpes normales deben conservar el destello de impacto"
	)


func _contar_destellos() -> int:
	return get_tree().root.find_children("*", "ImpactoGargolaVFX", true, false).size()