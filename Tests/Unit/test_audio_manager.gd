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


func test_goblin_explosive_death_streams_registered() -> void:
	# Arrange & Assert
	assert_true(audio_mgr.sfx_streams.has("goblin_explosive_death"), "Debe tener registrado goblin_explosive_death")
	assert_true(audio_mgr.sfx_streams.has("gobling_muerte_explosiva"), "Debe tener registrado gobling_muerte_explosiva como alias")

	var streams: Array = audio_mgr.sfx_streams["goblin_explosive_death"]
	assert_eq(streams.size(), 2, "Debe contener 2 variantes de sonido de muerte explosiva")
	for s in streams:
		assert_not_null(s, "Los recursos de audio no deben ser nulos")


func test_goblin_explosive_death_plays_with_50_percent_boost() -> void:
	# Arrange
	var base_enemy_vol_db: float = audio_mgr._get_specific_volume_db(audio_mgr.enemy_damage_volume)

	# Act
	audio_mgr.play_sfx("goblin_explosive_death")

	# Assert
	var used_player: AudioStreamPlayer = null
	for p in audio_mgr.sfx_pool:
		if p.playing and p.stream != null:
			used_player = p
			break

	assert_not_null(used_player, "Un reproductor debe estar reproduciendo el sonido goblin_explosive_death")
	if used_player:
		var expected_vol: float = base_enemy_vol_db + 3.5
		assert_almost_eq(
			used_player.volume_db,
			expected_vol,
			0.01,
			"El volumen de goblin_explosive_death debe aumentarse +3.5 dB (+50%) respecto al volumen base de enemigo"
		)


func test_invalid_sound_name_does_not_crash() -> void:
	# Arrange & Act: Pasar nombre inválido
	audio_mgr.play_sfx("sonido_inexistente_de_prueba")

	# Assert: Ningún reproductor debe haber sido activado con stream nulo
	var active_invalid: bool = false
	for p in audio_mgr.sfx_pool:
		if p.playing and p.stream == null:
			active_invalid = true
			break
	assert_false(active_invalid, "No debe activar reproductores para sonidos inexistentes")
