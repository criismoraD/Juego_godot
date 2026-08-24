extends "res://addons/gut/test.gd"

const RAGDOLL_SCENE: PackedScene = preload("res://TEST_/IMP_EXPLOTADO/ImpCuerpoRagdoll.tscn")
const CANTIDAD_HUESOS_ESPERADA: int = 20
const RADIO_MAX_METROS: float = 0.1
const ALTURA_MAX_METROS: float = 0.5
const TOLERANCIA_MASA: float = 0.1

var ragdoll: Node3D = null


func before_each():
	ragdoll = RAGDOLL_SCENE.instantiate()
	add_child(ragdoll)
	await get_tree().process_frame


func after_each():
	if is_instance_valid(ragdoll):
		ragdoll.free()
	ragdoll = null


func _obtener_huesos() -> Array[PhysicalBone3D]:
	var huesos: Array[PhysicalBone3D] = []
	for hijo in ragdoll.find_children("*", "PhysicalBone3D", true, false):
		huesos.append(hijo as PhysicalBone3D)
	return huesos


# ═══════════════════════════════════════════════════════════════════════════════
# 1. Detección de nodos
# ═══════════════════════════════════════════════════════════════════════════════

func test_skeleton_detectado_al_ready():
	assert_not_null(ragdoll.skeleton, "skeleton debe detectarse en _ready")
	assert_true(ragdoll.skeleton is Skeleton3D, "skeleton debe ser Skeleton3D")


func test_simulador_detectado_al_ready():
	assert_not_null(ragdoll.simulator, "simulator debe detectarse en _ready")
	assert_true(ragdoll.simulator is PhysicalBoneSimulator3D, "simulator debe ser PhysicalBoneSimulator3D")


func test_cantidad_huesos_fisicos_correcta():
	var huesos := _obtener_huesos()
	assert_eq(huesos.size(), CANTIDAD_HUESOS_ESPERADA, "Debe haber %d PhysicalBone3D" % CANTIDAD_HUESOS_ESPERADA)
	assert_eq(ragdoll._physical_bones.size(), CANTIDAD_HUESOS_ESPERADA, "_physical_bones debe recolectar todos")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. Guardas de regresión: escala en metros (anti-colisiones-gigantes)
# ═══════════════════════════════════════════════════════════════════════════════

func test_capsulas_en_escala_metros():
	var huesos := _obtener_huesos()
	assert_gt(huesos.size(), 0, "Debe haber huesos que validar")
	for pb in huesos:
		var forma := _capsula_de(pb)
		assert_not_null(forma, "%s debe tener CapsuleShape3D" % pb.name)
		if forma:
			assert_true(forma.radius <= RADIO_MAX_METROS, "%s radio %.3f excede escala metro" % [pb.name, forma.radius])
			assert_true(forma.height <= ALTURA_MAX_METROS, "%s altura %.3f excede escala metro" % [pb.name, forma.height])
			assert_true(forma.height >= 2.0 * forma.radius, "%s altura debe ser >= 2*radius" % pb.name)


func test_posiciones_huesos_en_escala_metros():
	var huesos := _obtener_huesos()
	for pb in huesos:
		var distancia := pb.position.length()
		assert_lt(distancia, 1.0, "%s posicion %.3f fuera de escala metro (hueso gigante)" % [pb.name, distancia])


func test_altura_total_ragdoll_menor_a_un_medio():
	var ys: Array[float] = []
	for pb in _obtener_huesos():
		ys.append(pb.global_position.y if ragdoll.is_inside_tree() else pb.position.y)
	if ys.is_empty():
		fail_test("Sin huesos para medir")
		return
	var altura: float = ys.max() - ys.min()
	assert_lt(altura, 1.0, "Envergadura vertical del ragdoll (%.3f) debe ser < 1 m" % altura)


# ═══════════════════════════════════════════════════════════════════════════════
# 3. Distribución de masa
# ═══════════════════════════════════════════════════════════════════════════════

func test_masa_total_distribuida():
	var suma: float = 0.0
	for pb in _obtener_huesos():
		suma += pb.mass
	assert_almost_eq(suma, ragdoll.masa_total, TOLERANCIA_MASA, "La suma de masas debe igualar masa_total")


