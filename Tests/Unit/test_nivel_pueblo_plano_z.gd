extends "res://addons/gut/test.gd"

## Test de alineacion de planos en Nivel Pueblo:
## Verifica que la protagonista y el WaveSpawner (enemigos) compartan el mismo plano Z (2.5D).

func test_player_y_enemigos_mismo_plano_z():
	# Arrange
	var scene: PackedScene = load("res://Levels/Nivel_Pueblo/NivelPueblo.tscn")
	assert_not_null(scene, "La escena NivelPueblo debe existir y cargar correctamente")
	
	# Act
	var nivel: Node = scene.instantiate()
	add_child_autofree(nivel)
	
	var player: Node3D = nivel.find_child("Player", true, false) as Node3D
	var spawner: Node3D = nivel.find_child("WaveSpawner", true, false) as Node3D
	
	# Assert
	assert_not_null(player, "Debe existir el nodo Player en NivelPueblo")
	assert_not_null(spawner, "Debe existir el nodo WaveSpawner en NivelPueblo")
	
	var spawner_z: float = spawner.position.z
	var player_plano_z: float = player.get("plano_profundidad_z") if player.get("plano_profundidad_z") != null else -999.0
	
	assert_almost_eq(player_plano_z, spawner_z, 0.01, 
		"El plano de profundidad Z del jugador (%.2f) debe coincidir con el plano de los enemigos (%.2f)" % [player_plano_z, spawner_z])
