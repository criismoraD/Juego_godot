@tool
class_name BattleSpawnerCosmetic
extends Node3D

## Spawner cosmético de batalla de fondo (no cuenta como oleada).
##
## Instancia una cantidad configurable de unidades en un plano Z separado
## para simular una batalla de fondo entre dos bandos.
## Tiene un sistema de equilibrio automático: si un bando supera por mucho
## al otro, el bando perdedor recibe refuerzos para mantener la batalla pareja.
##
## - Bando AZUL  → Defensoras ImperioGirl Melee
## - Bando ROJO  → Goblins Garrote
##
## Los personajes conservan sus grupos de combate originales ("allies"/"enemies")
## para que se detecten y ataquen mutuamente. El WaveSpawner los ignora porque
## solo trackea instancias que él mismo spawnea en su array `active_goblins`.
## Adicionalmente se les agrega el grupo "batalla_cosmetica" como tag de identidad.

# ═══════════════════════════════════════════════════════════════════════════════
# SEÑALES
# ═══════════════════════════════════════════════════════════════════════════════
signal battle_started
signal unit_spawned(unit: Node3D, bando: String)
signal unit_died(bando: String)

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTES
# ═══════════════════════════════════════════════════════════════════════════════
const BANDO_AZUL: String  = "azul"
const BANDO_ROJO: String  = "rojo"

## Diferencia mínima de unidades vivas entre bandos para activar refuerzos.
const UMBRAL_DESEQUILIBRIO: int = 3
## Máximo de unidades activas totales por bando (para no sobrecargar la escena).
const MAX_UNIDADES_ACTIVAS: int = 12

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS — IDENTIDAD DEL SPAWNER
# ═══════════════════════════════════════════════════════════════════════════════
@export_category("Identidad del Spawner")
@export_enum("azul", "rojo") var bando: String = BANDO_AZUL:
	set(v):
		bando = v
		if is_node_ready():
			_actualizar_color_visual()
			_construir_flecha()

@export var spawner_rival: NodePath = NodePath():
	set(v):
		spawner_rival = v

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS — CONFIGURACIÓN DE SPAWN
# ═══════════════════════════════════════════════════════════════════════════════
@export_category("Configuración de Spawn")
## Escena de la unidad a spawnear (deja vacío para usar la predeterminada del bando).
@export var escena_unidad: PackedScene

## Escala visual y de colisión de las unidades spawneadas por este bloque.
@export_range(0.1, 5.0, 0.05) var escala_unidad: float = 1.0

## Cantidad inicial de unidades a spawnear al inicio de la batalla.
@export_range(1, 20, 1) var cantidad_inicial: int = 5

## Tiempo en segundos entre cada spawn inicial.
@export_range(0.1, 10.0, 0.1) var intervalo_spawn_inicial: float = 0.8

## Delay antes de iniciar el spawn (en segundos).
@export_range(0.0, 30.0, 0.5) var delay_inicio: float = 1.0

## Si true, la batalla empieza automáticamente en _ready().
@export var auto_iniciar: bool = true

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS — EQUILIBRIO AUTOMÁTICO
# ═══════════════════════════════════════════════════════════════════════════════
@export_category("Sistema de Equilibrio")
## Activa el sistema de refuerzos automáticos para equilibrar la batalla.
@export var equilibrio_activo: bool = true

## Cada cuántos segundos se evalúa el equilibrio de la batalla.
@export_range(2.0, 30.0, 0.5) var intervalo_evaluacion: float = 5.0

## Refuerzos spawneados por ciclo cuando se detecta desequilibrio.
@export_range(1, 5, 1) var refuerzos_por_ciclo: int = 2

## Intervalo entre refuerzos del mismo ciclo.
@export_range(0.1, 5.0, 0.1) var intervalo_refuerzo: float = 0.5

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS — RESPAWN CONTINUO
# ═══════════════════════════════════════════════════════════════════════════════
@export_category("Respawn Continuo")
## Si true, respawnea automáticamente una unidad cada vez que una muere
## (por combate o por la ZonaKillBatalla). Mantiene el conteo constante
## e impide que la batalla se detenga por falta de unidades.
@export var respawn_al_morir: bool = true

