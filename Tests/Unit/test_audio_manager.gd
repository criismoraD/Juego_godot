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


func test_musica_oleada_5_noche_aplastante_registrada_y_volumen_equilibrado() -> void:
	# Assert
	assert_gt(audio_mgr.bgm_streams.size(), 5, "AudioManager debe tener registrado el índice 5 de música")
	assert_not_null(audio_mgr.bgm_streams[5], "El stream de Noche Aplastante no debe ser nulo")

	# Act
	audio_mgr.play_music(5)

	# Assert
	assert_not_null(audio_mgr.music_player.stream, "El reproductor de música debe cargar el stream")
	assert_almost_eq(
		audio_mgr.music_player.volume_db,
		audio_mgr.music_volume_db + 2.0,
		0.01,
		"Noche Aplastante debe tener un offset calibrado de +2.0 dB"
	)


func test_obtencion_arma_sfx_registrado_y_reproducible() -> void:
	# Assert: Registro en sfx_streams
	assert_true(audio_mgr.sfx_streams.has("obtencion_arma"), "AudioManager debe tener registrado el SFX obtencion_arma")
	assert_not_null(audio_mgr.sfx_streams["obtencion_arma"][0], "El recurso de audio obtencion_arma no debe ser nulo")

	# Act: Reproducir SFX
	audio_mgr.play_sfx("obtencion_arma")

	# Assert: Reproductor activado
	var played: bool = false
	for p in audio_mgr.sfx_pool:
		if p.playing and p.stream != null:
			played = true
			break
	assert_true(played, "Un reproductor debe haber iniciado para obtencion_arma")


func test_bgm_main_theme_volumen_reducido() -> void:
	# Assert
	assert_gt(audio_mgr.bgm_streams.size(), 1, "AudioManager debe tener registrado el índice 1 de música")
	assert_not_null(audio_mgr.bgm_streams[1], "El stream de BGM_main_theme no debe ser nulo")

	# Act
	audio_mgr.play_music(1)

	# Assert
	assert_not_null(audio_mgr.music_player.stream, "El reproductor de música debe cargar el stream")
	assert_almost_eq(
		audio_mgr.music_player.volume_db,
		audio_mgr.music_volume_db - 5.0,
		0.01,
		"BGM_main_theme debe tener un offset calibrado de -5.0 dB"
	)


func test_refuerzo_escudo_sfx_registrado_y_reproducible() -> void:
	# Assert: Debe estar registrado en sfx_streams
	assert_true(audio_mgr.sfx_streams.has("refuerzo_escudo"), "AudioManager debe tener registrado 'refuerzo_escudo'")
	var streams: Array = audio_mgr.sfx_streams.get("refuerzo_escudo", [])
	assert_gt(streams.size(), 0, "Debe tener al menos un stream para 'refuerzo_escudo'")
	assert_not_null(streams[0], "El stream no debe ser nulo")

	# Act
	audio_mgr.play_sfx("refuerzo_escudo")

	# Assert
	var played: bool = false
	for p in audio_mgr.sfx_pool:
		if p.playing and p.stream != null:
			played = true
			break
	assert_true(played, "Un reproductor debe haber iniciado para refuerzo_escudo")


func test_muerte_ballestera_sfx_registrado_y_reproducible() -> void:
	assert_true(audio_mgr.sfx_streams.has("muerte_ballestera"), "AudioManager debe tener registrado 'muerte_ballestera'")
	assert_true(audio_mgr.sfx_streams.has("ballestera_death"), "AudioManager debe tener el alias 'ballestera_death'")
	var streams: Array = audio_mgr.sfx_streams.get("muerte_ballestera", [])
	assert_gt(streams.size(), 0, "Debe tener stream para 'muerte_ballestera'")
	assert_not_null(streams[0], "El stream de muerte_ballestera no debe ser nulo")

	audio_mgr.play_sfx("muerte_ballestera")

	var played: bool = false
	for p in audio_mgr.sfx_pool:
		if p.playing and p.stream != null:
			played = true
			break
	assert_true(played, "Un reproductor debe haber iniciado para muerte_ballestera")


func test_risa_victoria_ballestera_sfx_registrado_y_reproducible() -> void:
	assert_true(audio_mgr.sfx_streams.has("risa_victoria_ballestera"), "AudioManager debe tener registrado 'risa_victoria_ballestera'")
	assert_true(audio_mgr.sfx_streams.has("ballestera_victoria"), "AudioManager debe tener el alias 'ballestera_victoria'")
	var streams: Array = audio_mgr.sfx_streams.get("risa_victoria_ballestera", [])
	assert_gt(streams.size(), 0, "Debe tener stream para 'risa_victoria_ballestera'")
	assert_not_null(streams[0], "El stream de risa_victoria_ballestera no debe ser nulo")

	audio_mgr.play_sfx("risa_victoria_ballestera")

	var played: bool = false
	for p in audio_mgr.sfx_pool:
		if p.playing and p.stream != null:
			played = true
			break
	assert_true(played, "Un reproductor debe haber iniciado para risa_victoria_ballestera")

