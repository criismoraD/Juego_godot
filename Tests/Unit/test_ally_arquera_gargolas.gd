extends "res://addons/gut/test.gd"

const ALLY_SCENE := preload("res://Entities/Aliada_Arquera/AllyArcher.tscn")
const GARGOLA_SCENE := preload("res://Entities/Enemigo_Gargola/Gargola.tscn")

var ally: AllyArcher = null
var gargola: Gargola = null


func before_each():
	EnemyBase.active_enemies_cache.clear()
	ally = ALLY_SCENE.instantiate() as AllyArcher
	add_child_autofree(ally)
	ally.global_position = Vector3(-5.0, 0.0, 0.0)
	await get_tree().process_frame


func after_each():
	if is_instance_valid(gargola):
		EnemyBase.active_enemies_cache.erase(gargola)
	gargola = null
	EnemyBase.active_enemies_cache.clear()


func test_sin_gargolas_no_hay_objetivo():
	assert_null(ally._obtener_gargola_objetivo(), "Sin gárgolas no debe adquirir objetivo")


func test_rig_tiene_hueso_spine_para_apuntado():
	# La arquera usa el mismo rig que la protagonista: debe encontrar el hueso
	# del torso para inclinarse al apuntar hacia arriba.
	assert_gt(ally._spine_bone_idx, -1, "El rig debe tener el hueso Spine para el apuntado visual")


func test_gargola_delante_es_adquirida():
	# Arrange
	gargola = GARGOLA_SCENE.instantiate() as Gargola
	add_child_autofree(gargola)
	gargola.global_position = Vector3(0.0, 4.0, 0.0)
	EnemyBase.active_enemies_cache.append(gargola)
	await get_tree().process_frame

	# Act & Assert
	assert_eq(
		ally._obtener_gargola_objetivo(), gargola,
		"La gárgola voladora delante debe ser adquirida como objetivo"
	)


func test_gargola_detras_no_es_adquirida():
	# Arrange
	gargola = GARGOLA_SCENE.instantiate() as Gargola
	add_child_autofree(gargola)
	gargola.global_position = Vector3(-6.0, 4.0, 0.0)
	EnemyBase.active_enemies_cache.append(gargola)
	await get_tree().process_frame

	# Act & Assert
	assert_null(ally._obtener_gargola_objetivo(), "Gárgolas detrás de la arquera no deben adquirirse")


func test_gargola_muerta_no_es_adquirida():
	# Arrange
	gargola = GARGOLA_SCENE.instantiate() as Gargola
	add_child_autofree(gargola)
	gargola.global_position = Vector3(0.0, 4.0, 0.0)
	EnemyBase.active_enemies_cache.append(gargola)
	await get_tree().process_frame
	gargola.current_state = EnemyBase.State.DYING

	# Act & Assert
	assert_null(ally._obtener_gargola_objetivo(), "Gárgolas muriendo no deben adquirirse")


func test_disparo_se_eleva_hacia_gargola_alta():
	# Arrange: gárgola volando alta delante; carga máxima (velocidad 12)
	gargola = GARGOLA_SCENE.instantiate() as Gargola
	add_child_autofree(gargola)
	gargola.global_position = Vector3(0.0, 4.5, 0.0)
	gargola.velocity = Vector3(-1.0, 0.0, 0.0)
	EnemyBase.active_enemies_cache.append(gargola)
	await get_tree().process_frame

	var flechas_antes := get_tree().root.find_children("*", "ArrowProjectile", true, false).size()
	ally.charge_duration = ally.tiempo_carga_max

	# Act
	ally._disparar()
	await get_tree().process_frame

	# Assert: la flecha nueva sale con componente vertical positiva (apuntando
	# hacia arriba para alcanzar a la gárgola en altura)
	var flechas := get_tree().root.find_children("*", "ArrowProjectile", true, false)
	assert_gt(flechas.size(), flechas_antes, "Debe dispararse una flecha")
	if flechas.size() > flechas_antes:
		var flecha := flechas[flechas.size() - 1] as Node3D
		var vel = flecha.get("velocity")
		if vel is Vector3:
			assert_gt(vel.y, 0.0, "La flecha debe ir elevada hacia la gárgola")
			assert_gt(vel.x, 0.0, "La flecha debe avanzar hacia la derecha")