## Delay (segundos) antes de respawnear la unidad que acaba de morir.
## Evita que aparezcan de golpe en el borde de pantalla.
@export_range(0.0, 10.0, 0.1) var delay_respawn: float = 2.0

## Número mínimo de unidades que se intenta mantener vivas.
## Si el conteo cae por debajo de este valor el respawn se acelera
## ignorando el delay (respawn inmediato al siguiente frame).
@export_range(0, 10, 1) var minimo_unidades_vivas: int = 1

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS — EQUILIBRIO DE COMBATE
# ═══════════════════════════════════════════════════════════════════════════════
# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS — GESTIÓN DE CADÁVERES
# ═══════════════════════════════════════════════════════════════════════════════
@export_category("Gestión de Cadáveres")
## Máximo de cadáveres simultáneos permitidos en pantalla para este bando (ej. 8).
## Al superarse, los cadáveres más antiguos desaparecen desvaneciéndose.
@export_range(1, 20, 1) var max_cadaveres: int = 8

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS — EQUILIBRIO DE COMBATE
# ═══════════════════════════════════════════════════════════════════════════════
@export_category("Equilibrio de Combate")
## Vida que tendrán las unidades al spawnear (si es > 0). Permite igualar la resistencia
## o diferenciar bandos (ej. 3 para armadura imperio, 1 para goblins).
@export_range(1, 20, 1) var vida_unidad: int = 2

## Daño de ataque de las unidades (si es > 0).
@export_range(1, 10, 1) var dano_unidad: int = 1

## Velocidad de avance de las unidades (m/s). Si es > 0, iguala la velocidad de ambos bandos
## para que alcancen el centro de la plataforma simultáneamente.
@export_range(0.5, 10.0, 0.1) var velocidad_unidad: float = 2.2

## Límite Y inferior de seguridad. Si una unidad cae por debajo de esta altura,
## se elimina como baja de combate y activa el respawn continuo.
@export var limite_y_muerte: float = -4.0

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS — AUDIO
# ═══════════════════════════════════════════════════════════════════════════════
@export_category("Audio")
## Si true, silencia a las unidades spawneadas por este bloque (pasos, ataques, muertes)
## para evitar saturar el audio en batallas cosméticas de fondo.
@export var silenciar_unidades: bool = false:
	set(v):
		silenciar_unidades = v
		if not is_inside_tree():
			return
		for u in _unidades_activas:
			if is_instance_valid(u):
				_silenciar_unidad(u)

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS — POSICIONAMIENTO
# ═══════════════════════════════════════════════════════════════════════════════
@export_category("Posicionamiento")

## Plano Z en el que viven las unidades de batalla.
@export var plano_z_batalla: float = 8.0

## Offset aleatorio en X al spawnear (radio).
@export_range(0.0, 5.0, 0.1) var scatter_x: float = 1.5

## Offset aleatorio en Z al spawnear (radio).
@export_range(0.0, 2.0, 0.1) var scatter_z: float = 0.5

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS — VISUAL EDITOR
# ═══════════════════════════════════════════════════════════════════════════════
@export_category("Visual Editor")
## Mostrar el bloque visual en tiempo de juego.
@export var mostrar_visual_en_juego: bool = false:
	set(v):
		mostrar_visual_en_juego = v
		if is_node_ready():
			_actualizar_visibilidad_visual()

# ═══════════════════════════════════════════════════════════════════════════════
# VARIABLES DE ESTADO
# ═══════════════════════════════════════════════════════════════════════════════
var _unidades_activas: Array[Node3D] = []
var _cadaveres: Array[Node3D] = []
var _batalla_iniciada: bool = false
var _timer_evaluacion: float = 0.0
var _spawneando: bool = false

# ═══════════════════════════════════════════════════════════════════════════════
# REFERENCIAS
# ═══════════════════════════════════════════════════════════════════════════════
var _rival: BattleSpawnerCosmetic = null
var _visual: MeshInstance3D = null
var _flecha: MeshInstance3D = null

