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

# === OBJECT POOLING PARA AUDIO ===
var sfx_pool: Array[AudioStreamPlayer] = []
var sfx_3d_pool: Array[AudioStreamPlayer3D] = []
const MAX_POOL_SIZE = 16
const MAX_3D_POOL_SIZE = 16
var _sfx_pool_idx: int = 0 # OPT: Índice circular para O(1) en vez de scan lineal
var _sfx_3d_pool_idx: int = 0


# === PITCH DITHERING (variación aleatoria de tono) ===
var shoot_pitch_min: float = 0.85
var shoot_pitch_max: float = 1.15
var damage_pitch_min: float = 0.9
var damage_pitch_max: float = 1.1

# === VOLÚMENES ESPECÍFICOS (0-100) ===
var player_hurt_volume: float = 100.0 # Volumen de daño recibido
var enemy_damage_volume: float = 66.0 # Volumen de daño a enemigos

# === CONTADORES ===
var player_kill_count: int = 0


func _ready():
	_setup_players()
	_load_all_sounds()
	
	# La música se inicia desde la escena correspondiente
	# (antes se auto-reproducía aquí)

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

	# Inicializar pools
	for i in range(MAX_POOL_SIZE):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		sfx_pool.append(p)

	for i in range(MAX_3D_POOL_SIZE):
		var p3d = AudioStreamPlayer3D.new()
		p3d.bus = "Master"
		p3d.unit_size = 50.0
		p3d.max_db = 6.0
		p3d.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		add_child(p3d)
		sfx_3d_pool.append(p3d)

func _load_all_sounds():
	# ═══════════════════════════════════════════════════════════════════════════════
	# SONIDOS DEL JUGADOR
	# ═══════════════════════════════════════════════════════════════════════════════
	sfx_streams["player_hurt"] = [
		load("res://Assets/Characters/Player/DAÑO_PERSONAJE0.mp3"),
		load("res://Assets/Characters/Player/DAÑO_PERSONAJE1.mp3"),
		load("res://Assets/Characters/Player/DAÑO_PERSONAJE3.mp3")
	]
	
	sfx_streams["player_death"] = [
		load("res://Assets/Characters/Player/SFX_player_death.mp3")
	]
	
	sfx_streams["player_shoot"] = [
		load("res://Assets/Characters/Player/DISPARO_FLECHA1.mp3"),
		load("res://Assets/Characters/Player/DISPARO_FLECHA2.mp3")
	]
	
	sfx_streams["bow_tension"] = [
		load("res://Assets/Characters/Player/TENSADO_CUERDA1.mp3"),
		load("res://Assets/Characters/Player/TENSADO_CUERDA2.mp3")
	]
	
	sfx_streams["bow_hold"] = [
		load("res://Assets/Characters/Player/MANTENER_ARCO.mp3")
	]
	
	sfx_streams["player_laugh"] = [
		load("res://Assets/Characters/Player/RISA_PERSONAJE.mp3")
	]
	
	# ═══════════════════════════════════════════════════════════════════════════════
	# SONIDOS DE ENEMIGOS
	# ═══════════════════════════════════════════════════════════════════════════════
	sfx_streams["goblin_shoot"] = [
		load("res://Assets/Characters/Goblin/DISPARO_Ballesta 1.mp3"),
		load("res://Assets/Characters/Goblin/DISPARO_Ballesta 2.mp3"),
		load("res://Assets/Characters/Goblin/DISPARO_Ballesta 3.mp3")
	]
	
	sfx_streams["goblin_death"] = [
		load("res://Assets/Characters/Goblin/MUERTE_GOBLING_1.mp3"),
		load("res://Assets/Characters/Goblin/MUERTE_GOBLING_2.mp3"),
		load("res://Assets/Characters/Goblin/MUERTE_GOBLING_3.mp3"),
		load("res://Assets/Characters/Goblin/MUERTE_GOBLING_4.mp3")
	]
	
	sfx_streams["goblin_laugh"] = [
		load("res://Assets/Characters/Goblin/RISA_GOBLING_3.mp3")
	]
	
	sfx_streams["goblin_girl_shoot"] = sfx_streams["player_shoot"] # Usa el mismo arco
	
	sfx_streams["goblin_girl_death"] = [
		load("res://Assets/Characters/GoblinGirl/SFX_goblin_girl_death1.mp3"),
		load("res://Assets/Characters/GoblinGirl/SFX_goblin_girl_death2.mp3"),
		load("res://Assets/Characters/GoblinGirl/SFX_goblin_girl_death3.mp3")
	]
	
	sfx_streams["imp_death"] = [
		load("res://Assets/Characters/Imp/MUERTE_IMP1.mp3"),
		load("res://Assets/Characters/Imp/MUERTE_IMP2.mp3")
	]
	
	sfx_streams["explosion_muerte"] = [
		load("res://Assets/Characters/Imp/EXPLOCION_Muerte1.mp3"),
		load("res://Assets/Characters/Imp/EXPLOCION_Muerte2.mp3"),
		load("res://Assets/Characters/Imp/EXPLOCION_Muerte3.mp3")
	]
	
	sfx_streams["trident_shot"] = [
		load("res://Assets/Characters/Imp/TRIDENTE_SHOT.mp3")
	]
	
	sfx_streams["shield_imp_impact"] = [
		load("res://Assets/Characters/ImpShieldGirl/IMPACTO_IMP_ESCUDO_01.mp3"),
		load("res://Assets/Characters/ImpShieldGirl/IMPACTO_IMP_ESCUDO_02.mp3")
	]
	
	sfx_streams["shield_imp_death"] = [
		load("res://Assets/Characters/ImpShieldGirl/MUERTE_IMP_ESCUDO_01.mp3"),
		load("res://Assets/Characters/ImpShieldGirl/MUERTE_IMP_ESCUDO_2.mp3")
	]
	
	# ═══════════════════════════════════════════════════════════════════════════════
	# SONIDOS DE AMBIENTE / ESCUDOS
	# ═══════════════════════════════════════════════════════════════════════════════
	sfx_streams["shield_hit_crossbow"] = [
		load("res://Assets/Environment/Shield/IMPACTO_ESCUDO_BALLESTA.mp3")
	]
	
	sfx_streams["shield_hit_arrow"] = [
		load("res://Assets/Environment/Shield/IMPACTO_ESCUDO_FLECHA.mp3")
	]
	
	# Alias genérico para compatibilidad
	sfx_streams["shield_hit"] = sfx_streams["shield_hit_crossbow"]
	
	sfx_streams["shield_break"] = [
		load("res://Assets/Environment/Shield/ESCUDO_ROTO.mp3")
	]
	

	# ═══════════════════════════════════════════════════════════════════════════════
	# MÚSICA
	# ═══════════════════════════════════════════════════════════════════════════════
	bgm_streams.append(null) # Índice 0 = silencio
	bgm_streams.append(load("res://Assets/Audio/Music/BGM_main_theme.mp3")) # Índice 1
	bgm_streams.append(load("res://Assets/Audio/Music/BGM_battle.mp3")) # Índice 2
	bgm_streams.append(load("res://Assets/Audio/Music/SONIDO BOSQUE.mp3")) # Índice 3 - Nivel 0 pacifista
	bgm_streams.append(load("res://Assets/Audio/Music/VICTORY.mp3")) # Índice 4 - Victoria


