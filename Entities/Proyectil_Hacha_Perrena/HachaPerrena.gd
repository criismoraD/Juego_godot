class_name HachaPerrenaProjectile
extends Area3D

## Proyectil Hacha de Perrena: vuela en trayectoria parabolica balistica y
## gira sobre su eje en el aire.
## Causa 2 de daño base, con un bono de +3 contra escudos (defensas del escenario,
## escudos de ImpShieldGirl y clase Guardian como Guardiana Moradita)
## y contra el pilar de la arquera Lonko (daño total = 5).
## El ataque especial causa 3 de daño base y +6 contra escudos/estructuras (daño total = 9).

signal impactado(target: Node)

const DANO_BASE: float = 2.0
const BONO_ESCUDOS_Y_PILAR: float = 3.0
const DANO_BASE_ESPECIAL: float = 3.0  ## Mismo daño base que la flecha explosiva (3 HP)
const BONO_ESTRUCTURAS_ESPECIAL: float = 6.0  ## Bono contra estructuras y escudos (3 + 6 = 9 HP total)
const VELOCIDAD_GIRO: float = 16.0  ## rad/s de giro del hacha
const VELOCIDAD_INICIAL_ESPECIAL: float = 26.0  ## Mayor velocidad y potencia para el ataque especial
const MAT_HACHA: Material = preload("res://Entities/Proyectil_Hacha_Perrena/HACHA_PERRENA_MAT.tres")
const SFX_IMPACTO: String = "res://Entities/Ambiente_Escudo/IMPACTO_ESCUDO_BALLESTA.mp3"

## Offset angular del filo: en el modelo local el filo se situa a +73.35° respecto al origen.
## Restar este angulo orienta el filo exactamente hacia la direccion de vuelo.
const ANGULO_FILO_OFFSET_RAD: float = deg_to_rad(73.35)


@export_category("Fisica")
@export var velocidad_inicial: float = 12.0
@export var gravedad_escala: float = 1.0
@export var tiempo_vida_max: float = 6.0
@export var tiempo_pegada: float = 3.0  ## Tiempo que permanece clavada tras impactar antes de desvanecerse

@export_category("Ataque Especial")
@export var es_hacha_especial: bool = false
@export var objetivo_fijado: Node = null

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

	# Configuracion de colision: detecta enemigos (capa 3/4), escudos (capa 1/2) y entorno (capa 1).
	# Excluida capa 7 (bit 64) y capa 10 (bit 512, BarreraLimite) para no colisionar en el aire
	collision_layer = 0
	collision_mask = 1 | 2 | 4 | 8 | 16 | 32

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


func initialize(
	direccion_disparo: Vector3,
	potencia: float = 1.0,
	p_tirador: Node = null,
	p_es_especial: bool = false,
	p_objetivo: Node = null
) -> void:
	tirador = p_tirador
	es_hacha_especial = p_es_especial
	objetivo_fijado = p_objetivo
	_impacto_procesado = false
	is_stuck = false

	var dir_norm := direccion_disparo.normalized()
	if es_hacha_especial:
		# Hacha de mayor tamaño (escala 2.0x), sin brillos ni particulas doradas
		scale = Vector3(2.0, 2.0, 2.0)
		velocity = dir_norm * (VELOCIDAD_INICIAL_ESPECIAL * maxf(0.5, potencia))
	else:
		velocity = dir_norm * (velocidad_inicial * maxf(0.1, potencia))


## Resuelve la entidad principal dueña en caso de colisionar con hitboxes o areas hijas
func _resolver_entidad_objetivo(node: Node) -> Node:
	var curr: Node = node
	while curr and curr != get_tree().root:
		if curr is ImpShieldGirl or curr is GuardianaMoradita or curr is Lonko or curr is PilarLonkoBody:
			return curr
		if curr is EscudoPesadoArea:
			return curr
		if curr.is_in_group("enemies") or curr.is_in_group("escudos") or curr.is_in_group("guardians") or curr.is_in_group("guardianes") or curr.is_in_group("shield_imps"):
			return curr
		curr = curr.get_parent()
	return node


