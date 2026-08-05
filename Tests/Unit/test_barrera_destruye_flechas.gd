extends "res://addons/gut/test.gd"

var BarreraScript = load("res://Entities/Ambiente_Barrera_Limite/BarreraDestruyeFlechas.gd")
var ArrowScene = load("res://Entities/Proyectil_Flecha/Arrow.tscn")
var AllyArrowScene = load("res://Entities/Proyectil_Flecha_Aliada/AllyArrow.tscn")

var _barrera: StaticBody3D = null
var _arrow: Area3D = null
var _ally_arrow: Area3D = null


func before_each():
	_barrera = BarreraScript.new()
	get_tree().root.add_child(_barrera)


func after_each():
	if is_instance_valid(_barrera):
		_barrera.free()
	if is_instance_valid(_arrow):
		_arrow.free()
	if is_instance_valid(_ally_arrow):
		_ally_arrow.free()


func test_barrera_properties():
	assert_true(_barrera.is_in_group("barrera_destruye_flechas"), "Debería estar en el grupo barrera_destruye_flechas")
	assert_eq(_barrera.collision_layer, 4, "La capa de colisión debería ser la 3 (bit 2 = valor 4)")
	assert_eq(_barrera.collision_mask, 0, "No debería colisionar con nada activamente (collision_mask = 0)")


func test_arrow_destroyed_by_barrier():
	# Arrange
	_arrow = ArrowScene.instantiate()
	get_tree().root.add_child(_arrow)

	# Act
	_arrow._on_body_entered(_barrera)

	# Assert
	assert_true(_arrow.get("_destroying"), "La flecha del jugador debería destruirse al chocar con la barrera")


func test_arrow_silent_on_barrier_no_vfx():
	# Arrange: flecha de máxima potencia (la que normalmente genera VFX de impacto)
	_arrow = ArrowScene.instantiate()
	get_tree().root.add_child(_arrow)
	_arrow.set_meta("is_max_power", true)

	var cpu_particles_before := get_tree().root.find_children("*", "CPUParticles3D", true, false).size()

	# Act
	_arrow._on_body_entered(_barrera)

	# Assert: al chocar con la barrera NO debe generar VFX de impacto (silencioso)
	var cpu_particles_after := get_tree().root.find_children("*", "CPUParticles3D", true, false).size()
	assert_eq(cpu_particles_after, cpu_particles_before,
		"La flecha NO debería generar partículas de impacto al chocar con la barrera (destrucción silenciosa)")
	assert_true(_arrow.get("_destroying"), "La flecha debería marcarse como destruyéndose")



func test_ally_arrow_destroyed_by_barrier():
	# Arrange
	_ally_arrow = AllyArrowScene.instantiate()
	get_tree().root.add_child(_ally_arrow)

	# Act
	_ally_arrow._on_body_entered(_barrera)

	assert_true(_ally_arrow.get("_destroying"), "La flecha aliada debería destruirse al chocar con la barrera")


func test_enemy_walks_out_of_barrier():
	# Arrange: Crear un enemigo y colocarlo en la posición de la barrera
	var EnemyBaseScript = load("res://System/Core/EnemyBase.gd")
	var enemy = EnemyBaseScript.new()
	# Añadir al árbol para que _physics_process y get_tree() funcionen
	get_tree().root.add_child(enemy)
	
	# Colocar la barrera en x = 5.0, tamaño 1.0 (cubre 4.5 a 5.5)
	_barrera.global_position = Vector3(5.0, 0.0, 0.0)
	_barrera.tamano = Vector3(1.0, 10.0, 1.0)
	
	# Colocar al enemigo dentro de la barrera en x = 5.0
	enemy.global_position = Vector3(5.0, 0.0, 0.0)
	enemy.current_state = enemy.State.SHOOTING
	
	# Act: Ejecutar un frame de física
	enemy._physics_process(0.1)
	
	# Assert: Debería haber cambiado a WALKING y tener velocidad hacia la izquierda (negativa)
	assert_eq(enemy.current_state, enemy.State.WALKING, "El enemigo debería cambiar a WALKING para salir de la barrera")
	assert_lt(enemy.velocity.x, 0.0, "La velocidad.x del enemigo debería ser negativa (moverse a la izquierda)")
	
	# Limpieza
	enemy.free()