# Escenas por defecto según el bando
const _ESCENA_AZUL: PackedScene = preload(
		"res://Entities/Defensora_ImperioGirl_Melee/ImperioGirlMelee.tscn")
const _ESCENA_ROJA: PackedScene = preload(
		"res://Entities/Enemigo_Goblin_Garrote/GoblinGarrote.tscn")

# Colores de identificación en el editor
const COLOR_AZUL: Color  = Color(0.0, 0.4, 1.0, 0.6)
const COLOR_ROJO: Color  = Color(1.0, 0.15, 0.0, 0.6)
const COLOR_FLECHA: Color = Color(1.0, 1.0, 1.0, 0.9)


# ═══════════════════════════════════════════════════════════════════════════════
# BUILT-IN
# ═══════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	_visual = get_node_or_null("Visual") as MeshInstance3D
	_actualizar_color_visual()
	_actualizar_visibilidad_visual()
	_construir_flecha()

	if Engine.is_editor_hint():
		return

	_resolver_rival()

	if auto_iniciar:
		if delay_inicio > 0.0:
			get_tree().create_timer(delay_inicio).timeout.connect(iniciar_batalla)
		else:
			iniciar_batalla()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not _batalla_iniciada:
		return

	_verificar_caida_vacio()

	if not equilibrio_activo:
		return

	_timer_evaluacion += delta
	if _timer_evaluacion >= intervalo_evaluacion:
		_timer_evaluacion = 0.0
		_evaluar_equilibrio()


## Detecta si alguna unidad activa o cadáver cayó de la plataforma al vacío.
## En caso afirmativo, la elimina y emite la señal de muerte para reciclarla.
func _verificar_caida_vacio() -> void:
	for i in range(_unidades_activas.size() - 1, -1, -1):
		var u: Node3D = _unidades_activas[i]
		if not is_instance_valid(u):
			continue
		if u.global_position.y < limite_y_muerte:
			if u.has_method("take_damage"):
				u.call("take_damage", 99999.0)
			elif u.has_signal("died"):
				u.emit_signal("died")
			elif not u.is_queued_for_deletion():
				u.queue_free()

	for i in range(_cadaveres.size() - 1, -1, -1):
		var c: Node3D = _cadaveres[i]
		if not is_instance_valid(c):
			_cadaveres.remove_at(i)
			continue
		if c.global_position.y < limite_y_muerte:
			_cadaveres.remove_at(i)
			if not c.is_queued_for_deletion():
				c.queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# MÉTODOS PÚBLICOS
# ═══════════════════════════════════════════════════════════════════════════════

## Inicia la batalla spawneando las unidades iniciales.
func iniciar_batalla() -> void:
	if _batalla_iniciada or _spawneando:
		return
	_batalla_iniciada = true
	battle_started.emit()
	await _spawn_lote(cantidad_inicial, intervalo_spawn_inicial)


## Devuelve el número de unidades vivas de este bando.
func contar_unidades_vivas() -> int:
	_limpiar_muertos()
	return _unidades_activas.size()


## True si el bloque de este bando está activo: batalla iniciada y nodo vigente
## en el árbol. El nivel tutorial lo usa para el sonido de batalla de fondo
## (solo suena con ambos bloques —azul y rojo— activos).
func batalla_activa() -> bool:
	if not _batalla_iniciada:
		return false
	if not is_inside_tree() or is_queued_for_deletion():
		return false
	return true


## Spawnea una unidad adicional manualmente.
func spawnear_refuerzo() -> Node3D:
	return await _spawn_una_unidad()


# ═══════════════════════════════════════════════════════════════════════════════
# SPAWN
# ═══════════════════════════════════════════════════════════════════════════════
func _spawn_lote(cantidad: int, intervalo: float) -> void:
	_spawneando = true
	for i in range(cantidad):
		if not is_instance_valid(self):
			return
		await _spawn_una_unidad()
		if i < cantidad - 1 and intervalo > 0.0:
			await get_tree().create_timer(intervalo).timeout
	_spawneando = false