## Comprueba si el objetivo califica como escudo, pilar o clase Guardian para el bono de daño
func _es_escudo_o_guardian(node: Node) -> bool:
	if not node or not is_instance_valid(node):
		return false

	# 1. Clase Guardian explicita (Imp con escudo, Guardiana Moradita)
	if node is ImpShieldGirl or node is GuardianaMoradita:
		return true

	# 2. Grupos de escudos o guardianes
	if node.is_in_group("escudos") or node.is_in_group("shield_imps") or node.is_in_group("guardians") or node.is_in_group("guardianes"):
		return true

	# 3. Propiedades y metadatos de escudos / pilares enemigos
	if ("es_escudo_enemigo" in node and node.es_escudo_enemigo) or (node.has_meta("es_escudo_enemigo") and node.get_meta("es_escudo_enemigo")):
		return true
	if node.get("es_escudo_enemigo") == true:
		return true
	if ("es_pilar_enemigo" in node and node.es_pilar_enemigo) or (node.has_meta("es_pilar_enemigo") and node.get_meta("es_pilar_enemigo")):
		return true
	if node.get("es_pilar_enemigo") == true:
		return true
	if node is PilarLonkoBody:
		return true
	if "escudo_vida_actual" in node:
		return true

	# 4. Comprobacion por nombre
	var n_lower: String = node.name.to_lower()
	if "pilar" in n_lower or "escudo" in n_lower or "guardiana" in n_lower or "moradita" in n_lower:
		return true
	if "imp" in n_lower and "shield" in n_lower:
		return true

	return false


## Calcula el daño infligido por el hacha segun el tipo de objetivo
## Hacha normal: Base 2.0. Con bono contra escudos (+3.0) para un total de 5.0 (imp de escudo, guardiana moradita, pilares).
## Hacha especial: Base 3.0. Con bono contra estructuras/escudos (+6.0) para un total de 9.0.
func calcular_dano_para(target: Node) -> float:
	if not target or not is_instance_valid(target):
		return DANO_BASE_ESPECIAL if es_hacha_especial else DANO_BASE

	var real_target: Node = _resolver_entidad_objetivo(target)
	var es_escudo_o_guardian: bool = _es_escudo_o_guardian(real_target) or _es_escudo_o_guardian(target)

	if es_hacha_especial:
		return (DANO_BASE_ESPECIAL + BONO_ESTRUCTURAS_ESPECIAL) if es_escudo_o_guardian else DANO_BASE_ESPECIAL

	var dano: float = DANO_BASE
	if es_escudo_o_guardian:
		dano += BONO_ESCUDOS_Y_PILAR
	return dano


func _physics_process(delta: float) -> void:
	if is_stuck or _impacto_procesado:
		return

	_vida_acumulada += delta
	if _vida_acumulada >= tiempo_vida_max:
		queue_free()
		return

	# Si es hacha especial y tiene objetivo fijado valido, corregir trayectoria para asegurar 100% de acierto
	if es_hacha_especial and is_instance_valid(objetivo_fijado) and not objetivo_fijado.is_queued_for_deletion() and objetivo_fijado is Node3D:
		var target_node := objetivo_fijado as Node3D
		var target_pos := target_node.global_position + Vector3(0.0, 0.4, 0.0)
		var to_target := target_pos - global_position
		var dist := to_target.length()

		if dist > 0.05:
			var dir_deseada := to_target.normalized()
			var current_speed: float = maxf(velocity.length(), VELOCIDAD_INICIAL_ESPECIAL)
			# Guiado progresivo hacia el blanco
			velocity = velocity.lerp(dir_deseada * current_speed, clampf(delta * 14.0, 0.0, 1.0)).normalized() * current_speed

		# Si estamos a quemarropa del objetivo, impactar directamente
		if dist <= 0.65:
			_procesar_impacto(target_node, target_pos, -velocity.normalized())
			return
	else:
		# Aplicar gravedad balistica estandar
		velocity.y -= _gravity * delta

	var paso: Vector3 = velocity * delta

	# Comprobacion CCD antes de mover
	if _ray_ccd:
		_ray_ccd.target_position = to_local(global_position + paso)
		_ray_ccd.force_raycast_update()
		if _ray_ccd.is_colliding():
			var col_obj: Object = _ray_ccd.get_collider()
			var col_point: Vector3 = _ray_ccd.get_collision_point()
			var col_normal: Vector3 = _ray_ccd.get_collision_normal()
			if col_obj is Node:
				_procesar_impacto(col_obj as Node, col_point, col_normal)
				if _impacto_procesado:
					return

	global_position += paso

	# Giro del hacha en el aire
	var vel_giro: float = VELOCIDAD_GIRO * (1.5 if es_hacha_especial else 1.0)
	if _modelo_hacha and is_instance_valid(_modelo_hacha):
		_modelo_hacha.rotate_z(-vel_giro * delta)


func _es_entidad_a_ignorar(target: Node) -> bool:
	if not target or not is_instance_valid(target):
		return true
	if target.is_in_group("player") or target.is_in_group("allies") or target == tirador:
		return true
	if target is BarreraLimite or target.is_in_group("barreras_limite") or target is BarreraDestruyeFlechas or target.is_in_group("barrera_destruye_flechas"):
		return true
	var n_lower: String = target.name.to_lower()
	if "limitzone" in n_lower or "barrera" in n_lower:
		return true
	if "es_escudo_enemigo" in target and not target.es_escudo_enemigo:
		return true
	if _es_plataforma_aliada(target):
		return true
	return false


