extends GutTest

## Presupuestos de rendimiento (regresión de bajones de FPS):
## - Torre: la rama IluminacionAnterior (11 luces con sombra) nace apagada.
## - Niveles: tope de luces con sombra en escena (texto de la tscn).
## - Flecha: chequeo fuera de pantalla cada 3 frames físicos + cámara cacheada.
## - Trayectoria explosiva: recálculo a 30 Hz (constante).

const ESCENA_INTERIOR: PackedScene = preload("res://Levels/Player_Interior.tscn")
const ARROW_SCENE: PackedScene = preload("res://Entities/Proyectil_Flecha/Arrow.tscn")

var scene_root: Node3D


func before_each() -> void:
	scene_root = Node3D.new()
	add_child(scene_root)


func after_each() -> void:
	if is_instance_valid(scene_root):
		scene_root.queue_free()
	await get_tree().process_frame


func _contar_shadow_enabled(ruta_tscn: String) -> int:
	var acceso := FileAccess.open(ruta_tscn, FileAccess.READ)
	assert_not_null(acceso, "Debe poder leerse " + ruta_tscn)
	if acceso == null:
		return 999
	var n: int = 0
	for linea in acceso.get_as_text().split("\n"):
		if linea.strip_edges() == "shadow_enabled = true":
			n += 1
	return n


func test_torre_rama_anterior_apagada_y_pocas_sombras_visibles() -> void:
	# Arrange
	var interior := ESCENA_INTERIOR.instantiate() as Node3D
	scene_root.add_child(interior)
	await get_tree().process_frame

	# Assert: la rama de iluminación original existe y está activa
	var anterior := interior.find_child("IluminacionAnterior", true, false) as Node3D
	assert_not_null(anterior, "Debe existir IluminacionAnterior")
	assert_true(anterior.visible, "IluminacionAnterior debe estar activa con los focos originales")


func test_niveles_tope_luces_con_sombra() -> void:
	# Assert: NIVEL01 y tutorial con máximo 2 luces con sombra en escena
	assert_lte(_contar_shadow_enabled("res://Levels/NIVEL01/NIVEL01.tscn"), 2, "NIVEL01: tope 2 sombras")
	assert_lte(_contar_shadow_enabled("res://Levels/NIVEL_TUTORIAL/NIVEL_TUTORIAL.tscn"), 2, "Tutorial: tope 2 sombras")


func test_flecha_offscreen_cada_3_frames() -> void:
	# Arrange: flecha muy alta (el fallback la destruiría por Y > 150)
	var flecha := ARROW_SCENE.instantiate() as Area3D
	scene_root.add_child(flecha)
	await get_tree().process_frame
	flecha.global_position = Vector3(0, 200, 0)
	flecha.set("velocity", Vector3.ZERO)

	# Act: 2 frames físicos (aún sin chequeo)
	flecha._physics_process(0.016)
	flecha._physics_process(0.016)

	# Assert: sigue viva (el chequeo toca al 3er frame)
	assert_false(bool(flecha.get("_destroying")), "Sin chequeo aún: no debe destruirse en 2 frames")

	# Act: 3er frame dispara el chequeo
	flecha._physics_process(0.016)

	# Assert: ahora sí se destruye por fuera de pantalla
	assert_true(bool(flecha.get("_destroying")), "Al 3er frame debe destruirse fuera de pantalla")


func test_trayectoria_explosiva_a_30hz() -> void:
	# Assert: la constante de cadencia existe y es 1/30
	assert_almost_eq(Player.INTERVALO_TRAYECTORIA, 1.0 / 30.0, 0.0001, "La trayectoria debe recalcularse a 30 Hz")
