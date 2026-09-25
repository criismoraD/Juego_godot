extends "res://addons/gut/test.gd"

## Tests de la salpicadura de agua del CanastaCaida al caer al agua:
## - Al cruzar la superficie del agua (grupo "agua") genera el splash del
##   enemigo Azulina (splash_vfx.tscn + play_splash) bajo la superficie.
## - Sin agua o fuera del rectángulo de agua no genera splash.
## - El splash solo se genera una vez y reemplaza al humo/piedras de impacto.

var CanastaCaidaScript: GDScript = preload("res://Entities/Enemigo_GloboAerostatico/CanastaCaida.gd")

var _root_test: Node3D = null
var _canasta: CanastaCaida = null
var _agua: Node3D = null


func before_each() -> void:
	_root_test = Node3D.new()
	_root_test.name = "RootTestCanastaAgua"
	get_tree().root.add_child(_root_test)
	get_tree().current_scene = _root_test


func after_each() -> void:
	if is_instance_valid(_canasta):
		_canasta.free()
	_canasta = null
	if is_instance_valid(_agua):
		_agua.free()
	_agua = null
	if is_instance_valid(_root_test):
		_root_test.free()
	_root_test = null


func _crear_agua(pos: Vector3) -> Node3D:
	_agua = Node3D.new()
	_agua.name = "AguaTest"
	_agua.add_to_group("agua")
	get_tree().root.add_child(_agua)
	_agua.global_position = pos
	var mi := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(60, 60)
	mi.mesh = plano
	_agua.add_child(mi)
	return _agua


func _crear_canasta(pos: Vector3) -> CanastaCaida:
	_canasta = CanastaCaidaScript.new()
	var visual_model := Node3D.new()
	visual_model.name = "ModeloCanasta"
	visual_model.scale = Vector3(0.65, 0.65, 0.65)
	_canasta.add_child(visual_model)
	_root_test.add_child(_canasta)
	_canasta.global_position = pos
	_canasta.iniciar_vuelo(Vector3(0.0, -2.0, 0.0), 0.0)
	return _canasta


func _buscar_splash() -> Node:
	for n in _root_test.get_children():
		if is_instance_valid(n) and n.has_method("play_splash"):
			return n
	return null


func _caer_frames(cantidad: int) -> void:
	for i in range(cantidad):
		if not is_instance_valid(_canasta):
			break
		_canasta._physics_process(0.016)


func test_canasto_cruzando_agua_genera_splash_de_azulina() -> void:
	# Arrange: agua ancha en y=0 y canasto cayendo desde arriba
	_crear_agua(Vector3.ZERO)
	_crear_canasta(Vector3(0.0, 3.0, 0.0))

	# Act: caída hasta cruzar la superficie y seguir hasta el fondo
	_caer_frames(45)

	# Assert: splash del enemigo Azulina generado
	assert_true(_canasta._splash_agua_hecho, "El canasto debe marcar su entrada al agua")
	assert_not_null(_buscar_splash(), "Al caer al agua debe generarse el splash de Azulina")
	var splash: Node = _buscar_splash()
	if splash:
		var ruta: String = str(splash.get("scene_file_path"))
		assert_true("splash_vfx.tscn" in ruta, "Debe usar la escena de splash del enemigo Azulina")


func test_splash_nace_bajo_la_superficie_del_agua() -> void:
	# Arrange
	_crear_agua(Vector3.ZERO)
	_crear_canasta(Vector3(0.0, 3.0, 0.0))

	# Act
	_caer_frames(45)

	# Assert: splash en la superficie (y = sup_y - profundidad_rotura_agua)
	var splash: Node = _buscar_splash()
	assert_not_null(splash, "Debe existir el splash para validar su posición")
	if splash and splash is Node3D:
		var sup_y_menos_profundidad: float = 0.0 - _canasta.profundidad_rotura_agua
		assert_almost_eq((splash as Node3D).global_position.y, sup_y_menos_profundidad, 0.05, "El splash nace bajo la línea de agua")
		assert_almost_eq((splash as Node3D).global_position.x, 0.0, 0.5, "El splash sigue la X del canasto")
		assert_almost_eq((splash as Node3D).scale.x, _canasta.escala_salpicadura_agua, 0.01, "El splash usa la escala configurada")


func test_canasto_sin_agua_no_genera_splash() -> void:
	# Arrange: sin nodos de agua en el grupo (niveles secos)
	_crear_canasta(Vector3(0.0, 3.0, 0.0))

	# Act
	_caer_frames(45)

	# Assert
	assert_false(_canasta._splash_agua_hecho, "Sin agua no debe marcar entrada al agua")
	assert_null(_buscar_splash(), "Sin agua no debe generarse splash")


func test_canasto_fuera_del_rect_agua_no_genera_splash() -> void:
	# Arrange: agua lejana fuera del recorrido del canasto
	_crear_agua(Vector3(500.0, 0.0, 0.0))
	_crear_canasta(Vector3(0.0, 3.0, 0.0))

	# Act
	_caer_frames(45)

	# Assert
	assert_false(_canasta._splash_agua_hecho, "Fuera del rect de agua no debe marcar entrada")
	assert_null(_buscar_splash(), "Fuera del agua no debe generarse splash")


func test_splash_se_genera_una_sola_vez() -> void:
	# Arrange: entrada al agua ya registrada (splash previo)
	_crear_agua(Vector3.ZERO)
	_crear_canasta(Vector3(0.0, 3.0, 0.0))
	_canasta._splash_agua_hecho = true

	# Act
	_caer_frames(45)

	# Assert
	assert_null(_buscar_splash(), "El splash no debe repetirse si ya ocurrió")


func test_canasto_en_agua_no_genera_humo_ni_piedras_de_impacto() -> void:
	# Arrange: cayendo al agua
	_crear_agua(Vector3.ZERO)
	_crear_canasta(Vector3(0.0, 3.0, 0.0))

	# Act: caída completa (cruza el agua y llega al fondo)
	_caer_frames(45)

	# Assert: el splash reemplaza al humo/piedras del impacto contra suelo
	assert_true(_canasta._splash_agua_hecho, "Debe haber entrado al agua")
	var hay_piedras := false
	for n in _root_test.get_children():
		if is_instance_valid(n) and n.name.begins_with("ParticulasPiedrasCanasta"):
			hay_piedras = true
			break
	assert_false(hay_piedras, "En el agua no debe generar piedras de impacto")


func test_canasto_en_suelo_seco_si_genera_piedras_de_impacto() -> void:
	# Arrange: sin agua, el impacto contra el suelo mantiene su humo/piedras
	_crear_canasta(Vector3(0.0, 3.0, 0.0))

	# Act: caída completa hasta el fondo (vacío)
	_caer_frames(45)
	_canasta._splash_agua_hecho = false
	_canasta._spawn_humo_y_piedras_impacto()

	# Assert
	var hay_piedras := false
	for n in _root_test.get_children():
		if is_instance_valid(n) and n.name.begins_with("ParticulasPiedrasCanasta"):
			hay_piedras = true
			break
	assert_true(hay_piedras, "Sin agua el impacto mantiene sus piedras")
