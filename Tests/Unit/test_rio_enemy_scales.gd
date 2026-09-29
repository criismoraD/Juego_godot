extends GutTest

## Test unitario para verificar la escala equiparada de enemigos en el nivel Río
## (Submarino, Balsa Pirata y enemigos estáticos en el nivel) respecto a la canoa.

const ESCENA_GOBLIN_GIRL: PackedScene = preload("res://Entities/Enemigo_Goblin_Girl/GoblinGirl.tscn")
const ESCENA_PIRATA: PackedScene = preload("res://Entities/Enemigo_Pirata_Goblin/PirataGoblin.tscn")
const ESCENA_IMP: PackedScene = preload("res://Entities/Enemigo_Imp/ImpEnemy.tscn")
const ESCENA_IMP_ESTANDARTE: PackedScene = preload("res://Entities/Enemigo_Imp_Estandarte/ImpEnemyEstandarte.tscn")
const ESCENA_GOBLIN_GENERAL: PackedScene = preload("res://Entities/Enemigo_Goblin_General/GoblinGeneral.tscn")
const ESCENA_SUBMARINO_RIO: PackedScene = preload("res://Levels/Rio_En_Canoa_Con_Parallax/SubmarinoRio.tscn")
const ESCENA_CANOA_RIO: PackedScene = preload("res://Levels/Rio_En_Canoa_Con_Parallax/CanoaProtagonistaRio.tscn")


func test_submarino_aplica_escala_a_enemigos() -> void:
	# Arrange
	var submarino: SubmarinoRio = ESCENA_SUBMARINO_RIO.instantiate() as SubmarinoRio
	add_child_autofree(submarino)
	var gg: GoblinGirl = ESCENA_GOBLIN_GIRL.instantiate() as GoblinGirl
	var pirata: PirataGoblin = ESCENA_PIRATA.instantiate() as PirataGoblin
	var imp: ImpEnemy = ESCENA_IMP.instantiate() as ImpEnemy
	var estandarte: ImpEstandarte = ESCENA_IMP_ESTANDARTE.instantiate() as ImpEstandarte
	var general: GoblinGeneral = ESCENA_GOBLIN_GENERAL.instantiate() as GoblinGeneral
	add_child_autofree(gg)
	add_child_autofree(pirata)
	add_child_autofree(imp)
	add_child_autofree(estandarte)
	add_child_autofree(general)

	# Act
	submarino._aplicar_escala_enemigo_rio(gg)
	submarino._aplicar_escala_enemigo_rio(pirata)
	submarino._aplicar_escala_enemigo_rio(imp)
	submarino._aplicar_escala_enemigo_rio(estandarte)
	submarino._aplicar_escala_enemigo_rio(general)

	# Assert
	assert_almost_eq(gg.scale.x, 1.6, 0.15, "GoblinGirl debe escalar a ~1.6-1.7 en el submarino")
	assert_almost_eq(pirata.scale.x, 1.12, 0.05, "PirataGoblin debe escalar a ~1.12 en el submarino")
	assert_almost_eq(general.scale.x, 1.11, 0.05, "GoblinGeneral debe escalar a ~1.11 en el submarino")
	assert_almost_eq(imp.scale.x, 2.1, 0.05, "ImpEnemy debe escalar a ~2.1 en el submarino")
	assert_almost_eq(estandarte.scale.x, 2.1, 0.05, "ImpEstandarte debe escalar a ~2.1 en el submarino")


func test_balsa_aplica_escala_a_tripulacion() -> void:
	# Arrange
	var balsa: BalsaPirataCombate = BalsaPirataCombate.new()
	add_child_autofree(balsa)
	balsa.scale = Vector3(5.0, 4.286, 4.286)
	var gg: GoblinGirl = ESCENA_GOBLIN_GIRL.instantiate() as GoblinGirl
	autofree(gg)
	balsa._aplicar_escala_enemigo_rio(gg)
	balsa.add_child(gg)

	# Assert
	# La escala global debe aproximarse a 1.7
	var global_scale_y: float = gg.global_transform.basis.get_scale().y
	assert_almost_eq(global_scale_y, 1.7, 0.1, "La escala global Y de la arquera en balsa debe ser ~1.7")


func test_enemigos_equiparados_con_canoa() -> void:
	# Arrange: Canoa con Protagonista a escala 2.0 (como en nivel río)
	var canoa: CanoaProtagonistaRio = ESCENA_CANOA_RIO.instantiate() as CanoaProtagonistaRio
	add_child_autofree(canoa)
	canoa.scale = Vector3(2.0, 2.0, 2.0)

	var gg: GoblinGirl = ESCENA_GOBLIN_GIRL.instantiate() as GoblinGirl
	add_child_autofree(gg)
	gg.scale = Vector3(1.7, 1.7, 1.7)

	# Act
	var prota: Node3D = canoa.get_node("Protagonista") as Node3D
	var prota_mesh: MeshInstance3D = prota.find_child("Body", true, false) as MeshInstance3D
	if prota_mesh == null:
		var meshes = prota.find_children("*", "MeshInstance3D", true, false)
		if not meshes.is_empty():
			prota_mesh = meshes[0] as MeshInstance3D

	# Assert: Verificar que la GoblinGirl escalada está configurada en 1.7
	assert_almost_eq(gg.scale.x, 1.7, 0.05, "La escala de la GoblinGirl debe ser 1.7")