func _on_body_entered(body: Node3D) -> void:
	if _impacto_procesado or _es_entidad_a_ignorar(body):
		return
	_procesar_impacto(body, global_position, -velocity.normalized())


func _on_area_entered(area: Area3D) -> void:
	if _impacto_procesado or _es_entidad_a_ignorar(area):
		return
	var target: Node = area.get_parent() if area.get_parent() else area
	if _es_entidad_a_ignorar(target):
		return
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

	if _es_entidad_a_ignorar(target):
		if _ray_ccd and target is CollisionObject3D:
			_ray_ccd.add_exception(target as CollisionObject3D)
		return

	# Capturar direccion de vuelo real antes de anular la velocidad
	var dir_vuelo: Vector3 = velocity.normalized()
	if dir_vuelo.length_squared() < 0.001:
		dir_vuelo = Vector3.RIGHT

	_impacto_procesado = true
	is_stuck = true
	velocity = Vector3.ZERO
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if _ray_ccd:
		_ray_ccd.enabled = false

	# ═══════════════════════════════════════════════════════════════════════════
	# ORIENTACION DE IMPACTO: EL FILO DEL HACHA (+X DEL MODELO) DEBE IMPACTAR
	# Y CLAVARSE SIEMPRE DIRECTAMENTE EN EL BLANCO
	# ═══════════════════════════════════════════════════════════════════════════
	var ang_filo: float = atan2(dir_vuelo.y, dir_vuelo.x) - ANGULO_FILO_OFFSET_RAD
	if _modelo_hacha and is_instance_valid(_modelo_hacha):
		_modelo_hacha.rotation = Vector3(0.0, 0.0, ang_filo)

	# Clavar ligeramente la hoja hacia el objetivo
	global_position += dir_vuelo * 0.08

	impactado.emit(target)

	var real_target: Node = _resolver_entidad_objetivo(target)
	var dano: float = calcular_dano_para(real_target)

	# Interaccion con aura repelente (ej: Arquera Rosa)
	if real_target.has_method("manejar_impacto_aura") and real_target.manejar_impacto_aura(self):
		_rebotar_y_destruir()
		return
	if target.has_method("manejar_impacto_aura") and target.manejar_impacto_aura(self):
		_rebotar_y_destruir()
		return

	# Registrar metadatos de golpe para efectos de sangre / direccion
	if "last_hit_position" in real_target:
		real_target.set("last_hit_position", punto)
	elif "last_hit_position" in target:
		target.set("last_hit_position", punto)

	if "last_hit_direction" in real_target:
		real_target.set("last_hit_direction", dir_vuelo)
	elif "last_hit_direction" in target:
		target.set("last_hit_direction", dir_vuelo)

	if "ultimo_atacante" in real_target:
		real_target.set("ultimo_atacante", tirador)
	elif "ultimo_atacante" in target:
		target.set("ultimo_atacante", tirador)

	# Si es hacha especial, activa murio_por_explosion para que los enemigos
	# reaccionen con su animacion/fisica especial de muerte explosiva
	if es_hacha_especial:
		if "murio_por_explosion" in real_target:
			real_target.set("murio_por_explosion", true)
		elif real_target.has_meta("murio_por_explosion"):
			real_target.set_meta("murio_por_explosion", true)
		elif "murio_por_explosion" in target:
			target.set("murio_por_explosion", true)
		elif target.has_meta("murio_por_explosion"):
			target.set_meta("murio_por_explosion", true)

		var game_feel = get_tree().root.get_node_or_null("GameFeel") if get_tree() else null
		if game_feel and game_feel.has_method("on_player_shoot"):
			game_feel.on_player_shoot()

	# Aplicar daño al objetivo resuelto o al nodo directo
	if real_target.has_method("recibir_golpe"):
		real_target.call("recibir_golpe", dano)
	elif real_target.has_method("take_damage"):
		real_target.call("take_damage", dano)
	elif real_target.has_method("recibir_dano"):
		real_target.call("recibir_dano", int(dano))
	elif target.has_method("recibir_golpe"):
		target.call("recibir_golpe", dano)
	elif target.has_method("take_damage"):
		target.call("take_damage", dano)
	elif target.has_method("recibir_dano"):
		target.call("recibir_dano", int(dano))

	_reproducir_sfx_impacto(punto)

	# Pegarse al objetivo si es un nodo 3D valido
	var target_pegar: Node = real_target if (real_target is Node3D) else target
	if target_pegar is Node3D and is_instance_valid(target_pegar) and not target_pegar.is_queued_for_deletion():
		call_deferred("_pegar_a_nodo", target_pegar as Node3D)

	# Quedarse el tiempo configurado y luego desvanecerse suavemente
	var dur_pegada: float = 2.0 if es_hacha_especial else tiempo_pegada
	if get_tree():
		get_tree().create_timer(dur_pegada).timeout.connect(
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
	var root := get_tree().current_scene if get_tree() else get_tree().root
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