func test_masa_negativa_no_rompe_distribucion():
	var masas_originales: Array[float] = []
	for pb in _obtener_huesos():
		masas_originales.append(pb.mass)
	ragdoll.masa_total = -5.0
	ragdoll._aplicar_masas()
	var huesos := _obtener_huesos()
	for i in huesos.size():
		assert_gt(huesos[i].mass, 0.0, "masa_total negativa no debe producir masa <= 0")
		assert_almost_eq(huesos[i].mass, masas_originales[i], 0.0001, "Masa no debe cambiar con masa_total invalida")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. Activación / detención del ragdoll
# ═══════════════════════════════════════════════════════════════════════════════

func test_activar_ragdoll_cambia_estado_y_emite_senal():
	watch_signals(ragdoll)
	var impulso := Vector3(1.0, 2.0, 3.0)
	ragdoll.activar_ragdoll(impulso)
	assert_true(ragdoll.is_ragdoll_active, "is_ragdoll_active debe ser true tras activar")
	assert_signal_emitted(ragdoll, "ragdoll_activado", "Debe emitir ragdoll_activado")
	for pb in _obtener_huesos():
		assert_eq(pb.linear_velocity, impulso, "%s debe recibir el impulso" % pb.name)


func test_activar_sin_impulso_usa_default():
	ragdoll.activar_ragdoll(Vector3.ZERO)
	var esperado: Vector3 = ragdoll.impulso_inicial_defecto
	for pb in _obtener_huesos():
		assert_eq(pb.linear_velocity, esperado, "%s debe usar impulso_inicial_defecto" % pb.name)


func test_capas_de_colision_correctas_tras_activar():
	ragdoll.activar_ragdoll()
	for pb in _obtener_huesos():
		assert_eq(pb.collision_layer, 4, "%s collision_layer debe ser 4" % pb.name)
		assert_eq(pb.collision_mask, 1, "%s collision_mask debe ser 1" % pb.name)


func test_detener_ragdoll_cambia_estado_y_emite_senal():
	ragdoll.activar_ragdoll()
	watch_signals(ragdoll)
	ragdoll.detener_ragdoll()
	assert_false(ragdoll.is_ragdoll_active, "is_ragdoll_active debe ser false tras detener")
	assert_signal_emitted(ragdoll, "ragdoll_detenido", "Debe emitir ragdoll_detenido")


func test_reiniciar_zero_velocidades():
	ragdoll.activar_ragdoll(Vector3(5.0, 5.0, 5.0))
	ragdoll.reiniciar()
	assert_false(ragdoll.is_ragdoll_active, "reiniciar debe detener el ragdoll")
	for pb in _obtener_huesos():
		assert_eq(pb.linear_velocity, Vector3.ZERO, "%s velocidad debe ser cero" % pb.name)
		assert_eq(pb.angular_velocity, Vector3.ZERO, "%s velocidad angular debe ser cero" % pb.name)


func test_articulaciones_6dof_con_limites():
	var joints := ragdoll.find_children("*", "Generic6DOFJoint3D", true, false)
	assert_eq(joints.size(), CANTIDAD_HUESOS_ESPERADA - 1, "Debe haber 1 articulacion por cada hueso excepto Hips")
	for j in joints:
		var con_limite: bool = false
		for ax in ["x", "y", "z"]:
			if j.get("angular_limit_%s/enabled" % ax):
				con_limite = true
		assert_true(con_limite, "%s debe tener limite angular activo" % j.name)


func test_articulaciones_enlazan_huesos_fisicos():
	for j in ragdoll.find_children("*", "Generic6DOFJoint3D", true, false):
		assert_not_null(j.get_node_or_null(j.node_a), "%s node_a debe apuntar a un hueso fisico" % j.name)
		assert_not_null(j.get_node_or_null(j.node_b), "%s node_b debe apuntar a un hueso fisico" % j.name)


# ═══════════════════════════════════════════════════════════════════════════════
# 4b. Rigidez anti-efecto-goma (brazos que no aletean)
# ═══════════════════════════════════════════════════════════════════════════════

func test_joints_con_limites_lineales_cerrados():
	for j in ragdoll.find_children("*", "Generic6DOFJoint3D", true, false):
		for ax in ["x", "y", "z"]:
			assert_true(
				j.get("linear_limit_%s/enabled" % ax),
				"%s eje %s: límite lineal debe estar activo" % [j.name, ax]
			)
			assert_true(
				j.get("linear_limit_%s/upper_distance" % ax) <= 0.05,
				"%s eje %s: los huesos no deben poder separarse (efecto goma)" % [j.name, ax]
			)


