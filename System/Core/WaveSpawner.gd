class_name WaveSpawner
extends Node3D
# === CONFIGURACIÓN (Español) ===
signal oleada_iniciada(numero_oleada: int)
signal oleada_completada(numero_oleada: int)
signal goblin_spawneado(goblin: Node)
signal evento_cuerno_iniciado
@export_category("Spawner")
@export var escena_goblin: PackedScene  # Escena del goblin a instanciar
@export var escena_goblin_girl: PackedScene  # Escena de la goblin girl
@export var escena_imp: PackedScene  # Escena del imp enemigo
@export var escena_canonero: PackedScene  # Nueva escena del cañonero
@export var escena_gargola: PackedScene  # Escena de la gárgola voladora
@export var escena_lonko: PackedScene  # Escena del nuevo enemigo Lonko
@export var escena_arquera_rosa: PackedScene  # Escena de la nueva Arquera Rosa
@export var intervalo_aparicion: float = 5.0  # Segundos entre spawns (más lento)
@export var enemigos_por_oleada: int = 6  # Cantidad de enemigos por oleada
@export var tiempo_entre_oleadas: float = 5.0  # Descanso entre oleadas
@export var altura_spawn: float = 0.0  # Altura extra para spawnar sobre el suelo
@export_range(0.0, 1.0, 0.05) var probabilidad_goblin_girl: float = 0.5  # Probabilidad de que aparezca una Goblin Girl
@export_range(0.0, 1.0, 0.05) var probabilidad_imp: float = 0.2  # Probabilidad de que aparezca un Imp
@export_range(0.0, 1.0, 0.05) var probabilidad_canonero: float = 0.15  # Probabilidad del canonero
@export var probabilidad_igual: bool = false  ## Todos los enemigos tienen la misma probabilidad (33.3%)
@export var spawn_infinito: bool = false  ## Si es true, el spawn de enemigos es continuo e infinito
@export_category("Imp Escudo")
@export var escena_imp_escudo: PackedScene  ## Escena de la ImpShieldGirl
@export var max_imp_escudo_activos: int = 1  ## Máximo de ImpShieldGirl simultáneas
@export var enemigos_minimos_para_escudo: int = 1  ## Enemigos vivos necesarios para spawnear escudo
@export var intervalo_check_escudo: float = 8.0  ## Segundos entre checks de spawn de escudo
@export_category("Debug")
@export var debug_logs_enabled: bool = false
# === ESTADO ===
var forzar_tipo_enemigo: int = -1  ## -1=normal, 0=goblin, 1=goblin_girl, 2=imp, 3=canonero, 4=imp_escudo, 5=gargola, 6=lonko, 7=arquera_rosa
var current_wave: int = 0
var goblins_spawned_in_wave: int = 0
var spawn_timer: float = 0.0
var wave_cooldown: float = 0.0
var is_wave_active: bool = false
var active_goblins: Array = []
var shield_imps_activos: Array = []  ## Lista de ImpShieldGirls activas
var shield_spawn_timer: float = 5.0  ## Timer para spawn de escudo
var enemigos_muertos_en_oleada: int = 0  ## Contador de muertos para la UI
var max_shield_imps_to_spawn_this_wave: int = 0
var shield_imps_spawned_this_wave: int = 0
var oleada_combate: int = 0  ## Nivel/Oleada de combate configurada desde el nivel (1, 2, 3, 4, 5)
var cola_spawn: Array[PackedScene] = []  ## Cola de enemigos prediseñada para la oleada activa
var evento_cuerno_activado: bool = false
var evento_cuerno_en_progreso: bool = false
var refuerzos_cuerno_total: int = 10  ## Cantidad de refuerzos que trae el evento de cuerno activo
var refuerzos_cuerno_spawneados: int = 0

# === SEÑALES ===


