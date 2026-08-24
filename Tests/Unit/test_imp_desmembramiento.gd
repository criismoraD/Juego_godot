extends "res://addons/gut/test.gd"

const IMP_SCENE: PackedScene = preload("res://Entities/Enemigo_Imp/ImpEnemy.tscn")

var imp: ImpEnemy = null


func before_each():
	imp = IMP_SCENE.instantiate()
	add_child(imp)
	await get_tree().process_frame


func after_each():
	if is_instance_valid(imp) and not imp.is_queued_for_deletion():
		imp.free()
	imp = null


# ═══════════════════════════════════════════════════════════════════════════════
# 1. Flag de muerte explosiva
# ═══════════════════════════════════════════════════════════════════════════════

func test_flag_desmembramiento_existe_y_arranca_falso():
	assert_false(imp.murio_por_explosion, "murio_por_explosion debe iniciar en false")


func test_piezas_ocultas_presentes_en_escena():
	var ragdoll: Node3D = imp.get_node_or_null("RagdollImp")
	var cabeza: Node3D = imp.get_node_or_null("CabezaImp")
	assert_not_null(ragdoll, "RagdollImp debe existir en ImpEnemy.tscn")
	assert_not_null(cabeza, "CabezaImp debe existir en ImpEnemy.tscn")
	if ragdoll:
		assert_false(ragdoll.visible, "RagdollImp debe iniciar oculto")
	if cabeza:
		assert_false(cabeza.visible, "CabezaImp debe iniciar oculta")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. Desmembramiento por explosión
# ═══════════════════════════════════════════════════════════════════════════════

func test_muerte_explosiva_genera_ragdoll_activo():
	imp.murio_por_explosion = true
	imp.call("_on_state_dying")
	await get_tree().process_frame
	await get_tree().process_frame

	var ragdolls := get_tree().root.find_children("*", "ImpCuerpoRagdoll", true, false)
	assert_gt(ragdolls.size(), 0, "Debe existir un ImpCuerpoRagdoll en la escena")
	if ragdolls.size() > 0:
		var ragdoll: ImpCuerpoRagdoll = ragdolls[0] as ImpCuerpoRagdoll
		assert_true(ragdoll.visible, "El ragdoll debe ser visible tras el desmembramiento")
		assert_true(ragdoll.is_ragdoll_active, "El ragdoll debe estar simulando")


func test_muerte_explosiva_dispara_cabeza_fisica():
	imp.murio_por_explosion = true
	imp.call("_on_state_dying")
	await get_tree().process_frame
	await get_tree().process_frame

	var piezas := get_tree().root.find_children("*", "ImpPiezaFisica", true, false)
	assert_gt(piezas.size(), 0, "Debe existir un contenedor ImpPiezaFisica para la cabeza")
	if piezas.size() > 0:
		var cabeza_mesh := piezas[0].find_children("*", "MeshInstance3D", true, false)
		assert_gt(cabeza_mesh.size(), 0, "El contenedor debe tener la malla de la cabeza visible")


func test_muerte_explosiva_libera_al_imp():
	imp.murio_por_explosion = true
	imp.call("_on_state_dying")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(imp.is_queued_for_deletion(), "El Imp debe liberarse tras el desmembramiento")


func test_muerte_explosiva_genera_sangre_animada_igual_que_goblin():
	var sprites_antes := get_tree().root.find_children("*", "Sprite3D", true, false).size()

	imp.murio_por_explosion = true
	imp.call("_on_state_dying")
	await get_tree().process_frame
	await get_tree().process_frame

	var sprites := get_tree().root.find_children("*", "Sprite3D", true, false)
	assert_gt(sprites.size(), sprites_antes, "Debe spawnear el sprite de sangre animada al explotar")

	var sangre: Sprite3D = null
	for s in sprites:
		var sprite := s as Sprite3D
		if sprite and sprite.vframes == 14:
			sangre = sprite
			break
	assert_not_null(sangre, "Debe existir un Sprite3D de sangre con los mismos 14 cuadros verticales que el Goblin")
	if sangre:
		assert_eq(sangre.hframes, 1, "La sangre debe tener 1 columna como el efecto del Goblin")
		assert_true(sangre.billboard == BaseMaterial3D.BILLBOARD_ENABLED, "La sangre debe mirar a la cámara")


func test_muerte_explosiva_difiere_particulas_hasta_desaparicion_del_cadaver():
	imp.murio_por_explosion = true
	imp.call("_on_state_dying")
	await get_tree().process_frame
	await get_tree().process_frame

	# Las partículas deben esperar a que el cadáver (ragdoll) desaparezca,
	# no aparecer en el instante de la explosión.
	assert_null(
		get_tree().root.find_child("ParticulasDisolucionExplosiva", true, false),
		"Las partículas NO deben aparecer al instante de la explosión"
	)

	# Emisión directa: mismo efecto que se disparará al desaparecer el cadáver
	imp._spawn_particulas_disolucion_explosiva(imp.global_position)
	await get_tree().process_frame

	var particulas := get_tree().root.find_child("ParticulasDisolucionExplosiva", true, false) as GPUParticles3D
	assert_not_null(particulas, "Debe spawnear el efecto de partículas de disolución al explotar")
	if particulas:
		assert_true(particulas.emitting, "Las partículas moradas deben estar emitiendo al explotar")
		var mesh := particulas.draw_pass_1 as SphereMesh
		assert_not_null(mesh, "El draw pass debe ser la esfera de partículas de disolución")
		if mesh:
			var mat := mesh.material as StandardMaterial3D
			assert_not_null(mat, "La esfera debe tener material emisivo")
			if mat:
				assert_eq(mat.emission, Color(0.4, 0.0, 0.5), "Las partículas deben ser moradas como en la muerte normal")


func test_muerte_normal_NO_desmemra():
	imp.call("_on_state_dying")
	await get_tree().process_frame
	var piezas := get_tree().root.find_children("*", "ImpPiezaFisica", true, false)
	assert_eq(piezas.size(), 0, "Muerte normal no debe generar piezas fisicas")
	assert_false(imp.is_queued_for_deletion(), "Muerte normal no debe liberar al instante")
