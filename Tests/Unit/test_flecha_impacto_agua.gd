extends "res://addons/gut/test.gd"

## Tests del chapoteo pequeño al impactar flechas en el agua (efecto TomAzod
## en versión contenida: solo ondas + burbujas a escala 0.3).

var ArrowScene = load("res://Entities/Proyectil_Flecha/Arrow.tscn")

var _arrow: Area3D = null
var _agua: Node3D = null


func after_each():
	if is_instance_valid(_arrow):
		_arrow.free()
	_arrow = null
	if is_instance_valid(_agua):
		_agua.free()
	_agua = null
	for n in get_tree().root.get_children():
		if is_instance_valid(n) and n.has_method("play_splash"):
			n.free()


func _crear_agua_ancha() -> Node3D:
	_agua = Node3D.new()
	_agua.name = "AguaTest"
	_agua.add_to_group("agua")
	get_tree().root.add_child(_agua)
	_agua.global_position = Vector3.ZERO
	var mi := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(60, 60)
	mi.mesh = plano
	_agua.add_child(mi)
	return _agua


func test_flecha_en_agua_genera_mini_splash_y_se_destruye() -> void:
	# Arrange: agua ancha en y=0 y flecha cayendo en picada
	_crear_agua_ancha()
	_arrow = ArrowScene.instantiate()
	get_tree().root.add_child(_arrow)
	_arrow.global_position = Vector3(0, 3, 0)
	_arrow.velocity = Vector3(0, -12, 0)

	# Act: pasos de física hasta cruzar la superficie
	for i in range(30):
		if not is_instance_valid(_arrow) or _arrow._destroying:
			break
		_arrow._physics_process(0.016)
		await get_tree().physics_frame

	# Assert: chapoteo contenido y flecha terminada
	var splash: Node = null
	for n in get_tree().root.get_children():
		if is_instance_valid(n) and n.has_method("play_splash"):
			splash = n
			break
	assert_not_null(splash, "Debe generar el mini chapoteo al impactar en agua")
	assert_true(_arrow._destroying or not is_instance_valid(_arrow), "La flecha termina en el agua")
	if splash:
		assert_almost_eq(splash.scale.x, 0.3, 0.01, "Versión pequeña (escala 0.3)")
		var capas: Array = splash.get("vfx_layers")
		if capas.size() >= 6:
			assert_true((capas[1] as Node3D).visible, "Ondas visibles")
			assert_true((capas[2] as Node3D).visible, "Burbujas visibles")
			assert_false((capas[4] as Node3D).visible, "Pilar oculto en la versión contenida")


func test_flecha_fuera_del_agua_no_chapotea() -> void:
	# Arrange: sin agua en el grupo (niveles secos)
	_arrow = ArrowScene.instantiate()
	get_tree().root.add_child(_arrow)
	_arrow.global_position = Vector3(0, 3, 0)
	_arrow.velocity = Vector3(0, -12, 0)

	# Act
	for i in range(10):
		_arrow._physics_process(0.016)
		await get_tree().physics_frame

	# Assert: sin chapoteo
	var hay_splash := false
	for n in get_tree().root.get_children():
		if is_instance_valid(n) and n.has_method("play_splash"):
			hay_splash = true
			break
	assert_false(hay_splash, "Sin agua no hay chapoteo")