func _ready():
	add_to_group("wave_spawners")
	# Cargar escenas si no están asignadas
	if not escena_goblin:
		escena_goblin = preload("res://Entities/Enemigo_Goblin/Goblin.tscn")
	if not escena_goblin_girl:
		escena_goblin_girl = preload("res://Entities/Enemigo_Goblin_Girl/GoblinGirl.tscn")
	if not escena_imp:
		escena_imp = preload("res://Entities/Enemigo_Imp/ImpEnemy.tscn")
	if not escena_canonero:
		escena_canonero = preload("res://Entities/Enemigo_Canonero/Canonero.tscn")
	if not escena_gargola:
		escena_gargola = preload("res://Entities/Enemigo_Gargola/Gargola.tscn")
	if not escena_lonko:
		escena_lonko = preload("res://Entities/Enemigo_Lonko/Lonko.tscn")
	if not escena_arquera_rosa:
		escena_arquera_rosa = preload("res://Entities/Enemigo_Arquera_Rosa/ArqueraRosa.tscn")

	if not escena_imp_escudo:
		escena_imp_escudo = preload("res://Entities/Enemigo_Imp_Escudo/ImpShieldGirl.tscn")

	# Precalentar pipelines gráficos de enemigos de forma asíncrona al inicio
	call_deferred("_precalentar_enemigos")

	# Iniciar primera oleada después de un delay
	wave_cooldown = 2.0


func _precalentar_enemigos() -> void:
	var escenas_prewarm: Array[PackedScene] = [
		escena_goblin,
		escena_goblin_girl,
		escena_imp,
		escena_canonero,
		escena_gargola,
		escena_lonko,
		escena_arquera_rosa,
		escena_imp_escudo
	]

	var holder := Node3D.new()
	holder.name = "EnemyPrewarmHolder"
	holder.position = Vector3(0.0, -300.0, 0.0)
	add_child(holder)

	for sc in escenas_prewarm:
		if not sc:
			continue
		var enemy = sc.instantiate()
		if enemy:
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
			holder.add_child(enemy)

	await get_tree().process_frame
	await get_tree().process_frame

	if is_instance_valid(holder):
		holder.queue_free()


func _process(delta):
	if not is_wave_active:
		wave_cooldown -= delta
		if wave_cooldown <= 0:
			_start_wave()
	else:
		spawn_timer -= delta
		if spawn_timer <= 0 and (spawn_infinito or goblins_spawned_in_wave < enemigos_por_oleada):
			_spawn_goblin()
			var intervalo_actual: float = (intervalo_aparicion / 2.0) if evento_cuerno_en_progreso else intervalo_aparicion
			spawn_timer = intervalo_actual

		# Verificar si la oleada terminó (OPT: solo si ya spawneamos todos y no es infinito)
		if not spawn_infinito and goblins_spawned_in_wave >= enemigos_por_oleada:
			_check_wave_complete()

	# Check de spawn de ImpShieldGirl (independiente de oleadas)
	_check_shield_imp_spawn(delta)


func _start_wave():
	current_wave += 1
	# Los enemigos ya presentes (pacíficos convertidos) cuentan como spawneados
	goblins_spawned_in_wave = active_goblins.size()
	enemigos_muertos_en_oleada = 0
	is_wave_active = true
	spawn_timer = 0.0  # Spawn inmediato al iniciar oleada
	
	shield_imps_spawned_this_wave = 0
	evento_cuerno_activado = false
	evento_cuerno_en_progreso = false
	refuerzos_cuerno_spawneados = 0

	_generar_cola_spawn()

	oleada_iniciada.emit(current_wave)


