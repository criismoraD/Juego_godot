extends Node
## AudioManager - Singleton para gestión centralizada de audio
##
## Uso:
##   AudioManager.play_sfx("player_shoot")
##   AudioManager.play_sfx_3d("goblin_death", position)
##   AudioManager.play_music(1)
# === REPRODUCTORES ===
const MAX_POOL_SIZE = 16
const MAX_3D_POOL_SIZE = 16
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
var _sfx_pool_idx: int = 0  # OPT: Índice circular para O(1) en vez de scan lineal
var _sfx_3d_pool_idx: int = 0
# === PITCH DITHERING (variación aleatoria de tono) ===
var shoot_pitch_min: float = 0.85
var shoot_pitch_max: float = 1.15
var damage_pitch_min: float = 0.9
var damage_pitch_max: float = 1.1
# === VOLÚMENES ESPECÍFICOS (0-100) ===
var player_hurt_volume: float = 100.0  # Volumen de daño recibido
var enemy_damage_volume: float = 66.0  # Volumen de daño a enemigos
# === CONTADORES ===
var player_kill_count: int = 0


func _ready():
	_setup_players()
	_load_all_sounds()
	ShaderGlobals.asegurar_outline_global(true)

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
		load("res://Entities/Jugador_Arquera/DAÑO_PERSONAJE0.mp3"),
		load("res://Entities/Jugador_Arquera/DAÑO_PERSONAJE1.mp3"),
		load("res://Entities/Jugador_Arquera/DAÑO_PERSONAJE3.mp3")
	]

	sfx_streams["player_death"] = [load("res://Entities/Jugador_Arquera/SFX_player_death.mp3")]

	sfx_streams["player_shoot"] = [
		load("res://Entities/Jugador_Arquera/DISPARO_FLECHA1.mp3"),
		load("res://Entities/Jugador_Arquera/DISPARO_FLECHA2.mp3")
	]

	sfx_streams["disparo_cargado"] = [load("res://TEST_/Disparo cargado.wav")]
	sfx_streams["sonido_100_carga"] = [load("res://TEST_/sonido 100% carga.mp3")]

	sfx_streams["bow_tension"] = [
		load("res://Entities/Jugador_Arquera/TENSADO_CUERDA1.mp3"),
		load("res://Entities/Jugador_Arquera/TENSADO_CUERDA2.mp3")
	]

	sfx_streams["fuego_tensado"] = [load("res://TEST_/Fuego tensado.wav")]

	sfx_streams["bow_hold"] = [load("res://Entities/Jugador_Arquera/MANTENER_ARCO.mp3")]

	sfx_streams["player_laugh"] = [load("res://Entities/Jugador_Arquera/RISA_PERSONAJE.mp3")]

	sfx_streams["obtencion_arma"] = [load("res://TEST_/Obtener arma.wav")]

	# ═══════════════════════════════════════════════════════════════════════════════
	# SONIDOS DE ENEMIGOS
	# ═══════════════════════════════════════════════════════════════════════════════
	sfx_streams["goblin_shoot"] = [
		load("res://Entities/Enemigo_Goblin/DISPARO_Ballesta 1.mp3"),
		load("res://Entities/Enemigo_Goblin/DISPARO_Ballesta 2.mp3"),
		load("res://Entities/Enemigo_Goblin/DISPARO_Ballesta 3.mp3")
	]

	sfx_streams["goblin_death"] = [
		load("res://Entities/Enemigo_Goblin/MUERTE_GOBLING_1.mp3"),
		load("res://Entities/Enemigo_Goblin/MUERTE_GOBLING_2.mp3"),
		load("res://Entities/Enemigo_Goblin/MUERTE_GOBLING_3.mp3"),
		load("res://Entities/Enemigo_Goblin/MUERTE_GOBLING_4.mp3")
	]

	sfx_streams["goblin_explosive_death"] = [
		load("res://Entities/Enemigo_Goblin/GOBLING_MUERTE_EXPLOSIVA_1.mp3"),
		load("res://Entities/Enemigo_Goblin/GOBLING_MUERTE_EXPLOSIVA_2.mp3")
	]
	sfx_streams["gobling_muerte_explosiva"] = sfx_streams["goblin_explosive_death"]

	sfx_streams["goblin_laugh"] = [load("res://Entities/Enemigo_Goblin/RISA_GOBLING_3.mp3")]

	sfx_streams["goblin_girl_shoot"] = sfx_streams["player_shoot"]  # Usa el mismo arco

	sfx_streams["goblin_girl_death"] = [
		load("res://Entities/Enemigo_Goblin_Girl/SFX_goblin_girl_death1.mp3"),
		load("res://Entities/Enemigo_Goblin_Girl/SFX_goblin_girl_death2.mp3"),
		load("res://Entities/Enemigo_Goblin_Girl/SFX_goblin_girl_death3.mp3")
	]

	sfx_streams["imp_death"] = [
		load("res://Entities/Enemigo_Imp/MUERTE_IMP1.mp3"),
		load("res://Entities/Enemigo_Imp/MUERTE_IMP2.mp3")
	]

	sfx_streams["explosion_muerte"] = [
		load("res://Entities/Enemigo_Imp/EXPLOCION_Muerte1.mp3"),
		load("res://Entities/Enemigo_Imp/EXPLOCION_Muerte2.mp3"),
		load("res://Entities/Enemigo_Imp/EXPLOCION_Muerte3.mp3")
	]

	sfx_streams["explosion_flecha_explosiva"] = [
		load("res://System/Audio/SFX/explocion_flecha_explociva.mp3")
	]

	sfx_streams["cuerno_guerra"] = [
		load("res://System/Audio/SFX/Cuerno de guerra.mp3")
	]

	sfx_streams["trident_shot"] = [load("res://Entities/Enemigo_Imp/TRIDENTE_SHOT.mp3")]

	sfx_streams["shield_imp_impact"] = [
		load("res://Entities/Enemigo_Imp_Escudo/IMPACTO_IMP_ESCUDO_01.mp3"),
		load("res://Entities/Enemigo_Imp_Escudo/IMPACTO_IMP_ESCUDO_02.mp3")
	]

	sfx_streams["shield_imp_death"] = [
		load("res://Entities/Enemigo_Imp_Escudo/MUERTE_IMP_ESCUDO_01.mp3"),
		load("res://Entities/Enemigo_Imp_Escudo/MUERTE_IMP_ESCUDO_2.mp3")
	]

	sfx_streams["gargola_fire"] = [
		load("res://Entities/Enemigo_Gargola/ffuego gargola.mp3"),
		load("res://Entities/Enemigo_Gargola/ffuego gargola 2.mp3")
	]

	sfx_streams["gargola_impacto"] = [
		load("res://Entities/Enemigo_Gargola/IMPACTO_FUEGO_01.mp3"),
		load("res://Entities/Enemigo_Gargola/IMPACTO_FUEGO_02.mp3")
	]

	sfx_streams["gargola_herida"] = [
		load("res://Entities/Enemigo_Gargola/IMPACTO_HERIDA_01.mp3"),
		load("res://Entities/Enemigo_Gargola/IMPACTO_HERIDA_02.mp3")
	]

	sfx_streams["gargola_death"] = [
		load("res://Entities/Enemigo_Gargola/Muerte new1.mp3"),
		load("res://Entities/Enemigo_Gargola/Muerte new2.mp3")
	]

	# ═══════════════════════════════════════════════════════════════════════════════
	# SONIDOS DE AMBIENTE / ESCUDOS
	# ═══════════════════════════════════════════════════════════════════════════════
	sfx_streams["shield_hit_crossbow"] = [
		load("res://Entities/Ambiente_Escudo/IMPACTO_ESCUDO_BALLESTA.mp3")
	]

	sfx_streams["shield_hit_arrow"] = [
		load("res://Entities/Ambiente_Escudo/IMPACTO_ESCUDO_FLECHA.mp3")
	]
	sfx_streams["arrow_impact"] = sfx_streams["shield_hit_arrow"]
	sfx_streams["impacto_flecha"] = sfx_streams["shield_hit_arrow"]
	sfx_streams["flecha_impacto"] = sfx_streams["shield_hit_arrow"]

	# Alias genérico para compatibilidad
	sfx_streams["shield_hit"] = sfx_streams["shield_hit_crossbow"]

	sfx_streams["shield_break"] = [load("res://Entities/Ambiente_Escudo/ESCUDO_ROTO.mp3")]
	sfx_streams["refuerzo_escudo"] = [load("res://System/Audio/SFX/Refuerzo_escudo.mp3")]
	sfx_streams["parry"] = [load("res://System/Audio/SFX/Parry.mp3")]
	sfx_streams["aura_parry"] = sfx_streams["parry"]
	sfx_streams["aura"] = [load("res://System/Audio/SFX/Aura.mp3")]
	sfx_streams["aura_loop"] = sfx_streams["aura"]
	sfx_streams["sangre_splash"] = [load("res://Entities/Enemigo_Goblin/Muerte_Explotado/Sangre_splash.mp3")]

	# ═══════════════════════════════════════════════════════════════════════════════
	# SONIDOS DE DEFENSORA BALLESTERA
	# ═══════════════════════════════════════════════════════════════════════════════
	sfx_streams["muerte_ballestera"] = [load("res://Entities/Aliada_Ballestera/Audio/Muerte_ballestera.mp3")]
	sfx_streams["ballestera_death"] = sfx_streams["muerte_ballestera"]
	sfx_streams["risa_victoria_ballestera"] = [load("res://Entities/Aliada_Ballestera/Audio/Risa_victoria_ballestera.mp3")]
	sfx_streams["ballestera_victoria"] = sfx_streams["risa_victoria_ballestera"]
	sfx_streams["ballestera_laugh"] = sfx_streams["risa_victoria_ballestera"]

	var _sfx_recarga_ballesta: AudioStream = null
	if ResourceLoader.exists("res://Entities/Aliada_Ballestera/Audio/recarga_ballesta.wav"):
		_sfx_recarga_ballesta = load("res://Entities/Aliada_Ballestera/Audio/recarga_ballesta.wav") as AudioStream
	elif ResourceLoader.exists("res://TEST_/recarga_ballesta.wav"):
		_sfx_recarga_ballesta = load("res://TEST_/recarga_ballesta.wav") as AudioStream
	elif ResourceLoader.exists("res://Entities/Aliada_Ballestera/Audio/recarga_ballesta.mp3"):
		_sfx_recarga_ballesta = load("res://Entities/Aliada_Ballestera/Audio/recarga_ballesta.mp3") as AudioStream
	elif ResourceLoader.exists("res://TEST_/recarga_ballesta.mp3"):
		_sfx_recarga_ballesta = load("res://TEST_/recarga_ballesta.mp3") as AudioStream

	if _sfx_recarga_ballesta:
		sfx_streams["recarga_ballesta"] = [_sfx_recarga_ballesta]
		sfx_streams["recarga_ballestera"] = [_sfx_recarga_ballesta]
		sfx_streams["recarga ballesta"] = [_sfx_recarga_ballesta]
		sfx_streams["crossbow_reload"] = [_sfx_recarga_ballesta]
	elif sfx_streams.has("bow_tension"):
		sfx_streams["recarga_ballesta"] = sfx_streams["bow_tension"]


	# Sonido de correr descalzo (Lonko y Goblina Pesada)
	var _sfx_correr: AudioStream = null
	if ResourceLoader.exists("res://System/Audio/SFX/sonido_correr_descalzo.wav"):
		_sfx_correr = load("res://System/Audio/SFX/sonido_correr_descalzo.wav") as AudioStream
	elif ResourceLoader.exists("res://TEST_/sonido_correr_descalzo.wav"):
		_sfx_correr = load("res://TEST_/sonido_correr_descalzo.wav") as AudioStream
	elif ResourceLoader.exists("res://System/Audio/SFX/sonido_correr_descalzo.mp3"):
		_sfx_correr = load("res://System/Audio/SFX/sonido_correr_descalzo.mp3") as AudioStream
	elif ResourceLoader.exists("res://TEST_/sonido_correr_descalzo.mp3"):
		_sfx_correr = load("res://TEST_/sonido_correr_descalzo.mp3") as AudioStream
	if _sfx_correr:
		sfx_streams["correr_descalzo"] = [_sfx_correr]
		sfx_streams["sonido_correr_descalzo"] = [_sfx_correr]

	# Sonido de escalera (pasos al subir/bajar; loop gestionado por el llamador)
	# NOTA: el archivo original venía como .mp3 pero era un WAV renombrado y
	# Godot no podía importarlo; ahora es un .wav real.
	var _sfx_escalera: AudioStream = null
	if ResourceLoader.exists("res://System/Audio/SFX/Subir escaleras.wav"):
		_sfx_escalera = load("res://System/Audio/SFX/Subir escaleras.wav") as AudioStream
	elif ResourceLoader.exists("res://TEST_/Subir escaleras.wav"):
		_sfx_escalera = load("res://TEST_/Subir escaleras.wav") as AudioStream
	if _sfx_escalera:
		sfx_streams["subir_escaleras"] = [_sfx_escalera]

	# Sonidos Goblina Escudo Pesado
	var _sfx_jabalina: AudioStream = null
	if ResourceLoader.exists("res://System/Audio/SFX/Goblina jabalina.wav"):
		_sfx_jabalina = load("res://System/Audio/SFX/Goblina jabalina.wav") as AudioStream
	elif ResourceLoader.exists("res://TEST_/Goblina jabalina.wav"):
		_sfx_jabalina = load("res://TEST_/Goblina jabalina.wav") as AudioStream
	elif ResourceLoader.exists("res://System/Audio/SFX/Goblina jabalina.mp3"):
		_sfx_jabalina = load("res://System/Audio/SFX/Goblina jabalina.mp3") as AudioStream
	elif ResourceLoader.exists("res://TEST_/Goblina jabalina.mp3"):
		_sfx_jabalina = load("res://TEST_/Goblina jabalina.mp3") as AudioStream
	if _sfx_jabalina:
		sfx_streams["goblina_jabalina"] = [_sfx_jabalina]
		sfx_streams["Goblina jabalina"] = [_sfx_jabalina]

	var _sfx_goblina_ataque: AudioStream = null
	if ResourceLoader.exists("res://System/Audio/SFX/goblina ataque.wav"):
		_sfx_goblina_ataque = load("res://System/Audio/SFX/goblina ataque.wav") as AudioStream
	elif ResourceLoader.exists("res://TEST_/goblina ataque.wav"):
		_sfx_goblina_ataque = load("res://TEST_/goblina ataque.wav") as AudioStream
	elif ResourceLoader.exists("res://System/Audio/SFX/goblina ataque.mp3"):
		_sfx_goblina_ataque = load("res://System/Audio/SFX/goblina ataque.mp3") as AudioStream
	elif ResourceLoader.exists("res://TEST_/goblina ataque.mp3"):
		_sfx_goblina_ataque = load("res://TEST_/goblina ataque.mp3") as AudioStream
	if _sfx_goblina_ataque:
		sfx_streams["goblina_ataque"] = [_sfx_goblina_ataque]
		sfx_streams["goblina ataque"] = [_sfx_goblina_ataque]
		sfx_streams["goblina atque"] = [_sfx_goblina_ataque]

	var _sfx_goblina_dano: AudioStream = null
	if ResourceLoader.exists("res://System/Audio/SFX/Goblina daño.wav"):
		_sfx_goblina_dano = load("res://System/Audio/SFX/Goblina daño.wav") as AudioStream
	elif ResourceLoader.exists("res://TEST_/Goblina daño.wav"):
		_sfx_goblina_dano = load("res://TEST_/Goblina daño.wav") as AudioStream
	elif ResourceLoader.exists("res://System/Audio/SFX/Goblina daño.mp3"):
		_sfx_goblina_dano = load("res://System/Audio/SFX/Goblina daño.mp3") as AudioStream
	elif ResourceLoader.exists("res://TEST_/Goblina daño.mp3"):
		_sfx_goblina_dano = load("res://TEST_/Goblina daño.mp3") as AudioStream
	if _sfx_goblina_dano:
		sfx_streams["goblina_dano"] = [_sfx_goblina_dano]
		sfx_streams["Goblina daño"] = [_sfx_goblina_dano]

	var _sfx_goblina_muerte: AudioStream = null
	if ResourceLoader.exists("res://System/Audio/SFX/goblina muerte.wav"):
		_sfx_goblina_muerte = load("res://System/Audio/SFX/goblina muerte.wav") as AudioStream
	elif ResourceLoader.exists("res://TEST_/goblina muerte.wav"):
		_sfx_goblina_muerte = load("res://TEST_/goblina muerte.wav") as AudioStream
	elif ResourceLoader.exists("res://System/Audio/SFX/goblina muerte.mp3"):
		_sfx_goblina_muerte = load("res://System/Audio/SFX/goblina muerte.mp3") as AudioStream
	elif ResourceLoader.exists("res://TEST_/goblina muerte.mp3"):
		_sfx_goblina_muerte = load("res://TEST_/goblina muerte.mp3") as AudioStream
	if _sfx_goblina_muerte:
		sfx_streams["goblina_muerte"] = [_sfx_goblina_muerte]
		sfx_streams["goblina muerte"] = [_sfx_goblina_muerte]

	# Sonido de muerte por daño crítico (remata con golpe vulnerable en pleno ataque)
	# NOTA: el archivo original venía como .mp3 pero era un WAV renombrado.
	var _sfx_muerte_critica: AudioStream = null
	if ResourceLoader.exists("res://System/Audio/SFX/Critico.wav"):
		_sfx_muerte_critica = load("res://System/Audio/SFX/Critico.wav") as AudioStream
	elif ResourceLoader.exists("res://TEST_/Critico.wav"):
		_sfx_muerte_critica = load("res://TEST_/Critico.wav") as AudioStream
	if _sfx_muerte_critica:
		sfx_streams["muerte_critica"] = [_sfx_muerte_critica]

	var _sfx_impacto_escudo: AudioStream = null
	if sfx_streams.has("shield_hit"):
		_sfx_impacto_escudo = sfx_streams["shield_hit"][0]
	if _sfx_impacto_escudo:
		sfx_streams["impacto_escudo_pesado"] = [_sfx_impacto_escudo]

	var _sfx_escudo_cayendo: AudioStream = null
	if ResourceLoader.exists("res://System/Audio/SFX/Escudo metal callendo.wav"):
		_sfx_escudo_cayendo = load("res://System/Audio/SFX/Escudo metal callendo.wav") as AudioStream
	elif ResourceLoader.exists("res://TEST_/Escudo metal callendo.wav"):
		_sfx_escudo_cayendo = load("res://TEST_/Escudo metal callendo.wav") as AudioStream
	if _sfx_escudo_cayendo:
		sfx_streams["escudo_metal_cayendo"] = [_sfx_escudo_cayendo]
		sfx_streams["Escudo metal callendo"] = [_sfx_escudo_cayendo]
		sfx_streams["escudo_cayendo"] = [_sfx_escudo_cayendo]


	# ═══════════════════════════════════════════════════════════════════════════════
	# MÚSICA
	# ═══════════════════════════════════════════════════════════════════════════════
	bgm_streams.append(null)  # Índice 0 = silencio
	bgm_streams.append(load("res://System/Audio/Music/BGM_main_theme.mp3"))  # Índice 1
	bgm_streams.append(load("res://System/Audio/Music/BGM_battle.mp3"))  # Índice 2
	bgm_streams.append(load("res://System/Audio/Music/SONIDO BOSQUE.mp3"))  # Índice 3 - Nivel 0 pacifista
	bgm_streams.append(load("res://System/Audio/Music/VICTORY.mp3"))  # Índice 4 - Victoria
	bgm_streams.append(load("res://System/Audio/Music/Noche Aplastante.mp3"))  # Índice 5 - Noche Aplastante (Oleada 5)
	bgm_streams.append(load("res://TEST_/Torre interior.mp3"))  # Índice 6 - Torre interior


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


