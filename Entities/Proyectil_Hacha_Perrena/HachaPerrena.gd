class_name HachaPerrenaProjectile
extends Area3D

## Proyectil Hacha de Perrena: vuela en trayectoria parabólica balística y
## gira sobre su eje como el hueso.
## Causa 2 de daño base, con un bono de +3 contra escudos (defensas del escenario)
## y contra el pilar de la arquera Lonko (daño total = 5).

signal impactado(target: Node)

const DANO_BASE: float = 2.0
const BONO_ESCUDOS_Y_PILAR: float = 3.0
const VELOCIDAD_GIRO: float = 16.0  ## rad/s de giro del hacha
const MAT_HACHA: Material = preload("res://Entities/Proyectil_Hacha_Perrena/HACHA_PERRENA_MAT.tres")
const SFX_IMPACTO: String = "res://Entities/Ambiente_Escudo/IMPACTO_ESCUDO_BALLESTA.mp3"


@export_category("Física")
@export var velocidad_inicial: float = 12.0
@export var gravedad_escala: float = 1.0
@export var tiempo_vida_max: float = 6.0
@export var tiempo_pegada: float = 3.0  ## Tiempo que permanece clavada tras impactar antes de desvanecerse

var velocity: Vector3 = Vector3.ZERO
var tirador: Node = null
var is_stuck: bool = false
var _gravity: float = 9.8
var _impacto_procesado: bool = false
var _desvaneciendose: bool = false
var _modelo_hacha: Node3D = null
var _ray_ccd: RayCast3D = null
var _vida_acumulada: float = 0.0


func _ready() -> void:
	_gravity = ProjectSettings.get_setting("physics/3d/default_gravity") * gravedad_escala
	_modelo_hacha = find_child("HachaModel", true, false) as Node3D
	_aplicar_material()

	# Configuración de colisión: detecta enemigos (capa 3/4), escudos (capa 1/2) y entorno (capa 1).
	# Excluida capa 7 (bit 64) para no colisionar con detectores de plataformas
	collision_layer = 0
	collision_mask = 1 | 2 | 4 | 8 | 16 | 32 | 512

	# Anti-tunneling con RayCast
	_ray_ccd = RayCast3D.new()
	_ray_ccd.name = "RayCastCCD"
	_ray_ccd.enabled = true
	_ray_ccd.collision_mask = collision_mask
	_ray_ccd.collide_with_areas = true
	_ray_ccd.collide_with_bodies = true
	_ray_ccd.exclude_parent = true
	add_child(_ray_ccd)

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func initialize(direccion_disparo: Vector3, potencia: float = 1.0, p_tirador: Node = null) -> void:
	tirador = p_tirador
	var dir_norm := direccion_disparo.normalized()
	velocity = dir_norm * (velocidad_inicial * maxf(0.1, potencia))
	_impacto_procesado = false
	is_stuck = false


## Calcula el daño infligido por el hacha según el tipo de objetivo
## Base: 2.0. Con bono contra escudos y el pilar de Lonko: +3.0 (Total: 5.0).
func calcular_dano_para(target: Node) -> float:
	if not target or not is_instance_valid(target):
		return DANO_BASE

	var es_escudo_o_pilar: bool = false
	if "es_escudo_enemigo" in target and target.es_escudo_enemigo:
		es_escudo_o_pilar = true
	elif target.has_meta("es_escudo_enemigo") and target.get_meta("es_escudo_enemigo"):
		es_escudo_o_pilar = true
	elif target.get("es_escudo_enemigo") == true:
		es_escudo_o_pilar = true
	elif "es_pilar_enemigo" in target and target.es_pilar_enemigo:
		es_escudo_o_pilar = true
	elif target.has_meta("es_pilar_enemigo") and target.get_meta("es_pilar_enemigo"):
		es_escudo_o_pilar = true
	elif target.get("es_pilar_enemigo") == true:
		es_escudo_o_pilar = true
	elif target is PilarLonkoBody:
		es_escudo_o_pilar = true
	elif target.is_in_group("escudos"):
		es_escudo_o_pilar = true

	var dano: float = DANO_BASE
	if es_escudo_o_pilar:
		dano += BONO_ESCUDOS_Y_PILAR
	return dano


func _physics_process(delta: float) -> void:
	if is_stuck or _impacto_procesado:
		return

	_vida_acumulada += delta
	if _vida_acumulada >= tiempo_vida_max:
		queue_free()
		return

	# Aplicar gravedad balística
	velocity.y -= _gravity * delta

	var paso: Vector3 = velocity * delta

	# Comprobación CCD antes de mover
	if _ray_ccd:
		_ray_ccd.target_position = to_local(global_position + paso)
		_ray_ccd.force_raycast_update()
		if _ray_ccd.is_colliding():
			var col_obj: Object = _ray_ccd.get_collider()
			var col_point: Vector3 = _ray_ccd.get_collision_point()
			var col_normal: Vector3 = _ray_ccd.get_collision_normal()
			if col_obj is Node:
				_procesar_impacto(col_obj as Node, col_point, col_normal)
				return

	global_position += paso

	# Giro constante del hacha en el aire
	if _modelo_hacha and is_instance_valid(_modelo_hacha):
		_modelo_hacha.rotate_z(-VELOCIDAD_GIRO * delta)


