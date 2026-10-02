extends GutTest

const TUTORIAL_SCENE: PackedScene = preload("res://Levels/NIVEL_TUTORIAL/NIVEL_TUTORIAL.tscn")
const ImperioGirlScript = preload("res://Entities/Jugador_ImperioGirl/ImperioGirl.gd")

func test_nivel_tutorial_has_imperio_girl_as_player():
	var level = TUTORIAL_SCENE.instantiate()
	assert_not_null(level, "NIVEL_TUTORIAL should instantiate")
	if not level:
		return
	
	var player = level.find_child("Player", true, false)
	assert_not_null(player, "Player node should exist in NIVEL_TUTORIAL")
	assert_true(player is ImperioGirlScript, "Player in NIVEL_TUTORIAL must be ImperioGirl")
	assert_true(player is Player, "Player in NIVEL_TUTORIAL must be Player")
	
	var model = player.find_child("ImperioGirlModel", true, false)
	assert_not_null(model, "Player must have ImperioGirlModel")
	
	level.free()