# ═══════════════════════════════════════════════════════════════════════════════
# POOL HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _get_available_sfx_player() -> AudioStreamPlayer:
	# OPT: Índice circular O(1) — buscar desde el último usado, máximo 1 vuelta
	for i in range(MAX_POOL_SIZE):
		var idx = (_sfx_pool_idx + i) % MAX_POOL_SIZE
		if not sfx_pool[idx].playing:
			_sfx_pool_idx = (idx + 1) % MAX_POOL_SIZE
			return sfx_pool[idx]
	# Todos ocupados: tomar el siguiente round-robin (fuerza reuso)
	var player = sfx_pool[_sfx_pool_idx]
	_sfx_pool_idx = (_sfx_pool_idx + 1) % MAX_POOL_SIZE
	return player

func _get_available_sfx_3d_player() -> AudioStreamPlayer3D:
	# OPT: Índice circular O(1)
	for i in range(MAX_3D_POOL_SIZE):
		var idx = (_sfx_3d_pool_idx + i) % MAX_3D_POOL_SIZE
		if not sfx_3d_pool[idx].playing:
			_sfx_3d_pool_idx = (idx + 1) % MAX_3D_POOL_SIZE
			return sfx_3d_pool[idx]
	# Todos ocupados: round-robin
	var player = sfx_3d_pool[_sfx_3d_pool_idx]
	_sfx_3d_pool_idx = (_sfx_3d_pool_idx + 1) % MAX_3D_POOL_SIZE
	return player

# ═══════════════════════════════════════════════════════════════════════════════
# API PÚBLICA
# ═══════════════════════════════════════════════════════════════════════════════