func _generar_cola_spawn() -> void:
	cola_spawn.clear()
	var wave_num = oleada_combate

	var pool: Array[PackedScene] = []

	if wave_num == 1:
		# Oleada 1: 6 imp normal, 5 goblin arquera, 1 imp escudo. Total: 12.
		for i in range(6):
			pool.append(escena_imp)
		for i in range(5):
			pool.append(escena_goblin_girl)
		pool.append(escena_imp_escudo)

	elif wave_num == 2:
		# Oleada 2: 2 imp escudo, 7 imp normal, 8 goblin arqueras, 8 goblin ballesta. Total: 25.
		for i in range(2):
			pool.append(escena_imp_escudo)
		for i in range(7):
			pool.append(escena_imp)
		for i in range(8):
			pool.append(escena_goblin_girl)
		for i in range(8):
			pool.append(escena_goblin)

	elif wave_num == 3:
		# Oleada 3: 4 imp escudo, 13 goblin arquera, 13 goblin ballesta. Total: 30.
		for i in range(4):
			pool.append(escena_imp_escudo)
		for i in range(13):
			pool.append(escena_goblin_girl)
		for i in range(13):
			pool.append(escena_goblin)

	elif wave_num == 4:
		# Oleada 4: 10 imp, 10 goblin ballesta (reemplaza arquera), 10 gárgola + 5 imp escudo garantizados (100%). Total: 35.
		# La primera en salir siempre es una gárgola.
		for i in range(5):
			pool.append(escena_imp_escudo)
		for i in range(10):
			pool.append(escena_gargola)
		for i in range(10):
			pool.append(escena_imp)
		for i in range(10):
			pool.append(escena_goblin)  # ballesta reemplaza a goblin_girl
		# Poner una gárgola al frente de la cola (sale primero)
		pool.push_front(escena_gargola)
		pool.pop_back()

	elif wave_num == 5:
		# Oleada 5: 40 enemigos totales
		# 11 Lonko (mínimo 10), 4 Imp Escudo, 7 Gárgolas, 9 Arqueras Goblin, 9 Goblins Ballesta. Total = 40.
		for i in range(11):
			pool.append(escena_lonko)
		for i in range(4):
			pool.append(escena_imp_escudo)
		for i in range(7):
			pool.append(escena_gargola)
		for i in range(9):
			pool.append(escena_goblin_girl)
		for i in range(9):
			pool.append(escena_goblin)

	else:
		return

	# Mezclar y verificar restricciones (no consecutivas, no al final)
	pool.shuffle()
	var intentos := 0
	while not _es_valida_cola(pool) and intentos < 150:
		pool.shuffle()
		intentos += 1

	cola_spawn = pool


func _es_valida_cola(pool: Array[PackedScene]) -> bool:
	if pool.is_empty():
		return true
	if pool.back() == escena_imp_escudo:
		return false
	for i in range(pool.size() - 1):
		if pool[i] == escena_imp_escudo and pool[i+1] == escena_imp_escudo:
			return false
	return true


func _elegir_escena_probabilidades() -> PackedScene:
	# Lógica para obligar/calcular el spawn de shield imps en la oleada
	if max_shield_imps_to_spawn_this_wave > 0:
		var remaining_shield_imps = max_shield_imps_to_spawn_this_wave - shield_imps_spawned_this_wave
		var remaining_total_spawns = enemigos_por_oleada - goblins_spawned_in_wave
		
		if remaining_total_spawns <= remaining_shield_imps and remaining_shield_imps > 0:
			shield_imps_spawned_this_wave += 1
			return escena_imp_escudo
		elif remaining_shield_imps > 0 and randf() < (float(remaining_shield_imps) / float(remaining_total_spawns)):
			shield_imps_spawned_this_wave += 1
			return escena_imp_escudo
		else:
			# El resto entre gobling ballesta y gobling girl (50/50)
			if forzar_tipo_enemigo == 0:
				return escena_goblin
			elif forzar_tipo_enemigo == 1:
				return escena_goblin_girl
			else:
				return escena_goblin_girl if randf() < 0.5 else escena_goblin
	else:
		# Modo forzado: solo un tipo de enemigo
		if forzar_tipo_enemigo == 0:
			return escena_goblin
		elif forzar_tipo_enemigo == 1:
			return escena_goblin_girl
		elif forzar_tipo_enemigo == 2:
			return escena_imp
		elif forzar_tipo_enemigo == 3:
			return escena_canonero
		elif forzar_tipo_enemigo == 4:
			return escena_imp_escudo
		elif forzar_tipo_enemigo == 5:
			return escena_gargola
		elif forzar_tipo_enemigo == 6:
			return escena_lonko
		elif forzar_tipo_enemigo == 7:
			return escena_arquera_rosa
		elif probabilidad_igual:
			# Probabilidad igual: 20% cada tipo (5 tipos)
			var roll = randf()
			if roll < 0.20:
				return escena_canonero
			elif roll < 0.40:
				return escena_imp
			elif roll < 0.60:
				return escena_goblin_girl
			elif roll < 0.80:
				return escena_goblin
			else:
				return escena_gargola
		else:
			# Probabilidades configuradas
			var roll = randf()
			if roll < probabilidad_canonero and escena_canonero:
				return escena_canonero
			elif roll < probabilidad_canonero + probabilidad_imp and escena_imp:
				return escena_imp
			elif (
				roll < probabilidad_canonero + probabilidad_imp + probabilidad_goblin_girl
				and escena_goblin_girl
			):
				return escena_goblin_girl
			else:
				return escena_goblin


