extends Node3D
class_name WaveSpawner

# === CONFIGURACIÓN (Español) ===
@export_category("Spawner")
@export var escena_goblin: PackedScene # Escena del goblin a instanciar
@export var escena_goblin_girl: PackedScene # Escena de la goblin girl
@export var intervalo_aparicion: float = 5.0 # Segundos entre spawns (más lento)
@export var goblins_por_oleada: int = 6 # Cantidad de goblins por oleada
@export var tiempo_entre_oleadas: float = 5.0 # Descanso entre oleadas
@export var altura_spawn: float = 0.0 # Altura extra para spawnar sobre el suelo
@export_range(0.0, 1.0, 0.05) var probabilidad_goblin_girl: float = 0.5 # Probabilidad de que aparezca una Goblin Girl

# === ESTADO ===
var current_wave: int = 0
var goblins_spawned_in_wave: int = 0
var spawn_timer: float = 0.0
var wave_cooldown: float = 0.0
var is_wave_active: bool = false
var active_goblins: Array = []

# === SEÑALES ===
signal oleada_iniciada(numero_oleada: int)
signal oleada_completada(numero_oleada: int)
signal goblin_spawneado(goblin: Node)

func _ready():
	# Cargar escenas si no están asignadas
	if not escena_goblin:
		escena_goblin = preload("res://Scenes/Characters/Goblin.tscn")
	if not escena_goblin_girl:
		escena_goblin_girl = preload("res://Scenes/Characters/GoblinGirl.tscn")
	
	# Iniciar primera oleada después de un delay
	wave_cooldown = 2.0

func _process(delta):
	if not is_wave_active:
		wave_cooldown -= delta
		if wave_cooldown <= 0:
			_start_wave()
	else:
		spawn_timer -= delta
		if spawn_timer <= 0 and goblins_spawned_in_wave < goblins_por_oleada:
			_spawn_goblin()
			spawn_timer = intervalo_aparicion
		
		# Verificar si la oleada terminó
		_check_wave_complete()

func _start_wave():
	current_wave += 1
	goblins_spawned_in_wave = 0
	is_wave_active = true
	spawn_timer = 0.0 # Spawn inmediato al iniciar oleada
	
	oleada_iniciada.emit(current_wave)

func _spawn_goblin():
	# Elegir aleatoriamente entre Goblin y GoblinGirl
	var scene_to_spawn: PackedScene
	var roll = randf()
	
	if roll < probabilidad_goblin_girl and escena_goblin_girl:
		scene_to_spawn = escena_goblin_girl
	else:
		scene_to_spawn = escena_goblin
	
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
	get_tree().root.add_child(goblin)
	goblin.global_position = spawn_pos
	
	# Conectar señal de muerte
	if goblin.has_signal("died"):
		goblin.died.connect(_on_goblin_died.bind(goblin))
	
	active_goblins.append(goblin)
	goblins_spawned_in_wave += 1
	
	goblin_spawneado.emit(goblin)

func _on_goblin_died(goblin):
	active_goblins.erase(goblin)

func _check_wave_complete():
	# La oleada termina cuando todos los goblins spawnearon Y todos murieron
	if goblins_spawned_in_wave >= goblins_por_oleada:
		# Limpiar referencias inválidas
		active_goblins = active_goblins.filter(func(g): return is_instance_valid(g))
		
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
		print("Spawning PAUSADO")
	else:
		is_wave_active = true
		print("Spawning REANUDADO")

func detener_spawning():
	is_wave_active = false
	wave_cooldown = 999999

func forzar_spawn():
	_spawn_goblin()

func obtener_goblins_activos() -> int:
	active_goblins = active_goblins.filter(func(g): return is_instance_valid(g))
	return active_goblins.size()
