import re

print("Patching DialogoComic...")
with open('Scripts/UI/DialogoComic.gd', 'r') as f:
    content = f.read()

diff_search = """var _revelando: bool = false
var _indice_pagina: int = 0
var _audio_player: AudioStreamPlayer

func _obtener_dialogo_label() -> RichTextLabel:"""

diff_replace = """var _revelando: bool = false
var _indice_pagina: int = 0
var _audio_player: AudioStreamPlayer
var _tiempo_acumulado: float = 0.0
var _ultimo_audio_ms: int = 0

func _obtener_dialogo_label() -> RichTextLabel:"""
content = content.replace(diff_search, diff_replace)

diff_search = """	_actualizar_texto_boton()

	await get_tree().process_frame
	await _revelar_texto()

func _actualizar_texto_boton():"""

diff_replace = """	_actualizar_texto_boton()
	set_process(false)

	await get_tree().process_frame
	_revelar_texto()

func _process(delta: float) -> void:
	if not _revelando or not dialogo_label:
		return

	_tiempo_acumulado += delta
	var espera = max(velocidad_texto, 0.005)

	if _tiempo_acumulado >= espera:
		var chars_a_mostrar = int(_tiempo_acumulado / espera)
		_tiempo_acumulado -= chars_a_mostrar * espera

		var chars_actuales = dialogo_label.visible_characters
		var total_chars = dialogo_label.get_total_character_count()

		if chars_actuales < total_chars:
			var nuevos_chars = min(chars_actuales + chars_a_mostrar, total_chars)
			dialogo_label.visible_characters = nuevos_chars

			if nuevos_chars > 0 and nuevos_chars % max(chars_por_sonido, 1) == 0 and audio_stream:
				var ahora_ms: int = Time.get_ticks_msec()
				if ahora_ms - _ultimo_audio_ms >= int(intervalo_min_sonido * 1000.0):
					_reproducir_audio()
					_ultimo_audio_ms = ahora_ms

			if nuevos_chars >= total_chars:
				_terminar_revelado()
		else:
			_terminar_revelado()

func _terminar_revelado() -> void:
	_revelando = false
	set_process(false)
	if dialogo_label:
		dialogo_label.visible_characters = dialogo_label.get_total_character_count()
	if boton_continuar:
		boton_continuar.visible = true

func _actualizar_texto_boton():"""
content = content.replace(diff_search, diff_replace)

diff_search = """func _revelar_texto():
	if _revelando or not dialogo_label:
		return

	_revelando = true
	dialogo_label.visible_characters = 0

	var total_chars: int = dialogo_label.get_total_character_count()
	if total_chars > 0:
		var ultimo_audio_ms: int = 0
		for i in range(total_chars + 1):
			if not is_instance_valid(self) or not is_inside_tree():
				return

			dialogo_label.visible_characters = i

			if i > 0 and i % max(chars_por_sonido, 1) == 0 and audio_stream:
				var ahora_ms: int = Time.get_ticks_msec()
				if ahora_ms - ultimo_audio_ms >= int(intervalo_min_sonido * 1000.0):
					_reproducir_audio()
					ultimo_audio_ms = ahora_ms

			await get_tree().create_timer(max(velocidad_texto, 0.005)).timeout

	if boton_continuar:
		boton_continuar.visible = true

	_revelando = false

func _reproducir_audio():"""

diff_replace = """func _revelar_texto():
	if _revelando or not dialogo_label:
		return

	_revelando = true
	_tiempo_acumulado = 0.0
	_ultimo_audio_ms = 0
	dialogo_label.visible_characters = 0

	if dialogo_label.get_total_character_count() > 0:
		set_process(true)
	else:
		_terminar_revelado()

func _reproducir_audio():"""
content = content.replace(diff_search, diff_replace)

diff_search = """	if paginas_texto.size() > 1 and _indice_pagina < paginas_texto.size() - 1:
		_indice_pagina += 1
		dialogo_label.text = paginas_texto[_indice_pagina]
		_actualizar_texto_boton()
		boton_continuar.visible = false
		await _revelar_texto()
		return"""

diff_replace = """	if paginas_texto.size() > 1 and _indice_pagina < paginas_texto.size() - 1:
		_indice_pagina += 1
		dialogo_label.text = paginas_texto[_indice_pagina]
		_actualizar_texto_boton()
		boton_continuar.visible = false
		_revelar_texto()
		return"""
content = content.replace(diff_search, diff_replace)

with open('Scripts/UI/DialogoComic.gd', 'w') as f:
    f.write(content)