func test_resorte_angular_de_brazos_amortiguado():
	var revisados: int = 0
	for j in ragdoll.find_children("*", "Generic6DOFJoint3D", true, false):
		if not ragdoll._es_joint_de_brazo(j.name):
			continue
		revisados += 1
		for ax in ["x", "y", "z"]:
			assert_gte(
				j.get("angular_spring_%s/damping" % ax),
				15.0,
				"%s eje %s: el resorte del brazo debe estar amortiguado" % [j.name, ax]
			)
	assert_gt(revisados, 0, "Debe existir al menos una articulación de brazo")


func test_huesos_de_brazos_con_damp_angular_extra():
	var revisados: int = 0
	for pb in _obtener_huesos():
		if not ragdoll._es_hueso_de_brazo(String(pb.bone_name)):
			continue
		revisados += 1
		assert_gte(pb.angular_damp, 5.0, "%s debe tener damp angular extra" % pb.name)
	assert_gt(revisados, 0, "Debe existir al menos un hueso de brazo")


# ═══════════════════════════════════════════════════════════════════════════════
# 5. Watchdog anti-estiramiento (divergencia de articulaciones)
# ═══════════════════════════════════════════════════════════════════════════════

func test_limites_watchdog_configurados_y_sanos():
	assert_gt(ragdoll.velocidad_maxima_hueso, 0.0, "velocidad_maxima_hueso debe ser positiva")
	assert_gt(ragdoll.radio_contencion_metros, 1.0, "radio_contencion_metros debe superar la envergadura del cuerpo (~0.55 m)")


func test_watchdog_limita_velocidad_extrema_de_huesos():
	ragdoll.activar_ragdoll(Vector3.ZERO)
	var hueso := _obtener_huesos()[0]
	hueso.linear_velocity = Vector3(500.0, 500.0, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(
		hueso.linear_velocity.length() <= ragdoll.velocidad_maxima_hueso + 0.01,
		"El watchdog debe limitar la velocidad del hueso a velocidad_maxima_hueso"
	)


func test_watchdog_contiene_huesos_fuera_del_radio():
	ragdoll.activar_ragdoll(Vector3.ZERO)
	var hueso := _obtener_huesos()[0]
	hueso.global_position = ragdoll.global_position + Vector3(50.0, 0.0, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_lt(
		hueso.global_position.distance_to(ragdoll.global_position),
		ragdoll.radio_contencion_metros + 0.1,
		"El watchdog debe devolver el hueso al radio de contencion"
	)


func test_obtener_centro_cadaver_cerca_del_origen_del_ragdoll():
	var centro: Vector3 = ragdoll.obtener_centro_cadaver()
	assert_lt(
		centro.distance_to(ragdoll.global_position),
		1.0,
		"El centro del cadaver debe quedar junto al ragdoll (escala metro)"
	)


func test_disolver_emite_particulas_en_ultima_posicion_del_cadaver():
	ragdoll.configurar_particulas_desaparicion(
		Color(0.4, 0.0, 0.5), 30, 1.0, Vector3(0.2, 0.5, 0.1), 20.0,
		0.1, 0.5, Vector3.ZERO, 3.0, 0.3, 0.005, 0.02
	)
	var centro_esperado: Vector3 = ragdoll.obtener_centro_cadaver()
	ragdoll._disolver(Color(0.4, 0.0, 0.5))
	await get_tree().process_frame

	var particulas := get_tree().root.find_child("ParticulasDisolucionExplosiva", true, false) as GPUParticles3D
	assert_not_null(particulas, "Al desaparecer el cadáver deben emitirse las partículas moradas")
	if particulas:
		assert_true(particulas.emitting, "Las partículas deben estar emitiendo")
		assert_lt(
			particulas.global_position.distance_to(centro_esperado + Vector3(0, 0.3, 0)),
			0.05,
			"Las partículas deben aparecer en la última posición del cadáver"
		)


# ═══════════════════════════════════════════════════════════════════════════════
# Helpers
# ═══════════════════════════════════════════════════════════════════════════════

func _capsula_de(pb: PhysicalBone3D) -> CapsuleShape3D:
	for hijo in pb.get_children():
		if hijo is CollisionShape3D and (hijo as CollisionShape3D).shape is CapsuleShape3D:
			return (hijo as CollisionShape3D).shape as CapsuleShape3D
	return null
