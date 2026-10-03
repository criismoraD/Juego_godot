extends GutTest
## Tests unitarios para el golpe melee de ImperioGirlMelee.
##
## Verifica que _ejecutar_golpe_espada() daña exactamente UNA unidad
## por swing, aunque haya múltiples enemigos en alcance.

const ESCENA_IMPERIO: PackedScene = preload(
		"res://Entities/Defensora_ImperioGirl_Melee/ImperioGirlMelee.tscn")


## Stub mínimo de enemigo para contar cuántas veces recibe daño.
class EnemigoDummy extends Node3D:
	var health: int = 5
	var golpes_recibidos: int = 0

	func take_damage(amount: float) -> void:
		golpes_recibidos += 1
		health -= int(amount)


# ─────────────────────────────────────────────────────────────────────────────
# Happy Path
# ─────────────────────────────────────────────────────────────────────────────

func test_golpe_espada_daña_solo_un_enemigo_con_dos_en_alcance() -> void:
	# Arrange
	var imperio: ImperioGirlMelee = ESCENA_IMPERIO.instantiate()
	imperio.direccion_avance = 1.0
	imperio.alcance_melee = 3.0
	imperio.margen_z_melee = 2.0
	imperio.dano_cuerpo_a_cuerpo = 1
	add_child_autofree(imperio)
	await get_tree().process_frame

	var enemigo_a: EnemigoDummy = EnemigoDummy.new()
	enemigo_a.global_position = imperio.global_position + Vector3(0.5, 0.0, 0.0)
	add_child_autofree(enemigo_a)
	enemigo_a.add_to_group("enemies")

	var enemigo_b: EnemigoDummy = EnemigoDummy.new()
	enemigo_b.global_position = imperio.global_position + Vector3(1.0, 0.0, 0.0)
	add_child_autofree(enemigo_b)
	enemigo_b.add_to_group("enemies")

	# Act
	imperio._ejecutar_golpe_espada()

	# Assert — solo uno de los dos debe haber recibido daño
	var total_golpes: int = enemigo_a.golpes_recibidos + enemigo_b.golpes_recibidos
	assert_eq(total_golpes, 1,
		"El golpe espada debe dañar exactamente 1 unidad, no %d" % total_golpes)


func test_golpe_espada_daña_un_enemigo_con_uno_en_alcance() -> void:
	# Arrange
	var imperio: ImperioGirlMelee = ESCENA_IMPERIO.instantiate()
	imperio.direccion_avance = 1.0
	imperio.alcance_melee = 3.0
	imperio.margen_z_melee = 2.0
	imperio.dano_cuerpo_a_cuerpo = 1
	add_child_autofree(imperio)
	await get_tree().process_frame

	var enemigo: EnemigoDummy = EnemigoDummy.new()
	enemigo.global_position = imperio.global_position + Vector3(0.5, 0.0, 0.0)
	add_child_autofree(enemigo)
	enemigo.add_to_group("enemies")

	# Act
	imperio._ejecutar_golpe_espada()

	# Assert
	assert_eq(enemigo.golpes_recibidos, 1,
		"El enemigo en alcance debe recibir exactamente 1 golpe")


# ─────────────────────────────────────────────────────────────────────────────
# Edge Cases
# ─────────────────────────────────────────────────────────────────────────────

func test_golpe_espada_no_daña_con_cero_enemigos() -> void:
	# Arrange
	var imperio: ImperioGirlMelee = ESCENA_IMPERIO.instantiate()
	add_child_autofree(imperio)
	await get_tree().process_frame

	# Act / Assert — no debe arrojar error sin enemigos
	imperio._ejecutar_golpe_espada()
	pass


func test_golpe_espada_no_daña_enemigo_fuera_de_alcance() -> void:
	# Arrange
	var imperio: ImperioGirlMelee = ESCENA_IMPERIO.instantiate()
	imperio.direccion_avance = 1.0
	imperio.alcance_melee = 1.0
	add_child_autofree(imperio)
	await get_tree().process_frame

	var enemigo: EnemigoDummy = EnemigoDummy.new()
	# Posicionar MUY lejos fuera del alcance
	enemigo.global_position = imperio.global_position + Vector3(10.0, 0.0, 0.0)
	add_child_autofree(enemigo)
	enemigo.add_to_group("enemies")

	# Act
	imperio._ejecutar_golpe_espada()

	# Assert
	assert_eq(enemigo.golpes_recibidos, 0,
		"No debe dañar enemigo fuera del alcance melee")


func test_golpe_espada_no_daña_enemigo_muerto() -> void:
	# Arrange
	var imperio: ImperioGirlMelee = ESCENA_IMPERIO.instantiate()
	imperio.direccion_avance = 1.0
	imperio.alcance_melee = 3.0
	add_child_autofree(imperio)
	await get_tree().process_frame

	var enemigo: EnemigoDummy = EnemigoDummy.new()
	enemigo.health = 0  # Ya muerto
	enemigo.global_position = imperio.global_position + Vector3(0.5, 0.0, 0.0)
	add_child_autofree(enemigo)
	enemigo.add_to_group("enemies")

	# Act
	imperio._ejecutar_golpe_espada()

	# Assert
	assert_eq(enemigo.golpes_recibidos, 0,
		"No debe dañar un enemigo con health <= 0")
