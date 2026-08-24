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
	assert_true(imp.is_queued_for_deletion(), "El Imp debe liberarse tras el desmembramiento")


func test_muerte_normal_NO_desmemra():
	imp.call("_on_state_dying")
	await get_tree().process_frame
	var piezas := get_tree().root.find_children("*", "ImpPiezaFisica", true, false)
	assert_eq(piezas.size(), 0, "Muerte normal no debe generar piezas fisicas")
	assert_false(imp.is_queued_for_deletion(), "Muerte normal no debe liberar al instante")
