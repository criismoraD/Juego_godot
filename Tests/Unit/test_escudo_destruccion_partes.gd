extends "res://addons/gut/test.gd"

## Regresión: al romperse, el escudo del jugador debe generar la animación de
## destrucción en partes (EscudoRoto con trozos RigidBody3D físicos).
## Estructura AAA (Arrange, Act, Assert) siguiendo las directrices de AGENTS.md.

const ESCUDO_SCENE := preload("res://Entities/Ambiente_Escudo/Escudo.tscn")


func _limpiar_rotos() -> void:
	for roto in get_tree().get_nodes_in_group("escudos_rotos"):
		if is_instance_valid(roto):
			roto.queue_free()
	await get_tree().process_frame


func test_destruccion_genera_partes_rigidbody() -> void:
	# Arrange
	_limpiar_rotos()
	var escudo = ESCUDO_SCENE.instantiate()
	add_child_autofree(escudo)
	await get_tree().process_frame
	escudo.golpes_para_destruir = 3

	# Act: tres golpes secuenciales con espera del flash entre ellos
	escudo.recibir_golpe(1)
	await wait_seconds(0.4)
	escudo.recibir_golpe(1)
	await wait_seconds(0.4)
	escudo.recibir_golpe(1)
	await wait_seconds(0.6)

	# Assert: el escudo original desaparece y nace un EscudoRoto con trozos físicos
	assert_false(is_instance_valid(escudo), "El escudo intacto debe liberarse al destruirse")
	var rotos := get_tree().get_nodes_in_group("escudos_rotos")
	assert_gt(rotos.size(), 0, "Debe instanciarse el EscudoRoto al romperse el escudo")
	var total_rbs: int = 0
	for roto in rotos:
		if is_instance_valid(roto) and roto.get("_rigid_bodies") != null:
			for rb in (roto.get("_rigid_bodies") as Array):
				if is_instance_valid(rb) and rb is RigidBody3D:
					total_rbs += 1
		roto.queue_free()
	await get_tree().process_frame
	assert_gt(total_rbs, 0, "El EscudoRoto debe convertir sus mallas en trozos RigidBody3D")


func test_doble_golpe_final_solo_un_escudo_roto() -> void:
	# Arrange
	_limpiar_rotos()
	var escudo = ESCUDO_SCENE.instantiate()
	add_child_autofree(escudo)
	await get_tree().process_frame
	escudo.golpes_para_destruir = 2

	# Act: dos golpes finales el mismo frame (carrera del await del flash)
	escudo.recibir_golpe(1)
	escudo.recibir_golpe(1)
	await wait_seconds(0.6)

	# Assert: la destrucción es idempotente (un solo EscudoRoto, sin duplicar partes/sonido)
	var rotos := get_tree().get_nodes_in_group("escudos_rotos")
	var vivos: int = 0
	for roto in rotos:
		if is_instance_valid(roto):
			vivos += 1
			roto.queue_free()
	await get_tree().process_frame
	assert_eq(vivos, 1, "Golpes finales simultáneos deben generar un solo EscudoRoto")
