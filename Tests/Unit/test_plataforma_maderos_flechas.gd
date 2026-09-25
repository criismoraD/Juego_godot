extends GutTest

## PlataformaMaderos del río: se pisa pero las flechas (jugadora, aliadas
## y enemigas) la atraviesan sin clavarse ni destruirse.

const ARROW_SCENE: PackedScene = preload("res://Entities/Proyectil_Flecha/Arrow.tscn")
const PLATAFORMA_SCENE: PackedScene = preload("res://Levels/Rio_En_Canoa_Con_Parallax/PlataformaMaderos.tscn")

var scene_root: Node3D


func before_each() -> void:
	scene_root = Node3D.new()
	add_child(scene_root)


func after_each() -> void:
	if is_instance_valid(scene_root):
		scene_root.queue_free()
	await get_tree().process_frame


func _crear_plataforma() -> Node3D:
	var plat := PLATAFORMA_SCENE.instantiate() as Node3D
	scene_root.add_child(plat)
	return plat


func _crear_flecha() -> ArrowProjectile:
	var flecha := ARROW_SCENE.instantiate() as ArrowProjectile
	scene_root.add_child(flecha)
	return flecha


func test_helper_detecta_plataforma_y_suelo_hijo() -> void:
	# Arrange
	var plat := _crear_plataforma()
	await get_tree().process_frame
	var flecha := _crear_flecha()
	var suelo := plat.find_child("SueloPlataforma", true, false)
	var otro := StaticBody3D.new()
	scene_root.add_child(otro)

	# Assert
	assert_not_null(suelo, "La escena debe traer SueloPlataforma")
	assert_true(flecha._es_plataforma_atravesable_por_flechas(plat), "La plataforma cuenta")
	assert_true(flecha._es_plataforma_atravesable_por_flechas(suelo), "El suelo hijo cuenta")
	assert_false(flecha._es_plataforma_atravesable_por_flechas(otro), "Otro cuerpo no cuenta")
	assert_false(flecha._es_plataforma_atravesable_por_flechas(null), "Nulo no cuenta")


func test_flecha_jugadora_atraviesa_sin_clavarse() -> void:
	# Arrange
	var plat := _crear_plataforma()
	await get_tree().process_frame
	var flecha := _crear_flecha()
	await get_tree().process_frame
	var suelo := plat.find_child("SueloPlataforma", true, false)

	# Act: impacto directo contra el suelo de tablones
	flecha._on_body_entered(suelo)

	# Assert: la atraviesa (ni clavada ni destruida)
	assert_false(bool(flecha.get("is_stuck")), "No debe clavarse en los tablones")
	assert_false(bool(flecha.get("_destroying")), "No debe destruirse en los tablones")


func test_proyectil_enemigo_atraviesa_sin_clavarse() -> void:
	# Arrange: proyectil base enemigo + plataforma real
	var proy := EnemyProjectileBase.new()
	scene_root.add_child(proy)
	await get_tree().process_frame
	var plat := _crear_plataforma()
	await get_tree().process_frame
	var suelo := plat.find_child("SueloPlataforma", true, false)

	# Act
	proy._on_body_entered(suelo)

	# Assert
	assert_false(bool(proy.get("is_stuck")), "El proyectil enemigo no debe clavarse en los tablones")