func _spawn_una_unidad() -> Node3D:
	if _unidades_activas.size() >= MAX_UNIDADES_ACTIVAS:
		return null

	var escena: PackedScene = _resolver_escena()
	if not escena:
		push_error("[BattleSpawnerCosmetic] No hay escena asignada para el bando '%s'." % bando)
		return null

	var unidad: Node3D = escena.instantiate() as Node3D
	if not is_instance_valid(unidad):
		return null

	# ── Correcciones PRE-árbol ───────────────────────────────────────────────
	_aplicar_fix_pre_arbol(unidad)

	# Agregar al árbol
	var padre: Node = get_parent() if get_parent() else self
	padre.add_child(unidad)

	# ── Posicionamiento ──────────────────────────────────────────────────────
	var pos: Vector3 = global_position
	pos.x += randf_range(-scatter_x, scatter_x)
	pos.z = plano_z_batalla + randf_range(-scatter_z, scatter_z)
	unidad.global_position = pos

	if "plano_profundidad_z" in unidad:
		unidad.set("plano_profundidad_z", plano_z_batalla)

	# ── Grupos ───────────────────────────────────────────────────────────────
	unidad.add_to_group("batalla_cosmetica")
	unidad.add_to_group("battle_" + bando)

	# ── Correcciones POST-árbol (animaciones) ────────────────────────────────
	_aplicar_fix_post_arbol(unidad)

	# ── Señal de muerte ──────────────────────────────────────────────────────
	_conectar_muerte(unidad)

	_unidades_activas.append(unidad)
	unit_spawned.emit(unidad, bando)
	return unidad


## Correcciones que deben aplicarse ANTES de add_child.
func _aplicar_fix_pre_arbol(unidad: Node3D) -> void:
	var dir_mov: float = 1.0 if bando == BANDO_AZUL else -1.0

	unidad.add_to_group("batalla_cosmetica")
	unidad.add_to_group("battle_" + bando)

	if "direccion_avance" in unidad:
		unidad.set("direccion_avance", dir_mov)
	if "plano_profundidad_z" in unidad:
		unidad.set("plano_profundidad_z", plano_z_batalla)

	var sc: Script = unidad.get_script() as Script
	if sc == null:
		return

	# Aplicar escala configurada en el bloque spawner
	unidad.scale = Vector3.ONE * escala_unidad

	# GoblinGarrote / EnemyBase: desactivar guardas que paralizan en fondo.
	# - evitar_caer_plataformas: el raycast no detecta el suelo cosmético.
	# - _test_hay_suelo_adelante_override = true: siempre hay suelo adelante.
	# - solo_atacar_en_pantalla = false: no depender de la cámara.
	if "_test_hay_suelo_adelante_override" in unidad:
		unidad.set("evitar_caer_plataformas", false)
		unidad.set("_test_hay_suelo_adelante_override", true)
		unidad.set("solo_atacar_en_pantalla", false)


## Correcciones que requieren que el nodo ya esté en el árbol (animaciones).
func _aplicar_fix_post_arbol(unidad: Node3D) -> void:
	unidad.scale = Vector3.ONE * escala_unidad
	var dir_mov: float = 1.0 if bando == BANDO_AZUL else -1.0
	if "direccion_avance" in unidad:
		unidad.set("direccion_avance", dir_mov)
	if "plano_profundidad_z" in unidad:
		unidad.set("plano_profundidad_z", plano_z_batalla)
	if unidad.has_method("_actualizar_orientacion_modelo"):
		unidad.call("_actualizar_orientacion_modelo")

	# Sincronización y equilibrio de atributos de combate
	if vida_unidad > 0:
		if "vida_maxima" in unidad:
			unidad.set("vida_maxima", vida_unidad)
		if "health" in unidad:
			unidad.set("health", vida_unidad)

	if dano_unidad > 0:
		if "dano_cuerpo_a_cuerpo" in unidad:
			unidad.set("dano_cuerpo_a_cuerpo", dano_unidad)

	if velocidad_unidad > 0.0:
		if "velocidad_correr" in unidad:
			unidad.set("velocidad_correr", velocidad_unidad)
		if "velocidad_caminar" in unidad:
			unidad.set("velocidad_caminar", velocidad_unidad)

	# Silenciar unidades si está activo en este spawner
	if silenciar_unidades:
		_silenciar_unidad(unidad)

	var sc: Script = unidad.get_script() as Script
	if sc == null or "ImperioGirlMelee" not in sc.resource_path:
		return

	# Re-ejecutar setup de animaciones un frame después para asegurar que el
	# AnimationPlayer ya esté listo (evita condición de carrera con _ready).
	get_tree().create_timer(0.05).timeout.connect(_post_setup_imperio_girl.bind(unidad))


