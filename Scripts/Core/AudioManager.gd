extends Node
## AudioManager - Singleton para gestión centralizada de audio
##
## Uso:
##   AudioManager.play_sfx("player_shoot")
##   AudioManager.play_sfx_3d("goblin_death", position)
##   AudioManager.play_music(1)

# === REPRODUCTORES ===
var sfx_player: AudioStreamPlayer
var sfx_player_3d: AudioStreamPlayer3D
var music_player: AudioStreamPlayer

# === STREAMS DE AUDIO ===
var sfx_streams: Dictionary = {}
var bgm_streams: Array[AudioStream] = []

# === CONFIGURACIÓN ===
var sfx_volume_db: float = -5.0
var music_volume_db: float = -15.0

# === VOLÚMENES ESPECÍFICOS (0-100) ===
var player_hurt_volume: float = 100.0 # Volumen de daño recibido
var enemy_damage_volume: float = 66.0 # Volumen de daño a enemigos


func _ready():
	_setup_players()
	_load_all_sounds()
	
	# Iniciar música por defecto
	play_music(1)

func _setup_players():
	# Reproductor SFX 2D
	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SFX_Player"
	sfx_player.volume_db = sfx_volume_db
	sfx_player.bus = "Master"
	add_child(sfx_player)
	
	# Reproductor SFX 3D (para spawn dinámico)
	sfx_player_3d = AudioStreamPlayer3D.new()
	sfx_player_3d.name = "SFX_Player3D"
	sfx_player_3d.unit_size = 10.0
	sfx_player_3d.max_db = 0.0
	add_child(sfx_player_3d)
	
	# Reproductor de música
	music_player = AudioStreamPlayer.new()
	music_player.name = "Music_Player"
	music_player.volume_db = music_volume_db
	music_player.bus = "Master"
	add_child(music_player)

func _load_all_sounds():
	# ═══════════════════════════════════════════════════════════════════════════════
	# SONIDOS DEL JUGADOR
	# ═══════════════════════════════════════════════════════════════════════════════
	sfx_streams["player_hurt"] = [
		load("res://Assets/Audio/SFX/Player/DAÑO_PERSONAJE0.mp3"),
		load("res://Assets/Audio/SFX/Player/DAÑO_PERSONAJE1.mp3")
	]
	
	sfx_streams["player_death"] = [
		load("res://Assets/Audio/SFX/Player/SFX_player_death.mp3")
	]
	
	sfx_streams["player_shoot"] = [
		load("res://Assets/Audio/SFX/Player/DISPARO_FLECHA1.mp3"),
		load("res://Assets/Audio/SFX/Player/DISPARO_FLECHA2.mp3")
	]
	
	sfx_streams["bow_tension"] = [
		load("res://Assets/Audio/SFX/Player/TENSADO_CUERDA1.mp3"),
		load("res://Assets/Audio/SFX/Player/TENSADO_CUERDA2.mp3")
	]
	
	# ═══════════════════════════════════════════════════════════════════════════════
	# SONIDOS DE ENEMIGOS
	# ═══════════════════════════════════════════════════════════════════════════════
	sfx_streams["goblin_shoot"] = [
		load("res://Assets/Audio/SFX/Enemies/DISPARO_Ballesta 1.mp3"),
		load("res://Assets/Audio/SFX/Enemies/DISPARO_Ballesta 2.mp3"),
		load("res://Assets/Audio/SFX/Enemies/DISPARO_Ballesta 3.mp3")
	]
	
	sfx_streams["goblin_death"] = [
		load("res://Assets/Audio/SFX/Enemies/SFX_goblin_death01.mp3"),
		load("res://Assets/Audio/SFX/Enemies/SFX_goblin_death02.mp3"),
		load("res://Assets/Audio/SFX/Enemies/SFX_goblin_death03.mp3"),
		load("res://Assets/Audio/SFX/Enemies/MUERTE_GOBLING1.mp3"),
		load("res://Assets/Audio/SFX/Enemies/MUERTE_GOBLING2.mp3")
	]
	
	sfx_streams["goblin_girl_shoot"] = sfx_streams["player_shoot"] # Usa el mismo arco
	
	sfx_streams["goblin_girl_death"] = [
		load("res://Assets/Audio/SFX/Enemies/SFX_goblin_girl_death1.mp3"),
		load("res://Assets/Audio/SFX/Enemies/SFX_goblin_girl_death2.mp3"),
		load("res://Assets/Audio/SFX/Enemies/SFX_goblin_girl_death3.mp3")
	]
	
	# ═══════════════════════════════════════════════════════════════════════════════
	# SONIDOS DE AMBIENTE / ESCUDOS
	# ═══════════════════════════════════════════════════════════════════════════════
	sfx_streams["shield_hit_crossbow"] = [
		load("res://Assets/Audio/SFX/Environment/IMPACTO_ESCUDO_BALLESTA.mp3")
	]
	
	sfx_streams["shield_hit_arrow"] = [
		load("res://Assets/Audio/SFX/Environment/IMPACTO_ESCUDO_FLECHA.mp3")
	]
	
	# Alias genérico para compatibilidad
	sfx_streams["shield_hit"] = sfx_streams["shield_hit_crossbow"]
	

	# ═══════════════════════════════════════════════════════════════════════════════
	# MÚSICA
	# ═══════════════════════════════════════════════════════════════════════════════
	bgm_streams.append(null) # Índice 0 = silencio
	bgm_streams.append(load("res://Assets/Audio/Music/BGM_main_theme.mp3"))
	bgm_streams.append(load("res://Assets/Audio/Music/BGM_battle.mp3"))