## Devuelve el stream de un SFX registrado, para loops gestionados por el
## llamador (ej.: sonido de escalera sincronizado con la animación de trepar).
## Retorna null si el sonido no existe.
func obtener_stream_sfx(sound_name: String) -> AudioStream:
	if not sfx_streams.has(sound_name):
		return null
	var sounds: Array = sfx_streams[sound_name]
	if sounds.is_empty():
		return null
	return sounds[0] as AudioStream


## Reproduce un efecto de sonido (selección aleatoria si hay variantes)
## Usa reproductores temporales para permitir sonidos simultáneos
## pitch_override > 0 fuerza esa velocidad de reproducción (1.0 = normal)
func play_sfx(sound_name: String, volume_boost_db: float = 0.0, pitch_override: float = 0.0):
	if not sfx_streams.has(sound_name):
		push_warning("[AudioManager] Sonido no encontrado: " + sound_name)
		return

	var sounds = sfx_streams[sound_name]
	if sounds.is_empty():
		return

	var sound = sounds[randi() % sounds.size()]
	if sound == null:
		push_warning("[AudioManager] Recurso de audio nulo en: " + sound_name + " (reimportar el archivo)")
		return
	if sound:
		# Usar object pooling
		var temp_player = _get_available_sfx_player()
		temp_player.stream = sound

		# Determinar volumen según tipo de sonido
		var volume_to_use = sfx_volume_db
		if sound_name == "player_hurt" or sound_name == "player_death":
			# Usar volumen de daño al jugador
			volume_to_use = _get_specific_volume_db(player_hurt_volume)
		elif sound_name == "goblin_death":
			# Muerte normal del goblin ballestero reducida un 20% (-1.9 dB)
			volume_to_use = _get_specific_volume_db(enemy_damage_volume) - 1.9
			# Variante 3 (MUERTE_GOBLING_3.mp3) demasiado alta: -6.0 dB extra
			if sound and sound.resource_path == "res://Entities/Enemigo_Goblin/MUERTE_GOBLING_3.mp3":
				volume_to_use -= 6.0
		elif sound_name == "goblin_girl_death":
			# Usar volumen de daño a enemigos
			volume_to_use = _get_specific_volume_db(enemy_damage_volume)
		elif sound_name in ["goblin_explosive_death", "gobling_muerte_explosiva"]:
			# Muerte explosiva de goblin aumentada un 50% (+3.5 dB)
			volume_to_use = _get_specific_volume_db(enemy_damage_volume) + 3.5
		elif sound_name == "imp_death":
			# Imp muerte al doble de volumen
			volume_to_use = _get_specific_volume_db(enemy_damage_volume) + 6.0
		elif sound_name == "gargola_death":
			# Muerte de gárgola reducida un 30% (-3.1 dB)
			volume_to_use = _get_specific_volume_db(enemy_damage_volume) - 3.1
		elif sound_name in ["gargola_fire", "gargola_impacto"]:
			# Fuego e impacto de gárgola reducidos un 60% (-8.0 dB)
			volume_to_use = sfx_volume_db - 8.0
		elif sound_name == "explosion_muerte":
			# Explosión 3x más fuerte
			volume_to_use = _get_specific_volume_db(enemy_damage_volume) + 10.0
		elif sound_name == "sangre_splash":
			# Splash de sangre balanceado para evitar volumen excesivo o duplicado
			volume_to_use = sfx_volume_db - 6.0
		elif sound_name == "muerte_critica":
			# Muerte por golpe crítico: fuente TEST_ a ~-36 dBFS RMS, necesita realce fuerte
			volume_to_use = sfx_volume_db + 12.0
		elif sound_name in ["escudo_metal_cayendo", "Escudo metal callendo", "escudo_cayendo"]:
			# Volumen reducido a pedido: contundente pero sin saturar
			volume_to_use = sfx_volume_db - 1.0


		temp_player.volume_db = volume_to_use + volume_boost_db
		temp_player.bus = "Master"

		# Pitch dithering (o velocidad forzada si se indica)
		if pitch_override > 0.0:
			temp_player.pitch_scale = pitch_override
		elif "shoot" in sound_name:
			temp_player.pitch_scale = randf_range(shoot_pitch_min, shoot_pitch_max)
		elif "hurt" in sound_name or "death" in sound_name or "impact" in sound_name or "hit" in sound_name:
			temp_player.pitch_scale = randf_range(damage_pitch_min, damage_pitch_max)
		else:
			temp_player.pitch_scale = 1.0

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
		var volume_to_use = sfx_volume_db + 5.0  # Boost adicional
		if sound_name == "gargola_death":
			volume_to_use -= 3.1
		elif sound_name in ["gargola_fire", "gargola_impacto"]:
			volume_to_use -= 8.0
		temp_player.volume_db = volume_to_use

		# Pitch dithering
		if "shoot" in sound_name:
			temp_player.pitch_scale = randf_range(shoot_pitch_min, shoot_pitch_max)
		elif "hurt" in sound_name or "death" in sound_name or "impact" in sound_name or "hit" in sound_name:
			temp_player.pitch_scale = randf_range(damage_pitch_min, damage_pitch_max)

		if not temp_player.is_inside_tree():
			add_child(temp_player)
		temp_player.global_position = position
		temp_player.play()


