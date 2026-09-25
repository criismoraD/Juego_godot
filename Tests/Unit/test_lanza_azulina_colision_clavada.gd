extends GutTest

## Regresión: las lanzas de Azulina clavadas no deben bloquear proyectiles.
## - Al clavarse/destruirse se desactivan sus CollisionShape3D (invisibles a
##   rayos CCD y señales) y se reactivan al salir del pool.
## - El CCD de la flecha ignora proyectiles (vivos o clavados) y los atraviesa.

const LANZA_SCENE: PackedScene = preload("res://Entities/Proyectil_Lanza_Azulina/LanzaAzulinaProjectile.tscn")
const ARROW_SCENE: PackedScene = preload("res://Entities/Proyectil_Flecha/Arrow.tscn")

var scene_root: Node3D


func before_each() -> void:
	scene_root = Node3D.new()
	add_child(scene_root)


func after_each() -> void:
	if is_instance_valid(scene_root):
		scene_root.queue_free()
	await get_tree().process_frame


func test_lanza_clavada_desactiva_y_reactiva_colisiones() -> void:
	# Arrange
	var lanza := LANZA_SCENE.instantiate() as Area3D
	lanza.position = Vector3(5, 1, 0)
	scene_root.add_child(lanza)
	await get_tree().process_frame
	var forma := lanza.find_child("CollisionShape3D", true, false) as CollisionShape3D
	assert_not_null(forma, "La lanza debe tener CollisionShape3D")
	assert_false(forma.disabled, "Precondición: forma activa en vuelo")

	# Act: clavarse
	lanza._marcar_como_pegado()
	await get_tree().process_frame
	await get_tree().process_frame

	# Assert: inerte a colisiones pero visible
	assert_true(lanza.get("is_stuck"), "Debe marcarse clavada")
	assert_false(lanza.get("monitoring"), "Clavada: sin monitoring")
	assert_false(lanza.get("monitorable"), "Clavada: sin monitorable")
	assert_true(forma.disabled, "Clavada: forma desactivada para no bloquear proyectiles")

	# Act: volver a vuelo (salida del pool)
	lanza._activar_desde_pool()
	await get_tree().process_frame

	# Assert: colisiones restauradas
	assert_false(forma.disabled, "Al reactivar: forma activa de nuevo")


func test_flecha_atraviesa_lanza_clavada() -> void:
	# Arrange: lanza clavada en la trayectoria (x=5, y=1, z=0)
	var lanza := LANZA_SCENE.instantiate() as Area3D
	lanza.position = Vector3(5, 1, 0)
	scene_root.add_child(lanza)
	await get_tree().process_frame
	lanza._marcar_como_pegado()
	await get_tree().process_frame
	await get_tree().process_frame

	var flecha := ARROW_SCENE.instantiate() as Area3D
	scene_root.add_child(flecha)
	await get_tree().process_frame
	flecha.set("escala_gravedad", 0.0)
	flecha.global_position = Vector3(0, 1, 0)
	flecha.initialize(Vector3.RIGHT, 12.0)

	# Act: volar 0.6 s (~7 m, atraviesa x=5)
	await wait_seconds(0.6)

	# Assert: no se clava ni se frena en la lanza
	assert_false(flecha.get("is_stuck"), "La flecha no debe clavarse en la lanza clavada")
	assert_gt(flecha.global_position.x, 5.5, "La flecha debe superar la lanza clavada, x=%.2f" % flecha.global_position.x)