func _spawn_goblin():
	_log_debug(
		"[WaveSpawner] Spawning enemy. Total spawned so far in wave: %d / %d"
		% [goblins_spawned_in_wave, enemigos_por_oleada]
	)
	# Trigger del Evento de Cuerno: Oleada 5 al haber 12 spawns, Oleada 4 al haber 10
	if (
		not evento_cuerno_activado
		and (
			(oleada_combate == 5 and goblins_spawned_in_wave >= 12)
			or (oleada_combate == 4 and goblins_spawned_in_wave >= 10)
		)
	):
		_iniciar_evento_cuerno(10, false)  # Oleada 4 ya trae 5 escudo fijos en cola, no spawnear extra

	if evento_cuerno_en_progreso:
		refuerzos_cuerno_spawneados += 1
		if refuerzos_cuerno_spawneados >= refuerzos_cuerno_total:
			evento_cuerno_en_progreso = false

	# Elegir qué tipo de enemigo spawnear
	var scene_to_spawn: PackedScene

	if forzar_tipo_enemigo != -1:
		scene_to_spawn = _elegir_escena_probabilidades()
	elif not cola_spawn.is_empty():
		scene_to_spawn = cola_spawn.pop_front()
	elif oleada_combate == 4 or oleada_combate == 5:
		# Oleadas 4 y 5 usan SOLO cola prediseñada
		return
	else:
		scene_to_spawn = _elegir_escena_probabilidades()

	if not scene_to_spawn:
		push_error("[WaveSpawner] No scene to spawn!")
		return

	var goblin = scene_to_spawn.instantiate()

	# Posicionar en el punto de spawn (este nodo)
	var spawn_pos = global_position
	spawn_pos.y += altura_spawn

	# Añadir variación vertical aleatoria
	spawn_pos.y += randf_range(-0.2, 0.2)

	# Añadir al mundo
	_obtener_nodo_padre_spawn().add_child(goblin)
	goblin.global_position = spawn_pos

	# Conectar señal de muerte
	if goblin.has_signal("died"):
		if scene_to_spawn == escena_imp_escudo:
			goblin.died.connect(_on_shield_imp_died.bind(goblin))
			shield_imps_activos.append(goblin)
		else:
			goblin.died.connect(_on_goblin_died.bind(goblin))

	active_goblins.append(goblin)
	goblins_spawned_in_wave += 1

	goblin_spawneado.emit(goblin)


func _obtener_nodo_padre_spawn() -> Node:
	var root := get_tree().current_scene
	if root and is_instance_valid(root):
		return root
	return get_parent() if get_parent() else get_tree().root


func _on_goblin_died(goblin):
	active_goblins.erase(goblin)
	enemigos_muertos_en_oleada += 1
	AudioManager.on_enemy_killed()


func _check_wave_complete():
	# La oleada termina cuando todos los goblins normales spawnearon Y todos murieron
	if goblins_spawned_in_wave >= enemigos_por_oleada:
		# Limpiar referencias inválidas
		# Opt: Iteración inversa in-place en lugar de Array.filter() para evitar allocations de memoria/GC en comprobaciones frecuentes
		for i in range(active_goblins.size() - 1, -1, -1):
			if not is_instance_valid(active_goblins[i]):
				active_goblins.remove_at(i)

		if active_goblins.is_empty():
			is_wave_active = false
			wave_cooldown = tiempo_entre_oleadas
			oleada_completada.emit(current_wave)


# === API PÚBLICA ===


func iniciar_spawning():
	wave_cooldown = 0.5


func toggle_pause_spawning():
	if is_wave_active:
		is_wave_active = false
		_log_debug("Spawning PAUSADO")
	else:
		is_wave_active = true
		_log_debug("Spawning REANUDADO")


func detener_spawning():
	is_wave_active = false
	wave_cooldown = 999999


func forzar_spawn():
	_spawn_goblin()


func obtener_goblins_activos() -> int:
	# Opt: Iteración inversa in-place en lugar de Array.filter()
	for i in range(active_goblins.size() - 1, -1, -1):
		if not is_instance_valid(active_goblins[i]):
			active_goblins.remove_at(i)
	return active_goblins.size()