# ═══════════════════════════════════════════════════════════════════════════════
# API PÚBLICA
# ═══════════════════════════════════════════════════════════════════════════════

## Reproduce un efecto de sonido (selección aleatoria si hay variantes)
## Usa reproductores temporales para permitir sonidos simultáneos
func play_sfx(sound_name: String):
	if not sfx_streams.has(sound_name):
		push_warning("[AudioManager] Sonido no encontrado: " + sound_name)
		return
	
	var sounds = sfx_streams[sound_name]
	if sounds.is_empty():
		return
	
	var sound = sounds[randi() % sounds.size()]
	if sound:
		# Crear reproductor temporal para permitir sonidos simultáneos
		var temp_player = AudioStreamPlayer.new()
		temp_player.stream = sound
		
		# Determinar volumen según tipo de sonido
		var volume_to_use = sfx_volume_db
		if sound_name == "player_hurt" or sound_name == "player_death":
			# Usar volumen de daño al jugador
			volume_to_use = _get_specific_volume_db(player_hurt_volume)
		elif sound_name in ["goblin_death", "goblin_girl_death"]:
			# Usar volumen de daño a enemigos
			volume_to_use = _get_specific_volume_db(enemy_damage_volume)
		
		temp_player.volume_db = volume_to_use
		temp_player.bus = "Master"
		add_child(temp_player)
		temp_player.play()
		# Auto-eliminar cuando termine (con verificación de seguridad)
		temp_player.finished.connect(func():
			if is_instance_valid(temp_player):
				temp_player.queue_free()
		)

## Reproduce un efecto de sonido en posición 3D
func play_sfx_3d(sound_name: String, position: Vector3):
	if not sfx_streams.has(sound_name):
		push_warning("[AudioManager] Sonido no encontrado: " + sound_name)
		return
	
	var sounds = sfx_streams[sound_name]
	if sounds.is_empty():
		return
	
	var sound = sounds[randi() % sounds.size()]
	if sound:
		# Crear reproductor temporal para permitir sonidos simultáneos
		var temp_player = AudioStreamPlayer3D.new()
		temp_player.stream = sound
		temp_player.unit_size = 50.0 # Aumentado para mayor alcance
		temp_player.max_db = 6.0 # Aumentado para más volumen cercano
		temp_player.volume_db = sfx_volume_db + 5.0 # Boost adicional
		temp_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED # Sin atenuación por distancia
		add_child(temp_player)
		temp_player.global_position = position
		temp_player.play()
		# Auto-eliminar cuando termine (con verificación de seguridad)
		temp_player.finished.connect(func():
			if is_instance_valid(temp_player):
				temp_player.queue_free()
		)

## Reproduce música de fondo
func play_music(index: int):
	if index == 0:
		music_player.stop()
		return
	
	if index < 0 or index >= bgm_streams.size():
		push_warning("[AudioManager] Índice de música inválido: " + str(index))
		return
	
	var stream = bgm_streams[index]
	if stream:
		if music_player.stream != stream:
			music_player.stream = stream
			music_player.play()
		elif not music_player.playing:
			music_player.play()

## Ajustar volumen de SFX (0-100)
func set_sfx_volume(value: float):
	sfx_volume_db = lerp(-40.0, 0.0, value / 100.0)
	if value == 0:
		sfx_volume_db = -80
	sfx_player.volume_db = sfx_volume_db

## Ajustar volumen de música (0-100)
func set_music_volume(value: float):
	music_volume_db = lerp(-40.0, 0.0, value / 100.0)
	if value == 0:
		music_volume_db = -80
	music_player.volume_db = music_volume_db

## Obtener el reproductor de música (para UI)
func get_music_player() -> AudioStreamPlayer:
	return music_player

## Obtener el reproductor de SFX (para UI)
func get_sfx_player() -> AudioStreamPlayer:
	return sfx_player

## Reproducir sonido de escudo estándar
func play_shield_hit():
	play_sfx("shield_hit")

## Reproducir sonido de tensar cuerda (usa sfx_player fijo para poder detenerlo)
func play_bow_tension():
	if not sfx_streams.has("bow_tension"):
		return
	var sounds = sfx_streams["bow_tension"]
	if sounds.is_empty():
		return
	var sound = sounds[randi() % sounds.size()]
	if sound:
		sfx_player.stream = sound
		sfx_player.play()

## Detener sonido de tensar cuerda
func stop_bow_tension():
	if sfx_player.playing:
		sfx_player.stop()

# ═══════════════════════════════════════════════════════════════════════════════
# VOLÚMENES ESPECÍFICOS
# ═══════════════════════════════════════════════════════════════════════════════

## Convierte un valor de 0-100 a dB
func _get_specific_volume_db(value: float) -> float:
	if value == 0:
		return -80.0
	return lerp(-40.0, 0.0, value / 100.0)

## Ajustar volumen de sonidos de daño al jugador (0-100)
func set_player_hurt_volume(value: float):
	player_hurt_volume = clamp(value, 0.0, 100.0)

## Obtener volumen de daño al jugador
func get_player_hurt_volume() -> float:
	return player_hurt_volume

## Ajustar volumen de sonidos de daño a enemigos (0-100)
func set_enemy_damage_volume(value: float):
	enemy_damage_volume = clamp(value, 0.0, 100.0)

## Obtener volumen de daño a enemigos
func get_enemy_damage_volume() -> float:
	return enemy_damage_volume
