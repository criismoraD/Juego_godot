extends "res://addons/gut/test.gd"

## Tests del barco pirata de combate (gemelo de la balsa con modelo propio).

const BARCO_SCENE: PackedScene = preload("res://Entities/Ambiente_Barco_Combate_Pirata/BarcoCombatePirata.tscn")

var _root_test: Node3D = null


func before_each() -> void:
	_root_test = Node3D.new()
	_root_test.name = "RootTestBarcoCombate"
	get_tree().root.add_child(_root_test)
	get_tree().current_scene = _root_test


func after_each() -> void:
	if is_instance_valid(_root_test):
		_root_test.free()
	for n in get_tree().root.get_children():
		if n is BarcoCombatePirata or n is EnemyBase:
			n.free()


func _crear_barco() -> BarcoCombatePirata:
	var barco := BARCO_SCENE.instantiate() as BarcoCombatePirata
	assert_not_null(barco, "Debe instanciar BarcoCombatePirata")
	barco.position = Vector3(30.0, 0.0, -7.5)
	barco.activar_al_entrar_en_camara = false
	_root_test.add_child(barco)
	return barco


func test_barco_instancia_con_textura_propia_y_vida() -> void:
	# Arrange & Act
	var barco := _crear_barco()

	# Assert: modelo con su textura, casco enemigo y 16 de vida
	assert_true(barco is BalsaPirataCombate, "Debe heredar el combate de la balsa")
	var modelo := barco.find_child("BarcoModel", true, false)
	assert_not_null(modelo, "Debe traer el modelo del barco")
	var con_textura := false
	for m in modelo.find_children("*", "MeshInstance3D", true, false):
		var mat := (m as MeshInstance3D).material_override as StandardMaterial3D
		if mat and mat.albedo_texture and "Barco Combate Pirata_D" in mat.albedo_texture.resource_path:
			con_textura = true
			break
	assert_true(con_textura, "Debe usar su textura difusa")
	var casco := barco.find_child("CascoBarco", true, false) as StaticBody3D
	assert_not_null(casco, "Debe tener casco con colisión")
	assert_true(casco.collision_layer & 4 != 0, "El casco debe estar en capa de enemigos")
	assert_not_null(barco.find_child("PlataformaCubierta", true, false), "Debe tener plataforma como la balsa")
	assert_almost_eq(barco.vida_actual, 16.0, 0.001, "16 de vida como la balsa")


func test_barco_tres_cubiertas_a_distinta_altura() -> void:
	# Arrange & Act
	var barco := _crear_barco()
	var cub := barco.find_child("PlataformaCubierta", true, false) as Node3D
	assert_not_null(cub, "Debe existir PlataformaCubierta")

	# Assert: 3 cajas (proa/centro/popa) con las cimas escalonadas
	var cimas := []
	for n in cub.find_children("*", "CollisionShape3D", true, false):
		var col := n as CollisionShape3D
		var caja := col.shape as BoxShape3D
		assert_not_null(caja, "Cada cubierta debe ser caja")
		cimas.append(col.position.y + caja.size.y * 0.5)
	assert_eq(cimas.size(), 3, "3 cubiertas: proa, centro y popa")
	cimas.sort()
	assert_gt(cimas[1] - cimas[0], 0.02, "Niveles escalonados 1-2")
	assert_gt(cimas[2] - cimas[1], 0.02, "Niveles escalonados 2-3")

	# Assert: cimas absolutas = constante x escala del modelo (código y cajas amarrados)
	var modelo := barco.find_child("BarcoModel", true, false) as Node3D
	assert_not_null(modelo, "Debe existir BarcoModel")
	var s: float = modelo.scale.x
	var nombres := ["CubiertaProa", "CubiertaCentro", "CubiertaPopa"]
	for n in cub.find_children("*", "CollisionShape3D", true, false):
		var col := n as CollisionShape3D
		if not (col.name in nombres):
			continue
		var idx: int = nombres.find(col.name)
		var cima: float = col.position.y + (col.shape as BoxShape3D).size.y * 0.5
		var esperada: float = float(BarcoCombatePirata.CUBIERTAS_GLB[idx]["y"]) * s
		assert_almost_eq(cima, esperada, 0.02, "Cima de " + col.name + " = constante")


func test_barco_reparte_puestos_en_tres_cubiertas() -> void:
	# Arrange: 3 arqueras ordenadas (una por cubierta)
	var barco := _crear_barco()
	barco.cantidad_goblin_arquera = 3
	barco.mezclar_orden_aleatorio = false
	barco.intervalo_spawn = 0.0
	barco.activar()
	for i in range(5):
		barco._process(0.1)

	# Act: niveles Y locales de los puestos asignados
	var niveles := {}
	for n in barco.find_children("*", "CharacterBody3D", true, false):
		if n is EnemyBase:
			var local_y: float = snappedf(barco.to_local((n as Node3D).global_position).y, 0.01)
			niveles[local_y] = true

	# Assert: 3 alturas distintas = una por cubierta
	assert_eq(niveles.size(), 3, "Los puestos deben cubrir las 3 cubiertas")


func test_barco_despliega_mezcla_embarcada() -> void:
	# Arrange: 2 piratas + 1 arquera
	var barco := _crear_barco()
	barco.cantidad_pirata = 2
	barco.cantidad_goblin_arquera = 1
	barco.mezclar_orden_aleatorio = false
	barco.intervalo_spawn = 0.0
	barco.activar()
	for i in range(5):
		barco._process(0.1)

	# Assert: 3 embarcados atacando
	var total := 0
	for n in barco.find_children("*", "CharacterBody3D", true, false):
		if n is EnemyBase:
			total += 1
			assert_eq((n as Node3D).get_parent(), barco, "Cada tripulante cuelga del barco")
			assert_eq((n as EnemyBase).current_state, EnemyBase.State.SHOOTING, "Atacando al desplegar")
	assert_eq(total, 3, "Mezcla completa embarcada")


func test_barco_se_disuelve_sin_pecio_de_balsa() -> void:
	# Arrange
	var barco := _crear_barco()
	barco.activar()

	# Act: destruir el casco
	barco.destruir_balsa()

	# Assert: disolver con su textura y sin aparecer el pecio de balsa
	assert_null(barco.find_child("BalsaPirataModel", true, false), "No debe aparecer el pecio de balsa")
	var con_disolver := 0
	for m in barco.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi and mi.material_override is ShaderMaterial:
			var sm := mi.material_override as ShaderMaterial
			if sm.shader == BalsaPirataCombate.SHADER_DISOLVER:
				con_disolver += 1
				assert_not_null(sm.get_shader_parameter("albedo_texture"), "Con su textura, no plano")
	assert_gt(con_disolver, 0, "El barco debe disolverse")


func test_barco_casco_aguanta_16_impactos() -> void:
	# Arrange
	var barco := _crear_barco()
	barco.activar()

	# Act & Assert
	barco.take_damage(15.0)
	assert_false(barco.esta_destruida(), "Con 15 sigue a flote")
	barco.take_damage(1.0)
	assert_true(barco.esta_destruida(), "Con 16 se destruye")