func get_active_enemies() -> Array:
	# Opt: Iteración inversa in-place en lugar de Array.filter()
	for i in range(active_goblins.size() - 1, -1, -1):
		if not is_instance_valid(active_goblins[i]):
			active_goblins.remove_at(i)
	return active_goblins


func get_active_shield_imps() -> Array:
	# Opt: Iteración inversa in-place en lugar de Array.filter()
	for i in range(shield_imps_activos.size() - 1, -1, -1):
		if not is_instance_valid(shield_imps_activos[i]):
			shield_imps_activos.remove_at(i)
	return shield_imps_activos


# ═══════════════════════════════════════════════════════════════════════════════
# IMP SHIELD GIRL
# ═══════════════════════════════════════════════════════════════════════════════


func _check_shield_imp_spawn(delta):
	if oleada_combate in [1, 2, 3, 4, 5]:
		return
	if max_shield_imps_to_spawn_this_wave > 0:
		return
	shield_spawn_timer -= delta
	if shield_spawn_timer > 0:
		return
	shield_spawn_timer = intervalo_check_escudo


# ═══════════════════════════════════════════════════════════════════════════════
# EVENTO DE CUERNO PROCEDURAL
# ═══════════════════════════════════════════════════════════════════════════════

func generar_sonido_cuerno_procedural() -> AudioStreamWAV:
	var sample_rate := 22050
	var duration := 2.2
	var num_samples := int(sample_rate * duration)
	var byte_array := PackedByteArray()
	byte_array.resize(num_samples * 2)

	var f0 := 174.61  # F3 (tono clásico de cuerno de guerra)
	for i in range(num_samples):
		var t := float(i) / float(sample_rate)
		
		# Envolvente de volumen (crescendo y decrescendo)
		var env := 1.0
		if t < 0.25:
			env = t / 0.25
		elif t > (duration - 0.7):
			env = (duration - t) / 0.7
		env = clamp(env, 0.0, 1.0)
		
		# Modulación de frecuencia (swell / vibrato)
		var vibrato := sin(t * 5.5 * TAU) * 1.5
		var pitch := f0 + vibrato
		
		# Síntesis aditiva armónica de metales / cuerno
		var s1 := sin(pitch * 1.0 * TAU * t) * 0.50
		var s2 := sin(pitch * 2.0 * TAU * t) * 0.30
		var s3 := sin(pitch * 3.0 * TAU * t) * 0.20
		var s4 := sin(pitch * 4.0 * TAU * t) * 0.10
		var s5 := sin(pitch * 5.0 * TAU * t) * 0.05
		var sample := (s1 + s2 + s3 + s4 + s5) * env * 0.8
		
		var sample_int := int(clamp(sample * 32767.0, -32768.0, 32767.0))
		byte_array.encode_s16(i * 2, sample_int)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = byte_array
	return wav


func reproducir_sonido_cuerno() -> void:
	# Activar viñeteado rojo durante el evento del cuerno por ~3 segundos en la UI
	var game_ui = get_tree().get_first_node_in_group("game_ui")
	if game_ui and game_ui.has_method("activar_efecto_viñeta_cuerno"):
		game_ui.activar_efecto_viñeta_cuerno(3.0)

	var cuerno_stream: AudioStream = load("res://System/Audio/SFX/Cuerno de guerra.mp3")
	if cuerno_stream:
		var player := AudioStreamPlayer.new()
		player.stream = cuerno_stream
		player.volume_db = 0.0  # -2 dB: 20% menos que el volumen anterior
		player.bus = "Master"
		var root := get_tree().current_scene
		if root:
			root.add_child(player)
		else:
			add_child(player)
		player.play()

		# Desvanecimiento (fade out) al sonido del cuerno
		var duracion_audio: float = cuerno_stream.get_length() if cuerno_stream.has_method("get_length") else 4.0
		if duracion_audio <= 0.0:
			duracion_audio = 4.0
		var tiempo_fade_inicio: float = max(1.0, duracion_audio - 1.5)
		var tween := player.create_tween()
		tween.tween_interval(tiempo_fade_inicio)
		tween.tween_property(player, "volume_db", -40.0, duracion_audio - tiempo_fade_inicio) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.finished.connect(func():
			if is_instance_valid(player):
				player.stop()
				player.queue_free()
		)


