extends "res://addons/gut/test.gd"

## Tests de la Aliada Arquera contra el enemigo vehiculo Globo Aerostatico:
## - Adquisicion de objetivo (delante/detras/muriendo)
## - Decision de disparo: munición NORMAL con apuntado directo (como la gárgola)
## - El globo cuenta como enemigo vivo para la activacion de la aliada
## - El disparo real se eleva hacia el globo (vehiculo a 3.3-5.2 m de altura)

const ALLY_SCENE := preload("res://Entities/Aliada_Arquera/AllyArcher.tscn")
const GLOBO_SCENE := preload("res://Entities/Enemigo_GloboAerostatico/GloboAerostatico.tscn")

var ally: AllyArcher = null
var globo: GloboAerostatico = null


func before_each():
	EnemyBase.active_enemies_cache.clear()
	ally = ALLY_SCENE.instantiate() as AllyArcher
	add_child_autofree(ally)
	ally.global_position = Vector3(-5.0, 0.0, 0.0)
	await get_tree().process_frame


func after_each():
	if is_instance_valid(globo):
		EnemyBase.active_enemies_cache.erase(globo)
	globo = null
	EnemyBase.active_enemies_cache.clear()


func _spawnar_globo(pos: Vector3) -> void:
	globo = GLOBO_SCENE.instantiate() as GloboAerostatico
	add_child_autofree(globo)
	globo.global_position = pos
	EnemyBase.active_enemies_cache.append(globo)
	await get_tree().process_frame


func test_sin_globos_no_hay_objetivo():
	assert_null(ally._obtener_globo_objetivo(), "Sin globos no debe adquirir objetivo globo")


func test_globo_delante_es_adquirido():
	# Arrange
	await _spawnar_globo(Vector3(0.0, 4.3, 0.0))

	# Act & Assert
	assert_eq(ally._obtener_globo_objetivo(), globo, "El globo delante debe ser adquirido como objetivo")


func test_globo_detras_no_es_adquirido():
	# Arrange
	await _spawnar_globo(Vector3(-6.0, 4.3, 0.0))

	# Act & Assert
	assert_null(ally._obtener_globo_objetivo(), "Globos detras de la arquera no deben adquirirse")


func test_globo_muriendo_no_es_adquirido():
	# Arrange
	await _spawnar_globo(Vector3(0.0, 4.3, 0.0))
	globo.current_state = EnemyBase.State.DYING

	# Act & Assert
	assert_null(ally._obtener_globo_objetivo(), "Globos muriendo no deben adquirirse")


func test_decision_normal_apunta_al_globo():
	# Arrange: globo delante, sin Lonko ni gargola en pantalla
	await _spawnar_globo(Vector3(0.0, 4.3, 0.0))

	# Act
	var decision: Dictionary = ally._decidir_disparo_y_objetivo()

	# Assert: enemigo volador -> munición normal con apuntado directo
	assert_eq(decision.get("target"), globo, "La decision debe apuntar al globo")
	assert_eq(decision.get("type"), AllyArcher.TipoDisparoAliada.NORMAL, "Contra el globo debe usar munición normal")


func test_globo_cuenta_como_enemigo_para_activarse():
	# Arrange: solo el globo en pantalla
	await _spawnar_globo(Vector3(0.0, 4.3, 0.0))

	# Act & Assert
	assert_eq(ally._contar_enemigos_vivos(), 1, "El globo debe contar como enemigo vivo para la activacion")


func test_globo_mas_cercano_gana_sobre_otro():
	# Arrange: dos globos delante a distinta distancia
	await _spawnar_globo(Vector3(5.0, 4.3, 0.0))
	var globo_lejos: GloboAerostatico = GLOBO_SCENE.instantiate() as GloboAerostatico
	add_child_autofree(globo_lejos)
	globo_lejos.global_position = Vector3(12.0, 5.2, 0.0)
	EnemyBase.active_enemies_cache.append(globo_lejos)
	await get_tree().process_frame

	# Act & Assert
	assert_eq(ally._obtener_globo_objetivo(), globo, "Debe adquirirse el globo mas cercano")
	EnemyBase.active_enemies_cache.erase(globo_lejos)


func test_disparo_se_eleva_hacia_globo():
	# Arrange: globo volando alto delante avanzando; carga maxima
	await _spawnar_globo(Vector3(0.0, 4.3, 0.0))
	globo.velocity = Vector3(-1.0, 0.0, 0.0)

	var flechas_antes := get_tree().root.find_children("*", "ArrowProjectile", true, false).size()
	ally.charge_duration = ally.tiempo_carga_max

	# Act
	ally._disparar()
	await get_tree().process_frame

	# Assert: la flecha nueva sale con componente vertical positiva (apuntando
	# hacia arriba para alcanzar al globo en altura)
	var flechas := get_tree().root.find_children("*", "ArrowProjectile", true, false)
	assert_gt(flechas.size(), flechas_antes, "Debe dispararse una flecha hacia el globo")
	if flechas.size() > flechas_antes:
		var flecha := flechas[flechas.size() - 1] as Node3D
		var vel = flecha.get("velocity")
		if vel is Vector3:
			assert_gt(vel.y, 0.0, "La flecha debe ir elevada hacia el globo")
			assert_gt(vel.x, 0.0, "La flecha debe avanzar hacia la derecha")