## Silencia los efectos de sonido de una unidad para evitar saturar el audio en batallas cosméticas.
func _silenciar_unidad(unidad: Node3D) -> void:
	if not is_instance_valid(unidad):
		return
	if "silenciar_audio" in unidad:
		unidad.set("silenciar_audio", true)
	for child in unidad.find_children("*", "AudioStreamPlayer3D", true, false):
		var asp := child as AudioStreamPlayer3D
		if is_instance_valid(asp):
			asp.volume_db = -80.0
	for child in unidad.find_children("*", "AudioStreamPlayer", true, false):
		var asp := child as AudioStreamPlayer
		if is_instance_valid(asp):
			asp.volume_db = -80.0



func _post_setup_imperio_girl(unidad: Node3D) -> void:
	if not is_instance_valid(unidad):
		return
	if unidad.has_method("_remapear_animaciones"):
		unidad.call("_remapear_animaciones")
	if unidad.has_method("_resolver_anim_player"):
		unidad.call("_resolver_anim_player")
	if unidad.has_method("_actualizar_orientacion_modelo"):
		unidad.call("_actualizar_orientacion_modelo")
	# Re-forzar estado CORRIENDO (enum 0) para que arranque la animación
	if unidad.has_method("_cambiar_estado"):
		var estado_corriendo: int = 0  # Estado.CORRIENDO
		# Forzar transición reiniciando el estado actual
		unidad.set("estado", 99)       # valor inválido → permite cambio
		unidad.call("_cambiar_estado", estado_corriendo)


func _resolver_escena() -> PackedScene:
	if escena_unidad:
		return escena_unidad
	return _ESCENA_AZUL if bando == BANDO_AZUL else _ESCENA_ROJA


func _conectar_muerte(unidad: Node3D) -> void:
	# Intentar conectar la señal "died" que usan tanto ImperioGirlMelee como EnemyBase
	if unidad.has_signal("died"):
		unidad.died.connect(_on_unidad_murio.bind(unidad))
	else:
		# Fallback: monitorear por árbol (tree_exited)
		unidad.tree_exited.connect(_on_unidad_salio_arbol.bind(unidad))


func _on_unidad_murio(unidad: Node3D) -> void:
	if is_instance_valid(unidad) and _unidades_activas.has(unidad):
		_unidades_activas.erase(unidad)
	unit_died.emit(bando)
	_registrar_cadaver(unidad)
	_respawnear_con_delay()


func _on_unidad_salio_arbol(unidad: Node3D) -> void:
	if _unidades_activas.has(unidad):
		_unidades_activas.erase(unidad)
	if _cadaveres.has(unidad):
		_cadaveres.erase(unidad)
	unit_died.emit(bando)
	_respawnear_con_delay()


## Registra un cadáver en la lista del bando. Si supera max_cadaveres (8 por bando),
## el más antiguo desaparece desvaneciéndose.
func _registrar_cadaver(unidad: Node3D) -> void:
	if not is_instance_valid(unidad):
		return
	_limpiar_cadaveres()
	_cadaveres.append(unidad)
	while _cadaveres.size() > max_cadaveres:
		var viejo: Node3D = _cadaveres.pop_front()
		if is_instance_valid(viejo):
			_desvanecer_y_liberar_cadaver(viejo)