## Reproduce un efecto de sonido (selección aleatoria si hay variantes)
## Usa reproductores temporales para permitir sonidos simultáneos
func play_sfx(sound_name: String, volume_boost_db: float = 0.0):
	if not sfx_streams.has(sound_name):
		push_warning("[AudioManager] Sonido no encontrado: " + sound_name)
		return
	
	var sounds = sfx_streams[sound_name]
	if sounds.is_empty():
		return
	
	var sound = sounds[randi() % sounds.size()]
	if sound:
		# Usar object pooling
		var temp_player = _get_available_sfx_player()
		temp_player.stream = sound
		
		# Determinar volumen según tipo de sonido
		var volume_to_use = sfx_volume_db
		if sound_name == "player_hurt" or sound_name == "player_death":
			# Usar volumen de daño al jugador
			volume_to_use = _get_specific_volume_db(player_hurt_volume)
		elif sound_name in ["goblin_death", "goblin_girl_death"]:
			# Usar volumen de daño a enemigos
			volume_to_use = _get_specific_volume_db(enemy_damage_volume)
		elif sound_name == "imp_death":
			# Imp muerte al doble de volumen
			volume_to_use = _get_specific_volume_db(enemy_damage_volume) + 6.0
		elif sound_name == "explosion_muerte":
			# Explosión 3x más fuerte
			volume_to_use = _get_specific_volume_db(enemy_damage_volume) + 10.0
		
		temp_player.volume_db = volume_to_use + volume_boost_db
		temp_player.bus = "Master"
		
		# Pitch dithering
		if "shoot" in sound_name:
			temp_player.pitch_scale = randf_range(shoot_pitch_min, shoot_pitch_max)
		elif "hurt" in sound_name or "death" in sound_name:
			temp_player.pitch_scale = randf_range(damage_pitch_min, damage_pitch_max)
		
		if not temp_player.is_inside_tree():
			add_child(temp_player)
		temp_player.play()

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
		# Usar object pooling
		var temp_player = _get_available_sfx_3d_player()
		temp_player.stream = sound
		temp_player.volume_db = sfx_volume_db + 5.0 # Boost adicional
		
		# Pitch dithering
		if "shoot" in sound_name:
			temp_player.pitch_scale = randf_range(shoot_pitch_min, shoot_pitch_max)
		elif "hurt" in sound_name or "death" in sound_name:
			temp_player.pitch_scale = randf_range(damage_pitch_min, damage_pitch_max)
		
		if not temp_player.is_inside_tree():
			add_child(temp_player)
		temp_player.global_position = position
		temp_player.play()

## Reproduce música de fondo
func play_music(index: int, loop: bool = true, volume_boost_db: float = 0.0):
	if index == 0:
		music_player.stop()
		return
	
	if index < 0 or index >= bgm_streams.size():
		push_warning("[AudioManager] Índice de música inválido: " + str(index))
		return
	
	var stream = bgm_streams[index]
	if stream:
		if stream is AudioStreamMP3:
			stream.loop = loop
		elif stream is AudioStreamOggVorbis:
			stream.loop = loop
		elif stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
		music_player.volume_db = music_volume_db + volume_boost_db
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

## Reproducir sonido de escudo estandar
func play_shield_hit():
	play_sfx("shield_hit")

## Reproducir sonido de escudo roto (+5.0 dB)
func play_shield_break():
	play_sfx("shield_break", 5.0)

## Reproducir sonido de mantener arco tensado
@export_category("Probabilidades de Audio")
@export var probabilidad_mantener_arco: float = 0.4 ## Probabilidad (0.0 - 1.0) de reproducir sonido al mantener arco al máximo
@export var delay_mantener_arco: float = 0.3 ## Segundos esperando al máximo antes de reproducir
var _bow_hold_played: bool = false

func play_bow_hold():
	if _bow_hold_played:
		return
	if randf() < probabilidad_mantener_arco:
		play_sfx("bow_hold", 6.0) # +6 dB = doble de volumen
		_bow_hold_played = true

func reset_bow_hold():
	_bow_hold_played = false

## Registrar muerte de enemigo y reproducir risa cada N kills
@export var kills_para_risa: int = 5 ## Cada cuántos kills evaluar la risa
@export var probabilidad_risa: float = 0.1 ## Probabilidad (0.0 - 1.0) de risa al alcanzar el múltiplo
@export var probabilidad_risa_goblin: float = 0.1 ## Probabilidad (0.0 - 1.0) de risa del goblin al acertar

func on_enemy_killed():
	player_kill_count += 1
	if player_kill_count % kills_para_risa == 0:
		if randf() < probabilidad_risa:
			play_sfx("player_laugh")

## Reproducir risa del goblin al acertar un objetivo (probabilidad configurable)
func play_goblin_laugh():
	if randf() < probabilidad_risa_goblin:
		play_sfx("goblin_laugh")

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

## Detener todos los sonidos (música + SFX + temporales)
func stop_all():
	music_player.stop()
	sfx_player.stop()
	if is_instance_valid(sfx_player_3d):
		sfx_player_3d.stop()
	for p in sfx_pool:
		p.stop()
	for p in sfx_3d_pool:
		p.stop()

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