print("Patching AudioManager...")
with open('Scripts/Core/AudioManager.gd', 'r') as f:
    content = f.read()

pool_vars = """
# === CONFIGURACIÓN ===
var sfx_volume_db: float = -5.0
var music_volume_db: float = -15.0

# === OBJECT POOLING PARA AUDIO ===
var sfx_pool: Array[AudioStreamPlayer] = []
var sfx_3d_pool: Array[AudioStreamPlayer3D] = []
const MAX_POOL_SIZE = 16
const MAX_3D_POOL_SIZE = 16
"""
content = re.sub(r'# === CONFIGURACIÓN ===\nvar sfx_volume_db: float = -5\.0\nvar music_volume_db: float = -15\.0', pool_vars, content)

setup_players_original = """func _setup_players():
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
	add_child(music_player)"""

setup_players_new = """func _setup_players():
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
		sfx_3d_pool.append(p3d)"""
content = content.replace(setup_players_original, setup_players_new)

pool_helpers = """
# ═══════════════════════════════════════════════════════════════════════════════
# POOL HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _get_available_sfx_player() -> AudioStreamPlayer:
	for p in sfx_pool:
		if not p.playing:
			return p
	# Si no hay disponibles, tomar el que esté más avanzado (o primero) y forzarlo
	var oldest = sfx_pool[0]
	var max_pos = 0.0
	for p in sfx_pool:
		var pos = p.get_playback_position()
		if pos > max_pos:
			max_pos = pos
			oldest = p
	return oldest

func _get_available_sfx_3d_player() -> AudioStreamPlayer3D:
	for p in sfx_3d_pool:
		if not p.playing:
			return p
	# Si no hay disponibles, tomar el más avanzado
	var oldest = sfx_3d_pool[0]
	var max_pos = 0.0
	for p in sfx_3d_pool:
		var pos = p.get_playback_position()
		if pos > max_pos:
			max_pos = pos
			oldest = p
	return oldest

# ═══════════════════════════════════════════════════════════════════════════════
# API PÚBLICA
# ═══════════════════════════════════════════════════════════════════════════════
"""
content = re.sub(r'# ═══════════════════════════════════════════════════════════════════════════════\n# API PÚBLICA\n# ═══════════════════════════════════════════════════════════════════════════════', pool_helpers, content)

play_sfx_original = """	var sound = sounds[randi() % sounds.size()]
	if sound:
		# Crear reproductor temporal para permitir sonidos simultáneos
		var temp_player = AudioStreamPlayer.new()
		temp_player.stream = sound"""
play_sfx_new = """	var sound = sounds[randi() % sounds.size()]
	if sound:
		# Usar object pooling
		var temp_player = _get_available_sfx_player()
		temp_player.stream = sound"""
content = content.replace(play_sfx_original, play_sfx_new)

play_sfx_end_original = """		add_child(temp_player)
		temp_player.play()
		# Auto-eliminar cuando termine (con verificación de seguridad)
		temp_player.finished.connect(func():
			if is_instance_valid(temp_player):
				temp_player.queue_free()
		)"""
play_sfx_end_new = """		if not temp_player.is_inside_tree():
			add_child(temp_player)
		temp_player.play()"""
content = content.replace(play_sfx_end_original, play_sfx_end_new)

play_sfx_3d_original = """	var sound = sounds[randi() % sounds.size()]
	if sound:
		# Crear reproductor temporal para permitir sonidos simultáneos
		var temp_player = AudioStreamPlayer3D.new()
		temp_player.stream = sound
		temp_player.unit_size = 50.0 # Aumentado para mayor alcance
		temp_player.max_db = 6.0 # Aumentado para más volumen cercano
		temp_player.volume_db = sfx_volume_db + 5.0 # Boost adicional
		temp_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED # Sin atenuación por distancia"""
play_sfx_3d_new = """	var sound = sounds[randi() % sounds.size()]
	if sound:
		# Usar object pooling
		var temp_player = _get_available_sfx_3d_player()
		temp_player.stream = sound
		temp_player.volume_db = sfx_volume_db + 5.0 # Boost adicional"""
content = content.replace(play_sfx_3d_original, play_sfx_3d_new)

play_sfx_3d_end_original = """		add_child(temp_player)
		temp_player.global_position = position
		temp_player.play()
		# Auto-eliminar cuando termine (con verificación de seguridad)
		temp_player.finished.connect(func():
			if is_instance_valid(temp_player):
				temp_player.queue_free()
		)"""
