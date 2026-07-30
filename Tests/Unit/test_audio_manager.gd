extends "res://addons/gut/test.gd"

var audio_mgr: Node = null


func before_each():
	var audio_script = load("res://System/Core/AudioManager.gd")
	audio_mgr = audio_script.new()
	add_child(audio_mgr)


func after_each():
	if is_instance_valid(audio_mgr):
		audio_mgr.free()


func test_gargola_death_volume_reducido_30_porciento() -> void:
	# Arrange
	var base_enemy_vol_db: float = audio_mgr._get_specific_volume_db(audio_mgr.enemy_damage_volume)

	# Act
	audio_mgr.play_sfx("gargola_death")

	# Buscar el AudioStreamPlayer creado/utilizado en sfx_pool
	var used_player: AudioStreamPlayer = null
	for p in audio_mgr.sfx_pool:
		if p.playing and p.stream != null:
			used_player = p
			break

	# Assert
	assert_not_null(used_player, "Un reproductor debe haber iniciado para gargola_death")
	if used_player:
		var expected_vol: float = base_enemy_vol_db - 3.1
		assert_almost_eq(
			used_player.volume_db,
			expected_vol,
			0.01,
			"El volumen de gargola_death debe reducirse 3.1 dB (~30%) respecto al volumen base de enemigo"
		)