func _iniciar_evento_cuerno(cantidad_refuerzos: int = 10, incluir_imp_escudo_fijo: bool = false) -> void:
	evento_cuerno_activado = true
	evento_cuerno_en_progreso = true
	refuerzos_cuerno_spawneados = 0
	refuerzos_cuerno_total = max(1, cantidad_refuerzos)
	evento_cuerno_iniciado.emit()
	reproducir_sonido_cuerno()

	# Reorganizar la cola para que los próximos spawns sean ráfaga intercalada
	# de Goblin Girl y Goblin Ballesta (mitad de cada uno) — excepto Oleada 4 que usa solo ballesta
	var burst: Array[PackedScene] = []
	if oleada_combate == 4:
		# Oleada 4: ráfaga 8x Goblin Ballesta + 2x Imp (10 total pedido)
		for i in range(8):
			burst.append(escena_goblin)
		for i in range(2):
			burst.append(escena_imp)
		burst.shuffle()
	else:
		for i in range(int(ceil(refuerzos_cuerno_total / 2.0))):
			burst.append(escena_goblin_girl)
			burst.append(escena_goblin)

	burst.append_array(cola_spawn)
	cola_spawn = burst

	# Asegurar que el total de enemigos de la oleada contabilice los refuerzos del cuerno
	if enemigos_por_oleada < goblins_spawned_in_wave + cola_spawn.size():
		enemigos_por_oleada = goblins_spawned_in_wave + cola_spawn.size()

	# La oleada 4 incluye fijo 1 Imp de Escudo con el evento (desactivado, ya tiene 5 en cola)
	if incluir_imp_escudo_fijo:
		_spawnear_imp_escudo_fijo()

	# Oleada 4: los 10 refuerzos salen DE GOLPE cuando suena el cuerno
	if oleada_combate == 4:
		var routine_golpe := func():
			for i in range(refuerzos_cuerno_total):
				if not is_instance_valid(self) or not is_inside_tree():
					return
				var escena_a_spawnear: PackedScene = cola_spawn.pop_front() if not cola_spawn.is_empty() else escena_goblin
				if escena_a_spawnear:
					var enemy = escena_a_spawnear.instantiate()
					var spawn_pos = global_position
					spawn_pos.y += altura_spawn
					spawn_pos.y += randf_range(-0.2, 0.2)
					_obtener_nodo_padre_spawn().add_child(enemy)
					enemy.global_position = spawn_pos
					if enemy.has_signal("died"):
						enemy.died.connect(_on_goblin_died.bind(enemy))
					active_goblins.append(enemy)
					goblins_spawned_in_wave += 1
					refuerzos_cuerno_spawneados += 1
				# Tanda 0.20s entre cada uno de los 10 (2s total) — de golpe pero espaciado
				await get_tree().create_timer(0.20, false).timeout
			evento_cuerno_en_progreso = false
			# Acelerador de spawn durante el evento ya no es necesario, ya salió la ráfaga
		routine_golpe.call()
	# Si el spawner está en pausa o inactivo (otras oleadas), spawnear la ráfaga progresivamente
	elif not is_wave_active:
		var routine := func():
			for i in range(refuerzos_cuerno_total):
				if not is_instance_valid(self) or not is_inside_tree():
					return
				var escena_a_spawnear: PackedScene = (
					cola_spawn.pop_front() if not cola_spawn.is_empty()
					else (escena_goblin_girl if (i % 2 == 0) else escena_goblin)
				)
				if escena_a_spawnear:
					var enemy = escena_a_spawnear.instantiate()
					var spawn_pos = global_position
					spawn_pos.y += altura_spawn
					_obtener_nodo_padre_spawn().add_child(enemy)
					enemy.global_position = spawn_pos
					if enemy.has_signal("died"):
						enemy.died.connect(_on_goblin_died.bind(enemy))
					active_goblins.append(enemy)
				await get_tree().create_timer(0.35, false).timeout
			evento_cuerno_en_progreso = false
		routine.call()

	# Limpiar referencias inválidas
	# Opt: Iteración inversa in-place en lugar de Array.filter() para evitar GC
	for i in range(shield_imps_activos.size() - 1, -1, -1):
		if not is_instance_valid(shield_imps_activos[i]):
			shield_imps_activos.remove_at(i)

	# Verificar condiciones
	if shield_imps_activos.size() >= max_imp_escudo_activos:
		return

	var enemigos_vivos = obtener_goblins_activos()
	if enemigos_vivos < enemigos_minimos_para_escudo:
		return

	# Verificar que hay al menos 1 enemigo en SHOOTING (parado)
	var hay_enemigo_shooting = false
	for enemy in active_goblins:
		if is_instance_valid(enemy) and enemy is EnemyBase:
			if enemy.current_state == EnemyBase.State.SHOOTING:
				hay_enemigo_shooting = true
				break
	if not hay_enemigo_shooting:
		return

	if not escena_imp_escudo:
		return

	_spawn_shield_imp()