## Ejecuta el desvanecimiento y liberación del cadáver más antiguo.
func _desvanecer_y_liberar_cadaver(cadaver: Node3D) -> void:
	if not is_instance_valid(cadaver) or cadaver.is_queued_for_deletion():
		return
	if cadaver.has_method("desvanecer_y_liberar"):
		cadaver.call("desvanecer_y_liberar")
	elif cadaver.has_method("_start_dissolve_effect"):
		cadaver.call("_start_dissolve_effect")
	elif cadaver.has_method("_start_dissolve"):
		cadaver.call("_start_dissolve")
	else:
		var tween: Tween = create_tween()
		tween.tween_property(cadaver, "scale", Vector3.ZERO, 1.2)
		tween.tween_callback(cadaver.queue_free)


func _limpiar_cadaveres() -> void:
	var validos: Array[Node3D] = []
	for c: Node3D in _cadaveres:
		if is_instance_valid(c) and not c.is_queued_for_deletion():
			validos.append(c)
	_cadaveres = validos


## Devuelve la cantidad actual de cadáveres visibles de este bando.
func contar_cadaveres() -> int:
	_limpiar_cadaveres()
	return _cadaveres.size()


func _limpiar_muertos() -> void:
	var vivas: Array[Node3D] = []
	for u in _unidades_activas:
		if is_instance_valid(u):
			vivas.append(u)
	_unidades_activas = vivas


## Respawnea una unidad tras un delay para reemplazar a la que murió.
## Si el bando tiene menos unidades que el mínimo configurado, el respawn
## es inmediato (sin delay) para evitar que la batalla quede vacía.
func _respawnear_con_delay() -> void:
	if not _batalla_iniciada:
		return
	if not respawn_al_morir:
		return
	if _unidades_activas.size() >= MAX_UNIDADES_ACTIVAS:
		return

	# Respawn acelerado si quedan muy pocas unidades vivas
	var vivos_actuales: int = contar_unidades_vivas()
	var usar_delay: float = delay_respawn if vivos_actuales >= minimo_unidades_vivas else 0.0

	if usar_delay > 0.0:
		get_tree().create_timer(usar_delay).timeout.connect(
			func() -> void:
				if is_instance_valid(self) and _batalla_iniciada:
					await _spawn_una_unidad()
		)
	else:
		await get_tree().process_frame
		if is_instance_valid(self) and _batalla_iniciada:
			await _spawn_una_unidad()


# ═══════════════════════════════════════════════════════════════════════════════
# SISTEMA DE EQUILIBRIO
# ═══════════════════════════════════════════════════════════════════════════════
func _evaluar_equilibrio() -> void:
	if not is_instance_valid(_rival):
		_resolver_rival()
		if not is_instance_valid(_rival):
			return

	var mis_vivos: int = contar_unidades_vivas()
	var rival_vivos: int = _rival.contar_unidades_vivas()
	var diferencia: int = rival_vivos - mis_vivos

	# Si el rival supera en más del umbral Y no hemos alcanzado el máximo
	if diferencia >= UMBRAL_DESEQUILIBRIO and mis_vivos < MAX_UNIDADES_ACTIVAS:
		var a_spawnear: int = mini(refuerzos_por_ciclo, MAX_UNIDADES_ACTIVAS - mis_vivos)
		_spawnear_refuerzos_equilibrio(a_spawnear)


func _spawnear_refuerzos_equilibrio(cantidad: int) -> void:
	if _spawneando:
		return
	_spawn_lote(cantidad, intervalo_refuerzo)


func _resolver_rival() -> void:
	if spawner_rival.is_empty():
		return
	var nodo: Node = get_node_or_null(spawner_rival)
	if is_instance_valid(nodo) and nodo is BattleSpawnerCosmetic:
		_rival = nodo as BattleSpawnerCosmetic


