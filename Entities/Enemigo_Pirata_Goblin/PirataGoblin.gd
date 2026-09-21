class_name PirataGoblin
extends ImpEnemy

## Pirata Goblin: variante del Imp con modelo, texturas y animaciones propias.
## Reutiliza TODO el comportamiento del Imp (caminar/correr, pausas IDLE,
## lanzamiento de tridentes, muerte normal y desmembramiento por explosiva).
## Las animaciones del GLB se registran con alias de los nombres del Imp,
## así el ciclo heredado (reproducción, duraciones y loops) funciona sin cambios.
## NOTA: el nodo del modelo se llama "ImpModel" a propósito para que el código
## heredado que lo oculta al morir lo encuentre (es el pirata, no un imp).

const MAT_PIRATA: Material = preload("res://Entities/Enemigo_Pirata_Goblin/MAT_PIRATA_GOBLIN.tres")

## Alias nombre-Imp -> nombre real en PirataGoblin.glb
const MAPA_ANIMACIONES: Dictionary = {
	"CAMINAR": "Strut Walking",
	"CORRER": "Correr",
	"IDLE": "Idle",
	"LANZAR01": "Ataque arrojar",
	"LANZAR2": "Disparo",
	"IMP_MUERTE01": "Muerte 1",
	"IMP_MUERTE02": "Muerte 2",
}
const ANIMACIONES_LOOP: Array[String] = ["CAMINAR", "CORRER", "IDLE"]

## Giro extra de yaw aplicado SOLO mientras se reproduce el disparo "Disparo"
## (alias LANZAR2). Todas las demás animaciones usan la orientación base del .tscn.
## Compensa el facing authored del clip; el seguimiento al jugador se suma aparte.
## Ajustable en el Inspector si el disparo mira al revés (probar 0, 90, -90 o 180).
@export var grados_extra_disparo: float = 180.0
## Velocidad con que el modelo gira para seguir al jugador durante el disparo.
@export var suavizado_aim_disparo: float = 10.0

var _yaw_base_modelo: float = 0.0
var _yaw_base_guardado: bool = false


func _on_enemy_ready() -> void:
	material_imp = MAT_PIRATA
	_aliasar_animaciones()
	super._on_enemy_ready()


## Registra cada animación del pirata también bajo el nombre que espera el Imp.
## Comparte el recurso (sin duplicar datos) y fuerza loop en las de movimiento.
func _aliasar_animaciones() -> void:
	if anim_player == null:
		return
	for lib_name in anim_player.get_animation_library_list():
		var lib := anim_player.get_animation_library(lib_name)
		if lib == null:
			continue
		for alias in MAPA_ANIMACIONES:
			var real: String = MAPA_ANIMACIONES[alias]
			if not lib.has_animation(alias) and lib.has_animation(real):
				lib.add_animation(alias, lib.get_animation(real))
	for alias in ANIMACIONES_LOOP:
		if anim_player.has_animation(alias):
			var a := anim_player.get_animation(alias)
			if a:
				a.loop_mode = Animation.LOOP_LINEAR


## Todo el playback del Imp pasa por _play_animation: aquí se gira el modelo
## solo durante LANZAR2 ("Disparo") y se restaura la base en cualquier otra
## animación (caminar, correr, idle, arrojar, muerte). El giro se aplica al
## nodo ImpModel, así el facing del cuerpo (CharacterBody3D) no se altera.
func _play_animation(anim_name: String, custom_blend: float = -1.0, speed: float = 1.0):
	_aplicar_yaw_disparo(anim_name)
	super._play_animation(anim_name, custom_blend, speed)


func _aplicar_yaw_disparo(anim_name: String) -> void:
	var modelo := get_node_or_null("ImpModel") as Node3D
	if modelo == null:
		return
	if not _yaw_base_guardado:
		_yaw_base_modelo = modelo.rotation.y
		_yaw_base_guardado = true
	if anim_name == "LANZAR2":
		modelo.rotation.y = _yaw_base_modelo + deg_to_rad(grados_extra_disparo)
	else:
		modelo.rotation.y = _yaw_base_modelo


func _process(delta: float) -> void:
	super._process(delta)
	_actualizar_aim_disparo(delta)


## Mientras dura el disparo (LANZAR2), el modelo gira para apuntar al jugador.
## Es la ÚNICA animación que se orienta: al terminar, _play_animation restaura
## la base con IDLE/caminar/muerte. El cuerpo (CharacterBody3D) no se toca.
func _actualizar_aim_disparo(delta: float) -> void:
	if not is_throwing or current_throw_anim != "LANZAR2":
		return
	if current_state == State.DYING or current_state == State.DEAD:
		return
	var modelo := get_node_or_null("ImpModel") as Node3D
	if modelo == null or not modelo.is_inside_tree():
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null or not is_instance_valid(player):
		return
	if player.get("is_dead"):
		return
	var dir: Vector3 = player.global_position - modelo.global_position
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	# Yaw de mundo hacia el jugador (forward -Z) + compensación del clip.
	var yaw_deseado_mundo: float = atan2(-dir.x, -dir.z) + deg_to_rad(grados_extra_disparo)
	# Pasar a yaw local por si el cuerpo alguna vez rota.
	var padre := modelo.get_parent() as Node3D
	var yaw_padre_mundo: float = padre.global_rotation.y if padre else 0.0
	var peso: float = minf(1.0, suavizado_aim_disparo * delta)
	modelo.rotation.y = lerp_angle(modelo.rotation.y, yaw_deseado_mundo - yaw_padre_mundo, peso)