# Offsets de volumen específicos por pista para balancear la mezcla
var bgm_volume_offsets: Dictionary = {
	1: -5.0,  ## BGM_main_theme (-20.0 dB base, reducido -5.0 dB)
	2: 0.0,   ## BGM_battle (-15.0 dB base)
	3: 12.0,  ## SONIDO BOSQUE (-3.0 dB base)
	4: 0.0,   ## VICTORY (-15.0 dB base)
	5: 2.0,   ## Noche Aplastante (Oleada 5: -13.0 dB base, aumentado +4.0 dB)
	6: 0.0,   ## Torre interior (-15.0 dB base)
}


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
		var track_offset: float = bgm_volume_offsets.get(index, 0.0)
		music_player.volume_db = music_volume_db + track_offset + volume_boost_db
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
@export var probabilidad_mantener_arco: float = 0.4  ## Probabilidad (0.0 - 1.0) de reproducir sonido al mantener arco al máximo
@export var delay_mantener_arco: float = 0.3  ## Segundos esperando al máximo antes de reproducir
var _bow_hold_played: bool = false


func play_bow_hold():
	if _bow_hold_played:
		return
	if randf() < probabilidad_mantener_arco:
		play_sfx("bow_hold", 6.0)  # +6 dB = doble de volumen
		_bow_hold_played = true