# ═══════════════════════════════════════════════════════════════════════════════
# VISUAL EDITOR
# ═══════════════════════════════════════════════════════════════════════════════
func _actualizar_color_visual() -> void:
	if not is_instance_valid(_visual):
		_visual = get_node_or_null("Visual") as MeshInstance3D
	if not is_instance_valid(_visual):
		return

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = COLOR_AZUL if bando == BANDO_AZUL else COLOR_ROJO
	_visual.material_override = mat

	# Actualizar también la flecha si ya existe
	_actualizar_flecha_direccion()


func _actualizar_visibilidad_visual() -> void:
	if not is_instance_valid(_visual):
		_visual = get_node_or_null("Visual") as MeshInstance3D
	if not is_instance_valid(_visual):
		return
	if Engine.is_editor_hint():
		_visual.visible = true
	else:
		_visual.visible = mostrar_visual_en_juego

	if is_instance_valid(_flecha):
		if Engine.is_editor_hint():
			_flecha.visible = true
		else:
			_flecha.visible = mostrar_visual_en_juego


## Construye proceduralmente una flecha 3D que indica la dirección de spawn.
## Bando AZUL → apunta a la derecha (+X, hacia los goblins).
## Bando ROJO → apunta a la izquierda (-X, hacia las defensoras).
func _construir_flecha() -> void:
	# ── Solo visible en el editor ─────────────────────────────────────────────
	if not Engine.is_editor_hint():
		return

	# Limpiar nodos de flecha anteriores
	for nombre in ["FlechaDireccion", "PuntaFlecha", "LabelBando"]:
		var old: Node = get_node_or_null(nombre)
		if is_instance_valid(old):
			old.queue_free()

	var dir_x: float = 1.0 if bando == BANDO_AZUL else -1.0
	var color_bando: Color = COLOR_AZUL if bando == BANDO_AZUL else COLOR_ROJO

	# Material del bando (semi-opaco)
	var mat_flecha := StandardMaterial3D.new()
	mat_flecha.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_flecha.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_flecha.cull_mode    = BaseMaterial3D.CULL_DISABLED
	mat_flecha.albedo_color = color_bando

	# ── Cuerpo de la flecha (cilindro horizontal) ─────────────────────────────
	var cuerpo_mesh := CylinderMesh.new()
	cuerpo_mesh.top_radius    = 0.07
	cuerpo_mesh.bottom_radius = 0.07
	cuerpo_mesh.height        = 1.6
	cuerpo_mesh.material      = mat_flecha

	var cuerpo := MeshInstance3D.new()
	cuerpo.name             = "FlechaDireccion"
	cuerpo.mesh             = cuerpo_mesh
	cuerpo.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	cuerpo.position         = Vector3(dir_x * 1.4, 1.8, 0.0)
	add_child(cuerpo)
	_flecha = cuerpo

	# ── Punta del cono ────────────────────────────────────────────────────────
	var punta_mesh := CylinderMesh.new()
	punta_mesh.top_radius    = 0.0
	punta_mesh.bottom_radius = 0.26
	punta_mesh.height        = 0.55
	punta_mesh.material      = mat_flecha

	var punta := MeshInstance3D.new()
	punta.name             = "PuntaFlecha"
	punta.mesh             = punta_mesh
	# top_radius=0 → punta en +Y. Rotación -90*dir_x en Z:
	# dir_x=-1 → +90° → punta hacia -X (AZUL); dir_x=+1 → -90° → punta hacia +X (ROJO)
	punta.rotation_degrees = Vector3(0.0, 0.0, -90.0 * dir_x)
	punta.position         = Vector3(dir_x * 2.5, 1.8, 0.0)
	add_child(punta)

	# ── Label informativo ─────────────────────────────────────────────────────
	var label := Label3D.new()
	label.name         = "LabelBando"
	label.text         = ("%s\n%d uds" % [bando.to_upper(), cantidad_inicial])
	label.font_size    = 52
	label.modulate     = color_bando
	label.modulate.a   = 1.0
	label.billboard    = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position     = Vector3(0.0, 3.4, 0.0)
	add_child(label)


## Reorienta la flecha existente cuando cambia el bando en el inspector.
func _actualizar_flecha_direccion() -> void:
	if not Engine.is_editor_hint():
		return
	_construir_flecha()
