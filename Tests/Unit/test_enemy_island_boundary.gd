extends "res://addons/gut/test.gd"

var EnemyBaseScript = load("res://System/Core/EnemyBase.gd")
var ImpShieldGirlScript = load("res://Entities/Enemigo_Imp_Escudo/ImpShieldGirl.gd")
var BarreraLimiteScript = load("res://Entities/Ambiente_Barrera_Limite/BarreraLimite.gd")

class MockEnemy extends "res://System/Core/EnemyBase.gd":
	func _on_state_shooting():
		pass

func test_enemy_stops_at_left_boundary_when_crowded():
	# Arrange
	var barrera = BarreraLimiteScript.new()
	barrera.tamano = Vector3(1.0, 5.0, 1.0)
	barrera.global_position = Vector3(-5.7, 0.0, 0.0)
	add_child_autofree(barrera)

	var enemy = MockEnemy.new()
	enemy.global_position = Vector3(-4.8, 0.0, 0.0)
	enemy.target_walk_distance = 100.0  # Intentaría caminar 100 metros
	add_child_autofree(enemy)

	# Act: Simular un frame de caminata
	enemy._process_walking(0.1)

	# Assert: El enemigo debe detenerse y cambiar a SHOOTING en lugar de seguir hacia la izquierda
	var limite_esperado = barrera.global_position.x + (barrera.tamano.x * 0.5) + 0.35
	assert_gte(enemy.global_position.x, limite_esperado, "El enemigo no debe sobrepasar el límite izquierdo de la isla")
	assert_eq(enemy.current_state, enemy.State.SHOOTING, "El enemigo debe transicionar a SHOOTING al tocar el límite")


func test_imp_shield_girl_stops_at_left_boundary():
	# Arrange
	var barrera = BarreraLimiteScript.new()
	barrera.tamano = Vector3(1.0, 5.0, 1.0)
	barrera.global_position = Vector3(-5.7, 0.0, 0.0)
	add_child_autofree(barrera)

	var shield_girl = ImpShieldGirlScript.new()
	shield_girl.global_position = Vector3(-4.8, 0.0, 0.0)
	add_child_autofree(shield_girl)

	# Act: Simular caminata sin enemigo o con target_x muy a la izquierda
	shield_girl.posicion_libre_destino = -10.0
	shield_girl._process_walking(0.1)

	# Assert
	var limite_esperado = barrera.global_position.x + (barrera.tamano.x * 0.5) + 0.35
	assert_gte(shield_girl.global_position.x, limite_esperado, "ImpShieldGirl no debe sobrepasar el límite izquierdo")
	assert_eq(shield_girl.current_state, shield_girl.State.DEFENDING, "ImpShieldGirl debe ponerse en DEFENDING en el límite")
