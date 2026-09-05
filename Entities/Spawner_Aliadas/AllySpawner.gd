class_name AllySpawner
extends Node3D

## Spawner de aliadas de refuerzo para la zona del jugador.
## Genera secuencialmente 1 Ballestera (dirigida siempre al último piso)
## y 9 Arqueras (repartidas entre el suelo y las plataformas).

# ═══════════════════════════════════════════════════════════════════════════════
# SEÑALES
# ═══════════════════════════════════════════════════════════════════════════════
signal ally_spawned(ally: Node3D, tipo: String, piso: int)
signal all_allies_spawned

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTES
# ═══════════════════════════════════════════════════════════════════════════════
const TIPO_BALLESTERA: String = "ballestera"
const TIPO_ARQUERA: String = "arquera"

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURACIÓN DE SPAWN
# ═══════════════════════════════════════════════════════════════════════════════
@export_category("Configuración")
@export var auto_iniciar: bool = true
@export var delay_inicio: float = 0.5
@export var intervalo_spawn: float = 0.6

@export_category("Escenas")
@export var escena_ballestera: PackedScene = preload("res://Entities/Aliada_Ballestera/AllyBallestera.tscn")
@export var escena_arquera: PackedScene = preload("res://Entities/Aliada_Arquera/AllyArcher.tscn")

@export_category("Audio")
@export var sonido_entrada: AudioStream = preload("res://TEST_/Defensoras entrada.wav")
@export var volumen_db: float = -4.0

@export_category("Distribución de Refuerzos")
## Distribución de la Ballestera: siempre 1 en el último piso (Piso 3)
@export var distribucion_ballestera: Array[Dictionary] = [
	{"piso": 3, "destino_x": -8.7}
]

## Distribución de las 9 Arqueras en la zona del jugador (Piso 0, 1, 2, 3)
@export var distribucion_arqueras: Array[Dictionary] = [
	{"piso": 0, "destino_x": -4.8},
	{"piso": 0, "destino_x": -5.8},
	{"piso": 0, "destino_x": -6.8},
	{"piso": 1, "destino_x": -6.9},
	{"piso": 1, "destino_x": -7.4},
	{"piso": 2, "destino_x": -7.7},
	{"piso": 2, "destino_x": -8.2},
	{"piso": 3, "destino_x": -9.3},
	{"piso": 3, "destino_x": -9.8}
]

# ═══════════════════════════════════════════════════════════════════════════════
# VARIABLES DE ESTADO
# ═══════════════════════════════════════════════════════════════════════════════
var aliadas_instanciadas: Array[Node3D] = []
var _audio_player: AudioStreamPlayer = null
var _spawn_en_curso: bool = false

# ═══════════════════════════════════════════════════════════════════════════════
# MÉTODOS BUILT-IN
# ═══════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	var preview_label: Node = get_node_or_null("EditorPreviewLabel")
	if preview_label and not Engine.is_editor_hint():
		preview_label.visible = false

	_configurar_audio()
	if not auto_iniciar:
		return

	if delay_inicio > 0.0:
		var timer: SceneTreeTimer = get_tree().create_timer(delay_inicio)
		timer.timeout.connect(iniciar_spawn)
	else:
		iniciar_spawn()

# ═══════════════════════════════════════════════════════════════════════════════
# MÉTODOS PÚBLICOS
# ═══════════════════════════════════════════════════════════════════════════════
## Inicia la secuencia escalonada de aparición de aliadas.
func iniciar_spawn() -> void:
	if _spawn_en_curso:
		return
	_spawn_en_curso = true

	_reproducir_sonido_entrada()

	# 1. Spawnear la Ballestera (siempre en el último piso)
	for config: Dictionary in distribucion_ballestera:
		var piso: int = int(config.get("piso", 3))
		var dest_x: float = float(config.get("destino_x", -8.7))
		var ballestera: Node3D = spawn_aliada(TIPO_BALLESTERA, piso, dest_x)
		if ballestera:
			aliadas_instanciadas.append(ballestera)
			ally_spawned.emit(ballestera, TIPO_BALLESTERA, piso)

		if intervalo_spawn > 0.0:
			await get_tree().create_timer(intervalo_spawn).timeout
			if not is_instance_valid(self):
				return

	# 2. Spawnear las 9 Arqueras
	for i in range(distribucion_arqueras.size()):
		var config: Dictionary = distribucion_arqueras[i]
		var piso: int = int(config.get("piso", 0))
		var dest_x: float = float(config.get("destino_x", NAN))
		var arquera: Node3D = spawn_aliada(TIPO_ARQUERA, piso, dest_x)
		if arquera:
			aliadas_instanciadas.append(arquera)
			ally_spawned.emit(arquera, TIPO_ARQUERA, piso)

		# Intervalo entre aliadas excepto en la última
		if i < distribucion_arqueras.size() - 1 and intervalo_spawn > 0.0:
			await get_tree().create_timer(intervalo_spawn).timeout
			if not is_instance_valid(self):
				return

	_spawn_en_curso = false
	all_allies_spawned.emit()

## Spawnea una aliada individual y activa su despliegue hacia la plataforma objetivo.
func spawn_aliada(tipo: String, piso: int, destino_x: float = NAN) -> Node3D:
	var escena: PackedScene = escena_ballestera if tipo == TIPO_BALLESTERA else escena_arquera
	if not escena:
		push_error("[AllySpawner] Escena no asignada para tipo: " + tipo)
		return null

	var ally: Node3D = escena.instantiate() as Node3D
	if not ally:
		push_error("[AllySpawner] Falló al instanciar la escena para: " + tipo)
		return null

	var nodo_padre: Node = get_parent()
	if not nodo_padre:
		nodo_padre = self
	nodo_padre.add_child(ally)

	# Posicionar en el punto del spawner manteniendo el plano Z
	ally.global_position = global_position

	# Iniciar rutina de movimiento y trepado hacia su puesto
	if ally.has_method("desplegar_a_plataforma"):
		ally.call("desplegar_a_plataforma", piso, destino_x)

	return ally

# ═══════════════════════════════════════════════════════════════════════════════
# MÉTODOS PRIVADOS
# ═══════════════════════════════════════════════════════════════════════════════
func _configurar_audio() -> void:
	if not sonido_entrada:
		return
	_audio_player = AudioStreamPlayer.new()
	_audio_player.name = "AudioEntrada"
	_audio_player.stream = sonido_entrada
	_audio_player.volume_db = volumen_db
	_audio_player.bus = "Master"
	add_child(_audio_player)

func _reproducir_sonido_entrada() -> void:
	if _audio_player and is_instance_valid(_audio_player):
		_audio_player.play()