func _on_body_entered(body: Node3D) -> void:
	if _impacto_procesado:
		return
	_procesar_impacto(body, global_position, -velocity.normalized())


func _on_area_entered(area: Area3D) -> void:
	if _impacto_procesado:
		return
	var target: Node = area.get_parent() if area.get_parent() else area
	_procesar_impacto(target, global_position, -velocity.normalized())


func _es_plataforma_aliada(target: Node) -> bool:
	if not target or not is_instance_valid(target):
		return false
	if target is PlataformaOneway:
		return true
	if target.is_in_group("plataformas") or target.is_in_group("allied_platforms"):
		return true
	var n_lower: String = target.name.to_lower()
	if "plataforma" in n_lower or "oneway" in n_lower or "muro_plataforma" in n_lower or "debris" in n_lower or "arrowdetector" in n_lower or "insidedetector" in n_lower:
		return true
	var p: Node = target.get_parent()
	while p and p != get_tree().root:
		if p is PlataformaOneway:
			return true
		var pn_lower: String = p.name.to_lower()
		if "plataforma" in pn_lower or "oneway" in pn_lower or "muro_plataforma" in pn_lower:
			return true
		p = p.get_parent()
	return false


func _procesar_impacto(target: Node, punto: Vector3, normal: Vector3) -> void:
	if _impacto_procesado or not is_instance_valid(target):
		return

	# Ignorar al jugador o aliados
	if target.is_in_group("player") or target.is_in_group("allies") or target == tirador:
		if _ray_ccd and target is CollisionObject3D:
			_ray_ccd.add_exception(target as CollisionObject3D)
		return

	# Ignorar defensas y escudos aliados
	if "es_escudo_enemigo" in target and not target.es_escudo_enemigo:
		if _ray_ccd and target is CollisionObject3D:
			_ray_ccd.add_exception(target as CollisionObject3D)
		return

	# Ignorar plataformas aliadas del castillo / torre
	if _es_plataforma_aliada(target):
		if _ray_ccd and target is CollisionObject3D:
			_ray_ccd.add_exception(target as CollisionObject3D)
		return

	_impacto_procesado = true
	is_stuck = true
	velocity = Vector3.ZERO
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if _ray_ccd:
		_ray_ccd.enabled = false

	impactado.emit(target)

	var dano: float = calcular_dano_para(target)

	# Interacción con aura repelente (ej: Arquera Rosa)
	if target.has_method("manejar_impacto_aura") and target.manejar_impacto_aura(self):
		_rebotar_y_destruir()
		return

	# Registrar metadatos de golpe para efectos de sangre / dirección
	if "last_hit_position" in target:
		target.set("last_hit_position", punto)
	if "last_hit_direction" in target:
		target.set("last_hit_direction", velocity.normalized())
	if "ultimo_atacante" in target:
		target.set("ultimo_atacante", tirador)

	# Aplicar daño
	if target.has_method("recibir_golpe"):
		target.call("recibir_golpe", dano)
	elif target.has_method("take_damage"):
		target.call("take_damage", dano)
	elif target.has_method("recibir_dano"):
		target.call("recibir_dano", int(dano))

	_reproducir_sfx_impacto(punto)

	# Pegarse al objetivo si es un nodo 3D válido
	if target is Node3D and is_instance_valid(target) and not target.is_queued_for_deletion():
		call_deferred("_pegar_a_nodo", target as Node3D)

	# Quedarse 3 segundos y luego desaparecer como el resto de proyectiles (flechas)
	if get_tree():
		get_tree().create_timer(tiempo_pegada).timeout.connect(
			func():
				if is_instance_valid(self) and is_inside_tree():
					_desvanecer_y_liberar()
		)


func _pegar_a_nodo(target: Node3D) -> void:
	if not is_instance_valid(target) or target.is_queued_for_deletion() or not is_instance_valid(self):
		return
	var trans_global := global_transform
	if get_parent() != target:
		reparent(target)
	global_transform = trans_global


func _desvanecer_y_liberar() -> void:
	if _desvaneciendose:
		return
	_desvaneciendose = true
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ZERO, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)



func _rebotar_y_destruir() -> void:
	velocity = -velocity * 0.4 + Vector3(0, 3, 0)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


func _reproducir_sfx_impacto(pos: Vector3) -> void:
	if not ResourceLoader.exists(SFX_IMPACTO):
		return
	var stream := load(SFX_IMPACTO) as AudioStream
	if not stream:
		return
	var audio := AudioStreamPlayer3D.new()
	audio.stream = stream
	audio.unit_size = 15.0
	audio.volume_db = 1.0
	audio.bus = "Master"
	var root := get_tree().current_scene if get_tree().current_scene else get_tree().root
	if root:
		root.add_child(audio)
		audio.global_position = pos
		audio.play()
		audio.finished.connect(audio.queue_free)
	else:
		audio.queue_free()


func _aplicar_material() -> void:
	if not _modelo_hacha:
		return
	for mesh in _modelo_hacha.find_children("*", "MeshInstance3D", true, false):
		if mesh is MeshInstance3D:
			(mesh as MeshInstance3D).material_override = MAT_HACHA