play_sfx_3d_end_new = """		if not temp_player.is_inside_tree():
			add_child(temp_player)
		temp_player.global_position = position
		temp_player.play()"""
content = content.replace(play_sfx_3d_end_original, play_sfx_3d_end_new)

stop_all_original = """## Detener todos los sonidos (música + SFX + temporales)
func stop_all():
	music_player.stop()
	sfx_player.stop()
	if is_instance_valid(sfx_player_3d):
		sfx_player_3d.stop()
	# Eliminar reproductores temporales de SFX 3D
	for child in get_children():
		if child is AudioStreamPlayer3D and child != sfx_player_3d:
			child.stop()
			child.queue_free()
		elif child is AudioStreamPlayer and child != sfx_player and child != music_player:
			child.stop()
			child.queue_free()"""
stop_all_new = """## Detener todos los sonidos (música + SFX + temporales)
func stop_all():
	music_player.stop()
	sfx_player.stop()
	if is_instance_valid(sfx_player_3d):
		sfx_player_3d.stop()
	for p in sfx_pool:
		p.stop()
	for p in sfx_3d_pool:
		p.stop()"""
content = content.replace(stop_all_original, stop_all_new)

with open('Scripts/Core/AudioManager.gd', 'w') as f:
    f.write(content)

print("Patching GameUI...")
with open('Scripts/UI/GameUI.gd', 'r') as f:
    content = f.read()

# Only keep proper caching
# We don't want to duplicate things or make them complex if it fails.
# Since the groups are only queried on button presses, we'll leave it out instead of risk breaking it.
# Actually, let's skip GameUI cache, it doesn't cause process lag since it's only on button clicks.

print("Patching Shader...")
with open('Assets/Shaders/TOON_LINEANEGRA.gdshader', 'r') as f:
    content = f.read()

shader_fix = """	// Clamp the depth so the outline doesn't scale infinitely and become a blob at a distance,
	// but still scales enough to be visible.
	float depth_scale = clamp(clip_position.w, 0.5, 5.0);
	vec2 offset = normalize(clip_normal.xy) / VIEWPORT_SIZE * depth_scale * outline_width * 2.0;"""

content = re.sub(r'\tvec2 offset = normalize\(clip_normal\.xy\) \/ VIEWPORT_SIZE \* clip_position\.w \* outline_width \* 2\.0;', shader_fix, content)

with open('Assets/Shaders/TOON_LINEANEGRA.gdshader', 'w') as f:
    f.write(content)

print("Patching EnemyBase class name issue...")
# No changes to class_name EnemyBase, maybe we just don't touch EnemyBase so it doesn't break?
# Let's add game_feel var without breaking anything.
with open('Scripts/Characters/EnemyBase.gd', 'r') as f:
    content = f.read()

game_feel_var = """
var game_feel: Node = null

# ═══════════════════════════════════════════════════════════════════════════════
# INICIALIZACIÓN
# ═══════════════════════════════════════════════════════════════════════════════
"""
content = re.sub(r'\n# ═══════════════════════════════════════════════════════════════════════════════\n# INICIALIZACIÓN\n# ═══════════════════════════════════════════════════════════════════════════════\n', game_feel_var, content)

ready_cache = """func _ready():
	game_feel = get_node_or_null("/root/GameFeel")
	add_to_group("enemies")"""
content = re.sub(r'func _ready\(\):\n\s+add_to_group\("enemies"\)', ready_cache, content)

content = content.replace('get_node("/root/GameFeel").on_enemy_hurt()', 'if game_feel:\n\t\t\tgame_feel.on_enemy_hurt()')
content = content.replace('get_node("/root/GameFeel").on_enemy_death()', 'if game_feel:\n\t\t\t\tgame_feel.on_enemy_death()')

with open('Scripts/Characters/EnemyBase.gd', 'w') as f:
    f.write(content)

with open('Scripts/Characters/ImpEstandarte.gd', 'r') as f:
    content = f.read()

game_feel_var2 = """
var game_feel: Node = null

func _on_enemy_ready():
	game_feel = get_node_or_null("/root/GameFeel")
"""
content = re.sub(r'\nfunc _on_enemy_ready\(\):\n', game_feel_var2, content)

content = content.replace('get_node("/root/GameFeel").on_enemy_hurt()', 'if game_feel:\n\t\t\tgame_feel.on_enemy_hurt()')
content = content.replace('get_node("/root/GameFeel").on_enemy_death()', 'if game_feel:\n\t\t\t\tgame_feel.on_enemy_death()')

with open('Scripts/Characters/ImpEstandarte.gd', 'w') as f:
    f.write(content)