func _spawn_shield_imp():
	if not escena_imp_escudo:
		return

	var shield_imp = escena_imp_escudo.instantiate()

	# Posicionar en el punto de spawn
	var spawn_pos = global_position
	spawn_pos.y += altura_spawn

	_obtener_nodo_padre_spawn().add_child(shield_imp)
	shield_imp.global_position = spawn_pos

	# Conectar señal de muerte
	if shield_imp.has_signal("died"):
		shield_imp.died.connect(_on_shield_imp_died.bind(shield_imp))

	shield_imps_activos.append(shield_imp)
	active_goblins.append(shield_imp)

	if is_wave_active:
		goblins_spawned_in_wave += 1


## Spawn directo y garantizado de 1 Imp de Escudo (refuerzo fijo del evento
## de cuerno de la oleada 4), sin pasar por la cola ni los límites de oleada.
func _spawnear_imp_escudo_fijo() -> void:
	if not escena_imp_escudo:
		return

	var shield_imp = escena_imp_escudo.instantiate()
	var spawn_pos = global_position
	spawn_pos.y += altura_spawn
	_obtener_nodo_padre_spawn().add_child(shield_imp)
	shield_imp.global_position = spawn_pos

	if shield_imp.has_signal("died"):
		shield_imp.died.connect(_on_shield_imp_died.bind(shield_imp))
	shield_imps_activos.append(shield_imp)
	active_goblins.append(shield_imp)


func _on_shield_imp_died(shield_imp):
	shield_imps_activos.erase(shield_imp)
	active_goblins.erase(shield_imp)
	enemigos_muertos_en_oleada += 1


func forzar_spawn_escudo():
	_spawn_shield_imp()


# ═══════════════════════════════════════════════════════════════════════════════
# MODO PACÍFICO (Nivel 0)
# ═══════════════════════════════════════════════════════════════════════════════


## Spawnea enemigos en modo pacífico (solo caminan, no atacan).
## El primero spawnea en la posición base, los siguientes más atrás.
## Todos reciben la misma velocidad para caminar sincronizados.
## Retorna el array de enemigos spawneados.
func spawn_pacificos(
	escenas: Array[PackedScene], velocidad_uniforme: float = 0.5, offset_entre: float = 0.4
) -> Array:
	var enemigos := []
	for i in range(escenas.size()):
		var escena = escenas[i]
		if not escena:
			continue
		var enemigo = escena.instantiate()
		enemigo.modo_pacifico = true
		enemigo.velocidad_caminar = velocidad_uniforme
		enemigo.distancia_maxima_caminar = 10.0

		var spawn_pos = global_position
		spawn_pos.y += altura_spawn
		# Offset escalonado: el primero en X base, los siguientes más atrás
		spawn_pos.x += i * offset_entre

		_obtener_nodo_padre_spawn().add_child(enemigo)
		enemigo.global_position = spawn_pos

		if enemigo.has_signal("died"):
			enemigo.died.connect(_on_goblin_died.bind(enemigo))
		active_goblins.append(enemigo)
		enemigos.append(enemigo)
	return enemigos


## Configura el spawner para una oleada custom y la inicia.
func iniciar_oleada_custom(
	total_enemigos: int, prob_imp: float = 0.5, prob_girl: float = 0.5, _prob_goblin: float = 0.0
):
	enemigos_por_oleada = total_enemigos
	probabilidad_imp = prob_imp
	probabilidad_goblin_girl = prob_girl
	probabilidad_igual = false
	# Ajustar para que el spawner use la oleada configurada
	current_wave = 0
	wave_cooldown = 1.0
	is_wave_active = false


func _log_debug(message: String) -> void:
	if not debug_logs_enabled:
		return

	print(message)