func reset_bow_hold():
	_bow_hold_played = false


## Registrar muerte de enemigo y reproducir risa cada N kills
@export var kills_para_risa: int = 5  ## Cada cuántos kills evaluar la risa
@export var probabilidad_risa: float = 0.1  ## Probabilidad (0.0 - 1.0) de risa al alcanzar el múltiplo
@export var probabilidad_risa_goblin: float = 0.1  ## Probabilidad (0.0 - 1.0) de risa del goblin al acertar


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
		if is_instance_valid(p):
			p.stop()
	for p in sfx_3d_pool:
		if is_instance_valid(p):
			p.stop()
	var tree := get_tree()
	if tree:
		for node in tree.get_nodes_in_group("pausable_audio"):
			if is_instance_valid(node) and (node is AudioStreamPlayer or node is AudioStreamPlayer3D):
				node.stop()


## Pausa o reanuda todos los sonidos y la música activas en el juego
func pause_all_sfx(p_paused: bool) -> void:
	if is_instance_valid(sfx_player):
		sfx_player.stream_paused = p_paused
	if is_instance_valid(sfx_player_3d):
		sfx_player_3d.stream_paused = p_paused
	if is_instance_valid(music_player):
		music_player.stream_paused = p_paused

	for p in sfx_pool:
		if is_instance_valid(p):
			p.stream_paused = p_paused

	for p3d in sfx_3d_pool:
		if is_instance_valid(p3d):
			p3d.stream_paused = p_paused

	var tree := get_tree()
	if tree:
		for node in tree.get_nodes_in_group("pausable_audio"):
			if is_instance_valid(node) and (node is AudioStreamPlayer or node is AudioStreamPlayer3D):
				node.stream_paused = p_paused


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


## Reproducir sonido de escudo metálico cayendo al suelo con volumen aumentado
func play_escudo_metal_cayendo(volume_boost: float = 0.0) -> void:
	play_sfx("escudo_metal_cayendo", volume_boost)

