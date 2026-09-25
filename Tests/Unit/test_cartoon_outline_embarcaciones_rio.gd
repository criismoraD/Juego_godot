extends "res://addons/gut/test.gd"

## Tests unitarios para verificar la línea 2D cartoon (TOON_LINEANEGRA)
## en Submarino, Barco de Combate Pirata, Mina Acuática y Misil Submarino,
## así como el comportamiento de idle del Imp Embajador en la cubierta.

const SUBMARINO_SCENE: PackedScene = preload("res://Levels/Rio_En_Canoa_Con_Parallax/SubmarinoRio.tscn")
const BARCO_SCENE: PackedScene = preload("res://Entities/Ambiente_Barco_Combate_Pirata/BarcoCombatePirata.tscn")
const MINA_SCENE: PackedScene = preload("res://Entities/Proyectil_Mina_Acuatica/MinaAcuatica.tscn")
const MISIL_SCENE: PackedScene = preload("res://Entities/Proyectil_Misil_Submarino/MisilSubmarino.tscn")
const IMP_ESTANDARTE_SCENE: PackedScene = preload("res://Entities/Enemigo_Imp_Estandarte/ImpEnemyEstandarte.tscn")

const MAT_SUBMARINO: StandardMaterial3D = preload("res://Levels/Rio_En_Canoa_Con_Parallax/Submarino_Mat.tres")
const MAT_BARCO: StandardMaterial3D = preload("res://Entities/Ambiente_Barco_Combate_Pirata/MAT_BARCO_COMBATE_PIRATA.tres")
const MAT_MINA: StandardMaterial3D = preload("res://Entities/Proyectil_Mina_Acuatica/MinaAcuatica_Mat.tres")
const MAT_MISIL: StandardMaterial3D = preload("res://Entities/Proyectil_Misil_Submarino/MisilSubmarino_Mat.tres")
const SHADER_TOON: Shader = preload("res://System/Shaders/TOON_LINEANEGRA.gdshader")


func before_each() -> void:
	ShaderGlobals.asegurar_outline_global(true)
	ShaderGlobals.asegurar_outline_proyectiles(true)


# -----------------------------------------------------------------------------
# Submarino
# -----------------------------------------------------------------------------

func test_submarino_material_tiene_outline_cartoon() -> void:
	# Arrange & Act
	var mat := MAT_SUBMARINO as StandardMaterial3D

	# Assert
	assert_not_null(mat, "Submarino_Mat debe existir")
	assert_not_null(mat.next_pass, "Submarino_Mat debe tener next_pass de outline")
	assert_is(mat.next_pass, ShaderMaterial, "next_pass debe ser ShaderMaterial")
	var sm := mat.next_pass as ShaderMaterial
	assert_eq(sm.shader, SHADER_TOON, "El shader de contorno debe ser TOON_LINEANEGRA")


func test_submarino_registra_mallas_en_outline_meshes() -> void:
	# Arrange & Act
	var sub := SUBMARINO_SCENE.instantiate() as SubmarinoRio
	add_child_autofree(sub)
	await get_tree().process_frame

	# Assert
	var mallas_en_grupo: int = 0
	for child in sub.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi.is_in_group("outline_meshes"):
			mallas_en_grupo += 1

	assert_gt(mallas_en_grupo, 0, "Las mallas del submarino deben estar en el grupo outline_meshes")


# -----------------------------------------------------------------------------
# Barco Combate Pirata
# -----------------------------------------------------------------------------

func test_barco_combate_material_tiene_outline_cartoon() -> void:
	# Arrange & Act
	var mat := MAT_BARCO as StandardMaterial3D

	# Assert
	assert_not_null(mat, "MAT_BARCO_COMBATE_PIRATA debe existir")
	assert_not_null(mat.next_pass, "MAT_BARCO_COMBATE_PIRATA debe tener next_pass")
	assert_is(mat.next_pass, ShaderMaterial, "next_pass debe ser ShaderMaterial")
	var sm := mat.next_pass as ShaderMaterial
	assert_eq(sm.shader, SHADER_TOON, "El shader debe ser TOON_LINEANEGRA")


func test_barco_combate_registra_mallas_en_outline_meshes() -> void:
	# Arrange & Act
	var barco := BARCO_SCENE.instantiate() as BarcoCombatePirata
	add_child_autofree(barco)
	await get_tree().process_frame

	# Assert
	var mallas_en_grupo: int = 0
	for child in barco.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi.is_in_group("outline_meshes"):
			mallas_en_grupo += 1

	assert_gt(mallas_en_grupo, 0, "Las mallas del barco deben estar en el grupo outline_meshes")


# -----------------------------------------------------------------------------
# Mina y Misil Submarino
# -----------------------------------------------------------------------------

func test_mina_acuatica_material_tiene_outline_cartoon() -> void:
	# Arrange & Act
	var mat := MAT_MINA as StandardMaterial3D

	# Assert
	assert_not_null(mat, "MinaAcuatica_Mat debe existir")
	assert_not_null(mat.next_pass, "MinaAcuatica_Mat debe tener next_pass")
	var sm := mat.next_pass as ShaderMaterial
	assert_eq(sm.shader, SHADER_TOON, "Shader de contorno base debe ser TOON_LINEANEGRA")


func test_misil_submarino_material_tiene_outline_cartoon() -> void:
	# Arrange & Act
	var mat := MAT_MISIL as StandardMaterial3D

	# Assert
	assert_not_null(mat, "MisilSubmarino_Mat debe existir")
	assert_not_null(mat.next_pass, "MisilSubmarino_Mat debe tener next_pass")
	var sm := mat.next_pass as ShaderMaterial
	assert_eq(sm.shader, SHADER_TOON, "Shader de contorno base debe ser TOON_LINEANEGRA")


# -----------------------------------------------------------------------------
# Imp Estandarte en Submarino (Idle sostener estandarte)
# -----------------------------------------------------------------------------

func test_imp_estandarte_al_detenerse_en_submarino_entra_en_idle_sostener() -> void:
	# Arrange
	var sub := SUBMARINO_SCENE.instantiate() as SubmarinoRio
	add_child_autofree(sub)
	var imp := IMP_ESTANDARTE_SCENE.instantiate() as ImpEstandarte
	imp.set("pasivo_hasta_ser_atacado", true)
	add_child_autofree(imp)
	await get_tree().process_frame

	# Act 1: Detener caminata al llegar a la posición asignada en cubierta
	sub.call("_detener_animacion_caminata", imp)

	# Assert 1: Debe reproducir IMP_IDLE_001 (idle de sostener estandarte)
	assert_not_null(imp.anim_player)
	assert_eq(imp.anim_player.current_animation, "IMP_IDLE_001",
		"Al posicionarse en cubierta debe estar en 'IMP_IDLE_001'")

	# Act 2: Submarino intenta iniciar el combate de la unidad
	sub.call("_iniciar_combate_enemigo", imp)

	# Assert 2: Al ser pasivo_hasta_ser_atacado, debe mantener IMP_IDLE_001 y no volver a caminar
	assert_eq(imp.anim_player.current_animation, "IMP_IDLE_001",
		"Debe conservar 'IMP_IDLE_001' sosteniendo el estandarte hasta ser atacado")
